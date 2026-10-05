# PRD: Orbital raw-inventory liquidity remediation

**Date:** 2026-10-04  
**Status:** Ready for a separately authorized implementation of the bounded scope below. Partial-book pricing and outage recovery remain explicit decision items, not silently selected designs.  
**Owner direction:** Keep raw inventory for LP ownership calculations; use rated reserves to price swaps, including actual swap legs inside zaps.  
**Implementation plan:** [UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_REMEDIATION_PRD.plan.md](UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_REMEDIATION_PRD.plan.md)

## 1. Authorization and precedence

This document specifies remediation; writing or reading it does not execute implementation. Give the linked plan to an implementation agent in a separate task. No deployment, migration, instruction/configuration edits, deletion, new storage, new external selector, or changes to another hook family are implied.

The owner's raw-ownership rule and the Orbital PRD's 2026-09-22 addendum control this scope. This PRD supplies precise rounding, conversion and acceptance requirements where older Orbital prose uses effective balances for proportional issuance. It does not globally replace the existing family PRD or invent a new partial-book invariant.

Read alongside:

- `CLAUDE.md` and `docs/agent/INDEXEDEX_AGENT_LAW.md` (APEX held-reserve valuation).
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828–835` and its co-located implementation plan. The old plan's v0.5 and "zap-in only" descriptions are not proof of current behavior.
- `docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md` and APEX remediation D59/D60/D63. D-number scope matters: Orbital-local D60 is a different decision.
- [Council consolidation](../research/orbital-liquidity-rate-policy-2026-10-04/CONSOLIDATION.md) and [remediation review](../research/orbital-liquidity-rate-policy-2026-10-04/remediation/CONSOLIDATION.md).

## 2. Problem and evidence

Under `contracts/hooks/uniswap/v4/standardExchange/orbital/`, the following source pointers were read on 2026-10-04. Basenames below omit the common `UniswapV4StandardExchangeOrbitalBufferHook` prefix; line numbers are navigation aids, not revision identities.

| Finding | Evidence | Interpretation |
|---|---|---|
| Full-book joins ratio rated contributions against rated holdings | `Common.sol:1066–1112` | Exact-arithmetic cancellation is not a proof of integer equivalence. Use raw inventory directly. |
| Zap planner combines rated swaps and terminal proportional mint | `ExitQuoteLib.sol:272–295,297–344` | Preserve the swap coordinate system; separate the final ownership calculation. |
| Zero-result conversions can substitute face amounts | `ExitQuoteLib.sol:376–381`; `ClaimLib.sol:300–311` | No face-value fallback may supply missing shares to the new ownership calculation. |
| Partial joins compare face offers with effective reserves | `Common.sol:1093–1183,1633–1656` | Unit-accounting concern. Final sphere-NAV pricing cannot be repaired by replacing rated reserves with raw shares while keeping rated radius. |
| Proportional payout arithmetic is raw | `Common.sol:1287–1356` | Preserve entitlements and real SE redemptions. |
| Entire withdrawal is nevertheless rate-dependent | `Common.sol:1359–1366` invokes `:459–479` | L2/reserve updates can revert the whole exit on provider failure, even with growth fees off. |
| Partial issuance uses rated sphere spot weights | `Math.sol:380–391` | Composition-changing partial pricing needs a separate explicit rule. |

**Not established by these observations:** an economically reachable exploit, a universal rounding bound, that a historical baseline fits gas, or that all hook families use FullSpread fixtures. Separately floored rated ratios can differ in either direction. A small illustrative vector (held=3, contributed=2, rate=1.5, supply=12) gives raw issuance 8 versus separately floored rated issuance 9; this is a unit arithmetic example, not a production exploit claim.

## 3. Scope

### Implementable now

1. Subsequent full-book proportional joins, including flexible pair/share-input variants, use raw inventory ownership math.
2. Orbital zap terminal proportional admission uses raw post-swap inventory and raw contributions. Internal swap sizing/pricing remains rated.
3. Required inventory collection rounds to sufficient backing; buffered face input is derived through actual SE conversion quotes and verified against execution.
4. Zero-share conversion results never become face-value ownership credit.
5. Existing proportional payout, bootstrap, rated fee accounting and fail-closed bookkeeping semantics are preserved and characterized by tests.
6. Partial-book call paths are inventoried and unit mismatches documented with independent references. No unapproved partial-pricing formula is installed.

### Not included

- New raw in-kind recovery route, stale/scaled reserve fallback, skipped growth fees, ignored radius checks, assumed rate=1, or changed provider-failure behavior.
- Orbital sphere/zap algorithm redesign, rate-source redesign, fee policy changes, bootstrap/radius redesign, or Weighted policy changes.
- Fixes to Hookless analytic math, Pons, other hook families, or unrelated dirty-worktree changes.
- New ABI/storage/package wiring, live deployment or immutable-instance migration.

Removing the earlier Hookless Gate M sequencing restriction does not remove these accounting and validation requirements. This document does not recreate that gate.

## 4. Accounting domains

Keep the following concepts distinct in code and tests:

| Domain | Units / source | Permitted use |
|---|---|---|
| Raw inventory | Booked raw face tokens for an unbuffered leg; live/projected SE share count for a buffered leg | Proportional LP ownership |
| Contribution | This operation's credited raw tokens or actual/projected newly received SE shares | Join numerator; exclude pre-existing holdings, donation credit and refunds belonging elsewhere |
| SE conversion | Exact/fee-inclusive shares minted for face input, or assets redeemed for shares | Real buffering/unwrapping and corresponding previews |
| Rated reserve | Held shares converted using the configured provider and correct decimals | Swap invariant and currently specified rated bookkeeping |

For direct share input, count the actual received shares; do not unwrap/redeposit solely to obtain an ownership ratio. Preserve conversions that a route actually requires. Decimal metadata determines units but must not introduce avoidable WAD truncation before a same-leg ratio. Do not change the product's token-policy restrictions.

## 5. Normative requirements

### R1 — Raw full-book ownership

For each leg `i`, let `B_i > 0` be incumbent raw inventory, `C_i` available caller contribution in the same units, and `S > 0` LP supply after any preserved pre-operation protocol-fee mint.

`m = min_i floor(S * C_i / B_i)`

Use overflow-safe full-precision arithmetic. The arithmetic helper must not read a rate provider or value the incumbent holdings by redeeming the full balance. No division across mismatched token/share units. First mint and zero-balance books are outside this formula and must not be forced through it.

### R2 — Backing and rounding

To issue a selected `m`, each leg must deliver at least:

`required_i = ceil(m * B_i / S)`

Acceptance invariant: `delivered_i * S >= m * B_i`, evaluated without overflowing intermediate products. Mint ratios floor; required contributions ceil; exit entitlements floor. Example: `S=10, B=3, C=1` supports `m=3`, but `floor(m*B/S)=0` does not back those shares. Rounding a pull down is not automatically LP-conservative.

Respect every user's maximum and refund policy. For a buffered leg, find a supported face input whose forward buffering result covers `required_i`. Do not reinterpret required shares as face tokens. A quote/execution discrepancy must not leave unsupported minted LP; validate realized inventory and revert atomically if insufficient. Excess belongs to the existing route's explicit refund/retention policy; never fund refunds from incumbent inventory.

Prefer existing supported conversion machinery. If inversion requires search, justify monotonicity on its domain, ensure decreasing intervals and overflow-safe bound expansion, retain existing supported error behavior and measure total quote work. The eight interpolation probes and 64 expansion attempts seen in existing helpers are not total nested-call ceilings. No unbounded search, fake linear inverse, or assumed exact-output capability.

### R3 — Sequential zap planning

Preserve rated `_depositSales`, `_depositOutputs`, sphere swap pricing and their state ordering. For terminal admission, obtain raw incumbent inventory and contributed shares from the exact projected post-swap state. A live balance read must not overwrite a projected snapshot. Preview and execute must agree from identical starting state and funding mode.

At fixed post-swap inventory, contributions and post-fee supply, terminal LP math is rate-independent. **An entire zap is not required to return the same result after rates change:** the swaps legitimately change the resulting basket. Likewise, preserved rate-dependent protocol-fee dilution can change `S`; do not mistake that for the ratio reading rates.

Change the ownership-specific conversion helper/call sites without changing a shared rated helper's contract for swaps. Remove zero-result face substitution only from ownership credit paths; a zero conversion must yield no positive mint, with established preview/revert conventions.

### R4 — Payout and bookkeeping preservation

Retain `floor(burnedLP * rawInventory_i / supply)` entitlements and required actual SE unwraps. Pure payout reference tests must match those entitlements exactly.

Preserve current Orbital fee mint/snapshot timing, first-mint scale, radius constraints, L2 and reserve-view synchronization. Provider failures remain atomic failures where those operations require rates. No caching, no-op update, scaled old reserve, omitted fee mint or bypassed radius validation is approved.

Tests must follow complete entrypoints with fees on and off, not merely `_proRataOut`. A passing raw arithmetic test is not evidence that the whole exit survives provider failure. Any future raw in-kind recovery design is OD-2.

### R5 — Partial-book boundary (OD-1)

Map all partial/unbalanced entry, flexible and quote twins, including `_partialSharesUsed`, `_partialUsed`, `_partialMinShares`, `_partialNavShares`, `_singleSidedPlan` and `_partialDepositAtState`.

The current sphere-NAV formula changes pool composition and depends on rated radius `R`. The owner's raw rule is binding, but does not by itself choose a replacement partial-book pricing formula. Do not feed raw shares into the old rated-radius formula; do not silently remove a supported partial route or relabel its result proportional.

Implement R1–R4 independently. Preserve partial economic behavior unless a change is provably mechanical and cannot alter pricing/route semantics; document any shared-helper reach into partial paths. Deliver a decision note containing the exact unit mismatch, affected states, conversion effects and candidate raw-accounting designs. Do not claim full partial-book remediation until OD-1 is resolved and its requirements/test oracle are written.

### R6 — Family and runtime boundaries

Preserve Weighted's explicit native-inventory first mint and `kLast`; do not transplant Orbital fee/bootstrap behavior. No reliance on historical Weighted wrapper results as FullSpread coverage.

Keep current compiler/configuration (observed configuration: solc 0.8.35, optimizer runs 1, no via-IR), external interfaces, selectors and storage layout. Every changed deployed library/facet/delegate/package must fit 24,576 runtime bytes. Keep actual consumer caps (including 31M call stipends and any existing 32M acceptance ceiling) unchanged. The larger Foundry harness gas limit is not a transaction-budget substitute.

## 6. Acceptance matrix

| ID | Evidence required |
|---|---|
| A1 | Exact independent raw-ratio mint reference across 0–3 buffered legs, nonidentity rates and mixed face/share decimals |
| A2 | Per-leg ceil-backing inequalities on actual settlement; tiny/large values; overflow rejection; no asserted generic one-wei tolerance |
| A3 | Pair/share flexible inputs, non-1:1 and fee-bearing conversions, zero mint, caller-credit isolation and refund conservation |
| A4 | Full-book pure ownership result invariant under rate-only changes with inventory/conversion outputs/post-fee supply fixed |
| A5 | Zap terminal mint matches raw reference on projected post-swap state; complete same-state preview/execute equality; swaps remain rated |
| A6 | Matched-state raw proportional payouts, rated swap quotes, fee/bootstrap bookkeeping and supported errors preserved except documented intended join-rounding fixes |
| A7 | Provider revert/zero/short-return tests through whole exits and joins, fees on/off, rollback of transfers/supply/bookkeeping; no invented outage success |
| A8 | Partial-route inventory/decision note complete; unresolved cases explicitly not reported fixed |
| A9 | Production-first proxy tests, required existing family/consumer suites and full final tallies; no inference of success from a truncated run |
| A10 | Matched before/after gas and quote counts; no new capped consumer failure, changed runtimes fit, ABI/storage/config unchanged |

Rate fixtures may vary a non-SUT provider using existing approved testing infrastructure. Do not mock the hook, vault, manager, registry, fee oracle or PoolManager under test. Verify actual fixture types; use actual FullSpread fixtures where that compatibility is claimed.

## 7. Decision items and completion labels

**OD-1 — Partial/unbalanced pricing:** owner must approve a specified raw-inventory rule before changing the composition-changing sphere-NAV path. A unit-consistent rated-NAV exception is not the default: it would require an explicit exception to the retained raw rule. No recommendation here authorizes that exception.

**OD-2 — Rate-failure recovery:** decide whether users need raw in-kind exit availability despite provider failure, and define pending fees, reserve discovery, sphere/radius state, synchronization on recovery, underlying SE unavailability and any ABI/storage changes. Default remains fail-closed.

Neither item stops independent R1–R4 work. Report separately: `bounded remediation complete`, `bounded remediation incomplete`, `OD-1 unresolved`, and `OD-2 deferred`. "Bounded complete" must never be presented as all Orbital liquidity issues fixed or full release acceptance when required consumer failures remain.

## 8. Evidence and limitations

The council completed four original proposals plus four cross-reviews in retained sessions. The final requirements reject unsupported stale-state/fee-skip proposals and floored underfunded pulls; the accompanying consolidation attributes dissent. Prior-round incidental peer-snippet exposure remains disclosed. No tests, measurements or exploit proofs were produced in this authoring round.

Baseline attribution must come from reproducible source/artifact identities and runs, not whether a test file was edited. Untouched tests can fail because dependencies changed. LSP messages alone do not establish stale or pre-existing compiler failures. Passing tests and council agreement are not proofs of security.
