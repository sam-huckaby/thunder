(** Parse and resolve Thunder deploy manifests. *)

type t = {
  abi_version : int;
  app_id : string;
  runtime_entry : string;
  app_abi : string;
  generated_wasm_assets : string;
  compiled_runtime_backend : string;
  bootstrap_module : string;
  compiled_runtime : string;
  assets_dir : string;
}

val parse : manifest_path:string -> (t, string) result
val referenced_paths : manifest_path:string -> (string list, string) result
