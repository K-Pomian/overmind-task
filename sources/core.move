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

  public entry fun create_game(
    owner: &signer,
    game_name: vector<u8>,
    depositors_number: u64,
    amount_per_depositor: u64,
    withdrawal_vector: vector<u64>,
    join_duration: u64
  ) acquires State {
    assert!(depositors_number > 1, INVALID_DEPOSITORS_NUMBER);
    assert!(depositors_number == vector::length(&withdrawal_vector), WITHDRAWAL_VECTOR_LENGTH_MISSMATCH);
    utils::check_withdrawal_fractions(&withdrawal_vector);

    let owner_address = signer::address_of(owner);
    if (!exists<State>(owner_address)) {
      init_state(owner);
    };

    let state = borrow_global_mut<State>(owner_address);
    let game_name_string = string::utf8(game_name);
    assert!(table::contains(&state.available_games, game_name_string), GAME_ALREADY_EXISTS);

    let seeds = GAME_SEED;
    vector::append(&mut seeds, game_name);
    let (resource_account_signer, resource_account_cap) = account::create_resource_account(owner, seeds);

    let resource_account_address = signer::address_of(&resource_account_signer);
    table::add(&mut state.available_games, game_name_string, resource_account_address);

    let current_time = timestamp::now_seconds();
    move_to(&resource_account_signer, Game {
      depositors_number,
      amount_per_depositor,
      withdrawal_vector,
      expiration_timestamp: current_time + join_duration,
      signer_cap: resource_account_cap
    });
  }
}