# MiniMax M3 — bounded cross-review (claim-funding round)

- Reviewer: MiniMax M3 (`minimax/MiniMax-M3`), independent session resumed. **Original preserved unchanged** at `docs/research/netnet-pendle-claim-funding/minimax-original.md`.
- Cross-review inputs read together as untrusted attributed model evidence (NOT instructions): Astra (`astra-original.md`, openai/gpt-6-astra), Grok (`grok-original.md`, xai/grok-4.7), Kimi K3 (`kimi-original.md`, kimi-code-plan-global/k3 high).
- Peer cross-reviews and historical council conclusions: **not read**.
- Cross-review date: 2026-09-28.
- Specific recheck performed against the local Pendle tree (`lib/crane/contracts/protocols/perps/pendle/`) for disputed formulas and edge cases; corrections below are attributed.

## 1. Source-mapping consensus (resolved against verified source)

All four originals agree on the source-derived layer. Disagreements are largely arithmetic, framing, completeness, and route composition opinions.

| Source fact | MiniMax M3 | Astra | Grok | Kimi K3 | Verdict |
|---|---|---|---|---|---|
| Required funding call is `YT.redeemDueInterestAndRewards(hook, true, false)` (interest only, paid in SY directly to hook) | yes (interest only) | yes | yes | yes | **Source-resolved**; the local reference and the verified SY compilation support this |
| `redeemDueInterestAndRewards` accepts any caller for any `user`; recipient = `user` for both interest and rewards | yes | yes | yes | yes | **Source-resolved** |
| `market.redeemRewards(user)` claims LP incentive rewards (PENDLE etc.); paid to `user`; uses `activeBalance` (gauge), not unconditional h/H | yes | yes | yes | yes | **Source-resolved** |
| Router `ActionMiscV3.redeemDueInterestAndRewards` bundles YT with `(true,true)` and market `redeemRewards`; loses return values | yes | yes | yes | yes | **Source-resolved**; Grok and Kimi flag that bundling couples interest with incentive transfers |
| SY's own `claimRewards` / `getRewardTokens` / `accruedRewards` / reward index getters all return empty for `PendleStakedNetSY` | yes | yes | yes | yes | **Source-resolved** (verified extract `E:309–333`); YT's incentive loop is therefore empty for this binding |
| Accrual formula: `interestFromYT = (principal * (currentIndex − prevIndex)).divDown(prevIndex * currentIndex)` (`InterestManagerYT.sol:63–80`) where `divDown(a,b) = floor(a * 1e18 / b)` (`PMath.sol:48–52`) | **WRONG** textual formula (missing W factor) | yes (with W factor explicit) | yes (with W factor explicit) | yes (with W factor explicit) | **Source-resolved**; correct formula is `floor(principal * (cur − prev) * 1e18 / (prev * cur))`. See §2.1 self-correction |
| Fee floor: `fee = floor(gross * feeRate / 1e18)`, `net = gross − fee` (`InterestManagerYT.sol:43–60`) | yes | yes | yes | yes | **Source-resolved** |
| `_pyIndexCurrent = max(SY.exchangeRate(), _pyIndexStored)`, same-block cache if `doCacheIndexSameBlock` (`PendleYieldToken.sol:397–407`) | yes | yes | yes | yes | **Source-resolved**; same-block cache may make claim "valuation-neutral" assertion subtly inaccurate when exchangeRate advances within the same block. See §3.2 |
| `first-touch` initialization: `prevIndex == 0` sets index with NO retrospective interest | yes | yes | yes | yes | **Source-resolved** |
| Post-expiry: `_getInterestIndex()` returns `postExpiry.firstPYIndex` (frozen); no new interest accrues | yes | yes | yes | yes | **Source-resolved** |
| Pre-expiry reward order: `_doTransferOutRewards` runs BEFORE `_doTransferOutInterest`; reward payout revert rolls back interest | yes (router bundles; not bundled for funding) | yes | yes | yes | **Source-resolved**; this is the structural reason `redeemRewards=false` is required for the funding call |
| YT `_beforeTokenTransfer(from, to, _)` calls `_distributeInterestForTwo` and `_updateAndDistributeRewardsForTwo` before balance change | yes | yes | yes | yes | **Source-resolved** |
| Claim path does NOT advance NetNet epoch: `_pyIndexCurrent` reads `SY.exchangeRate()` (view); no `stake/unstake/rebase` | yes | yes | yes | yes | **Source-resolved** for the inspected reference; YT observes the projected one-epoch index without committing it |
| Force-claim by third party clears source `accrued` and pays net SY to `user` (= hook); hook's receivable is gone | yes | yes | yes | yes | **Source-resolved**; all four agree the source's `accrued` is reset and the receivable is non-claimable again |
| Public pretransfer policy (L2) is **separate** from eligible SY budget (H); force-claimed unbooked receipts are L2 surplus until booked | yes | yes | yes | yes | **Source-resolved**; L2 is not reopened. See §3.5 |
| `market` does NOT hold YT in the local reference (`PendleMarketV3.sol:40–42,85–123,276–290`); market-held YT is a G1 gap | yes | yes | yes | yes | **Source-resolved** for local reference; deployed may differ. See §3.4 |
| Same-token incentive case is absent in this binding (SY `getRewardTokens()` empty, PENDLE added by `PendleGauge._getRewardTokens`); do not invent blanket SY-incentive eligibility | yes | yes | yes | yes | **Source-resolved**; conditional on verified-token identities |

