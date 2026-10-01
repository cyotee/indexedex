# Grok cross-review — Pendle claim funding

| Field | Value |
| --- | --- |
| Researcher | Grok (`xai/grok-4.7`) |
| Access date | 2026-09-28 |
| Inputs | Own original unchanged. Untrusted originals: `astra-original.md`, `minimax-original.md` (through line 449; later sections not needed once the disputed formulas were checked), `kimi-original.md`. No peer cross-reviews |
| Source re-check | `InterestManagerYT.sol:43–79`, `PMath.sol:34–52`, `PendleYieldToken.sol:166–193,392–407,417–419,475–503`, `PendleGauge.sol:43–48,102–106`, `RewardManager.sol:61–76`, `ActionMiscV3.sol:67–84`, `IPInterestManagerYTV2.sol:5–8` |
| Closure | Local YTv1 interest math and caller/recipient rules are mapped. Deployed YT version and live factory/gauge state are not. Not L3 or G1 closure |

---

## 1. Accrual formula — WAD is required

**Source.** `interestFromYT = (principal * (currentIndex - prevIndex)).divDown(prevIndex * currentIndex)` (`InterestManagerYT.sol:76`). `divDown(a,b) = floor(a * 1e18 / b)` (`PMath.sol:48–52`). So:

```text
pending = floor(b * (k - j) * 1e18 / (j * k))
```

when `j != 0` and `j != k`. This is one floor, not `floor(b*1e18/j) - floor(b*1e18/k)`.

**Retain Grok. Agree Astra §3.** Astra's vector `b=1000, j=1e18, k=2e18` is `floor(1000 * 1e18 * 1e18 / (1e18 * 2e18)) = 500`. That matches the source.

**Object Kimi §3 and §8.** Kimi writes `floor(principal * (cur - prev) / (prev * cur))` and `floor(Y * (Iproj - idx) / (idx * Iproj))`, omitting `* 1e18`. For the same inputs that expression is `floor(1000 / 2e18) = 0`, not 500. The missing WAD is not a rounding variant. It is the wrong function. Kimi's dust vector `Y=1e18, prev=1e18, cur=1e18+1 → 0` happens to be zero either way; it does not prove the omitted factor.

**First index.** `j == 0` sets the index and returns. No retrospective interest (`InterestManagerYT.sol:69–71`). All four agree on that interest rule. Do not copy it onto rewards: reward `userIndex == 0` is treated as `1` and can accrue (`RewardManagerAbstract.sol:54–61`). Grok's original stated the interest rule and did not conflate the two. Retain that split.

---

## 2. Fee is gross minus floor(fee), not floor(net factor)

**Source.** `fee = interestPreFee.mulDown(feeRate) = floor(gross * f / 1e18)`; `net = gross - fee` (`InterestManagerYT.sol:50–54`, `PMath.sol:34–38`).

`floor(gross * (1e18 - f) / 1e18)` is a different integer. Astra's counterexample holds: `gross=19`, `f=0.05e18` gives `fee=floor(0.95)=0`, `net=19`. The other expression gives 18.

**Retain Grok §6.1.** Adopt Astra's 19/20 fee-floor vectors as the check. Grok's 10% illustration (`90909090909090909` gross, fee `9090909090909090`, net `81818181818181819`) is the same rule, not a live rate.

**Object MiniMax.** `interestPreFee * (1 - interestFeeRate)` is the continuous form, not the source. MiniMax §6.4 also inverts the dust rule: if `gross * f < 1e18`, `fee=0` and the **user** receives `gross`. The treasury does not take the whole amount. `gross=1`, `f=1e17` pays the user 1.

---

## 3. `C` is net of fee, including pending; clear only the settled source

**Retain Grok.** `C` for a series is stored accrued plus pending, then one fee floor on that gross. `userInterest.accrued` alone is stale. It omits pending and is pre-fee.

**Agree Astra §8.** After a claim of one YT:

```text
H1 = H0 + measured c
C1 = C_other
```

Do not write `C1 = C0 - c` or `C1 = C0 - (c+f)`. The YT zeros that user's accrued even if the measured delta is short (`InterestManagerYT.sol:50–51`). A short receipt does not leave a residual receivable. It fails the remainder test and reverts the route.

