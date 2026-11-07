# Final artifact-size classification

`54-final-build.log` records the successful final plain Solar build.
`54-final-sizes.log` records the complete final size table and the nonzero
global size-check result. No size limit was raised or diagnostic hidden.

All 77 non-harness FullSpread, SE buffer-hook and V4 DETF product entries
in that table fit both runtime 24,576 and initcode 49,152 bytes. The
largest runtime is the single-CP ClaimLib at 21,570 bytes; Curve ClaimLib
is 21,484, Weighted LiquidityLib is 18,746, and the FullSpread MoneyFacet
is 17,184. This includes the newly installed native-component routes.

## Why the global size command still exits 1

The following 13 table identities exceed a runtime or initcode limit.
Their sizes are identical to `19-final-size-receipt.md`; they are not
new regressions from the clarified single-input or native-route repairs.
That earlier receipt is not a pristine pre-task baseline, so this report
does not claim every oversized artifact predates this entire session.

| Artifact | Runtime | Initcode | Source class |
|---|---:|---:|---|
| FullSpreadSameManagerAmmFixture | 40,333 | 40,378 | Foundry fixture |
| Handler_UniswapV4PairTokenStandardExchangeVault | 25,425 | 28,530 | Foundry invariant handler |
| NonfungiblePositionManager | 26,787 | 27,517 | Uniswap V3 vendor implementation |
| SeMatrix_AaveLoopFixture | 2,444 | 806,423 | Foundry fixture constructor |
| SeMatrix_AerodromeFixture | 1,690 | 57,765 | Foundry fixture constructor |
| SeMatrix_BufferPoolFixture | 1,871 | 316,680 | Foundry fixture constructor |
| SeMatrix_CbmvFixture | 1,883 | 319,333 | Foundry fixture constructor |
| SeMatrix_CbmvsFixture | 1,872 | 318,840 | Foundry fixture constructor |
| SeMatrix_MbmvsFixture | 1,874 | 319,261 | Foundry fixture constructor |
| SeMatrix_MixedLegFixture | 1,871 | 320,066 | Foundry fixture constructor |
| SeMatrix_MultiPairFixture | 1,884 | 319,335 | Foundry fixture constructor |
| SeMatrix_StataFixture | 2,837 | 781,084 | Foundry fixture constructor |
| VaultMock | 31,736 | 42,937 | Balancer vendor test mock |

Artifact metadata identifies the fixtures under
`test/foundry/spec/hooks/uniswap/v4/standardExchange/`, the invariant
handler under
`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/harness/`,
the position manager under
`lib/crane/contracts/protocols/dexes/uniswap/v3/periphery/`, and VaultMock
under `lib/crane/contracts/protocols/dexes/balancer/v3/test/mocks/`.

These test helpers and unrelated vendor artifacts are not the deployed
FullSpread/SE-hook/DETF products being delivered. Their global size
diagnostic remains visible and unresolved; it is not labelled a green
whole-repository size gate or deployment authorization.
