open Printf
open Unix

let default_node_config_file_name = "config.json"

let make_config ctx =
  let cfg = Node.default_node_config in

  (* Load config file *)
  let read_config_from_file ctx cfg =
    match Cli.string ctx ConfigFileFlag.name with
    | Some file -> (
        match Sys.file_exists file with
        | true -> (
            match try Some (Json.from_file file) with _ -> None with
            | Some json_conf -> (
                match Node.config_of_json json_conf with
                | Ok cfg -> Ok cfg
                | Error err ->
                    printf "Config malformed: cannot unmarshal the config file content, error: %s\n" err;
                    Error err )
            | None ->
                printf "Config file missing: you can provide a data path using the --data flag or provide a config file using the --config flag, configPath: %s\n" file;
                Error "Config file missing" )
        | false -> (
            (* Second read default settings *)
            let data_path =
              match Cli.string ctx DataPathFlag.name with
              | Some data_dir -> data_dir
              | None -> cfg.data_path
            in
            let config_path = Filename.concat data_path default_node_config_file_name in
            match try Some (Json.from_file config_path) with _ -> None with
            | Some json_conf -> (
                match Node.config_of_json json_conf with
                | Ok cfg -> Ok cfg
                | Error err ->
                    printf "Config malformed: please check, error: %s\n" err;
                    Error err )
            | None ->
                printf "Config file missing: you can provide a data path using the --data flag or provide a config file using the --config flag, configPath: %s\n" config_path;
                Error "Config file missing" ) )
    | None -> Error "Config file path not provided"
  in

  match read_config_from_file ctx cfg with
  | Ok cfg ->
      (* Apply flags, Overwrite the configuration file configuration *)
      apply_flags_to_config ctx cfg;

      (* Make dir paths absolute *)
      ( match Node.make_paths_absolute cfg with
      | Ok () -> ()
      | Error err -> raise (Failure err) );

      (* Config log to file *)
      Common.init_logging cfg.data_path cfg.log_level;

      (* Log config *)
      ( match Node.config_to_json cfg with
      | Ok j -> printf "Using the following znnd config: %s\n" j
      | Error err -> printf "Error serializing configuration: %s\n" err );
      printf "Using the following znnd config: %s\n" (Node.config_to_string cfg);
      log.info "using znnd config" ~config:cfg;
      Ok cfg
  | Error err -> Error err

and apply_flags_to_config ctx cfg =
  Cli.string ctx DataPathFlag.name
  |> Option.iter (fun data_dir -> cfg.data_path <- data_dir);

  (* Wallet *)
  Cli.string ctx WalletDirFlag.name
  |> Option.iter (fun wallet_dir -> cfg.wallet_path <- wallet_dir);

  Cli.string ctx GenesisFileFlag.name
  |> Option.iter (fun genesis_file -> cfg.genesis_file <- genesis_file);

  (* Network Config *)
  Cli.string ctx IdentityFlag.name
  |> Option.iter (fun identity -> cfg.name <- identity);

  Cli.int ctx MaxPeersFlag.name
  |> Option.iter (fun max_peers -> cfg.net.max_peers <- max_peers);

  Cli.int ctx MaxPendingPeersFlag.name
  |> Option.iter (fun max_pending_peers -> cfg.net.max_pending_peers <- max_pending_peers);

  Cli.string ctx ListenHostFlag.name
  |> Option.iter (fun listen_host -> cfg.rpc.http_host <- listen_host);

  Cli.int ctx ListenPortFlag.name
  |> Option.iter (fun listen_port -> cfg.net.listen_port <- listen_port);

  (* Http Config *)
  Cli.bool ctx RPCEnabledFlag.name
  |> Option.iter (fun enable_http -> cfg.rpc.enable_http <- enable_http);

  Cli.string ctx RPCListenAddrFlag.name
  |> Option.iter (fun http_host -> cfg.rpc.http_host <- http_host);

  Cli.int ctx RPCPortFlag.name
  |> Option.iter (fun http_port -> cfg.rpc.http_port <- http_port);

  (* WS Config *)
  Cli.bool ctx WSEnabledFlag.name
  |> Option.iter (fun enable_ws -> cfg.rpc.enable_ws <- enable_ws);

  Cli.string ctx WSListenAddrFlag.name
  |> Option.iter (fun ws_host -> cfg.rpc.ws_host <- ws_host);

  Cli.int ctx WSPortFlag.name
  |> Option.iter (fun ws_port -> cfg.rpc.ws_port <- ws_port);

  (* Log Level Config *)
  Cli.string ctx LogLvlFlag.name
  |> Option.iter (fun log_level -> cfg.log_level <- log_level)

