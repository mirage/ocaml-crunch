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

module SM = Map.Make (String)

type file_info = {
  chunk_digests : string list;
  file_digest : string;
  size : int;
}

type t = { block_size : int; chunks : string SM.t; files : file_info SM.t }

let make ?(block_size = 4096) () =
  { block_size; chunks = SM.empty; files = SM.empty }

module Filename = struct
  include Filename

  (* Always use Unix-style filenames for keys *)
  let dir_sep = "/"
  let is_dir_sep s i = s.[i] = '/'

  let concat dirname filename =
    let l = String.length dirname in
    if l = 0 || is_dir_sep dirname (l - 1) then dirname ^ filename
    else dirname ^ dir_sep ^ filename
end

let ocaml_keywords =
  [
    "and";
    "as";
    "assert";
    "asr";
    "begin";
    "class";
    "constraint";
    "do";
    "done";
    "downto";
    "else";
    "end";
    "exception";
    "external";
    "false";
    "for";
    "fun";
    "function";
    "functor";
    "if";
    "in";
    "include";
    "inherit";
    "initializer";
    "land";
    "lazy";
    "let";
    "lor";
    "lsl";
    "lsr";
    "lxor";
    "match";
    "method";
    "mod";
    "module";
    "mutable";
    "new";
    "nonrec";
    "object";
    "of";
    "open";
    "or";
    "private";
    "rec";
    "sig";
    "struct";
    "then";
    "to";
    "true";
    "try";
    "type";
    "val";
    "virtual";
    "when";
    "while";
    "with";
  ]

let reserved = ocaml_keywords @ [ "all"; "contents"; "name"; "path"; "size" ]
let internal_module = "Internal"

let valid_module_name s =
  let ok = function
    | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '\'' -> true
    | _ -> false
  in
  let rec all i = i >= String.length s || (ok s.[i] && all (i + 1)) in
  s <> "" && (match s.[0] with 'A' .. 'Z' -> true | _ -> false) && all 1

let check_module_name name =
  if name = internal_module then
    Error (Printf.sprintf "%S is used by the generated module" name)
  else if not (valid_module_name name) then
    Error (Printf.sprintf "%S is not a valid module name" name)
  else Ok ()

