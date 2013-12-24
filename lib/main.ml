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

open Cmdliner

(* wrapper for realpath(2) *)
external realpath : string -> string = "unix_realpath"

let binary = Filename.basename Sys.argv.(0)

let walker output mode dirs exts =
  let dirs = List.map realpath dirs in
  let oc = match output with
    | None   -> stdout
    | Some f ->
      Printf.printf "Generating %s\n%!" f;
      open_out f in
  let cwd = Sys.getcwd () in
  Crunch.output_header oc binary;
  List.iter (Crunch.walk_directory_tree exts (Crunch.output_file oc)) dirs;
  Crunch.output_footer oc;
  begin match mode with
    | `Lwt   -> Crunch.output_lwt_skeleton_ml oc
    | `Plain -> Crunch.output_plain_skeleton_ml oc
  end;
  close_out oc;
  match output with
  | Some f when Filename.check_suffix f ".ml" && mode = `Lwt ->
    let mli = (Filename.chop_extension f) ^ ".mli" in
    Printf.printf "Generating %s\n%!" mli;
    Sys.chdir cwd;
    let oc = open_out mli in
    Crunch.output_generated_by oc binary;
    Crunch.output_lwt_skeleton_mli oc;
    close_out oc
  | Some _ -> Printf.printf "Skipping generation of .mli\n%!"
  | None   -> ()

let () =
  let dirs = Arg.(non_empty & pos_all dir [] & info [] ~docv:"DIRECTORIES"
    ~doc:"Directories to recursively walk and crunch.") in
  let output = Arg.(value & opt (some string) None & info ["o";"output"] ~docv:"OUTPUT"
    ~doc:"Output file for the OCaml module.") in
  let mode = Arg.(value & opt (enum ["lwt",`Lwt; "plain",`Plain]) `Lwt & info ["m";"mode"] ~docv:"MODE"
    ~doc:"Interface access mode: 'lwt' or 'plain'. 'lwt' is the default.") in
  let exts = Arg.(value & opt_all string [] & info ["e";"ext"] ~docv:"VALID EXTENSION"
    ~doc:"If specified, only these extensions will be included in the crunched output. If not specified, then all files will be crunched into the output module.") in
  let cmd_t = Term.(pure walker $ output $ mode $ dirs $ exts) in
  let info =
    let doc = "Convert a directory structure into a standalone OCaml module that can serve the file contents without requiring an external filesystem to be present." in
    let man = [ `S "BUGS"; `P "Email bug reports to <mirage-devel@lists.xenproject.org>."] in
    Term.info "ocaml-crunch" ~version:"1.2.3" ~doc ~man
  in
  match Term.eval (cmd_t, info) with `Ok x -> x | _ -> exit 1
