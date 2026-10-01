# Kimi K3 — original (follow-up round): Pendle market/YT claim path composed with plan v0.8 SY redemption

| Field | Value |
| --- | --- |
| Researcher | Kimi K3 (`kimi-code-plan-global/k3`, variant high), retained session, new bounded follow-up question |
| Date / access date | 2026-09-28 |
| Status | Independent original. No peer NEW originals or cross-reviews read (no read/glob/grep of them). Prior round context treated as historical; this question is derived from current primary source. Research only — no shell/tests/deployments/implementation/delegation/config edits; no plan/tracker writes. |
| Question | Map the actual Pendle market/YT claim path used when eligible held SY is insufficient, and compose it with plan v0.8's specified SY redemption. |
| Governing docs | `CLAUDE.md`; PRD v0.33; implementation/test plan **v0.8** (§6.5 rewritten; §6.5.5 funding sequence; §6.5.7 dependency rows); `PRD_OPEN_QUESTIONS.md`. |
| Primary source | Local Pendle tree `lib/crane/contracts/protocols/perps/pendle/` (cited `P/...`). This is a **local reference port**; deployed binding on chain 4663 is **G1 evidence**, not established here. SY identity from the verified extract `E` (`docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md`) as recorded in plan v0.8 §6.5. |
| Context7 / web | Not used: no new external library/API documentation claim; all claims are from local source. |

## 1. Actual claim entrypoints (observed fact, local Pendle source)

| # | Entrypoint | Signature / location | Caller | Recipient of proceeds |
| --- | --- | --- | --- | --- |
| C1 | YT interest+rewards | `IPYieldToken.redeemDueInterestAndRewards(address user, bool redeemInterest, bool redeemRewards)` — `P/core/YieldContracts/PendleYieldToken.sol:166–193`; interface `P/interfaces/IPYieldToken.sol:35` | **Anyone, for any `user`**; no authorization | Hardcoded `user`: `_doTransferOutRewards(user, user)` (`:179`); `_doTransferOutInterest(user, SY, factory)` pays `user` (`:188`; `InterestManagerYT.sol:43–60`). No recipient redirection exists. |
| C2 | Market LP rewards | `IPMarket.redeemRewards(address user)` — `P/core/Market/v3/PendleMarketV3.sol:237–239` → `PendleGauge._redeemRewards` (`PendleGauge.sol:43–48`) | Anyone, for any `user` | `user` (`_doTransferOutRewards(user, user)`, `RewardManager.sol:61–77`). No fee on market LP rewards. |
| C3 | Router batch | `ActionMiscV3.redeemDueInterestAndRewards(user, sys[], yts[], markets[])` — `P/router/ActionMiscV3.sol:67–84` | Anyone | Same per-leg rules; loops `SY.claimRewards(user)`, C1 with `(true,true)`, C2. Pure convenience; offers no partial amounts and no recipient override. |
| C4 | Post-expiry treasury sweep | `redeemInterestAndRewardsPostExpiryForTreasury()` — `PendleYieldToken.sol:199–226` | Anyone; pays **factory treasury**, not users | Treasury only; reverts pre-expiry (`YCNotExpired`). |
| C5 | SY rewards | `SY.claimRewards(user)` | — | **No-op for this SY compilation**: verified `PendleStakedNetSY` (SYBaseUpgV2) returns empty arrays from `claimRewards/getRewardTokens/accruedRewards/rewardIndexesCurrent/Stored` (E:309–333 of the extract; plan v0.8 §6.5.5 step 4). |

Direct calls (C1/C2) and the router batch (C3) are functionally equivalent for this market. The hook should call C1 on the YT and C2 on the market with `user = hook`; any permissionless keeper can do the same with identical effect (PRD R30). There is no "claim on behalf to a different recipient" API in this source.

## 2. What is claimable for THIS market's SY (observed + derived)