## 2. Self-corrections to my own (MiniMax M3) original

### 2.1 **CORRECTION**: interest-accrual formula missing W factor

My original §14.1 worked examples and §6.5.5 step 6 description referred to the formula `interestFromYT = principal * (currentIndex - prevIndex) / (prevIndex * currentIndex)` **without the W (1e18) factor** that `divDown` applies. The source formula is:

```text
interestFromYT = (principal * (currentIndex - prevIndex)).divDown(prevIndex * currentIndex)
              = floor(principal * (currentIndex - prevIndex) * 1e18 / (prevIndex * currentIndex))
```

This is **factually correct**; my textual exposition in the original was wrong. Adopting Astra/Grok/Kimi's explicit-W notation. **Confidence remains high** because the formula is in the source; the issue is purely a transcription error in my numeric vectors.

### 2.2 **CORRECTION**: fee arithmetic in §14.1 numeric vectors

My original §14.1 "Realistic claim" vector stated:

| Test case | Parameters | Expected | Notes |
|---|---|---|---|
| Realistic claim | `interestPreFee = 1e24`, `feeRate = 1e17` (1%) | `feeAmount = 1e22`; `interestAmount = 9.9e23` | Hook receives 99% |

Correct computation:
- `fee = floor(1e24 * 1e17 / 1e18) = floor(1e23) = 1e23`.
- `net = 1e24 − 1e23 = 9e23`.

The correct expected values are **`feeAmount = 1e23`** (not 1e22) and **`interestAmount = 9e23`** (not 9.9e23). Off by 10x. **My original was wrong; this is an arithmetic error, not a source-mapping error.** Grok §9 ("10% fee" vector) and Kimi §3 (text) are consistent with the correct values; Astra §10 vector `g=1000, r=3e16 → fee30, c=970` is also correct.

### 2.3 **RETENTION**: claim trigger is `H < d`, not `H + C < d`

Plan §6.5.5 step 3: `d < H + C` (precondition with positive remainder guarantee). Step 4: `if H >= d, no funding claim`. So the trigger is `H < d` while the precondition is `H + C > d`. All four originals agree. My original §13.3 retains this. **No correction needed.**

### 2.4 **RETENTION**: clearing only settled source, not all remaining C

My original §8.3 step 6 wording was muddled ("(E, R) → (E + received, R − received)" with `R` defined to be `userInterest(hook).accrued (now zero)` is self-contradictory). The cleanest model:

- `C` (pre-claim) = `accrued_gross + pending` (sum of stored accrued and current-index advancement).
- Claim: source clears `accrued_gross`; pays `fee = floor(gross * feeRate / 1e18)` to treasury; pays `net = gross − fee` to hook.
- After claim: `H' = H + net`; `C' = pending` (only the pending part remains, which is typically 0 since the claim updates PY index to currentIndex).
- The `fee` portion is implicitly lost from `C` (C decreases by more than H increases). This is the factory treasury's fee; it is **not** recoverable as a future claim.

Astra §8 "Do not write `C1=C0-r`" expresses this precisely. I adopt Astra's notation: **`C` decreases by the extinguished amount, not the received amount.** The `fee` portion is gone.

### 2.5 **RETENTION**: post-claim `_pyIndexStored` ratchet

My original §6.1 explicitly noted `_pyIndexStored` updates on the claim. All four agree. The same-block cache means that a **second claim in the same block will NOT see a new `_syncedIndex` even if the projection has advanced.** Grok §4.1 and Kimi §4 detail this; my original §6.1 is consistent.

