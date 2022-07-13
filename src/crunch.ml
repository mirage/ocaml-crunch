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

type file_info = { chunk_digests : string list; file_digest : string }
type t = string SM.t * file_info SM.t

let make () = (SM.empty, SM.empty)

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
            | exts, e when e <> "" && List.mem e exts ->
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
let scan_file (chunk_info, file_info) root name =
  let full_name = Filename.concat root name in
  let stats = Unix.stat full_name in
  let size = stats.Unix.st_size in
  let fin = open_in_bin full_name in
  let buf = Buffer.create size in
  Buffer.add_channel buf fin size;
  let s = Buffer.contents buf in
  close_in fin;
  let rev_chunks = ref [] in
  let calc_chunk chunk_info b =
    let digest = Digest.to_hex (Digest.string b) in
    rev_chunks := digest :: !rev_chunks;
    match SM.find_opt digest chunk_info with
    | None -> SM.add digest b chunk_info
    | Some cur ->
        if not (String.equal cur b) then
          failwith ("MD5 hash collision in file " ^ name)
        else chunk_info
  in
  (* Split the file as a series of chunks, of size up to 4096 (to simulate reading sectors) *)
  let sec = 4096 in
  (* sector size *)
  let rec consume idx chunk_info =
    if idx = size then chunk_info (* EOF *)
    else if idx + sec < size then
      let chunk_info' = calc_chunk chunk_info (String.sub s idx sec) in
      consume (idx + sec) chunk_info'
    else
      (* final chunk, short *)
      calc_chunk chunk_info (String.sub s idx (size - idx))
  in
  (* consume fills !rev_chunks as a side effect, so sequentialise this*)
  let ci = consume 0 chunk_info in
  let entry =
    {
      chunk_digests = List.rev !rev_chunks;
      file_digest = Digest.(to_hex (string s));
    }
  in
  (ci, SM.add name entry file_info)

let output_implementation (chunk_info, file_info) oc =
  let pf fmt = Printf.fprintf oc fmt in
  pf "module Internal = struct\n";
  SM.iter (fun name chunk -> pf "  let d_%s = %S\n\n" name chunk) chunk_info;
  pf "  let file_chunks = function\n";
  SM.iter
    (fun name { chunk_digests; _ } ->
      pf "    | %S | \"/%s\" -> Some [" name (String.escaped name);
      List.iter (pf " d_%s;") chunk_digests;
      pf " ]\n")
    file_info;
  pf "    | _ -> None\n\n";
  pf "  let file_list = [ ";
  SM.iter (fun name _ -> pf "%S; " name) file_info;
  pf "]\n";
  pf "end\n"

let output_plain_skeleton_ml (_, file_info) oc =
  let pf fmt = Printf.fprintf oc fmt in
  pf
    {|
let file_list = Internal.file_list

let read name =
  match Internal.file_chunks name with
  | None -> None
  | Some c -> Some (String.concat "" c)

let hash = function
|};
  SM.iter
    (fun name { file_digest; _ } ->
      pf "  | %S | \"/%s\" -> Some \"%s\"\n" name (String.escaped name)
        file_digest)
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

module C = struct
  let now_d_ps () = (%d, %LdL)
  let current_tz_offset_s () = None
  let period_d_ps () = None
end

include Mirage_kv_mem.Make (C)

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
  connect () >>= fun store ->
  Lwt_list.iter_s (add store) Internal.file_list >|= fun () -> store
|}
    days ps

let output_lwt_skeleton_mli oc =
  Printf.fprintf oc {|include Mirage_kv.RO

val connect : unit -> t Lwt.t
|}
