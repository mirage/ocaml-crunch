open Lwt.Infix

let string_of_stream s =
  let s = List.map Cstruct.to_string s in
  Lwt.return (String.concat "" s)

let () =
  let _ =
    T1.connect()
    >>= fun src ->
    T1.read src "a" 0L 4096L
    >>= function
    | Ok s ->
       string_of_stream s
       >>= fun res ->
       if res = "foo\n" then
         Lwt.return_unit
       else
         raise (Failure (Printf.sprintf "unexpected read value, expecting foo, read: %s" res))
    | Error a -> raise (Failure "error")
  in
  ()
