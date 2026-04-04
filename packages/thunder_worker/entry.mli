(** Framework-owned Worker entry/export helpers. *)

val handle_json : Handler.t -> string -> string
(** [handle_json app payload] decodes a Worker ABI request payload, runs [app], and
    returns an encoded response payload. *)

val handle_json_async : Handler.t -> string -> string Async.t
(** [handle_json_async app payload] decodes a Worker ABI request payload and returns an
    async encoded response payload. *)

val export : Handler.t -> unit
(** [export app] registers [app] as the global Worker runtime entrypoint. *)