**Correction of Grok's shorthand.** The single-series example `C' = 0` is only that series. Other validated YTs stay in `C`. Grok's step "C := 0 for this YT interest" already said that; the global equation in the example must not be read as clearing every series.

**Object Kimi §5/§8.** The post-claim line `C_YT ← C_YT - (c+f)` keeps a phantom receivable when `c` is short, and it mixes a net `C` with a gross subtraction. The "net-of-fee convention" label does not repair the missing `1e18` in the pending term.

**Object MiniMax §8.2–8.3.** Quoting `C = userInterest.accrued` drops pending and the fee floor. Step 3 triggers a claim when `H+C-d < 1`. That is not the rule.

---

## 4. Trigger is `H < d`, not `H+C < d`

**Retain Grok, Astra, Kimi on the trigger.** Plan v0.8 §6.5.5: if `H >= d`, do not claim for funding. `H = d` and remaining eligible `C >= 1` is valid. `H = d` and `C = 0` fails `d < H+C`. If `H < d`, claim even when `H+C-d` is already at least 1, because the shares are not yet held.

| State | Action |
| --- | --- |
| `H=100`, `C=1`, `d=100` | no claim; remainder is the receivable |
| `H=99`, `C=10`, `d=100` | **claim**. `H+C-d=9` does not waive it |
| `H=100`, `C=0`, `d=100` | revert; no claim |

**Object MiniMax §8.3 step 3 and §10.** "If `H+C-d >= 1`, no claim" skips the required pull in the `H=99, C=10, d=100` row. MiniMax also sets `H` from `balanceOf(hook) - booked` in that same step, which is the L2 surplus shape. `H` is recognized eligible booked SY, not raw minus booked.

---

## 5. Force-claim, L2, and donated market YT

**Retain Grok. Agree Astra.** Snapshot supported pretransfer credit **before** booking a prior force-claim. Unbooked SY from `redeemDueInterestAndRewards(hook, …)` is `max(raw-booked, 0)` until booked. The caller of that claim cannot redirect it, but the next eligible pretransfer caller can consume it. That is L2, not a provenance defect to close. Units already credited as pretransfer are not also `H` or `C`. The hook's own in-transaction claim is booked to `H` and clears only that series.

**Object Kimi §5.** Booking the force-claim "before computing available credit" appropriates L2 surplus into `H`. Do not do that.

**Correction of Grok.** Grok's original said this market's reserves are PT/SY and that market-held YT is not an applicable interest path. The reserve fields are still PT/SY (`PendleMarketV3` storage). That does **not** prove `YT.balanceOf(market) == 0`. A transfer or donation can make `user=market` accrue interest. Anyone may claim that interest **to the market**. `skim` sends excess SY/PT over reserves to the market treasury (`PendleMarketV3.sol:224–231`). It does not pay that SY to the hook. **Do not put market-owned YT interest in hook `C`.** Kimi's "market-held YT does not exist" is too strong. Astra §5 is the accurate statement. No deployed proof that the balance is zero.

Market `redeemRewards` is incentives, not LP principal. It does not burn LP. Gauge order is distribute on the **current** `activeBalance`, then refresh it (`PendleGauge.sol:43–46`). A claim is not an `h/H` reserve exit. If `totalActiveSupply == 0`, `RewardManager` still absorbs `selfBalance - lastBalance` into `lastBalance` and does not increment the index (`RewardManager.sol:43–49`). Those units are not retroactive hook income. Market payouts use `RewardManager._doTransferOutRewards`, which has **no** factory fee. The YT reward-fee override does not apply. MiniMax's "market pays less factory rewardFee" is wrong for this path.

---

## 6. Batch flags, who may call, interest-only versus all rewards

**Router YT loop always passes `true, true`** (`ActionMiscV3.sol:77–78`). There is no boolean argument. A batch that includes `yts` cannot be interest-only. It also calls `market.redeemRewards(user)` for each market. Anyone may call the YT, the market, or the router. Proceeds go to `user`, not `msg.sender`.

**Interest-only is a real funding call and is not a partial-shortfall selector.** `YT.redeemDueInterestAndRewards(hook, true, false)` still settles **all** accrued interest. It does not transfer YT reward tokens. On this verified SY, `getRewardTokens()` is empty, so the reward-index update returns an empty list and does not transfer incentives (`PendleYieldToken.sol:417–419, 486–496`; `RewardManagerAbstract.sol:35–37`). `(true, true)` on that YT alone does not create a reward transfer. It is not harmless once the router also calls the market.

**PRD collection is not satisfied by skipping incentives.** §13 still requires holding interest and forwarding other attributable rewards. That is a second call, not a flag on the funding pull:

1. Required SY funding, uncaught: `YT(hook, true, false)`.
2. If this operation's claim phase includes incentive collection, uncaught: `market.redeemRewards(hook)`, and `YT(hook, false, true)` only when that YT's reward list is non-empty.
3. Caught: only the hook's later transfer of received non-interest tokens to current `feeTo`.

**Correction of Grok.** The original isolated "non-interest collection" too broadly. A revert inside `market.redeemRewards` or inside YT reward transfer is upstream. It is not the §13 forwarding exception. If that call is in the same transaction and not caught, it rolls back the interest claim. Catching it would omit a required collection failure. Do not catch it. Do not put it in the same uncaught frame as interest if the intent is to keep a PENDLE failure from undoing a needed SY pull — that split is exactly why interest-only is the funding call and incentive collection is a separate uncaught call **after** interest is booked only if the implementation can catch the second call. If both are required and uncaught, Astra is right that a PENDLE failure reverts the earlier interest claim. Grok now states that explicitly. The selected exception remains hook→`feeTo` only.

**Upstream reward failure on the interest-only path.** For this empty reward list, `redeemRewards=false` does not transfer reward tokens. `getRewardTokens()` is still read. A non-empty deployed list can make `rewardIndexesCurrent()` revert before interest is paid, even with `redeemRewards=false` (`PendleYieldToken.sol:486–495` calls it whenever not expired). That revert is required-claim failure. It is not forwarding isolation. G1 must read the live list.

**Same-token absence is conditional.** Empty SY rewards plus local gauge append of `PENDLE` do not prove `controller.pendle() != SY`. If they are equal, `RewardManager`'s `selfBalance - lastBalance` treats reserve SY as reward inventory (Astra §6). Do not declare the collision absent until those addresses are read. No blanket eligibility is added.

---

## 7. PY ratchet, cache, and the false neutrality claim

**Source.** Before expiry, `k = max(SY.exchangeRate(), stored)` unless `doCacheIndexSameBlock` and the block was already updated, in which case `k = stored` and `exchangeRate` is not read (`PendleYieldToken.sol:397–405`). After expiry, `k = firstPYIndex` (`:392–395`). The verified SY `exchangeRate` is a view of one-step `_syncedIndex() * 1e9`. The claim does not call NetNet `stake`/`unstake`/`rebase`.

**Retain Grok.** NET redeem after the claim still uses `_syncedIndex` and may advance one epoch inside `unstake`. sNET redeem still uses current `index()`. Do not use the PY index as the redemption index.

**Object Kimi §6.1.** "The claim does not change the pricing vector" is false when the claim's `k` is not the index used to quote `C`:

- Same-block cache can pay at an older `k` after `exchangeRate` has risen, so `c` is below a fresh-rate `C`.
- `max` can keep a stored index above a later `exchangeRate` read. This SY's index is not expected to fall if the mirror holds, but the YT source still ratchets. A quote that uses raw `exchangeRate` instead of the cached/max `k` mis-states `C`.
- Expiry freezes `firstPYIndex`. Later NetNet epochs do not become user `C`. Kimi's "nothing is forfeited" across multiple overdue epochs is too strong if expiry freezes before those epochs are projected.

Recompute `H`, `C`, and `d` after the claim. Do not assume `R[sNET]` is invariant. Moving a correctly measured `c` from `C` to `H` preserves the **share sum** only when `c` equals the `C` that was in the quote and no other series changes. That equality is a check, not an assumption.

---

## 8. YTv1 versus YTv2

**Correction, shared with Kimi §10.** The formulas above are the local `PendleYieldToken` / `InterestManagerYT` body (`userInterest` returns index and accrued). `IPInterestManagerYTV2.userInterest` returns `(lastInterestIndex, accruedInterest, lastPYIndex)` (`IPInterestManagerYTV2.sol:5–8`). No local V2 implementation was found. The configured chain-4663 YT is **unknown**. Do not apply the V1 `divDown` expression to a V2 binding. Grok's original mapped V1 and did not say the deployed YT was proved V1. State the gap explicitly. Astra's "local reference, not deployed binding" covers the same limit.

---

## 9. Final safe call sequence

No new fee, no percent floor, no ordinary PLP/YT liquidation, no second Weighted fee, no catch of a required interest failure, no L2 provenance gate.

1. Authenticate. Capture supported pretransfer credit from `max(raw-booked, 0)` **before** any sync or force-claim booking.
2. Quote native `y` with the existing Weighted helper, fee once. Derive raw `d` from plan §6.5.3 at the redeem-branch index. NET price stays PLP/YT. sNET price stays the provider.
3. For each validated hook-owned YT, compute net `C` with the WAD pending formula and one `floor(gross * f / 1e18)`, using the `k` that the claim will use (cache, `max(exchangeRate, stored)`, or frozen expiry index). Exclude market-address YT, payables, principal-exit SY, and L2 surplus already snapshotted.
4. Require `d < H+C`. If `H >= d`, do not call YT for funding.
5. If `H < d`, call direct `YT.redeemDueInterestAndRewards(hook, true, false)`. Do not use the router. Do not pass `true, true` on this call. Do not catch it.
6. Measure SY delta `c` outside the pretransfer snapshot. `H += c`. Clear **only** that YT's interest entitlement. Leave `C_other`. If native accrued is now zero, do not keep `expected - c` as `C`.
7. Recompute branch `d`. The claim did not advance NetNet. Require `H >= d` and `H+C-d >= 1`. Otherwise revert the whole route, including the claim. No `redeemPY`, `skim`, or LP burn.
8. If this phase also collects incentives, call `market.redeemRewards(hook)` uncaught, and `YT(hook, false, true)` only if that reward list is non-empty. A revert here is upstream. It is not the forwarding exception. On this SY the YT reward list is empty, so step 8's YT reward call is unnecessary until G1 shows otherwise.
9. Forward received non-interest tokens to current `feeTo`. **Only this transfer is caught.** A failure keeps the excluded payable.
10. `SY.redeem(receiver, d, tokenOut, minNominal, false)` from hook-held shares. Measure the final NET/sNET delta. Exact-out still delivers the required net amount or reverts. Debit `d`. Require post-redeem `H+C >= 1`. Refund, then sync.

---

## 10. Numeric vectors (specified, not run)

`W = 1e18`. Fee rates are illustrations, not live factory values.

| Vector | Result |
| --- | --- |
| `b=1000, j=W, k=2W, A=0, f=0.1W` | pending `500`; fee `50`; net `450`. Not Kimi's omitted-WAD `0` |
| `gross=19, f=0.05W` | fee `0`, net `19`. Not `floor(19*0.95)=18` |
| `gross=20, f=0.05W` | fee `1`, net `19` |
| `gross=1, f=0.1W` | fee `0`, user receives `1`. Treasury does not take it |
| `j=0, b>0` | index set, pending `0` |
| `H=99, C=10, d=100` | claim. Do not skip because `H+C-d=9` |
| `H=100, C=1, d=100` | no funding claim |
| `H=100, C=0, d=100` | revert, no claim |
| Claim of series A, series B remains | clear A only; `C1 = C_B` |
| `expected net 450`, measured `449`, accrued cleared | `C` for that YT is `0`, not `1`; remainder test fails; full revert |
| Force-claim `450` still unbooked at pretransfer snapshot | L2 credit. Not auto-booked into `H` before that snapshot |
| YT donated to market | not hook `C`. Claim pays the market. `skim` pays treasury, not LPs |
| Router `yts=[YT]` | always `true, true`, plus market loop if `markets` is non-empty |
| Claim then read NetNet epoch end | unchanged. Later NET `unstake` may add one length |

---

## 11. What is resolved, and what is still a gap

| Item | Status |
| --- | --- |
| Local YTv1 pending formula, fee floor, first-index rule, `H<d` trigger, per-series clear, caller/recipient, router `true,true` | **Mapped.** Grok/Astra agree. Kimi's omitted WAD and MiniMax's trigger/fee/H definition do not survive the source |
| Claim does not call NetNet stake/unstake/rebase | **Mapped** for this local graph plus the verified SY `exchangeRate` view. Conditional on those bindings |
| Market reserves versus donated YT; gauge distribute-then-refresh; no market fee in `RewardManager` | **Mapped** locally. Donated balance is unobserved |
| Interest-only versus full reward collection; upstream versus `feeTo` | **Specified** as the sequence in §9. Not executed |
| Deployed YTv1 vs YTv2, fee rate, treasury, cache flag, `PENDLE != SY`, gauge controller, market code | **G1, open** |
| Owned-HLP inverse, exact-output `I>1e18` residual, tests | **Unfinished composition.** Not closed by this claim map |

**Grok claims retained:** WAD pending formula, net-of-fee `C`, `H<d`, direct `true,false` funding call, no router for that call, no NetNet advance, L2 snapshot before booking, no catch of the interest call.

**Grok claims corrected:** market-held YT can exist by transfer even though reserves are not YT; do not catch incentive collection if that call is required; same-token absence is conditional on addresses; V1 mapping is not a deployed-version proof; single-series `C'=0` must not clear other series.

**Confidence:** high on the local arithmetic corrections. Medium on the §9 split between uncaught incentive collection and caught `feeTo` forwarding, because the PRD requires both collection and forwarding isolation and a single uncaught frame cannot have both. Low on deployed YT version and live fee/gauge state. No test or economic-soundness claim.
