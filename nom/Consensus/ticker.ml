module Consensus = struct
  open Common
  open Chain
  open Nom
  open Errors

  module type ChainTicker = sig
    include Common.Ticker
    val is_finished : uint64 -> bool
    val has_started : uint64 -> bool
    val get_end_block : uint64 -> nom_momentum option * error option
    val get_content : uint64 -> nom_momentum list * error option
  end

  module ChainTicker : ChainTicker = struct
    type chain_ticker = {
      ticker : Common.Ticker.t;
      chain : Chain.chain;
    }

    let create chain ticker =
      { ticker; chain }

    let is_finished ct tick =
      if tick > (1 lsl 62) - 1 then
        failwith "most probably an overflow error"
      else
        let _, e_time = to_time ct.ticker tick in
        match get_frontier_momentum_store ct.chain |> get_frontier_momentum with
        | Some block ->
          let after_or_equal = Timestamp.compare block.timestamp e_time >= 0 in
          after_or_equal
        | None -> false (* consider if you want to handle this case *)

    let has_started ct tick =
      if tick > (1 lsl 62) - 1 then
        failwith "most probably an overflow error"
      else
        let s_time, _ = to_time ct.ticker tick in
        match get_frontier_momentum_store ct.chain |> get_frontier_momentum with
        | Some block ->
          let before = Timestamp.compare block.timestamp s_time < 0 in
          before
        | None -> false (* consider if you want to handle this case *)

    let get_end_block ct tick =
      if tick > (1 lsl 62) - 1 then
        failwith "most probably an overflow error"
      else
        let _, e_time = to_time ct.ticker tick in
        match get_frontier_momentum_store ct.chain |> get_momentum_before_time e_time with
        | Some block -> Some block, None
        | None -> None, Some (Errors.errorf "chainTicker.GetEndBlock failed to get block for tick %Lu endTime %Lu" tick (Timestamp.to_unix e_time))

    let get_content ct tick =
      if tick > (1 lsl 62) - 1 then
        failwith "most probably an overflow error"
      else
        let s_time, _ = to_time ct.ticker tick in
        let end_block, end_error = get_end_block ct tick in
        match end_block with
        | Some end_block ->
          if not (Timestamp.compare end_block.timestamp s_time < 0) then
            let start_block =
              match tick with
              | 0 -> get_genesis_momentum ct.chain
              | _ -> Option.value (get_end_block ct (tick - 1) |> fst) ~default:(failwith "failed to get startBlock for content. Tick")
            in
            if end_block.height = start_block.height then [], None
            else
              let blocks, err = get_frontier_momentum_store ct.chain |> get_momentums_by_height ~inclusive:true ~limit:(end_block.height - start_block.height) (start_block.height + 1) in
              match err with
              | None ->
                if List.length blocks = 0 then [], None
                else
                  let last_block = List.last_exn blocks in
                  if end_block.hash = last_block.hash then blocks, None
                  else Some [], Some (Errors.errorf "chainTicker.GetContent failed expects %s but got %s" (Hash.to_string end_block.hash) (Hash.to_string last_block.hash))
              | Some e -> [], Some e
          else [], None
        | None -> [], end_error
  end
end

