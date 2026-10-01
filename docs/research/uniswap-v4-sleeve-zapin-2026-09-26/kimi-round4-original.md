# Kimi K3 — Round 4 independent original: repair-swap protection, hook admissibility, settled pretransfer, alignment tolerance

**Date:** 2026-09-26. Research only; no code/shell/tests/delegation. No round-4 peer files or cross-review artifacts read. Read directly: `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` (full; §1.1 L-RSRV-*, §4.2–4.9), `contracts/vaults/basic/BasicVaultRepo.sol:20-110`, `UniswapV4StandardExchangeCommon.sol:605-648, 669-670, 996-1118, 1260-1297`, `InBase.sol:273-315`, `InTarget.sol:37-78`, and the latest moderator PRD. External evidence (details §3): Context7 `/websites/developers_uniswap` (2026-09-26) plus primary fetches of Universal Router `Dispatcher.sol` and `V3ToV4Migrator.sol` (2026-09-26). All numbers below are **reasoned defaults, not empirical truth**.

## 1. Permissionless inventory-repair swaps (owner overrides swap-free public rebalance)

### 1.1 Structural contrast with deposit-route swaps (PZ-2)
| Axis | Deposit composition swap (accepted) | Permissionless repair swap (new ask) |
|---|---|---|
| Input | caller's basket only | **incumbent inventory** (backlog/donations/skewed sleeve) |
| Cost bearer | the depositor (smaller basket → fewer shares) | **all holders pro-rata** (socialized) |
| Caller | self-interested depositor | anyone, incl. MEV bots |
| Bound anchor | user `minSharesOut` + protocol impact cap | **no user present** — protocol bounds are the *only* protection |
| Termination | one call, done | none inherent — needs explicit completion criterion |

Because no user limit exists on the repair path, protection must be entirely protocol-side, and socialized loss must be capped per call *and* cumulatively.

### 1.2 Threat mechanics (inference, no claimed exploit)
1. **Per-call cap bypass by repetition:** any per-call impact cap is defeated by N same-block calls; each call is sandwiched or walks the price, and the vault's own full-range L is the counterparty, so repeated calls leak fee-on-impact each time.
2. **Finite progress:** each swap shrinks the skew gap geometrically (swap ≤ fixed fraction of remaining gap ⇒ gap_n = gap_0·(1−f)^n). Converges but never finishes — so the policy deadband (D22) must remain the *termination* criterion; when both tokens are within deadband, repair is a no-op success.
3. **Anchor drift:** any independent-reference gate needs freshness bounds; a stale anchor under fast price movement mis-prices "fair."

### 1.3 Proposed protection stack (numbers = reasoned defaults; distinguish the quantities)
| Quantity | Definition | Proposed default |
|---|---|---|
| **Execution slippage** | actual fill vs quoter output at call-start state | ≥ `max(2 × pool LP fee tier, 10 bps)` headroom; revert otherwise (a bound tighter than the fee tier makes every call revert) |
| **Terminal spot impact** | |slot0 price move caused by this call| | ≤ **25 bps per call** |
| **Per-call notional** | swap input size | ≤ **min(10% of abundant-token free balance, 25% of remaining skew gap, impact-capped max)** |
| **Per-block cumulative** | total swapped per block per vault | ≤ **3× per-call cap** (blunts same-block repetition without a per-tx oracle read) |
| **Anchored campaign budget** | cumulative swapped value vs independent reference while book remains off-deadband | ≤ **25% of the backlog value measured at campaign start**; reference freshness ≤ 1 hour, fail-closed when stale/unavailable |
| **Anchor deviation** (if reference adopted) | execution price vs reference | ≤ **100 bps** |
| **Alignment loss** (deposit route, §4) | relative divergence of implied per-leg share counts | ≤ **1 bp** + per-token absolute floor; else revert |
| **Sleeve deadband** | unchanged D22 | `max(floor_i, 5%·F*_i)`; also the repair termination rule |

**Fee/impact allocation:** repair-swap LP fees partially self-recycle into the vault's own position (incumbent income); residual fee + impact is a socialized cost of inventory repair — must be disclosed as "policy spends book value to restore deployability." Deposit-route costs remain caller-borne (PZ-6). Never blend the two budgets: repair swaps must not consume the caller-basket measurement window of a concurrent deposit (same-tx ordering: repair is a separate public entrypoint; it must not run inside zap-in).

