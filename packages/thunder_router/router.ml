type segment = Static of string | Param of string

type route = {
  meth : Method.t;
  segments : segment list;
  handler : Handler.t;
}

type t = route list

let split_path path =
  let trimmed = String.trim path in
  let raw = if trimmed = "" then "/" else trimmed in
  if raw = "/" then []
  else
    raw
    |> String.split_on_char '/'
    |> List.filter (fun part -> part <> "")

let parse_segment raw =
  if String.length raw > 0 && raw.[0] = ':' then
    let name = String.sub raw 1 (String.length raw - 1) in
    if name = "" then None else Some (Param name)
  else Some (Static raw)

let parse_pattern pattern =
  let rec loop acc = function
    | [] -> Some (List.rev acc)
    | raw :: rest ->
        (match parse_segment raw with
        | None -> None
        | Some seg -> loop (seg :: acc) rest)
  in
  loop [] (split_path pattern)

let make_route meth pattern handler =
  match parse_pattern pattern with
  | Some segments -> { meth; segments; handler }
  | None -> invalid_arg ("Invalid route pattern: " ^ pattern)

let get pattern handler = make_route Method.GET pattern handler
let post pattern handler = make_route Method.POST pattern handler
let put pattern handler = make_route Method.PUT pattern handler
let patch pattern handler = make_route Method.PATCH pattern handler
let delete pattern handler = make_route Method.DELETE pattern handler

let make routes = routes

let match_route route req =
  if not (Method.equal route.meth (Request.meth req)) then None
  else
    let path_segments = split_path (Request.path req) in
    if List.length path_segments <> List.length route.segments then None
    else
      let rec collect segments values params =
        match (segments, values) with
        | [], [] -> Some params
        | Static expected :: seg_rest, actual :: val_rest ->
            if expected = actual then collect seg_rest val_rest params else None
        | Param name :: seg_rest, actual :: val_rest ->
            collect seg_rest val_rest ((name, actual) :: params)
        | _ -> None
      in
      collect route.segments path_segments []

let static_score route =
  List.fold_left
    (fun count segment -> match segment with Static _ -> count + 1 | Param _ -> count)
    0 route.segments

let dispatch t req =
  let candidates =
    List.filter_map
      (fun route ->
        match match_route route req with
        | None -> None
        | Some params -> Some (route, params))
      t
  in
  match candidates with
  | [] -> (None, req)
  | _ ->
      let best_route, params =
        List.fold_left
          (fun ((best_route, _best_params) as best) (route, params) ->
            if static_score route > static_score best_route then (route, params) else best)
          (List.hd candidates) (List.tl candidates)
      in
      let enriched_req =
        List.fold_left (fun acc (k, v) -> Request.with_param acc k v) req params
      in
      (Some best_route.handler, enriched_req)

let router routes =
  let compiled = make routes in
  Handler.handler_async (fun req ->
      match dispatch compiled req with
      | Some handler, enriched -> Handler.run_async handler enriched
      | None, _ -> Async.return (Response.text ~status:Status.not_found "Not Found"))
