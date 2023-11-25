let spf = Printf.sprintf
let ( let@ ) = ( @@ )
let n_errs = Atomic.make 0
let n_queries = Atomic.make 0

let run_n ~sum ~port ~n () =
  let@ client = Ezcurl.with_client ?set_opts:None in
  for _i = 1 to n do
    Atomic.incr n_queries;
    let r =
      match
        Twirp_ezcurl.call ~client ~use_tls:false ~host:"localhost" ~port
          Calculator.Calculator.Client.add
        @@ Calculator.default_add_req ~a:31l ~b:100l ()
      with
      | Ok x -> x.value |> Int32.to_int
      | Error err ->
        Atomic.incr n_errs;
        Printf.eprintf "call to add failed: %s\n%!"
        @@ Twirp_ezcurl.show_error err;
        assert false
    in
    assert (r = 131);

    ignore (Atomic.fetch_and_add sum r : int)
  done;
  ()

let main ~port ~j ~n () =
  let sum = Atomic.make 0 in
  let t_start = Unix.gettimeofday () in

  (* init in single thread place.
     TODO: remove this once it's fixed in ezcurl *)
  ignore (Ezcurl.make ());

  let slice_size = n / j in
  let workers =
    Array.init j (fun i ->
        let actual_size = min n ((i + 1) * slice_size) - (i * slice_size) in
        Moonpool.start_thread_on_some_domain
          (fun () -> run_n ~sum ~n:actual_size ~port ())
          ())
  in

  Array.iter Thread.join workers;

  let t_stop = Unix.gettimeofday () in
  Printf.printf "sum: %d, expected: %d\n" (Atomic.get sum) (131 * n);
  Printf.printf "did %d queries in %.4fs (%.1f req/s)\n%!"
    (Atomic.get n_queries) (t_stop -. t_start)
    (float n /. (t_stop -. t_start));
  Printf.printf "%d errors\n%!" (Atomic.get n_errs);
  ()

let () =
  let port = ref @@ try int_of_string (Sys.getenv "PORT") with _ -> 8080 in
  let j = ref 30 in
  let n = ref 100_000 in
  let args =
    [
      "-p", Arg.Set_int port, " port";
      "-j", Arg.Set_int j, " number of workers";
      "-n", Arg.Set_int n, " number of queries";
    ]
    |> Arg.align
  in
  Arg.parse args ignore "";

  Printf.printf "run %d queries on http://localhost:%d with %d workers\n%!" !n
    !port !j;
  main ~j:!j ~port:!port ~n:!n ()
