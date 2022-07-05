(* poor-man reimplementation of realpath, from OPAM's system library *)
let realpath p =
  let getchdir s =
    let p = Sys.getcwd () in
    Sys.chdir s;
    p
  in
  let normalize s = getchdir (getchdir s) in
  if Filename.is_relative p then
    match (try Some (Sys.is_directory p) with Sys_error _ -> None) with
    | None -> p
    | Some true -> normalize p
    | Some false ->
       let dir = normalize (Filename.dirname p) in
       match Filename.basename p with
       | "."  -> dir
       | base -> Filename.concat dir base
  else p
