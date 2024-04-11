module Consensus (C : Common) (T : Types) = struct
  type algorithm_config = {
    delegations : types.Pillar_delegation.t list;
    hash_h : types.Hash_height.t;
  }

  let new_algorithm_context delegations hash_h = { delegations; hash_h }

  module type ElectionAlgorithm = sig
    val select_producers : algorithm_config -> types.Pillar_delegation.t list
  end

  module ElectionAlgorithmImpl : ElectionAlgorithm = struct
    let group = C.group

    let find_seed context = Int64.of_int context.hash_h.height

    let shuffle_order producers context =
      let random = Random.State.make [|find_seed context|] in
      let perm = Array.of_list producers |> Array.permute ~random in
      Array.to_list perm

    let filter_by_weight context =
      if List.length context.delegations <= group.node_count then
        (context.delegations, [])
      else
        let sorted = List.sort types.compare_pd_by_weight context.delegations in
        let group_a = List.take group.node_count sorted in
        let group_b = List.drop group.node_count sorted in
        (group_a, group_b)

    let filter_random group_a group_b context =
      let total = group.node_count in
      let seed = find_seed context in
      if total <> List.length group_a then begin
        let rec fill_up result =
          if List.length result >= total then
            result
          else
            let random1 = Random.State.make [|seed|] in
            let arr = Array.init (List.length group_a) (fun i -> i) |> Array.permute ~random:random1 in
            let result' = List.rev_append (List.rev_map (fun index -> List.nth group_a index) (Array.to_list arr)) result in
            fill_up result'
        in
        fill_up []
      end else begin
        let top_total = total - group.rand_count in
        let top_index = Array.init (List.length group_a) (fun i -> i) |> Array.permute ~random:(Random.State.make [|seed|]) in
        let top_producers = Array.to_list (Array.sub top_index 0 top_total) |> List.map (fun index -> List.nth group_a index) in
        let remaining_producers = List.rev_append group_b top_producers in
        let random_index = Array.init (List.length group_b) (fun i -> i) |> Array.permute ~random:(Random.State.make [|seed + 1L|]) |> Array.sub 0 group.rand_count in
        let random_producers = Array.to_list random_index |> List.map (fun index -> List.nth group_b index) in
        List.rev_append top_producers random_producers
      end

    let select_producers context =
      let group_a, group_b = filter_by_weight context in
      let producers = filter_random group_a group_b context in
      shuffle_order producers context
  end

  let new_election_algorithm group = ElectionAlgorithmImpl

  let algorithm_config_delegations = List.map Types.to_pillar_delegation T.delegations
  let algorithm_config_hash_h = T.hash_h
  let algorithm_config = { delegations = algorithm_config_delegations; hash_h = algorithm_config_hash_h }
end

