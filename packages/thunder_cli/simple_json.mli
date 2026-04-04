type value =
  | Null
  | Bool of bool
  | Number of string
  | String of string
  | Array of value list
  | Object of (string * value) list

val parse : string -> (value, string) result
val to_string : value -> string
val object_field : string -> value -> value option
val string_field : string -> value -> string option
val bool_field : string -> value -> bool option
val array_field : string -> value -> value list option
