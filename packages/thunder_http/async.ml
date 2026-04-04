type 'a t =
  | Pure of 'a
  | Pending of ((('a, exn) result -> unit) -> unit)

let return value = Pure value
let fail exn = Pending (fun callback -> callback (Error exn))
let make fn = Pending fn

let respond value callback =
  match value with
  | Pure result -> callback (Ok result)
  | Pending fn ->
      (try fn callback with exn -> callback (Error exn))

let bind value fn =
  make (fun callback ->
      respond value (function
        | Ok inner ->
            (try respond (fn inner) callback with exn -> callback (Error exn))
        | Error exn -> callback (Error exn)))

let map value fn =
  bind value (fun inner ->
      try return (fn inner) with exn -> fail exn)

let catch value handler =
  make (fun callback ->
      respond value (function
        | Ok inner -> callback (Ok inner)
        | Error exn ->
            (try respond (handler exn) callback with exn -> callback (Error exn))))

let run value =
  let result = ref None in
  respond value (fun next -> result := Some next);
  match !result with
  | Some (Ok inner) -> inner
  | Some (Error exn) -> raise exn
  | None -> failwith "Thunder.Async.run cannot synchronously resolve a pending computation."
