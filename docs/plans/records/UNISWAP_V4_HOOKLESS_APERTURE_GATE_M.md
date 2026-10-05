# Gate M: withdrawn

**Status: removed by the owner on 2026-10-04.** It is not a limitation and does not block integration. The production edit to `TransitionPlanner._composition` is in scope. Do not use this file as a stop.

Stage 2 parity and lifecycle tests had already passed when the limitation was removed. Runtime size and the locked consumer commands are recorded in the Stage 2 record, not here.

## Identity

- Source revision at Stage 1 start: `92cdf89a6fefd9c2ff4f04f74bdade1a7d379f5b`
- Corpus version: `hookless-analytic-corpus-v1`
- Seed recorded in the corpus file: `uint256(0xA4E0000000000001)`
- Provenance: [UNISWAP_V4_HOOKLESS_APERTURE_PROVENANCE.md](UNISWAP_V4_HOOKLESS_APERTURE_PROVENANCE.md)
- Compiler: solc `0.8.35`, optimizer runs `1`, `via_ir = false`
- `foundry.toml` was not changed

## Checksums

- `AnalyticSwapMath.sol`: `64dd3eb1da76d6cd991aa8cac91030d10d6df1fa37ac1ae36423073a0da7f91d`
- `AnalyticComposition.sol`: `8bb08f66cc00bdcb0b68af3989b47ba0b09eb19c29cde48101c2bbc75869152a`

## Ceilings

| Counter | Ceiling | Over-ceiling result |
|---|---|---|
| Discovery core steps | 64 | `WorkLimit` |
| Bitmap word reads | 64 | `WorkLimit` |
| Certification core steps | 64 | `WorkLimit` |
| Placement evaluations | 3 | `WorkLimit` |

## Commands and results

Analytic contract filter, 2026-10-04, `--offline`:

```bash
forge test --match-contract 'Analytic(SwapMath|Traversal|CorpusTest|Certification)' --offline
```

46 tests passed, 0 failed. That includes math, traversal, corpus, planted witnesses, live protocol fee, a real fee-3000 LP-fee pool, a 6/18 pool, and both-direction executor settlement.

Planted witnesses withheld from the planner and certified by the reference:

- Multi-step, credit `1e9`: `500024998`, source quote steps `2`
- 6/18, same liquidity shape and credit: `500024998`

`Reference._classify` completed for credit `64` (`test_referenceClassifiesSmallCredit`). Credit above `4096` remains `Unknown` and is not used as a success discharge.

Production dispatch after the composition replacement:

```bash
forge test --match-path test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/QuoteExecutionParity.t.sol --offline
forge test --match-path test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/TransitionLifecycleClosure.t.sol --offline
```

6 parity tests passed. 9 lifecycle tests passed. The first parity run failed `ArtifactCreationCode: cyclic or excessive library dependencies` because `AnalyticComposition` imported `TransitionPlanner`. That import was removed. Certification now calls `Inventory._safePlacement` and a local `_afterSwap` with the same booking as `TransitionPlanner._afterSwap`.

## Remaining limitations

- No frozen Stage 2 gas baseline. No `forge build --sizes` record. No orbital, DETF, or Pons consumer command.
- Corpus negative discriminant and overflow tests check the failure enum. The real inputs are in the math suite.
- No dedicated corpus case forces a price move above 50 bps.
- Discovery and bitmap word-65 tests accept `WorkLimit`, `Rejected`, or `OutOfDomain`.