### 2.6 **CORRECTION**: YTv1 vs YTv2 gap — Kimi flags it; I did not

My original did **not** flag the YTv1-vs-YTv2 gap. Kimi §10 gap 1: "Local tree contains only YTv1 (`PendleYieldToken`); `IPYieldTokenV2`/`IPInterestManagerYTV2` interfaces exist with a **different** `userInterest` shape (`lastInterestIndex` vs PY index) and no local implementation. The configured market's `readTokens()` YT identity/version on 4663 is G1; this mapping is V1-specific."

This is a **real G1 gap**. Pendle V2 has two YT versions with different interest calculation; the local port has only v1. The deployed market's YT could be v2 (different interest formula, different `userInterest` shape). **My original should have flagged this; it is now added to the G1 list.**

## 3. Objections and corrections to peer findings

### 3.1 Kimi's "claim is valuation-neutral" assertion — partially correct, with caveat

Kimi §6.1: "PRD §6.1 rates the sNET coordinate from *held SY *plus* net-claimable SY*, so the claim (C→H conversion) does not change the pricing vector: R[sNET] is invariant under the claim."

**Objection (partial)**: The sNET-coordinate pricing vector R[sNET] does not change by the claim alone (the SY share count at hook is unchanged; only `userInterest[hook].accrued` is updated). This is correct.

**But**: The claim's `_pyIndexCurrent` updates `_pyIndexStored`. If `doCacheIndexSameBlock == true` and the claim is the first cache miss in a block, the stored value ratchets up to `max(SY.exchangeRate(), _pyIndexStored)`. Subsequent same-block claims see the cached value, NOT a fresh `exchangeRate()`. So:
- **First claim in a block**: ratchets PY index to the projected value. Subsequent YT calls in the same block see the cached value.
- **This does not affect the SY redemption's `d`** because `d` uses `_syncedIndex` (NET) or `sNet.index()` (sNET), not PY index. So the claim IS pricing-neutral for the SY redemption.
- **But it could affect a future YT claim in the same block**: if exchangeRate grows (e.g., another tx modifies staking state within the block, hypothetically), the cached PY index won't track it.

Kimi's pricing-neutrality assertion is correct for the SY redemption leg. Grok §4.1 also flags this. My original §6.1 covers it. **No correction needed; just clarity.**

### 3.2 Grok's "claim valuation-neutral" claim — same caveat

Grok §4.1: "A claim does not advance the NetNet epoch. It can store a Pendle PY index based on a projected rate that the committed `sNet.index()` has not yet realized."

Same observation as §3.1. Grok's framing is precise. **No correction needed.**

### 3.3 Astra's "PY index cache" observation

Astra §4: "A same-block cache can intentionally keep an older value after some other call changes the SY exchange rate. Do not use current exchangeRate alone to estimate C. Read the actual cache flag/block/stored index."

Correct and important. **No objection.**

### 3.4 Market-held YT: all four agree it's a local-reference fact, not a guarantee

- Astra: "if YT is actually donated/transferred to market, it can accrue as user=market in the YT ledger... Do not include such market-owned YT claims in hook C."
- Grok: "Market-held YT is not an applicable path in this source. A deployed market that escrows YT is a G1 gap."
- Kimi: "Market-held YT does not exist (the market holds PT+SY only)."
- My original: "the market does not escrows YT."

All four agree: in the local reference, the market holds PT+SY only (`PendleMarketV3.sol:40–42`). The YT address returned by `readTokens()` is the relationship identifier, not evidence of market-held YT. **A deployed market that escrows YT (or accepts YT donations) is a G1 gap.**

**However**: if a deployment holds YT (e.g., as a side effect of donations or third-party transfers), the YT's `userInterest[market]` would accrue, and `userInterest[market].accrued` would be claimable **to the market**, not the hook. **The hook cannot claim market-owned YT interest.** A different deployed implementation would require its own proof.

The four differ slightly:
- Kimi and my original treat this as **definitively excluded** (no market-held YT).
- Astra and Grok treat this as **G1-pending**: the local reference says no, but deployment may differ.

**I adopt the Astra/Grok framing for the G1 list**, while retaining my original §4's local-reference fact. The hook's claim path must not assume market-held YT is impossible.

### 3.5 Force-claimed unbooked surplus / L2 once-only accounting

