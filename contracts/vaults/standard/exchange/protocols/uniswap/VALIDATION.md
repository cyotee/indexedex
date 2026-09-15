# V2 implementation validation

Date: 2026-09-15. Local hermetic fixtures; no live transactions.

## Result

**419 passed, 0 failed, 0 skipped, across 46 suites.** This expands the initial 86-test remediation run with feature suites, additional regressions, mixed-decimal cases, and stateful campaigns.

- Fuzz cases: **128 runs per fuzz test**; Foundry also replays cached counterexamples where present.
- Stateful campaigns: **64 runs × 96 operations for each of V3 and V4**, totaling **12,288 operations**. Unexpected handler reverts fail the campaign. Each operation probes both raw and prepared zero-delivery claims for both tokens; ghost accounting reconciles issued/burned shares and all asset custody. Deterministic sequences ensure every handler is exercised.
- Solidity **0.8.35**, optimizer runs **1**, **no viaIR**, repository default hermetic profile.
- **26** facet/delegate/package runtimes fit EIP-170; largest **23,737 bytes**. [VALIDATED_ARTIFACTS.json](VALIDATED_ARTIFACTS.json) records sizes and SHA-256 of the exact unlinked runtime object strings, including their `0x` prefix.
- All **96** hashes in [PRESERVED_SOURCE_SHA256.json](PRESERVED_SOURCE_SHA256.json) still match. Original implementations and their tests remain in place.

