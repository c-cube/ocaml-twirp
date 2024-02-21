# Twirp

[![Build and Test](https://github.com/c-cube/ocaml-twirp/actions/workflows/main.yml/badge.svg)](https://github.com/c-cube/ocaml-twirp/actions/workflows/main.yml)

This is an OCaml implementation of [Twirp](https://twitchtv.github.io/twirp/)
that relies on [ocaml-protoc](https://github.com/mransan/ocaml-protoc/) to
compile protobuf IDL files.

**NOTE**: this relies on unreleased changes to ocaml-protoc, currently on master. The whole twirp library will have to wait for ocaml-protoc 3.0 to be released to be released itself.

## License

MIT license

## Usage

In the following examples we use a basic "calculator" service
as an example:

```proto
syntax = "proto3";

// single int
message I32 {
  int32 value = 0;
}

// add two numbers
message AddReq {
  int32 a = 1;
  int32 b = 2;
}

// add an array of numbers
message AddAllReq {
  repeated int32 ints = 1;
}

service Calculator {
  rpc add(AddReq) returns (I32);

  rpc add_all(AddAllReq) returns (I32);
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

### Using Tiny_httpd as a server

The library `twirp_tiny_httpd` uses [Tiny_httpd](https://github.com/c-cube/tiny_httpd)
as a HTTP server to host services over HTTP 1.1.

Tiny_httpd is a convenient little HTTP server with no dependencies
that uses direct style control flow
and system threads, rather than an event loop.
Realistically, it is sufficient
for low traffic services (say, less than 100 req/s), and is best used coupled
with a thread pool such as [Moonpool](https://github.com/c-cube/moonpool/)
to improve efficiency.

<details>
<summary>detailed example</summary>

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
end

(* instantiate the code-generated [Calculator] service
  to turn it into a [Pbrt_services.Server.t] abstract service. *)
let calc_service : Twirp_tiny_httpd.handler Pbrt_services.Server.t =
  Calculator.Server.make
    ~add:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.add)
    ~add_all:(fun rpc -> Twirp_tiny_httpd.mk_handler rpc Service_impl.add_all)
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

</details>

### Using ezcurl as a client

The library `twirp_ezcurl` uses [Ezcurl](https://github.com/c-cube/ezcurl)
as a [Curl](https://curl.haxx.se/) wrapper to provide Twirp clients.

Curl is very widely available and is a robust HTTP client; ezcurl adds a
simple OCaml API on top.
Twirp_ezcurl is best used for low-traffic querying of services.

<details>
<summary>full example</summary>
Example (as in 'examples/twirp_ezcurl/') that computes `31 + 100`
remotely:

```ocaml
let spf = Printf.sprintf

let () =
  let port = try int_of_string (Sys.getenv "PORT") with _ -> 8080 in
  Printf.printf "query on http://localhost:%d/\n%!" port;

  let r =
    match
      (* call [Calculator.add] with arguments [{a=31; b=100}] *)
      Twirp_ezcurl.call ~use_tls:false ~host:"localhost" ~port
        Calculator.Calculator.Client.add
      @@ Calculator.default_add_req ~a:31l ~b:100l ()
    with
    | Ok x -> x.value |> Int32.to_int
    | Error err ->
      failwith (spf "call to add failed: %s" @@ Twirp_ezcurl.show_error err)
  in

  Printf.printf "add call: returned %d\n%!" r;
  ()
```

The main function is `Twirp_ezcurl.call`, which takes a remote host, port, service
endpoint (code-generated from a `.proto` file), and an argument, and performs
a HTTP query.
The user can provide an already existing Curl client to reuse, turn TLS off or on,
and pick the wire format (JSON or binary protobuf).

</details>

