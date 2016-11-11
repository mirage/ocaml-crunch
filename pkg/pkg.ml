#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  let opams = [ Pkg.opam_file "opam" ~lint_deps_excluding:(Some ["mirage-types-lwt"]) ] in
  Pkg.describe ~opams "crunch" @@ fun c ->
  Ok [ Pkg.mllib "lib/crunch.mllib";
       Pkg.bin "lib/main" ~dst:"ocaml-crunch";
       Pkg.test "test/test" ]
