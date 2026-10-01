# Kimi K3 — cross-review: Pendle claim-funding round

| Field | Value |
| --- | --- |
| Reviewer | Kimi K3 (`kimi-code-plan-global/k3`, variant high), retained session |
| Date | 2026-09-28 |
| Inputs (untrusted attributed model evidence) | `astra-original.md`, `grok-original.md`, `minimax-original.md` in this directory, read complete. No peer cross-reviews read. My original `kimi-original.md` preserved unchanged; corrections in §2. |
| Verification | Every disputed formula re-checked against `lib/crane/contracts/protocols/perps/pendle/` (`P/...`) including `P/core/libraries/math/PMath.sol:34–53`, `PendleYieldToken.sol`, `InterestManagerYT.sol`, `RewardManager(Abstract).sol`, `PendleGauge.sol`, `PendleMarketV3.sol`, `ActionMiscV3.sol`. |
| Constraints | No implementation/shell/tests/delegation. One review, then stop. |

## 1. Four-way agreements (re-verified against source)

1. **Entrypoints and beneficiaries:** `YT.redeemDueInterestAndRewards(user,bool,bool)` (`PendleYieldToken.sol:166–193`) and `market.redeemRewards(user)` (`PendleMarketV3.sol:237–239`) are permissionless for any `user`; proceeds go only to `user`; no partial-amount selector; router batch (`ActionMiscV3.sol:67–84`) hardcodes `(true,true)` per YT plus market loop and returns nothing. `SY.claimRewards` is an empty stub in the verified SY compilation.
2. **Claim inventory for this SY:** YT SY interest (held) is the only SY-denominated claim; market LP incentives are `[PENDLE]` (`PendleGauge.sol:102–106`); no same-token incentive case in these sources (conditional caveat in §3.4).
3. **Fee:** `fee = floor(gross × interestFeeRate / 1e18)` (`mulDown`), `net = gross − fee`, fee → YC-factory treasury, net → user (`InterestManagerYT.sol:43–60`). Fee applies once per claim to total accrued (Astra's fee-dust timing vector: two claims of 10 net 20 vs one combined claim of gross 20 netting 19 at 5% — force-claim timing changes fee dust).
4. **Index mechanics:** pre-expiry `max(SY.exchangeRate(), _pyIndexStored)` as uint128 with optional same-block cache; post-expiry frozen `firstPYIndex`; first-touch (`prevIndex==0`) initializes without retroactive accrual; YT transfers crystallize accrued interest to the transferor's `userInterest` slot before the balance moves (`PendleYieldToken.sol:499–503`).
5. **No NetNet epoch advancement:** no claim path calls NetNet `stake`/`unstake`/`rebase`; `SY.exchangeRate()` is a view projection. Claims can make interest claimable against a projected-but-uncommitted index (bounded one epoch ahead; nothing forfeited).
6. **Failure split:** upstream claim reverts are atomic with entitlements preserved (accrued reset rolled back) — required failures, never caught; only the hook's downstream forward-to-`feeTo()` is the selected best-effort exception; router `multicall` `allowFailure=true` is not a permitted workaround for required steps (Astra).
7. **H/C discipline:** trigger is `H < d`; claim collects all accrued; remainder `H + C − d ≥ 1` evaluated on measured post-claim state; `H = d, C ≥ 1` valid without claim; full rollback otherwise; no PLP/YT liquidation, no percent floor, no second Weighted fee.
8. **Status:** source mapping recorded; L3 composition and G1 deployed equivalence (including YT V1-vs-V2 binding) not closed. L1/L2/NN-03 undisturbed.

## 2. Corrections to my own original

1. **Accrual formula missing the WAD factor (material).** My §3/§5/§8 wrote `interest = floor(principal × (k−j) / (j×k))`. The source is `(principal × (k−j)).divDown(j×k)` with `divDown(a,b) = floor(a×1e18/b)` (`PMath.sol:48–53`; `InterestManagerYT.sol:76`), i.e. `interest = floor(b × (k−j) × 1e18 / (j×k))`. Astra and Grok have it correctly (Grok's vector: `B=1e18, prev=1e18, cur=1.1e18 → 90909090909090909`; verified by hand: `1e53/1.1e36`). My "accrual dust" vector conclusion (tiny deltas floor to 0) survives coincidentally, but the formula and all C estimates must carry the `×1e18`. Astra's related warning also adopted: `floor(bW/j) − floor(bW/k)` is **not** identical to the single source expression; do not restructure the floors.
2. **"Market-held YT does not exist" was too absolute.** YT is a freely transferable ERC20; YT donated/transferred to the market address accrues interest owned by `user = market`, claimable by anyone **to the market**, with no inspected method routing it to LPs (Astra §5). It is excluded from hook C, and `skim()` does not touch it (skim moves only excess PT/SY to treasury, `PendleMarketV3.sol:225–231`). Corrected statement: the market holds no YT by reserve design, but market-address YT accrual is a real, stranded-by-source case — not hook entitlement. The market-incentives-vs-principal distinction is unchanged.
3. **"Pricing-neutrality of the claim" needs qualification.** The claim does not move the SY conversion index and does not change `d` — that stands. But `R[sNET]` invariance under C→H holds only if C is tracked **net-of-fee with the source's own floors**; estimation gaps (stale same-block cache, fee-floor dust, pending-delta floor, force-claim timing) mean realized `H + C` after the claim can be **less** than the pre-claim estimate. The remainder check must therefore use measured post-claim values, never the estimate (Astra §8's "do not write `C1 = C0 − r`"; Grok §6.2 steps 4–7). I downgrade my claim from "pricing-neutral" to "quote- and `d`-invariant under consistent net-of-fee accounting; measure, don't assume."
4. **Force-claim reconciliation ordering.** Astra/Grok sharpen my "book promptly": (a) capture supported pretransfer credit **before** any sync/booking that would erase it; (b) if an eligible caller consumes the unbooked force-claimed receipt under L2, those units are the consumer's contribution — they cannot also be booked as hook H or remain C. Booking is reconciliation, not auto-appropriation; there is no provenance restriction either. My original's "hook must book force-claimed SY promptly" is retained only with this ordering and the L2-consumption precedence.
5. **C must include the pending delta.** Reading only `userInterest[hook].accrued` understates C whenever the index has moved since the last touch (Grok §4.2; Astra §3). My §5 formula had the projected-delta structure but with the wrong floor (correction 1) — restated correctly in §5 below.

## 3. Objections to peer claims (source-checked)

### 3.1 MiniMax — claim-trigger sequencing error
MiniMax §8.3 step 3 and §15.1 step 2 use "`H + C − d ≥ 1` → no claim" as the trigger. Counterexample: `H = 50, C = 100, d = 100` passes that test, no claim is made, and the subsequent `SY.redeem(d = 100)` from 50 hook-held shares reverts on insufficient balance. Plan v0.8 §6.5.5 step 4, Astra §8 step 2, Grok §6.2 step 2 and my original all use the correct trigger: **`H ≥ d` → no claim; `H < d` → claim.** MiniMax's own §14.2 vectors ("`H = d, C > 0` proceed") are consistent with the correct trigger and contradict its sequence text.

### 3.2 MiniMax — fee-dust direction error
MiniMax §6.4: "For `interestPreFee < 1`... the entire interest goes to the treasury." Backwards: `fee = floor(gross × r / 1e18) = 0` for tiny gross, so `net = gross − 0 = gross` — the **user** receives everything; MiniMax's own §14.1 vectors (10 wei, 1% → hook gets all 10) confirm. The dangerous boundary is the opposite of what the text says, and §6.4's "hook must treat sub-wei interest claims as not yielding funding" is unfounded — a sub-wei-*fee* claim still pays full gross.

### 3.3 MiniMax — "hook cannot be frontrun / funds not at risk"
MiniMax §7.3/§15.1: force-claim "does not harm the hook" because recipient = hook. Incomplete under the resolved L2 policy: the force-claimed SY lands **unbooked**, becoming origin-independent public pretransfer credit consumable by the next eligible caller (Astra §8; Grok §5). The hook can lose the funding value to an intervening pretransfer consumer unless its reconciliation respects credit-then-book ordering (my correction §2.4). MiniMax §8.4's own L2 paragraph contradicts its §7.3 absoluteness. Separately, MiniMax §8.4's "L2 credit is not for hook's NET/sNET funding" is too absolute in the other direction: once the hook books a settled receipt as recognized eligible held (and it was not consumed as L2 credit), it **is** H — plan §6.5.5 step 2 distinguishes booked H from the public-credit rule precisely to allow this.

### 3.4 Same-token collision — Astra's conditional case adopted; all four now conditional
Astra §6: if `gaugeController.pendle() == market SY`, `RewardManager`'s "entire token balance is reward inventory" assumption (`RewardManager.sol:38–49`) collides with the market's reserve SY — a concrete conditional binding incompatibility. My original's flat "no same-token case" stands for the inspected sources (empty SY reward list; PENDLE appended with a `contains` dedupe check) but must carry this identity-verification caveat as a G1 row. Grok §3's treatment (book any such finding as retained incentive, not C) is the correct disposition.

### 3.5 Astra vs Grok — combined `(true,true)` vs interest-only required call (the one genuine design disagreement)
- **Astra** proposes the funding phase as combined `YT(hook,true,true)` + `market(hook)`, citing PRD §6.2 step 3's "collect available pending Pendle interest/rewards... retain the SY, and attempt forwarding of other fee-destined tokens," while explicitly noting the interest-only variant is a real supported API.
- **Grok** (and MiniMax §11.2, and my original) require the **funding** leg to be `YT(hook,true,false)`: with `(true,true)` or the router batch, a reverting reward-token transfer (PENDLE/gauge) sits in the same revert domain and would roll back the required interest claim — the opposite of failure isolation (`PendleYieldToken.sol:174–189` pays rewards **before** interest in one frame; a reward-transfer revert undoes the interest transfer too).
- **Assessment (source-checked):** Grok's failure-domain analysis is correct for the required funding call. PRD §6.2 step 3's collection language is satisfied by a **separate** reward-collection/forwarding obligation (scheduled or same-tx isolated call the hook may catch) — not by coupling rewards into the funding claim. Astra's own fallback sentence concedes the interest-only variant is supported. For this SY compilation the YT reward list is empty, so the coupling risk materializes only through the market call; the router batch always includes it and must not be the funding path. **I side with Grok; the plan should name the combined collection obligation explicitly (per Astra's warning not to silently omit it) but keep it out of the required interest call's revert domain.** This is a composition choice for the moderator, not source disagreement.

