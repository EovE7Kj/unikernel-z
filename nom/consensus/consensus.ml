module Consensus (C : Common) (T : Types) = struct
  let epoch_duration = 24. *. 60. *. 60. (* seconds in a day *)

  type consensus = {
    log : Common.logger;
    genesis : Common.timestamp;
    chain : Chain.chain;
    testing : bool;
    event_manager : event_manager;
    election_manager : election_manager;
    points : points;
    wg : Common.wait_group;
    closed : unit Lwt.t;
  }

  let frontier_pillar_reader cs =
    {
      momentum_store = Chain.get_frontier_momentum_store cs.chain;
      er = cs.election_manager;
      points = cs.points;
    }

  let fixed_pillar_reader cs identifier =
    {
      momentum_store = Chain.get_momentum_store cs.chain identifier;
      er = cs.election_manager;
      points = cs.points;
    }

  let new_consensus db chain testing : consensus =
    let genesis_timestamp = Chain.get_genesis_momentum chain |> Nom.timestamp_of_momentum in
    let epoch_ticker = Common.new_ticker genesis_timestamp epoch_duration in
    let cache_size =
      (7 * 24 * 60 * 60) / (int_of_float Constants.consensus_config.block_time * Constants.consensus_config.node_count)
    in
    let db_cache = Storage.new_consensus_db db cache_size cache_size in
    let election_manager = new_election_manager chain db_cache in
    {
      log = Common.consensus_logger;
      genesis = genesis_timestamp;
      chain;
      testing;
      event_manager = new_event_manager ();
      election_manager;
      points = new_points election_manager epoch_ticker chain db_cache;
      wg = Common.new_wait_group ();
      closed = Lwt.task ();
    }

  let get_momentum_producer cs timestamp =
    let election, err = Election_manager.election_by_time cs.election_manager timestamp in
    match err with
    | Some err -> Lwt.return_error err
    | None ->
        let open Option in
        let producer =
          Election.producers election |> List.find_opt (fun plan -> plan.start_time = timestamp)
          |> map (fun plan -> plan.producer)
        in
        match producer with
        | Some producer -> Lwt.return_ok producer
        | None -> Lwt.return_error (Failure "couldn't find producer for timestamp")

  let verify_momentum_producer cs momentum =
    let open Option in
    let%lwt expected = get_momentum_producer cs (Nom.timestamp_of_momentum momentum) in
    match expected with
    | Ok expected -> Lwt.return_ok (Nom.producer momentum = expected)
    | Error err -> Lwt.return_error err

  let init _ = Lwt.return_unit

  let start cs =
    Log.info cs.log "starting ..." >>= fun () ->
    let work () =
      let rec loop () =
        let now = Common.clock_now () in
        let tick = Election_manager.to_tick cs.election_manager now in
        let election_result =
          match Election_manager.election_by_tick cs.election_manager tick with
          | Some election -> election
          | None ->
              Log.error cs.log "can't get election result" [ ("time", Common.format_timestamp now) ]
              >>= fun () -> Lwt_unix.sleep 1.0 >>= loop
        in
        let rec process_events = function
          | [] -> Lwt.return_unit
          | event :: rest ->
              if Common.clock_now () > event.end_time then process_events rest
              else
                Lwt_unix.sleep (event.start_time -. Common.clock_now ()) >>= fun () ->
                Event_manager.broadcast_new_producer_event cs.event_manager event
                >>= fun () -> process_events rest
        in
        process_events election_result.producers >>= fun () ->
        let%lwt () = Lwt_unix.sleep (election_result.e_time -. Common.clock_now ()) in
        loop ()
      in
      loop ()
    in
    if not cs.testing then (
      Common.add_wait_group cs.wg 1;
      Lwt.async (fun () -> Lwt.catch (fun () -> work ()) (fun _ -> Lwt.return_unit))
    );
    Chain.register cs.chain cs.points >>= fun () -> Chain.register cs.chain cs.election_manager >>= fun () ->
    Lwt.return_unit

  let stop cs =
    Log.info cs.log "stopping ..." >>= fun () ->
    Chain.un_register cs.chain cs.points >>= fun () -> Chain.un_register cs.chain cs.election_manager >>= fun () ->
    Lwt.wakeup_later cs.closed ();
    Common.wait_group_wait cs.wg >>= fun () -> Lwt.return_unit
end

