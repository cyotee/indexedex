# MiniMax M3 — `UniswapV4UpperLowerWingsStandardExchangeVault` cross-review

- **Inputs read in full:** `astra-original.md`, `grok-original.md`, `kimi-original.md` (untrusted attributed proposals, not authority). Original at `minimax-original.md` preserved. **No** peer cross-reviews read.
- **Direct primary evidence located:** `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md:64–74` records the historical three-position geometry: `centerWidthMultiplier = 2` (±1 tickSpacing center), `widthMultiplier`-driven wing envelope, **`activeLiquidityBps = 1000` (10% center / 90% per-side wings)**, ticks frozen at first create, rebalance moves free↔deployed only. This is the historical restoration source, not commit `35f47b51` (which I did not read).
- **Method:** peer proposals treated as proposals; primary code/PRD re-checked. Cross-checks against code: `H/PositionRepo:9–22` stores **one** center; `H/Common:659–666` creates no wings; `H/LiquidReserveTarget:59–60,87–89` is full-range; `H/Common:300–301,354–357` already-unlocked ⇒ `UniswapV4Exchange_PoolManagerInteractionBlocked` (full reentrancy lock, `pm.unlock` reverts `AlreadyUnlocked`). All confirm FullSpread is currently center-only.
- **Scope honesty:** **No** full security proof, **no** measured chain gas, **no** claim that 35f47b51 / 1.28M are wings evidence. Restoration is from the primary PRD text only.

## 1. Direct corrections to my original

| # | Original (minimax-original.md) | Correction | Evidence |
|---|---|---|---|
| 1 | UD-1: "Upper wing token1-only while `currentTick ≤ tickLower_w`" (line 27 of §0) | **Inverted.** Historical PRD text at `FULL_RANGE_DEPLOYED_BOOK_PRD.md:74` says *"90% of deployable token1 in the lower wing, 90% of deployable token0 in the upper wing"*. The PRD-text-binding mapping is: **lower wing ⇒ token1; upper wing ⇒ token0**. My orientation was wrong. | PRD:74 |
| 2 | OD-1 recommended v1 disallow single-token entries | Owner direction: **"useful single-token composability, not banning scalar entry."** Correction: propose a single-token composition rule against the three-position book (see §3 proposal), not a ban. | Owner clarification, this round |
| 3 | OD-2 wing gap/width left numeric | Primary PRD supplies a 10/90 `activeLiquidityBps = 1000` rule. Propose this as the default for **restoration**. Owner may change it. | PRD:74 |
| 4 | OD-4 sleeve = `F_0+F_1`, no inner position | Local liquid buffer PRD type default is `liquidReservePercentageOfVault = 20%`. Propose 20% sleeve target with **wing-aware** sizing because wings concentrate one-sided capital and a flat 20% can leave one side thin. | Local buffer PRD; D29 sleeve precedent |
| 5 | OD-3 sleeve base = sum of `D` | Propose **sum of owned D across all three positions** as base; flat 20% may not be safe under 10/90 split. | D29; PRD:74 (8% effective center / 90% per wing) |
| 6 | Forbidden: NAV admission, oracle admission | Owner direction requires **useful single-token composability**. Propose bounded single-token composition against the post-swap incumbent whole book with a TWAP guard (do not claim NAV safety), per option B of Grok OD-3. | Owner direction; Grok OD-3 B |
| 7 | No mention of EIP-7825 | **Add.** EIP-7825 caps transaction gas at **16,777,216** on networks that activate it. 31M/32M (cited in `orbital/…Common.sol:1929–1931`) is a **historical** chain cap; not all chains adopt it. | EIP-7825 |
| 8 | "Chain gas limit 31M/32M" | Replace with **per-chain verification** (Ethereum: 30M, Base: same; RH 4663: per chain policy; EIP-7825 active networks: 16,777,216 per tx). | EIP-7825; `orbital/…Common.sol:1929–1931` is a code comment, not a measurement |
| 9 | Forbidden: arbitrary SUT mocks | **Add explicit clause** that no `MockStandardExchange`, no mocked rate provider, no mocked hook, no mocked PoolManager — production-first per `CLAUDE.md:2,30,387`; the consuming-hook test harness is allowed **only** when it binds a real production vault (FullSpread, this new vault) and the SUT is a real registered diamond. | CLAUDE.md:2,30 |
| 10 | No mention of Weighted `2≤n≤8` shape | Add the **permutation constraint** (Kimi OD-9 / §7): `b=1..8` buffered + `r=0..8-b` raw, `2≤b+r≤8`. Eight buffered is invalid. | `weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:373–400` |

## 2. Agreements with peers