### 3.6 MiniMax — closure language
MiniMax §17 claims "L3 claim-phase composition: source-derived path is closed" and NN-10 "satisfied at source-mapping level." Astra, Grok and I all hold: source mapping recorded, **no L3/G1 closure** (deployed YT version, factory parameters, gauge infrastructure, and the exact-output residual item in plan §6.5.3 all remain). MiniMax's closure claims should be discounted to "mapping recorded," as in the prior round.

## 4. Adopted refinements (attributed)

- **Astra:** `_setPostExpiryData` freezes `firstPYIndex` at the **first post-expiry touch**, not at the expiry timestamp — expiry-boundary vectors must not assume an exact-expiry index. `ActionInfoStatic.getUserPYInfo`/`getUserMarketInfo` actually perform claims — never call "Static" helpers in read-only phases. The static `pyIndexCurrentViewYt` reads `exchangeRate` even when the real cached YT call would not — don't substitute it blindly (different failure dependency). Zero-`totalActiveSupply` market absorbs reward receipts into `lastBalance` without index increment — no retroactive allocation to the next LP. User reward index 0 initializes to `INITIAL_REWARD_INDEX = 1`.
- **Grok:** receipt rule `c == interestOut` unless a proved SY fee shows a smaller measured delta, then use the delta. Scoped clearing: after a claim, `C := 0` **for that YT's interest**; other remaining claims persist (`C1 = Cother`, per Astra). Recompute `d` with the branch index the upcoming redeem will use; never use the PY index as the sNET branch index.
- Both: required steps must not use router `multicall` `allowFailure=true`.