[REGRESSION_RESULTS.txt](REGRESSION_RESULTS.txt) contains the test runner output. The [README](README.md#validation) records the complete build-before-test command. Forge required execution outside the macOS sandbox because system-proxy discovery crashed inside it; tests used local protocol deployments and no RPC. No unrelated monorepo suite or live-chain replay is included in this count.

## Suites and independent controls

Tests live under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`:

| Directory / suite | Evidence |
|---|---|
| `remediation/*PreservedBaseline*` | Real old registry packages mint unfunded shares after trades in both directions, then redeem real assets. A no-movement control rejects the same claim. The old locked exit quotes approximately 100 for a tenth of the `(1000,1000)` book; the paired new test quotes approximately 190. |
| `remediation/StandardExchangeDeliveryBehavior.sol` | Shared public-route assertions run on V3, V4 ERC20 and V4 native currency/WETH. Exact delivery, caller/calldata binding, donations, missing/short/excess delivery, replay, all input/output modes, refunds, locks, FoT rejection and rollback. |
| `remediation/StandardExchangeReleaseBehavior.sol` | SY own-share and prepared internal redemption; donated-share isolation; callback attacks against preparation, exchange and SY; permit replay/allowance consumption; disabled vault/package exits; malformed preparations; sleeve ratios; every compiled Target ABI selector installed on the actual registry proxy. |
| `remediation/StandardExchangeConstantProduct.t.sol` | Independently worked swap-plus-mint and burn-plus-swap references, limiting-side dual mint, surplus donations, inverse minimality, dust, empty backing, exhaustion and >256-bit reserve products. |
| `release/v3/` | Real V3 pool, NPM imports, fees, full-range placement, sleeve rebalance, routes, limits, previews, projected transitions, multi-input/output, registry metadata, and Crane facet behavior checks. Mixed-decimal pools use whole-token price parity for 6/18, 9/18 and 6/6 assets. |
| `release/v4/` | Real PoolManager and PositionManager, ERC20/native settlement, imports including earned fees and ownership/minimum failures, full-range placement, fees, sleeve rebalance, routes, limits, transition quotes, TWAP writes/failure handling, multi-input/output, registry and facet declarations. Four decimal fixture variants include 6/18, 18/6, 9/18 and both-six-decimal assets. |
| `release/sy/` | Native SY metadata, allowance-free caller redemption, fresh internal share delivery, slippage rollback, rewards views, and locked-pool use. |
| `invariants/` | Real deployments, separate funded trader, six stateful operations: deposit, withdrawal, market trade, donation, rebalance, and sleeve configuration. The attacker owns no input tokens. All successful supply changes have an identified funding/burn operation. |

Feature suites were ported to the distinct V2 packages. Their legitimate push calls now prepare exact inputs. Blocked withdrawal expectations use an independent proportional-burn-plus-swap reference, not the new production math helper. Existing old-version test files were not edited.

The SUT vaults, manager, registry, fee oracle, facets, pools and position managers are real. External helper contracts supply tokens, protocol callbacks, NFT metadata, and an intentionally reverting advisory TWAP dependency. Constructor-error tests inspect actual package creation-code reverts; all successful vault deployment uses the manager registry.

## Shared pretransfer acceptance matrix

| Gate | Concrete coverage |
|---|---|
| PT-01 | Old/new price-movement regressions for both protocols, with actual redeemable baseline profit and zero new-version claims. |
| PT-02 | Both movement/input directions, bounded trade-size fuzzing, imported-position probes, and 2%/20%/50%/100% sleeve choices. Imported probes run on the new packages; old profitable reproduction uses ordinary positions. |
| PT-03 | Old no-movement control, new no-position/donation control, and honest pull/prepared funding after trades. |
| PT-04 | Exact-in/out asset swaps, single/multi joins, share withdrawals and two-token exits; execution through installed proxies/delegates. |
| PT-05 | Malformed/zero/short/excess input, replay, donor balances, share refunds, recipient/caller/calldata binding, partial-failure retry. |
| PT-06 | Earned fees, import, collection through public operations, add/remove rebalance, price movement and native settlement; pending funding blocks interleaved rebalance. |
| PT-07 | Real V3 flash locks and V4 outer unlock sessions; valid funded callbacks plus preparation/exchange/SY callback attacks. |
| PT-08 | Both stateful campaigns described above, including collection through rebalance/deposits/withdrawals. |
| PT-09 | Decimal fixtures, dust/empty backing, exhausted reserves, integer inverse minimality, large products and atomic failures. Fuzz domains are bounded, not exhaustive proofs over uint256. |
| PT-10 | Shared behavior and stateful assertions on both families, independent math examples, and family-specific fee/position tests. |
| PT-11 | Crane declaration controls, registry metadata, all Target ABI selectors on the proxy, exact public routes, preserved hashes and refreshed artifacts. |

## Constant-product acceptance and remaining boundaries

| Gates | Evidence / boundary |
|---|---|
| CP-01–03 | Preserved hashes and distinct artifacts; two-token activation/donation cases; proportional and limiting-side issuance. |
| CP-04–06 | Independent zero-fee example, skew fuzzing, fee-bearing real-pool exits, exact-output minimality and rollback, large-number and near-empty pure math. |
| CP-07 | Reconstructed hermetic accounting examples and old/new locked-exit comparison. **No exact replay of the historical user's transaction or intervening chain state.** |
| CP-08 | Same/opposite-token round trips, projected sequences, separately funded market trades, stateful deposits/withdrawals and explicit donor/incumbent accounting. These are bounded campaigns, not an exhaustive economic proof. |
| CP-09 | Real pool-session callers and SY routes are covered. **A release-specific production consuming hook/router integration remains open.** Existing push-only consumers require preparation changes and must not be repointed automatically. |
| CP-10–11 | Sleeve choices, public fee collection/rebalance, complete-book transitions, quote/execute parity, refunds, native SY and invalid routes. |
| CP-12–14 | Decimal/native/import/full-range/rounding tests; callback and permit negatives; complete deployed Target surface. Tick walks are bounded, not every possible tick. |
| CP-15 | Local vault/package disable blocks inbound operations and preserves withdrawals. No deployed old-instance control was exercised. |
| CP-16–17 | Shared PT matrix and independently deployed V3/V4 fixtures above. |

These tests provide reproducible regression and feature evidence. They do not certify arbitrary existing DETF, Pendle, router, or hook compositions, and do not replace review of the new implementation or deployment-specific integration testing.

## Fixes exposed by this expansion

The broader suites found two new-version integration issues, fixed in this change:

1. SY redemption now validates a fresh transfer of the caller's own shares, or a prepared internal-balance redemption, through the common delivery path. Existing donated shares remain unclaimable.
2. New vault/package disable controls preserve share withdrawals, including prepared exact-output exits, while continuing to gate inbound operations.

Both fixes apply only to the new V2 trees and have direct regression coverage.