- **YT interest — the only SY-denominated claim.** YT accrues SY interest from PY-index growth (`InterestManagerYT.sol:63–80`). Net of factory interest fee (`§3`).
- **YT reward tokens — none.** `YT.getRewardTokens()` delegates to `SY.getRewardTokens()` (`PendleYieldToken.sol:417–419`), which is empty for this SY. YT's `_updateRewardIndex` returns empty and `_updateAndDistributeRewardsForTwo` exits early (`RewardManagerAbstract.sol:35–41; PendleYieldToken.sol:486–496`); `_redeemExternalReward` calls the no-op `SY.claimRewards` (`:475–477`). Therefore `redeemDueInterestAndRewards(hook, true, false)` suffices; `(true,true)` is harmless and returns an empty rewards array.
- **Market LP rewards — PENDLE only.** `PendleGauge._getRewardTokens()` = `SY.getRewardTokens()` ∪ `{PENDLE}` = `[PENDLE]` (`PendleGauge.sol:102–106`). Accrual via `activeBalance` with ve-boost (`TOKENLESS_PRODUCTION = 40` → 40% tokenless weight without vePENDLE, `:22,74–83`); funding via `gaugeController.redeemMarketReward()` (`:85–88`; `PendleGaugeControllerBaseUpg.sol:85–96`, weekly-vote-funded `accumulatedPendle`; zero amount is a no-op, not a revert).
- **Same-token incentive case: none in this source.** No SY-denominated incentive stream exists for this compilation, so there is no interest-token/incentive collision to adjudicate; no blanket same-token eligibility is inferred. If a different configured SY ever lists reward tokens, that is a separate G1 finding, not this source.
- **LP rights are not claims.** Market LP swap-fee income accrues inside reserves (`netSyToReserve → treasury`, `PendleMarketV3.sol:171,208`); it is realized at `burn`, not claimable. YT interest and market PENDLE incentives are the only pullable streams. **Market-held YT does not exist** (the market holds PT+SY only); "hook-held YT" is the only applicable YT custody, and `address(this)`/`address(0)` are excluded from interest/reward accrual by the `updateForTwo` guards (`InterestManagerYT.sol:37–41`).

## 3. Interest accrual, index, cache, expiry and fee floors (observed exact math)

- **PY index:** `_pyIndexCurrent()` = `max(IStandardizedYield(SY).exchangeRate(), _pyIndexStored)`, stored as `uint128` (`PendleYieldToken.sol:397–407`). For this SY, `exchangeRate() = _syncedIndex() × 1e9` (plan v0.8 §6.5.1) — the **projected** one-epoch NetNet index, in 18-decimal scaled-NET terms. `doCacheIndexSameBlock` (immutable, factory-set, `PendleYieldContractFactory.sol:102,144`) makes the index constant within a block; the static view `pyIndexCurrentViewYt` replicates the logic including the cache check (`P/offchain-helpers/router-static/base/ActionMintRedeemStatic.sol:103–115`).
- **Accrual:** on any distribution trigger, `interestFromYT = floor(principal × (cur − prev) / (prev × cur))` (`divDown`), added to `userInterest[user].accrued` (uint128; `Uint128()` cast reverts above) (`InterestManagerYT.sol:63–80`). First touch initializes `index` with **no retroactive accrual** (`:69–72`). Triggers: any YT `_beforeTokenTransfer` distributes for `from`/`to` **before** the balance change (`PendleYieldToken.sol:499–503`), and C1 distributes before paying (`:186–188`). Units: YT principal and PY index are 18-decimal-scaled; accrued interest is SY shares.
- **Fee and net SY:** `fee = floor(accrued × interestFeeRate / 1e18)` (`mulDown`), `net = accrued − fee`; fee → YC-factory `treasury()`, net → `user` (`InterestManagerYT.sol:43–60`; `IPYieldContractFactory.sol:43–47`). Fee transfer precedes user transfer, both inside one atomic claim. The C estimate must therefore be net-of-fee per (series, YT), or gross with the fee reconciled at claim time; mixing the two double-counts or overstates C.
- **Expiry:** `updateData` sets post-expiry data once (`PendleYieldToken.sol:52–56,373–386`): `firstPYIndex` frozen at first post-expiry index; post-expiry `_getInterestIndex()` returns the frozen index (`:392–395`) so **no new interest accrues post-expiry**; already-accrued interest stays claimable in the historical SY indefinitely (matches PRD §11.1). Post-expiry rewards go to treasury (`:429–441`, C4). `redeemPY` pays current-index SY to the user and books the first-index-vs-current-index difference to `totalSyInterestForTreasury` (`:347–357`) — matching plan v0.7 §7.1.2's treasury-exclusion note.
- **Interest crystallization on YT moves:** selling/transferring YT crystallizes the hook's accrued interest into `userInterest[hook].accrued` at the pre-transfer index; the receiver starts fresh. Accrued interest therefore **stays with the hook** through Keep-YT position exits and does not travel with the YT. `redeemPY` does **not** pay interest (`PendleYieldToken.sol:124–127` doc); interest is claimed separately via C1.

