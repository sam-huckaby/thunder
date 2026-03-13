(** Thin wrapper around Wrangler command invocation. *)

type result = {
  status : Unix.process_status;
  stdout : string;
  stderr : string;
}

type preview_info = {
  version_id : string option;
  preview_url : string option;
}

val run : string list -> result
val preview_upload : config_path:string -> result
val deploy_prod : config_path:string -> result
val available : unit -> bool
val parse_preview_info : stdout:string -> stderr:string -> preview_info
