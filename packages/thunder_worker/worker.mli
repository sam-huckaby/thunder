(** Worker env/ctx binding access. *)

type env
type ctx
type raw

val create_env : (string * string) list -> env
val create_ctx : string list -> ctx

val env_binding : env -> string -> string option
val ctx_has_feature : ctx -> string -> bool
val request_id : Request.t -> string option

val env : Request.t -> env
val ctx : Request.t -> ctx
val raw_env : Request.t -> raw option
val raw_ctx : Request.t -> raw option
val binding_any : Request.t -> string -> raw option

val with_env : Request.t -> env -> Request.t
val with_ctx : Request.t -> ctx -> Request.t
val with_request_id : Request.t -> string option -> Request.t
val with_raw_env : Request.t -> string option -> Request.t
val with_raw_ctx : Request.t -> string option -> Request.t
