(** Parse and resolve Thunder deploy manifests. *)

type runtime_kind = Js | Wasm

type t = {
  abi_version : int;
  app_id : string;
  runtime_kind : runtime_kind;
  runtime_entry : string;
  app_abi : string;
  generated_wasm_assets : string option;
  compiled_runtime_backend : string;
  bootstrap_module : string option;
  compiled_runtime : string;
  assets_dir : string option;
}

val parse : manifest_path:string -> (t, string) result
val resolve_reference : framework_root:string -> manifest_path:string -> string -> string
val referenced_paths : framework_root:string -> manifest_path:string -> (string list, string) result
