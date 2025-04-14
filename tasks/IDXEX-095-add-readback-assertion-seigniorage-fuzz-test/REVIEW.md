# Code Review: IDXEX-095

Origin: Converted from IDXEX-066 review suggestion

## Notes

- Add an `assertEq` similar to the other fuzz tests. Run the specific test file to verify behavior:

  forge test --match-path test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol
