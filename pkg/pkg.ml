#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  Pkg.describe "crunch" @@ fun c ->
  Ok [ Pkg.mllib "src/crunch.mllib";
       Pkg.bin "src/main" ~dst:"ocaml-crunch";
       Pkg.test "test/test" ]
