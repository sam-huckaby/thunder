type compile_target = Js | Wasm

type cloudflare_mode = Dev_test

type cloudflare_named_binding = {
  binding : string;
  name : string;
}

type cloudflare_r2_binding = {
  binding : string;
  bucket : string;
}

type cloudflare_ai_binding = { binding : string }

type cloudflare_durable_object_binding = {
  binding : string;
  class_name : string;
}

type cloudflare_service_binding = {
  binding : string;
  service : string;
}

type cloudflare_resources = {
  kv : cloudflare_named_binding list;
  r2 : cloudflare_r2_binding list;
  d1 : cloudflare_named_binding list;
  queues : cloudflare_named_binding list;
  ai : cloudflare_ai_binding list;
  durable_objects : cloudflare_durable_object_binding list;
  services : cloudflare_service_binding list;
}

type cloudflare = {
  mode : cloudflare_mode option;
  bootstrap_worker : bool option;
  resources : cloudflare_resources;
}

let compile_target_to_string = function Js -> "js" | Wasm -> "wasm"

let compile_target_of_string = function
  | "js" -> Ok Js
  | "wasm" -> Ok Wasm
  | value ->
      Error
        ("Unsupported compile_target: " ^ value
       ^ ". Expected one of: js, wasm")

type t = {
  compile_target : compile_target option;
  app_module : string option;
  worker_entry_path : string option;
  compiled_runtime_path : string option;
  wrangler_template_path : string option;
  deploy_dir : string option;
  framework_root : string option;
  cloudflare : cloudflare option;
}

let empty =
  {
    compile_target = None;
    app_module = None;
    worker_entry_path = None;
    compiled_runtime_path = None;
    wrangler_template_path = None;
    deploy_dir = None;
    framework_root = None;
    cloudflare = None;
  }

let default_path () = "thunder.json"

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let cloudflare_mode_of_string = function
  | "dev_test" -> Ok Dev_test
  | value -> Error ("Unsupported cloudflare.mode: " ^ value ^ ". Expected: dev_test")

let parse_named_binding ~field_name ~name_field = function
  | Simple_json.Object _ as value ->
      (match (Simple_json.string_field field_name value, Simple_json.string_field name_field value) with
      | Some binding, Some name -> Ok { binding; name }
      | _ -> Error ("Cloudflare resource entry must include '" ^ field_name ^ "' and '" ^ name_field ^ "'"))
  | _ -> Error "Cloudflare resource entry must be an object"

let parse_ai_binding = function
  | Simple_json.Object _ as value ->
      (match Simple_json.string_field "binding" value with
      | Some binding -> Ok { binding }
      | None -> Error "Cloudflare AI entry must include 'binding'")
  | _ -> Error "Cloudflare AI entry must be an object"

let parse_r2_binding = function
  | Simple_json.Object _ as value ->
      (match (Simple_json.string_field "binding" value, Simple_json.string_field "bucket" value) with
      | Some binding, Some bucket -> Ok { binding; bucket }
      | _ -> Error "Cloudflare R2 entry must include 'binding' and 'bucket'")
  | _ -> Error "Cloudflare R2 entry must be an object"

let parse_durable_object_binding = function
  | Simple_json.Object _ as value ->
      (match (Simple_json.string_field "binding" value, Simple_json.string_field "class_name" value) with
      | Some binding, Some class_name -> Ok { binding; class_name }
      | _ -> Error "Cloudflare durable object entry must include 'binding' and 'class_name'")
  | _ -> Error "Cloudflare durable object entry must be an object"

let parse_service_binding = function
  | Simple_json.Object _ as value ->
      (match (Simple_json.string_field "binding" value, Simple_json.string_field "service" value) with
      | Some binding, Some service -> Ok { binding; service }
      | _ -> Error "Cloudflare service entry must include 'binding' and 'service'")
  | _ -> Error "Cloudflare service entry must be an object"

