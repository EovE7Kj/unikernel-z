module Pow (C : Common) (N : Nom) (T : Types) = struct
  let get_account_block_hash block =
    let address_bytes = T.address_to_bytes block.address in
    let previous_hash_bytes = T.hash_to_bytes block.previous_hash in
    T.hash (address_bytes @ previous_hash_bytes)

  let check_pow_nonce block =
    let data_hash = get_account_block_hash block in
    let target = get_target_by_difficulty block.difficulty in
    let calc = hash_with_nonce data_hash (T.serialize_uint64 block.nonce) in
    greater_difficulty calc target

  let get_pow_nonce difficulty data_hash =
    let rng = Wallet.get_entropy_csprng 8 in
    let calc, target = get_target difficulty data_hash rng in
    let rec loop calc =
      if greater_difficulty (Crypto.hash calc) target then
        calc
      else
        loop (quick_inc calc)
    in
    loop calc

  let get_target difficulty data_hash nonce =
    let threshold = get_threshold_by_difficulty difficulty in
    let nonce_bytes = T.serialize_bytes nonce in
    let calc = nonce_bytes @ T.hash_to_bytes data_hash in
    let target = uint64_to_byte_array threshold in
    (calc, target)

  let uint64_to_byte_array i =
    let buf = Bytes.create 8 in
    Bytes.set_int64_le buf 0 i;
    Bytes.to_string buf |> Bytes.to_list

  let quick_inc x =
    let inc_byte i b =
      let new_b = Char.chr (Char.code b + 1) in
      if new_b = Char.chr 0 then
        (new_b, true)
      else
        (new_b, false)
    in
    let rec aux i carry =
      if i < 0 then
        carry
      else
        let byte, new_carry = inc_byte i x.(i) in
        Bytes.set x i byte;
        if new_carry then
          aux (i - 1) new_carry
        else
          false
    in
    aux (Array.length x - 1) true

  let get_threshold_by_difficulty difficulty =
    if Big_int.is_positive_big_int difficulty then
      let x = Big_int.pow_big_int (Big_int.of_int 2) 64 in
      let y = Big_int.div_big_int x difficulty in
      Big_int.sub_big_int x y |> Big_int.to_int64 |> Unsigned.UInt64.to_int
    else
      failwith "No difficulty supplied to compute PoW"

  let hash_with_nonce data_hash nonce =
    let data_bytes = T.hash_to_bytes data_hash in
    let nonce_bytes = T.serialize_bytes nonce in
    let calc = nonce_bytes @ data_bytes in
    Crypto.hash calc |> Bytes.sub 0 8 |> Bytes.to_string

  let get_target_by_difficulty difficulty =
    if difficulty = 0L then
      Bytes.make 8 '\000'
    else
      let x = Big_int.pow_big_int (Big_int.of_int 2) 64 in
      let y = Big_int.div_big_int x (Big_int.of_int64 (Int64.of_int difficulty)) in
      let x = Big_int.sub_big_int x y in
      let buf = Bytes.create 8 in
      Bytes.set_int64_le buf 0 (Big_int.to_int64 x);
      Bytes.to_string buf

  let greater_difficulty x y =
    let rec aux i =
      if i < 0 then
        true
      else if x.[i] > y.[i] then
        true
      else if x.[i] < y.[i] then
        false
      else
        aux (i - 1)
    in
    aux 7
end