### 1.4 Minimal remaining owner decisions (this item)
- **O-R1 — configuration authority/source:** recommend package-level immutable default constants (above), *no* new fee-oracle fields (D5 spirit); vault-level override only via a future governed parameter if demanded. Owner confirms constants vs oracle.
- **O-R2 — risk model:** recommend per-call + per-block caps **and** the anchored campaign budget (defense in depth); owner may accept per-call + deadband-only as a cheaper v1 with documented repetition risk.
- **O-R3 — admission:** permissionless at all times (recommended; matches existing permissionless `rebalanceLiquidReserve`, `LiquidReserveTarget.sol:90-95`) vs keeper-gated.

## 2. Hook compatibility — what is actually provable on-chain (owner criterion: "executable via Universal Router")

### 2.1 Primary-source findings (accessed 2026-09-26)
- **Universal Router cannot add/remove liquidity on an existing V4 position.** `Dispatcher.sol` routes `V4_POSITION_MANAGER_CALL` (0x14) through `_checkV4PositionManagerCall` with the comment "should only call modifyLiquidities() to mint"; `V3ToV4Migrator.sol` implements it: any `INCREASE_LIQUIDITY`, `INCREASE_LIQUIDITY_FROM_DELTAS`, `DECREASE_LIQUIDITY` or `BURN_POSITION` action **reverts `OnlyMintAllowed()`** ("of the position-altering Actions, we only allow Actions.MINT … an attacker could take their fees, or drain their entire position"). Only mint + settle/take/sweep/wrap flows pass.
- **PositionManager itself fully supports add/remove** (`PositionManager._handleAction`: INCREASE/DECREASE/BURN with `onlyIfApproved`) — but *directly*, not through the router. (Source content obtained via search-result highlights of `src/PositionManager.sol` at Uniswap/v4-periphery, 2026-09-26; I did not open the raw file — recorded as a partial-verification gap, low risk given the Dispatcher/Migrator evidence.)
- **Our vault doesn't use either path for its managed book:** it calls `poolManager.modifyLiquidity` directly (`Common.sol:1033-1063`); PositionManager is used only for *imported* positions (`Common.sol:963-980`), also directly. So the UR criterion tests a path this vault never takes.
- **UR V4_SWAP** does nest safely (`Dispatcher.sol`: if `poolManager.isUnlocked()` it runs actions within the existing lock) — evidence that UR swap *execution* handles locked/unlocked contexts, but says nothing about hook behavior.
- **Hook flags are callback declarations, not behavior proofs:** v4 hook-address bits declare which callbacks the PoolManager will invoke. A pool whose hook has **no liquidity-callback flags** can still run `beforeSwap/afterSwap` during our composition/repair swap (with the vault or router as sender and attacker-influenced `hookData` semantics), can implement dynamic fees, and can revert conditionally. The no-liquidity-callback case is *limited* evidence only. Simulation proves behavior at one state, not future states.

### 2.2 Consequence for the owner criterion
"Provable on-chain via UR execution" is **not achievable as stated**: UR's mint-only restriction means add/remove compatibility can never be demonstrated through it, and flags/simulation do not prove arbitrary hook logic. Therefore the **owner fallback is the operative law**: the deployer is responsible; a supplied PoolKey is assumed compatible; **no discretionary on-chain hook whitelist** is introduced. What remains mandatory (and distinct from admission) is *execution integrity*: hook-agnostic settlement checks — post-call delta reconciliation (PM unlock already requires zero deltas, `Common.sol:676-680` + callback auth `:996-999`), caller basket measured from actual fills (PZ-6), minShares + impact cap, and **quote honesty labeling**: `_adjustHookSwap` returns unadjusted amounts for unrecognized hooks, so previews on such pools must be labeled non-projectable rather than silently vanilla. Recommend an informational flags-derived view (callback surface) for operators — informational only, not an admission gate.

## 3. Pretransfer — settled law applied; prior suggestions withdrawn

**Withdrawn explicitly:** my round-3 Q3 (measured-pull-only on the composed route) and all provenance/nonce framing from earlier rounds. Settled law (PRD §4.2/§4.6, L-RSRV-CALLER as amended by APEX D9): any eligible **contract** caller may claim `≤ U = B − R` (live held minus local snapshot); no origin provenance; atomic transfer+operation is integrator responsibility; EOAs revert.