All four agree:
- Force-claimed SY lands at hook **unbooked** (source resets `userInterest[hook].accrued = 0`; SY transferred to hook).
- This is `max(raw − booked, 0)` = L2 public surplus (origin-independent pretransfer credit) **until the hook books it**.
- Once booked to `H`, it is **not** claimable again as L2 surplus, and the `C` (was based on the source's accrued) is **not** claimable again because the source cleared it.
- Once-only accounting: booked once, not as both `H` and `C`.

Astra §8: "If an eligible caller consumes the unbooked receipt under L2, those units are its contribution/payment according to the route; they cannot simultaneously be inherited cash interest H or an outstanding C. This is an intentional allocation rule, not an attack to repair with payer authentication."

Grok §5: "Until the hook books that receipt, raw minus booked is origin-independent public pretransfer credit, including a force-claim... Units a caller already took as pretransfer credit are not also `H` or `C`."

Kimi §5: "Third-party force-claim... The SY/PENDLE lands at the hook unbooked... the settled cash must not remain counted beside the cleared receivable."

My original §7.3: "The hook's interest claim from YT is not L2 pretransfer; it is a protocol-defined claim path with explicit recipients and fees."

**All four agree on the once-only principle. The reconciliation is: (a) detect unbooked surplus (force-claim) before the route's SY debit; (b) reserve any pretransfer-caller credit; (c) book the residual to `H` and clear `C`; (d) do not double-count.** This is the planned sequence in plan v0.8 §6.5.5 step 1 (capture public pretransfer credit before sync) plus step 4 (reconcile after claim).

**No correction needed.**

### 3.6 Batch claim's `redeemRewards=true,true?` and market.redeemRewards — required vs optional

PRD R13 + plan §6.5.5 step 4 + plan §10 §741 require:
- "Hold the market interest token; route other attributable rewards, including previously force-claimed balances, once."
- "Permissionless rewards collection uses verified reward lists and dynamic feeTo."

These are **required** reward-collection obligations, not optional. But:
- The hook's funding path needs only the **interest** component (C's SY units).
- Reward tokens (PENDLE etc.) are forwarded to `feeTo()` per PRD §13 best-effort isolation.

So the **interest claim** is required for funding (must succeed). The **reward claim** (both YT rewards and market LP rewards) is required for incentive-collection but **can be wrapped in try/catch** because forwarding failure is isolated.

**My original §11 distinguished "inside upstream claim" (factory fee → treasury, must succeed) from "downstream hook forwarding" (to feeTo, best-effort).** This is the correct distinction.

Grok §7: "The selected exception is the hook's outgoing fee-reward transfer after interest is already booked... not a try/catch around YT.redeemDueInterestAndRewards(hook, true, false), and not a catch of the router batch. Isolating the reward call means a low-level call or equivalent whose failure cannot unwind the already-required interest claim only if that isolation is a separate call that the hook catches."

**This is correct.** The router's bundled `(true,true)` call couples reward-transfer revert with interest-transfer revert; using it for the funding call is wrong. Direct calls with separate try/catch boundaries are required.

Astra §2: "a selected interest-only variant must explicitly use YT's true/false flags and retain separate incentive-collection obligations; it must not silently catch or omit failed required reward collection."

Also correct. My original §11 aligns. **No correction needed; this is a design choice.**

### 3.7 Market callable by whom and gauge reset effects

