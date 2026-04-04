type worker = {
  name : string option;
  configured : bool;
  bootstrapped : bool;
  remote_exists : bool;
}

type resource = {
  kind : string;
  binding : string;
  name : string option;
  managed : bool;
  configured : bool;
  state_present : bool;
  remote_exists : bool;
  healthy : bool;
}

type t = {
  ok : bool;
  mode : string;
  account_id : string option;
  worker : worker;
  resources : resource list;
  warnings : string list;
  errors : string list;
}

type ops = {
  account_id : unit -> (string option, string) result;
  kv_resources : unit -> (Wrangler.resource_ref list, string) result;
  r2_resources : unit -> (Wrangler.resource_ref list, string) result;
  d1_resources : unit -> (Wrangler.resource_ref list, string) result;
  queue_resources : unit -> (Wrangler.resource_ref list, string) result;
  worker_exists : string -> (bool, string) result;
}

let empty =
  {
    ok = false;
    mode = "dev_test";
    account_id = None;
    worker = { name = None; configured = false; bootstrapped = false; remote_exists = false };
    resources = [];
    warnings = [];
    errors = [];
  }

let string_opt value = match value with Some s -> Simple_json.String s | None -> Simple_json.Null

let first_some left right = match left with Some _ -> left | None -> right

let worker_to_json (worker : worker) =
  Simple_json.Object
    [ "name", string_opt worker.name;
      "configured", Simple_json.Bool worker.configured;
      "bootstrapped", Simple_json.Bool worker.bootstrapped;
      "remote_exists", Simple_json.Bool worker.remote_exists ]

let resource_to_json (resource : resource) =
  Simple_json.Object
    [ "kind", Simple_json.String resource.kind;
      "binding", Simple_json.String resource.binding;
      "name", string_opt resource.name;
      "managed", Simple_json.Bool resource.managed;
      "configured", Simple_json.Bool resource.configured;
      "state_present", Simple_json.Bool resource.state_present;
      "remote_exists", Simple_json.Bool resource.remote_exists;
      "healthy", Simple_json.Bool resource.healthy ]

let to_json status =
  Simple_json.Object
    [ "ok", Simple_json.Bool status.ok;
      "mode", Simple_json.String status.mode;
      "account_id", string_opt status.account_id;
      "worker", worker_to_json status.worker;
      "resources", Simple_json.Array (List.map resource_to_json status.resources);
      "warnings", Simple_json.Array (List.map (fun s -> Simple_json.String s) status.warnings);
      "errors", Simple_json.Array (List.map (fun s -> Simple_json.String s) status.errors) ]

let refs_from_result parse result =
  match result.Wrangler.status with
  | Unix.WEXITED 0 -> parse ~stdout:result.stdout ~stderr:result.stderr
  | status ->
      Error
        ("Wrangler command failed: "
        ^ (match status with
          | Unix.WEXITED code -> "exit(" ^ string_of_int code ^ ")"
          | Unix.WSIGNALED signal -> "signal(" ^ string_of_int signal ^ ")"
          | Unix.WSTOPPED signal -> "stopped(" ^ string_of_int signal ^ ")"))

let read_wrangler_account_id path =
  if not (Sys.file_exists path) then None
  else
    let ic = open_in_bin path in
    Fun.protect ~finally:(fun () -> close_in_noerr ic) (fun () ->
        let rec loop () =
          match input_line ic with
          | line ->
              let trimmed = String.trim line in
              if String.starts_with ~prefix:"account_id =" trimmed then
                match List.rev (String.split_on_char '=' trimmed) with
                | value :: _ ->
                    let value = String.trim value in
                    let len = String.length value in
                    if len >= 2 && value.[0] = '"' && value.[len - 1] = '"' then
                      Some (String.sub value 1 (len - 2))
                    else Some value
                | [] -> None
              else loop ()
          | exception End_of_file -> None
        in
        loop ())

let default_ops =
  {
    account_id = (fun () -> Ok (Wrangler.parse_account_id ~stdout:(Wrangler.whoami ()).stdout ~stderr:(Wrangler.whoami ()).stderr));
    kv_resources = (fun () -> refs_from_result Wrangler.parse_kv_namespace_list (Wrangler.kv_namespace_list ())); 
    r2_resources = (fun () -> refs_from_result Wrangler.parse_r2_bucket_list (Wrangler.r2_bucket_list ())); 
    d1_resources = (fun () -> refs_from_result Wrangler.parse_resource_refs (Wrangler.d1_database_list ())); 
    queue_resources = (fun () -> refs_from_result Wrangler.parse_queue_list (Wrangler.queue_list ())); 
    worker_exists =
      (fun worker_name ->
        let result = Wrangler.worker_list () in
        match result.status with
        | Unix.WEXITED 0 -> Wrangler.worker_exists ~worker_name ~stdout:result.stdout ~stderr:result.stderr
        | status ->
            Error
              ("Wrangler worker inspection failed: "
              ^ (match status with
                | Unix.WEXITED code -> "exit(" ^ string_of_int code ^ ")"
                | Unix.WSIGNALED signal -> "signal(" ^ string_of_int signal ^ ")"
                | Unix.WSTOPPED signal -> "stopped(" ^ string_of_int signal ^ ")")))
  }

