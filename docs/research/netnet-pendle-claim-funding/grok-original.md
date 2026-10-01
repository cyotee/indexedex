# Grok original — Pendle claim path when held SY is short

| Field | Value |
| --- | --- |
| Researcher | Grok (`xai/grok-4.7`), independent follow-up original |
| Access date | 2026-09-28 |
| Question | Map the actual Pendle market/YT claim path used when eligible held SY is insufficient, and compose it with plan v0.8 §6.5 SY redemption |
| Authority | PRD v0.33 §§6.2–6.3, §13; plan v0.8 §6.4–§6.5, especially §6.5.5 steps 4–7 and §6.5.7 claim row |
| Local Pendle | `lib/crane/contracts/protocols/perps/pendle/` inspected 2026-09-28. Pragmas `^0.8.17` on `PendleYieldToken.sol`, `InterestManagerYT.sol`, `PendleMarketV3.sol`, `PendleYieldContractFactory.sol`. No commit hash computed (no shell). **Not** a verified chain-4663 deployment |
| Verified SY | Compilation identity in plan §6.5 remains the candidate `PendleStakedNetSY` extract. Its `claimRewards` is empty. That does not prove the live YT/market bytecode |
| Context7 | Not called. No new external library/API documentation claim. Deployed V6 ABI is not inferred from docs |
| Not read | Other members' new originals or cross-reviews |
| Closure | This does **not** close L3 or G1 |

---

## 1. Evidence classes

**Fact (local Pendle source):** signatures, caller/recipient rules, interest formula, fee floor, reward transfer order, YT transfer checkpoint, market reward path, and that `pyIndexCurrent` reads `SY.exchangeRate()`.

**Fact (verified SY compilation, plan §6.5):** `PendleStakedNetSY.claimRewards` returns an empty array. `exchangeRate()` is a view of one-step `_syncedIndex()` times `1e9`. It does not call `stake`/`unstake`/`rebase`.

**Inference:** composing those two facts gives the chronology below **if** the bound YT is this local `PendleYieldToken` and its `SY` immutable is that proxy. That binding is not proved.

**Uncertainty:** chain-4663 YT/market implementation, `interestFeeRate`, `doCacheIndexSameBlock`, expiry, and whether a later market escrows YT. PRD §16.1's V6 factory addresses are publication pins, not this file's bytecode.

---

## 2. Entrypoints

### 2.1 Required interest claim — direct YT

```text
PendleYieldToken.redeemDueInterestAndRewards(address user, bool redeemInterest, bool redeemRewards)
  external nonReentrant updateData
  returns (uint256 interestOut, uint256[] memory rewardsOut)
```

`PendleYieldToken.sol:166–193`. Interface `IPYieldToken.sol:35`.

Anyone may call for any `user`. There is no `msg.sender == user` check. Interest is transferred to `user`, not to `msg.sender` (`InterestManagerYT.sol:43–57`). Rewards, if requested, are also transferred to `user` (`PendleYieldToken.sol:179`, receiver argument equals `user`).

Required funding call:

```text
YT.redeemDueInterestAndRewards(address(hook), true, false)
```

`true, false` updates reward indexes (`_updateAndDistributeRewards`) but does not transfer reward tokens. It then `_distributeInterest` and `_doTransferOutInterest`. Both flags false reverts `YCNothingToRedeem` (`:172`). Do not use that combination.

This call is not try/caught. If it reverts, the whole ordinary-output route reverts.

### 2.2 Router / batch — not the required funding call

```text
ActionMiscV3.redeemDueInterestAndRewards(
  address user,
  address[] calldata sys,
  address[] calldata yts,
  address[] calldata markets
) external
```

`ActionMiscV3.sol:67–84`; interface `IPActionMiscV3.sol:157–162`.

For each SY it calls `claimRewards(user)`. For each YT it calls `redeemDueInterestAndRewards(user, true, true)`. For each market it calls `redeemRewards(user)`. No amounts are returned. Recipient is still `user`. The router does not skim.

Do **not** use this batch for the required shortfall. `redeemRewards=true` plus `market.redeemRewards` couples PENDLE and any other reward-token transfer into the same revert domain as the interest transfer. A failed incentive transfer would then roll back required interest. That is the opposite of PRD §13's forwarding isolation.

### 2.3 Market LP rewards — not SY interest

