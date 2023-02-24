module OvermindTask::utils {
  use std::vector;
  
  friend OvermindTask::core;

  const INVALID_FRACTION: u64 = 2;
  const INVALID_FRACTIONS_SUM: u64 = 3;

  public(friend) fun check_withdrawal_fractions(withdrawal_vector: &vector<u64>) {
    let withdrawal_vector_length = vector::length(withdrawal_vector);

    let i = 0;
    let sum = 0;
    while (i < withdrawal_vector_length - 1) {
      let current_fraction = *vector::borrow(withdrawal_vector, i);
      let next_fraction = *vector::borrow(withdrawal_vector, i + 1);

      assert!(current_fraction >= next_fraction, INVALID_FRACTION);
      
      sum = sum + current_fraction;
      if (i == withdrawal_vector_length - 2) {
        sum = sum + next_fraction;
      };
      
      i = i + 1;
    };

    assert!(sum == 10000, INVALID_FRACTIONS_SUM);
  }
}