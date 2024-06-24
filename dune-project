(lang dune 2.9)

(name twirp)
(version 0.1)
(generate_opam_files true)
(source
 (github c-cube/ocaml-twirp))
(authors "Simon Cruanes")
(maintainers "Simon Cruanes")
(license MIT)

;(documentation https://url/to/documentation)

(package
 (name twirp_core)
 (synopsis "Twirp core library")
 (depends
  (ocaml (>= 4.08))
  dune
  (ocaml-protoc (and (>= 3.0) :with-dev))
  logs
  (pbrt (>= 3.0))
  (pbrt_yojson (>= 3.0))
  (pbrt_services (>= 3.0))
  (odoc :with-doc))
 (tags
  (twirp protobuf client rpc curl)))

(package
 (name twirp_ezcurl)
 (synopsis "Twirp client using Ezcurl")
 (depends
  (ocaml (>= 4.08))
  (twirp_core (= :version))
  dune
  ezcurl
  (odoc :with-doc))
 (tags
  (twirp protobuf client rpc curl)))

(package
 (name twirp_cohttp_lwt_unix)
 (synopsis "Twirp client using cohttp-lwt-unix")
 (depends
  (ocaml (>= 4.08))
  (twirp_core (= :version))
  dune
  (cohttp-lwt-unix (>= 5.0))
  lwt
  (odoc :with-doc))
 (tags
  (twirp protobuf client rpc curl)))

(package
 (name twirp_tiny_httpd)
 (synopsis "Host Twirp services using Tiny_httpd")
 (depends
  (ocaml (>= 4.08))
  (twirp_core (= :version))
  dune
  (tiny_httpd (>= 0.16))
  (odoc :with-doc))
 (tags
  (twirp protobuf services rpc)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