```text
PendleMarketV3.redeemRewards(address user) external nonReentrant returns (uint256[] memory)
```

`PendleMarketV3.sol:237–238`, implemented by `PendleGauge._redeemRewards` (`PendleGauge.sol:43–47`): update rewards, update active balance, `_doTransferOutRewards(user, user)`.

Pays gauge/SY-reported reward tokens to `user`. It does not pay YT interest and does not transfer LP, PT, or the market's SY reserve. `skim` (`PendleMarketV3.sol:225–231`) sends excess PT/SY to the market treasury. Do not call `skim` or `redeemPY` to fund an ordinary output. Those are principal paths.

`readTokens` exposes SY, PT, and YT addresses. The market's reserves are PT and SY (`MarketStorage.totalPt/totalSy`). This local market does not hold YT for the LP. Hook-held YT is the interest source. Market-held YT is not an applicable path in this source. A deployed market that escrows YT is a G1 gap, not a second formula invented here.

### 2.4 What is not the shortfall API

| Call | Why it is not ordinary-output funding |
| --- | --- |
| `SY.claimRewards(user)` on the verified `PendleStakedNetSY` | Returns an empty array. Plan §6.5.5 step 4. YT `_redeemExternalReward` calls it (`PendleYieldToken.sol:475–476`) and receives nothing |
| `redeemPY` / `redeemPYMulti` | Burns PT/YT already transferred to the YT and pays **principal** SY (`:129–138, 317–339`). Position exit. Forbidden as an ordinary-output fallback |
| `redeemInterestAndRewardsPostExpiryForTreasury` | Only post-expiry. Pays treasury, not the hook (`:199–226`) |
| Router `exitPreExpToSy` / `exitPostExpToSy` | LP/PT/YT liquidation. Not the shortfall claim |

---

## 3. Interest versus incentives versus LP rights

| Right | Source | Token | Eligible SY budget `C`? | Destination |
| --- | --- | --- | --- | --- |
| Accrued YT interest | `userInterest[user].accrued` plus undistributed index delta | The YT's `SY` immutable | Yes, **net of interest fee**, once | `user` (the hook) |
| YT incentive rewards | `userReward[token][user]`, from `SY.getRewardTokens()` | Whatever that list is | No, unless a later G1 observation shows the token **is** the interest token | Hook first, then non-interest tokens to current `feeTo()` |
| Market/gauge rewards | `PendleGauge._getRewardTokens`: SY reward list, plus PENDLE if absent (`PendleGauge.sol:102–105`) | PENDLE and any SY reward tokens | No | Same forwarding rule. Not LP principal |
| LP SY/PT reserves | Market `totalSy`/`totalPt` | SY/PT inside the pool | No | Not withdrawn on `redeemRewards` |
| Post-expiry new interest | `postExpiry.totalSyInterestForTreasury` | SY | No | Treasury via the post-expiry function, not the hook |

**Same-token incentives.** PRD §13 holds interest-token incentive receipts and keeps them distinct from accrued YT interest. Spendability is conditional on an actual case. This verified SY's `getRewardTokens()` is empty, so the local YT reward loop has length 0 and the local market list is `[PENDLE]` unless the deployed SY reports tokens. **No SY-denominated incentive is present in the sources read.** Do not add a blanket rule that every SY receipt is eligible interest. If G1 finds a reward token equal to the configured SY, book it as retained incentive, not as `C`, and do not spend it on the ordinary route until that narrow case is classified.

---

## 4. Accrual, index, cache, expiry, fee

### 4.1 Index update

`redeemDueInterestAndRewards` uses `updateData` (`PendleYieldToken.sol:52–56, 166–169`): if expired, `_setPostExpiryData()`; after the body, `syReserve = SY.balanceOf(YT)`.

Interest index (`:392–407`):

```text
if expired: index = postExpiry.firstPYIndex
else: index = _pyIndexCurrent()
_pyIndexCurrent:
  if doCacheIndexSameBlock && pyIndexLastUpdatedBlock == block.number:
      return _pyIndexStored          // no exchangeRate read
  index128 = max(SY.exchangeRate(), _pyIndexStored) as uint128
  store index128 and block.number
```

On the verified SY, `exchangeRate()` is `Ip * 1e9` and `Ip` is the one-step **view** projection. This read does not call NetNet `stake`, `unstake`, or `rebase`. **A claim does not advance the NetNet epoch.** It can store a Pendle PY index based on a projected rate that the committed `sNet.index()` has not yet realized.

