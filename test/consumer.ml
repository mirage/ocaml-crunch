open Lwt.Infix

let key s = Mirage_kv.Key.v s

let size t1 key =
  T1.get t1 key >|= function
  | Ok r -> Ok (String.length r)
  | Error e -> Error e

let main =
  T1.connect() >>= fun src ->
  (T1.get src (key "a") >>= function
    | Ok res ->
      if res = "foo\n" then
        (print_endline "read a successfully" ; Lwt.return_unit)
      else
        raise (Failure (Printf.sprintf "unexpected read value, expecting foo, read: %s" res))
    | Error _ -> raise (Failure "error while reading 'a'")) >>= fun () ->
  ( size src (key "c") >>= function
      | Error _ -> raise (Failure "error while calling size on 'c'")
      | Ok l ->
        if l = 4100 then
          T1.get src (key "c") >>= function
          | Error _ -> raise (Failure "error while reading 'c'")
          | Ok _ -> print_endline "read 'c' successfully" ; Lwt.return_unit
        else
          raise (Failure "invalid size while reading 'c'") ) >>= fun () ->
  ( size src (key "d") >>= function
      | Error _ -> raise (Failure "error while calling size on 'd'")
      | Ok l ->
        if l = 12300 then
          T1.get src (key "d") >>= function
          | Error _ -> raise (Failure "error while reading 'd'")
          | Ok _ -> print_endline "read 'd' successfully" ; Lwt.return_unit
        else
          raise (Failure "invalid size while reading 'd'") ) >>= fun () ->
  T1.get src (key "e/f") >>= function
  | Error _ -> raise (Failure "error while reading 'd'")
  | Ok data ->
    if data = "hallohallo\n" then
      (print_endline "read e/f successfully" ; Lwt.return_unit)
    else
      raise (Failure (Printf.sprintf "unexpected read value, expecting hallohallo, read: %s" data))

let () =
  Lwt_main.run main
