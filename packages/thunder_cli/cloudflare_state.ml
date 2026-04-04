type managed_resource = {
  kind : string;
  binding : string;
  name : string option;
  identifier : string option;
  managed : bool;
}

type worker_bootstrap = {
  script_name : string option;
  bootstrapped : bool;
  last_deploy_at : string option;
}

type t = {
  account_id : string option;
  worker : worker_bootstrap option;
  resources : managed_resource list;
  last_provision_at : string option;
  last_status_at : string option;
}

let empty =
  {
    account_id = None;
    worker = None;
    resources = [];
    last_provision_at = None;
    last_status_at = None;
  }

let default_path () = Filename.concat ".thunder" "cloudflare_resources.json"

let read_file path =
  let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let ensure_parent_dir path =
  let dir = Filename.dirname path in
  if dir <> "." && not (Sys.file_exists dir) then Unix.mkdir dir 0o755

let string_opt key value = Simple_json.string_field key value
let bool key value = Option.value (Simple_json.bool_field key value) ~default:false

let managed_resource_of_json = function
  | Simple_json.Object _ as value ->
      Ok
        {
          kind = Option.value (string_opt "kind" value) ~default:"unknown";
          binding = Option.value (string_opt "binding" value) ~default:"";
          name = string_opt "name" value;
          identifier = string_opt "identifier" value;
          managed = bool "managed" value;
        }
  | _ -> Error "Cloudflare state resource entry must be an object"

let worker_of_json = function
  | Simple_json.Object _ as value ->
      Ok
        {
          script_name = string_opt "script_name" value;
          bootstrapped = bool "bootstrapped" value;
          last_deploy_at = string_opt "last_deploy_at" value;
        }
  | _ -> Error "Cloudflare state worker entry must be an object"

let resources_of_json = function
  | Some (Simple_json.Array items) ->
      let rec loop acc = function
        | [] -> Ok (List.rev acc)
        | item :: rest ->
            (match managed_resource_of_json item with
            | Ok resource -> loop (resource :: acc) rest
            | Error _ as e -> e)
      in
      loop [] items
  | Some _ -> Error "Cloudflare state resources must be an array"
  | None -> Ok []

let read ~path =
  if not (Sys.file_exists path) then Error ("Missing Cloudflare state: " ^ path)
  else
    match Simple_json.parse (read_file path) with
    | Error msg -> Error msg
    | Ok (Simple_json.Object _ as json) ->
        (match resources_of_json (Simple_json.object_field "resources" json) with
        | Error _ as e -> e
        | Ok resources ->
            let worker =
              match Simple_json.object_field "worker" json with
              | None | Some Simple_json.Null -> Ok None
              | Some value ->
                  (match worker_of_json value with Ok item -> Ok (Some item) | Error _ as e -> e)
            in
            (match worker with
            | Error _ as e -> e
            | Ok worker ->
                Ok
                  {
                    account_id = string_opt "account_id" json;
                    worker;
                    resources;
                    last_provision_at = string_opt "last_provision_at" json;
                    last_status_at = string_opt "last_status_at" json;
                  }))
    | Ok _ -> Error "Cloudflare state root must be an object"

let read_if_exists ~path =
  if Sys.file_exists path then match read ~path with Ok state -> state | Error _ -> empty else empty

let resource_to_json resource =
  Simple_json.Object
    [ "kind", Simple_json.String resource.kind;
      "binding", Simple_json.String resource.binding;
      ( "name",
        match resource.name with Some value -> Simple_json.String value | None -> Simple_json.Null );
      ( "identifier",
        match resource.identifier with
        | Some value -> Simple_json.String value
        | None -> Simple_json.Null );
      "managed", Simple_json.Bool resource.managed ]

let worker_to_json worker =
  Simple_json.Object
    [ ( "script_name",
        match worker.script_name with Some value -> Simple_json.String value | None -> Simple_json.Null );
      "bootstrapped", Simple_json.Bool worker.bootstrapped;
      ( "last_deploy_at",
        match worker.last_deploy_at with
        | Some value -> Simple_json.String value
        | None -> Simple_json.Null ) ]

let to_json state =
  Simple_json.Object
    [ ( "account_id",
        match state.account_id with Some value -> Simple_json.String value | None -> Simple_json.Null );
      ( "worker",
        match state.worker with Some worker -> worker_to_json worker | None -> Simple_json.Null );
      "resources", Simple_json.Array (List.map resource_to_json state.resources);
      ( "last_provision_at",
        match state.last_provision_at with
        | Some value -> Simple_json.String value
        | None -> Simple_json.Null );
      ( "last_status_at",
        match state.last_status_at with
        | Some value -> Simple_json.String value
        | None -> Simple_json.Null ) ]

let write ~path state =
  try
    ensure_parent_dir path;
    let oc = open_out_bin path in
    Fun.protect ~finally:(fun () -> close_out_noerr oc)
      (fun () -> output_string oc (Simple_json.to_string (to_json state) ^ "\n"));
    Ok ()
  with Sys_error msg -> Error msg