`doCacheIndexSameBlock` is an immutable set at YT creation (`:43, 75–81`). If true, a prior same-block update freezes the index for later claims in that block. G1 must read it. Do not assume every claim sees a fresh `exchangeRate()`.

### 4.2 User accrual and fee floor

`InterestManagerYT.sol:63–79, 43–57`. `PMath.divDown(a,b) = floor(a * 1e18 / b)` (`PMath.sol:48–52`). `mulDown(a,b) = floor(a * b / 1e18)` (`:34–38`).

For `user != 0` and `user != YT`:

```text
if prevIndex == currentIndex: no change
if prevIndex == 0: set index = currentIndex; accrued unchanged (no historical gift)
else:
  pending = floor( YT.balanceOf(user) * (currentIndex - prevIndex) * 1e18
                   / (prevIndex * currentIndex) )
  accrued = accrued + pending     // uint128; overflow reverts
  index = currentIndex
```

Transfer out:

```text
gross = userInterest[user].accrued
userInterest[user].accrued = 0
fee = floor(gross * interestFeeRate / 1e18)
net = gross - fee
SY.transfer(treasury, fee)    // zero amount is a no-op in TokenHelper
SY.transfer(user, net)
interestOut = net
```

`interestFeeRate` is factory storage, capped on set at `2e17` (`PendleYieldContractFactory.sol:72, 169–175`). The cap is not the live value. A quote must use the live rate. `userInterest(user)` (`IPInterestManagerYT.sol:7`) returns the **stored** index and accrued. It does not include `pending`. A preview that reads only `accrued` understates `C` whenever `prevIndex != 0` and `currentIndex > prevIndex`.

Post-expiry, `_getInterestIndex` sticks at `firstPYIndex`. Further exchange-rate growth is not user interest. New post-expiry SY interest is treasury inventory. A shortfall that depended on post-expiry growth is not fundable by this claim. Do not switch to `redeemPY`.

### 4.3 Reward fee, only if rewards are transferred

`PendleYieldToken.sol:443–472`: for each reward token, zero the user's accrued, `fee = floor(pre * rewardFeeRate / 1e18)`, transfer fee to treasury and net to `receiver`. If the YT's balance is short and external redeem is allowed, it calls `SY.claimRewards(YT)` once. On this SY that call pays nothing. A reward-token `transfer` revert reverts the whole YT call, including an interest transfer already executed in the same call. That is why the required call uses `redeemRewards=false`.

---

## 5. Hook-held YT, transfers, and force-claims

YT `_beforeTokenTransfer` (`PendleYieldToken.sol:499–503`) checkpoints rewards and interest for `from` and `to` before the balance moves. Accrued-but-unclaimed interest stays on the old address's `userInterest` slot. Future accrual follows the new holder from the then-current index. A first-time receiver with `prevIndex == 0` gets the current index and zero accrued.

Therefore:

- Hook-held YT is the principal in the formula. YT inside an LP is not, in this market.
- Transferring YT away does not transfer stored accrued interest. The hook can still be the `user` in a later claim for that stored amount.
- Transferring YT in does not import the sender's accrued interest.
- A third party may call `redeemDueInterestAndRewards(hook, true, false)` before the hook's route. That is a force-claim: `accrued` becomes 0 and net SY is sent to the hook. `C` for that YT is cleared. The SY is physically at the hook.

**L2, not reopened.** Until the hook books that receipt, raw minus booked is origin-independent public pretransfer credit, including a force-claim. Ordinary-output `H` is still the recognized eligible booked balance, not `max(raw-booked,0)`. Units a caller already took as pretransfer credit are not also `H` or `C`.

On the hook's own claim inside the route, the received SY is a protocol-controlled inflow. Book it to `H` in that operation. Do not leave it as a second L2 credit, and do not keep the old receivable beside the cash.

A permissionless harvest that only observes a prior force-claim should book attributable interest SY into `H` and clear `C` once, after any supported pretransfer snapshot has reserved its declared credit. That is reconciliation, not a new provenance test.

---

## 6. Ledger and composition with §6.5 redemption

Pricing stays on the Weighted coordinate. NET price is still the PLP/YT zap-out. sNET price is still the provider. `d` is still `ceil(y * 1e18 / I_branch)` from plan §6.5.3, after any tax hop that is actually on. Claim does not add a fee to that inverse. Weighted fee stays once inside the existing helper. No percent floor. No ordinary PLP/YT liquidation.

