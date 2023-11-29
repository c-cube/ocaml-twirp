(** Generic client module *)

module Common = struct
  module Error = Error

  type headers = (string * string) list
  type error = Error.error

  let pp_error = Error.pp_error
  let show_error e = Format.asprintf "%a" pp_error e
end

open! Common

module type IO = sig
  type 'a t

  val return : 'a -> 'a t
  val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
end

module type PARAMS = sig
  module IO : IO

  type client

  val http_post :
    headers:headers ->
    url:string ->
    body:string ->
    client ->
    unit ->
    (string * int * headers, string) result IO.t
end

module type S = sig
  module IO : IO

  type client

  val call :
    ?encoding:[ `JSON | `BINARY ] ->
    ?prefix:string option ->
    ?use_tls:bool ->
    ?headers:headers ->
    host:string ->
    port:int ->
    client ->
    ( 'req,
      Pbrt_services.Value_mode.unary,
      'res,
      Pbrt_services.Value_mode.unary )
    Pbrt_services.Client.rpc ->
    'req ->
    ('res, error) result IO.t
end

module Make (P : PARAMS) : S with module IO = P.IO and type client = P.client =
struct
  module IO = P.IO
  open IO
  open! Pbrt_services

  let spf = Printf.sprintf

  type client = P.client

  let decode_error exn : error =
    {
      Error.code = "decoding error";
      msg = spf "decoding response failed with: %s" (Printexc.to_string exn);
    }

  let unknown_error msg : error =
    {
      Error.code = "unknown";
      msg = spf "call failed with unknown reason: %s" msg;
    }

  let call ?(encoding : [ `JSON | `BINARY ] = `BINARY) ?(prefix = Some "twirp")
      ?(use_tls = false) ?(headers = []) ~host ~port (client : P.client)
      (rpc : ('req, Value_mode.unary, 'res, Value_mode.unary) Client.rpc)
      (req : 'req) : ('res, error) result t =
    (* first, encode query *)
    let (req_data : string), content_type =
      match encoding with
      | `JSON ->
        let data = rpc.encode_json_req req |> Yojson.Basic.to_string in
        data, "application/json"
      | `BINARY ->
        let enc = Pbrt.Encoder.create () in
        rpc.encode_pb_req req enc;
        Pbrt.Encoder.to_string enc, "application/protobuf"
    in

    (* Compute remote URL.
       Routing is done via:
       [POST [<prefix>]/[<package>.]<Service>/<Method>],
       see {{:https://twitchtv.github.io/twirp/docs/routing.html} the docs}.

       Errors: [https://twitchtv.github.io/twirp/docs/errors.html]
    *)
    let url : string =
      (* the [<package>.<Service>] part. *)
      let qualified_service_path_component =
        match rpc.package with
        | [] -> rpc.service_name
        | path -> spf "%s.%s" (String.concat "." path) rpc.service_name
      in

      let prefix =
        match prefix with
        | None -> ""
        | Some p -> spf "%s/" p
      in

      let protocol =
        if use_tls then
          "https"
        else
          "http"
      in
      spf "%s://%s:%d/%s%s/%s" protocol host port prefix
        qualified_service_path_component rpc.rpc_name
    in

    let headers = ("content-type", content_type) :: headers in

    let* res = P.http_post client ~url ~body:req_data ~headers () in

    match res with
    | Ok (body, code, _headers) when code >= 200 && code < 300 ->
      (* success *)
      let res =
        match
          match encoding with
          | `JSON -> rpc.decode_json_res (Yojson.Basic.from_string body)
          | `BINARY -> rpc.decode_pb_res (Pbrt.Decoder.of_string body)
        with
        | res -> Ok res
        | exception exn -> Error (decode_error exn)
      in
      return res
    | Ok (body, _, _) ->
      let res =
        match Error.decode_json_error @@ Yojson.Basic.from_string body with
        | err -> Error err
        | exception exn -> Error (decode_error exn)
      in
      return res
    | Error msg ->
      return @@ Error (unknown_error @@ spf "http call failed: %s" msg)
end