**V4-SE-specific findings under that law (facts, from code):**
1. **Local snapshot vs economic totals collision (real, structural).** BasicVaultRepo documents `reserveOfToken` as *locally held* balances, "NOT the owned shares of deployed liquidity reserves" (`BasicVaultRepo.sol:25, 92-97`). The V4 SE instead writes **economic totals** — `_syncVaultReserves` stores `free + deployed` per token (`Common.sol:605-613`). The V4 override compensates: `faceBooked = R − deployed; U = B0 − faceBooked` (`Common.sol:1281-1284`). This is correct only if `deployed_now == deployed_at_sync`; between syncs, fee accrual and price drift change `deployed`, so `U` is mis-sized by the drift — in the inflation direction this *over*-credits pretransfer capacity. Under settled law the clean fix is to book **face balances** (`balanceOf`) at end-sync and drop the subtraction override; that is a code-law alignment task, not a provenance choice.
2. **Absent EOA guard = code-law gap.** Grep confirms `EOAPretransferNotAllowed`/code-length checks exist in `LocalCreditLib.sol` and DETF/SY surfaces but **nowhere in `contracts/protocols/dexes/uniswap/v4/**`** — the V4 SE's `pretransferred=true` is currently open to code-less callers, contrary to APEX D9. Record as a code-law gap to close in the implementation plan; not a new owner question.
3. **Ordering is compatible with the composed route:** credit is computed at pull time (`InTarget.sol:56/64`) *before* `_collectManagedFeesIfIdle` inside the delegate (`InBase.sol:281`) — fee collection (E→F) after credit cannot inflate the caller's measured input; end-of-op `_syncVaultReserves` (`InBase.sol:307`) satisfies L-RSRV-SYNC-WHEN in timing, subject to the totals-vs-face collision above. The composed swap's output lands on the diamond and is booked at end-sync; `U`-based double claims within the same call are impossible (single transaction).
4. Donation-as-pretransfer on the composed route is **accepted settled behavior** (L-RSRV-DUST / caller responsibility): an unbooked surplus can fund a claim and thus become swap input; integrators must be atomic. This is disclosed, not fixed.

## 4. Alignment tolerance (owner accepts best effort; number is a reasoned default)

- **Metric (unitless):** let `m0 = S·C0/B0`, `m1 = S·C1/B1` (the two min-ratio legs, post-swap B). Alignment error `e = |m0 − m1| / max(m0, m1)`.
- **Recommended default:** `e ≤ 1 bp (1e-4)` with a per-token absolute floor (`10^max(0,decimals−6)`) to keep tiny deposits feasible; exceeding it **reverts** — never mint the donated result. This is a proposed constant pending engineering's measured rounding/solver error across 6/9/18-decimal fixtures; it is not empirical truth and not prior law.
- **Independence:** this tolerance is enforced separately from `minSharesOut` (which bounds share count, not alignment); neither substitutes for the other.
- **Best-effort boundary:** *placement* residual (skew residue vs LP ratio) may be material and is retained/disclosed (PZ-7); *numerical* surplus beyond the tolerance is not a residual — it is a solver failure and reverts. Exact-in semantics: the full input is consumed; **no refund** of the composed basket's unmatched rounding within tolerance; zero-output (quote or mint `m == 0`) reverts `ZeroAmount` (existing error, `Common.sol:297`).

## 5. Minimal remaining owner decisions (whole round)
1. **O-R1/O-R2/O-R3** (§1.4): repair-swap config authority (recommend immutable package constants, no new oracle fields), risk model (recommend per-call + per-block + anchored budget), admission (recommend permissionless).
2. **O-A1:** approve the alignment tolerance *value* after engineering measurement (default proposed: 1 bp + floor).
3. **Hook admission fallback confirmed** (deployer responsibility, no whitelist) — plus one sub-choice: ship the informational hook-flags view? (recommend yes, additive).
4. **Code-law gaps acknowledged for the plan** (not product choices): V4 EOA pretransfer guard; face-balance vs totals reserve booking.

## 6. Corrections to my prior rounds
- Round-3 Q3 (restrict pretransferred on the composed route) and all provenance/nonce framing: **withdrawn** per settled law (moderator-confirmed).
- Round-3 Q2 remnants: subsumed by §1.3's protocol-side stack (repair path has no user bound at all — strengthens the case).

## 7. Confidence and gaps
High: UR mint-only restriction (primary source), V4 direct-PM path, pretransfer collision and missing guard (local code). Medium: numeric defaults (reasoned, unmeasured); PositionManager action set (search-highlight evidence, raw file not opened); dynamic-fee flag behavior (round-3 peer Context7 claim, not re-verified). Gaps: no tests; upstream port pin unverified; UR deployment-version equivalence to `main` unestablished. Nothing here authorizes implementation.