let sanitize_component s =
  let cleaned =
    String.map
      (function ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9') as c -> c | _ -> '_')
      s
  in
  if cleaned = "" || cleaned = "_" then "__"
  else match cleaned.[0] with 'a' .. 'z' | '_' -> cleaned | _ -> "_" ^ cleaned

let path_to_identifier ?(strip_ext = false) path =
  (* The generated [read] accepts both "x" and "/x", so normalise *)
  let path =
    if path <> "" && path.[0] = '/' then
      String.sub path 1 (String.length path - 1)
    else path
  in
  let path =
    if strip_ext then
      try Filename.chop_extension path with Invalid_argument _ -> path
    else path
  in
  let id =
    String.split_on_char '/' path
    |> List.map sanitize_component
    |> String.concat "__"
  in
  (* Trailing underscore is the usual OCaml escape for a reserved word *)
  if List.mem id reserved then id ^ "_" else id

(* Walk directory and call walkfn on every file that matches extension ext *)
let walk_directory_tree t exts walkfn root_dir =
  (* Recursive directory walker *)
  let rec walk_dir dir t =
    let dh = Unix.opendir dir in
    let rec repeat t =
      match Unix.readdir dh with
      | exception End_of_file -> t
      | "." | ".." -> repeat t
      | f -> (
          let n = Filename.concat dir f in
          if Sys.is_directory n then repeat (walk_dir n t)
          else
            let name = String.sub n 2 (String.length n - 2) in
            (* If extension list is empty then let all through, otherwise white list *)
            match (exts, Filename.extension f) with
            | [], _ -> repeat (walkfn t root_dir name)
            | exts, e
              when e <> ""
                   && List.mem (String.sub e 1 (String.length e - 1)) exts ->
                repeat (walkfn t root_dir name)
            | _ -> repeat t)
    in
    let result = repeat t in
    Unix.closedir dh;
    result
  in
  Unix.chdir root_dir;
  walk_dir "." t

let now () =
  try float_of_string (Sys.getenv "SOURCE_DATE_EPOCH")
  with Not_found -> Unix.gettimeofday ()

let output_generated_by oc binary =
  let t = now () in
  let months =
    [|
      "Jan";
      "Feb";
      "Mar";
      "Apr";
      "May";
      "Jun";
      "Jul";
      "Aug";
      "Sep";
      "Oct";
      "Nov";
      "Dec";
    |]
  in
  let days = [| "Sun"; "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat" |] in
  let time = Unix.gmtime t in
  let date =
    Printf.sprintf "%s, %d %s %d %02d:%02d:%02d GMT" days.(time.Unix.tm_wday)
      time.Unix.tm_mday months.(time.Unix.tm_mon) (time.Unix.tm_year + 1900)
      time.Unix.tm_hour time.Unix.tm_min time.Unix.tm_sec
  in
  Printf.fprintf oc "(* Generated by: %s\n   Creation date: %s *)\n\n" binary
    date

(** Generate a set of MD5 hashed blocks, abort on collision *)
let scan_file t root name =
  let full_name = Filename.concat root name in
  let stats = Unix.stat full_name in
  let size = stats.Unix.st_size in
  let fin = open_in_bin full_name in
  let buf = Buffer.create size in
  Buffer.add_channel buf fin size;
  let s = Buffer.contents buf in
  close_in fin;
  let rev_chunks = ref [] in
  let calc_chunk chunks b =
    let digest = Digest.to_hex (Digest.string b) in
    rev_chunks := digest :: !rev_chunks;
    match SM.find_opt digest chunks with
    | None -> SM.add digest b chunks
    | Some cur ->
        if not (String.equal cur b) then
          failwith ("MD5 hash collision in file " ^ name)
        else chunks
  in
  (* Split the file as a series of chunks, of size up to [block_size] (to
     simulate reading sectors). A non-positive [block_size] keeps each file as a
     single chunk, so that [read] can return the string literal itself. *)
  let sec = if t.block_size > 0 then t.block_size else max size 1 in
  let rec consume idx chunks =
    if idx = size then chunks (* EOF *)
    else if idx + sec < size then
      let chunks = calc_chunk chunks (String.sub s idx sec) in
      consume (idx + sec) chunks
    else
      (* final chunk, short *)
      calc_chunk chunks (String.sub s idx (size - idx))
  in
  (* consume fills !rev_chunks as a side effect, so sequentialise this*)
  let chunks = consume 0 t.chunks in
  let entry =
    {
      chunk_digests = List.rev !rev_chunks;
      file_digest = Digest.(to_hex (string s));
      size = String.length s;
    }
  in
  { t with chunks; files = SM.add name entry t.files }

let output_implementation { chunks; files; _ } oc =
  let pf fmt = Printf.fprintf oc fmt in
  pf "module Internal = struct\n";
  SM.iter (fun name chunk -> pf "  let d_%s = %S\n\n" name chunk) chunks;
  pf "  let file_chunks = function\n";
  SM.iter
    (fun name { chunk_digests; _ } ->
      pf "    | %S | \"/%s\" -> Some [" name (String.escaped name);
      List.iter (pf " d_%s;") chunk_digests;
      pf " ]\n")
    files;
  pf "    | _ -> None\n\n";
  pf "  let file_list = [ ";
  SM.iter (fun name _ -> pf "%S; " name) files;
  pf "]\n";
  pf "end\n"

let output_plain_skeleton_ml { files = file_info; _ } oc =
  let pf fmt = Printf.fprintf oc fmt in
  pf
    {|
let file_list = Internal.file_list

let read name =
  match Internal.file_chunks name with
  | None -> None
  | Some [ c ] -> Some c
  | Some c -> Some (String.concat "" c)

let hash = function
|};
  SM.iter
    (fun name { file_digest; _ } ->
      pf "  | %S | \"/%s\" -> Some \"%s\"\n" name (String.escaped name)
        file_digest)
    file_info;
  pf "  | _ -> None\n\n";
  pf "let size = function\n";
  SM.iter
    (fun name { size; _ } ->
      pf "  | %S | \"/%s\" -> Some %d\n" name (String.escaped name) size)
    file_info;
  pf "  | _ -> None\n"

let output_lwt_skeleton_ml oc =
  let days, ps =
    Ptime.Span.to_d_ps
    @@ Ptime.to_span
         (match Ptime.of_float_s (now ()) with
         | None -> assert false
         | Some x -> x)
  in
  Printf.fprintf oc
    {|
open Lwt

include Mirage_kv_mem

let file_content name =
  match Internal.file_chunks name with
  | None -> Lwt.fail_with ("expected file content, found no blocks " ^ name)
  | Some blocks -> Lwt.return (String.concat "" blocks)

let add store name =
  file_content name >>= fun data ->
  set store (Mirage_kv.Key.v name) data >>= function
  | Ok () -> Lwt.return_unit
  | Error e -> Lwt.fail_with (Fmt.to_to_string pp_write_error e)

let connect () =
  connect ~now:(fun () -> Ptime.v (%d, %LdL)) () >>= fun store ->
  Lwt_list.iter_s (add store) Internal.file_list >|= fun () -> store
|}
    days ps

let output_lwt_skeleton_mli oc =
  Printf.fprintf oc {|include Mirage_kv.RO

val connect : unit -> t Lwt.t
|}

type names = { module_name : string; entries : (string * file_info) SM.t }

(* The mangling is lossy, so distinct paths can collide *)
let names { files; _ } ~module_name ~strip_ext =
  (match check_module_name module_name with
  | Ok () -> ()
  | Error msg -> failwith msg);
  let entries =
    SM.fold
      (fun path info acc ->
        let id = path_to_identifier ~strip_ext path in
        match SM.find_opt id acc with
        | Some (other, _) ->
            failwith
              (Printf.sprintf
                 "identifier collision: %S and %S both map to the OCaml \
                  identifier %S"
                 other path id)
        | None -> SM.add id (path, info) acc)
      files SM.empty
  in
  { module_name; entries }

let output_bindings entries oc =
  let pf fmt = Printf.fprintf oc fmt in
  pf "  module type S = sig\n";
  pf "    type t\n\n";
  SM.iter (fun id _ -> pf "    val %s : t\n" id) entries;
  pf "  end\n\n"

let output_names_sig { module_name; entries } oc =
  let pf fmt = Printf.fprintf oc fmt in
  pf "\nmodule %s : sig\n" module_name;
  pf "  type t\n\n";
  output_bindings entries oc;
  pf
    {|  include S with type t := t

  val name : t -> string
  val path : t -> string
  val contents : t -> string
  val size : t -> int
  val all : t list
end|}

let output_names_ml ({ entries; _ } as names) oc =
  let pf fmt = Printf.fprintf oc fmt in
  output_names_sig names oc;
  pf
    {| = struct
  type t = {
    name : string;
    path : string;
    chunks : string list;
    size : int;
  }

|};
  output_bindings entries oc;
  SM.iter
    (fun id (path, { chunk_digests; size; _ }) ->
      pf "  let %s =\n" id;
      pf "    {\n";
      pf "      name = %S;\n" id;
      pf "      path = %S;\n" path;
      (* Reuse [Internal]'s chunks rather than re-emitting the payload *)
      pf "      chunks = [";
      List.iter (pf " %s.d_%s;" internal_module) chunk_digests;
      pf " ];\n";
      pf "      size = %d;\n" size;
      pf "    }\n\n")
    entries;
  pf
    {|  let name t = t.name
  let path t = t.path
  let contents t = match t.chunks with [ c ] -> c | cs -> String.concat "" cs
  let size t = t.size
|};
  pf "  let all = [ ";
  SM.iter (fun id _ -> pf "%s; " id) entries;
  pf "]\nend\n"

let output_names_mli names oc =
  output_names_sig names oc;
  Printf.fprintf oc "\n"
