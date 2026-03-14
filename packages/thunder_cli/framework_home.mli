(** Installed Thunder framework-home helpers. *)

val default_base_dir : unit -> string
(** Default base directory for installed Thunder framework assets. *)

val current_dir : unit -> string
(** Installed framework-home path for the active Thunder version. *)

val versioned_dir : version:string -> string
(** Versioned install path for a specific Thunder release. *)
