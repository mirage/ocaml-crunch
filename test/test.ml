open Bos
open Printf
open Rresult

let compile file pkgs =
  OS.Cmd.run (Cmd.(v "ocamlbuild" % "-use-ocamlfind" % "-classic-display" % "-tag" % "thread" % "-pkgs" % pkgs % (file ^ ".native")))

let copy_files target orig =
  OS.Dir.contents ~rel:true ~dotfiles:false (Fpath.v orig) >>= fun files ->
  List.fold_left (fun r file ->
      r >>= fun () -> OS.Cmd.run Cmd.(v "cp" % sprintf "%s/%s" orig (Fpath.filename file) % target ))
    (R.ok ())
    files

let crunch dir =
  OS.Cmd.run Cmd.(v "./main.native" % dir % "-o" % (dir ^ ".ml"))

let prepare dest orig =
  OS.Dir.delete ~recurse:true (Fpath.v dest) >>= fun () ->
  OS.Dir.create ~path:true (Fpath.v dest) >>= fun _ ->
  List.fold_left (fun r o -> r >>= fun () -> copy_files dest o) (R.ok ()) orig

let () =
  let build_dir = "_build/_tests" in
  let test_files_dir = sprintf "%s/t1" build_dir in

  Rresult.R.error_msg_to_invalid_arg (

    (* move files to _build dir *)
    prepare build_dir ["src"; "test/consumer"] >>= fun () ->
    prepare test_files_dir ["test/t1"] >>= fun () ->

    (* compile main binary, crunch and compile consumer for crunched files *)
    OS.Dir.set_current (Fpath.v build_dir) >>= fun () ->
    compile "main" "cmdliner" >>= fun () ->
    crunch "t1" >>= fun () ->
    compile "consumer" "cstruct,lwt,lwt.unix,mirage-types,io-page.unix,io-page" >>= fun () ->

    (* check that the compiled consumer exits successfully *)
    OS.Cmd.run (Cmd.v ("./consumer.native")))
