
let runtime_args_r = ref []
let runtime_args () = !runtime_args_r

module Arg = struct
  type 'a t = { arg : 'a Cmdliner.Term.t; mutable value : 'a option }

  let create arg = { arg; value = None }

  let get t =
    match t.value with
    | None ->
        invalid_arg
          "Functoria_runtime.Arg..get: Called too early. Please delay this \
           call after cmdliner's evaluation."
    | Some v -> v

  let term (type a) (t : a t) =
    let set w = t.value <- Some w in
    Cmdliner.Term.(const set $ t.arg)

  let conv of_string to_string : _ Cmdliner.Arg.conv =
    let pp ppf v = Format.pp_print_string ppf (to_string v) in
    Cmdliner.Arg.conv (of_string, pp)
end

let register t =
  let u = Arg.create t in
  runtime_args_r := Arg.term u :: !runtime_args_r;
  fun () -> Arg.get u

let initialized = ref false
let help_version = 63
let argument_error = 64

let with_argv keys s argv =
  let open Cmdliner in
  if !initialized then ()
  else
    let gather k rest = Term.(const (fun () () -> ()) $ k $ rest) in
    let t = List.fold_right gather keys (Term.const ()) in
    let exits =
      [
        Cmd.Exit.info ~doc:"on success." Cmd.Exit.ok;
        Cmd.Exit.info ~doc:"on Solo5 internal error." 1;
        Cmd.Exit.info ~doc:"on showing this help." help_version;
        Cmd.Exit.info ~doc:"on any argument parsing error." argument_error;
        Cmd.Exit.info
          ~doc:
            "on unexpected internal errors (bugs) while processing the boot \
             parameters."
          Cmd.Exit.internal_error;
        Cmd.Exit.info ~doc:"on OCaml uncaught exception." 255;
      ]
    in
    match Cmd.(eval_value ~argv (Cmd.v (info ~exits s) t)) with
    | Ok (`Ok _) ->
        initialized := true;
        ()
    | Error (`Parse | `Term) -> exit argument_error
    | Error `Exn -> exit Cmd.Exit.internal_error
    | Ok `Help | Ok `Version -> exit help_version
