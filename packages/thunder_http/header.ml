type t = { name : string; value : string }

let normalized_name s = String.lowercase_ascii (String.trim s)

let make name value = { name = normalized_name name; value }
let name h = h.name
let value h = h.value
