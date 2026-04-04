module Body = struct
  type t = Text of string | Bytes of bytes

  let text value = Text value
  let bytes value = Bytes value
end

type t = { status : Status.t; headers : Headers.t; body : Body.t }

let status response = response.status
let headers response = response.headers
let body response = response.body

let body_string response =
  match response.body with Body.Text value -> value | Body.Bytes value -> Bytes.to_string value

let with_status response status = { response with status }
let with_header response name value = { response with headers = Headers.set response.headers name value }
let add_header response name value = { response with headers = Headers.add response.headers name value }

let with_cookie response cookie =
  add_header response "set-cookie" (Cookie.serialize_set cookie)

let empty ?(status = Status.ok) () = { status; headers = Headers.empty; body = Body.Text "" }

let with_content_type content_type response = with_header response "content-type" content_type

let text ?(status = Status.ok) body =
  empty ~status () |> with_content_type "text/plain; charset=utf-8" |> fun r ->
  { r with body = Body.Text body }

let bytes ?(status = Status.ok) ?(content_type = "application/octet-stream") body =
  empty ~status () |> with_content_type content_type |> fun r ->
  { r with body = Body.Bytes body }

let html ?(status = Status.ok) body =
  empty ~status () |> with_content_type "text/html; charset=utf-8" |> fun r ->
  { r with body = Body.Text body }

let json ?(status = Status.ok) body =
  empty ~status () |> with_content_type "application/json" |> fun r ->
  { r with body = Body.Text body }

let redirect ?(status = Status.found) location =
  empty ~status ()
  |> fun response -> with_header response "location" location
  |> with_content_type "text/plain; charset=utf-8"
