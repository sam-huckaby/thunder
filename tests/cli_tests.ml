let assert_true msg cond = if not cond then failwith msg

let assert_eq msg expected actual =
  if expected <> actual then failwith (msg ^ " expected=" ^ expected ^ " actual=" ^ actual)

let contains_substring haystack needle =
  let haystack_len = String.length haystack in
  let needle_len = String.length needle in
  let rec loop index =
    if index + needle_len > haystack_len then false
    else if String.sub haystack index needle_len = needle then true
    else loop (index + 1)
  in
  if needle_len = 0 then true else loop 0

let with_temp_file prefix content f =
  let path = Filename.temp_file prefix ".tmp" in
  let oc = open_out path in
  output_string oc content;
  close_out oc;
  Fun.protect ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () -> f path)

let with_temp_path prefix f =
  let path = Filename.temp_file prefix ".tmp" in
  if Sys.file_exists path then Sys.remove path;
  Fun.protect ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () -> f path)

let rm_rf path =
  if Sys.file_exists path then
    match Sys.command ("rm -rf " ^ Filename.quote path) with
    | 0 -> ()
    | _ -> failwith ("failed to remove temporary path: " ^ path)

let with_temp_dir prefix f =
  let base = Filename.temp_file prefix ".tmp" in
  if Sys.file_exists base then Sys.remove base;
  Unix.mkdir base 0o755;
  Fun.protect ~finally:(fun () -> rm_rf base) (fun () -> f base)

let write_file path content =
  let oc = open_out path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc content)

let with_cwd path f =
  let prev = Sys.getcwd () in
  Fun.protect ~finally:(fun () -> Unix.chdir prev) (fun () ->
      Unix.chdir path;
      f ())

let with_env_var name value_opt f =
  let previous = Sys.getenv_opt name in
  let sentinel = Filename.temp_file "thunder-env-empty" ".tmp" in
  let set = function
    | Some value -> Unix.putenv name value
    | None -> Unix.putenv name sentinel
  in
  Fun.protect ~finally:(fun () -> set previous) (fun () ->
      set value_opt;
      f ())

let () =
  with_temp_file "thunder-artifact" "hello" (fun artifact ->
      match Thunder_cli_lib.Artifact_hash.compute [ artifact ] with
      | Error e -> failwith e
      | Ok h1 ->
          (match Thunder_cli_lib.Artifact_hash.compute [ artifact ] with
          | Error e -> failwith e
          | Ok h2 -> assert_true "stable hash" (h1 = h2)));
  ()

let () =
  with_temp_path "thunder-metadata" (fun metadata_path ->
      let metadata : Thunder_cli_lib.Preview_publish.metadata =
        {
          artifact_hash = Some "abc";
          last_upload_at = Some "2026-03-12T00:00:00Z";
          last_version_id = Some "v1";
          last_preview_url = Some "https://preview.example";
          raw_wrangler_output = Some "uploaded";
        }
      in
      Thunder_cli_lib.Preview_publish.write_metadata ~metadata_path metadata;
      let loaded = Thunder_cli_lib.Preview_publish.read_metadata ~metadata_path in
      assert_eq "metadata hash" (Option.get metadata.artifact_hash)
        (Option.get loaded.artifact_hash);
      assert_eq "metadata version" (Option.get metadata.last_version_id)
        (Option.get loaded.last_version_id));
  ()

let () =
  with_temp_file "thunder-legacy-metadata" "hash=legacy123\n" (fun metadata_path ->
      let hash = Thunder_cli_lib.Artifact_hash.read_previous_hash ~metadata_path in
      assert_eq "legacy hash migration" "legacy123" (Option.get hash));
  ()

let () =
  with_temp_dir "thunder-manifest" (fun dir ->
      let worker_runtime_dir = Filename.concat dir "worker_runtime" in
      let dist_dir = Filename.concat dir "dist/worker" in
      Unix.mkdir worker_runtime_dir 0o755;
      Unix.mkdir (Filename.concat dir "dist") 0o755;
       Unix.mkdir dist_dir 0o755;
       let manifest_path = Filename.concat dist_dir "manifest.json" in
       write_file manifest_path
         "{\"abi_version\":1,\"app_id\":\"test-app\",\"runtime_kind\":\"wasm\",\"runtime_entry\":\"../../worker_runtime/index.mjs\",\"app_abi\":\"../../worker_runtime/app_abi.mjs\",\"generated_wasm_assets\":\"../../worker_runtime/generated_wasm_assets.mjs\",\"compiled_runtime_backend\":\"../../worker_runtime/compiled_runtime_backend.mjs\",\"bootstrap_module\":\"../../worker_runtime/compiled_runtime_bootstrap.mjs\",\"compiled_runtime\":\"thunder_runtime.mjs\",\"assets_dir\":\"thunder_runtime.assets\"}\n";
       match Thunder_cli_lib.Deploy_manifest.parse ~manifest_path with
       | Error e -> failwith e
       | Ok manifest ->
           assert_eq "manifest app id" "test-app" manifest.app_id;
           assert_true "manifest runtime kind wasm"
             (manifest.runtime_kind = Thunder_cli_lib.Deploy_manifest.Wasm);
           assert_eq "manifest generated assets" "../../worker_runtime/generated_wasm_assets.mjs"
             (Option.get manifest.generated_wasm_assets);
           assert_eq "manifest backend" "../../worker_runtime/compiled_runtime_backend.mjs"
             manifest.compiled_runtime_backend;
           assert_eq "manifest compiled runtime" "thunder_runtime.mjs"
             manifest.compiled_runtime);
  ()

let () =
  with_temp_dir "thunder-manifest-js" (fun dir ->
      let worker_runtime_dir = Filename.concat dir "worker_runtime" in
      let dist_dir = Filename.concat dir "dist/worker" in
      Unix.mkdir worker_runtime_dir 0o755;
      Unix.mkdir (Filename.concat dir "dist") 0o755;
      Unix.mkdir dist_dir 0o755;
      let manifest_path = Filename.concat dist_dir "manifest.json" in
      write_file manifest_path
        "{\"abi_version\":1,\"app_id\":\"js-app\",\"runtime_kind\":\"js\",\"runtime_entry\":\"../../worker_runtime/index.mjs\",\"app_abi\":\"../../worker_runtime/app_abi.mjs\",\"compiled_runtime_backend\":\"../../worker_runtime/compiled_runtime_backend.mjs\",\"compiled_runtime\":\"thunder_runtime.mjs\"}\n";
      match Thunder_cli_lib.Deploy_manifest.parse ~manifest_path with
      | Error e -> failwith e
      | Ok manifest ->
          assert_true "manifest runtime kind js"
            (manifest.runtime_kind = Thunder_cli_lib.Deploy_manifest.Js);
          assert_true "manifest js omits generated assets"
            (manifest.generated_wasm_assets = None);
          assert_true "manifest js omits bootstrap"
            (manifest.bootstrap_module = None);
          assert_true "manifest js omits assets dir" (manifest.assets_dir = None))

