module H = Tiny_httpd
open Calculator

let ( let@ ) = ( @@ )

module Service_impl = struct
  let add (a : add_req) : i32 = default_i32 ~value:Int32.(add a.a a.b) ()

  let add_all (a : add_all_req) : i32 =
    let l = ref 0l in
    List.iter (fun x -> l := Int32.add !l x) a.ints;
    default_i32 ~value:!l ()

  let n_pings = ref 0
  let ping () = incr n_pings
  let get_pings () : i32 = default_i32 ~value:(Int32.of_int !n_pings) ()
end

let calc_service : Twirp_tiny_httpd.handler Pbrt_services.Server.t =
  Calculator.Server.make
    ~add:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.add)
    ~add_all:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.add_all)
    ~ping:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.ping)
    ~get_pings:(fun rpc ->
      Twirp_tiny_httpd.mk_handler rpc Service_impl.get_pings)
    ()

let () =
  let port = ref @@ try int_of_string (Sys.getenv "PORT") with _ -> 8080 in
  let j = ref 30 in
  let args =
    [
      "-p", Arg.Set_int port, " port"; "-j", Arg.Set_int j, " number of workers";
    ]
    |> Arg.align
  in
  Arg.parse args ignore "";

  Printf.printf "listen on http://localhost:%d/ with %d workers\n%!" !port !j;

  let@ pool = Moonpool.Fifo_pool.with_ ~num_threads:!j () in

  let server =
    H.create ~port:!port
      ~new_thread:(fun task -> Moonpool.Runner.run_async pool task)
      ()
  in
  Twirp_tiny_httpd.add_service ~prefix:(Some "twirp") server calc_service;

  H.run_exn server
