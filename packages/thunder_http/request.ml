type t = {
  meth : Method.t;
  url : string;
  path : string;
  headers : Headers.t;
  query : Query.t;
  cookies : (string * string) list;
  params : (string * string) list;
  body : string;
  context : Thunder_core.Context.t;
}

let split_once s ch =
  match String.index_opt s ch with
  | None -> (s, "")
  | Some idx ->
      let left = String.sub s 0 idx in
      let right = String.sub s (idx + 1) (String.length s - idx - 1) in
      (left, right)

let path_and_query_of_url url =
  let after_scheme =
    match String.index_opt url ':' with
    | None -> url
    | Some colon_idx ->
        if colon_idx + 2 < String.length url then (
          if String.sub url (colon_idx + 1) 2 = "//" then
            let start =
              match String.index_from_opt url (colon_idx + 3) '/' with
              | None -> String.length url
              | Some idx -> idx
            in
            String.sub url start (String.length url - start)
          else url)
        else url
  in
  let candidate = if after_scheme = "" then "/" else after_scheme in
  if String.length candidate > 0 && candidate.[0] = '/' then split_once candidate '?'
  else split_once ("/" ^ candidate) '?'

let make ~meth ~url ~headers ~body ?(context = Thunder_core.Context.empty) () =
  let path, query_raw = path_and_query_of_url url in
  let cookies =
    match Headers.get headers "cookie" with
    | None -> []
    | Some value -> Cookie.parse_request_header value
  in
  {
    meth;
    url;
    path;
    headers;
    query = Query.parse query_raw;
    cookies;
    params = [];
    body;
    context;
  }

let with_param req key value = { req with params = (key, value) :: req.params }
let with_context req context = { req with context }
let context_map req = req.context

let meth req = req.meth
let url req = req.url
let path req = req.path

let header req name = Headers.get req.headers name
let headers req = req.headers

let query req name = Query.get req.query name
let queries req name = Query.get_all req.query name

let cookie req name = Cookie.get req.cookies name
let param req name = req.params |> List.find_opt (fun (k, _) -> k = name) |> Option.map snd

let body_string req = req.body
let body_bytes req = Bytes.of_string req.body

let context req key = Thunder_core.Context.get req.context key