let () =
  with_temp_dir "thunder-manifest-missing-wasm" (fun dir ->
      let dist_dir = Filename.concat dir "dist/worker" in
      Unix.mkdir (Filename.concat dir "dist") 0o755;
      Unix.mkdir dist_dir 0o755;
      let manifest_path = Filename.concat dist_dir "manifest.json" in
      write_file manifest_path
        "{\"abi_version\":1,\"app_id\":\"bad-app\",\"runtime_kind\":\"wasm\",\"runtime_entry\":\"../../worker_runtime/index.mjs\",\"app_abi\":\"../../worker_runtime/app_abi.mjs\",\"compiled_runtime_backend\":\"../../worker_runtime/compiled_runtime_backend.mjs\",\"compiled_runtime\":\"thunder_runtime.mjs\"}\n";
      match Thunder_cli_lib.Deploy_manifest.parse ~manifest_path with
      | Ok _ -> failwith "expected missing wasm field error"
      | Error msg ->
          assert_true "manifest missing wasm fields error"
            (contains_substring msg "runtime_kind=wasm"))

let () =
  with_temp_dir "thunder-config" (fun dir ->
      let config_path = Filename.concat dir "thunder.json" in
      write_file config_path
        "{\"compile_target\":\"wasm\",\"app_module\":\"My_app.Routes\",\"worker_entry_path\":\"worker/entry.ml\",\"compiled_runtime_path\":\"build/runtime.mjs\",\"wrangler_template_path\":\"config/wrangler.toml\",\"deploy_dir\":\".thunder/deploy\",\"framework_root\":\"/tmp/thunder-framework\"}\n";
      match Thunder_cli_lib.Thunder_config.read ~config_path with
      | Error e -> failwith e
      | Ok config ->
          assert_true "config compile target wasm"
            (Option.get config.compile_target = Thunder_cli_lib.Thunder_config.Wasm);
          assert_eq "config app module" "My_app.Routes"
            (Option.get config.app_module);
          assert_eq "config worker entry" "worker/entry.ml"
            (Option.get config.worker_entry_path);
           assert_eq "config runtime path" "build/runtime.mjs"
              (Option.get config.compiled_runtime_path));
  ()

let () =
  with_temp_dir "thunder-cloudflare-config" (fun dir ->
      let config_path = Filename.concat dir "thunder.json" in
      write_file config_path
        "{\"cloudflare\":{\"mode\":\"dev_test\",\"bootstrap_worker\":true,\"resources\":{\"kv\":[{\"binding\":\"MY_KV\",\"name\":\"demo-kv\"}],\"r2\":[{\"binding\":\"FILES\",\"bucket\":\"demo-files\"}],\"d1\":[{\"binding\":\"DB\",\"name\":\"demo-db\"}],\"queues\":[{\"binding\":\"JOBS\",\"queue\":\"demo-jobs\"}],\"ai\":[{\"binding\":\"AI\"}],\"durable_objects\":[{\"binding\":\"MY_DO\",\"class_name\":\"MyDurableObject\"}],\"services\":[{\"binding\":\"API\",\"service\":\"demo-service\"}]}}}\n";
      match Thunder_cli_lib.Thunder_config.read ~config_path with
      | Error e -> failwith e
      | Ok config ->
          let cloudflare = Option.get config.cloudflare in
          assert_true "cloudflare mode dev_test"
            (cloudflare.mode = Some Thunder_cli_lib.Thunder_config.Dev_test);
          assert_true "cloudflare bootstrap worker true"
            (cloudflare.bootstrap_worker = Some true);
          assert_eq "cloudflare kv binding" "MY_KV"
            (List.hd cloudflare.resources.kv).binding;
          assert_eq "cloudflare r2 bucket" "demo-files"
            (List.hd cloudflare.resources.r2).bucket;
          assert_eq "cloudflare d1 binding" "DB" (List.hd cloudflare.resources.d1).binding;
          assert_eq "cloudflare queue name" "demo-jobs"
            (List.hd cloudflare.resources.queues).name;
          assert_eq "cloudflare ai binding" "AI" (List.hd cloudflare.resources.ai).binding;
          assert_eq "cloudflare do class" "MyDurableObject"
            (List.hd cloudflare.resources.durable_objects).class_name;
          assert_eq "cloudflare service name" "demo-service"
            (List.hd cloudflare.resources.services).service)

let () =
  with_temp_path "thunder-cloudflare-state" (fun state_path ->
      let state : Thunder_cli_lib.Cloudflare_state.t =
        {
          account_id = Some "account-123";
          worker =
            Some
              {
                script_name = Some "demo-app";
                bootstrapped = true;
                last_deploy_at = Some "2026-04-04T12:00:00Z";
              };
          resources =
            [ { kind = "kv"; binding = "MY_KV"; name = Some "demo-kv"; identifier = Some "id-1"; managed = true } ];
          last_provision_at = Some "2026-04-04T12:00:00Z";
          last_status_at = Some "2026-04-04T12:05:00Z";
        }
      in
      (match Thunder_cli_lib.Cloudflare_state.write ~path:state_path state with
      | Error e -> failwith e
      | Ok () -> ());
      match Thunder_cli_lib.Cloudflare_state.read ~path:state_path with
      | Error e -> failwith e
      | Ok loaded ->
          assert_eq "cloudflare state account" "account-123" (Option.get loaded.account_id);
          assert_eq "cloudflare state worker name" "demo-app"
            (Option.get (Option.get loaded.worker).script_name);
          assert_eq "cloudflare state resource binding" "MY_KV"
            (List.hd loaded.resources).binding)

let () =
  let status : Thunder_cli_lib.Cloudflare_status.t =
    {
      ok = true;
      mode = "dev_test";
      account_id = Some "account-123";
      worker =
        {
          name = Some "demo-app";
          configured = true;
          bootstrapped = true;
          remote_exists = true;
        };
      resources =
        [ {
            kind = "kv";
            binding = "MY_KV";
            name = Some "demo-kv";
            managed = true;
            configured = true;
            state_present = true;
            remote_exists = true;
            healthy = true;
          } ];
      warnings = [];
      errors = [];
    }
  in
  let json = Thunder_cli_lib.Simple_json.to_string (Thunder_cli_lib.Cloudflare_status.to_json status) in
  assert_true "cloudflare status json ok" (contains_substring json "\"ok\":true");
  assert_true "cloudflare status json binding" (contains_substring json "\"binding\":\"MY_KV\"")

let () =
  let pretty =
    Thunder_cli_lib.Cloudflare_status.render_pretty
      {
        Thunder_cli_lib.Cloudflare_status.empty with
        ok = true;
        account_id = Some "acct-1";
        worker =
          {
            name = Some "demo-app";
            configured = true;
            bootstrapped = true;
            remote_exists = true;
          };
        resources =
          [ {
              kind = "kv";
              binding = "MY_KV";
              name = Some "demo-kv";
              managed = true;
              configured = true;
              state_present = true;
              remote_exists = true;
              healthy = true;
            } ];
      }
  in
  assert_true "cloudflare status pretty ok" (contains_substring pretty "ok: true");
  assert_true "cloudflare status pretty resource" (contains_substring pretty "kv MY_KV")

