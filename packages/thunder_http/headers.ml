type t = (string * string) list

let empty = []

let normalize = Header.normalized_name

let of_list headers =
  List.map (fun (name, value) -> (normalize name, value)) headers

let to_list headers = headers

let get headers name =
  let target = normalize name in
  headers
  |> List.find_opt (fun (candidate, _) -> candidate = target)
  |> Option.map snd

let get_all headers name =
  let target = normalize name in
  headers
  |> List.filter_map (fun (candidate, value) ->
         if candidate = target then Some value else None)

let remove headers name =
  let target = normalize name in
  List.filter (fun (candidate, _) -> candidate <> target) headers

let add headers name value = headers @ [ (normalize name, value) ]
let set headers name value = add (remove headers name) name value
