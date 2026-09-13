# Remaining V4 policy-test migration

Engineering work under existing D39/D49/D50/D51 decisions; not an open product question. The current broad production-path checkpoint is `v4-cached-orbital-343-green-*`. The standard call migration and shared policy helpers have since been applied; their validation and the remaining family overrides are tracked in `execution-status.md`.

| Legacy test behavior | Required replacement behavior |
|---|---|
| `thresholdMode()` equals Policy/Open | The new V4 deployment has no mode argument/getter. Verify configured threshold values and selected primary/swap behavior. Shared legacy enum support required by excluded Balancer DETFs is not a V4 deployment option. |
| Minting in the deadband reverts with MintingNotAllowed | Quote and execute the actual reserve swap; verify funded output, existing swap fees, supply neutrality and final minimum. Do not catch arbitrary failures as gating. |
| Gated failure rolls back due expansion | Settle the due aggregate expansion first, then execute the selected primary/swap branch; reward and LP-custody assertions use funded staking and actual protocol LP. |
| Open mode never expands | Use a mandatory-gated instance with no eligible reserve premium; confirm no expansion while primary/swap selection still obeys the thresholds. A zero expansion-rate deployment argument retains the existing 10% default and does not disable expansion. |
| One-day epochs/four-epoch cap | Fixed eight-hour boundaries anchored to first bond; one uncapped aggregate catch-up from actually funded backing. |
| Expansion accumulates as DETF in the bond-NFT LP-claim reserve | Newly minted expansion funds the sDETF reserve and the agreed standing fee/creator sDETF receipts; NFT positions hold funded staking entitlements. |
| Reward principal or redemption equals user-owned reserve LP | Funded DETF principal, immediate stake, linear principal vesting and separately claimable staking rewards. The protocol retains all acquired LP. |

Apply these replacements to the shared CP and decimal policy helpers and their n-leg overrides, then consolidate duplicate wrappers without dropping distinct authorization, native-decimal, funding, or pool-state assertions. The existing `v4-existing-test-body-inventory.json` and `v4-legacy-test-api-occurrences.json` are discovery inventories, not completed coverage mappings. Full default compilation and attributed test results remain release work. D66 excludes unfinished Slipstream migration or validation from this list.

## Validated replacement behavior

`V4ReserveLiquidityBehavior.test_standardMintAndBurnFallbackMatchActualSwapWithoutIssuance` and `test_standardFallbackSettlesFundedCatchupBeforeBothDirections` passed in every reserve/policy combination in `v4-funded-fallback-and-packaging-108-green-*`. These establish the replacement assertions for the legacy gated-revert/expansion-rollback bodies: funded swaps, exact final previews/minimums, only actual expansion changing supply, staking reserve funding and unchanged protocol LP. The old test files have not yet been retired; native-decimal and production-SE distinctions still need complete migration/coverage mapping.
