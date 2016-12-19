open Lwt.Infix

let string_of_stream s =
  let s = List.map Cstruct.to_string s in
  String.concat "" s

let main =
  T1.connect() >>= fun src ->
  (T1.read src "a" 0L 4096L >>= function
    | Ok s ->
      let res = string_of_stream s in
      if res = "foo\n" then
        (print_endline "read a successfully" ; Lwt.return_unit)
      else
        raise (Failure (Printf.sprintf "unexpected read value, expecting foo, read: %s" res))
    | Error _ -> raise (Failure "error while reading 'a'")) >>= fun () ->
  ( T1.size src "c" >>= function
      | Error _ -> raise (Failure "error while calling size on 'c'")
      | Ok l ->
        if l = 4100L then
          T1.read src "c" 0L l >>= function
          | Error _ -> raise (Failure "error while reading 'c'")
          | Ok _ -> print_endline "read 'c' successfully" ; Lwt.return_unit
        else
          raise (Failure "invalid size while reading 'c'") ) >>= fun () ->
  T1.size src "d" >>= function
  | Error _ -> raise (Failure "error while calling size on 'd'")
  | Ok l ->
    if l = 12300L then
      T1.read src "d" 0L l >>= function
      | Error _ -> raise (Failure "error while reading 'd'")
      | Ok _ -> print_endline "read 'd' successfully" ; Lwt.return_unit
    else
      raise (Failure "invalid size while reading 'd'")


let () =
  Lwt_main.run main
