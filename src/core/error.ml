[@@@ocaml.warning "-27-30-39-44"]

type error = {
  _presence: Pbrt.Bitfield.t;
  (** tracking presence for 2 fields *)
  code : string;
  msg : string;
}

let default_error: error = 
{
  _presence=Pbrt.Bitfield.empty;
  code="";
  msg="";
}

type error_mutable = {
  mutable _presence: Pbrt.Bitfield.t;
  (** tracking presence for 2 fields *)
  mutable code : string;
  mutable msg : string;
}

let default_error_mutable () : error_mutable = {
  _presence = Pbrt.Bitfield.empty;
  code = "";
  msg = "";
}


(** {2 Make functions} *)

let rec make_error 
  ?(code:string option)
  ?(msg:string option)
  () : error  =
  let _presence = ref Pbrt.Bitfield.empty in
  let code=(match code with
  | None -> ""
  | Some v -> _presence := (Pbrt.Bitfield.set !_presence 0); v) in
  let msg=(match msg with
  | None -> ""
  | Some v -> _presence := (Pbrt.Bitfield.set !_presence 1); v) in
  { _presence= !_presence;code;msg }
let[@inline] has_error_code (self:error) : bool = (Pbrt.Bitfield.get self._presence 0)
let[@inline] has_error_msg (self:error) : bool = (Pbrt.Bitfield.get self._presence 1)

[@@@ocaml.warning "-27-30-39"]

(** {2 Formatters} *)

let rec pp_error fmt (v:error) = 
  let pp_i fmt () =
    Pbrt.Pp.pp_record_field ~first:true "code" Pbrt.Pp.pp_string fmt v.code;
    if not (Pbrt.Bitfield.get v._presence 0) then Format.pp_print_string fmt "(* absent *)";
    Pbrt.Pp.pp_record_field ~first:false "msg" Pbrt.Pp.pp_string fmt v.msg;
    if not (Pbrt.Bitfield.get v._presence 1) then Format.pp_print_string fmt "(* absent *)";
  in
  Pbrt.Pp.pp_brk pp_i fmt ()

[@@@ocaml.warning "-27-30-39"]

(** {2 Protobuf YoJson Encoding} *)

let rec encode_json_error (v:error) = 
  let assoc = [] in 
  let assoc = ("code", Pbrt_yojson.make_string v.code) :: assoc in
  let assoc = ("msg", Pbrt_yojson.make_string v.msg) :: assoc in
  `Assoc assoc

[@@@ocaml.warning "-27-30-39"]

(** {2 JSON Decoding} *)

let rec decode_json_error d =
  let v = default_error_mutable () in
  let assoc = match d with
    | `Assoc assoc -> assoc
    | _ -> assert(false)
  in
  List.iter (function 
    | ("code", json_value) -> 
      v.code <- Pbrt_yojson.string json_value "error" "code"
    | ("msg", json_value) -> 
      v.msg <- Pbrt_yojson.string json_value "error" "msg"
    
    | (_, _) -> () (*Unknown fields are ignored*)
  ) assoc;
  ({
    _presence = v._presence;
    code = v.code;
    msg = v.msg;
  } : error)