let () =
  let config : Thunder_cli_lib.Thunder_config.t =
    {
      Thunder_cli_lib.Thunder_config.empty with
      cloudflare =
        Some
          {
            mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
            bootstrap_worker = Some true;
            resources =
              {
                kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
                r2 = [];
                d1 = [];
                queues = [];
                ai = [];
                durable_objects = [];
                services = [];
              };
          };
    }
  in
  let state : Thunder_cli_lib.Cloudflare_state.t =
    {
      Thunder_cli_lib.Cloudflare_state.empty with
      account_id = Some "acct-1";
      worker =
        Some
          {
            script_name = Some "demo-app";
            bootstrapped = true;
            last_deploy_at = Some "2026-04-04T12:00:00Z";
          };
      resources =
        [ { kind = "kv"; binding = "MY_KV"; name = Some "demo-kv"; identifier = Some "kv-1"; managed = true } ];
    }
  in
  let ops : Thunder_cli_lib.Cloudflare_status.ops =
    {
      account_id = (fun () -> Ok (Some "acct-1"));
      kv_resources = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-kv"; identifier = Some "kv-1" } ]);
      r2_resources = (fun () -> Ok []);
      d1_resources = (fun () -> Ok []);
      queue_resources = (fun () -> Ok []);
      worker_exists = (fun name -> Ok (name = "demo-app"));
    }
  in
  let status = Thunder_cli_lib.Cloudflare_status.run ~ops config state in
  assert_true "cloudflare status run healthy" status.ok;
  assert_true "cloudflare status run resource healthy" (List.hd status.resources).healthy

let () =
  let config : Thunder_cli_lib.Thunder_config.t =
    {
      Thunder_cli_lib.Thunder_config.empty with
      cloudflare =
        Some
          {
            mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
            bootstrap_worker = Some true;
            resources =
              {
                kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
                r2 = [];
                d1 = [];
                queues = [];
                ai = [];
                durable_objects = [];
                services = [];
              };
          };
    }
  in
  let status =
    Thunder_cli_lib.Cloudflare_status.run
      ~ops:
        {
          account_id = (fun () -> Ok (Some "acct-1"));
          kv_resources = (fun () -> Ok []);
          r2_resources = (fun () -> Ok []);
          d1_resources = (fun () -> Ok []);
          queue_resources = (fun () -> Ok []);
          worker_exists = (fun _ -> Ok false);
        }
      config Thunder_cli_lib.Cloudflare_state.empty
  in
  assert_true "cloudflare status detects drift" (not status.ok)

let () =
  let config : Thunder_cli_lib.Thunder_config.t =
    {
      Thunder_cli_lib.Thunder_config.empty with
      cloudflare =
        Some
          {
            mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
            bootstrap_worker = Some true;
            resources = { kv = []; r2 = []; d1 = []; queues = []; ai = []; durable_objects = []; services = [] };
          };
    }
  in
  let state : Thunder_cli_lib.Cloudflare_state.t =
    {
      Thunder_cli_lib.Cloudflare_state.empty with
      account_id = Some "acct-old";
      resources =
        [ { kind = "kv"; binding = "MY_KV"; name = Some "demo-kv"; identifier = Some "kv-1"; managed = true } ];
    }
  in
  let status =
    Thunder_cli_lib.Cloudflare_status.run
      ~ops:
        {
          account_id = (fun () -> Ok (Some "acct-new"));
          kv_resources = (fun () -> Ok []);
          r2_resources = (fun () -> Ok []);
          d1_resources = (fun () -> Ok []);
          queue_resources = (fun () -> Ok []);
          worker_exists = (fun _ -> Ok false);
        }
      config state
  in
  assert_true "cloudflare status account mismatch fails" (not status.ok);
  assert_true "cloudflare status account mismatch recorded"
    (List.exists (fun msg -> contains_substring msg "account mismatch") status.errors);
  assert_true "cloudflare status warns on stale state"
    (List.exists (fun msg -> contains_substring msg "no longer declared") status.warnings)

let () =
  with_temp_dir "thunder-status-config" (fun dir ->
      let wrangler_path = Filename.concat dir "wrangler.toml" in
      write_file wrangler_path "name = \"demo-app\"\naccount_id = \"acct-from-config\"\n";
      let config : Thunder_cli_lib.Thunder_config.t =
        {
          Thunder_cli_lib.Thunder_config.empty with
          wrangler_template_path = Some wrangler_path;
          cloudflare =
            Some
              {
                mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
                bootstrap_worker = Some true;
                resources = { kv = []; r2 = []; d1 = []; queues = []; ai = []; durable_objects = []; services = [] };
              };
        }
      in
      let status =
        with_cwd dir (fun () ->
            Thunder_cli_lib.Cloudflare_status.run
              ~ops:
                {
                  account_id = (fun () -> Ok None);
                  kv_resources = (fun () -> Error "kv should not be queried");
                  r2_resources = (fun () -> Error "r2 should not be queried");
                  d1_resources = (fun () -> Error "d1 should not be queried");
                  queue_resources = (fun () -> Error "queue should not be queried");
                  worker_exists = (fun _ -> Ok true);
                }
              config Thunder_cli_lib.Cloudflare_state.empty)
      in
      assert_eq "cloudflare status falls back to wrangler account id" "acct-from-config"
        (Option.get status.account_id))

let () =
  let config : Thunder_cli_lib.Thunder_config.t =
    {
      Thunder_cli_lib.Thunder_config.empty with
      cloudflare =
        Some
          {
            mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
            bootstrap_worker = Some true;
            resources =
              {
                kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
                r2 = [ { binding = "FILES"; bucket = "demo-files" } ];
                d1 = [ { binding = "DB"; name = "demo-db" } ];
                queues = [ { binding = "JOBS"; name = "demo-jobs" } ];
                ai = [ { binding = "AI" } ];
                durable_objects = [ { binding = "MY_DO"; class_name = "MyDurableObject" } ];
                services = [ { binding = "API"; service = "demo-service" } ];
              };
          };
    }
  in
  let ops : Thunder_cli_lib.Cloudflare_provision.ops =
    {
      create_kv = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = Some "kv-1" });
      list_kv = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-kv"; identifier = Some "kv-1" } ]);
      create_r2 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_r2 = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-files"; identifier = None } ]);
      create_d1 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = Some "d1-1" });
      list_d1 = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-db"; identifier = Some "d1-1" } ]);
      create_queue = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = Some "queue-1" });
      list_queue = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-jobs"; identifier = Some "queue-1" } ]);
    }
  in
  match
    Thunder_cli_lib.Cloudflare_provision.run ~account_id:"acct-1" ~worker_name:"demo-app"
      ~timestamp:"2026-04-04T12:00:00Z" ~ops config Thunder_cli_lib.Cloudflare_state.empty
  with
  | Error e -> failwith e
  | Ok (state, steps) ->
      assert_eq "provision state account" "acct-1" (Option.get state.account_id);
      assert_eq "provision worker script" "demo-app"
        (Option.get (Option.get state.worker).script_name);
      assert_true "provision created kv"
        (List.exists
           (fun step ->
             step.Thunder_cli_lib.Cloudflare_provision.kind = "kv"
             && step.action = Thunder_cli_lib.Cloudflare_provision.Create)
           steps);
      assert_true "provision wires ai"
        (List.exists
           (fun step ->
             step.Thunder_cli_lib.Cloudflare_provision.kind = "ai"
             && step.action = Thunder_cli_lib.Cloudflare_provision.Wire)
           steps);
      assert_true "provision adopts service"
        (List.exists
           (fun step ->
             step.Thunder_cli_lib.Cloudflare_provision.kind = "service"
             && step.action = Thunder_cli_lib.Cloudflare_provision.Adopt)
           steps);
      assert_true "provision records resources" (List.length state.resources = 7)

