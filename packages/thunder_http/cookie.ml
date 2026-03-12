type same_site = Strict | Lax | None_

type set = {
  name : string;
  value : string;
  path : string option;
  domain : string option;
  max_age : int option;
  expires : string option;
  secure : bool;
  http_only : bool;
  same_site : same_site option;
}

let make_set ?path ?domain ?max_age ?expires ?(secure = false)
    ?(http_only = false) ?same_site name value =
  { name; value; path; domain; max_age; expires; secure; http_only; same_site }

let trim = String.trim

let parse_pair piece =
  match String.split_on_char '=' piece with
  | [] -> None
  | [ key ] -> Some (trim key, "")
  | key :: rest -> Some (trim key, trim (String.concat "=" rest))

let parse_request_header header =
  String.split_on_char ';' header
  |> List.filter_map parse_pair
  |> List.filter (fun (k, _) -> k <> "")

let get cookies name =
  cookies |> List.find_opt (fun (k, _) -> k = name) |> Option.map snd

let serialize_set cookie =
  let parts = ref [ cookie.name ^ "=" ^ cookie.value ] in
  let add_opt label value_opt =
    match value_opt with
    | None -> ()
    | Some v -> parts := !parts @ [ label ^ "=" ^ v ]
  in
  add_opt "Path" cookie.path;
  add_opt "Domain" cookie.domain;
  (match cookie.max_age with
  | None -> ()
  | Some age -> parts := !parts @ [ "Max-Age=" ^ string_of_int age ]);
  add_opt "Expires" cookie.expires;
  if cookie.secure then parts := !parts @ [ "Secure" ];
  if cookie.http_only then parts := !parts @ [ "HttpOnly" ];
  (match cookie.same_site with
  | None -> ()
  | Some Strict -> parts := !parts @ [ "SameSite=Strict" ]
  | Some Lax -> parts := !parts @ [ "SameSite=Lax" ]
  | Some None_ -> parts := !parts @ [ "SameSite=None" ]);
  String.concat "; " !parts
