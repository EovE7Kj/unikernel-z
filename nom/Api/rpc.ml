module Rpc = struct
  module Api = struct
    type service = unit 

    type t = {
      namespace : string;
      version : string;
      service : service;
      public : bool;
    }

    let newLedgerApi (z : Zenon.zenon) : service = ()
    let getSubscribeApi () : service = ()
    let newTokenApi (z : Zenon.zenon) : service = ()
    let newSentinelApi (z : Zenon.zenon) : service = ()
    let newPillarApi (z : Zenon.zenon) (b : bool) : service = ()
    let newPlasmaApi (z : Zenon.zenon) : service = ()
    let newStakeApi (z : Zenon.zenon) : service = ()
    let newSwapApi (z : Zenon.zenon) : service = ()
    let newSporkApi (z : Zenon.zenon) : service = ()
    let newAcceleratorApi (z : Zenon.zenon) : service = ()
    let newHtlcApi (z : Zenon.zenon) : service = ()
    let newBridgeApi (z : Zenon.zenon) : service = ()
    let newLiquidityApi (z : Zenon.zenon) : service = ()
    let newStatsApi (z : Zenon.zenon) (p2p : P2p.server) : service = ()
  end

  type zenon = unit 
  type p2pServer = unit 

  module Server = struct
    type api = Api.t list

    let getApi (z : zenon) (p2p : p2pServer) (apiModule : string) : api =
      match apiModule with
      | "ledger" ->
          [
            {
              Api.namespace = "ledger";
              version = "1.0";
              service = Api.newLedgerApi z;
              public = true;
            }
          ]
      | "ledgerSubscribe" ->
          [
            {
              namespace = "ledger";
              version = "1.0";
              service = Api.getSubscribeApi ();
              public = true;
            }
          ]
      | "embedded" ->
          [
            {
              namespace = "embedded.token";
              version = "1.0";
              service = Api.newTokenApi z;
              public = true;
            };
            {
              namespace = "embedded.sentinel";
              version = "1.0";
              service = Api.newSentinelApi z;
              public = true;
            };
          ]
      | "stats" ->
          [
            {
              namespace = "stats";
              version = "1.0";
              service = Api.newStatsApi z p2p;
              public = true;
            }
          ]
      | _ -> []

    let getApis (z : zenon) (p2p : p2pServer) (apiModules : string list) : api list =
      List.concat (List.map (fun m -> getApi z p2p m) apiModules)

    let getPublicApis (z : zenon) (p2p : p2pServer) : api =
      getApis z p2p [ "ledger"; "ledgerSubscribe"; "embedded"; "stats" ]
  end
end

