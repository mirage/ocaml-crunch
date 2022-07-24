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

val make : unit -> t
(** [make ()] is an empty crunch. *)

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
