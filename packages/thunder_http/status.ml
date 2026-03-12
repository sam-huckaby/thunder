type t = { code : int; reason : string }

let make code reason = { code; reason }
let code s = s.code
let reason s = s.reason

let ok = make 200 "OK"
let created = make 201 "Created"
let no_content = make 204 "No Content"
let moved_permanently = make 301 "Moved Permanently"
let found = make 302 "Found"
let bad_request = make 400 "Bad Request"
let not_found = make 404 "Not Found"
let method_not_allowed = make 405 "Method Not Allowed"
let internal_server_error = make 500 "Internal Server Error"
