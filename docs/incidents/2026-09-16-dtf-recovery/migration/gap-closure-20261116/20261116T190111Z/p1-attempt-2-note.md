# P1 attempt 2

Share reconciliation passed. Five of the six new tests passed. test_RawObservedHookParity failed with a bare assertion 50000000000000000 != 0, equal to the installed 5e16 seigniorage. Existing snapshot and weighted pricing tests in the same command passed. This is not a pass. The worker was steered to distinguish a bad zero-input control from an evaluator counterexample. Log: c4-p1-attempt-2.log.
