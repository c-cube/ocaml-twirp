(** Generic client module *)

open struct
  let spf = Printf.sprintf
end

module Common = struct
  module Error = Error
  module Log = (val Logs.src_log (Logs.Src.create "twirp.client"))

  type headers = (string * string) list
  type error = Error.error

  let pp_error = Error.pp_error
  let show_error e = Format.asprintf "%a" pp_error e

  (** Print at most [max] bytes of [s] in ["%S"] form *)
  let pp_truncate_str ~max out (s : string) =
    if String.length s > max then
      Format.fprintf out "%S[%d bytes omitted]" (String.sub s 0 max)
        (String.length s - max)
    else
      Format.fprintf out "%S" s

  (** Compute base URL from host+port *)
  let base_url ?(use_tls = false) ~host ~port () : string =
    let protocol =
      if use_tls then
        "https"
      else
        "http"
    in
    spf "%s://%s:%d/" protocol host port
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
    ?headers:headers ->
    base_url:string ->
    client ->
    ( 'req,
      Pbrt_services.Value_mode.unary,
      'res,
      Pbrt_services.Value_mode.unary )
    Pbrt_services.Client.rpc ->
    'req ->
    ('res, error) result IO.t
  (** Make a RPC call.
      @param base_url
        replaces host+port+use_tls with a http(s) URL. See {!Common.base_url} to
        get it from host+port+use_tls. since NEXT_RELEASE. *)
end

module Make (P : PARAMS) : S with module IO = P.IO and type client = P.client =
struct
  module IO = P.IO
  open IO
  open! Pbrt_services

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
      ?(headers = []) ~base_url (client : P.client)
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

      spf "%s/%s%s/%s" base_url prefix qualified_service_path_component
        rpc.rpc_name
    in

    let headers = ("content-type", content_type) :: headers in

    Log.debug (fun k ->
        k "issuing HTTP POST on %s body-size=%d" url (String.length req_data));
    let* res = P.http_post client ~url ~body:req_data ~headers () in

    match res with
    | Ok (body, code, _headers) when code >= 200 && code < 300 ->
      Log.debug (fun k ->
          k "got success response with code=%d@ body=%a" code
            (pp_truncate_str ~max:64) body);
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
    | Ok (body, http_code, headers) ->
      let is_json =
        List.exists
          (fun (k, v) ->
            String.lowercase_ascii k = "content-type" && v = "application/json")
          headers
      in
      Log.err (fun k ->
          k "got failed response with code=%d@ body=%a" http_code
            (pp_truncate_str ~max:64) body);
      let res =
        if is_json then (
          match Error.decode_json_error @@ Yojson.Basic.from_string body with
          | err -> err
          | exception exn -> decode_error exn
        ) else (
          match
            List.find_all (fun (_, c, _) -> c = http_code) Error_codes.all
          with
          | [ (code, _, doc) ] ->
            {
              code = Error_codes.to_msg_and_code code |> fst;
              msg = spf "%s\nHTTP code %d, raw message: %s" doc http_code body;
            }
          | _ ->
            {
              code = Error_codes.Malformed |> Error_codes.to_msg_and_code |> fst;
              msg = spf "Unknown error\nraw message: %s" body;
            }
        )
      in
      return @@ Error res
    | Error msg ->
      return @@ Error (unknown_error @@ spf "http call failed: %s" msg)
end
