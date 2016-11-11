open Bos
open Printf
open Result

let compile file pkgs =
  Cmd.(v "ocamlbuild" % "-use-ocamlfind" % "-tag" % "thread" % "-pkgs" % pkgs % (file ^ ".native"))
  |> OS.Cmd.run_out |> OS.Cmd.to_string ~trim:true |>
    function | Ok r -> prerr_endline r; r | Error (`Msg e) -> raise (Failure (sprintf "Error: %s" e))

let create_dir dir =
  Fpath.v (dir) |> OS.Dir.create ~path:true |>
    function | Ok r -> r | Error (`Msg e) -> raise (Failure (sprintf "Error: %s" e))

let copy_files target orig =
  (OS.Dir.contents ~rel:true ~dotfiles:false (Fpath.v orig) |>
     function | Ok l -> l | Error (`Msg e) -> raise (Failure (sprintf "Error: %s" e)))
  |> List.iter (fun file ->
         OS.Cmd.run_out Cmd.(v "cp"  % sprintf "%s/%s" orig (Fpath.filename file) % target ) |> OS.Cmd.to_string ~trim:true |>
           function | Ok _ -> () | Error (`Msg e) -> raise (Failure (sprintf "Error: %s" e))
       )

let crunch dir =
  Cmd.(v "./main.native" % dir % "-o" % (dir ^ ".ml"))
  |> OS.Cmd.run_out |> OS.Cmd.to_string ~trim:true |>
    function | Ok r -> prerr_endline r; r | Error (`Msg e) -> raise (Failure (sprintf "Error: %s" e))

let prepare dest orig =
  OS.Dir.delete ~recurse:true (Fpath.v dest)
  |> function
    | Ok r ->
       let _ = create_dir dest in
       List.iter (copy_files dest) orig
    | Error (`Msg e) -> raise (Failure (sprintf "Error: %s" e))

let () =
  let build_dir = "_build/_tests" in
  let test_files_dir = sprintf "%s/t1" build_dir in

  (* move files to _build dir *)
  let _ = prepare build_dir ["lib"; "test/consumer"] in
  let _ = prepare test_files_dir ["test/t1"] in

  (* compile main binary, crunch and compile consumer for crunched files *)
  let _ = OS.Dir.set_current (Fpath.v build_dir) in
  let _ = compile "main" "cmdliner" in
  let _ = crunch "t1" in
  let _ = compile "consumer" "cstruct,lwt,mirage-types,io-page.unix,io-page" in

  (* check that the compiled consumer exits successfully *)
  let _ = Cmd.v ("./consumer.native")
          |> OS.Cmd.run_out |> OS.Cmd.to_string ~trim:true |>
            function | Ok _ -> () | Error (`Msg e) -> raise (Failure (sprintf "Error: %s" e)) in
  ()
