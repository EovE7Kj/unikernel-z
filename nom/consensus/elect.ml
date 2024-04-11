module Consensus (C : Common) (T : Types) = struct
  let err_election_before_genesis = Errors.new_error "election time/tick before genesis timestamp"

  let get_momentum_before_time chain t =
    match Chain.get_frontier_momentum_store chain |> Storage.get_momentum_before_time t with
    | Some block -> Ok block
    | None -> Errors.new_error ("no block before time " ^ (Common.format_timestamp t))

  type election_result = {
    s_time : Common.timestamp;
    e_time : Common.timestamp;
    producers : Producer_event.t list;
    delegations : types.Pillar_delegation.t list;
    tick : uint64;
  }

  let generate_producers info tick producer_addresses =
    let s_time = info.to_time tick in
    let rec loop s_time producers = function
      | [] -> List.rev producers
      | address :: rest ->
          let e_time = Common.add_duration s_time (Int64.of_int info.block_time) in
          let producer = Producer_event.create ~start_time:s_time ~end_time:e_time ~producer:address in
          loop e_time (producer :: producers) rest
    in
    if List.length producer_addresses = info.node_count then
      loop s_time [] producer_addresses
    else
      None

  let gen_election_result info tick data =
    let s_time = info.to_time tick in
    let e_time = Common.add_duration s_time (Int64.of_int info.block_time) in
    {
      s_time;
      e_time;
      producers = Option.get (generate_producers info tick data.producers);
      delegations = data.delegations;
      tick;
    }

  type election_manager = {
    log : Common.logger;
    context : Context.t;
    chain : Chain.chain;
    algo : Election_algorithm.t;
    db : storage.DB.t;
  }

  let election_by_time em t =
    if Common.before t em.genesis_time then
      Errors.error err_election_before_genesis
    else
      let tick = em.to_tick t in
      election_by_tick em tick

  let election_by_tick em tick =
    if tick < 0L then
      Errors.error err_election_before_genesis
    else
      let proof_time = em.gen_proof_time tick in
      match get_momentum_before_time em.chain proof_time with
      | Error err ->
          Log.error em.log "GetMomentumBeforeTime failed" [("reason", err)];
          Errors.error err
      | Ok proof_block ->
          Log.debug em.log "election" [("tick", Int64.to_string tick); ("hash", proof_block.hash); ("time", Common.format_timestamp proof_time)];
          let data, err = em.generate_producers proof_block in
          match err with
          | Some err ->
              Log.error em.log "generateProducers failed" [("reason", err)];
              Errors.error err
          | None ->
              let result = gen_election_result em.context tick data in
              let register_map =
                List.fold_left (fun acc v -> Map.add v.producing v.name acc) Map.empty data.delegations
              in
              List.iter
                (fun p ->
                  match Map.find p.producer register_map with
                  | Some name -> p.name <- name
                  | None ->
                      Log.error em.log "pillar name-lookup failed" [("reason", "can't find name for address"); ("producing-address", p.producer)];
                      Errors.error ("pillar name-lookup failed. reason: can't find name for producing-address " ^ p.producer))
                result.producers;
              Ok result

  let delegations_by_tick em tick =
    let proof_time = em.gen_proof_time tick in
    match get_momentum_before_time em.chain proof_time with
    | Error err ->
        Log.error em.log "GetMomentumBeforeTime failed" [("reason", err)];
        Errors.error err
    | Ok proof_block ->
        let store = Chain.get_momentum_store em.chain proof_block.identifier in
        let%lwt delegations = Storage.compute_pillar_delegations store in
        Ok delegations

  let gen_proof_time em tick =
    if tick < 2L then
      Common.add_duration em.genesis_time 1L
    else
      let s_time, e_time = em.to_time (Int64.sub tick 2L) in
      e_time

  let generate_producers em proof_block =
    let hash_h = { Hash = proof_block.hash; Height = proof_block.height } in
    let store = Chain.get_momentum_store em.chain hash_h in
    match Storage.get_election_result_by_hash em.db proof_block.hash with
    | Some cached -> Ok cached
    | None ->
        let%lwt delegations_detailed = Storage.compute_pillar_delegations store in
        let delegations = Types.to_pillar_delegation delegations_detailed in
        let context = Context.new_algorithm_context delegations hash_h in
        let final_producers = Election_algorithm.select_producers em.algo context in
        let producers = List.map (fun v -> v.producing) final_producers in
        Log.info em.log "computed producers" [("proof-hash", hash_h.hash); ("proof-height", string_of_int hash_h.height); ("delegations", Types.to_string delegations); ("producers", Types.to_string producers)];
        let election_data = Storage.gen_election_data producers delegations in
        Storage.store_election_result_by_hash em.db proof_block.hash election_data;
        Ok election_data

  let insert_momentum em detailed =
    let block = detailed.Momentum in
    let tick = em.to_tick block.timestamp in
    if tick = 0L then
      ()
    else
      let e_time = em.to_time (Int64.sub tick 1L) in
      match Chain.get_frontier_momentum_store em.chain |> Storage.get_momentum_before_time e_time with
      | Error err -> Log.error em.log "failed to GetMomentumBeforeTime" [("reason", err)]
      | Ok header ->
          match generate_producers em header with
          | Error err -> Log.error em.log "failed to generateProducers" [("reason", err)]
          | Ok _ -> ()

  let delete_momentum _ = ()
end

let new_election_manager chain db =
  let context = Context.new_consensus_context (Chain.get_genesis_momentum chain).timestamp in
  {
    log = Common.consensus_logger;
    context;
    chain;
    algo = Election_algorithm.new_election_algorithm context;
    db;
  }

