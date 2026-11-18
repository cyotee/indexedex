# P1 zero-fee diagnosis

dexSwapFeeOfVault treats a stored zero override as unset and returns the vault-type default. The measured default is 50000000000000000. previewOriginalCredit(0, 0) returned 0, so the failure is not an evaluator counterexample. A follow-up worker is replacing the impossible zero-fee assertion with a comparison against the hook's actual reported fee. Source: contracts/oracles/fee/VaultFeeOracleQueryFacet.sol dexSwapFeeOfVault.
