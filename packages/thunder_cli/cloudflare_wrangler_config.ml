let begin_marker section = "# BEGIN thunder-managed-" ^ section
let end_marker section = "# END thunder-managed-" ^ section

let read_file path =
  let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let write_file path contents =
  let oc = open_out_bin path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc) (fun () -> output_string oc contents)

let trim = String.trim

let has_prefix prefix line = String.starts_with ~prefix (trim line)

let replace_or_append_section ~section ~content text =
  let lines = String.split_on_char '\n' text in
  let start_marker = begin_marker section in
  let stop_marker = end_marker section in
  let block_lines =
    if content = [] then [] else [ start_marker ] @ content @ [ stop_marker ]
  in
  let rec consume acc = function
    | [] -> List.rev acc @ block_lines
    | line :: rest when has_prefix start_marker line ->
        let rec skip_until_end = function
          | [] -> []
          | inner :: tail when has_prefix stop_marker inner -> tail
          | _ :: tail -> skip_until_end tail
        in
        List.rev acc @ block_lines @ skip_until_end rest
    | line :: rest -> consume (line :: acc) rest
  in
  String.concat "\n" (consume [] lines)

let find_resource state ~kind ~binding =
  List.find_opt
    (fun resource -> resource.Cloudflare_state.kind = kind && resource.binding = binding)
    state.Cloudflare_state.resources

let render_kv config state =
  config.Thunder_config.resources.kv
  |> List.filter_map (fun (item : Thunder_config.cloudflare_named_binding) ->
         match find_resource state ~kind:"kv" ~binding:item.binding with
         | Some resource ->
             Some
               (Printf.sprintf
                  "[[kv_namespaces]]\nbinding = %S\nid = %S"
                  item.binding
                  (Option.value resource.identifier ~default:"<missing-kv-id>"))
         | None -> None)

let render_r2 config state =
  config.Thunder_config.resources.r2
  |> List.filter_map (fun (item : Thunder_config.cloudflare_r2_binding) ->
         match find_resource state ~kind:"r2" ~binding:item.binding with
         | Some resource ->
             Some
               (Printf.sprintf
                  "[[r2_buckets]]\nbinding = %S\nbucket_name = %S"
                  item.binding
                  (Option.value resource.name ~default:item.bucket))
         | None -> None)

let render_d1 config state =
  config.Thunder_config.resources.d1
  |> List.filter_map (fun (item : Thunder_config.cloudflare_named_binding) ->
         match find_resource state ~kind:"d1" ~binding:item.binding with
         | Some resource ->
             Some
               (Printf.sprintf
                  "[[d1_databases]]\nbinding = %S\ndatabase_name = %S\ndatabase_id = %S"
                  item.binding item.name
                  (Option.value resource.identifier ~default:"<missing-d1-id>"))
         | None -> None)

let render_queues config state =
  config.Thunder_config.resources.queues
  |> List.filter_map (fun (item : Thunder_config.cloudflare_named_binding) ->
         match find_resource state ~kind:"queue" ~binding:item.binding with
         | Some resource ->
             Some
               (Printf.sprintf
                  "[[queues.producers]]\nbinding = %S\nqueue = %S"
                  item.binding
                  (Option.value resource.name ~default:item.name))
         | None -> None)

let render_ai config _state =
  config.Thunder_config.resources.ai
  |> List.map (fun (item : Thunder_config.cloudflare_ai_binding) -> Printf.sprintf "[ai]\nbinding = %S" item.binding)

let render_durable_objects config state =
  let bindings =
    config.Thunder_config.resources.durable_objects
    |> List.filter_map (fun (item : Thunder_config.cloudflare_durable_object_binding) ->
           match find_resource state ~kind:"durable_object" ~binding:item.binding with
           | Some _ ->
               Some
                 (Printf.sprintf
                    "[[durable_objects.bindings]]\nname = %S\nclass_name = %S"
                    item.binding item.class_name)
           | None -> None)
  in
  let migrations =
    config.Thunder_config.resources.durable_objects
    |> List.mapi (fun index (item : Thunder_config.cloudflare_durable_object_binding) ->
           Printf.sprintf
             "[[migrations]]\ntag = %S\nnew_sqlite_classes = [%S]"
             ("thunder-v" ^ string_of_int (index + 1)) item.class_name)
  in
  bindings @ migrations

let render_services config state =
  config.Thunder_config.resources.services
  |> List.filter_map (fun (item : Thunder_config.cloudflare_service_binding) ->
         match find_resource state ~kind:"service" ~binding:item.binding with
         | Some _ ->
             Some
               (Printf.sprintf
                  "[[services]]\nbinding = %S\nservice = %S"
                  item.binding item.service)
         | None -> None)

let render_managed ~config ~state ~template =
  let rendered =
    template
    |> replace_or_append_section ~section:"kv" ~content:(render_kv config state)
    |> replace_or_append_section ~section:"r2" ~content:(render_r2 config state)
    |> replace_or_append_section ~section:"d1" ~content:(render_d1 config state)
    |> replace_or_append_section ~section:"queues" ~content:(render_queues config state)
    |> replace_or_append_section ~section:"ai" ~content:(render_ai config state)
    |> replace_or_append_section ~section:"durable-objects" ~content:(render_durable_objects config state)
    |> replace_or_append_section ~section:"services" ~content:(render_services config state)
  in
  Ok rendered

let apply_to_file ~config ~state ~path =
  match render_managed ~config ~state ~template:(read_file path) with
  | Error _ as e -> e
  | Ok rendered ->
      write_file path (rendered ^ if String.ends_with ~suffix:"\n" rendered then "" else "\n");
      Ok rendered
