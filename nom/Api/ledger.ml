module Api = struct
  type service = unit

  type t = {
    namespace : string;
    version : string;
    service : service;
    public : bool;
  }

  let newLedgerApi (z : Zenon.zenon) : service = ()

end

type ledgerApi = {
  z : Zenon.zenon;
  chain : chain.Chain;
  log : log15.Logger;
}

let unreceivedMaxPageIndex = 10
let unreceivedMaxPageSize = 50
let unreceivedQuerySize = unreceivedMaxPageIndex * unreceivedMaxPageSize

let ( >>= ) x f = match x with
  | Error e -> Error e
  | Ok v -> f v

let ( >>? ) x f = match x with
  | None -> Error "null parameter"
  | Some v -> f v

let ( >>| ) x f = match x with
  | Error e -> Error e
  | Ok v -> Ok (f v)

let ( |? ) x y = match x with
  | None -> y
  | Some v -> v

let ( +@ ) x y = x + y

let string_of_ledgerApi _ = "LedgerApi"

let publishRawTransaction l block =
  if block = None then
    Error "null parameter"
  else
    match block |? None with
    | Some b ->
      if b.chainIdentifier <> 0 && b.chainIdentifier <> l.chain.ChainIdentifier() then
        Error ("the block has a different network Id (" ^ string_of_int b.chainIdentifier ^ ") from the node (" ^ string_of_int l.chain.ChainIdentifier() ^ ")")
      else
        b.ToLedgerBlock()
        >>= fun lb ->
        checkTokenIdValid l.chain lb.TokenStandard
        >>= fun () ->
        let supervisor = vm.NewSupervisor(l.z.Chain(), l.z.Consensus()) in
        let transaction, err = supervisor.ApplyBlock lb in
        if err <> None then
          Error err
        else (
          l.z.Broadcaster().CreateAccountBlock transaction;
          Ok ()
        )
    | None -> Error "null parameter"

let getUnconfirmedBlocksByAddress l address pageIndex pageSize =
  if pageSize > RpcMaxPageSize then
    Error "PageSizeParamTooBig"
  else
    let unreceived = l.chain.GetUncommittedAccountBlocksByAddress address in
    let start, end_ = GetRange(pageIndex, pageSize, List.length unreceived) in
    ledgerAccountBlocksToRpc l.chain (List.sub unreceived start (end_ - start))
    >>| fun a ->
    {
      List = a;
      Count = List.length unreceived;
      More = false
    }

let getFrontierAccountBlock l address =
  let accountStore = l.chain.GetFrontierAccountStore address in
  accountStore.Frontier()
  >>? fun block ->
  ledgerAccountBlockToRpc l.chain block
  >>| fun b -> Some b

let getAccountBlockByHash l blockHash =
  let momentumStore = l.chain.GetFrontierMomentumStore() in
  momentumStore.GetAccountBlockByHash blockHash
  >>? fun block ->
  ledgerAccountBlockToRpc l.chain block
  >>| fun b -> Some b

let getAccountBlocksByHeight l address height count =
  if height = 0 then
    Error "HeightParamIsZero"
  else if count > RpcMaxCountSize then
    Error "CountParamTooBig"
  else
    let accountStore = l.chain.GetFrontierAccountStore address in
    accountStore.Frontier()
    >>? fun frontier ->
    if frontier = None then
      Ok {
        List = [];
        Count = 0;
      }
    else
      accountStore.MoreByHeight height count
      >>| fun accountBlocks ->
      ledgerAccountBlocksToRpc l.chain accountBlocks
      >>| fun list -> {
        List = list;
        Count = int frontier.Height;
      }

let getAccountBlocksByPage l address pageIndex pageSize =
  if pageSize > RpcMaxPageSize then
    Error "PageSizeParamTooBig"
  else
    let accountStore = l.chain.GetFrontierAccountStore address in
    accountStore.Frontier()
    >>? fun frontier ->
    if frontier = None then
      Ok {
        List = [];
        Count = 0;
        More = false;
      }
    else
      let startHeight = int64 frontier.Height - int64 (pageIndex + 1) * int64 pageSize + 1 in
      let count = int64 pageSize in
      let tooMuch = 1 - startHeight in
      let startHeight' = if tooMuch > 0 then 1 else startHeight in
      let count' = if count < 1 then 1 - startHeight' else count in
      getAccountBlocksByHeight l address (uint64 startHeight') (uint64 count')
      >>| fun ans ->
      let rec reverse lst =
        match lst with
        | [] -> []
        | hd :: tl -> reverse tl @ [hd]
      in
      { ans with List = reverse ans.List }

