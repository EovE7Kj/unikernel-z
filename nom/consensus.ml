(* consensus.ml *)

open Lwt
open Lwt_unix

(* Define types *)

module type Chain = sig
  type t
  val get_genesis_momentum : unit -> time
  val get_frontier_momentum_store : unit -> momentum_store
  val get_momentum_store : types.HashHeight -> momentum_store
  val register : unit -> unit
  val unregister : unit -> unit
end

module type Consensus = sig
  type t
  val get_momentum_producer : time -> types.Address Lwt.t
  val verify_momentum_producer : nom_momentum -> bool Lwt.t
  val init : unit -> unit Lwt.t
  val start : unit -> unit Lwt.t
  val stop : unit -> unit Lwt.t
end

module Make (Chain : Chain) : Consensus = struct
  type t = {
    log : common_logger;
    genesis : time;
    chain : Chain.t;
    testing : bool;
    event_manager : event_manager;
    election_manager : election_manager;
    points : points;
    mutable wg : Lwt_unix.file_descr Lwt.t;
    closed : unit Lwt.t;
  }

  let frontier_pillar_reader t =
    let momentum_store = Chain.get_frontier_momentum_store () in
    let er = t.election_manager in
    let points = t.points in
    { momentum_store; er; points }

  let fixed_pillar_reader t identifier =
    let momentum_store = Chain.get_momentum_store identifier in
    let er = t.election_manager in
    let points = t.points in
    { momentum_store; er; points }

  let get_momentum_producer t timestamp =
    let%lwt election, _ = t.election_manager.election_by_time timestamp in
    let%lwt expected = match election.producers with
      | [] -> raise (Errors.error_msg "no producers found for the timestamp")
      | plan :: _ -> return plan.producer
    in
    return expected

module Consensus = Make (struct
  type t = unit (* Replace this with your implementation of the Chain module *)
  let get_genesis_momentum () = (* Implementation *)
  let get_frontier_momentum_store () = (* Implementation *)
  let get_momentum_store _ = (* Implementation *)
  let register () = (* Implementation *)
  let unregister () = (* Implementation *)
end)


