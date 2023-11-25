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
 (name twirp_ezcurl)
 (synopsis "Twirp client using Ezcurl")
 (depends
  (ocaml (>= 4.08))
  dune
  ezcurl
  pbrt
  pbrt-yojson
  pbrt-services
  (odoc :with-doc))
 (tags
  (twirp protobuf client rpc curl)))

(package
 (name twirp_tiny_httpd)
 (synopsis "Host Twirp services using Tiny_httpd")
 (depends
  (ocaml (>= 4.08))
  dune
  tiny_httpd
  pbrt
  pbrt-yojson
  pbrt-services
  (odoc :with-doc))
 (tags
  (twirp protobuf services rpc)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
