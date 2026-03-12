type t = (string * string) list

let empty = []

let hex_value = function
  | '0' .. '9' as c -> Char.code c - Char.code '0'
  | 'a' .. 'f' as c -> 10 + (Char.code c - Char.code 'a')
  | 'A' .. 'F' as c -> 10 + (Char.code c - Char.code 'A')
  | _ -> -1

let decode_component s =
  let len = String.length s in
  let buf = Buffer.create len in
  let rec loop i =
    if i >= len then ()
    else
      match s.[i] with
      | '+' ->
          Buffer.add_char buf ' ';
          loop (i + 1)
      | '%' when i + 2 < len ->
          let hi = hex_value s.[i + 1] in
          let lo = hex_value s.[i + 2] in
          if hi >= 0 && lo >= 0 then (
            Buffer.add_char buf (Char.chr ((hi lsl 4) lor lo));
            loop (i + 3))
          else (
            Buffer.add_char buf s.[i];
            loop (i + 1))
      | c ->
          Buffer.add_char buf c;
          loop (i + 1)
  in
  loop 0;
  Buffer.contents buf

let split_once s ch =
  match String.index_opt s ch with
  | None -> (s, "")
  | Some idx ->
      let left = String.sub s 0 idx in
      let right = String.sub s (idx + 1) (String.length s - idx - 1) in
      (left, right)

let parse raw =
  let trimmed =
    if String.length raw > 0 && raw.[0] = '?' then
      String.sub raw 1 (String.length raw - 1)
    else raw
  in
  if trimmed = "" then empty
  else
    String.split_on_char '&' trimmed
    |> List.filter (fun p -> p <> "")
    |> List.map (fun pair ->
           let k, v = split_once pair '=' in
           (decode_component k, decode_component v))

let get t key =
  t |> List.find_opt (fun (k, _) -> k = key) |> Option.map snd

let get_all t key =
  t |> List.filter_map (fun (k, v) -> if k = key then Some v else None)

let to_list t = t
