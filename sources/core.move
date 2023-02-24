module OvermindTask::core {
  use std::table::{Self, Table};
  struct State has key {
    available_games: Table<String, address>
  }

  fun init_state(owner: &signer) {
    move_to(owner, State {
      available_games: table::new()
    })
  }

}