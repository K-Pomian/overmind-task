module OvermindTask::core {
  use std::vector;
  use std::table::{Self, Table};
  use aptos_framework::account::{Self, SignerCapability};
  struct State has key {
    available_games: Table<String, address>
  }
  
  struct Game has key {
    depositors_number: u64,
    amount_per_depositor: u64,
    withdrawal_vector: vector<u64>, // 10000 == 100% => 100 == 1%
    expiration_timestamp: u64,
    signer_cap: SignerCapability
  }

  fun init_state(owner: &signer) {
    move_to(owner, State {
      available_games: table::new()
    })
  }

}