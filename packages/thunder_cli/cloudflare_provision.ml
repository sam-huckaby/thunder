type action = Create | Reuse | Adopt | Wire

type step = {
  kind : string;
  binding : string;
  name : string option;
  action : action;
}

type ops = {
  create_kv : name:string -> (Wrangler.resource_ref, string) result;
  list_kv : unit -> (Wrangler.resource_ref list, string) result;
  create_r2 : name:string -> (Wrangler.resource_ref, string) result;
  list_r2 : unit -> (Wrangler.resource_ref list, string) result;
  create_d1 : name:string -> (Wrangler.resource_ref, string) result;
  list_d1 : unit -> (Wrangler.resource_ref list, string) result;
  create_queue : name:string -> (Wrangler.resource_ref, string) result;
  list_queue : unit -> (Wrangler.resource_ref list, string) result;
}

let first_some left right = match left with Some _ -> left | None -> right

let string_of_status = function
  | Unix.WEXITED code -> "exit(" ^ string_of_int code ^ ")"
  | Unix.WSIGNALED signal -> "signal(" ^ string_of_int signal ^ ")"
  | Unix.WSTOPPED signal -> "stopped(" ^ string_of_int signal ^ ")"

let truncate text = if String.length text <= 800 then text else String.sub text 0 800 ^ "...<truncated>"

let normalize_lower s = String.lowercase_ascii (String.trim s)

let text_indicates_already_exists text =
  let lower = normalize_lower text in
  String.contains lower 'a'
  && (String.contains lower 'l')
  && (String.contains lower 'r')
  && (String.contains lower 'e')
  && (String.contains lower 'a')
  && (String.contains lower 'd')
  && (String.contains lower 'y')
  && (String.contains lower 'e')
  && (String.contains lower 'x')
  && (String.contains lower 'i')
  && (String.contains lower 's')
  && (String.contains lower 't')

let mentions_exists text =
  let lower = normalize_lower text in
  String.length lower > 0
  && ((String.contains lower 'e' && String.contains lower 'x' && String.contains lower 'i'
       && String.contains lower 's' && String.contains lower 't')
      && (String.contains lower 'a' || String.contains lower 'l' || String.contains lower 'r' || String.contains lower 'd' || String.contains lower 'y'))

let mentions_already_exists text = text_indicates_already_exists text || mentions_exists text

let find_named_resource resources name =
  List.find_opt (fun (resource : Wrangler.resource_ref) -> resource.name = name) resources

let create_from_result parse kind result =
  match result.Wrangler.status with
  | Unix.WEXITED 0 ->
      (match parse ~stdout:result.stdout ~stderr:result.stderr with
      | Error msg -> Error msg
      | Ok (resource : Wrangler.resource_ref) -> Ok resource)
  | status ->
      Error
        ("Wrangler " ^ kind ^ " create failed: " ^ string_of_status status ^ "\n"
       ^ result.stderr)

let default_ops =
  let parse_list label parse result =
    match result.Wrangler.status with
    | Unix.WEXITED 0 ->
        (match parse ~stdout:result.stdout ~stderr:result.stderr with
        | Ok resources -> Ok resources
        | Error msg ->
            Error
              (msg ^ "\nstdout:\n" ^ truncate result.stdout ^ "\nstderr:\n" ^ truncate result.stderr))
    | status -> Error ("Wrangler " ^ label ^ " list failed: " ^ string_of_status status ^ "\n" ^ result.stderr)
  in
  {
    create_kv = (fun ~name ->
      Wrangler.kv_namespace_create ~name
      |> create_from_result (Wrangler.parse_kv_namespace_create ~name) "kv");
    list_kv = (fun () -> parse_list "kv" Wrangler.parse_kv_namespace_list (Wrangler.kv_namespace_list ())); 
    create_r2 = (fun ~name ->
      Wrangler.r2_bucket_create ~name
      |> create_from_result (Wrangler.parse_r2_bucket_create ~name) "r2");
    list_r2 = (fun () -> parse_list "r2" Wrangler.parse_r2_bucket_list (Wrangler.r2_bucket_list ())); 
    create_d1 = (fun ~name ->
      Wrangler.d1_database_create ~name
      |> create_from_result (Wrangler.parse_d1_database_create ~name) "d1");
    list_d1 = (fun () -> parse_list "d1" Wrangler.parse_resource_refs (Wrangler.d1_database_list ())); 
    create_queue = (fun ~name ->
      Wrangler.queue_create ~name
      |> create_from_result (Wrangler.parse_queue_create ~name) "queue");
    list_queue = (fun () -> parse_list "queue" Wrangler.parse_queue_list (Wrangler.queue_list ())); 
  }

