module OvermindTask::utils {
  use std::vector;
  
  friend OvermindTask::core;

  const INVALID_ORDERING: u64 = 0;
  const INVALID_FRACTIONS_SUM: u64 = 1;

  const WITHDRAWAL_DENOMINATOR: u64 = 10000;

  public(friend) fun check_withdrawal_fractions(withdrawal_vector: &vector<u64>) {
    let withdrawal_vector_length = vector::length(withdrawal_vector);

    let i = 0;
    let sum = 0;
    while (i < withdrawal_vector_length - 1) {
      let current_fraction = *vector::borrow(withdrawal_vector, i);
      let next_fraction = *vector::borrow(withdrawal_vector, i + 1);

      assert!(current_fraction >= next_fraction, INVALID_ORDERING);
      
      sum = sum + current_fraction;
      if (i == withdrawal_vector_length - 2) {
        sum = sum + next_fraction;
      };
      
      i = i + 1;
    };

    assert!(sum == 10000, INVALID_FRACTIONS_SUM);
  }

  public(friend) fun calculate_withdraw_amount(
    withdrawal_fraction: u64,
    number_of_players: u64,
    deposit_amount: u64
  ): u64 {
    let numerator = withdrawal_fraction * number_of_players * deposit_amount;
    numerator / WITHDRAWAL_DENOMINATOR
  }

  #[test]
  fun test_check_withdrawal_fractions_successful() {
    let withdrawal_fractions = vector[3555, 2450, 1790, 1500, 705, 0, 0];
    check_withdrawal_fractions(&withdrawal_fractions);
  }

  #[test]
  #[expected_failure(abort_code = 0x0, location = Self)]
  fun test_check_withdrawal_fractions_invalid_ordering() {
    let withdrawal_fractions = vector[3555, 2450, 1499, 1500, 705, 0, 0];
    check_withdrawal_fractions(&withdrawal_fractions);
  }

  #[test]
  #[expected_failure(abort_code = 0x1, location = Self)]
  fun test_check_withdrawal_fractions_fraction_sum_too_big() {
    let withdrawal_fractions = vector[3555, 2450, 1790, 1500, 710, 0, 0];
    check_withdrawal_fractions(&withdrawal_fractions);
  }

  #[test]
  #[expected_failure(abort_code = 0x1, location = Self)]
  fun test_check_withdrawal_fractions_fraction_sum_too_small() {
    let withdrawal_fractions = vector[3555, 2450, 1790, 1500, 0, 0, 0];
    check_withdrawal_fractions(&withdrawal_fractions);
  }

  #[test]
  fun test_calculate_withdraw_amount() {
    use std::math64;

    let withdrawal_fraction = 2560;
    let number_of_players = 9;
    let deposit_amount = 11 * math64::pow(10, 8);

    let expected = 2534400000;
    let actual = calculate_withdraw_amount(withdrawal_fraction, number_of_players, deposit_amount);
    assert!(expected == actual, 0);

    withdrawal_fraction = 4528;
    number_of_players = 111;
    deposit_amount = 1884236;
    
    expected = 94703208; // 94703208,7488
    actual = calculate_withdraw_amount(withdrawal_fraction, number_of_players, deposit_amount);
    assert!(expected == actual, 1);
  }
}