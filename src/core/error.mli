
(** Code for error.proto *)

(* generated from "error.proto", do not edit *)



(** {2 Types} *)

type error = {
  _presence: Pbrt.Bitfield.t;
  (** tracking presence for 2 fields *)
  code : string;
  msg : string;
}


(** {2 Basic values} *)

val default_error : error 
(** [default_error] is the default value for type [error] *)


(** {2 Make functions} *)

val make_error : 
  ?code:string ->
  ?msg:string ->
  unit ->
  error
(** [make_error … ()] is a builder for type [error] *)

val has_error_code : error -> bool
  (** presence of field "code" in [error] *)

val has_error_msg : error -> bool
  (** presence of field "msg" in [error] *)


(** {2 Formatters} *)

val pp_error : Format.formatter -> error -> unit 
(** [pp_error v] formats v *)


(** {2 Protobuf YoJson Encoding} *)

val encode_json_error : error -> Yojson.Basic.t
(** [encode_json_error v encoder] encodes [v] to to json *)


(** {2 JSON Decoding} *)

val decode_json_error : Yojson.Basic.t -> error
(** [decode_json_error decoder] decodes a [error] value from [decoder] *)
