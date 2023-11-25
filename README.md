# Twirp

This is an OCaml implementation of [Twirp](https://twitchtv.github.io/twirp/)
that relies on [ocaml-protoc](https://github.com/mransan/ocaml-protoc/) to
compile protobuf IDL files.

## License

MIT license

## Usage

In the following examples we use a basic "calculator" service
as an example:

```proto
syntax = "proto3";

message DivByZero {}

message I32 {
  int32 value = 0;
}

message AddReq {
  int32 a = 1;
  int32 b = 2;
}

message AddAllReq {
  repeated int32 ints = 1;
}

message Empty {}

service Calculator {
  rpc add(AddReq) returns (I32);

  rpc add_all(AddAllReq) returns (I32);

  rpc ping(Empty) returns (Empty);

  rpc get_pings(Empty) returns (I32);
}
```

We assume there's a dune rule to extract it into a pair
of .ml and .mli files:

```scheme
(rule
 (targets calculator.ml calculator.mli)
 (deps calculator.proto)
 (action
  (run ocaml-protoc --binary --pp --yojson --services --ml_out ./ %{deps})))
```

### using Tiny_httpd as a server

See 'examples/twirp_tiny_httpd/' for an example:

```ocaml
module H = Tiny_httpd
open Calculator

(* here we give concrete implementations for each of the
  methods of the service.  *)
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

(* instantiate the code-generated [Calculator] service
  to turn it into a [Pbrt_services.Server.t] abstract service. *)
let calc_service : Twirp_tiny_httpd.handler Pbrt_services.Server.t =
  Calculator.make_server
    ~add:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.add)
    ~add_all:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.add_all)
    ~ping:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.ping)
    ~get_pings:(fun rpc ->
      Twirp_tiny_httpd.mk_handler rpc Service_impl.get_pings)
    ()

let () =
  let port = try int_of_string (Sys.getenv "PORT") with _ -> 8080 in
  Printf.printf "listen on http://localhost:%d/\n%!" port;

  (* create the httpd on the given port *)
  let server = H.create ~port () in
  (* register the service in the httpd (adds routes) *)
  Twirp_tiny_httpd.add_service ~prefix:(Some "twirp") server calc_service;

  H.run_exn server
```

We implement the concrete service `Calculator`, then turn it into
a `Pbrt_services.Server.t` (which is an abtract representation of
any service: a set of endpoints). We can then create a [Tiny_httpd.Server.t]
(a web server) and register the service (or multiple services) in it.
This will add new routes (e.g. "/twirp/foo.bar.Calculator/add")
and call the functions we defined above to serve these routes.

