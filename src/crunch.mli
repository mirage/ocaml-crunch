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

(** Expose the contents of a directory as a static filesystem. *)

type t
(** The type of a crunch. *)

val make : ?block_size:int -> unit -> t
(** [make ()] is an empty crunch. Files are split into chunks of [block_size]
    bytes (4096 by default). A non-positive [block_size] emits each file as a
    single string literal: chunks are no longer deduplicated, but [read] returns
    the literal without copying it, and the data stays demand-paged from the
    executable instead of being pulled into memory by the GC's root scan. *)

val output_generated_by : out_channel -> string -> unit
(** [output_generated_by oc binary_name] generate a comments saying
    who generates that file. *)

val scan_file : t -> string -> string -> t
(** [scan_file t root file] records the contents of [root]/[file] in [t]. *)

val output_implementation : t -> out_channel -> unit
(** Output the footer. *)

val output_lwt_skeleton_ml : out_channel -> unit
(** Output the Lwt helpers. *)

val output_lwt_skeleton_mli : out_channel -> unit
(** Output the Lwt helpers. *)

val output_plain_skeleton_ml : t -> out_channel -> unit
(** Output a simple skeleton. *)

val walk_directory_tree :
  t -> string list -> (t -> string -> string -> t) -> string -> t
(** [walk t extensions fn root_dir] traverses all the directory
    structure starting from [root_dir] and keeping only the [extensions]
    provided (or do not filter anything if the list is empty). *)

val path_to_identifier : ?strip_ext:bool -> string -> string
(** Mangle a path into an OCaml value identifier, lossily: ["css/app.css"] is
    ["css__app_css"], and ["some/secret.age"] with [~strip_ext] is
    ["some__secret"]. *)

val check_module_name : string -> (unit, string) result
(** [Error reason] if {!output_names_ml} cannot use that module name. *)

type names
(** The bindings {!output_names_ml} will emit, one per crunched file. *)

val names : t -> module_name:string -> strip_ext:bool -> names
(** Mangle every path, before any output is opened.

    @raise Failure on an unusable module name or an identifier collision. *)

val output_names_ml : names -> out_channel -> unit
(** Output a module binding one value per crunched file, with [name], [path],
    [contents], [size] and [all] accessors. Refers to the chunks of
    {!output_implementation}, so must follow it. *)

val output_names_mli : names -> out_channel -> unit
(** The matching signature, for the modes that generate an [.mli]. *)
