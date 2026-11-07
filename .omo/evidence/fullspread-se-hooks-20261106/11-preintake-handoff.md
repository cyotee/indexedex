# Task 11: CURVE QUAD strict pre-intake source handoff

Date: 2026-11-07.
Status: source and test edits handed to the parent; no compilation or runtime claim.

## Contract implemented in source

Authority is the FullSpread PRD's FS-HOOK-05 through FS-HOOK-10, with the parent's literal pre-intake/caller-only interpretation. The earlier implementation plan is context, not competing economics.

`JoinCore` snapshots supply and all incumbent share/local/raw components before pulling or converting caller inputs. Every entry uses caller-only SE conversion followed by the same component-limited gross mint and ceil acceptance against that original snapshot. There are no join-time component trades against incumbent inventory and no post-trade replacement of the snapshot.

Removed `tradeJoinBasket`, `commitJoinTrades`, and join rate collection from the family engine. `projectedShareJoin` no longer trades against the book or accepts a projected rate as an LP ownership input. The published `JoinComponentTrade` event declaration remains for ABI compatibility, marked retired; no family engine emits it.

Single-input previews return zero when another positive original leg cannot be supplied. The SE exact-input preview reports the whole input as unconsumed for that impossible join. Exact-net requests with another positive original component revert `Slippage()` before funding instead of attempting rate-based sizing and incumbent trades. Zero-gross proportional/flexible previews report zero used amounts.

Kept caller SE deposits/redemptions, actual refund reconciliation, rate-free genesis denomination, actual 5% share redemption, backed gross/net fee split, and component ceil acceptance. `acceptBasket` still commits every accepted component before sending any refunds; LP issuance remains committed before refund callbacks. No edits were made to the parent's Newton/StableSwap math fixes, swap or exit engines, or refund-observer test.

## Changed paths

Production root: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`

- `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol`
- `interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol`

Test root: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/`

