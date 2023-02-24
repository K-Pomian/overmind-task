module OvermindTask::core {
  use std::vector;
  use std::table::{Self, Table};
  use std::string::{Self, String};
  use std::signer;

  use aptos_framework::account::{Self, SignerCapability};
  use aptos_framework::timestamp;
  use aptos_framework::coin;

  use OvermindTask::utils;

  const GAME_SEED: vector<u8> = b"DIAMOND_HANDS_GAME";
  const WITHDRAWAL_DENOMINATOR: u64 = 10000;

  const WRONG_ADMIN: u64 = 0;
  const COIN_NOT_EXISTS: u64 = 1;
  const INVALID_DEPOSITORS_NUMBER: u64 = 2;
  const WITHDRAWAL_FRACTIONS_LENGTH_MISSMATCH: u64 = 3;
  const GAME_ALREADY_EXISTS: u64 = 4;
  const GAME_NOT_EXISTS: u64 = 5;
  const GAME_IS_FULL: u64 = 6;
  const GAME_ALREADY_STARTED: u64 = 7;
  const GAME_NOT_STARTED: u64 = 8;
  const GAME_EXPIRED: u64 = 9;
  const GAME_NOT_EXPIRED: u64 = 10;
  const GAME_COIN_TYPE_MISMATCH: u64 = 11;
  const PLAYER_ALREADY_JOINED: u64 = 12;
  const PLAYER_HAS_COIN_NOT_REGISTERED: u64 = 13;
  const INSUFFICIENT_BALANCE: u64 = 14;
  const PERMISSION_DENIED: u64 = 15;

  struct State has key {
    available_games: Table<String, address>
  }
  
  struct DiamondHandsGame<phantom CoinType> has key {
    players: vector<address>,
    deposit_amount: u64,
    withdrawal_fractions: vector<u64>, // 10000 == 100% => 100 == 1%
    expiration_timestamp: u64,
    has_started: bool,
    has_finished: bool,
    signer_cap: SignerCapability
  }

  fun init_state(owner: &signer) {
    move_to(owner, State {
      available_games: table::new()
    })
  }

  public entry fun create_game<CoinType>(
    owner: &signer,
    game_name: vector<u8>,
    depositors_number: u64,
    amount_per_depositor: u64,
    withdrawal_fractions: vector<u64>,
    join_duration: u64
  ) acquires State {
    let owner_address = signer::address_of(owner);
    assert!(owner_address == @ADMIN, WRONG_ADMIN);

    assert!(coin::is_coin_initialized<CoinType>(), COIN_NOT_EXISTS);
    assert!(depositors_number > 1, INVALID_DEPOSITORS_NUMBER);
    assert!(depositors_number == vector::length(&withdrawal_fractions), WITHDRAWAL_FRACTIONS_LENGTH_MISSMATCH);
    utils::check_withdrawal_fractions(&withdrawal_fractions);
    
    if (!exists<State>(owner_address)) {
      init_state(owner);
    };

    let state = borrow_global_mut<State>(owner_address);
    let game_name_string = string::utf8(game_name);
    assert!(table::contains(&state.available_games, game_name_string), GAME_ALREADY_EXISTS);

    let seeds = GAME_SEED;
    vector::append(&mut seeds, game_name);
    let (resource_account_signer, resource_account_cap) = account::create_resource_account(owner, seeds);
    coin::register<CoinType>(&resource_account_signer);

    let resource_account_address = signer::address_of(&resource_account_signer);
    table::add(&mut state.available_games, game_name_string, resource_account_address);

    let current_time = timestamp::now_seconds();
    move_to(&resource_account_signer, DiamondHandsGame<CoinType> {
      players: vector::empty(),
      deposit_amount: amount_per_depositor,
      withdrawal_fractions,
      expiration_timestamp: current_time + join_duration,
      has_started: false,
      has_finished: false,
      signer_cap: resource_account_cap
    });
  }

  public entry fun join_game<CoinType>(
    player: &signer,
    game_name: vector<u8>
  ) acquires State, DiamondHandsGame {
    let state = borrow_global<State>(@ADMIN);

    let game_name_string = string::utf8(game_name);
    assert!(table::contains(&state.available_games, game_name_string), GAME_NOT_EXISTS);

    let game_address = *table::borrow(&state.available_games, game_name_string);
    assert!(coin::is_account_registered<CoinType>(game_address), GAME_COIN_TYPE_MISMATCH);
    let game = borrow_global_mut<DiamondHandsGame<CoinType>>(game_address);

    let current_time = timestamp::now_seconds();
    let player_address = signer::address_of(player);
    assert!(current_time < game.expiration_timestamp, GAME_EXPIRED);
    assert!(!game.has_started, GAME_ALREADY_STARTED);
    assert!(vector::length(&game.players) < vector::length(&game.withdrawal_fractions), GAME_IS_FULL);
    assert!(!vector::contains(&game.players, &player_address), PLAYER_ALREADY_JOINED);
    assert!(coin::is_account_registered<CoinType>(player_address), PLAYER_HAS_COIN_NOT_REGISTERED);
    assert!(coin::balance<CoinType>(player_address) >= game.deposit_amount, INSUFFICIENT_BALANCE);

    coin::transfer<CoinType>(player, game_address, game.deposit_amount);
    vector::push_back(&mut game.players, player_address);

    if (vector::length(&game.players) == vector::length(&game.withdrawal_fractions)) {
      game.has_started = true;
    };
  }

  public entry fun cancel_expired_game<CoinType>(
    account: &signer,
    game_name: vector<u8>
  ) acquires State, DiamondHandsGame {
    let state = borrow_global_mut<State>(@ADMIN);

    let game_name_string = string::utf8(game_name);
    assert!(table::contains(&state.available_games, game_name_string), GAME_NOT_EXISTS);

    let game_address = *table::borrow(&state.available_games, game_name_string);
    assert!(coin::is_account_registered<CoinType>(game_address), GAME_COIN_TYPE_MISMATCH);
    let game = borrow_global_mut<DiamondHandsGame<CoinType>>(game_address);

    let user_address = signer::address_of(account);
    let current_time = timestamp::now_seconds();
    assert!(current_time >= game.expiration_timestamp && !game.has_started, GAME_NOT_EXPIRED);
    assert!(user_address == @ADMIN || vector::contains(&game.players, &user_address), PERMISSION_DENIED);

    let resource_account_signer = account::create_signer_with_capability(&game.signer_cap);
    let i = 0;
    while (i < vector::length(&game.players)) {
      let player_address = *vector::borrow(&game.players, i);
      coin::transfer<CoinType>(&resource_account_signer, player_address, game.deposit_amount);

      i = i + 1;
    };

    game.has_finished = true;
  }

  public entry fun paperhand<CoinType>(player: &signer, game_name: vector<u8>) acquires State, DiamondHandsGame {
    let state = borrow_global<State>(@ADMIN);

    let game_name_string = string::utf8(game_name);
    assert!(table::contains(&state.available_games, game_name_string), GAME_NOT_EXISTS);

    let game_address = *table::borrow(&state.available_games, game_name_string);
    assert!(coin::is_account_registered<CoinType>(game_address), GAME_COIN_TYPE_MISMATCH);
    let game = borrow_global_mut<DiamondHandsGame<CoinType>>(game_address);

    let player_address = signer::address_of(player);
    assert!(vector::contains(&game.players, &player_address), PERMISSION_DENIED);
    assert!(game.has_started, GAME_NOT_STARTED);

    let fraction = vector::pop_back(&mut game.withdrawal_fractions);
    let number_of_players = vector::length(&game.players);
    let numerator = fraction * number_of_players * game.deposit_amount;
    let eligible_amount = numerator / WITHDRAWAL_DENOMINATOR;

    let resource_account_signer = account::create_signer_with_capability(&game.signer_cap);
    coin::transfer<CoinType>(&resource_account_signer, player_address, eligible_amount);

    let (_, player_index) = vector::index_of(&game.players, &player_address);
    vector::remove(&mut game.players, player_index);

    if (vector::length(&game.players) == 0) {
      game.has_finished = true;
    }
  }
}