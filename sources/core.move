module OvermindTask::core {
  use std::vector;
  use std::table::{Self, Table};
  use std::string::{Self, String};
  use std::signer;

  use aptos_framework::account::{Self, SignerCapability};
  use aptos_framework::timestamp;
  use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};

  use OvermindTask::utils;

  const GAME_SEED: vector<u8> = b"DIAMOND_HANDS_GAME";

  const WRONG_ADMIN: u64 = 0;
  const COIN_NOT_EXISTS: u64 = 1;
  const INVALID_DEPOSITORS_NUMBER: u64 = 2;
  const GAME_ALREADY_EXISTS: u64 = 3;
  const GAME_ALREADY_EXISTED: u64 = 4;
  const GAME_NOT_EXISTS: u64 = 5;
  const GAME_ALREADY_STARTED: u64 = 6;
  const GAME_NOT_STARTED: u64 = 7;
  const GAME_EXPIRED: u64 = 8;
  const GAME_NOT_EXPIRED: u64 = 9;
  const PLAYER_ALREADY_JOINED: u64 = 10;
  const PLAYER_HAS_COIN_NOT_REGISTERED: u64 = 11;
  const INSUFFICIENT_BALANCE: u64 = 12;
  const PERMISSION_DENIED: u64 = 13;

  struct State has key {
    available_games: Table<String, address>
  }
  
  struct DiamondHandsGame<phantom CoinType> has key {
    players: vector<address>,
    max_players: u64,
    deposit_amount: u64,
    withdrawal_fractions: vector<u64>, // 10000 == 100% => 100 == 1%
    expiration_timestamp: u64,
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
    amount_per_depositor: u64,
    withdrawal_fractions: vector<u64>,
    join_duration: u64
  ) acquires State {
    let owner_address = signer::address_of(owner);
    assert!(owner_address == @ADMIN, WRONG_ADMIN);

    assert!(coin::is_coin_initialized<CoinType>(), COIN_NOT_EXISTS);
    assert!(vector::length(&withdrawal_fractions) > 1, INVALID_DEPOSITORS_NUMBER);
    utils::check_withdrawal_fractions(&withdrawal_fractions);
    
    if (!exists<State>(owner_address)) {
      init_state(owner);
    };

    let state = borrow_global_mut<State>(owner_address);
    let game_name_string = string::utf8(game_name);
    assert!(!table::contains(&state.available_games, game_name_string), GAME_ALREADY_EXISTS);

    let seeds = GAME_SEED;
    vector::append(&mut seeds, game_name);

    let resource_account_address = account::create_resource_address(&owner_address, seeds);
    assert!(!account::exists_at(resource_account_address), GAME_ALREADY_EXISTED);

    let (resource_account_signer, resource_account_cap) = account::create_resource_account(owner, seeds);
    coin::register<CoinType>(&resource_account_signer);

    let resource_account_address = signer::address_of(&resource_account_signer);
    table::add(&mut state.available_games, game_name_string, resource_account_address);

    let current_time = timestamp::now_seconds();
    move_to(&resource_account_signer, DiamondHandsGame<CoinType> {
      players: vector::empty(),
      max_players: vector::length(&withdrawal_fractions),
      deposit_amount: amount_per_depositor,
      withdrawal_fractions,
      expiration_timestamp: current_time + join_duration,
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
    let game = borrow_global_mut<DiamondHandsGame<CoinType>>(game_address);

    let current_time = timestamp::now_seconds();
    let player_address = signer::address_of(player);
    assert!(current_time < game.expiration_timestamp, GAME_EXPIRED);
    assert!(vector::length(&game.players) < game.max_players, GAME_ALREADY_STARTED);
    assert!(!vector::contains(&game.players, &player_address), PLAYER_ALREADY_JOINED);
    assert!(coin::is_account_registered<CoinType>(player_address), PLAYER_HAS_COIN_NOT_REGISTERED);
    assert!(coin::balance<CoinType>(player_address) >= game.deposit_amount, INSUFFICIENT_BALANCE);

    coin::transfer<CoinType>(player, game_address, game.deposit_amount);
    vector::push_back(&mut game.players, player_address);
  }

  public entry fun cancel_expired_game<CoinType>(
    account: &signer,
    game_name: vector<u8>
  ) acquires State, DiamondHandsGame {
    let state = borrow_global_mut<State>(@ADMIN);

    let game_name_string = string::utf8(game_name);
    assert!(table::contains(&state.available_games, game_name_string), GAME_NOT_EXISTS);

    let game_address = *table::borrow(&state.available_games, game_name_string);
    let game = borrow_global_mut<DiamondHandsGame<CoinType>>(game_address);

    let user_address = signer::address_of(account);
    let current_time = timestamp::now_seconds();
    assert!(
      current_time >= game.expiration_timestamp &&
      vector::length(&game.players) < vector::length(&game.withdrawal_fractions),
      GAME_NOT_EXPIRED
    );
    assert!(user_address == @ADMIN || vector::contains(&game.players, &user_address), PERMISSION_DENIED);

    let resource_account_signer = account::create_signer_with_capability(&game.signer_cap);
    let i = 0;
    while (i < vector::length(&game.players)) {
      let player_address = *vector::borrow(&game.players, i);
      coin::transfer<CoinType>(&resource_account_signer, player_address, game.deposit_amount);

      i = i + 1;
    };
    
    table::remove(&mut state.available_games, game_name_string);
  }

  public entry fun paperhand<CoinType>(player: &signer, game_name: vector<u8>) acquires State, DiamondHandsGame {
    let state = borrow_global_mut<State>(@ADMIN);

    let game_name_string = string::utf8(game_name);
    assert!(table::contains(&state.available_games, game_name_string), GAME_NOT_EXISTS);

    let game_address = *table::borrow(&state.available_games, game_name_string);
    let game = borrow_global_mut<DiamondHandsGame<CoinType>>(game_address);

    let player_address = signer::address_of(player);
    assert!(vector::contains(&game.players, &player_address), PERMISSION_DENIED);
    assert!(vector::length(&game.players) == vector::length(&game.withdrawal_fractions), GAME_NOT_STARTED);

    let resource_account_signer = account::create_signer_with_capability(&game.signer_cap);

    let fraction = vector::pop_back(&mut game.withdrawal_fractions);
    let eligible_amount = if (vector::length(&game.withdrawal_fractions) == 0) {
      coin::balance<CoinType>(signer::address_of(&resource_account_signer))
    } else {
      utils::calculate_withdraw_amount(fraction, game.max_players, game.deposit_amount)
    };

    coin::transfer<CoinType>(&resource_account_signer, player_address, eligible_amount);

    let (_, player_index) = vector::index_of(&game.players, &player_address);
    vector::remove(&mut game.players, player_index);

    if (vector::length(&game.players) == 0) {
      table::remove(&mut state.available_games, game_name_string);
    }
  }

  #[test_only]
  struct TestCoin {}

  #[test_only]
  fun initialize_test_coin(
    account: &signer
  ): (BurnCapability<TestCoin>, FreezeCapability<TestCoin>, MintCapability<TestCoin>) {
    coin::initialize<TestCoin>(
      account,
      string::utf8(b"TestCoin"),
      string::utf8(b"TC"),
      6,
      false
    )
  }

  #[test(account = @0x1111)]
  fun test_init_state(account: &signer) {
    init_state(account);

    let account_address = signer::address_of(account);
    assert!(exists<State>(account_address), 0);
  }

  #[test(owner = @ADMIN, aptos_framework = @0x1)]
  public entry fun test_create_game_successfull(
    owner: &signer,
    aptos_framework: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);
    let game_name = b"TestGame";
    let amount_per_depositor = 159842396;
    let withdrawal_fractions = vector[4492, 2559, 1111, 687, 555, 321, 175, 100];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let game_name_string = string::utf8(game_name);
    let owner_address = signer::address_of(owner);
    let state = borrow_global<State>(owner_address);
    assert!(table::contains(&state.available_games, game_name_string), 0);

    let game_address = *table::borrow(&state.available_games, game_name_string);
    assert!(exists<DiamondHandsGame<TestCoin>>(game_address), 1);

    let game = borrow_global<DiamondHandsGame<TestCoin>>(game_address);
    assert!(vector::length(&game.players) == 0, 2);
    assert!(game.max_players == 8, 3);
    assert!(game.deposit_amount == amount_per_depositor, 4);
    assert!(game.withdrawal_fractions == withdrawal_fractions, 5);

    let expected_seeds = GAME_SEED;
    vector::append(&mut expected_seeds, game_name);

    let expected_resource_account_address = account::create_resource_address(&owner_address, expected_seeds);
    assert!(game_address == expected_resource_account_address, 7);

    let signer_cap = account::create_test_signer_cap(expected_resource_account_address);
    assert!(&game.signer_cap == &signer_cap, 8);

    assert!(coin::is_account_registered<TestCoin>(game_address), 9);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(owner = @0xaaaa444522)]
  #[expected_failure(abort_code = 0x0, location = Self)]
  public entry fun test_create_game_wrong_admin(owner: &signer) acquires State {
    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[6550, 2000, 1450];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);
  }

  #[test(owner = @ADMIN)]
  #[expected_failure(abort_code = 0x1, location = Self)]
  public entry fun test_create_game_coin_not_exists(owner: &signer) acquires State {
    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[6550, 2000, 1450];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);
  }

  #[test(owner = @ADMIN)]
  #[expected_failure(abort_code = 0x2, location = Self)]
  public entry fun test_create_game_invalid_number_of_depositors(owner: &signer) acquires State {
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[10000];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(owner = @ADMIN, aptos_framework = @0x1)]
  #[expected_failure(abort_code = 0x3, location = Self)]
  public entry fun test_create_game_already_exists(
    owner: &signer, 
    aptos_framework: &signer
  ) acquires State {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 2550, 1950];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);
    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(owner = @ADMIN, aptos_framework = @0x1)]
  #[expected_failure(abort_code = 0x4, location = Self)]
  public entry fun test_create_game_which_existed_in_the_past(
    owner: &signer,
    aptos_framework: &signer
  ) acquires State {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 2550, 1950];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let game_name_string = string::utf8(game_name);
    let owner_address = signer::address_of(owner);
    let state = borrow_global_mut<State>(owner_address);
    table::remove(&mut state.available_games, game_name_string);

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(
    aptos_framework = @0x1,
    owner = @ADMIN,
    first_player = @0xafdd8854,
    second_player = @0xffade455,
    third_player = @0xaaced55548
  )]
  public entry fun test_join_game_successful(
    aptos_framework: &signer,
    owner: &signer,
    first_player: &signer,
    second_player: &signer,
    third_player: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 2550, 1950];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let owner_address = signer::address_of(owner);
    let state = borrow_global<State>(owner_address);
    
    let game_name_string = string::utf8(game_name);
    let game_address = *table::borrow(&state.available_games, game_name_string);

    let first_player_address = signer::address_of(first_player);
    account::create_account_for_test(first_player_address);
    coin::register<TestCoin>(first_player);
    coin::deposit(first_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(first_player, game_name);

    {
      let game = borrow_global<DiamondHandsGame<TestCoin>>(game_address);
      assert!(vector::length(&game.players) == 1, 0);
      assert!(vector::contains(&game.players, &first_player_address), 1);
      assert!(coin::balance<TestCoin>(game_address) == amount_per_depositor, 2);
      assert!(coin::balance<TestCoin>(first_player_address) == 0, 3);
    };

    let second_player_address = signer::address_of(second_player);
    account::create_account_for_test(second_player_address);
    coin::register<TestCoin>(second_player);
    coin::deposit(second_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(second_player, game_name);

    {
      let game = borrow_global<DiamondHandsGame<TestCoin>>(game_address);
      assert!(vector::length(&game.players) == 2, 4);
      assert!(vector::contains(&game.players, &first_player_address), 5);
      assert!(vector::contains(&game.players, &second_player_address), 6);
      assert!(coin::balance<TestCoin>(game_address) == amount_per_depositor * 2, 7);
      assert!(coin::balance<TestCoin>(second_player_address) == 0, 8);
    };

    let third_player_address = signer::address_of(third_player);
    account::create_account_for_test(third_player_address);
    coin::register<TestCoin>(third_player);
    coin::deposit(third_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(third_player, game_name);

    {
      let game = borrow_global<DiamondHandsGame<TestCoin>>(game_address);
      assert!(vector::length(&game.players) == 3, 9);
      assert!(vector::contains(&game.players, &first_player_address), 10);
      assert!(vector::contains(&game.players, &second_player_address), 11);
      assert!(vector::contains(&game.players, &third_player_address), 12);
      assert!(coin::balance<TestCoin>(game_address) == amount_per_depositor * 3, 13);
      assert!(coin::balance<TestCoin>(third_player_address) == 0, 14);
    };

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(owner = @ADMIN, player = @0xafdd8854)]
  #[expected_failure(abort_code = 0x5, location = Self)]
  public entry fun test_join_game_not_exists(
    owner: &signer,
    player: &signer
  ) acquires State, DiamondHandsGame {
    init_state(owner);

    let game_name = b"TestGame";
    join_game<TestCoin>(player, game_name);
  }

  #[test(aptos_framework = @0x1, owner = @ADMIN, player = @0xafdd8854)]
  #[expected_failure(abort_code = 0x8, location = Self)]
  public entry fun test_join_game_already_expired(
    aptos_framework: &signer,
    owner: &signer,
    player: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 2550, 1950];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    timestamp::fast_forward_seconds(604801);

    join_game<TestCoin>(player, game_name);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(
    aptos_framework = @0x1,
    owner = @ADMIN,
    first_player = @0xafdd8854,
    second_player = @0xaabbcc,
    third_player = @0x55874216
  )]
  #[expected_failure(abort_code = 0x6, location = Self)]
  public entry fun test_join_game_already_started(
    aptos_framework: &signer,
    owner: &signer,
    first_player: &signer,
    second_player: &signer,
    third_player: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 4500];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let first_player_address = signer::address_of(first_player);
    account::create_account_for_test(first_player_address);
    coin::register<TestCoin>(first_player);
    coin::deposit(first_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(first_player, game_name);

    let second_player_address = signer::address_of(second_player);
    account::create_account_for_test(second_player_address);
    coin::register<TestCoin>(second_player);
    coin::deposit(second_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(second_player, game_name);

    join_game<TestCoin>(third_player, game_name);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(aptos_framework = @0x1, owner = @ADMIN, player = @0xafdd8854)]
  #[expected_failure(abort_code = 0xa, location = Self)]
  public entry fun test_join_game_player_already_joined(
    aptos_framework: &signer,
    owner: &signer,
    player: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 4500];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let player_address = signer::address_of(player);
    account::create_account_for_test(player_address);
    coin::register<TestCoin>(player);
    coin::deposit(player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(player, game_name);
    join_game<TestCoin>(player, game_name);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(aptos_framework = @0x1, owner = @ADMIN, player = @0xafdd8854)]
  #[expected_failure(abort_code = 0xb, location = Self)]
  public entry fun test_join_game_player_has_coin_not_registered(
    aptos_framework: &signer,
    owner: &signer,
    player: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 4500];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let player_address = signer::address_of(player);
    account::create_account_for_test(player_address);
    
    join_game<TestCoin>(player, game_name);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(aptos_framework = @0x1, owner = @ADMIN, player = @0xafdd8854)]
  #[expected_failure(abort_code = 0xc, location = Self)]
  public entry fun test_join_game_player_has_insufficient_balance(
    aptos_framework: &signer,
    owner: &signer,
    player: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 4500];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let player_address = signer::address_of(player);
    account::create_account_for_test(player_address);
    coin::register<TestCoin>(player);
    coin::deposit(player_address, coin::mint<TestCoin>(1, &mint_cap));
    
    join_game<TestCoin>(player, game_name);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(
    aptos_framework = @0x1,
    owner = @ADMIN,
    first_player = @0xafdd8854,
    second_player = @0xaabbccdd
  )]
  public entry fun test_cancel_expired_game_successful(
    aptos_framework: &signer,
    owner: &signer,
    first_player: &signer,
    second_player: &signer,
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 3000, 1500];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let first_player_address = signer::address_of(first_player);
    account::create_account_for_test(first_player_address);
    coin::register<TestCoin>(first_player);
    coin::deposit(first_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(first_player, game_name);

    let second_player_address = signer::address_of(second_player);
    account::create_account_for_test(second_player_address);
    coin::register<TestCoin>(second_player);
    coin::deposit(second_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(second_player, game_name);

    timestamp::fast_forward_seconds(604801);

    cancel_expired_game<TestCoin>(first_player, game_name);

    let owner_address = signer::address_of(owner);
    let state = borrow_global<State>(owner_address);

    let game_name_string = string::utf8(game_name);
    assert!(!table::contains(&state.available_games, game_name_string), 0);

    let seeds = GAME_SEED;
    vector::append(&mut seeds, game_name);
    let game_address = account::create_resource_address(&owner_address, seeds);

    assert!(coin::balance<TestCoin>(game_address) == 0, 1);
    assert!(coin::balance<TestCoin>(first_player_address) == amount_per_depositor, 2);
    assert!(coin::balance<TestCoin>(second_player_address) == amount_per_depositor, 3);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(owner = @ADMIN, player = @0xafdd8854)]
  #[expected_failure(abort_code = 0x5, location = Self)]
  public entry fun test_cancel_expired_game_not_exists(
    owner: &signer,
    player: &signer
  ) acquires State, DiamondHandsGame {
    init_state(owner);

    let game_name = b"TestGame";
    cancel_expired_game<TestCoin>(player, game_name);
  }

  #[test(aptos_framework = @0x1, owner = @ADMIN)]
  #[expected_failure(abort_code = 0x9, location = Self)]
  public entry fun test_cancel_expired_game_not_expired(
    aptos_framework: &signer,
    owner: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 3000, 1500];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    cancel_expired_game<TestCoin>(owner, game_name);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(
    aptos_framework = @0x1,
    owner = @ADMIN,
    player = @0x45841,
    random_guy = @0x5555555
  )]
  #[expected_failure(abort_code = 0xd, location = Self)]
  public entry fun test_cancel_expired_game_permission_denied(
    aptos_framework: &signer,
    owner: &signer,
    player: &signer,
    random_guy: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 486123;
    let withdrawal_fractions = vector[5500, 3000, 1500];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let player_address = signer::address_of(player);
    account::create_account_for_test(player_address);
    coin::register<TestCoin>(player);
    coin::deposit(player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(player, game_name);

    timestamp::fast_forward_seconds(604801);

    cancel_expired_game<TestCoin>(random_guy, game_name);

    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(
    aptos_framework = @0x1,
    owner = @ADMIN,
    first_player = @0xaab4284,
    second_player = @0xaabbccddeeff,
    third_player = @0x4861326abc
  )]
  public entry fun test_paperhand_successful(
    aptos_framework: &signer,
    owner: &signer,
    first_player: &signer,
    second_player: &signer,
    third_player: &signer
  ) acquires State, DiamondHandsGame {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    let (burn_cap, freeze_cap, mint_cap) = initialize_test_coin(owner);

    let game_name = b"TestGame";
    let amount_per_depositor = 489461526;
    let withdrawal_fractions = vector[5423, 2954, 1623];
    let join_duration = 604800; // week

    create_game<TestCoin>(owner, game_name, amount_per_depositor, withdrawal_fractions, join_duration);

    let first_player_address = signer::address_of(first_player);
    account::create_account_for_test(first_player_address);
    coin::register<TestCoin>(first_player);
    coin::deposit(first_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(first_player, game_name);

    let second_player_address = signer::address_of(second_player);
    account::create_account_for_test(second_player_address);
    coin::register<TestCoin>(second_player);
    coin::deposit(second_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(second_player, game_name);

    let third_player_address = signer::address_of(third_player);
    account::create_account_for_test(third_player_address);
    coin::register<TestCoin>(third_player);
    coin::deposit(third_player_address, coin::mint<TestCoin>(amount_per_depositor, &mint_cap));

    join_game<TestCoin>(third_player, game_name);

    let owner_address = signer::address_of(owner);
    let seeds = GAME_SEED;
    vector::append(&mut seeds, game_name);
    let game_address = account::create_resource_address(&owner_address, seeds);

    let game_name_string = string::utf8(game_name);

    paperhand<TestCoin>(second_player, game_name);

    {
      let game = borrow_global<DiamondHandsGame<TestCoin>>(game_address);

      assert!(vector::length(&game.withdrawal_fractions) == 2, 0);
      assert!(vector::contains(&game.withdrawal_fractions, &5423), 1);
      assert!(vector::contains(&game.withdrawal_fractions, &2954), 2);

      assert!(vector::length(&game.players) == 2, 3);
      assert!(vector::contains(&game.players, &first_player_address), 4);
      assert!(vector::contains(&game.players, &third_player_address), 5);

      let first_expected_eligible_amount = 238318817; // 238318817,0094
      assert!(coin::balance<TestCoin>(second_player_address) == first_expected_eligible_amount, 6);
      // 3 * amount_per_depositor - first_expected_eligible_amount
      assert!(coin::balance<TestCoin>(game_address) == 1230065761, 7); 

      let state = borrow_global<State>(owner_address);
      assert!(table::contains(&state.available_games, game_name_string), 8);
    };

    paperhand<TestCoin>(third_player, game_name);

    {
      let game = borrow_global<DiamondHandsGame<TestCoin>>(game_address);

      assert!(vector::length(&game.withdrawal_fractions) == 1, 9);
      assert!(vector::contains(&game.withdrawal_fractions, &5423), 10);

      assert!(vector::length(&game.players) == 1, 11);
      assert!(vector::contains(&game.players, &first_player_address), 12);

      let second_expected_eligible_amount = 433760804; // 433760804,3412
      assert!(coin::balance<TestCoin>(third_player_address) == second_expected_eligible_amount, 13);
      // 3 * amount_per_depositor - first_expected_eligible_amount - second_expected_eligible_amount
      assert!(coin::balance<TestCoin>(game_address) == 796304957, 14);

      let state = borrow_global<State>(owner_address);
      assert!(table::contains(&state.available_games, game_name_string), 15); 
    };

    paperhand<TestCoin>(first_player, game_name);

    let game = borrow_global<DiamondHandsGame<TestCoin>>(game_address);
    assert!(vector::length(&game.withdrawal_fractions) == 0, 16);
    assert!(vector::length(&game.players) == 0, 17);

    let third_expected_eligible_amount = 796304957;
    assert!(coin::balance<TestCoin>(first_player_address) == third_expected_eligible_amount, 18);
    assert!(coin::balance<TestCoin>(game_address) == 0, 19);
    
    let state = borrow_global<State>(owner_address);
    assert!(!table::contains(&state.available_games, game_name_string), 20);
    
    coin::destroy_burn_cap(burn_cap);
    coin::destroy_freeze_cap(freeze_cap);
    coin::destroy_mint_cap(mint_cap);
  }

  #[test(owner = @ADMIN, player = @0x48651)]
  #[expected_failure(abort_code = 0x5, location = Self)]
  public entry fun test_paperhand_game_not_exists(
    owner: &signer,
    player: &signer
  ) acquires State, DiamondHandsGame {
    init_state(owner);

    let game_name = b"TestGame";
    paperhand<TestCoin>(player, game_name);
  }
}