- `UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting.t.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHook_Liquidity.t.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHook_B6Firm.t.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHook_Adversarial.t.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi.t.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `UniswapV4StandardExchangeCurveQuadStableBufferHook_OwnerDuringLock.t.sol`
- `decimals/UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals.sol`

This handoff is the only additional edited path. No shared cross-family library or behavior was edited.

## Exact changed regression tests

In `UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting.t.sol`:

- `test_H643_singleJoinMissingComponentsRollsBack`
- `test_H643_depositAliasMissingComponentsRollsBack`
- `test_H643_flexibleJoinMissingComponentsRollsBack`
- `test_H643_flexibleDepositMissingComponentsRollsBack`
- `test_H643_seJoinMissingComponentsRollsBack`
- `test_H643_syJoinMissingComponentsRollsBack`
- `test_H643_orderedSparseJoinMissingComponentsRollsBack`
- `test_H643_listedSparseJoinMissingComponentsRollsBack`
- `test_H643_permit2SingleJoinMissingComponentsRollsBack`
- `test_H643_eachMissingLegRejectsOrderedListedAndFlexible`
- `test_H643_preownedShareSingleJoinMissingComponentsRollsBack`
- `test_H643_shareAddressAliasMissingComponentsRollsBack`
- `test_H643_flexibleShareJoinMissingComponentsRollsBack`
- `test_H643_seShareAliasMissingComponentsRollsBack`
- `test_H643_syShareAliasMissingComponentsRollsBack`
- `test_H643_bufferedPairSingleJoinMissingComponentsRollsBack`
- `test_H647_exactNetMissingComponentsRejectsBeforeFunding`
- `test_H647_seExactNetMissingComponentsRollsBack`
- `test_H645_rawSingleJoinCannotBorrowDisabledShares`
- `test_H646_basketMinimumRestoresCallerConversionState`

The missing-leg test checks each of the four possible omitted legs through ordered, listed, and flexible execution. Finite ERC20 allowances make consumed-allowance rollback observable. The snapshot covers caller/hook pair and SE custody, caller/fee/incumbent LP, supply, SE supplies, native/SE book getters, ERC20 and Permit2 allowances/nonces, conversion approvals, the primary SE rate and underlying custody, manager custody, hook currency deltas, manager lock/delta count, and synced currency/reserves.

In `UniswapV4StandardExchangeCurveQuadStableBufferHook_Liquidity.t.sol`:

- `test_depositSingle_withdrawSingle_previewEqualsExec`: impossible join rejects; a real genesis-funded LP fraction still exercises the positive single exit.
- `test_joinSingleAssetExactOut_previewEqualsExec`: both preview and execution reject the impossible exact-net join and preserve funding/LP/fee balances.

In `UniswapV4StandardExchangeCurveQuadStableBufferHook_B6Firm.t.sol`:

- `test_B6_depositSingleFlexible_seShare_previewEqualsExec`
- `test_B6_withdrawSingleFlexible_paysSeShares`: positive setup now uses a complete caller-funded proportional basket rather than an impossible single-input top-up.

In `UniswapV4StandardExchangeCurveQuadStableBufferHook_Adversarial.t.sol`:

- `test_C1_reentrancy_join_hitsReentrancy`: positive control is a complete basket; hostile callback still attempts the guarded single-deposit selector.

In `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi.t.sol`:

- `test_T4_3_afterLive_joinSingleAsset_pairAndShare`

In `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`:

- `test_row_previewMatchesExecution`, through `_assertDepositSinglePreview`: zero preview plus atomic rejection replaces impossible single-input success; join-basket, exit, and swap preview checks remain.

In `UniswapV4StandardExchangeCurveQuadStableBufferHook_OwnerDuringLock.t.sol`:

- `test_D89_ownerJoinAtMin_requiresCompleteCallerBasket`: unauthorized rejection remains; owner single input cannot borrow the locked floor's backing; a complete owner-funded basket still must mint positive LP at minimum supply.

In `decimals/UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals.sol`, across its concrete decimal variants:

- `test_depositSingle_withdrawSingle_previewEqualsExec`
- `test_C1_reentrancy_join_hitsReentrancy`
- `test_B6_depositSingleFlexible_seShare_previewEqualsExec`
- `test_B6_withdrawSingleFlexible_paysSeShares`

No skips or tolerance changes were introduced.

## Required positive controls retained

The component suite still inherits `HookExactNetComponentAccountingBehavior`; neither its inheritance nor `_hbExactNetRequest`/`_hbExactNet` adapters were removed. The parent-owned shared file now contains `test_HB47_exactNetCannotBuyMissingIncumbentComponents`, observed read-only during handoff.

Existing positive tests retained include:

- `test_H643_orderedFacadeAndFlexiblePreviewAgree`
- `test_H643_addressListedShareBasketReachesPositiveJoin`
- `test_H643_permit2ShareSeedReachesActualPositiveJoin`
- `test_H643_zeroLocalAfterSwapStillAcceptsBackedPairJoin`
- `test_H645_reenableKeepsLocalOwnershipOnNextShareJoin`
- `test_H648_disabledGenesisUsesOnlyPermittedRedemptions`
- `test_H648_fourSeLegsSeedAndExitOnRealProxies`
- The inherited independent component-ledger, fee, bootstrap, pair-funded and share-funded basket controls.

There is no actual CURVE QUAD live single-input positive topology to report: `_isLive()` requires a nonzero raw or SE component on all four legs, so every single input omits another positive original leg. Zero components *within* a funded leg remain ignored by component sizing; the zero-local positive basket test remains. No topology or live-status rule was changed.

The original FullSpread V4 matrix row and its swap cases were not edited. Actual swaps/exits retain Curve StableSwap pricing; the removed mechanism was join-time incumbent component trading only.

## Static checks and limitations

- File-specific Native LSP diagnostics returned `No diagnostics found` for all 12 edited Solidity files. A final check of the component suite after adding the complete rollback snapshot also returned no diagnostics.
- Literal scans of the family source found no `tradeJoinBasket`, `commitJoinTrades`, `joinRates`, or `_needsBasketTrades` references. Source and test scans found no remaining post-trade join oracle or `_assertTradedJoin` reference.
- Directory-level LSP checks were unsupported: source-directory dispatch selected `.md`; the test-directory dispatch reported no supported source files. Explicit `.sol` checks above were used instead. This is static feedback, not compiler evidence.
- No build, test, artifact writer, Git operation, install, deployment, delegation, or memory write was run. No generated artifacts were refreshed. All runtime, compiler/linking, gas, and complete-family regression validation remains with the parent.
- Necessary shared expectation: exact-net single-input success against a full positive basket must remain replaced by the parent's strict rejection/rollback test. No additional shared edit is requested by this source handoff.
