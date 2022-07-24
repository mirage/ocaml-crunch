(* poor-man reimplementation of realpath, from OPAM's system library *)
let realpath p =
  let getchdir s =
    let p = Sys.getcwd () in
    Sys.chdir s;
    p
  in
  let normalize s = getchdir (getchdir s) in
  if Filename.is_relative p then
    match Sys.is_directory p with
    | exception Sys_error _ -> p
    | true -> normalize p
    | false -> (
        let dir = normalize (Filename.dirname p) in
        match Filename.basename p with
        | "." -> dir
        | base -> Filename.concat dir base)
  else p