- **Identity / path / kind** (Astra, Grok, Kimi, me): `UniswapV4UpperLowerWingsStandardExchangeVault` under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`; vault diamond via IndexedEx manager vault registry; not a V4 hook diamond; FullSpread untouched.
- **No restoration of commit `35f47b51`; no ~1.28M gas claim; `92cdf89a^` is center-only.** All four agree; primary PRD is the source.
- **Custody vs economic backing separation.** `B_i = F_i + D_i + E_i` with `D_i = D_i^L + D_i^C + D_i^U` (lower/center/upper). FoT/rebasing forbidden. Caller credit excluded from `B`.
- **No nested unlock.** `pm.unlock` reverts `AlreadyUnlocked`; sleeve is the only settlement path in blocked state. **No new inner V4 position** unless owner rules.
- **Immutability post-deploy.** No human `diamondCut`. Permissionless consolidation only.
- **One center (full-range) + ≤1 upper + ≤1 lower = 3 positions max.**
- **First mint dual-only, decimal-scaled dead-sink minimum** (current activation rule, FullSpread README; type default per `StandardExchangeConstantProduct.sol:16–34`).
- **No `new` SUT, no `MockStandardExchange`, no `via_ir`.** No scaled stale reserve, no fee waiver, no NAV.
- **Per-position fee collection, no double-count**; `E→F` once.
- **DETF composition via existing I/O routing law** (`DETF_INSTANCE_IO_ROUTING_PRD.md §16`); wings vault is composable wherever a FullSpread SE is, **if** it implements the same `IStandardExchangeIn/Out` + `IStandardExchangeTransitionQuote` + native SY surface.

## 3. Proposed (not owner-approved) parameters

These are **explicitly proposed** for owner selection; not consensus defaults. Each carries a "owner may override" clause.

### 3.1 Geometry (proposal — restoration from `FULL_RANGE_DEPLOYED_BOOK_PRD.md:64–74`)

| # | Parameter | Proposed value | Owner-may-override? |
|---|---|---|---|
| G1 | Center range | Full-range: `[TickMath.MIN_TICK aligned to tickSpacing, TickMath.MAX_TICK aligned to tickSpacing)` | Yes, but only via new PkgArgs; the historical "tight center ±1 spacing" is **not** adopted (it requires the tight-band optimizer that the v1.2 release removed; D28 forbids rebalance swaps; restoration here is "three positions" not "tight center + wings") |
| G2 | Lower wing tickLower | `MIN_TICK` aligned to `tickSpacing` | Yes |
| G3 | Lower wing tickUpper | `center.tickLower` | Yes |
| G4 | Upper wing tickLower | `center.tickUpper` | Yes |
| G5 | Upper wing tickUpper | `MAX_TICK` aligned to `tickSpacing` | Yes |
| G6 | Salt | `keccak256(abi.encode(PRODUCT_ID, "lower"))` and `keccak256(abi.encode(PRODUCT_ID, "upper"))`; deterministic per instance; no caller bytes | Yes |
| G7 | Tick freezing | **Frozen at first create** for the center. Wings are mutable only by permissionless consolidation that fully removes the wing then re-creates it at a new (still legal) range, **at the same center bounds**. No arbitrary recast. | Yes |
| G8 | Orientation (per §1 correction #1) | **Lower wing = token1-only; upper wing = token0-only** (matches PRD:74). Tick G2/G3 lower wing's range is *above* current price at activation; G4/G5 upper wing's range is *below* current price at activation. | Yes (orientation is part of geometry) |
| G9 | `activeLiquidityBps` | **1000** (10% of deployable to center; 90% per wing) — restoration. | Yes |

### 3.2 Sleeve (proposal)

| # | Parameter | Proposed value |
|---|---|---|
| S1 | Sleeve target | `liquidReservePercentageOfVault` (existing oracle field) type default **20%** of `D_total = D_lower + D_center + D_upper` per token. Per-token sleeve target uses **per-token** `D_i` (not `D_total` averaged). |
| S2 | Sleeve base | `D_i` summed across **all three positions** for that token. A flat 20% of a 90/0/10 split token may leave the other side thin; per-token target is a per-position sum. |
| S3 | Sleeve replenishment | Existing rebalance discipline (no D28 swap; sleeve top-up via incremental `modifyLiquidity` on center; wings untouched unless fully consolidated). |
| S4 | Already-unlocked | Sleeve only; no `pm.unlock`; revert `UniswapV4Exchange_PoolManagerInteractionBlocked` for unlock-requiring routes; no in-kind recovery. |

### 3.3 Pricing, issuance, redemption (proposal — owner may override)

| # | Parameter | Proposed value |
|---|---|---|
| P1 | First mint | Dual-only; `mean = floor((d0+d1)/2)`; `MIN = mean<3 ? 1 : 10^(mean-3)`; caller shares = `floor(sqrt(c0*c1)) - MIN`; MIN to `address(0xdEaD)`; residual sink shares to dead sink. Malformed metadata → revert. |
| P2 | Idle proportional join | `m = min_i floor(S * C_i / B_i)` over the **complete three-position book**. 1 bp alignment `10000*m*B_i >= 9999*S*C_i`. Caller credit counted. Incumbent own-LP fees and swap-earned fees stay with incumbents. |
| P3 | Single-token zap (idle) | **Allowed.** Caller-funded composition + placement + proportional issuance against **post-swap incumbent whole book**. **TWAP guard:** reject if `|sqrtPrice_current - sqrtPrice_TWAP(window)| / sqrtPrice_TWAP(window) > 25 bp`. Same-domain reentry forbidden. Out-of-range own-wing crossing reverts if it would leave the other side empty after exit. |
| P4 | Idle proportional exit | `floor(shares * inventory_i / S)` per concrete inventory component; opposing entitlement swapped forward (bounded forward work; no probe loop). |
| P5 | Blocked deposits | Credit sleeve; mint on totals; no nested unlock. |
| P6 | Blocked withdrawals | Pay only from sleeve cover; else revert. |
| P7 | Exact-output | R2/R6/R8 of FullSpread plan preserved; no new supported exact-output domain. |
| P8 | No NAV; no oracle-NAS admission; no idle internal-CP admission. |

### 3.4 Management (proposal)

| # | Parameter | Proposed value |
|---|---|---|
| M1 | Consolidation | Permissionless, **1 wing per call**, deterministic salt order. |
| M2 | Immutability | No human `diamondCut`; wings immutable except via M1. |
| M3 | No caller reward. |
| M4 | No new fee, no fee waiver. |

### 3.5 Surface (proposal)

| # | Selector | Required? |
|---|---|---|
| F1 | `IStandardExchangeIn` | Yes |
| F2 | `IStandardExchangeOut` | Yes |
| F3 | `IStandardExchangeInMulti` | Yes (for unbalanced join) |
| F4 | `IStandardExchangeOutMulti` | Yes (proportional-only; unbalanced reverts) |
| F5 | `IStandardExchangeTransitionQuote` | Yes (DETF composition + hook simulation) |
| F6 | `IStandardizedYield` native SY | Yes (per FullSpread README) |
| F7 | New: `placeWing(side, saltIndex)` / `consolidateWing(side)` / `wings()` / `wing(side)` / `wingLiquidity(side)` | Yes (WingsFacet) |

### 3.6 Imports (proposal)

- Default v1: **no import surface.** Optional `importPosition` may be added later; the historical precedent (FullSpread import keeps the empty NFT in custody, credits only the assets delivered from the NFT) is not automatically copied.

## 4. Restoration vs new design (explicit ledger)

| Element | Restoration? | New? | Source |
|---|---|---|---|
| Center full-range | **Restored** (PRD v1.2 chose full-range; PRD:73 historical ±1 spacing is *not* restored) | New restoration policy: full-range + two wings | `FULL_RANGE_DEPLOYED_BOOK_PRD.md:99` |
| 10/90 wings `activeLiquidityBps = 1000` | **Restored** | — | PRD:74 |
| Lower wing = token1; upper wing = token0 | **Restored** | — | PRD:74 |
| Ticks frozen at first create | **Restored** | — | PRD:73 |
| Sleeve 20% per token | Restored (type default `liquidReservePercentageOfVault`) | New: per-token `D_i` base | Local buffer PRD D29 |
| Single-token composition | **New** (historical 10/90 wings were an inventory layout, not a single-token admission rule) | New rule with TWAP guard | Owner direction this round |
| WingsFacet / new selectors | **New** | New surface | Owner direction |
| FullSpread route matrix R1–R11 | Restored (preserved by mandate) | — | FullSpread plan |

## 5. Token orientation correction (the inversion)

My original §0 said "Upper wing = token1-only while `currentTick ≤ tickLower_w`" and "Lower wing = token0-only while `tickUpper_w ≤ currentTick`." This is the **opposite** of the historical PRD text (PRD:74: 90% of token1 in lower wing, 90% of token0 in upper wing).

**Adopted correction (per §3.1 G8):** lower wing ⇒ token1; upper wing ⇒ token0. The activation-time tick relationship (G2/G3/G4/G5) follows from the source-of-truth text. This is a textual correction, not a redesign.

## 6. Gas and chain limits (corrected)

- **Foundry ceiling** `foundry.toml:38` `gas_limit = 30_000_000_000` — a Foundry parameter, not a chain policy.
- **Chain policies (named, not measured here):** Ethereum mainnet 30M block gas; Base 60M; RH 4663 per its policy. **EIP-7825 transaction-gas cap 16,777,216** applies on networks that activate it (currently flagged; not universal). Do not assume 30M for whole-tx acceptance.
- **Required measurements** (per-peer consensus, not adopted by this PRD): top-level transaction gas on the deployed bytecode for: dual first mint that places all three positions; one proportional join; one proportional exit; one blocked sleeve exit; one public consolidation. Cold and warm. **No numeric pass line until that limit and a measured baseline exist.**
- **Harness gas** (`vm.startSnapshotGas/stopSnapshotGas`) reported separately from whole-tx gas. The cited ~1.28M figure is whole-test harness gas, **not** a wings measurement, **not** adopted.

## 7. Adversarial + consumer matrix (corrected)

### 7.1 Adversarial (Astra §7 + Kimi §8 + Grok §9, all agreed)

Donation (free balances count, not deployed); price-walk-into-wing; wing-edge JIT/tick-crossing; first-mint inflation (decimal-scaled sink); fee double-count across three positions; `AlreadyUnlocked` griefing; reentrancy through PM callback + ERC-20 hooks; tick-spacing alignment edges; import (if any) blocked per D15; sleeve drain (blocked exits capped at free); disabled-vault exit preservation; same-tx manipulation under whichever OD-3 rule is chosen.

### 7.2 Consumer (named, no claim)

- FullSpread family regression — hookless + PonsFamily unchanged.
- DETF binding — Orbit-grade + Pons-grade + V4-only, with native SY.
- **Weighted consumer matrix:** `n ∈ [2,8]`, `b = 1..8` buffered, `r = 0..8-b` raw, `2 ≤ b+r ≤ 8`. **Eight buffered is invalid** (a mandatory raw DETF self-leg limits buffered legs to 7 at n=8). Cover permutations per n, both directions, same/different managers, repeated SE dependencies, duplicate-binding rejects.
- Orbital (3 legs) with wings SE on 1..3 legs.
- Single-CP / dual-CP hooks.
- Pons V2 graduated pool fixture (R20 of DETF I/O routing PRD).
- `V4FundedBindings`-style consumer suites (distinguish wrapper fixtures from actual-position fixtures).
- Nested-lock matrix: wings vault as SE of a hook during outer `unlock` — deposits via sleeve, wing liquidity untouched, cover/short amount-out.

### 7.3 Forbidden

No `MockStandardExchange`, no mocked rate provider, no mocked hook, no mocked PoolManager. Production-first per CLAUDE.md. The consuming-hook test harness is permitted **only** when it binds a real production vault and the SUT is a real registered diamond.

## 8. Honest scope (no over-claim)

- **No** full security proof. Restoration is from primary PRD text, not from a re-executed historical build.
- **No** measured chain gas. Foundry harness gas and chain gas are separated and named, not asserted.
- **No** restoration of commit `35f47b51`. The historical PRD is the only source cited.
- **No** claim that any peer proposal is safe by consensus. All proposals require owner ruling.
- **No** changes to FullSpread, PonsFamily, Weighted, Orbital, raw monomorph, hook factory, or `foundry.toml`.
- **No** claim that wings behavior is end-to-end safe. The PRD specifies **what to measure**, not **that it has been measured**.

## 9. Final corrections list (machine-readable summary)

1. UD-1 / §0 orientation: **lower wing ⇒ token1; upper wing ⇒ token0** (PRD:74 binding).
2. G1–G9 propose explicit geometry; G9 = 1000 bps = 10/90.
3. P3 single-token composition: **proposed allowed** with TWAP guard ≤ 25 bp; no NAV, no oracle-NAS, no internal-CP admission.
4. S1–S4 propose 20% per-token sleeve; base = sum of `D_i` across all three positions for that token.
5. EIP-7825: 16,777,216 per-tx cap named; not all chains; not adopted as a universal rule.
6. No `MockStandardExchange`, no `new` SUT, no `via_ir`, no `diamondCut`, no scaled stale reserve, no fee waiver, no in-kind recovery.
7. WingsFacet is **new surface**, not restored.
8. Sleeve replenishment follows existing D28/D29 (no rebalance swap).
9. Restoration vs new ledger per §4.
10. Honest scope per §8; this PRD **does not** claim security or chain-gas evidence.

---

*Saved to `docs/research/uniswap-v4-upper-lower-wings-prd-2026-10-05/minimax-cross-review.md`. Original preserved. No code/tests/shell/config/deploy/instruction edits performed. Cross-reviews of other peers not read. The owner-decision register and the explicit geometry/pricing/sleeve proposals are blocking inputs for the next stage.*