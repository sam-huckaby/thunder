(** Artifact hashing for preview publish decisions. *)

val compute : string list -> (string, string) result
val compute_with_manifest :
  ?framework_root:string -> manifest_path:string -> string list -> (string, string) result
val read_previous_hash : metadata_path:string -> string option
val write_hash : metadata_path:string -> hash:string -> unit
