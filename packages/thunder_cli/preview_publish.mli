(** Preview publish orchestration. *)

type config = {
  metadata_path : string;
  artifacts : string list;
  deploy_dir : string;
  wrangler_template_path : string;
  manifest_path : string;
  runtime_path : string;
  framework_root : string;
  has_durable_objects : bool;
  force : bool;
}

type metadata = {
  artifact_hash : string option;
  last_upload_at : string option;
  last_version_id : string option;
  last_preview_url : string option;
  raw_wrangler_output : string option;
}

val read_metadata : metadata_path:string -> metadata
val write_metadata : metadata_path:string -> metadata -> unit

val run : config -> (string, string) result
