# Remediation authoring round — consolidation

Date: 2026-10-04. Four original proposals and four combined cross-reviews completed in the retained sessions below. No implementation or tests run. Each review received the other three originals, not their cross-reviews. Prior-round independence limitation (Kimi's incidental peer-snippet exposure) remains disclosed in the parent consolidation; no new incident was reported this round.

| Researcher | Session | Original | Review |
|---|---|---|---|
| Astra | `ses_ef7c68835ffey58T5UT2G8JDZo` | [original](astra-original.md) | [review](astra-cross-review.md) |
| Grok | `ses_ef7c1c50fffe87e6QGupvs3xke` | [original](grok-original.md) | [review](grok-cross-review.md) |
| MiniMax M3 | `ses_ef7bc045effeTc96xsW5R2MidY` | [original](minimax-original.md) | [review](minimax-cross-review.md) |
| Kimi K3 | `ses_ef7b7b72fffe3JJ0CVG6FmBRGL` | [original](kimi-original.md) | [review](kimi-cross-review.md) |

## Final documents

- [Remediation PRD](../../../plans/UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_REMEDIATION_PRD.md)
- [Implementation plan](../../../plans/UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_REMEDIATION_PRD.plan.md)

## Original positions and corrections

- Astra proposed raw full-book/flexible and terminal-zap ownership now, preserving fee/bookkeeping failures; separate decisions for partial pricing and recovery. Cross-review retained this scope and sharpened exact backing/rounding and inverse-search requirements.
- Grok initially proposed scaling last stored reserves during outages without a new slot. Cross-review retracted that fallback as an unapproved stale-valued-state change, adopted fail-closed default and partial-pricing deferral.
- MiniMax initially proposed skipped fee mint and cached rated state during outages, raw partial inputs into existing NAV, and an unjustified small rounding bound. It withdrew the fee-skip default and one-wei bound but retained inconsistent cache/radius-bypass suggestions and opposed ceil backing. Those positions are NOT adopted.
- Kimi initially included partial conversion remediation and an overbroad rate-invariant zap assertion. Cross-review narrowed partial pricing to an owner decision, accepted fixed-post-swap terminal invariance and ceil backing, and retained fail-closed default.

## Moderator resolution of dissent

The raw ratio rule is agreed. The plan does not pretend all proposals agree about implementation:

1. **No stale/scaled reserves or ignored radius checks.** Keeping old L2 after inventory changes is a behavioral change even without adding storage. Skipping a fee mint is not proven fee-neutral by leaving old kLast. All such outage redesigns are deferred.
2. **Mint floor; required backing ceil; payout floor.** For S=10, B=3, C=1, m=3, floor(mB/S)=0 would permit three LP without this leg's contribution. Therefore MiniMax's floor-pull rationale is rejected. Use actual delivered backing inequalities, not a claim that lower pulls favor incumbents.
3. **Partial pricing remains undefined by the raw rule alone.** The present `sphereNavShares` uses weights R-r on a rated sphere. Swapping in raw SE shares without a compatible radius/invariant is not a safe mechanical fix. Defer only that economic branch, not full-book work.
4. **Terminal versus full-zap invariance.** Actual swaps may change with rates. Hold post-swap balances/contributions and post-fee supply fixed to test rate-free terminal ownership.
5. **No invented small error bound or gas proof.** Exact raw reference, mixed decimals, full-width backing, total quote-count measurement and complete test results are required.

## Evidence and confidence

Direct moderator inspection confirms `Orbital Math.sol:146–170` floors both existing mint and used amounts, and `:380–391` uses rated sphere-NAV spot weights. Current Common/ExitQuoteLib paths and family addenda are cited in the PRD and parent consolidation. Repository configuration was previously observed as solc 0.8.35, optimizer runs 1, via-IR false; the implementation agent must record actual source/toolchain/artifact identities before measurements.

Researcher references to incidental LSP diagnostics do not establish pre-existing compiler errors. Untouched assertion files do not prove failures unrelated. No performance or exploit demonstration was executed this round. High confidence in raw-domain separation and ceil-backing arithmetic; unresolved policy on partial joins and outage recovery is explicitly not an engineering fact.

## Human checkpoint

The bounded implementation can proceed under a separate implementation task naming the plan. Partial/unbalanced pricing needs a specified raw rule; outage recovery needs separate fee/cache/ABI decisions. Neither authoring these files nor the retained owner direction authorizes silently selecting those designs. No production paths were edited in this authoring round.
