include Twirp_core.Client.Common

module C = Twirp_core.Client.Make (struct
  module IO = struct
    type 'a t = 'a

    let ( let* ) = ( |> )
    let return = Fun.id
  end

  type client = Ezcurl.t

  let http_post ~headers ~url ~body client () : _ result =
    match
      Ezcurl.post ~client ~url ~params:[] ~content:(`String body) ~headers ()
    with
    | Ok { code; body; headers; _ } -> Ok (body, code, headers)
    | Error (_code, str) -> Error str
end)

let call ?(client : Ezcurl.t = Ezcurl.make ()) ?encoding ?prefix ?headers
    ~base_url rpc req : _ result =
  C.call ?encoding ?prefix ?headers ~base_url client rpc req

exception E_twirp of error

let call_exn ?client ?encoding ?prefix ?headers ~base_url rpc req =
  match call ?client ?encoding ?prefix ?headers ~base_url rpc req with
  | Ok x -> x
  | Error err -> raise (E_twirp err)