## 4. Claims cannot advance the NetNet epoch (derived from the call graph; high confidence)

Full call graph of every claim path: C1 → `_pyIndexCurrent()` → `SY.exchangeRate()` (**view**; reads `staking.epoch()` and projects — plan v0.8 §6.5.2) plus YT-internal writes; C2 → `SY.claimRewards` (no-op) + `gaugeController.redeemMarketReward()` (PENDLE transfer only); C3 → C1/C2/no-op. **None of these call NetNet `stake`/`unstake`/`rebase`.** Only SY NET-deposit (`stake`), SY NET-redeem (`unstake`), and direct `Staking.rebase()` advance the NetNet epoch (plan v0.8 §6.5.2; local `N/Staking.sol:88–151`, reference only). Claims **read/project**; they never settle an epoch.

Two consequences:

1. **Ratchet on projection:** YT's stored PY index ratchets to `max(projected exchangeRate, stored)`. While a profitable epoch is overdue-but-unsettled, YT interest accrues against the one-epoch *projection* — at most one NetNet epoch ahead of the realized sNET index. This is not loss or double-count: interest is paid in SY shares whose redemption value is realized when the epoch actually settles (the hook's NET redemption itself settles it via `unstake`). With multiple overdue epochs, YT accrual lags wall-clock until staking advances, then catches up via `max`; nothing is forfeited.
2. **Funding chronology:** a claim does **not** change the SY conversion index (`Ic`/`Ip`). Therefore in the H<d path the claim leaves `d` unchanged; only an actual stake/unstake (Keep-YT ingress, or the redemption itself) or a timestamp crossing can change the branch index and force recomputation of `d` (plan v0.8 §6.5.5 step 5).

## 5. Force-claims, transfers, and the once-only H/C ledger (consistent with L2; L2 not reopened)

Effects on interest rights (observed):

- **Third-party force-claim:** because C1/C2 are permissionless with beneficiary `user`, anyone can settle the hook's accrued interest/rewards at any time. The SY/PENDLE lands at the hook **unbooked**: `userInterest[hook].accrued` and `userReward[PENDLE][hook].accrued` are zeroed upstream while the hook's booked H is stale. This is the exact force-claim case PRD §6.3/NN-11 anticipates.
- **Donations to third-party contracts are not hook claims:** SY sent to the YT contract becomes floating SY mintable as PY by anyone (`PendleYieldToken.sol:368–371`, `mintPY`); SY/PT dust on the market is `skim()`-able to treasury (`PendleMarketV3.sol:225–231`); PENDLE force-sent to the **market** is absorbed into the reward index and distributed **pro-rata to all LPs** including the hook (`RewardManager.sol:38–49`: `accrued = selfBalance − lastBalance`, once per block). None of these is attributable hook income on arrival; the market-index case becomes hook income only through the hook's accrued share.
- **Ledger transitions (proposed specification, consistent with plan v0.8 §6.5.5 steps 2/5 and PRD §6.3):**

