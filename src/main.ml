(*
 * Copyright (c) 2009-2013 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2013      Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(* let binary = Sys.argv.(0) |> Filename.basename |> Filename.remove_extension *)
(* NOTE(dinosaure): for the sake of compatibility, we must keep the
   ["ocaml-crunch"] name even for tests where the binary is named by [dune] as
   ["main"]. *)
let binary = "ocaml-crunch"

let walk output mode dirs exts block_size silent names strip_ext =
  let log fmt =
    if silent then Printf.ifprintf stdout fmt
    else Printf.fprintf stdout (fmt ^^ "%!")
  in
  let cwd = Sys.getcwd () in
  let dirs = List.map Realpath.realpath dirs in
  let t =
    List.fold_left
      (fun t -> Crunch.walk_directory_tree t exts Crunch.scan_file)
      (Crunch.make ~block_size ())
      dirs
  in
  Sys.chdir cwd;
  let names =
    Option.map (fun module_name -> Crunch.names t ~module_name ~strip_ext) names
  in
  let output_names emit oc = Option.iter (fun n -> emit n oc) names in
  let oc =
    match output with
    | None -> stdout
    | Some f ->
        log "Generating %s\n" f;
        open_out_bin f
  in
  Crunch.output_generated_by oc binary;
  Crunch.output_implementation t oc;
  (match mode with
  | `Lwt -> Crunch.output_lwt_skeleton_ml oc
  | `Plain -> Crunch.output_plain_skeleton_ml t oc);
  output_names Crunch.output_names_ml oc;
  close_out oc;
  match output with
  | Some f when Filename.check_suffix f ".ml" && mode = `Lwt ->
      let mli = Filename.chop_extension f ^ ".mli" in
      log "Generating %s\n" mli;
      let oc = open_out_bin mli in
      Crunch.output_generated_by oc binary;
      Crunch.output_lwt_skeleton_mli oc;
      output_names Crunch.output_names_mli oc;
      close_out oc
  | Some _ -> log "Skipping generation of .mli\n"
  | None -> ()

let resolve_names names names_module strip_ext =
  if names then
    let m = Option.value names_module ~default:"Name" in
    match Crunch.check_module_name m with
    | Ok () -> Ok (Some m)
    | Error e -> Error (`Msg ("--names-module: " ^ e))
  else if names_module <> None then
    Error (`Msg "--names-module has no effect without --names")
  else if strip_ext then
    Error (`Msg "--names-strip-ext has no effect without --names")
  else Ok None

let walker output mode dirs exts block_size silent names names_module strip_ext
    =
  match resolve_names names names_module strip_ext with
  | Error _ as e -> e
  | Ok names -> (
      try Ok (walk output mode dirs exts block_size silent names strip_ext)
      with Failure msg -> Error (`Msg msg))

open Cmdliner

let () =
  let dirs =
    Arg.(
      non_empty & pos_all dir []
      & info [] ~docv:"DIRECTORIES"
          ~doc:"Directories to recursively walk and crunch.")
  in
  let output =
    Arg.(
      value
      & opt (some string) None
      & info [ "o"; "output" ] ~docv:"OUTPUT"
          ~doc:"Output file for the OCaml module.")
  in
  let modes = [ ("lwt", `Lwt); ("plain", `Plain) ] in
  let mode =
    Arg.(
      value
      & opt (enum modes) `Lwt
      & info [ "m"; "mode" ] ~docv:"MODE"
          ~doc:
            (Printf.sprintf
               "Interface access mode: %s. $(b,lwt) is the default."
               (Arg.doc_alts_enum modes)))
  in
  let exts =
    Arg.(
      value & opt_all string []
      & info [ "e"; "ext" ] ~docv:"VALID EXTENSION"
          ~doc:
            "If specified, only these extensions will be included in the \
             crunched output. If not specified, then all files will be \
             crunched into the output module.")
  in
  let block_size =
    Arg.(
      value & opt int 4096
      & info [ "b"; "block-size" ] ~docv:"BLOCK SIZE"
          ~doc:
            "Size of the chunks files are split into. Identical chunks are \
             emitted only once. Use $(b,0) to emit each file as a single \
             string literal instead: the generated module is bigger, but \
             $(b,read) returns the literal without copying it and the data \
             stays demand-paged from the executable rather than being faulted \
             in wholesale by the GC.")
  in
  let quiet = Arg.(value & flag & info [ "s"; "silent" ] ~doc:"Silent mode.") in
  let names =
    Arg.(
      value & flag
      & info [ "names" ]
          ~doc:
            "Also generate a module binding one value per crunched file, named \
             after its path, so that files are referred to by an identifier \
             the compiler checks rather than by a string.")
  in
  let names_module =
    Arg.(
      value
      & opt (some string) None
      & info [ "names-module" ] ~docv:"MODULE"
          ~doc:
            "Name of the module generated by $(b,--names). Defaults to \
             $(b,Name). Only meaningful together with $(b,--names).")
  in
  let strip_ext =
    Arg.(
      value & flag
      & info [ "names-strip-ext" ]
          ~doc:
            "Drop the file extension when deriving identifiers for \
             $(b,--names), so that $(i,some/secret.age) becomes \
             $(b,some__secret) instead of $(b,some__secret_age). Only \
             meaningful together with $(b,--names), and rejected if two files \
             then map to the same identifier.")
  in
  let cmd_t =
    Term.term_result
      Term.(
        const walker $ output $ mode $ dirs $ exts $ block_size $ quiet $ names
        $ names_module $ strip_ext)
  in
  let info =
    let doc =
      "Convert a directory structure into a standalone OCaml module that can \
       serve the file contents without requiring an external filesystem to be \
       present."
    in
    let envs =
      [
        Cmd.Env.info
          ~doc:
            "Specifies the last modification of crunched files for \
             reproducible output."
          "SOURCE_DATE_EPOCH";
      ]
    in
    let man =
      [
        `S "BUGS";
        `P "Email bug reports to <mirage-devel@lists.xenproject.org>.";
      ]
    in
    Cmd.info "ocaml-crunch" ~version:"%%VERSION%%" ~doc ~man ~envs
  in
  exit @@ Cmd.eval (Cmd.v info cmd_t)
