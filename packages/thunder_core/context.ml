type t = (int * Obj.t) list

type 'a key = { id : int }

let empty = []

let next_id =
  let counter = ref 0 in
  fun () ->
    incr counter;
    !counter

let key () = { id = next_id () }

let add ctx key value =
  let without_key = List.filter (fun (id, _) -> id <> key.id) ctx in
  (key.id, Obj.repr value) :: without_key

let get ctx key =
  match List.assoc_opt key.id ctx with
  | None -> None
  | Some value -> Some (Obj.obj value)
