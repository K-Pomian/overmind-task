module OvermindTask::core {
  use std::vector;
  use std::table::{Self, Table};
  use std::string::{Self, String};
  use std::signer;

  use aptos_framework::account::{Self, SignerCapability};
  use aptos_framework::timestamp;

  use OvermindTask::utils;

  const GAME_SEED: vector<u8> = b"GAME_SEED";
  const WITHDRAWAL_DENOMINATOR: u64 = 10000;

  const WRONG_ADMIN: u64 = 0;
  const COIN_NOT_EXISTS: u64 = 1;
  const INVALID_DEPOSITORS_NUMBER: u64 = 2;
  const WITHDRAWAL_FRACTIONS_LENGTH_MISSMATCH: u64 = 3;
  const GAME_ALREADY_EXISTS: u64 = 4;
  const GAME_NOT_EXISTS: u64 = 5;
  const GAME_IS_FULL: u64 = 6;
  const GAME_ALREADY_STARTED: u64 = 7;
  const GAME_EXPIRED: u64 = 8;
  const GAME_COIN_TYPE_MISMATCH: u64 = 9;
  const PLAYER_ALREADY_JOINED: u64 = 10;
  const PLAYER_HAS_NOT_COIN_REGISTERED: u64 = 11;
  const INSUFFICIENT_BALANCE: u64 = 12;

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