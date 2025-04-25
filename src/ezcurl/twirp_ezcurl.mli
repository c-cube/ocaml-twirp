open Pbrt_services
include module type of Twirp_core.Client.Common

val call :
  ?client:Ezcurl.t ->
  ?encoding:[ `JSON | `BINARY ] ->
  ?prefix:string option ->
  ?headers:headers ->
  base_url:string ->
  ('req, Value_mode.unary, 'res, Value_mode.unary) Client.rpc ->
  'req ->
  ('res, error) result

exception E_twirp of error

val call_exn :
  ?client:Ezcurl.t ->
  ?encoding:[ `JSON | `BINARY ] ->
  ?prefix:string option ->
  ?headers:headers ->
  base_url:string ->
  ('req, Value_mode.unary, 'res, Value_mode.unary) Client.rpc ->
  'req ->
  'res
(** Same as {!call} but raises [E_twirp] on failure. *)