let () =
  with_temp_path "thunder-provision-state" (fun state_path ->
      let config : Thunder_cli_lib.Thunder_config.t =
        {
          Thunder_cli_lib.Thunder_config.empty with
          cloudflare =
            Some
              {
                mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
                bootstrap_worker = Some true;
                resources =
                  {
                    kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
                    r2 = [];
                    d1 = [];
                    queues = [];
                    ai = [];
                    durable_objects = [];
                    services = [];
                  };
              };
        }
      in
      let ops : Thunder_cli_lib.Cloudflare_provision.ops =
        {
          create_kv = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = Some "kv-1" });
          list_kv = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-kv"; identifier = Some "kv-1" } ]);
          create_r2 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
          list_r2 = (fun () -> Ok []);
          create_d1 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
          list_d1 = (fun () -> Ok []);
          create_queue = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
          list_queue = (fun () -> Ok []);
        }
      in
      match
        Thunder_cli_lib.Cloudflare_provision.run_and_write ~account_id:"acct-1"
          ~worker_name:"demo-app" ~timestamp:"2026-04-04T12:00:00Z" ~ops ~state_path config
          Thunder_cli_lib.Cloudflare_state.empty
      with
      | Error e -> failwith e
      | Ok (_state, _steps) ->
          let persisted = Thunder_cli_lib.Cloudflare_state.read_if_exists ~path:state_path in
          assert_eq "provision persisted account" "acct-1" (Option.get persisted.account_id);
          assert_true "provision persisted kv resource" (List.length persisted.resources = 1))

let () =
  let config : Thunder_cli_lib.Thunder_config.t =
    {
      Thunder_cli_lib.Thunder_config.empty with
      cloudflare =
        Some
          {
            mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
            bootstrap_worker = Some true;
            resources =
              {
                kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
                r2 = [];
                d1 = [];
                queues = [];
                ai = [];
                durable_objects = [];
                services = [];
              };
          };
    }
  in
  let state : Thunder_cli_lib.Cloudflare_state.t =
    {
      Thunder_cli_lib.Cloudflare_state.empty with
      resources =
        [ { kind = "kv"; binding = "MY_KV"; name = Some "demo-kv"; identifier = Some "kv-1"; managed = true } ];
    }
  in
  let ops : Thunder_cli_lib.Cloudflare_provision.ops =
    {
      create_kv = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = Some "new-id" });
      list_kv = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-kv"; identifier = Some "kv-1" } ]);
      create_r2 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_r2 = (fun () -> Ok []);
      create_d1 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_d1 = (fun () -> Ok []);
      create_queue = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_queue = (fun () -> Ok []);
    }
  in
  match Thunder_cli_lib.Cloudflare_provision.run ~ops config state with
  | Error e -> failwith e
  | Ok (_state, steps) ->
      assert_true "provision reuses existing kv"
        (List.exists
           (fun step ->
             step.Thunder_cli_lib.Cloudflare_provision.kind = "kv"
             && step.action = Thunder_cli_lib.Cloudflare_provision.Reuse)
           steps)

let () =
  let config : Thunder_cli_lib.Thunder_config.t =
    {
      Thunder_cli_lib.Thunder_config.empty with
      cloudflare =
        Some
          {
            mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
            bootstrap_worker = Some true;
            resources = { kv = []; r2 = []; d1 = []; queues = []; ai = []; durable_objects = []; services = [] };
          };
    }
  in
  let state : Thunder_cli_lib.Cloudflare_state.t =
    { Thunder_cli_lib.Cloudflare_state.empty with account_id = Some "acct-old" }
  in
  let ops : Thunder_cli_lib.Cloudflare_provision.ops =
    {
      create_kv = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = Some "kv-1" });
      list_kv = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-kv"; identifier = Some "kv-1" } ]);
      create_r2 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_r2 = (fun () -> Ok []);
      create_d1 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_d1 = (fun () -> Ok []);
      create_queue = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_queue = (fun () -> Ok []);
    }
  in
  match Thunder_cli_lib.Cloudflare_provision.run ~account_id:"acct-new" ~ops config state with
  | Ok _ -> failwith "expected provision account mismatch error"
  | Error msg -> assert_true "provision mismatch message" (contains_substring msg "account mismatch")

let () =
  let config : Thunder_cli_lib.Thunder_config.t =
    {
      Thunder_cli_lib.Thunder_config.empty with
      cloudflare =
        Some
          {
            mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
            bootstrap_worker = Some true;
            resources =
              {
                kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
                r2 = [];
                d1 = [];
                queues = [];
                ai = [];
                durable_objects = [];
                services = [];
              };
          };
    }
  in
  let ops : Thunder_cli_lib.Cloudflare_provision.ops =
    {
      create_kv = (fun ~name:_ -> Error "Namespace already exists");
      list_kv = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-kv"; identifier = Some "kv-1" } ]);
      create_r2 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_r2 = (fun () -> Ok []);
      create_d1 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_d1 = (fun () -> Ok []);
      create_queue = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
      list_queue = (fun () -> Ok []);
    }
  in
  match Thunder_cli_lib.Cloudflare_provision.run ~ops config Thunder_cli_lib.Cloudflare_state.empty with
  | Error e -> failwith e
  | Ok (state, steps) ->
      assert_eq "already-exists reused id" "kv-1" (Option.get (List.hd state.resources).identifier);
      assert_true "already-exists action becomes reuse"
        (List.exists
           (fun step ->
             step.Thunder_cli_lib.Cloudflare_provision.kind = "kv"
             && step.action = Thunder_cli_lib.Cloudflare_provision.Reuse)
           steps)

