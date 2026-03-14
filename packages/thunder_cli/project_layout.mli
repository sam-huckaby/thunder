(** Default Thunder app-relative paths used by the CLI. *)

type t = {
  compiled_runtime_path : string;
  manifest_path : string;
  assets_dir : string;
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

val with_overrides :
  ?compiled_runtime_path:string ->
  ?manifest_path:string ->
  ?wrangler_template_path:string ->
  ?deploy_dir:string ->
  ?framework_root:string ->
  unit ->
  t
(** Default layout with selected overrides applied. *)
