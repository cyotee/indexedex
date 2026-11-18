Publication limitation: `apply_patch` is unavailable. No other writer was used. The complete feedback follows.

## Identity

Member: grok. Phase: advisory review. Requested role: council-member. Requested model: xai/grok-4.7:high. Runtime identity: not exposed. Draft under review: `dtf-migration-gap-closure-plan-20261116-r1`. Coordinator-supplied SHA-256 `0fbc28eb001b2964b63b0bea527da03786c0347841bf8b3ef37a0cc020c405fc`, not recomputed. This feedback does not replace the proposal or the draft, does not authorize implementation, and does not demand another round.

## Draft under review

`docs/research/dtf-migration-gap-closure-plan-20261116/coordinator/draft.md`, identity `dtf-migration-gap-closure-plan-20261116-r1`. Read completely. Cited sweep, bond-delivery, and hook surfaces were reread. No peer planning file was read.

## Disposition

requested-changes

F2, F3, F4, the task order, and the Forge commands are executable as written. The selected F1 placement is right: implicit purchase sweep calls `sweepDustAtomic`, not `sweepDust`. The handoff must stay on explicit `sweepDust()` and must not be added to bootstrap or `sweepDustAtomic`. It is not executable as specified, because it leaves `residualInventory` above the token balance. P1's separate mixed hook and capture mapping are the right comparison, but the join call and the DETF acquisition step do not match the APIs that actually move those tokens.

## Concerns

1. Draft section: F1, Chosen mechanism and Acceptance. Concrete defect: the handoff adds the full donation amount to `residualInventory`, zeroes `donationInventory`, then calls `_sweepDustBody` without settling the residual book. With the budget closed, `_residualBalance` returns that mapping, so the sweep can join the released tokens. After a successful join, `residualInventory` is still the pre-join amount while the token balance has fallen. The next `_beginBudget` computes `operationFloor = balance - residualInventory` and reverts on underflow, or, if a later edit makes that subtraction saturating, lowers the floor and exposes recovery inventory. The stated assertions, donation book zero, LP increase, and recovery unchanged on the same call, all pass while this hole remains. Requested correction: keep the release only in the explicit `sweepDust()` wrapper, under one outer `nonReentrant`, and do not call `_entrySweepDust`. After `_sweepDustBody`, set each released non-self token's `residualInventory` to the unconsumed remainder, using the existing end-budget rule inside that wrapper if that is the smallest settlement. Add one regression that a later `donateMigrationCapital` opens a budget successfully and a seeded recovery balance is unchanged. Do not move the handoff to bootstrap or `sweepDustAtomic`.

2. Draft section: P1, Chosen mechanism. Concrete defect: claiming a mature ordinary bond does not yield parent DETF. `UniswapV4DetfMigrationBondNFTVaultTarget._deliverClaim` pays `deliverBondClaim` on the staking receipt, and the shared renderer states that claims pay sDETF. `joinNativeComponents` is also not a single `amounts` array. Its signature is `joinNativeComponents(uint256[] localAmounts, uint256[] shareAmounts, address to, uint256 minLp, uint256 deadline)`. An executor who joins the claim output, or who passes one array, cannot fund the comparison hook. Requested correction: claim principal, then redeem that sDETF for parent DETF through the existing receipt exit. Put raw pair and DETF amounts in `localAmounts` and the auxiliary Standard Exchange amount in `shareAmounts`. Do not mint through the migration parent.

3. Draft section: P1, Chosen mechanism. Concrete defect: `hook.standardExchangeOf(i)` does not exist for a leg index. `standardExchangeOf` takes a token address. The index view is `standardExchange(uint256)`. `captureWeightedMintBook` already returns `standardExchange`, `provider`, `rawReserve`, scales, and rate. Calling `MigrationWeightedPricingFixture.observed` on the parent reads the parent reserve hook, which this test must not use. The local book also cannot pass `PricingLib.validate` unless version is 2 and chain id, consumer, WETH, original DTF, fee, and seigniorage are set. Requested correction: call `Capture(comparisonHook).captureWeightedMintBook()`, map Raw and RawRate exactly as `MigrationWeightedPricingFixture.observed` already does, and set those book header fields before `validate`. Compare `evaluateOriginal(...).user` with `previewExchangeIn` on the comparison hook only.

## What was not adopted from others

I did not read peer planning responses. Relative to my proposal and the draft's disagreement section:

- A new `fundReserveFromBookedDonations` selector was not adopted. That is correct. Implicit sweep is `sweepDustAtomic` at `UniswapV4DetfCommon.sol:483-485`, so explicit `sweepDust()` can hold the release without the owner purchase consuming it. The missing piece is residual settlement, not a new selector.
- Caller-selected amounts and a required `minLpOut` revert were not adopted. Full release plus an LP-increase assertion is an allowed resolution of the funding choice. I do not ask to restore either, provided Concern 1 is fixed.
- A pure-library Raw comparison against the parent reserve hook was not adopted. The separate four-leg hook, with one auxiliary Standard Exchange and raw pair legs, matches the hook family's stated shape of at least one SE buffer leg. I do not ask to restore the parent-hook comparison.
- I cannot confirm the draft's account of Kimi's or MiniMax's omitted wording. Nothing in the cited source contradicts the draft's refusal to add an NFT wrapper, a TokenStaking adapter dependency, or a gas-campaign rerun.

## Limits

I did not recompute the draft hash, run tests, or read peer files. I did not inspect the hook package's deploy arguments beyond the interface statement that a weighted book has at least one SE buffer leg. The auxiliary leg satisfies that statement. I did not execute `previewExchangeIn` on a zero-SE leg. This file was not written.
