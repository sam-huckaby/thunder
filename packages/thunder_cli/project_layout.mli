(** Default Thunder app-relative paths used by the CLI. *)

type compile_target = Js | Wasm

type t = {
  compile_target : compile_target;
  compiled_runtime_path : string;
  manifest_path : string;
  assets_dir : string option;
  wrangler_template_path : string;
  deploy_dir : string;
  framework_root : string;
}

val discover_framework_root : unit -> string
(** Discover the best available Thunder framework root for runtime asset lookup. *)

val config_path : unit -> string
(** Default Thunder app config path. *)

val default : unit -> t
(** Default layout expected in a Thunder app workspace. *)

val default_result : unit -> (t, string) result
(** Default layout expected in a Thunder app workspace, preserving config errors. *)

val with_overrides :
  ?compile_target:compile_target ->
  ?compiled_runtime_path:string ->
  ?manifest_path:string ->
  ?wrangler_template_path:string ->
  ?deploy_dir:string ->
  ?framework_root:string ->
  unit ->
  t
(** Default layout with selected overrides applied. *)

val with_overrides_result :
  ?compile_target:compile_target ->
  ?compiled_runtime_path:string ->
  ?manifest_path:string ->
  ?wrangler_template_path:string ->
  ?deploy_dir:string ->
  ?framework_root:string ->
  unit ->
  (t, string) result
(** Default layout with selected overrides applied, preserving config errors. *)