All four agree:
- `market.redeemRewards(user)` is permissionless.
- Anyone can call it for the hook.
- The gauge controller resets `lastBalance` on `_redeemExternalReward` (Astra §5: `lastBalance = actualMarketRewardBalance` after the external redeem). This is a one-per-block cap.
- The hook's call resets the gauge's `lastBalance`, but the hook is the recipient. Third-party calls also reset (so subsequent callers don't double-claim).

**Side effect**: a third-party force-claim on the market resets the gauge controller's `lastBalance`. If the hook plans to claim later in the same block, the gauge controller may have already been updated, and the hook's claim returns 0.

This is the **same-block `lastBalance` reset issue** that affects the market incentive path. **Astra §5 and Grok §7 cover this.** My original §13.2 covers it.

**No correction needed.**

### 3.8 Upstream reward failure in interest-only path

If the hook calls `YT.redeemDueInterestAndRewards(hook, true, false)`:
- `redeemInterest = true`, `redeemRewards = false`.
- The body skips `_doTransferOutRewards` (lines 178–184 only run on `redeemRewards == true`).
- Only `_distributeInterest` and `_doTransferOutInterest` run.
- No reward-transfer revert can occur.

**This is the structural reason for the recommendation.** Verified in `PendleYieldToken.sol:166–193`. All four agree.

**No correction needed.**

### 3.9 Same-token reward absence conditional on actual identities

- For the verified SY (`PendleStakedNetSY`), `getRewardTokens()` returns `[]` (verified `E:309–333`).
- For the local YT, `PendleYieldToken.getRewardTokens()` delegates to `SY.getRewardTokens()` (`PendleYieldToken.sol:417–419`). So local YT reward list = empty.
- For the local market, `PendleGauge._getRewardTokens()` extends with `PENDLE` (`PendleGauge.sol:102–106`). So local market reward list = `[PENDLE]`.
- **The local reference has no SY-denominated reward token.** PENDLE is a separate token.

**But**: a deployed configuration might have a non-empty `SY.getRewardTokens()`. **All four agree**: do not invent blanket SY-incentive eligibility; verify token identities.

Kimi §2: "Same-token incentive case: none in this source. No SY-denominated incentive stream exists for this compilation, so there is no interest-token/incentive collision to adjudicate; no blanket same-token eligibility is inferred. If a different configured SY ever lists reward tokens, that is a separate G1 finding, not this source."

**No correction needed.**

### 3.10 PY-index ratchet vs claim valuation-neutral — same caveat as §3.1

Grok §4.1: "On the verified SY, `exchangeRate()` is `Ip * 1e9` and `Ip` is the one-step view projection... A claim does not advance the NetNet epoch. It can store a Pendle PY index based on a projected rate that the committed `sNet.index()` has not yet realized."

Correct. **No correction needed.**

### 3.11 YTv1 vs YTv2 — Kimi is correct, others should adopt this gap

Kimi §10 gap 1 flags the YTv1 vs YTv2 distinction. The local tree has only YTv1; YTv2 has a different `userInterest` shape (`lastInterestIndex`). **The deployed YT may be YTv2 with a different calculation.** This is a real G1 gap.

**My original did not flag it; adopting Kimi's framing.**

### 3.12 Net claimable C — NET-of-fee (not gross/stale accrued)

All four agree `C` should be **NET of the live factory interest fee**, computed from the source's formula plus the current index delta, not from `userInterest[user].accrued` alone (which is stale and gross).

Grok §4.2: "The view `userInterest(user)` returns the **stored** index and accrued. It does not include `pending`. A preview that reads only `accrued` understates `C` whenever `prevIndex != 0` and `currentIndex > prevIndex`."

Astra §3: "The public `userInterest` value alone is stale accrued storage, not net claimable. C must include the current incremental floor and current factory fee, after current balance/transfer checkpoints."

Kimi §3: "The C estimate must therefore be net-of-fee per (series, YT), or gross with the fee reconciled at claim time; mixing the two double-counts or overstates C."

My original §8.2 stated this. **All four agree: C is NET of fee, including current index delta.** My original retained this.

### 3.13 Claim trigger `H < d` (not `H+C < d`) — all four agree

Astra §8: "If H≥d, **no funding claim**."
Grok §6.2: "If H >= d, do not claim."
Kimi §6.3: "trigger is H<d only."

All four agree. **No correction needed.**

### 3.14 Clearing only settled source, not all remaining C — all four agree

Astra §8: "Do not write `C1=C0-r` merely because r was received."
Grok §6.1 step 5: "C := 0 for this YT interest. Do not keep the old `C`."
Kimi §5: "C_YT ← C_YT − (c + f) (once)."

All four agree: C is reduced by the extinguished amount (c + f), not the received amount (c). My original §2.4 adopts Astra's framing. **No correction needed.**

## 4. Source mapping resolved vs ( source composition pending) vs G1

### 4.1 Source mapping (resolved)

- Entrypoint signatures, caller/recipient rules, fee formulas, accrual formulas (with W factor).
- `_pyIndexCurrent` cache semantics, post-expiry freeze, first-touch initialization.
- YT transfer checkpoint effects on interest/reward.
- Force-claim by third party clears source accrued and pays net to user.
- Claim does not advance NetNet epoch.
- Router batch vs direct calls; bundling couples interest with reward transfers.
- Same-token incentive absence in this binding (verified).
- Local-reference fact: market does not hold YT.

### 4.2 Source composition (pending — engineering/plan work)

- Hook-side custody of SY ERC20 (hook vs SY proxy as canonical receiver). PRD does not pin this.
- Per-series ledger reconciliation after force-claim.
- Hook-side `redeemRewards=false` isolation with separate `market.redeemRewards` try/catch.
- Per-YT C aggregation across historical/retained series.
- Indexed-time-chronology for cross-block PY index updates.
- Provider sampling strategy (one-whole-SY sample q=1e18 vs sub-wei sample).

### 4.3 G1 (deployed evidence — explicitly unfinished)

- Deployed YT version (V1 vs V2 with different `userInterest` shape).
- Factory `interestFeeRate`, `rewardFeeRate`, `treasury`.
- `doCacheIndexSameBlock` for the configured YT.
- Configured YT/market addresses.
- Deployed `IStakedNetStaking(staking).stake/unstake/rebase` behavior and whether it matches the local reference.
- Deployed `_syncedIndex()` parity with deployed sNet index.
- Gauge controller address, PENDLE token identity, vePENDLE presence.
- Actual reward token list on the deployed SY/market.
- Whether the deployed market escrows YT.
- Live `userInterest[hook]`, `userReward`, `activeBalance` state.

## 5. Final exact safe call sequence (MiniMax M3 synthesis)

This sequence combines the four originals' consensus. It is the planning-level hook behavior for the ordinary `H < d` NET/sNET output path. **Not** executed here; **not** a deployment claim.

### 5.1 Pre-conditions and bookkeeping

1. Authenticate caller/operator/token/route/deadline; protect cross-component callback phase.
2. Capture supported public pretransfer credit BEFORE sync that would erase it: `available = max(raw − booked, 0)` (L2, resolved; not reopened). Reserve any caller-declared credit.
3. Reconcile prior force-claims: detect unbooked surplus (raw − booked > 0 with recent `RedeemInterest`/`RedeemRewards` events for hook on the YT), book the residual to `H`, and clear any now-stale `C` for that YT (the source's `userInterest[hook].accrued` is zero post-force-claim).
4. Settle required DETF processed-epoch expansion + TWAP capture/check; checkpoint/store synthetic readiness before any price-changing operation.
5. Construct coherent projected state after all pre-steps.

### 5.2 Quote d and eligibility

6. Quote `y` in selected pricing coordinate (NET/sNET) using existing Weighted helper/native wrapper; one fee gross-up; NET pricing is PLP/YT-derived; sNET pricing uses the validated provider.
7. Independently compute raw SY debit `d` from the actual final-delivery hops and the SY branch inverse: `d = ceil(y * 1e18 / I_branch)` with forward check. Use `I_branch = _syncedIndex()` for NET, `I_branch = IStakedNet(sNet).index()` for sNET.
8. Compute eligible `H` (recognized held SY, booked; exclude fee payables, exclusive principal, transient Keep-YT, allocated principal-exit SY, public-surplus L2 credit already reserved). Compute eligible `C` as net-of-fee per YT, including the current index delta:
  ```text
  for each configured YT, in a stable order:
    if prev == 0 or current == prev: pending = 0
    else: pending = floor( YT.balanceOf(hook) * (current - prev) * 1e18 / (prev * current) )
    gross_i = userInterest(hook).accrued + pending
    fee_i = floor(gross_i * interestFeeRate / 1e18)
    net_i = gross_i - fee_i
  C = Σ net_i   (across all configured active + retained historical series)
  ```
  Post-expiry: `current = postExpiry.firstPYIndex`; do NOT add later `exchangeRate` growth.
  Same-block cache: call `pyIndexCurrent()` (or trigger a claim) once per block to materialize. Subsequent same-block claims see cached value.
9. Check `d < H + C` (positive remainder guaranteed by `≥ 1` raw SY unit). If `H ≥ d`, no funding claim. If `H = d` and `C ≥ 1`, valid. If `H = d` and `C = 0`, revert (no remainder).

### 5.3 Claim phase (only when `H < d`)

10. Call **direct** `YT.redeemDueInterestAndRewards(hook, true, false)` for each configured active + retained historical YT (in a stable order). Do **NOT** catch this. Do **NOT** use the router batch. Do **NOT** set `redeemRewards=true` on this call. Each call pays net SY to hook; pays factory fee to factory treasury.
11. Measure actual SY receipt by `SY.balanceOf(hook)` delta across the claim window (excluding pre-transfer reserved credit and other booked balances). `c_i = balanceAfter_i − balanceBefore_i`. If `c_i < net_i` (short fee-floor or receipt), revert entire route.
12. Update ledger per YT: `H ← H + c_i`; `C_i ← 0` for that YT (the source cleared `userInterest[hook].accrued`; the `fee_i` portion is lost to treasury; new `pending` is zero since claim updated `_pyIndexStored`).
13. After all YT interest claims: aggregate `H' = H + Σ c_i`; `C' = Σ new_pending` (typically 0).

### 5.4 Reward collection (separately, best-effort isolated)

14. Separately call `YT.redeemDueInterestAndRewards(hook, false, true)` and/or `market.redeemRewards(hook)` in **dedicated try/catch** boundaries. Each pays reward tokens to hook. Forward non-SY tokens to current `feeTo()` under the selected best-effort exception. Failed forwarding retains the excluded payable.
15. **No retry solver. No second claim. No `redeemPY`. No LP burn.**

### 5.5 Redemption (per plan v0.8 §6.5.5 step 6)

16. Re-check `H' ≥ d` and `H' + C' − d ≥ 1`. If the claim still leaves the route short (fee variance, stale cache, post-expiry freeze), revert entire route (including the claim). No retry; no PLP/YT liquidation.
17. Call `SY.redeem(receiver, d, tokenOut, minTokenOut, false)` from hook-held shares (`false` burns hook-held shares, not SY-owned).
18. Measure final NET or sNET delta at receiver; revert if `received < y` (exact-out) or `received < minOut` (exact-in). EVM rollback reverts all preceding steps (claim, transfer, ledger).
19. Recompute affected state after the redemption:
   - NET branch: `_redeem(net)` calls `unstake` which may advance one epoch. If `_syncedIndex` actually advanced (one overdue epoch committed), recompute `C` for subsequent same-tx operations.
   - sNET branch: `_redeem(sNet)` does NOT call staking. `I_branch` unchanged for the rest of the tx.
20. `H'' = H' − d`. `C''` may include a new pending if a stake/unstake advanced the index. Check `H'' + C'' ≥ 1`.

### 5.6 Failure scope and refund

21. Refund any unused exact-input maximum (per plan §6.5.4). Full expected-set sync. Emit typed events.
22. Atomic rollback on any required failure: input pull, claim, burn, redeem, ledger, observation, fee-forwarding (if caught). **Only** outgoing fee-reward forwarding to `feeTo()` is the best-effort exception. Factory fee transfer inside claim is NOT best-effort.

## 6. Numeric vectors (synthesis, planned not executed)

`ONE = 1e18`. `WAD = 1e18`. Native PY index and gross SY shares are 18-decimal. Indexes/fees are 18-decimal.

| Case | Inputs | Result | Notes |
|---|---|---|---|
| Accrual dust | `Y=1e18, prev=1e18, cur=1e18+1` | `pending = floor(1e18*1*1e18/(1e18*(1e18+1))) = floor(1e36/(1e36+1e18)) = floor(1 − 1e-18) = 0` | nothing accrues; index still updates |
| Pending interest | `Y=1e18, prev=1e18, cur=1.1e18` | `pending = floor(1e18*1e17*1e18/(1e18*1.1e18)) = floor(1e17/1.1) = 90909090909090909` | Grok's vector; matches source |
| Fee 1% | `gross=1e24, f=1e17` | `fee = floor(1e24*1e17/1e18) = 1e23`, `net = 9e23` | corrected from my original (was 1e22 / 9.9e23) |
| Fee 0% | `gross=g, f=0` | `fee = 0`, `net = g` | |
| Fee sub-wei | `gross=99, f=1e17` | `fee = floor(99*1e17/1e18) = floor(0.99) = 0`, `net = 99` | hook gets full gross; treasury gets 0 |
| Fee boundary wei | `gross=100, f=1e17` | `fee = 1`, `net = 99` | 100*0.01 = 1 exactly → floor = 1 |
| First-touch | `prev=0, Y>0` | `pending = 0`; index initialized; no retroactive accrual | |
| Same-block cache hit | `doCacheIndexSameBlock=true`, prior `_pyIndexCurrent` this block | `currentIndex = _pyIndexStored`; no `exchangeRate()` call | hook should `pyIndexCurrent()` once/block |
| Post-expiry | `firstPYIndex=2e18, cur=3e18, prev=1e18, Y=1000` | `pending = floor(1000*1e18*1e18/(1e18*2e18)) = 5e20` | uses frozen index; no live `exchangeRate` |
| Transfer crystallization | `Y=1000, j=1e18, k=2e18` then transfer out | sender accrues `5e20` before transfer; recipient starts fresh; sender retains `5e20` claim despite zero YT balance | per `PendleYieldToken.sol:499–503` |
| Claim 1 | `H=50, C=0, d=100`; `acc=500, fee=1%`; `c = 500 - 5 = 495` | claim once; `H' = 545, C' = 0`; `H' + C' - d = 445 ≥ 1`; success | |
| Claim 2 (shortfall) | `H=50, C=0, d=100`; `acc=50, fee=1%`; `c = 50 - 0 = 50` (fee rounds to 0) | `H' = 100, C' = 0`; `H' - d = 0`; revert (no remainder) | full rollback |
| Claim 3 (over-claim) | `H=80, C=0, d=100`; `acc=500, fee=1%`; `c = 500 - 5 = 495` | `H' = 575, C' = 0`; `H' - d = 475 ≥ 1`; success; excess remains | excess stays booked `H` |
| Force-claim pre-route | third party settled `acc=500, fee=1%` for hook before hook's tx | hook's raw SY increased 495; route book: `H += 495`, `C_YT = 0`; hook's own claim returns 0; no double count | per source reset |
| Reward failure in interest-only path | `redeemInterest=true, redeemRewards=false` | reward-transfer revert cannot occur (skipped in body) | structural isolation |
| Reward failure in `true,true` | `redeemInterest=true, redeemRewards=true` | reward revert rolls back interest | structural coupling; do not use |
| Same-block gauge `lastBalance` reset | third party calls `market.redeemRewards(hook)` before hook's tx | gauge `lastBalance` updated; hook's later call may return 0; per-block cap | `RewardManager.sol:38–49` |
| Net claimable from stale `accrued` | `userInterest(hook).accrued = 500`, `prev = current` | `C = 500 - fee` only (no pending) | stale-only view understates C when `prev != current` |
| Empty YT rewards | verified SY `getRewardTokens() == []` | YT reward loop empty; market list = `[PENDLE]` | conditional on identities |
| Force-claimed pretransfer consumed | raw 100, booked 80, force-claim deposited 20 | L2 surplus `max(100-80,0)=20` available to next supported pretransfer caller; if consumed, not also `H` and not also `C` | L2 once-only |

## 7. Counterarguments addressed

- "Market redeemRewards pays SY interest": **false** for this reference/empty-SY-reward binding; market rewards are LP incentive tokens (PENDLE etc.), not SY interest.
- "userInterest.accrued is all claimable": **false**; it's stale gross accrued; C must include current `pending = floor(Y * (cur − prev) * 1e18 / (prev * cur))` and net of `interestFeeRate`.
- "exchangeRate update rebases NetNet": **false**; `exchangeRate()` is a view that reads `_syncedIndex()`; it does NOT call `stake/unstake/rebase`.
- "Force-claim protects origin": **conflicts** with selected public pretransfer policy (L2 resolved).
- "safeTransfer/minimum return proves net receipt": **false** for funding; `minTokenOut` is nominal; balance-delta required.
- "Best-effort forwarding permits swallowing upstream failure": **false**; factory fee transfer is upstream and required; only hook's downstream forwarding is best-effort.
- "v1 vs v2 YT is the same": **unknown**; YTv1 vs YTv2 is a real G1 gap with different `userInterest` shape.

## 8. Confidence summary

| Topic | Confidence | Notes |
|---|---|---|
| Entrypoint signatures, caller/recipient rules, fee formula (with W factor), first-touch, post-expiry freeze | High | All four agree; verified source |
| Accrual formula with W factor | High | Verified source `divDown` includes 1e18 multiplier |
| `H < d` trigger, `d < H+C` precondition | High | All four agree |
| `C` is net-of-fee (not gross/stale) | High | All four agree |
| Force-claim clears source, not double-counted | High | All four agree |
| Same-token incentive absence for this binding | High | Verified SY + local reference |
| Local reference market does NOT hold YT | High | `PendleMarketV3.sol:40–42` |
| Claim does NOT advance NetNet epoch | High | Verified source call graph |
| YTv1 vs YTv2 distinction (different `userInterest` shape) | High (Kimi's flagging) | **G1 evidence required** |
| Market-held YT in deployed implementation | Low | **G1 evidence required** |
| Same-block gauge `lastBalance` cap on market rewards | High | `RewardManager.sol:38–49` |
| Deployed YT/market addresses, factory fee rates, treasury, `doCacheIndexSameBlock` | Low | **G1 evidence required** |

## 9. Saved cross-review path

`docs/research/netnet-pendle-claim-funding/minimax-cross-review.md` (this file).

Stop after this cross-review. No implementation, no shell/tests, no peer cross-review reading, no plan/tracker edits.