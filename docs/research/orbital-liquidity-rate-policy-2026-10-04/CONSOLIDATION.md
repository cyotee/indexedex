# Council: Orbital liquidity rate policy

Date/access: 2026-10-04. Research only. No implementation, compilation, tests, deployments, configuration or instruction changes performed in this council round.

## Question and answer

Should every liquidity operation fetch rates, only zap-in/zap-out operations, or none?

**Classify the sub-operation, not the entrypoint name.** Use raw concrete inventory for proportional ownership; use rated reserves for actual swap pricing, including swaps inside Orbital zaps. Actual SE buffering/redemption needs conversion quotes, not an assumed rate-based payout. Bootstrap, protocol fees and state synchronization need separate family-specific policies.

The closest option is rates for zap swap legs, but standalone swaps also require rates. Nor does this imply every function named `depositSingle` performs a multi-leg zap: Weighted's family law specifies inventory-domain single-asset joins/exits.

## Round and provenance

Four original passes and four continuations completed, each continuation given all three other originals, never peer cross-reviews. Originals are preserved. Kimi disclosed that an early broad grep incidentally exposed two peer snippets; it reported not relying on them. Consequently this is a completed four-member round with an independence limitation, not four perfectly sealed first passes.

| Researcher | Original session | Original | Cross-review |
|---|---|---|---|
| Astra | `ses_ef7c68835ffey58T5UT2G8JDZo` | [original](astra-original.md) | [cross-review](astra-cross-review.md) |
| Grok | `ses_ef7c1c50fffe87e6QGupvs3xke` | [original](grok-original.md) | [cross-review](grok-cross-review.md) |
| MiniMax M3 | `ses_ef7bc045effeTc96xsW5R2MidY` | [original](minimax-original.md) | [cross-review](minimax-cross-review.md) |
| Kimi K3 | `ses_ef7b7b72fffe3JJ0CVG6FmBRGL` | [original](kimi-original.md) | [cross-review](kimi-cross-review.md) |

Researchers' outputs are attributed evidence, not authority. Reported incidental LSP diagnostics do not establish whether errors are stale or pre-existing; no compiler was run to classify them.

## Source facts checked by moderator

All paths below are repository-relative. `O/` abbreviates `contracts/hooks/uniswap/v4/standardExchange/orbital/`; abbreviated Solidity basenames have prefix `UniswapV4StandardExchangeOrbitalBufferHook`.

- `CLAUDE.md:12,83`: research council is distinct from implementation; canonical IndexedEx skills are read from `.claude/skills/`.
- `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md:112`: raw liquidity, rated swaps.
- `O/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828–835`: current addendum specifies rate-provider swap valuation and raw share-ratio LP issuance/pro-rata exits. Its older implementation plan still says v0.5 and zap-in only (`...IMPLEMENTATION_AND_TEST_PLAN.md:3–18,39–41`); current code and newer law take precedence over that narrative.
- `O/Common.sol:1066–1083`: full-book joins use rated inflows and rated reserve coordinates.
- `O/Common.sol:1093–1112,1145–1183`: partial join calculations mix face offers with effective reserves and lack the full-book inverse conversion. This is a specific unit-accounting concern, not an established quantified exploit.
- `O/Common.sol:1287–1356`: proportional exit slices raw tokens or live SE share balances; SE shares may then be unwrapped. Raw ownership allocation does not make redemption rate-independent or costless.
- `O/Common.sol:1359–1366`: payout is followed by sphere recomputation, fee snapshot and reserve synchronization. `:459–479` uses effective/rated reserves for synchronization and recomputation. A provider failure on remaining buffered inventory can therefore revert an exit even with growth fees disabled. Full execution is not rate-free merely because the pro-rata formula is raw.
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md:61–74`: Weighted uses native inventory for LP math, first mint and `kLast`; its single-asset entry/exit is not Orbital's multi-leg zap.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol:36–56`: the cited Weighted funded fixture has three legs and ERC4626 SEs over `SimpleYieldERC4626`, not FullSpread vaults.

Researchers additionally traced `O/ExitQuoteLib.sol:272–295,347–381`, `O/ClaimLib.sol:317–338`, APEX D59/D60/D63, fee paths, and actual single-output exit execution. See preserved reports for full citations. Source build configuration reported by researchers: solc 0.8.35; no installed compiler/runtime version or source commit was independently measured this round.

## Attributed positions and corrections

- **Astra:** raw inventory for ownership, rated swap pricing; separate bookkeeping. Initially and after review identified fees-off exit rate dependence. Cross-review added the partial-join concern and an overmint arithmetic example.
- **Grok:** initially said proportional exits were rate-free; corrected this after tracing unconditional post-payout updates. Emphasizes partial joins as the stronger implementation concern and rejects treating rated variable names alone as exploit evidence.
- **MiniMax M3:** initially asserted bit-identical cancellation and no current correctness defect. Retracted bit-identical cancellation. Its cross-review still incorrectly restricts exit rate dependence to fees-on conditions and misstates the Weighted contract's existence. These assertions are not adopted. It also overgeneralizes some single-asset join and D63 scope statements.
- **Kimi K3:** initially understated rounding severity and restricted liveness risk to active fees. Corrected both after review. Highlights partial-join unit mixing, distinguishes Weighted's inventory-only law, and discloses the first-pass independence limitation.