let () =
  let config : Thunder_cli_lib.Thunder_config.cloudflare =
    {
      mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
      bootstrap_worker = Some true;
      resources =
        {
          kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
          r2 = [ { binding = "FILES"; bucket = "demo-files" } ];
          d1 = [ { binding = "DB"; name = "demo-db" } ];
          queues = [ { binding = "JOBS"; name = "demo-jobs" } ];
          ai = [ { binding = "AI" } ];
          durable_objects = [ { binding = "MY_DO"; class_name = "MyDurableObject" } ];
          services = [ { binding = "API"; service = "demo-service" } ];
        };
    }
  in
  let state : Thunder_cli_lib.Cloudflare_state.t =
    {
      Thunder_cli_lib.Cloudflare_state.empty with
      resources =
        [ { kind = "kv"; binding = "MY_KV"; name = Some "demo-kv"; identifier = Some "kv-1"; managed = true };
          { kind = "r2"; binding = "FILES"; name = Some "demo-files"; identifier = None; managed = true };
          { kind = "d1"; binding = "DB"; name = Some "demo-db"; identifier = Some "d1-1"; managed = true };
          { kind = "queue"; binding = "JOBS"; name = Some "demo-jobs"; identifier = Some "queue-1"; managed = true };
          { kind = "ai"; binding = "AI"; name = Some "AI"; identifier = None; managed = true };
          { kind = "durable_object"; binding = "MY_DO"; name = Some "MyDurableObject"; identifier = None; managed = true };
          { kind = "service"; binding = "API"; name = Some "demo-service"; identifier = None; managed = false } ];
    }
  in
  let template =
    "name = \"demo-app\"\nmain = \"worker_runtime/index.mjs\"\naccount_id = \"acct-1\"\n"
  in
  match
    Thunder_cli_lib.Cloudflare_wrangler_config.render_managed ~config ~state ~template
  with
  | Error e -> failwith e
  | Ok rendered ->
      assert_true "rendered kv block" (contains_substring rendered "[[kv_namespaces]]");
      assert_true "rendered r2 block" (contains_substring rendered "[[r2_buckets]]");
      assert_true "rendered d1 block" (contains_substring rendered "[[d1_databases]]");
      assert_true "rendered queue block" (contains_substring rendered "[[queues.producers]]");
      assert_true "rendered ai block" (contains_substring rendered "[ai]");
      assert_true "rendered durable object block"
        (contains_substring rendered "[[durable_objects.bindings]]");
      assert_true "rendered sqlite durable object migration"
        (contains_substring rendered "new_sqlite_classes");
      assert_true "rendered service block" (contains_substring rendered "[[services]]")

let () =
  with_temp_file "thunder-managed-wrangler" "name = \"demo-app\"\n" (fun config_path ->
      let config : Thunder_cli_lib.Thunder_config.cloudflare =
        {
          mode = Some Thunder_cli_lib.Thunder_config.Dev_test;
          bootstrap_worker = Some true;
          resources =
            {
              kv = [ { binding = "MY_KV"; name = "demo-kv" } ];
              r2 = [];
              d1 = [];
              queues = [];
              ai = [];
              durable_objects = [];
              services = [];
            };
        }
      in
      let state : Thunder_cli_lib.Cloudflare_state.t =
        {
          Thunder_cli_lib.Cloudflare_state.empty with
          resources =
            [ { kind = "kv"; binding = "MY_KV"; name = Some "demo-kv"; identifier = Some "kv-1"; managed = true } ];
        }
      in
      match
        Thunder_cli_lib.Cloudflare_wrangler_config.apply_to_file ~config ~state ~path:config_path
      with
      | Error e -> failwith e
      | Ok rendered ->
          assert_true "apply_to_file writes managed marker"
            (contains_substring rendered "# BEGIN thunder-managed-kv"))

let () =
  with_temp_path "thunder-bootstrap-state" (fun state_path ->
      let state = Thunder_cli_lib.Cloudflare_state.empty in
      let ops : Thunder_cli_lib.Cloudflare_bootstrap.ops =
        {
          deploy_worker =
            (fun ~workdir:_ ~config_path:_ ~runtime_path:_ ->
              { Thunder_cli_lib.Wrangler.status = Unix.WEXITED 0; stdout = "ok"; stderr = "" });
        }
      in
      match
        Thunder_cli_lib.Cloudflare_bootstrap.run ~timestamp:"2026-04-04T12:00:00Z" ~ops
          ~worker_name:"demo-app" ~config_path:"wrangler.toml" ~state_path:state_path state
      with
      | Error e -> failwith e
      | Ok updated ->
          assert_true "bootstrap marks worker bootstrapped"
            (Option.get updated.worker).bootstrapped;
          assert_eq "bootstrap persists worker name" "demo-app"
            (Option.get (Option.get updated.worker).script_name))

let () =
  with_temp_dir "thunder-cloudflare-command" (fun dir ->
      let config_path = Filename.concat dir "thunder.json" in
      let wrangler_path = Filename.concat dir "wrangler.toml" in
      write_file config_path
        "{\"wrangler_template_path\":\"wrangler.toml\",\"cloudflare\":{\"mode\":\"dev_test\",\"bootstrap_worker\":false,\"resources\":{\"kv\":[{\"binding\":\"MY_KV\",\"name\":\"demo-kv\"}],\"r2\":[],\"d1\":[],\"queues\":[],\"ai\":[],\"durable_objects\":[],\"services\":[]}}}\n";
      write_file wrangler_path "name = \"demo-app\"\naccount_id = \"acct-1\"\n";
      with_cwd dir (fun () ->
          let ops : Thunder_cli_lib.Cloudflare_commands.provision_ops =
            {
              account_id = (fun () -> Ok (Some "acct-1"));
              provision =
                {
                  create_kv = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = Some "kv-1" });
                  list_kv = (fun () -> Ok [ { Thunder_cli_lib.Wrangler.name = "demo-kv"; identifier = Some "kv-1" } ]);
                  create_r2 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
                  list_r2 = (fun () -> Ok []);
                  create_d1 = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
                  list_d1 = (fun () -> Ok []);
                  create_queue = (fun ~name -> Ok { Thunder_cli_lib.Wrangler.name; identifier = None });
                  list_queue = (fun () -> Ok []);
                };
              build_worker = (fun () -> Ok ());
              bootstrap =
                {
                  deploy_worker =
                    (fun ~workdir:_ ~config_path:_ ~runtime_path:_ ->
                      { Thunder_cli_lib.Wrangler.status = Unix.WEXITED 0; stdout = "ok"; stderr = "" });
                };
            }
          in
          match Thunder_cli_lib.Cloudflare_commands.run_provision_with ~debug:false ~ops ~config_path with
          | Error e -> failwith e
          | Ok msg ->
              assert_true "provision command summary" (contains_substring msg "Cloudflare provision complete");
              assert_true "provision command status hint"
                (contains_substring msg "thunder cloudflare status --pretty");
              let wrangler =
                let ic = open_in wrangler_path in
                Fun.protect ~finally:(fun () -> close_in_noerr ic)
                  (fun () -> really_input_string ic (in_channel_length ic))
              in
              assert_true "provision command patched wrangler"
                (contains_substring wrangler "# BEGIN thunder-managed-kv")))

let () =
  with_temp_file "thunder-config-invalid" "{\"compile_target\":\"lua\"}\n"
    (fun config_path ->
      match Thunder_cli_lib.Thunder_config.read ~config_path with
      | Ok _ -> failwith "expected invalid compile target error"
      | Error msg ->
          assert_true "invalid compile target message"
            (contains_substring msg "Unsupported compile_target: lua"))

