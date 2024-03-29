module H = Tiny_httpd
module PB_server = Pbrt_services.Server
module Error = Twirp_core.Error
module Error_codes = Twirp_core.Error_codes

let spf = Printf.sprintf

exception Fail of Error_codes.t * string option

let fail ?msg err = raise (Fail (err, msg))
let failf err fmt = Format.kasprintf (fun m -> fail err ~msg:m) fmt

(** A request handler, specialized for Twirp. *)
type handler =
  | Handler : {
      rpc:
        ( 'req,
          Pbrt_services.Value_mode.unary,
          'res,
          Pbrt_services.Value_mode.unary )
        Pbrt_services.Server.rpc;
      f: 'req -> 'res;
    }
      -> handler

let mk_handler rpc f : handler = Handler { rpc; f }

let return_error (err : Error_codes.t) (msg : string option) : H.Response.t =
  let msg =
    match msg with
    | Some m -> m
    | None -> Error_codes.to_descr err
  in
  let code, http_code = Error_codes.to_msg_and_code err in
  let err = Error.default_error ~code ~msg () in
  let json_body : string =
    Error.encode_json_error err |> Yojson.Basic.to_string
  in
  H.Response.make_raw
    ~headers:[ "content-type", "application/json" ]
    ~code:http_code json_body

let handle_rpc (rpc : handler) (req : string H.Request.t) : H.Response.t =
  try
    let (Handler
          {
            rpc =
              {
                name = _;
                req_mode;
                res_mode;
                encode_json_res;
                encode_pb_res;
                decode_json_req;
                decode_pb_req;
              };
            f;
          }) =
      rpc
    in

    (* get the raw unary wrapper *)
    let f : _ -> _ =
      match req_mode, res_mode with
      | Unary, Unary -> f
      | _ ->
        failf Error_codes.Unimplemented
          "twirp over http 1.1 does not handle streaming"
    in

    let content_type =
      match H.Request.get_header req "content-type" with
      | Some "application/json" -> `JSON
      | Some "application/protobuf" -> `BINARY
      | Some r -> failf Error_codes.Malformed "unknown application type %S" r
      | None -> failf Error_codes.Malformed "no application type specified"
    in

    (* parse request *)
    let req =
      match content_type with
      | `JSON ->
        (try decode_json_req (Yojson.Basic.from_string req.body)
         with _ -> failf Error_codes.Malformed "could not decode json")
      | `BINARY ->
        let dec = Pbrt.Decoder.of_string req.body in
        (try decode_pb_req dec
         with _ -> failf Error_codes.Malformed "could not decode protobuf")
    in

    (* call handler *)
    let res =
      try f req
      with exn ->
        failf Error_codes.Internal "handler failed with %s"
          (Printexc.to_string exn)
    in

    (* serialize result *)
    match content_type with
    | `JSON ->
      let res = Yojson.Basic.to_string @@ encode_json_res res in
      H.Response.make_string @@ Ok res
    | `BINARY ->
      (* TODO: it would be good to be able to reuse the encoder,
         e.g. with a pool of encoders *)
      let enc = Pbrt.Encoder.create () in
      encode_pb_res res enc;

      (* write the encoder's content directly into the output *)
      let write out =
        Pbrt.Encoder.write_chunks
          (fun buf i len -> H.IO.Output.output out buf i len)
          enc
      in
      H.Response.make_writer @@ Ok (H.IO.Writer.make ~write ())
  with
  | Fail (err, msg) -> return_error err msg
  | exn ->
    return_error Error_codes.Unknown
      (Some (spf "handler failed with %s" (Printexc.to_string exn)))

open struct
  let add_prefix_to_route (pre : string) (r : _ H.Route.t) : _ H.Route.t =
    if pre = "" then
      r
    else (
      let pre_fragments = String.split_on_char '/' pre in
      List.fold_right
        (fun fragment r -> H.Route.(exact fragment @/ r))
        pre_fragments r
    )
end

let add_service ?middlewares ?(prefix = Some "twirp") (server : H.t)
    (service : handler PB_server.t) : unit =
  let add_handler (Handler { rpc; _ } as handler) : unit =
    (* routing is done via:
       [POST [<prefix>]/[<package>.]<Service>/<Method>],
       see {{:https://twitchtv.github.io/twirp/docs/routing.html} the docs}.

       Errors: [https://twitchtv.github.io/twirp/docs/errors.html]
    *)

    (* the [<package>.<Service>] part. *)
    let qualified_service_path_component =
      match service.package with
      | [] -> service.service_name
      | path -> spf "%s.%s" (String.concat "." path) service.service_name
    in

    let route =
      add_prefix_to_route qualified_service_path_component
        H.Route.(exact rpc.name @/ return)
    in

    let route =
      match prefix with
      | Some p -> H.Route.(exact p @/ route)
      | None -> route
    in

    H.add_route_handler server ~meth:`POST ?middlewares route (fun req ->
        handle_rpc handler req)
  in

  List.iter add_handler service.handlers