let parse_list parse_one values =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | item :: rest ->
        (match parse_one item with Ok parsed -> loop (parsed :: acc) rest | Error _ as e -> e)
  in
  loop [] values

let parse_resources json =
  let get_array name = match Simple_json.array_field name json with Some values -> values | None -> [] in
  match
    parse_list (parse_named_binding ~field_name:"binding" ~name_field:"name") (get_array "kv")
  with
  | Error _ as e -> e
  | Ok kv ->
      (match parse_list parse_r2_binding (get_array "r2") with
      | Error _ as e -> e
      | Ok r2 ->
          (match parse_list (parse_named_binding ~field_name:"binding" ~name_field:"name") (get_array "d1") with
          | Error _ as e -> e
          | Ok d1 ->
              (match parse_list (parse_named_binding ~field_name:"binding" ~name_field:"queue") (get_array "queues") with
              | Error _ as e -> e
              | Ok queues ->
                  (match parse_list parse_ai_binding (get_array "ai") with
                  | Error _ as e -> e
                  | Ok ai ->
                      (match parse_list parse_durable_object_binding (get_array "durable_objects") with
                      | Error _ as e -> e
                      | Ok durable_objects ->
                          (match parse_list parse_service_binding (get_array "services") with
                          | Error _ as e -> e
                          | Ok services ->
                              Ok { kv; r2; d1; queues; ai; durable_objects; services }))))))

let parse_cloudflare = function
  | Simple_json.Object _ as value ->
      let mode =
        match Simple_json.string_field "mode" value with
        | None -> Ok None
        | Some mode -> (match cloudflare_mode_of_string mode with Ok item -> Ok (Some item) | Error _ as e -> e)
      in
      (match mode with
      | Error _ as e -> e
      | Ok mode ->
          let bootstrap_worker = Simple_json.bool_field "bootstrap_worker" value in
          let resources_json =
            match Simple_json.object_field "resources" value with Some (Simple_json.Object _ as item) -> item | _ -> Simple_json.Object []
          in
          match parse_resources resources_json with
          | Ok resources -> Ok { mode; bootstrap_worker; resources }
          | Error _ as e -> e)
  | _ -> Error "cloudflare must be an object"

let read ~config_path =
  if not (Sys.file_exists config_path) then
    Error ("Missing Thunder config: " ^ config_path)
  else
    match Simple_json.parse (read_file config_path) with
    | Error msg -> Error (msg ^ " in " ^ config_path)
    | Ok (Simple_json.Object _ as json) ->
        let compile_target =
          match Simple_json.string_field "compile_target" json with
          | None -> Ok None
          | Some value ->
              (match compile_target_of_string value with Ok target -> Ok (Some target) | Error msg -> Error (msg ^ " in " ^ config_path))
        in
        let cloudflare =
          match Simple_json.object_field "cloudflare" json with
          | None -> Ok None
          | Some value -> (match parse_cloudflare value with Ok item -> Ok (Some item) | Error msg -> Error (msg ^ " in " ^ config_path))
        in
        (match (compile_target, cloudflare) with
        | Error msg, _ -> Error msg
        | _, Error msg -> Error msg
        | Ok compile_target, Ok cloudflare ->
            Ok
              {
                compile_target;
                app_module = Simple_json.string_field "app_module" json;
                worker_entry_path = Simple_json.string_field "worker_entry_path" json;
                compiled_runtime_path = Simple_json.string_field "compiled_runtime_path" json;
                wrangler_template_path = Simple_json.string_field "wrangler_template_path" json;
                deploy_dir = Simple_json.string_field "deploy_dir" json;
                framework_root = Simple_json.string_field "framework_root" json;
                cloudflare;
              })
    | Ok _ -> Error ("Thunder config root must be an object in " ^ config_path)

let read_if_exists ~config_path =
  if Sys.file_exists config_path then
    match read ~config_path with
    | Ok config -> config
    | Error _ -> empty
  else empty
