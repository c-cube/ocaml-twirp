include Twirp_core.Client.Common

module C = Twirp_core.Client.Make (struct
  module IO = struct
    type 'a t = 'a Lwt.t

    let ( let* ) = Lwt.bind
    let return = Lwt.return
  end

  type client = unit

  (* type client = Cohttp_lwt_unix.Net.ctx *)

  open IO

  let http_post ~headers ~url ~body (_client : client) () : _ result IO.t =
    let uri = Uri.of_string url in
    Lwt.catch
      (fun () ->
        let headers = Cohttp.Header.of_list headers in
        let* resp, res_body =
          Cohttp_lwt_unix.Client.post ~body:(`String body) ~headers uri
        in

        let code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in

        let* res_body = res_body |> Cohttp_lwt.Body.to_string in
        let headers = Cohttp.Response.headers resp |> Cohttp.Header.to_list in
        return @@ Ok (res_body, code, headers))
      (fun exn -> return @@ Error (Printexc.to_string exn))
end)

let call ?encoding ?prefix ?use_tls ?headers ~host ~port rpc req :
    _ result Lwt.t =
  let client = () in
  C.call ?encoding ?prefix ?use_tls ?headers ~host ~port client rpc req