let existing_resource state ~kind ~binding ~name =
  List.find_opt
    (fun resource ->
      resource.Cloudflare_state.kind = kind && resource.binding = binding
      && resource.name = name)
    state.Cloudflare_state.resources

let add_or_replace_resource state resource =
  let filtered =
    List.filter
      (fun current ->
        not
          (current.Cloudflare_state.kind = resource.Cloudflare_state.kind
          && current.binding = resource.binding))
      state.Cloudflare_state.resources
  in
  { state with Cloudflare_state.resources = resource :: filtered }

let resource_step ~kind ~binding ~name ~action = { kind; binding; name; action }

let maybe_log debug_log message = match debug_log with Some log -> log message | None -> ()

let ensure_resource ~debug_log ~state ~kind ~binding ~name ~managed ~action_if_new create list_remote =
  match existing_resource state ~kind ~binding ~name:(Some name) with
  | Some resource ->
      maybe_log debug_log
        (Printf.sprintf "Reusing %s resource for binding %s from Thunder state (%s)" kind binding name);
      Ok (state, resource_step ~kind ~binding ~name:(Some name) ~action:Reuse, resource)
  | None ->
      maybe_log debug_log
        (Printf.sprintf "Creating %s resource for binding %s (%s)" kind binding name);
      (match create ~name with
      | Error msg when mentions_already_exists msg ->
          maybe_log debug_log
            (Printf.sprintf
               "%s resource for binding %s (%s) already exists remotely; listing existing resources"
               kind binding name);
          (match list_remote () with
          | Error list_error ->
              Error
                ("Failed to list existing " ^ kind ^ " resources after create reported an existing resource for binding "
               ^ binding ^ " (" ^ name ^ "): " ^ list_error)
          | Ok resources ->
               maybe_log debug_log
                 (Printf.sprintf "Found %d remote %s resource(s) while resolving existing %s"
                    (List.length resources) kind name);
               (match find_named_resource resources name with
               | None ->
                   Error
                     ("Wrangler reported that " ^ kind ^ " resource " ^ name
                    ^ " already exists, but Thunder could not find it in the subsequent list output for binding "
                    ^ binding ^ ". Raw error: " ^ msg)
               | Some created ->
                   let resource =
                    {
                      Cloudflare_state.kind;
                      binding;
                      name = Some name;
                      identifier = created.identifier;
                      managed;
                    }
                  in
                  Ok
                    ( add_or_replace_resource state resource,
                      resource_step ~kind ~binding ~name:(Some name) ~action:Reuse,
                      resource )))
      | Error msg ->
          Error
            ("Failed to provision " ^ kind ^ " resource for binding " ^ binding ^ " (" ^ name ^ "): "
           ^ msg)
      | Ok (created : Wrangler.resource_ref) ->
          maybe_log debug_log
            (Printf.sprintf "Created %s resource for binding %s (%s)" kind binding name);
          let resource =
            {
              Cloudflare_state.kind;
              binding;
              name = Some name;
              identifier = created.identifier;
              managed;
            }
          in
          Ok
            ( add_or_replace_resource state resource,
              resource_step ~kind ~binding ~name:(Some name) ~action:action_if_new,
              resource ))

let ensure_virtual_resource ~debug_log ~state ~kind ~binding ~name ~managed ~action_if_new =
  match existing_resource state ~kind ~binding ~name:(Some name) with
  | Some resource ->
      maybe_log debug_log
        (Printf.sprintf "Reusing %s virtual resource for binding %s (%s)" kind binding name);
      Ok (state, resource_step ~kind ~binding ~name:(Some name) ~action:Reuse, resource)
  | None ->
      maybe_log debug_log
        (Printf.sprintf "Recording %s virtual resource for binding %s (%s)" kind binding name);
      let resource =
        {
          Cloudflare_state.kind;
          binding;
          name = Some name;
          identifier = None;
          managed;
        }
      in
      Ok
        ( add_or_replace_resource state resource,
          resource_step ~kind ~binding ~name:(Some name) ~action:action_if_new,
          resource )

