open Big_int

module type Common = sig
  type ticker
  type ticker_error

  val epoch_ticker : ticker
  val ticker_error : ticker_error
end

module type Types = sig
  type pillar_delegation_detail

  val get_pillar_weights : (string * big_int) list
  val get_pillar_delegations_by_epoch : int -> (string * pillar_delegation_detail) list
end

module Api (C : Common) (T : Types) = struct
  type epoch_pillar_stats = {
    epoch : int;
    block_num : int;
    excepted_block_num : int;
    weight : big_int;
    name : string;
  }

  type epoch_stats = {
    epoch : int;
    pillars : (string, epoch_pillar_stats) Hashtbl.t;
    total_weight : big_int;
    total_blocks : int;
  }

  let epoch_stats_of_json json_string =
    (* Implement JSON parsing here *)

  let get_pillar_weights () =
    T.get_pillar_weights

  let epoch_ticker () =
    C.epoch_ticker

  let epoch_stats epoch =
    (* Implement epoch_stats retrieval here *)

  let get_pillar_delegations_by_epoch epoch =
    T.get_pillar_delegations_by_epoch epoch
end

