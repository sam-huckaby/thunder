(** Project scaffolding for generated Thunder apps. *)

val create_project : destination:string -> project_name:string -> (unit, string) result
(** [create_project ~destination ~project_name] creates a new Thunder app skeleton. *)

val init_project : destination:string -> project_name:string -> (unit, string) result
(** [init_project ~destination ~project_name] writes a Thunder app skeleton into an
    existing directory, failing if required files already exist. *)
