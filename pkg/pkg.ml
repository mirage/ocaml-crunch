#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  Pkg.describe "crunch" @@ fun c ->
  Ok [ Pkg.mllib "lib/crunch.mllib";
       Pkg.bin "lib/main" ~dst:"ocaml-crunch";
       Pkg.test "test/test" ]