let find_resource_ref refs name = List.exists (fun item -> item.Wrangler.name = name) refs

let read_template_worker_name path =
  if not (Sys.file_exists path) then None
  else
    let ic = open_in_bin path in
    Fun.protect ~finally:(fun () -> close_in_noerr ic) (fun () ->
        let rec loop () =
          match input_line ic with
          | line ->
              let trimmed = String.trim line in
              if String.starts_with ~prefix:"name =" trimmed then
                let parts = String.split_on_char '=' trimmed in
                (match List.rev parts with
                | value :: _ ->
                    let value = String.trim value in
                    let len = String.length value in
                    if len >= 2 && value.[0] = '"' && value.[len - 1] = '"' then
                      Some (String.sub value 1 (len - 2))
                    else Some value
                | [] -> None)
              else loop ()
          | exception End_of_file -> None
        in
        loop ())

let mode_string = function Some Thunder_config.Dev_test -> "dev_test" | None -> "dev_test"

let resource_status ~kind ~binding ~name ~managed ~configured ~state_present ~remote_exists =
  { kind; binding; name; managed; configured; state_present; remote_exists; healthy = configured && state_present && remote_exists }

let run ~(ops : ops) (config : Thunder_config.t) (state : Cloudflare_state.t) =
  let cloudflare = config.Thunder_config.cloudflare in
  let warnings = ref [] in
  let errors = ref [] in
  let remember_result = function
    | Ok value -> Some value
    | Error msg ->
        errors := msg :: !errors;
        None
  in
  let account_id =
    first_some
      (first_some (remember_result (ops.account_id ()) |> Option.join) state.account_id)
      (read_wrangler_account_id (Option.value config.wrangler_template_path ~default:"wrangler.toml"))
  in
  (match (account_id, state.account_id) with
  | Some remote, Some existing when remote <> existing ->
      errors :=
        ("Cloudflare account mismatch: remote account is " ^ remote
       ^ " but Thunder state is bound to " ^ existing ^ ".")
        :: !errors
  | _ -> ());
  let worker_name =
    match state.worker with
    | Some worker -> worker.script_name
    | None -> read_template_worker_name "wrangler.toml"
  in
  let worker_remote_exists =
    match worker_name with
    | Some name -> Option.value (remember_result (ops.worker_exists name)) ~default:false
    | None ->
        warnings := "Worker name is not configured." :: !warnings;
        false
  in
  let state_present kind binding =
    List.exists
      (fun (item : Cloudflare_state.managed_resource) ->
        item.kind = kind && item.binding = binding)
      state.resources
  in
  let resources =
    match cloudflare with
    | None -> []
    | Some (cloudflare : Thunder_config.cloudflare) ->
        let kv_refs =
          if cloudflare.resources.kv = [] then []
          else Option.value (remember_result (ops.kv_resources ())) ~default:[]
        in
        let r2_refs =
          if cloudflare.resources.r2 = [] then []
          else Option.value (remember_result (ops.r2_resources ())) ~default:[]
        in
        let d1_refs =
          if cloudflare.resources.d1 = [] then []
          else Option.value (remember_result (ops.d1_resources ())) ~default:[]
        in
        let queue_refs =
          if cloudflare.resources.queues = [] then []
          else Option.value (remember_result (ops.queue_resources ())) ~default:[]
        in
        let kv =
          cloudflare.resources.kv
          |> List.map (fun (item : Thunder_config.cloudflare_named_binding) ->
                 resource_status ~kind:"kv" ~binding:item.binding ~name:(Some item.name)
                   ~managed:true ~configured:true ~state_present:(state_present "kv" item.binding)
                   ~remote_exists:(find_resource_ref kv_refs item.name))
        in
        let r2 =
          cloudflare.resources.r2
          |> List.map (fun (item : Thunder_config.cloudflare_r2_binding) ->
                 resource_status ~kind:"r2" ~binding:item.binding ~name:(Some item.bucket)
                   ~managed:true ~configured:true ~state_present:(state_present "r2" item.binding)
                   ~remote_exists:(find_resource_ref r2_refs item.bucket))
        in
        let d1 =
          cloudflare.resources.d1
          |> List.map (fun (item : Thunder_config.cloudflare_named_binding) ->
                 resource_status ~kind:"d1" ~binding:item.binding ~name:(Some item.name)
                   ~managed:true ~configured:true ~state_present:(state_present "d1" item.binding)
                   ~remote_exists:(find_resource_ref d1_refs item.name))
        in
        let queues =
          cloudflare.resources.queues
          |> List.map (fun (item : Thunder_config.cloudflare_named_binding) ->
                 resource_status ~kind:"queue" ~binding:item.binding ~name:(Some item.name)
                   ~managed:true ~configured:true ~state_present:(state_present "queue" item.binding)
                   ~remote_exists:(find_resource_ref queue_refs item.name))
        in
        let ai =
          cloudflare.resources.ai
          |> List.map (fun (item : Thunder_config.cloudflare_ai_binding) ->
                 resource_status ~kind:"ai" ~binding:item.binding ~name:(Some item.binding)
                   ~managed:true ~configured:true ~state_present:(state_present "ai" item.binding)
                   ~remote_exists:true)
        in
        let durable_objects =
          cloudflare.resources.durable_objects
          |> List.map (fun (item : Thunder_config.cloudflare_durable_object_binding) ->
                 resource_status ~kind:"durable_object" ~binding:item.binding ~name:(Some item.class_name)
                   ~managed:true ~configured:true
                   ~state_present:(state_present "durable_object" item.binding) ~remote_exists:true)
        in
        let services =
          cloudflare.resources.services
          |> List.map (fun (item : Thunder_config.cloudflare_service_binding) ->
                 resource_status ~kind:"service" ~binding:item.binding ~name:(Some item.service)
                   ~managed:false ~configured:true ~state_present:(state_present "service" item.binding)
                   ~remote_exists:true)
        in
        kv @ r2 @ d1 @ queues @ ai @ durable_objects @ services
  in
  let configured_bindings =
    match cloudflare with
    | None -> []
    | Some cloudflare ->
        List.map (fun (item : Thunder_config.cloudflare_named_binding) -> ("kv", item.binding)) cloudflare.resources.kv
        @ List.map (fun (item : Thunder_config.cloudflare_r2_binding) -> ("r2", item.binding)) cloudflare.resources.r2
        @ List.map (fun (item : Thunder_config.cloudflare_named_binding) -> ("d1", item.binding)) cloudflare.resources.d1
        @ List.map (fun (item : Thunder_config.cloudflare_named_binding) -> ("queue", item.binding)) cloudflare.resources.queues
        @ List.map (fun (item : Thunder_config.cloudflare_ai_binding) -> ("ai", item.binding)) cloudflare.resources.ai
        @ List.map (fun (item : Thunder_config.cloudflare_durable_object_binding) -> ("durable_object", item.binding)) cloudflare.resources.durable_objects
        @ List.map (fun (item : Thunder_config.cloudflare_service_binding) -> ("service", item.binding)) cloudflare.resources.services
  in
  let unconfigured_state_resources =
    state.resources
    |> List.filter (fun (item : Cloudflare_state.managed_resource) ->
           not (List.exists (fun (kind, binding) -> kind = item.kind && binding = item.binding) configured_bindings))
  in
  if unconfigured_state_resources <> [] then
    warnings :=
      ("Thunder state contains resources no longer declared in thunder.json: "
      ^ String.concat ", "
          (List.map
             (fun (item : Cloudflare_state.managed_resource) -> item.kind ^ "/" ^ item.binding)
             unconfigured_state_resources))
      :: !warnings;
  let ok = !errors = [] && List.for_all (fun resource -> resource.healthy) resources && worker_remote_exists in
  {
    ok;
    mode = mode_string (Option.bind cloudflare (fun item -> item.mode));
    account_id;
    worker =
      {
        name = worker_name;
        configured = worker_name <> None;
        bootstrapped = (match state.worker with Some worker -> worker.bootstrapped | None -> false);
        remote_exists = worker_remote_exists;
      };
    resources;
    warnings = List.rev !warnings;
    errors = List.rev !errors;
  }

let render_pretty status =
  let resource_lines =
    status.resources
    |> List.map (fun resource ->
           Printf.sprintf "- %s %s configured=%b state=%b remote=%b healthy=%b"
             resource.kind resource.binding resource.configured resource.state_present
             resource.remote_exists resource.healthy)
  in
  String.concat "\n"
    ([ Printf.sprintf "ok: %b" status.ok;
       Printf.sprintf "mode: %s" status.mode;
       Printf.sprintf "account_id: %s"
         (Option.value status.account_id ~default:"<missing>");
       Printf.sprintf "worker: name=%s configured=%b bootstrapped=%b remote_exists=%b"
         (Option.value status.worker.name ~default:"<missing>") status.worker.configured
         status.worker.bootstrapped status.worker.remote_exists;
       "resources:" ]
    @ resource_lines
    @ (if status.warnings = [] then [] else "warnings:" :: List.map (fun item -> "- " ^ item) status.warnings)
    @ if status.errors = [] then [] else "errors:" :: List.map (fun item -> "- " ^ item) status.errors)
