open Lwt.Infix

let key s = Mirage_kv.Key.v s

let size t1 key =
  T1.get t1 key >|= function Ok r -> Ok (String.length r) | Error e -> Error e

let main =
  T1.connect () >>= fun src ->
  (T1.get src (key "a.ext") >|= function
   | Ok res ->
       if res = "foo\n" then print_endline "read a.ext successfully"
       else Fmt.failwith "unexpected read value, expecting foo, read: %s" res
   | Error e -> Fmt.failwith "error while reading 'a.ext': %a" T1.pp_error e)
  >>= fun () ->
  (size src (key "c") >>= function
   | Error _ -> Fmt.failwith "error while calling size on 'c'"
   | Ok l ->
       if l = 4100 then
         T1.get src (key "c") >|= function
         | Error e -> Fmt.failwith "error while reading 'c': %a" T1.pp_error e
         | Ok _ -> print_endline "read 'c' successfully"
       else failwith "invalid size while reading 'c'")
  >>= fun () ->
  (size src (key "d") >>= function
   | Error e -> Fmt.failwith "error while calling size on 'd': %a" T1.pp_error e
   | Ok l ->
       if l = 12300 then
         T1.get src (key "d") >|= function
         | Error e -> Fmt.failwith "error while reading 'd': %a" T1.pp_error e
         | Ok _ -> print_endline "read 'd' successfully"
       else Fmt.failwith "invalid size while reading 'd'")
  >>= fun () ->
  T1.get src (key "e/f") >|= function
  | Error e -> Fmt.failwith "error while reading 'd': %a" T1.pp_error e
  | Ok data ->
      if data = "hallohallo\n" then print_endline "read e/f successfully"
      else
        Fmt.failwith "unexpected read value, expecting hallohallo, read: %s"
          data

let () = Lwt_main.run main
