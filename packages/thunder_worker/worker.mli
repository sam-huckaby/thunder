(** Worker env/ctx binding access. *)

type env
type ctx

val create_env : (string * string) list -> env
val create_ctx : string list -> ctx

val env_binding : env -> string -> string option

val env : Request.t -> env
val ctx : Request.t -> ctx

val with_env : Request.t -> env -> Request.t
val with_ctx : Request.t -> ctx -> Request.t
