# Code Review: IDXEX-094

Origin: Converted from IDXEX-066 review suggestion

## Notes

- Small defensive change. Ensure `_validateWadPercentage()` is available in scope and called before any storage writes in `_initVaultRegistryFeeOracle`.
- Run `forge test --match-path test/foundry/spec/oracles/fee/...` to verify no regressions.
