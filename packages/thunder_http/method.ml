type t =
  | GET
  | POST
  | PUT
  | PATCH
  | DELETE
  | HEAD
  | OPTIONS

let equal = ( = )

let normalize s = String.uppercase_ascii (String.trim s)

let of_string s =
  match normalize s with
  | "GET" -> Some GET
  | "POST" -> Some POST
  | "PUT" -> Some PUT
  | "PATCH" -> Some PATCH
  | "DELETE" -> Some DELETE
  | "HEAD" -> Some HEAD
  | "OPTIONS" -> Some OPTIONS
  | _ -> None

let to_string = function
  | GET -> "GET"
  | POST -> "POST"
  | PUT -> "PUT"
  | PATCH -> "PATCH"
  | DELETE -> "DELETE"
  | HEAD -> "HEAD"
  | OPTIONS -> "OPTIONS"
