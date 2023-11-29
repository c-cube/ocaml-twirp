module C = Twirp_cohttp_lwt_unix

let ( let* ) = Lwt.bind
let spf = Printf.sprintf
let aspf = Format.asprintf

let main ~port () : _ Lwt.t =
  let* res =
    C.call ~use_tls:false ~host:"localhost" ~port
      Calculator.Calculator.Client.add
    @@ Calculator.default_add_req ~a:31l ~b:100l ()
  in
  let r =
    match res with
    | Ok x -> x.value |> Int32.to_int
    | Error err -> failwith (aspf "call to add failed: %a" C.pp_error err)
  in

  Printf.printf "add call: returned %d\n%!" r;
  Lwt.return ()

let () =
  let port = try int_of_string (Sys.getenv "PORT") with _ -> 8080 in
  Printf.printf "query on http://localhost:%d/\n%!" port;

  Lwt_main.run @@ main ~port ()