let apply_cloudflare_resources ~debug_log ~ops cloudflare state =
  let open Thunder_config in
  let apply_list state steps items apply_one =
    let rec loop state steps = function
      | [] -> Ok (state, steps)
      | item :: rest ->
          (match apply_one state item with
          | Error _ as e -> e
          | Ok (state, step, _) -> loop state (step :: steps) rest)
    in
    loop state steps items
  in
  match
    apply_list state [] cloudflare.resources.kv (fun state item ->
        ensure_resource ~debug_log ~state ~kind:"kv" ~binding:item.binding ~name:item.name ~managed:true
          ~action_if_new:Create ops.create_kv ops.list_kv)
  with
  | Error _ as e -> e
  | Ok (state, steps) ->
      (match
         apply_list state steps cloudflare.resources.r2 (fun state item ->
             ensure_resource ~debug_log ~state ~kind:"r2" ~binding:item.binding ~name:item.bucket
               ~managed:true ~action_if_new:Create ops.create_r2 ops.list_r2)
       with
      | Error _ as e -> e
      | Ok (state, steps) ->
          (match
             apply_list state steps cloudflare.resources.d1 (fun state item ->
                 ensure_resource ~debug_log ~state ~kind:"d1" ~binding:item.binding ~name:item.name
                   ~managed:true ~action_if_new:Create ops.create_d1 ops.list_d1)
           with
          | Error _ as e -> e
          | Ok (state, steps) ->
              (match
                 apply_list state steps cloudflare.resources.queues (fun state item ->
                     ensure_resource ~debug_log ~state ~kind:"queue" ~binding:item.binding ~name:item.name
                        ~managed:true ~action_if_new:Create ops.create_queue ops.list_queue)
               with
              | Error _ as e -> e
              | Ok (state, steps) ->
                  (match
                     apply_list state steps cloudflare.resources.ai (fun state item ->
                         ensure_virtual_resource ~debug_log ~state ~kind:"ai" ~binding:item.binding
                           ~name:item.binding ~managed:true ~action_if_new:Wire)
                   with
                  | Error _ as e -> e
                  | Ok (state, steps) ->
                      (match
                         apply_list state steps cloudflare.resources.durable_objects
                            (fun state item ->
                              ensure_virtual_resource ~debug_log ~state ~kind:"durable_object"
                                ~binding:item.binding ~name:item.class_name ~managed:true
                                ~action_if_new:Wire)
                       with
                      | Error _ as e -> e
                      | Ok (state, steps) ->
                          (match
                             apply_list state steps cloudflare.resources.services
                                (fun state item ->
                                  ensure_virtual_resource ~debug_log ~state ~kind:"service"
                                    ~binding:item.binding ~name:item.service ~managed:false
                                    ~action_if_new:Adopt)
                           with
                          | Error _ as e -> e
                          | Ok (state, steps) -> Ok (state, List.rev steps)))))))

let run ?account_id ?worker_name ?timestamp ?debug_log ~ops config state =
  (match (account_id, state.Cloudflare_state.account_id) with
  | Some requested, Some existing when requested <> existing ->
      Error
        ("Cloudflare account mismatch: requested " ^ requested ^ " but state file is bound to "
       ^ existing ^ ". Refusing to provision against a different account.")
  | _ -> Ok ())
  |> function
  | Error _ as e -> e
  | Ok () ->
      match config.Thunder_config.cloudflare with
  | None -> Ok (state, [])
  | Some cloudflare ->
      (match apply_cloudflare_resources ~debug_log ~ops cloudflare state with
      | Error _ as e -> e
      | Ok (state, steps) ->
          let worker =
            let existing =
              Option.value state.worker
                ~default:
                  {
                    Cloudflare_state.script_name = None;
                    bootstrapped = false;
                    last_deploy_at = None;
                  }
            in
            Some
              {
                Cloudflare_state.script_name = first_some worker_name existing.script_name;
                bootstrapped = existing.bootstrapped;
                last_deploy_at = existing.last_deploy_at;
              }
          in
          Ok
            ( { state with
                Cloudflare_state.account_id = first_some account_id state.account_id;
                worker;
                last_provision_at = first_some timestamp state.last_provision_at; },
              steps ))

let run_and_write ?account_id ?worker_name ?timestamp ?debug_log ~ops ~state_path config state =
  match run ?account_id ?worker_name ?timestamp ?debug_log ~ops config state with
  | Error _ as e -> e
  | Ok (updated_state, steps) ->
      (match Cloudflare_state.write ~path:state_path updated_state with
      | Error _ as e -> e
      | Ok () -> Ok (updated_state, steps))