```text
Receivable model per (series, YT): C_YT = userInterest[hook].accrued_stored
        + floor(YT_hook × (Iproj − idx) / (idx × Iproj))   [projected, net-of-fee convention]
Aggregate: C = Σ C_YT (net of interest fee),  H = booked eligible held SY
Own claim settling gross g with fee f = floor(g×feeRate/1e18), measured receipt c = g − f:
    H ← H + c ; C_YT ← C_YT − (c + f) (once); no profit, no double count
Third-party force-claim detected by (rawBalance − booked H) > 0 and upstream accrued drop:
    book identically at the next route's reconciliation BEFORE computing available credit;
    the settled cash must not remain counted beside the cleared receivable
Reward leg (PENDLE): claimed → held at hook → forward to current feeTo() (best-effort);
    never eligible SY; a failed forward leaves an excluded payable, not backing
```

- The origin-independent public pretransfer rule (L2, resolved) is preserved and not reopened: an unbooked force-claimed SY balance **is** `max(raw−booked,0)` surplus consumable by the next eligible caller on routes supporting pretransfer. That is precisely why the hook must reconcile force-claims into its booked H/C ledger at route start (PRD §6.3) — bookkeeping promptness, not a provenance gate.

## 6. Composition with plan v0.8 §6.5.5 (claim phase inside H<d)

