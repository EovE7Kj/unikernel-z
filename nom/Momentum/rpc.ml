module Node = struct
  let start_rpc node =
    if node.config.rpc_http_host <> "" then (
      let config = {
        cors_allowed_origins = node.config.rpc_http_cors;
        vhosts = node.config.rpc_http_virtual_hosts;
        modules = node.config.rpc_endpoints;
        prefix = "";
      } in
      if node.http.set_listen_addr node.config.rpc_http_host node.config.rpc_http_port <> Ok () then
        Error "Failed to set HTTP listen address"
      else if node.http.enable_rpc node.rpc_apis config <> Ok () then
        Error "Failed to enable HTTP RPC"
    );
    if node.config.rpc_ws_host <> "" then (
      let server = ws_server_for_port node config.rpc_ws_port in
      let config = {
        modules = node.config.rpc_endpoints;
        origins = node.config.rpc_ws_origins;
        prefix = "";
      } in
      if server.set_listen_addr node.config.rpc_ws_host node.config.rpc_ws_port <> Ok () then
        Error "Failed to set WebSocket listen address"
      else if server.enable_ws node.rpc_apis config <> Ok () then
        Error "Failed to enable WebSocket RPC"
    );
    if node.http.start () <> Ok () then
      Error "Failed to start HTTP server"
    else
      node.ws.start ()

  let ws_server_for_port node port =
    if node.config.rpc_http_host = "" || node.http.port = port then
      node.http
    else
      node.ws

  let stop_rpc node =
    node.http.stop ();
    node.ws.stop ()
end

