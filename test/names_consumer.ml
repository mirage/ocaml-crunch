(* Re-export the bindings while hiding the accessors, as a wrapper library would *)
module Narrow : T1_names.Name.S with type t = T1_names.Name.t = T1_names.Name

(* [--names-strip-ext] drops the extension, so [a.ext] is [a] here *)
let () = ignore (T1_names_strip.Directory.path T1_names_strip.Directory.a)

let () =
  let open T1_names.Name in
  assert (path a_ext = "a.ext");
  assert (name a_ext = "a_ext");
  assert (contents a_ext = "foo\n");
  assert (size a_ext = 4);
  assert (path e__f = "e/f");
  assert (contents e__f = "hallohallo\n");
  assert (size d = 12300);
  assert (String.length (contents d) = 12300);
  assert (List.length all = 5);
  List.iter (fun n -> assert (T1_names.read (path n) = Some (contents n))) all;
  assert (Narrow.a_ext == a_ext);
  print_endline "names_consumer: ok"

let () =
  let id = Crunch.path_to_identifier in
  assert (id "a.ext" = "a_ext");
  assert (id "e/f" = "e__f");
  assert (id "/e/f" = "e__f");
  assert (id ~strip_ext:true "some/secret.age" = "some__secret");
  List.iter
    (fun n -> assert (id (T1_names.Name.path n) = T1_names.Name.name n))
    T1_names.Name.all
