module OvermindTask::events {
  use std::string::String;

  struct CreateGameEvent has store, drop {
    game_name: String,
    max_players: u64,
    amount_per_depositor: u64,
    expiration_timestamp: u64,
  }

  struct JoinGameEvent has store, drop {
    player_address: address,
  }

  struct StartGameEvent has store, drop {
    game_name: String,
    players: vector<address>
  }

  struct CancelGameEvent has store, drop {
    game_name: String
  }

  struct PaperhandEvent has store, drop {
    player: address,
    withdraw_amount: u64,
  }

  public fun new_create_game_event(
    game_name: String,
    max_players: u64,
    amount_per_depositor: u64,
    expiration_timestamp: u64
  ): CreateGameEvent {
    CreateGameEvent { game_name, max_players, amount_per_depositor, expiration_timestamp }
  }

  public fun new_join_game_event(player_address: address): JoinGameEvent {
    JoinGameEvent { player_address }
  }

  public fun new_start_game_event(game_name: String, players: vector<address>): StartGameEvent {
    StartGameEvent { game_name, players }
  }

  public fun new_cancel_game_event(game_name: String): CancelGameEvent {
    CancelGameEvent { game_name }
  }

  public fun new_paperhand_event(
    player: address,
    withdraw_amount: u64
  ): PaperhandEvent {
    PaperhandEvent { player, withdraw_amount }
  }
}