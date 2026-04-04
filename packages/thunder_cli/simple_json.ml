type value =
  | Null
  | Bool of bool
  | Number of string
  | String of string
  | Array of value list
  | Object of (string * value) list

let object_field key = function
  | Object fields -> List.assoc_opt key fields
  | _ -> None

let string_field key value =
  match object_field key value with Some (String s) -> Some s | _ -> None

let bool_field key value =
  match object_field key value with Some (Bool b) -> Some b | _ -> None

let array_field key value =
  match object_field key value with Some (Array items) -> Some items | _ -> None

let escape_string value =
  let buffer = Buffer.create (String.length value + 8) in
  String.iter
    (function
      | '"' -> Buffer.add_string buffer "\\\""
      | '\\' -> Buffer.add_string buffer "\\\\"
      | '\n' -> Buffer.add_string buffer "\\n"
      | '\r' -> Buffer.add_string buffer "\\r"
      | '\t' -> Buffer.add_string buffer "\\t"
      | c -> Buffer.add_char buffer c)
    value;
  Buffer.contents buffer

let rec to_string = function
  | Null -> "null"
  | Bool true -> "true"
  | Bool false -> "false"
  | Number value -> value
  | String value -> "\"" ^ escape_string value ^ "\""
  | Array values -> "[" ^ String.concat "," (List.map to_string values) ^ "]"
  | Object fields ->
      let render (key, value) = to_string (String key) ^ ":" ^ to_string value in
      "{" ^ String.concat "," (List.map render fields) ^ "}"

type parser = { text : string; mutable index : int }

let make_parser text = { text; index = 0 }

let current parser =
  if parser.index >= String.length parser.text then None else Some parser.text.[parser.index]

let advance parser = parser.index <- parser.index + 1

let rec skip_ws parser =
  match current parser with
  | Some (' ' | '\n' | '\r' | '\t') ->
      advance parser;
      skip_ws parser
  | _ -> ()

let error parser message =
  Error (Printf.sprintf "JSON parse error at index %d: %s" parser.index message)

let expect_char parser expected =
  skip_ws parser;
  match current parser with
  | Some c when c = expected ->
      advance parser;
      Ok ()
  | Some c -> error parser (Printf.sprintf "expected '%c', got '%c'" expected c)
  | None -> error parser (Printf.sprintf "expected '%c', got end of input" expected)

let parse_literal parser literal value =
  let len = String.length literal in
  if parser.index + len > String.length parser.text then error parser ("expected " ^ literal)
  else if String.sub parser.text parser.index len = literal then (
    parser.index <- parser.index + len;
    Ok value)
  else error parser ("expected " ^ literal)

let parse_number parser =
  let start = parser.index in
  let is_number_char = function
    | '0' .. '9' | '-' | '+' | '.' | 'e' | 'E' -> true
    | _ -> false
  in
  let rec consume () =
    match current parser with
    | Some c when is_number_char c ->
        advance parser;
        consume ()
    | _ ->
        if parser.index = start then error parser "expected number"
        else Ok (Number (String.sub parser.text start (parser.index - start)))
  in
  consume ()

let parse_string parser =
  let buffer = Buffer.create 32 in
  match expect_char parser '"' with
  | Error _ as e -> e
  | Ok () ->
      let rec loop () =
        match current parser with
        | None -> error parser "unterminated string"
        | Some '"' ->
            advance parser;
            Ok (String (Buffer.contents buffer))
        | Some '\\' ->
            advance parser;
            begin
              match current parser with
              | None -> error parser "unterminated escape"
              | Some escaped ->
                  (match escaped with
                  | '"' -> Buffer.add_char buffer '"'
                  | '\\' -> Buffer.add_char buffer '\\'
                  | 'n' -> Buffer.add_char buffer '\n'
                  | 'r' -> Buffer.add_char buffer '\r'
                  | 't' -> Buffer.add_char buffer '\t'
                  | c -> Buffer.add_char buffer c);
                  advance parser;
                  loop ()
            end
        | Some c ->
            Buffer.add_char buffer c;
            advance parser;
            loop ()
      in
      loop ()

let rec parse_value parser =
  skip_ws parser;
  match current parser with
  | Some '"' -> parse_string parser
  | Some '{' -> parse_object parser
  | Some '[' -> parse_array parser
  | Some 't' -> parse_literal parser "true" (Bool true)
  | Some 'f' -> parse_literal parser "false" (Bool false)
  | Some 'n' -> parse_literal parser "null" Null
  | Some ('0' .. '9' | '-') -> parse_number parser
  | Some c -> error parser (Printf.sprintf "unexpected character '%c'" c)
  | None -> error parser "unexpected end of input"

and parse_array parser =
  match expect_char parser '[' with
  | Error _ as e -> e
  | Ok () ->
      skip_ws parser;
      if current parser = Some ']' then (
        advance parser;
        Ok (Array []))
      else
        let rec loop acc =
          match parse_value parser with
          | Error _ as e -> e
          | Ok value ->
              skip_ws parser;
              (match current parser with
              | Some ',' ->
                  advance parser;
                  loop (value :: acc)
              | Some ']' ->
                  advance parser;
                  Ok (Array (List.rev (value :: acc)))
              | Some c -> error parser (Printf.sprintf "unexpected character '%c' in array" c)
              | None -> error parser "unterminated array")
        in
        loop []

and parse_object parser =
  match expect_char parser '{' with
  | Error _ as e -> e
  | Ok () ->
      skip_ws parser;
      if current parser = Some '}' then (
        advance parser;
        Ok (Object []))
      else
        let rec loop acc =
          match parse_string parser with
          | Error _ as e -> e
          | Ok (String key) ->
              (match expect_char parser ':' with
              | Error _ as e -> e
              | Ok () ->
                  (match parse_value parser with
                  | Error _ as e -> e
                  | Ok value ->
                      skip_ws parser;
                      match current parser with
                      | Some ',' ->
                          advance parser;
                          loop ((key, value) :: acc)
                      | Some '}' ->
                          advance parser;
                          Ok (Object (List.rev ((key, value) :: acc)))
                      | Some c -> error parser (Printf.sprintf "unexpected character '%c' in object" c)
                      | None -> error parser "unterminated object"))
          | Ok _ -> error parser "object keys must be strings"
        in
        loop []

let parse text =
  let parser = make_parser text in
  match parse_value parser with
  | Error _ as e -> e
  | Ok value ->
      skip_ws parser;
      if parser.index = String.length parser.text then Ok value
      else error parser "trailing characters after JSON value"