### 6.1 `C` before the call

Pre-expiry, live fee `f`, hook YT balance `B`, stored accrued `A`, stored user index `Ip_user`, execution index `I` from §4.1:

```text
if Ip_user == 0 or I == Ip_user: pending = 0
else: pending = floor(B * (I - Ip_user) * 1e18 / (Ip_user * I))
gross = A + pending
fee = floor(gross * f / 1e18)
C = gross - fee
```

If `I < Ip_user`, the source subtraction reverts. Treat that as claim failure, not as `C = 0`. Post-expiry, `I` is `firstPYIndex`; do not add later `exchangeRate` growth to `C`.

`H` is eligible booked held SY. Exclude fee payables, exclusive principal, transient Keep-YT SY, allocated principal-exit SY, and unbooked L2 surplus. `d < H + C` is the entry test. Remainder target is `H + C - d >= 1` in SY wei.

### 6.2 Call sequence when `H < d`

1. Finish plan §6.5.5 steps 1–3 (auth, pretransfer snapshot, quote, `d`). Do not sync away the snapshotted surplus.
2. If `H >= d`, do not claim. `H = d` and `C >= 1` is valid. `H = d` and `C = 0` reverts. No partial-claim selector.
3. If `H < d`, call **direct** `YT.redeemDueInterestAndRewards(hook, true, false)`. Do not catch it. Do not pass the router. Do not set `redeemRewards=true` on this call.
4. Measure `c` as the hook's SY balance delta across that call, excluding the already-snapshotted pretransfer credit and any other booked balance. Require `c == interestOut` returned, unless a proved SY fee shows a smaller delta; then use the measured delta. This SY transfer is not the local NET tax predicate.
5. `H := H + c`, `C := 0` for this YT interest. Do not keep the old `C`.
6. Recompute the branch index and `d`. The claim did not advance NetNet. `sNet.index()` is unchanged unless an earlier stake/unstake in this transaction already rebased. `exchangeRate()` may still project. NET redeem's later `unstake` can advance one epoch; sNET redeem will not. Use the index the upcoming redeem will use, not the PY index, as `I_branch`.
7. Require `H >= d` and `H + C - d >= 1`. If the fee, a stale cache, or a post-expiry freeze made `c` too small, revert the whole route, including the claim. No second claim, no `redeemPY`, no LP burn.
8. Then, and only then, isolate non-interest collection and `feeTo` forwarding (section 7).
9. `SY.redeem(receiver, d, tokenOut, minNominal, false)` as plan §6.5.4. Hook holds the shares. Measure the final NET or sNET delta. Exact-out still requires the required net amount or a full revert. Do not drop the ERC-4626 route. `I > 1e18` representability remains the existing §6.5.3 gap, not a claim-path exception.
10. Debit `d` from `H`. Refund, then full expected-set sync. Booked `H` cannot be claimed again as L2.

### 6.3 Before/after

```text
Before, H < d, d < H+C, C = net interest above
After successful interest claim and before redeem:
  H' = H + c
  C' = 0
  require H' >= d and H' + C' - d >= 1
After redeem:
  H'' = H' - d
  C'' = 0 unless a new accrual was created by the redeem (it is not, by this SY transfer)
  require H'' + C'' >= 1
```

A claim that returns more than the shortfall is allowed. The excess stays in `H'` as eligible interest cash, not as a new fee and not as unbooked surplus.

---

## 7. Failure domains

| Failure | Where | Effect | Catch? |
| --- | --- | --- | --- |
| `YCNothingToRedeem`, YT pause, interest `transfer` revert, treasury fee `transfer` revert, uint128 accrued overflow, `currentIndex < prevIndex` | Inside the required YT call | Whole route reverts, including any earlier input | **No.** This is required claim failure |
| `interestOut == 0` or `c` leaves `H' < d` or remainder 0 | After a successful call | Full revert. A zero transfer is not a forwarding success | **No** |
| Reward-token transfer inside `redeemDueInterestAndRewards(..., true, true)` or router market `redeemRewards` | Upstream, same call as interest if coupled | Rolls back interest too | Do not use that coupling for funding |
| Hook's later `feeTo` transfer of non-interest tokens, or an isolated incentive collection | Downstream of a booked interest claim | PRD §13: keep the payable, continue, retry later. Do not reclassify as backing | **Yes, only this** |
| SY `minTokenOut`, NET/sNET short delivery, pause, insufficient sNET backing | §6.5 redeem | Full revert, including the claim | **No** |
| `SY.claimRewards` empty | Verified SY | No payment, no revert | Not a funding success |