## 5. Final exact safe call sequence (consensus synthesis; specification only)

Preconditions: plan §6.5.5 steps 1–3 done (auth, pretransfer credit captured **first**, required settlement, Weighted quote `y`, `d = qMin(y)` at branch index). `C` per (series, YT) = `accrued_stored + floor(b × (k − j) × 1e18 / (j × k))` with `k` the actual claim index (cache/frozen-aware), then `C −= floor(C_gross × liveFeeRate / 1e18)` — net, current, per-series.

1. If `H ≥ d`: no funding claim. (`H = d` requires `C ≥ 1`.) Skip to step 5.
2. If `H < d`: call **direct** `YT.redeemDueInterestAndRewards(hook, true, false)` per configured validated series (active first, then retained historical YTs as selected). **Do not catch. No router batch. No `(true,true)` in the funding leg.** `(false,false)` reverts `YCNothingToRedeem`.
3. Measure `c` = hook SY balance delta across the call (narrow window, excluding snapshotted pretransfer credit); check `c == interestOut` (or use the measured delta if a proved SY fee exists). Zero `c` is not funding.
4. Book: `H ← H + c`; `C ← Cother` (clear only the settled series' entitlement; re-read native state rather than `C −= c`). Excess above the shortfall stays booked eligible H — never L2, never a fee.
5. Recompute branch index (unchanged by the claim itself) and `d`; require `H ≥ d` and `H + C − d ≥ 1` on measured values. Else revert everything — including the claim. No second claim, no `redeemPY`, no LP burn.
6. Separately (different revert domain): collect/forward non-interest rewards (market PENDLE, YT reward tokens if any) and attempt `feeTo()` forwarding under the selected best-effort exception. This step's failure never unwinds steps 2–5; conversely a required failure in steps 2–5 reverts it too.
7. `SY.redeem(receiver, d, tokenOut, minNominal, false)` from hook-held shares (plan §6.5.4). NET branch may advance one NetNet epoch inside `unstake`; sNET branch does not. Measure recipient delta; exact-out requires the required net amount (plan §6.5.3 `I > 1e18` residual unchanged).
8. Debit `d` once from H; require post-state eligible `H + C ≥ 1`; refunds; full expected-set sync. Booked H is never again L2 credit.

## 6. Numeric boundary vectors (consensus; specified, not executed)

| Vector | Expected |
| --- | --- |
| Accrual WAD | `b=1e18, j=1e18, k=1.1e18, A=0` → pending `floor(1e18×1e17×1e18/(1e18×1.1e18)) = 90909090909090909` |
| Floor non-identity | `b=1, j=0.75e18, k=1.5e18` → source `floor(1×0.75e18×1e18/(0.75e18×1.5e18)) = 0`, while `floor(bW/j) − floor(bW/k) = 1` — preserve the source expression (Astra) |
| Fee floor | gross 19, r=5% → fee 0, net 19 (not 18, and **not** "all to treasury" — §3.2). gross 20 → fee 1, net 19 |
| Fee timing | two claims gross 10+10 at 5% → net 20; one combined claim gross 20 → net 19 (Astra) |
| First touch | `j=0, b>0` → index initialized, pending 0, no retroactive interest |
| Cache | `doCacheIndexSameBlock`, updated this block, exchangeRate 2W vs stored W → k = W; next uncached update may use 2W |
| Expiry | `firstPYIndex=2W, live 3W, j=W, b=1000` → gross 500 at frozen index; live growth is treasury's, not C |
| Trigger | `H=50, C=100, d=100` → **must claim** (§3.1); `H=d, C=1` → no claim, valid; `H=d, C=0` → revert |
| Short receipt | expected 450, measured `c=449`, `d=549, H=100` → `H'=549, C=0` → zero remainder → full rollback; do not fabricate `C=1` |
| Force-claim | third party settles 450 → unbooked 450 is L2 credit until booked; if consumed by a pretransfer caller, it is not also H/C; hook's later claim returns 0 |
| Market zero-active | `totalActiveSupply=0`, reward receipt 10 → `lastBalance` absorbs, no index increment; next LP gets none of the 10 retroactively |
| Epoch | `staking.epoch().end` unchanged across any claim; one later NET `unstake` advances at most one epoch; sNET redeem none |
| Upstream vs downstream | reverting PENDLE transfer inside a coupled claim reverts interest too (hence interest-only funding leg); failed hook→feeTo forward retains excluded payable and the route succeeds |

## 7. Resolved source mapping vs true gaps

**Resolved (four-way, source-verified):** entrypoints/caller-recipient rules; accrual formula with WAD factor and first-touch rule; fee structure and per-claim floor timing; index max/cache/frozen-expiry mechanics; crystallization-on-transfer; claim inventory for this SY (interest-only + PENDLE); no-epoch-advance call graph; failure domains; trigger/remainder semantics; once-only H/C with L2 precedence.

**True deployed/source gaps (G1; unchanged by this review):** deployed YT version (V1 local vs V2 interfaces with different `userInterest` shape — no local V2 implementation); YC factory `interestFeeRate`/`rewardFeeRate`/`treasury` live values; gauge controller/PENDLE/vePENDLE identity and funding on 4663, including the §3.4 PENDLE==SY collision check; `doCacheIndexSameBlock`; market/YT/SY binding via `readTokens`; deployed market implementation (YT escrow variant); deployed NetNet staking/sNET mirror and SY proxy identity; live state (indexes, accrued, active balances). Local Pendle tree remains an unpinned reference port.

## 8. Confidence

High: §1 agreements, §2 corrections 1–2, §3.1–§3.4 objections (all line-level verified). High-but-conditional: §5 sequence as the composition satisfying plan v0.8 and failure isolation. Medium: §3.5 disposition (moderator's composition choice; PRD §6.2 step 3 wording vs failure isolation). No tests run; no L3/G1 closure claimed; consensus is not proof of security or economic soundness.

Saved: `docs/research/netnet-pendle-claim-funding/kimi-cross-review.md`. Original preserved at `kimi-original.md`. Returning to the moderator; stopping.