1. **Pricing-neutrality of the claim (derived, resolves an apparent ordering tension).** PRD §6.1 rates the sNET coordinate from *held SY **plus** net-claimable SY*, so the claim (C→H conversion) does not change the pricing vector: `R[sNET]` is invariant under the claim. Combined with §4 (claims don't move the SY index), the quoted output `y` and the SY debit `d = qMin(y)` are both unchanged by the claim itself. Requoting/recomputing `d` is required only after state changes that alter the index (stake/unstake/epoch) or the requested amounts — exactly plan v0.8 §6.5.5 step 5, now with the reason pinned.
2. **Claim trigger and amount:** trigger is `H < d` only. C1 settles the **entire** accrued balance per YT — there is no partial/shortfall selector in this source (confirmed §1). The plan's "claim-only-if-short is a trigger, not a fictitious partial-shortfall selector" is source-correct. Collecting more than the shortfall is expected and bounded by the accrued entitlement itself.
3. **Sequence for the claim phase:** read `userInterest[hook]` per configured YT (active + retained historical series) → if `H ≥ d`, no claim → else C1 on each configured YT (interest only; rewards leg empty for this SY) and, on the configured schedule, C2 for market PENDLE → measure the SY receipt in a narrow window around the claim (no rebase can intervene inside it; §4) → book per §5 → re-check `H' ≥ d` and `H' + C' − d ≥ 1` → redeem per plan v0.8 §6.5.5 step 6 (`redeem(receiver, d, tokenOut, minNominal, false)` from hook-held shares) → verify recipient delta and post-state `H + C ≥ 1`.
4. **Index chronology example (plan-only vector):** snapshot `Ip` (one overdue profitable epoch) → `d = ceil(y×1e18/Ip)` → claim (no index change) → redeem NET: `unstake` settles the projected epoch; nominal `floor(d×Ip/1e18) ≥ y` by the §6.5.3 inverse proof; post-unstake `Ic = Ip_realized`; any subsequent same-tx operation sees a new `_syncedIndex` (next epoch's queue). If a same-tx Keep-YT ingress `stake` preceded the claim, the epoch is already settled and `d` must have been recomputed with the post-stake index before the shortfall test.
5. **Receipt semantics:** C1's returned `interestOut` is the nominal net amount and equals the SY transferred (TokenHelper safeTransfer; `InterestManagerYT.sol:53–58`); a zero-accrued claim succeeds with `interestOut = 0` (no revert; `_transferOut` early-returns on 0) — **a zero-receipt claim is not funding** and must fail the shortfall re-check, not satisfy it. `(false,false)` reverts `YCNothingToRedeem` (`PendleYieldToken.sol:172`).
6. **Atomic failure split (directly verified):** upstream claim failures revert the entire claim with entitlements intact (revert restores `accrued` zeroing and both transfers — `InterestManagerYT.sol:50–58` is one frame; a paused SY blocks its transfers via `whenNotPaused`, E:363). These are **unavoidable claim failures** → the hook propagates and the whole route reverts (plan v0.8 §6.5.5 step 7); **no catching of required claim failure**. Distinct: only the hook's *own downstream* forward of PENDLE/other fee tokens to `feeTo()` is the selected best-effort exception (PRD §13, NN-03); a failed `market.redeemRewards` or YT interest transfer is upstream and never isolated. A gauge-controller revert inside C2 is likewise upstream and fatal to that claim call.

## 7. Historical series, rollover and custody notes

- Post-rollover/expired YT: C1 remains callable (no `notExpired` on C1), index frozen, accrued interest claimable in the old SY; the hook's series Repo must retain (oldSY, oldYT) locators per plan §5.1, and C per series must be tracked separately (fee floors are per-claim, per-YT).
- Hook-held YT vs market-held YT: only hook-held YT exists (§2). Market-held SY (reserves) earns no claim; LP fee income is realized at burn.
- Hook operations map: plan §5.4's `collectRewards(historicalMarket)` is implementable as: `readTokens()` → C1 on that YT + C2 on that market (when `historicalMarket == activeMarket()` or a retained validated series), hold SY, forward non-SY tokens to dynamic `feeTo()` — permissionless-safe because proceeds can only go to `user` = the hook.

## 8. Before/after equations and boundary vectors (plan-only; nothing executed)

State: `H, C = Σ_YT C_YT`, `d` from plan §6.5.3, fee rate `r` (uint128 WAD), per-YT `acc`, `idx`, YT balance `Y`, projected index `Iproj`.

```text
C_YT(pre)  = acc + floor(Y × (Iproj − idx) / (idx × Iproj)) − feeConvention
claim:     g = acc (settled in full) ; f = floor(g × r / 1e18) ; c = g − f
(post)     H' = H + c ; C_YT' = projected remainder only (acc cleared; idx ← Iproj)
invariant: H' + C' − d ≥ 1 required at redemption; H' ≥ d required to skip further action
```

| Vector | Expected |
| --- | --- |
| Accrual dust | Y=1e18, prev=1e18, cur=1e18+1 → interest floor `1e18×1/(1e18×(1e18+1)) = 0`; nothing accrues; index still updates |
| Fee floor | g=1000, r=3e16 → f=30, c=970. g=1, any r<1e18 → f=0, c=1. r=0 → c=g |
| Zero-accrued claim | `interestOut=0`, no revert; shortfall re-check fails → full route revert |
| Claim-collects-all | d−H=100, acc=500 → H'=H+500(−f); remainder test uses actual c, not 100 |
| Force-claim race | third party settles acc=500 before the route: route books H+=500, C_YT cleared, own claim returns 0; no double count, no second receivable |
| uint128 boundaries | `accrued`/`index` casts revert above uint128 — a domain fault, not a quote of zero; at the sNET supply cap, `exchangeRate ≈ 6.81e37 < type(uint128).max ≈ 3.40e38`, so the PY-index cast remains safe through the cap (derived from plan §6.5.2 constants; local-reference inference) |
| Two overdue epochs | claim ratchets PY index by the one-epoch projection only; redemption settles one epoch; second epoch settles on a later staking call; no interest loss, no catch-up loop |
| Market reward donation | force-sent PENDLE to market raises the index pro-rata; hook's claim pays only its accrued share; `skim()` never touches PENDLE |
| Expired YT | C1 pays accrued at frozen index; no new accrual; C4 pays treasury only |

## 9. Exact proposed plan addition (text for the moderator; not applied)

Add **§6.5.9 "Configured Pendle claim phase (market/YT source mapping)"**:

1. Entrypoint table = §1 C1–C5 with paths/lines; beneficiary fixed to `user`; no recipient override; direct vs router-batch equivalence; `SY.claimRewards` no-op for this compilation.
2. Claimable inventory for this SY: YT SY interest (held); market PENDLE incentives (forward); empty YT rewards; no same-token incentive case; LP fee income not claimable; no market-held YT.
3. Exact accrual/fee math of §3 including the per-YT net-of-fee convention and the crystallization-on-transfer rule; C1 settles full accrued (no partial selector).
4. Claims do not settle NetNet epochs (§4 call-graph proof); index/`d` recomputation triggers are stake/unstake/timestamp only; claim is pricing-neutral because R[sNET] rates H+C.
5. Once-only H/C transitions including third-party force-claim booking at route reconciliation (§5), consistent with the resolved L2 policy.
6. Failure split: upstream claim revert = required failure (propagate; entitlements persist upstream); only downstream hook→feeTo forwarding is best-effort (§6.6).
7. Amend §6.5.5 steps 4–5 to cite C1/C2 by name and §6.5.7's claim row from "remaining source composition" to "source-mapped; G1 bindings pending" (list in §10 below). Add §8's vectors to §6.5.8.

## 10. Finite remaining G1 / source gaps (no closure claimed)

1. **Deployed YT version.** Local tree contains only YTv1 (`PendleYieldToken`); `IPYieldTokenV2`/`IPInterestManagerYTV2` interfaces exist with a **different** `userInterest` shape (`lastInterestIndex` vs PY index) and no local implementation. The configured market's `readTokens()` YT identity/version on 4663 is G1; this mapping is V1-specific.
2. **YC factory parameters:** `interestFeeRate`, `rewardFeeRate`, `treasury` (`PendleYieldContractFactory.sol:58–62`) — live values are G1; no default is assumed.
3. **Gauge infrastructure on 4663:** GaugeController deployment, PENDLE token identity, funding/voting messages (`accumulatedPendle` may be zero — claim then yields 0 PENDLE without revert), vePENDLE presence (hook boost = 40% tokenless weight absent ve).
4. **Deployed market/YT immutables:** `doCacheIndexSameBlock`, expiry, SY binding to the verified `PendleStakedNetSY` proxy; market factory `getMarketConfig` affects swap pricing, not this claim path.
5. **Deployed NetNet staking/sNET equivalence** (projection mirror) and SY proxy identity — unchanged from plan §6.5.7.
6. Local Pendle tree is an unpinned port; deployed market/YC code equivalence is G1, exactly as with the NetNet reference.

This maps the claim path from local source; it does **not** close L3 composition (owned-HLP/Keep-YT chronology, exact-output residuals per plan §6.5.3/§6.5.7 remain) and does **not** close G1.

## 11. Fact / inference / uncertainty and confidence

- **Fact (local source):** all §1 entrypoints/caller-recipient rules; §2 empty-reward consequence contingent on the verified SY extract; §3 math; §6.6 failure atomicity; gauge/factory mechanics.
- **Inference:** pricing-neutrality of claims (from PRD §6.1 + plan v0.8); ratchet-without-loss argument; 40% tokenless boost for the hook; per-series net-of-fee ledger convention as the cleanest once-only model.
- **Uncertainty (G1):** everything in §10, especially YT V1-vs-V2, live fee rates, gauge funding/PENDLE existence on 4663.
- **Confidence:** high on the V1 claim-path map and its composition with plan v0.8; medium on deployed applicability pending §10. No tests run; no runtime observation made.

Saved: `docs/research/netnet-pendle-claim-funding/kimi-original.md` (this file). Stopping after this original.