**Agreement:** raw proportional ownership, rated swaps, necessary conversion simulation, and insufficient evidence for the moderator's blanket bug assertion.

**Not full agreement:** correctness severity/reachability and precise bootstrap/fee law. MiniMax's remaining exit-liveness explanation conflicts with source and the other three reviews. The moderator resolves the source-level question in favor of the unconditional update calls, without claiming unanimous consensus.

## Why cancellation does not settle correctness

With exact arithmetic and a common per-leg rate `r`, `(newShares*r)/(heldShares*r) = newShares/heldShares`. Rates may differ between legs: cancellation is within each leg.

Separate integer floors break this equivalence. Hand example (not an executed exploit): held=3, contributed=2, rate=1.5, LP supply=12. Raw issuance gives `floor(12*2/3)=8`; separately floored rated units give `floor(12*3/4)=9`. A one-unit conversion error can become a larger ownership error. Whether a production state reaches this depends on supported scales, minimum liquidity, other binding legs and actual buffering.

Zero-result fallbacks that substitute face amounts for rated claims further defeat a blanket cancellation proof. Raw ratios are preferable to relying on conditional cancellation. Exact backing and rounding tests remain required.

## Corrections to the earlier discussion

1. A single-output LP exit that swaps residual legs is a zap-out-type workflow. Describing it as an ordinary proportional exit was misleading.
2. Presence of rated balances in a zap planner is not itself evidence of a bug: swaps legitimately need them. The LP mint/burn and conversion boundaries require separate analysis.
3. The passing Weighted funded-binding results do not prove FullSpread compatibility; their fixture uses different SEs. The fixture is also three-legged, so a two-rates-versus-three explanation is not established.
4. The old planner's matched-state gas advantage was not measured in this round or established by the prior claims. Historical logs, comments and test names are not such a benchmark.
5. A rate read is not synonymous with a vault transition quote, and is not guaranteed cheap. Current gas failures and manipulation risks are distinct questions.

## Recommended operation policy

| Component | Accounting/pricing policy |
|---|---|
| Proportional join ownership | Actual raw token/share contributions versus corresponding held raw inventory; explicit rounding |
| Proportional exit ownership | Pro-rata raw token/share entitlement; unwrap only when requested/required |
| SE buffer/unwrap | Actual conversion quantities, fees and projected state; do not replace with `amount * rate` or 1:1 |
| Standalone swap / Orbital zap swap | Rated invariant; fail closed on invalid rates; preserve sequential state |
| Terminal proportional mint/burn after zap | Raw post-conversion holdings and contributions |
| Partial/unbalanced joins | Explicit family economic rule; repair unit mismatches, do not assume proportional formula covers them |
| Bootstrap / protocol-growth fees | Preserve explicit family policy pending a separate decision; Weighted and Orbital differ |
| Post-operation state refresh | Specify whether provider failure may revert withdrawals; raw in-kind recovery requires deliberate fee/cache semantics |

Do not silently use rate=1, stale valuation, waived fees or weakened caps to obtain liveness.

## External corroboration and limits

Researchers used Context7 `/balancer/docs` and Balancer primary documentation, accessed 2026-10-04:
- https://github.com/balancer/docs/blob/main/docs/reference/contracts/rate-providers.md
- https://raw.githubusercontent.com/balancer/docs/main/docs/reference/lp-tokens/underlying.md

These are corroboration, not authority over IndexedEx product law. No external docs are needed to establish the local arithmetic or call paths.

High confidence in the policy split, fixture correction and unconditional exit bookkeeping dependency. Medium confidence in economic severity of the partial-join and rounding issues. Exploit reachability, matched-state gas, current full-matrix test outcomes and final deployed sizes are unverified here. Consensus and passing tests are not security proofs.

## Human decision checkpoint and implementation handoff

Recommend confirming raw ownership/rated swap separation and commissioning a scoped Orbital remediation PRD covering full-book mint rounding, partial-join units, and provider-failure exit liveness. Decide separately whether an explicit raw in-kind recovery path is required and what happens to growth fees and sphere state on that path.

Implementation handoff (not executed): trace complete entrypoints, build raw-vs-rated differential and hostile-provider tests, preserve exact SE conversion accounting, benchmark actual FullSpread fixtures under unchanged transaction budgets, and reconcile stale family documentation. Do not treat the removed Gate M sequencing restriction as permission to waive accounting, gas, or consumer-success requirements.