let () =
  with_temp_dir "thunder-layout" (fun dir ->
      write_file (Filename.concat dir "thunder.json")
        "{\"compile_target\":\"wasm\",\"compiled_runtime_path\":\"build/runtime.mjs\",\"wrangler_template_path\":\"config/wrangler.toml\",\"deploy_dir\":\".thunder/deploy\"}\n";
      with_cwd dir (fun () ->
          let layout = Thunder_cli_lib.Project_layout.default () in
          assert_true "layout compile target wasm"
            (layout.Thunder_cli_lib.Project_layout.compile_target
           = Thunder_cli_lib.Project_layout.Wasm);
          assert_eq "layout runtime path" "build/runtime.mjs"
            layout.Thunder_cli_lib.Project_layout.compiled_runtime_path;
          assert_eq "layout manifest path" "build/manifest.json"
            layout.Thunder_cli_lib.Project_layout.manifest_path;
          assert_eq "layout wasm assets dir" "build/thunder_runtime.assets"
            (Option.get layout.Thunder_cli_lib.Project_layout.assets_dir);
          assert_eq "layout wrangler path" "config/wrangler.toml"
            layout.Thunder_cli_lib.Project_layout.wrangler_template_path));
  ()

let () =
  with_temp_dir "thunder-layout-default-js" (fun dir ->
      with_cwd dir (fun () ->
          match Thunder_cli_lib.Project_layout.default_result () with
          | Error e -> failwith e
          | Ok layout ->
              assert_true "layout default compile target js"
                (layout.Thunder_cli_lib.Project_layout.compile_target
               = Thunder_cli_lib.Project_layout.Js);
              assert_true "layout js has no assets dir"
                (layout.Thunder_cli_lib.Project_layout.assets_dir = None)))

let () =
  with_temp_dir "thunder-layout-override" (fun dir ->
      write_file (Filename.concat dir "thunder.json") "{\"compile_target\":\"wasm\"}\n";
      with_cwd dir (fun () ->
          match
            Thunder_cli_lib.Project_layout.with_overrides_result
              ~compile_target:Thunder_cli_lib.Project_layout.Js ()
          with
          | Error e -> failwith e
          | Ok layout ->
              assert_true "layout override prefers cli target"
                (layout.Thunder_cli_lib.Project_layout.compile_target
               = Thunder_cli_lib.Project_layout.Js);
              assert_true "layout override js omits assets dir"
                (layout.Thunder_cli_lib.Project_layout.assets_dir = None)))

let () =
  with_temp_dir "thunder-stage-js" (fun dir ->
      let runtime_dir = Filename.concat dir "worker_runtime" in
      let dist_dir = Filename.concat dir "dist/worker" in
      let deploy_dir = Filename.concat dir "deploy" in
      Unix.mkdir runtime_dir 0o755;
      Unix.mkdir (Filename.concat dir "dist") 0o755;
      Unix.mkdir dist_dir 0o755;
      let runtime_path = Filename.concat runtime_dir "index.mjs" in
      let request_context_path = Filename.concat runtime_dir "request_context.mjs" in
      let binding_rpc_path = Filename.concat runtime_dir "binding_rpc.mjs" in
      let app_abi_path = Filename.concat runtime_dir "app_abi.mjs" in
      let js_backend_path = Filename.concat runtime_dir "compiled_js_runtime_backend.mjs" in
      let backend_path = Filename.concat runtime_dir "compiled_runtime_backend.mjs" in
      let bootstrap_path = Filename.concat runtime_dir "compiled_runtime_bootstrap.mjs" in
      let compiled_runtime_path = Filename.concat dist_dir "thunder_runtime.mjs" in
      let manifest_path = Filename.concat dist_dir "manifest.json" in
      let wrangler_path = Filename.concat dir "wrangler.toml" in
      write_file runtime_path "export default {}\n";
      write_file request_context_path "export function enterRequestContext() {}\n";
      write_file binding_rpc_path "export default {}\n";
      write_file app_abi_path "export async function init() { return {}; }\n";
      write_file js_backend_path "export async function initCompiledJsRuntimeBackend() { return {}; }\n";
      write_file backend_path "export async function initCompiledRuntimeBackend() { return {}; }\n";
      write_file bootstrap_path "export async function initializeCompiledRuntime() { return {}; }\n";
      write_file compiled_runtime_path "export default {}\n";
      write_file manifest_path
        "{\"abi_version\":1,\"app_id\":\"js-app\",\"runtime_kind\":\"js\",\"runtime_entry\":\"../../worker_runtime/index.mjs\",\"app_abi\":\"../../worker_runtime/app_abi.mjs\",\"compiled_runtime_backend\":\"../../worker_runtime/compiled_runtime_backend.mjs\",\"compiled_runtime\":\"thunder_runtime.mjs\"}\n";
      write_file wrangler_path "name = \"test\"\nmain = \"ignored.mjs\"\n";
      match
        Thunder_cli_lib.Deploy_layout.stage ~deploy_dir ~wrangler_template_path:wrangler_path
          ~manifest_path ~framework_root:dir
      with
      | Error e -> failwith e
      | Ok staged ->
          assert_true "stage js runtime copied" (Sys.file_exists staged.runtime_path);
          assert_true "stage js app abi copied" (Sys.file_exists staged.app_abi_path);
          assert_true "stage js request context copied"
            (Sys.file_exists (Filename.concat deploy_dir "worker_runtime/request_context.mjs"));
          assert_true "stage js binding rpc copied"
            (Sys.file_exists (Filename.concat deploy_dir "worker_runtime/binding_rpc.mjs"));
          assert_true "stage js backend copied"
            (Sys.file_exists
               (Filename.concat deploy_dir "worker_runtime/compiled_js_runtime_backend.mjs"));
          assert_true "stage js bootstrap omitted" (staged.bootstrap_path = None);
          assert_true "stage js assets omitted" (staged.assets_dir = None))

