# Astra — combined wings PRD cross-review

2026-10-05. Read all three other originals completely together; no cross-review artifacts. Original preserved. No execution. This proposes requirements for owner approval, not an implementation plan or economic safety certificate.

## 1. New direct evidence changes my geometry recommendation

Kimi identified a primary historical document I had not inspected. I now read `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` (F below). **F:66–83 directly describes** frozen first-create ticks, centerWidthMultiplier=2 (approximately ±one spacing), activeLiquidityBps=1000, and 90% of deployable token1 toward the lower wing / token0 toward the upper wing. Rebalance did not recast ticks. This supports restoring that **intent** rather than a full-range center.

F:98–102,141–147 records the later center-only replacement. Neither paragraph proves the implementation in commit `35f47b5…`, exact historical envelope algebra, or historical gas. My original “geometry unspecified” remains true for exact formulas, but was incomplete regarding historical intent.

## 2. Corrections to peers

* **MiniMax reverses orientation:** above current price an initially out-of-range upper wing holds token0; lower holds token1 (F:74). Holdings change after crossings. Its proposed full-range center is a new strategy, not restoration. Grok overstates the opposite claim: a full-range center can coexist with wings; it simply differs from the historical design.
* Scalar entry is required by the owner. Reject MiniMax’s dual-only live product and Grok’s reopening whether zaps exist. Dual-only **activation** does not imply dual-only subsequent entry.
* A sleeve is local spendable currency, not MiniMax’s inner position or “locally unlocked sub-account.” The singleton lock cannot be bypassed by another account. Kimi/Grok’s “impossible to touch while blocked” is too broad as protocol mechanics: manager operations are allowed during a session, but this product deliberately does not participate in an unauthenticated outer session.
* Spot-based proportional admission alone is neither proof of exploitation (Grok) nor safety. Evaluate complete attack-funded state transitions. TWAP guards also do not prove safety.
* FullSpread constants/routes are precedent, not automatically wings law. MiniMax’s “locked” table and deferred DoD contradict a proposed complete PRD. Acceptance criteria belong in the PRD even though execution does not.
* `forge test --gas-report` is not a top-level chain transaction measurement. Grok’s requested block limit is insufficient: transaction caps and outer-consumer overhead also bind. None of the originals measures wings.

## 3. Coherent proposed product — all parameters below need approval

**Identity:** separate `UniswapV4UpperLowerWingsStandardExchangeVault` under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`; preserve FullSpread. Registry-deployed vault diamond, not mined-address hook. Proposed initial pool admission: hookless; separately approve named hooked integrations rather than inherit arbitrary-hook support.

**Frozen geometry proposal:** spacing `s>0`; activation anchor `a=s*floor(tick/s)` using mathematical floor for negative ticks. Center `[a-s,a+s)`, lower `[a-w*s,a-s)`, upper `[a+s,a+w*s)`, with immutable deployment parameter integer `w>=2`. Proposal for a displayed default is **w=10**, explicitly newly selected, not recovered history or calibrated safety. Require all endpoints usable/in bounds; reject rather than silently shrink/collapse geometry. Three fixed distinct salts; no recenter/consolidation into full range in v1.

**Allocation proposal:** after sleeve reservation, allocate at most 10% of each token's deployable budget to center, choosing the binding liquidity amount. Allocate remaining token0 toward upper and token1 toward lower at activation. Do not pretend precisely 90% is always deployed: binding ratios and integer settlement leave residuals. Later price regions use exact range requirements and funded caps; unavailable opposite tokens leave residual inventory local. Permissionless maintenance adjusts these same positions without swaps or share mint, prioritizes sleeve shortfalls, pays no caller, and is a no-op within its accepted band. These restore historical intent, not verified historical bytecode.

**Sleeve proposal:** 20% of placeable per-token `F+D`, rather than FullSpread's later 20%-of-D convention; historical local-buffer PRD D7/D17 (`…LOCAL_LIQUID_BUFFER_PRD.md:150,160`) supports this choice. Uncollected fees enter economic backing but not spendable cover. Proposed deadband max(token floor, 5% target), with explicit token-floor formula still needing selection. Blocked deposits remain local; redemptions require full cover. No nested unlock or stale-reserve substitute.

**Ownership proposal:** `B_i=F_i+ΣD_ij+ΣE_ij`, excluding caller credit/liabilities. Dual-funded first mint with the existing decimal-scaled minimum formula and dead sink, proposed for reuse. Idle scalar deposit composes caller funds against post-swap incumbent B, accounts for all three positions' repricing/own fees, deducts caller placement loss, then mints min-ratio shares. Idle scalar redeem removes proportional position/local entitlement then converts at post-removal liquidity. Support both token directions, SY and sequential projections.

**Blocked scalar proposal:** retain the historical local CP issuance/redemption mechanism over complete B, with outputs capped by actual F, not physical wing withdrawal. This is an explicit economic selection requiring validation, not implied by sleeve funding. Use a proposed 30-minute TWAP and 100-bp spot-price deviation gate for scalar ownership operations; require mature observations, fail closed when unavailable. These numbers are uncalibrated proposals. Gate behavior, bootstrap warm-up and exit-liveness tradeoffs need owner approval. Keep in-kind/proportional supported routes separately specified, not silently subjected to every scalar gate.

Propose 50-bp caller-composition impact, 10-bp fee-inclusive execution-shortfall and 1-bp share-alignment limits as **provisional reused values**, never proof of concentrated-wing safety. No 25-bp maintenance-swap parameter when maintenance does not swap. Exact-output routes require their own integer-supported domains; useful scalar exact-in entry/exit cannot disappear to satisfy tests.

## 4. Complete acceptance and remaining decisions

Require production vault, manager, registry, fee oracle and real consumer hooks; no arbitrary SUT mocks. Controlled external token/provider fixtures need an explicit non-SUT purpose. Validate all range crossings, own/external liquidity, fee checkpoints, repeated maintenance, mixed decimals/native mapping if admitted, donation/pretransfer isolation, callback authorization, first-mint inflation, scalar/blocked-idle attack cycles, depleted sleeve and atomic rollback. Same-state preview/execution equality must include complete multi-position transition state.

Weighted: total n=2..8; buffered b=1..8 and raw r=n-b, all valid raw/buffer combinations and leg permutations. All-raw is a rejection/control for the SE-weighted package, not Grok's required successful row. A raw DETF self-leg leaves at most seven buffered legs. Also require Orbital/CP/SY/DETF lifecycle integration with wings plus other eligible SEs and bare tokens. Shared-manager/shared-pool dependencies must not double-count projected liquidity or fees.

Select target chains and deployed managers before claiming compatibility. Measure outer transaction receipts, including calldata/intrinsic and nested work, separately from subcall diagnostics; verify chain-active transaction limits (EIP-7825 specifies 2^24 where active), block limits and client/RPC policy. Historical 1.28M is not a baseline.

Remaining approval items: exact geometry/default width, sleeve convention/floors, blocked CP and price guards, scalar protections, fees/rate-provider semantics, hook/native/import admission, full route matrix, manager/network set and measured-work acceptance budgets. Final PRD must label selected proposals versus owner-approved requirements and include concrete success/rejection cases. No implementation plan, security proof or historical implementation/gas validation is claimed.
