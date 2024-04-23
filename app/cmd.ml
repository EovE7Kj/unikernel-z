open Printf
open Unix

type manager = {
  ctx : Cli.context;
  node : Node.node;
}

let new_node_manager ctx =
  (* make config *)
  let node_config, err = make_config ctx in
  if err <> None then
    raise (Failure (sprintf "Error creating config: %s" (Option.get err)))
  else
    (* make node *)
    let new_node, err = Node.new_node node_config in
    if err <> None then
      raise (Failure (sprintf "Error creating node: %s" (Option.get err)))
    else
      { ctx = ctx; node = new_node }

let start node_manager =
  (* Start up the node *)
  printf "starting znnd\n";
  match Node.start node_manager.node with
  | Error err ->
      printf "failed to start node; reason:%s\n" err;
      printf "failed to start node; reason:%s\n" err;
      exit 1
  | Ok () ->
      printf "znnd successfully started\n";
      printf "*** Node status ***\n";
      let address = Zenon.producer node_manager.node.Zenon.get_coin_base in
      ( match address with
      | None -> printf "* No Pillar configured for current node\n"
      | Some addr -> printf "* Producer address detected: %s\n" addr );

      (* Listening event closes the node *)
      let signal_handler = function
        | SIGINT | SIGTERM | SIGKILL ->
            printf "Shutting down znnd\n";
            ignore (stop node_manager)
        | _ -> ()
      in
      let _ = signal SIGINT signal_handler in
      let _ = signal SIGTERM signal_handler in
      let _ = signal SIGKILL signal_handler in
      try
        ignore (pause ())
      with
      | _ ->
          for i = 10 downto 1 do
            if i > 1 then
              printf
                "Please DO NOT interrupt the shutdown process, panic may \
                 occur. times: %d\n"
                (i - 1);
            ignore (pause ())
          done

and stop node_manager =
  printf "Stopping znnd ...\n";
  match Node.stop node_manager.node with
  | Error err -> printf "Failed to stop node; reason:%s\n" err
  | Ok () -> ()

let () =
  let ctx = Cli.get_context () in
  let node_manager = new_node_manager ctx in
  ignore (start node_manager)

