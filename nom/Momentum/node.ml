type node = {
  config : config;
  wallet_manager : unit;
  mutable z : unit;
  mutable server : unit;
  mutable rpc_apis : unit;
  stop : unit Lwt.t;
  lock : Lwt_mutex.t;
  mutable data_dir_lock : unit;
}

let new_node conf =
  let stop = Lwt.wait () |> snd in
  let wallet_manager = () in
  let http = () in
  let ws = () in
  let z = () in
  let server = () in
  let node = {
    config = conf;
    wallet_manager;
    z;
    server;
    rpc_apis = ();
    http;
    ws;
    stop;
    lock = Lwt_mutex.create ();
    data_dir_lock = ();
  } in
  printf "preparing node ... ";
  open_data_dir conf;
  start_wallet wallet_manager;
  make_zenon_config conf wallet_manager |> start_zenon;
  let net_config = () in
  let nodes = () in
  node

let start node =
  Lwt_mutex.lock node.lock >>= fun () ->
  start_zenon node.z;
  Lwt_mutex.unlock node.lock;
  Lwt.return ()

let stop node =
  Lwt_mutex.lock node.lock >>= fun () ->
  Lwt.wakeup_later node.stop ();
  Lwt_mutex.unlock node.lock;
  Lwt.return ()

let wait node = Lwt.wait () |> fst

let zenon node = node.z

let config node = node.config

let wallet_manager node = node.wallet_manager