The selected exception is the hook's outgoing fee-reward transfer after interest is already booked. It is not a `try/catch` around `YT.redeemDueInterestAndRewards(hook, true, false)`, and not a catch of the router batch. Isolating the reward call means a low-level call or equivalent whose failure cannot unwind the already-required interest claim **only if** that isolation is a separate call that the hook catches. If it is in the same transaction without a catch, its revert undoes the interest claim. The plan must state that catch explicitly and must not apply it to the interest call.

`PendleStakedNetSY` has no reward tokens in the compilation, so `redeemRewards=true` on that YT alone may transfer nothing. That is not a reason to use the router, which still calls `market.redeemRewards` and can revert on PENDLE. Keep the interest call flag-false for rewards anyway, so a later non-empty reward list cannot block funding.

---

## 8. NetNet epoch chronology

```text
Claim:  SY.exchangeRate() view -> Ip * 1e9 -> may write pyIndexStored
        does not write staking.epoch, does not change sNet.index()
sNET redeem after claim: uses Ic, not Ip, unless a stake/unstake already ran
NET redeem after claim: computes nominal at Ip, then unstake may advance one epoch
```

Do not insert `staking.rebase()` to "sync" the claim. Plan §6.5.2 already forbids a catch-up loop. One later NET `unstake` still advances at most one overdue epoch on the local reference. Multiple overdue epochs remain after one redeem. Recompute `d` after the claim because `H` changed; recompute again if the redeem itself is preceded by a stake. Do not treat the PY index as the sNET branch index.

---

## 9. Numeric vectors (specified, not executed)

`ONE = 1e18`. Interest example uses the local `divDown`/`mulDown`. These are formula checks, not live state.

| Case | Inputs | Result |
| --- | --- | --- |
| Pending interest | `B = 1e18`, `prev = 1e18`, `cur = 1.1e18`, `A = 0` | `pending = floor(1e18 * 1e17 * 1e18 / (1e18 * 1.1e18)) = 90909090909090909` |
| 10% fee | `f = 1e17`, gross as above | `fee = 9090909090909090`, `C = 81818181818181819` |
| 0% fee | `f = 0` | `C = pending` |
| First sight | `prev = 0`, any `B` | `pending = 0`, index initialized, `C = A` only |
| No movement | `cur == prev` | `pending = 0` |
| No claim | `H = 10`, `C = 0`, `d = 9` | no YT call; redeem 9; remainder 1 |
| Claimable remainder | `H = 10`, `C = 1`, `d = 10` | no claim; remainder is the unclaimed 1 |
| Drain | `H = 10`, `C = 0`, `d = 10` | revert; no claim |
| Short, exact net | `H = 8`, `C = 3`, `d = 10`, `c = 3` | claim once; `H' = 11`, `C' = 0`; remainder 1; no second claim |
| Fee shortfall | `H = 8`, quoted gross 3, live `c = 1`, `d = 10` | `H' = 9 < 10`; revert all, including the claim |
| Over-claim | `H = 8`, `C = 5`, `d = 10`, `c = 5` | allowed; excess 3 stays booked `H`, not L2 |
| Force-claim already taken as pretransfer | raw surplus consumed by the caller | not also `H` or `C` |
| Empty rewards | verified SY `getRewardTokens()` length 0 | no same-token incentive; do not add SY to `C` from `claimRewards` |
| Epoch | claim then read `staking.epoch().end` | unchanged by the claim; a following NET `unstake` may add one length |

Factory max `2e17` is not a test default. Use the observed `f` when a fork exists. `f = 1e17` above is an illustration of the floor, not a live oracle.

---

## 10. Exact proposed plan addition

Add **§6.5.9 Claim-if-short composition** after §6.5.8. Do not change §6.4 fee order, weights, or the redemption inverse. Proposed text:

```text
### 6.5.9 Claim-if-short composition — local Pendle reference, not a deployment pin

Local reference, inspected 2026-09-28, pragma ^0.8.17:
PendleYieldToken.redeemDueInterestAndRewards(address,bool,bool) at
PendleYieldToken.sol:166–193; interest transfer InterestManagerYT.sol:43–79;
router batch ActionMiscV3.sol:67–84; market rewards PendleMarketV3.sol:237–238
and PendleGauge.sol:43–47. Chain-4663 YT/market bytecode is G1. Do not treat
this section as L3 or G1 closure.

When H < d, the required call is direct
YT.redeemDueInterestAndRewards(hook, true, false).
Anyone may call it; SY interest is paid to the user argument, not msg.sender.
Do not use the router batch and do not set redeemRewards=true on this call.
Those paths can revert on incentive-token transfers and would roll back interest.
SY.claimRewards, redeemPY, skim, and the post-expiry treasury function are not
this funding call.

C is net of the live factory interestFeeRate, not the 20% setter cap:
pending = 0 if the user's stored index is 0 or equal to the execution index;
otherwise floor(balance * (I - prev) * 1e18 / (prev * I));
C = grossAccrued - floor(grossAccrued * feeRate / 1e18).
The view userInterest.accrued omits pending. Post-expiry I is firstPYIndex.
Same-block cache applies only if doCacheIndexSameBlock is true.

The claim reads SY.exchangeRate(), which on the verified SY is a projected view.
It does not advance the NetNet epoch. Recompute d with the redeem branch index
after the claim. sNET redeem still uses current index. NET redeem still uses
_syncedIndex and may then advance one epoch inside unstake.

Measure the SY delta c. Set H = H + c and C = 0 for that interest. Require
H >= d and H + C - d >= 1. Extra claimed SY stays booked eligible interest.
A short c reverts the route. Do not catch the YT interest call.
After interest is booked, isolate non-interest collection and feeTo forwarding.
Only that isolation is the §13 exception. A reward-transfer revert inside the
required YT call is not that exception.

Force-claims clear YT accrued and deliver SY to the hook. Until booked, that
raw surplus remains L2 pretransfer credit. Do not count it as H and as C.
Units already credited to a pretransfer caller are not booked again.
No ordinary LP/YT liquidation, no new fee, no percent floor, no second Weighted fee.
```

Proposed unexecuted rows for §6.5.8, owned by W3/W6/W11, not run here:

| Case | Required result |
| --- | --- |
| Direct interest-only | `redeemInterest=true`, `redeemRewards=false`; `interestOut` equals measured SY delta; reward balances unchanged |
| Router rejected for funding | A reverting market reward token does not sit in the required interest call |
| Fee floor | The 10% illustration above, plus `f = 0` and the live `f` when observed |
| `prevIndex = 0` | No pending; a claim does not invent back interest |
| Cache | If `doCacheIndexSameBlock`, second same-block claim does not reread `exchangeRate` |
| Force-claim | Accrued zero; unbooked SY is L2 until booked; booked once, not also `C` |
| Short `c` | Full rollback of input, claim, and redeem |
| Isolated forward | `feeTo` transfer failure retains payable and still allows a funded redeem; interest-call revert does not |
| Epoch | `staking.epoch` end unchanged across the YT call; one later NET `unstake` advances at most one epoch |
| No liquidation | `H` still short after the claim reverts without `redeemPY` or LP burn |

---

## 11. Remaining gaps

| Gap | Why it blocks closure |
| --- | --- |
| Deployed YT/market/factory addresses, code hashes, `SY`/`PT` immutables | Local V3-shaped source may not be the V6 deployment |
| Live `interestFeeRate`, `rewardFeeRate`, treasury, `doCacheIndexSameBlock`, expiry, `postExpiry.firstPYIndex` | Formula inputs |
| Whether the deployed market holds YT or uses a different `redeemRewards` selector | LP-versus-YT split is local-source only |
| Reward-token list on the deployed SY and market | Same-token incentive case is absent here; a non-empty list would be a new classification, not automatic `C` |
| Warmup, staking equivalence, tax-pair mapping | Still the §6.5.7 NET redemption gaps. The claim does not resolve them |
| Exact-output `I > 1e18` residual | Unchanged §6.5.3 composition item |
| No test execution | Vectors above are specifications |

**Confidence:** high on the local signatures, recipient rule, fee formula, and empty verified-SY rewards. Medium on the composition sequence as the reading that satisfies §6.5.5 without catching a required claim. Low on deployed equivalence. No security or economic-soundness claim.