let getAccountInfoByAddress l address =
  l.log.Info "GetAccountInfoByAddress";
  let momentumStore = l.chain.GetFrontierMomentumStore() in
  let accountStore = l.chain.GetFrontierAccountStore address in
  accountStore.Frontier()
  >>? fun frontierAccountBlock ->
  let totalNum = match frontierAccountBlock with None -> 0 | Some f -> f.Height in
  accountStore.GetBalanceMap()
  >>| fun balanceMap ->
  let balanceInfoMap = Hashtbl.create (Hashtbl.length balanceMap) in
  Hashtbl.iter (fun zts balance ->
      match momentumStore.GetTokenInfoByTs zts with
      | None -> ()
      | Some tokenInfo ->
        Hashtbl.add balanceInfoMap zts {
          TokenInfo = LedgerTokenInfoToRpc tokenInfo;
          Balance = balance
        }
    ) balanceMap;
  {
    Address = address;
    AccountHeight = totalNum;
    BalanceInfoMap = balanceInfoMap;
  }

let getUnreceivedBlocksByAddress l address pageIndex pageSize =
  l.log.Info "GetUnreceivedBlocksByAddress" ["address", address; "page", pageIndex; "size", pageSize];
  if pageSize > unreceivedMaxPageSize then
    Error "PageSizeParamTooBig"
  else if pageIndex >= unreceivedMaxPageIndex then
    Error "PageIndexParamTooBig"
  else
    let accountStore = l.chain.GetFrontierAccountStore address in
    let hashList = l.chain.GetFrontierMomentumStore().GetAccountMailbox address |> GetUnreceivedAccountBlockHashes unreceivedQuerySize in
    let blockList = List.filter_map (fun hash ->
        if accountStore.IsReceived hash then
          None
        else
          match l.chain.GetFrontierMomentumStore().GetAccountBlockByHash hash with
          | None -> None
          | Some block -> Some block
      ) hashList in
    let isMore = List.length hashList = unreceivedQuerySize in
    let start, end_ = GetRange(pageIndex, pageSize, List.length blockList) in
    ledgerAccountBlocksToRpc l.chain (List.sub blockList start (end_ - start))
    >>| fun a -> {
      List = a;
      Count = List.length blockList;
      More = isMore
    }

let getFrontierMomentum l =
  l.chain.GetFrontierMomentumStore().GetFrontierMomentum()
  >>| fun momentum -> ledgerMomentumToRpc momentum

let getMomentumBeforeTime l timestamp =
  let currentTime = time.Unix(timestamp, 0) in
  l.chain.GetFrontierMomentumStore().GetMomentumBeforeTime currentTime
  >>? fun momentum -> ledgerMomentumToRpc momentum

let getMomentumByHash l hash =
  l.chain.GetFrontierMomentumStore().GetMomentumByHash hash
  >>? fun momentum -> ledgerMomentumToRpc momentum

let getMomentumsByHeight l height count =
  if height = 0 then
    Error "HeightParamIsZero"
  else if count > RpcMaxCountSize then
    Error "CountParamTooBig"
  else
    let momentumStore = l.chain.GetFrontierMomentumStore() in
    momentumStore.GetFrontierMomentum()
    >>? fun frontier ->
    let momentums = momentumStore.GetMomentumsByHeight height true count in
    ledgerMomentumsToRpc momentums
    >>| fun list -> {
      List = list;
      Count = int frontier.Height;
    }

let getMomentumsByPage l pageIndex pageSize =
  if pageSize > RpcMaxPageSize then
    Error "PageSizeParamTooBig"
  else
    let momentumStore = l.chain.GetFrontierMomentumStore() in
    momentumStore.GetFrontierMomentum()
    >>? fun frontier ->
    let startHeight = int64 frontier.Height - int64 (pageIndex + 1) * int64 pageSize + 1 in
    let count = int64 pageSize in
    let tooMuch = 1 - startHeight in
    let count' = if count < 1 then 1 - startHeight else count in
    getMomentumsByHeight l (uint64 startHeight) (uint64 count')
    >>| fun ans ->
    let rec reverse lst =
      match lst with
      | [] -> []
      | hd :: tl -> reverse tl @ [hd]
    in
    { ans with List = reverse ans.List }

let getDetailedMomentumsByHeight l height count =
  l.log.Info "GetDetailedMomentumsByHeight" ["height", height; "count", count];
  if count > RpcMaxCountSize then
    Error "CountParamTooBig"
  else
    getMomentumsByHeight l height count
    >>| fun ans -> momentumListToDetailedList l.chain ans

