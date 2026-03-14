(** Framework-owned Worker entry/export helpers. *)

val handle_json : Handler.t -> string -> string
(** [handle_json app payload] decodes a Worker ABI request payload, runs [app], and
    returns an encoded response payload. *)

val export : Handler.t -> unit
(** [export app] registers [app] as the global Worker runtime entrypoint. *)
