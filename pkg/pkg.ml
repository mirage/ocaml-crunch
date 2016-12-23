#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  let opams = [ Pkg.opam_file "opam" ~lint_deps_excluding:(Some ["mirage-types-lwt"]) ] in
  Pkg.describe ~opams "crunch" @@ fun c ->
  Ok [ Pkg.mllib "src/crunch.mllib";
       Pkg.bin "src/main" ~dst:"ocaml-crunch";
       Pkg.test "test/test" ]