let () =
  with_temp_dir "thunder-scaffold" (fun dir ->
      let destination = Filename.concat dir "demo-app" in
      match Thunder_cli_lib.Scaffold.create_project ~destination ~project_name:"demo-app" with
      | Error e -> failwith e
      | Ok () ->
          let read path =
            let ic = open_in path in
            Fun.protect ~finally:(fun () -> close_in_noerr ic)
              (fun () -> really_input_string ic (in_channel_length ic))
          in
          assert_true "scaffold dune-project"
            (Sys.file_exists (Filename.concat destination "dune-project"));
          assert_true "scaffold thunder config"
            (Sys.file_exists (Filename.concat destination "thunder.json"));
          assert_true "scaffold app routes"
            (Sys.file_exists (Filename.concat destination "app/routes.ml"));
          assert_true "scaffold bin main"
            (Sys.file_exists (Filename.concat destination "bin/main.ml"));
          assert_true "scaffold worker entry"
            (Sys.file_exists (Filename.concat destination "worker/entry.ml"));
          assert_true "scaffold test dune"
            (Sys.file_exists (Filename.concat destination "test/dune"));
          assert_true "scaffold framework home"
            (Sys.file_exists (Filename.concat destination "vendor/thunder-framework/dune-project"));
          assert_true "scaffold local runtime host"
            (Sys.file_exists (Filename.concat destination "worker_runtime/index.mjs"));
          assert_true "scaffold root dune references installed thunder binary"
            (contains_substring (read (Filename.concat destination "dune"))
               "%{bin:thunder}");
          assert_true "scaffold root dune builds js runtime"
            (contains_substring (read (Filename.concat destination "dune"))
               "js_of_ocaml");
          assert_true "scaffold thunder config defaults to js"
            (contains_substring (read (Filename.concat destination "thunder.json"))
               "\"compile_target\": \"js\"");
          assert_true "scaffold thunder config includes cloudflare mode"
            (contains_substring (read (Filename.concat destination "thunder.json"))
               "\"mode\": \"dev_test\"");
          assert_true "worker entry exports app"
            (contains_substring (read (Filename.concat destination "worker/entry.ml"))
               "Entry.export app");
          assert_true "runtime bundle includes development manifest"
            (Sys.file_exists (Filename.concat destination "worker_runtime/development_manifest.mjs"));
          let dune_file = read (Filename.concat destination "dune") in
          assert_true "preview publish uses installed thunder binary"
            (contains_substring dune_file "%{bin:thunder}");
          assert_true "wrangler template uses nodejs_als"
            (contains_substring (read (Filename.concat destination "wrangler.toml"))
               "compatibility_flags = [\"nodejs_als\"]");
          assert_true "scaffold readme mentions cloudflare provision"
            (contains_substring (read (Filename.concat destination "README.md"))
               "thunder cloudflare provision");
          assert_true "scaffold readme mentions cloudflare status"
            (contains_substring (read (Filename.concat destination "README.md"))
               "thunder cloudflare status --pretty");
          assert_true "routes mention edit app routes"
            (contains_substring (read (Filename.concat destination "app/routes.ml"))
               "Edit app/routes.ml to start building.");
          assert_true "routes include Thunder worker bindings overview"
            (contains_substring (read (Filename.concat destination "app/routes.ml"))
               "Thunder.Worker.KV");
          assert_true "routes include bindings route"
            (contains_substring (read (Filename.concat destination "app/routes.ml"))
               "Thunder.get \"/bindings\"");
          assert_true "routes scaffold styled landing page"
            (contains_substring (read (Filename.concat destination "app/routes.ml"))
               "radial-gradient(circle at 70% 28%"));
  ()

let () =
  with_temp_dir "thunder-init" (fun dir ->
      match Thunder_cli_lib.Scaffold.init_project ~destination:dir ~project_name:"demo-app" with
      | Error e -> failwith e
      | Ok () ->
          assert_true "init thunder config"
            (Sys.file_exists (Filename.concat dir "thunder.json"));
          assert_true "init worker entry"
            (Sys.file_exists (Filename.concat dir "worker/entry.ml")));
  ()

let () =
  let info =
    Thunder_cli_lib.Wrangler.parse_preview_info
      ~stdout:
        "Upload complete\nWorker Version ID: 4f9f4f4a\nPreview URL: https://edge.example.workers.dev"
      ~stderr:""
  in
  assert_eq "parsed version" "4f9f4f4a" (Option.get info.version_id);
  assert_eq "parsed url" "https://edge.example.workers.dev"
    (Option.get info.preview_url)

let () =
  let info =
    Thunder_cli_lib.Wrangler.parse_preview_info
      ~stdout:
        "Upload complete\nVersion ID: 4f9f4f4a\n"
      ~stderr:""
  in
  assert_eq "parsed legacy version" "4f9f4f4a" (Option.get info.version_id)

let () =
  let account_id =
    Thunder_cli_lib.Wrangler.parse_account_id
      ~stdout:{|You are logged in with an API Token, associated with the email sam@example.com.
Account Name: Personal
Account ID: abc123
|}
      ~stderr:""
  in
  assert_eq "parsed account id" "abc123" (Option.get account_id)

let () =
  match
    Thunder_cli_lib.Wrangler.extract_json_payload
      ~stdout:""
      ~stderr:
        "⛅️ wrangler 4.80.0\n───────────────────\n[{\"uuid\":\"46244928-52d8-46e0-afd8-1c43babc678a\",\"name\":\"my-first-d1\"}]"
  with
  | Error e -> failwith e
  | Ok payload ->
      assert_true "extract json payload from mixed output"
        (contains_substring payload "my-first-d1")

let () =
  match
    Thunder_cli_lib.Wrangler.parse_resource_refs ~stdout:
      {|[{"title":"demo-kv","id":"kv-1"},{"bucket_name":"demo-files"},{"queue_name":"demo-jobs","id":"queue-1"}]|}
      ~stderr:""
  with
  | Error e -> failwith e
  | Ok resources ->
      assert_eq "parsed resource first name" "demo-kv" (List.nth resources 0).name;
      assert_eq "parsed resource first id" "kv-1" (Option.get (List.nth resources 0).identifier);
      assert_eq "parsed resource second name" "demo-files" (List.nth resources 1).name;
      assert_eq "parsed resource third name" "demo-jobs" (List.nth resources 2).name

let () =
  match
    Thunder_cli_lib.Wrangler.worker_exists ~worker_name:"demo-worker"
      ~stdout:{|[{"script_name":"demo-worker"},{"script_name":"other-worker"}]|}
      ~stderr:""
  with
  | Error e -> failwith e
  | Ok exists -> assert_true "parsed worker exists" exists

let () =
  match
    Thunder_cli_lib.Wrangler.parse_kv_namespace_create ~name:"demo-kv"
      ~stdout:"🌀 Created namespace demo-kv\nNamespace ID: 123e4567-e89b-12d3-a456-426614174000\n"
      ~stderr:""
  with
  | Error e -> failwith e
  | Ok resource ->
      assert_eq "parsed kv create name" "demo-kv" resource.name;
      assert_eq "parsed kv create id" "123e4567-e89b-12d3-a456-426614174000"
        (Option.get resource.identifier)

let () =
  match
    Thunder_cli_lib.Wrangler.parse_kv_namespace_list
      ~stdout:"| title | id |\n| demo-kv | 123e4567-e89b-12d3-a456-426614174000 |\n"
      ~stderr:""
  with
  | Error e -> failwith e
  | Ok resources -> assert_eq "parsed kv list name" "demo-kv" (List.hd resources).name

let () =
  match
    Thunder_cli_lib.Wrangler.parse_r2_bucket_create ~name:"demo-files"
      ~stdout:"Created bucket demo-files successfully\n" ~stderr:""
  with
  | Error e -> failwith e
  | Ok resource -> assert_eq "parsed r2 create name" "demo-files" resource.name

let () =
  match
    Thunder_cli_lib.Wrangler.parse_d1_database_create ~name:"demo-db"
      ~stdout:"✅ Successfully created DB 'demo-db' in region WEUR\nCreated your database using id: 0f1e2d3c-4b5a-6789-0123-456789abcdef\n"
      ~stderr:""
  with
  | Error e -> failwith e
  | Ok resource ->
      assert_eq "parsed d1 create name" "demo-db" resource.name;
      assert_eq "parsed d1 create id" "0f1e2d3c-4b5a-6789-0123-456789abcdef"
        (Option.get resource.identifier)

