#!/usr/bin/env bash
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fixture_root="${THUNDER_GENERATED_FIXTURE_DIR:-$(mktemp -d)}"
app_dir="$fixture_root/generated-app"

cleanup() {
  if [ "${THUNDER_KEEP_GENERATED_FIXTURE:-0}" = "1" ]; then
    printf 'Generated app fixture kept at %s\n' "$app_dir"
  else
    rm -rf "$fixture_root"
  fi
}

trap cleanup EXIT

cd "$repo_root"
opam exec -- dune build packages/thunder_cli/main.exe

THUNDER_FRAMEWORK_ROOT="$repo_root" opam exec -- dune exec ./packages/thunder_cli/main.exe -- new "$app_dir"

cd "$app_dir"

cat > app/routes.ml <<'EOF'
let bindings_overview _ =
  Thunder.json
    {|{"bindings":["Thunder.Worker.KV","Thunder.Worker.R2","Thunder.Worker.D1","Thunder.Worker.Queues","Thunder.Worker.AI","Thunder.Worker.Service","Thunder.Worker.Durable_object","Thunder.Worker.Generic"]}|}

let cloudflare_demo req =
  let key = Option.value (Thunder.Request.param req "key") ~default:"demo" in
  Thunder.Async.bind (Thunder.Worker.KV.get_text ~binding:"MY_KV" ~key req) (fun kv_value ->
      let kv_json = match kv_value with Some value -> Printf.sprintf "%S" value | None -> "null" in
      Thunder.Async.bind
        (Thunder.Worker.D1.first_json ~binding:"DB"
           ~sql:"select * from demo where id = ?" ~params_json:(Printf.sprintf {|[%S]|} key) req)
        (fun row_json ->
          Thunder.Async.bind
            (Thunder.Worker.Service.fetch_json ~binding:"API" ~url:"https://internal.service/demo" req)
            (fun service_json ->
              Thunder.Async.bind
                (Thunder.Worker.AI.run_json ~binding:"AI" ~model:"@cf/meta/demo"
                   ~input_json:
                     ( {|{"kv":|} ^ kv_json ^ {|,"row":|} ^ row_json ^ {|,"service":|}
                     ^ service_json ^ "}" ) req)
                (fun ai_json ->
                  Thunder.Async.bind
                    (Thunder.Worker.R2.put_text ~binding:"FILES" ~key:(key ^ ".json")
                       ~value:ai_json req)
                    (fun () ->
                      Thunder.Async.bind
                        (Thunder.Worker.Queues.send_json ~binding:"JOBS"
                           ~value_json:(Printf.sprintf {|{"key":%S}|} key) req)
                        (fun () ->
                          Thunder.Async.bind
                            (Thunder.Worker.Durable_object.call_json ~binding:"MY_DO"
                               ~name:key ~method_:"greet" ~args_json:{|["thunder"]|} req)
                            (fun do_json ->
                              Thunder.Async.map
                                (Thunder.Worker.Generic.invoke_json ~binding:"CUSTOM"
                                   ~method_:"ping"
                                   ~args_json:(Printf.sprintf {|[%S]|} key) req)
                                (fun generic_json ->
                                  Thunder.json
                                    ( {|{"kv":|} ^ kv_json ^ {|,"row":|} ^ row_json
                                    ^ {|,"service":|} ^ service_json ^ {|,"ai":|} ^ ai_json
                                    ^ {|,"do":|} ^ do_json ^ {|,"generic":|} ^ generic_json
                                    ^ "}" )))))))))

let app =
  Thunder.router
    [
      Thunder.get "/"
        (Thunder.handler (fun _ ->
             Thunder.html
               {html|
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Thunder Cloudflare Fixture</title>
  </head>
  <body>
    <main>
      <h1>Thunder Generated Fixture</h1>
      <p>This generated app fixture validates Thunder.Worker.* wrapper compilation.</p>
    </main>
  </body>
</html>
|html}));
      Thunder.get "/health"
        (Thunder.handler (fun _ -> Thunder.json "{\"ok\":true}"));
      Thunder.get "/bindings" (Thunder.handler bindings_overview);
      Thunder.get "/cloudflare/:key" (Thunder.handler_async cloudflare_demo);
    ]
EOF

dune build @worker-build
env -u CLOUDFLARE_API_TOKEN dune build

printf 'Generated app fixture verified at %s\n' "$app_dir"
