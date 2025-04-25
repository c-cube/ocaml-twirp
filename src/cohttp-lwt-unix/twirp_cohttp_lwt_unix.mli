open Pbrt_services
include module type of Twirp_core.Client.Common

val call :
  ?encoding:[ `JSON | `BINARY ] ->
  ?prefix:string option ->
  ?headers:headers ->
  base_url:string ->
  ('req, Value_mode.unary, 'res, Value_mode.unary) Client.rpc ->
  'req ->
  ('res, error) result Lwt.t