let () =
  match
    Thunder_cli_lib.Wrangler.parse_queue_list
      ~stdout:"⛅️ wrangler 4.80.0\n───────────────────\n┌──────────────────────────────────┬────────────────┬─────────────────────────────┬─────────────────────────────┬───────────┬───────────┐\n│ id                               │ name           │ created_on                  │ modified_on                 │ producers │ consumers │\n├──────────────────────────────────┼────────────────┼─────────────────────────────┼─────────────────────────────┼───────────┼───────────┤\n│ 2c7aad2f0981464f875b9bc2c7a5e6ba │ demo-jobs      │ 2026-04-04T14:56:44.343371Z │ 2026-04-04T14:56:44.343371Z │ 0         │ 0         │\n└──────────────────────────────────┴────────────────┴─────────────────────────────┴─────────────────────────────┴───────────┴───────────┘"
      ~stderr:""
  with
  | Error e -> failwith e
  | Ok resources ->
      assert_eq "parsed queue list name" "demo-jobs" (List.hd resources).name;
      assert_eq "parsed queue list id" "2c7aad2f0981464f875b9bc2c7a5e6ba"
        (Option.get (List.hd resources).identifier)

let () =
  match
    Thunder_cli_lib.Wrangler.parse_resource_refs
      ~stdout:
        {|[
  {
    "uuid": "46244928-52d8-46e0-afd8-1c43babc678a",
    "name": "my-first-d1",
    "created_at": "2026-04-04T14:56:42.500Z",
    "version": "production",
    "num_tables": 0,
    "file_size": 12288,
    "jurisdiction": null
  }
]|}
      ~stderr:""
  with
  | Error e -> failwith e
  | Ok resources ->
      assert_eq "parsed d1 list name" "my-first-d1" (List.hd resources).name;
      assert_eq "parsed d1 list uuid" "46244928-52d8-46e0-afd8-1c43babc678a"
        (Option.get (List.hd resources).identifier)

let () =
  let kv_create = Thunder_cli_lib.Wrangler.kv_namespace_create_args ~name:"demo-kv" in
  let kv_list = Thunder_cli_lib.Wrangler.kv_namespace_list_args () in
  let r2_create = Thunder_cli_lib.Wrangler.r2_bucket_create_args ~name:"demo-files" in
  let queue_create = Thunder_cli_lib.Wrangler.queue_create_args ~name:"demo-jobs" in
  let d1_list = Thunder_cli_lib.Wrangler.d1_database_list_args () in
  assert_true "kv create args omit json" (not (List.exists (( = ) "--json") kv_create));
  assert_true "kv list args omit json" (not (List.exists (( = ) "--json") kv_list));
  assert_true "r2 create args omit json" (not (List.exists (( = ) "--json") r2_create));
  assert_true "queue create args omit json"
    (not (List.exists (( = ) "--json") queue_create));
  assert_true "d1 list args keep json" (List.exists (( = ) "--json") d1_list)

let () =
  with_temp_file "thunder-artifact" "hello" (fun artifact ->
      with_temp_dir "thunder-preview" (fun dir ->
          let metadata_path = Filename.concat dir "preview.txt" in
          let runtime_dir = Filename.concat dir "worker_runtime" in
          let dist_dir = Filename.concat dir "dist/worker" in
          let assets_dir = Filename.concat dist_dir "thunder_runtime.assets" in
          let runtime_path = Filename.concat runtime_dir "index.mjs" in
          let app_abi_path = Filename.concat runtime_dir "app_abi.mjs" in
          let generated_wasm_assets_path = Filename.concat runtime_dir "generated_wasm_assets.mjs" in
          let bootstrap_path = Filename.concat runtime_dir "compiled_runtime_bootstrap.mjs" in
          let wasm_path = Filename.concat dist_dir "thunder_runtime.mjs" in
          let manifest_path = Filename.concat dist_dir "manifest.json" in
          let wrangler_path = Filename.concat dir "wrangler.toml" in
          Unix.mkdir runtime_dir 0o755;
          Unix.mkdir (Filename.concat dir "dist") 0o755;
          Unix.mkdir dist_dir 0o755;
          Unix.mkdir assets_dir 0o755;
          write_file runtime_path "export default {}\n";
          write_file app_abi_path "export async function init() { return {}; }\nexport async function handle() { return new Response(); }\n";
          write_file generated_wasm_assets_path
            "export function getBundledWasmAsset() { return null; }\nexport function getBundledWasmModule() { return null; }\nexport function listBundledWasmAssets() { return []; }\n";
          write_file (Filename.concat runtime_dir "compiled_runtime_backend.mjs")
            "export async function initCompiledRuntimeBackend() { return {}; }\nexport async function handleCompiledRuntimePayload() { return '{}'; }\nexport function resetCompiledRuntimeBackendForTests() {}\n";
           write_file bootstrap_path "export const compiledRuntimeInitError = null;\n";
           write_file wasm_path "compiled-runtime\n";
           write_file manifest_path
             "{\"abi_version\":1,\"app_id\":\"test-app\",\"runtime_kind\":\"wasm\",\"runtime_entry\":\"../../worker_runtime/index.mjs\",\"app_abi\":\"../../worker_runtime/app_abi.mjs\",\"generated_wasm_assets\":\"../../worker_runtime/generated_wasm_assets.mjs\",\"compiled_runtime_backend\":\"../../worker_runtime/compiled_runtime_backend.mjs\",\"bootstrap_module\":\"../../worker_runtime/compiled_runtime_bootstrap.mjs\",\"compiled_runtime\":\"thunder_runtime.mjs\",\"assets_dir\":\"thunder_runtime.assets\"}\n";
          let artifacts =
            [ artifact; runtime_path; app_abi_path; generated_wasm_assets_path; bootstrap_path;
              wasm_path; manifest_path; wrangler_path; assets_dir ]
          in
          let hash =
            match
              Thunder_cli_lib.Artifact_hash.compute_with_manifest ~manifest_path artifacts
            with
            | Ok value -> value
            | Error e -> failwith e
          in
          write_file (Filename.concat assets_dir "chunk.wasm") "wasm\n";
          write_file wrangler_path "name = \"test\"\nmain = \"worker_runtime/index.mjs\"\n";
          Thunder_cli_lib.Preview_publish.write_metadata ~metadata_path
            {
              artifact_hash = Some hash;
              last_upload_at = None;
              last_version_id = None;
              last_preview_url = None;
              raw_wrangler_output = None;
            };
          with_env_var "CLOUDFLARE_API_TOKEN" (Some "") (fun () ->
              match
                Thunder_cli_lib.Preview_publish.run
                  {
                    metadata_path;
                    artifacts;
                    deploy_dir = Filename.concat dir "deploy";
                    wrangler_template_path = wrangler_path;
                    manifest_path;
                    runtime_path = runtime_path;
                    framework_root = dir;
                    has_durable_objects = false;
                    force = false;
                  }
              with
              | Ok msg -> assert_true "skip unchanged" (String.length msg > 0)
              | Error err -> failwith err)));
  print_endline "cli_tests: ok"
