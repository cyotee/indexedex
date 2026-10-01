# MiniMax M3 — Independent original: Pendle market/YT claim path for SY-short NET/sNET output, composed with plan v0.8 §6.5 SY redemption

- Researcher: MiniMax M3 (`minimax/MiniMax-M3`), independent original pass; no peer originals or cross-reviews consulted.
- Date: 2026-09-28.
- Normative documents read directly: `CLAUDE.md`; `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.33; `NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` v0.7→v0.8 (post-extraction §6.5 revisions read at lines 437–545); `PRD_OPEN_QUESTIONS.md` (especially NN-07/NN-10/NN-11/NN-14, post-2026-09-28 progress note).
- Primary local Pendle source inspected (local reference port, **not** deployed equivalence): `lib/crane/contracts/protocols/perps/pendle/core/YieldContracts/PendleYieldToken.sol`, `…/InterestManagerYT.sol`; `…/RewardManager/RewardManagerAbstract.sol`; `…/StandardizedYield/SYUtils.sol`; `…/Market/v3/PendleMarketV3.sol`; `…/Market/PendleGauge.sol`; `…/router/ActionMiscV3.sol`; `…/router/base/ActionBase.sol`; `…/offchain-helpers/router-static/base/ActionMintRedeemStatic.sol`; interfaces `IPYieldToken.sol`, `IPInterestManagerYT.sol`, `IRewardManager.sol`, `IPYieldContractFactory.sol`, `IPMarket.sol`.
- Primary SY evidence: `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md` (verified 25-source compilation; `PendleStakedNetSY.sol` decoded; SY reward surface returns empty arrays at `SYBaseUpgV2.sol:309–333` of the verified extract).
- PRD economics preserved: shared SY budget held first, claim only if short, no ordinary PLP/YT liquidation, no percentage reserve floor, no second fee, existing Weighted helper/native fee order, pricing/funding separation, `H+C−d≥1` raw SY unit remainder, atomic rollback on required-failure except outgoing fee-forwarding exception.
- No external library/API doc claims are made in this round (Context7 not invoked). All references are local Solidity.

## 1. Bottom-line finding

The configured claim path for "eligible held SY insufficient" funding of ordinary NET/sNET output is **the YT contract's `redeemDueInterestAndRewards(hook, true, false)`** (interest only, paid in the SY token), optionally bundled with LP-incentive claims via `IPMarket(market).redeemRewards(hook)` for PENDLE/other tokens. The SY contract's own `claimRewards/getRewardTokens/accruedRewards/rewardIndexesCurrent/rewardIndexesStored` return empty arrays in the verified compilation (`SYBaseUpgV2.sol:309–333`), so all market/YT interest lands on the hook only through the **YT contract**, never through the SY. The hook is the persistent `userInterest` and `userReward` owner (per PRD §7.1.3 "the underlying Pendle userInterest belongs to the hook address"). The claim phase does **not** advance the NetNet staking epoch: `_rebaseIfDue()` lives only in `IStakedNetStaking(staking).stake/unstake/rebase()` and none of these are called by `redeemDueInterestAndRewards`, `_distributeInterest`, `_doTransferOutInterest`, `_doTransferOutRewards`, `_updateAndDistributeRewards`, or `IPMarket.redeemRewards`. The SY's `exchangeRate()` (used by YT's `_pyIndexCurrent`) returns `_syncedIndex() * 1e9`, the **projected** post-rebase index; the YT's claim therefore pays interest based on the projected index, even before any actual rebase has happened. There is **no `rebase()` side-effect** to recompute `IStakedNet(sNet).index()`. Once-eligible (cached at `_pyIndexStored` and gated by `doCacheIndexSameBlock`) plus interest fees and reward fees mean: **the hook receives only `interestPreFee * (1 - interestFeeRate)` SY units**; the factory treasury retains the fee (deducted inside `_doTransferOutInterest` at `InterestManagerYT.sol:43–60`).

## 2. Source identity and trust tier

- **Local Pendle reference** under `lib/crane/contracts/protocols/perps/pendle/` is the Crane port of Pendle V2 (`README.md`). It is the **de-facto reference body** for the family; **not** verified deployed equivalence. Solidity pragmas `^0.8.17` (router/YT/Market) and `^0.8.0` (interfaces/helpers). This round does not rerun a fresh deployment check.
- **PendleStakedNetSY** compilation identity recorded in plan §6.5: chain 4663, candidate SY proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`, implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, Sourcify match `47105638` (exact, both creation and runtime), verified `2026-09-04T08:05:04Z`, external solc `0.8.30+commit.73712a01`, optimizer `1,000,000`, `viaIR=true`, Cancun.
- The compiled SY's reward surface is empty in source (`VERIFIED_SY_SOURCE_EXTRACTS.md` line numbers for `SYBaseUpgV2.sol:309–333`); therefore **the SY does not source market interest itself** and **does not implement `claimRewards(user)` for users**. The only path for interest to reach the hook is the YT contract.
- Confidence: **High** on the source-derived formulas, branch behavior and fees; **Medium** on the NetNet epoch non-advance (verified by reading all entry points); **Low** on the deployed-config specifics (factory `interestFeeRate`, `rewardFeeRate`, `treasury`, `doCacheIndexSameBlock`, market/YT/SY identities). These are **G1 evidence** not established here.

## 3. Caller-authority map for claim paths (who may call, for whom, who receives)

### 3.1 Direct YT interest + rewards claim (`PendleYieldToken.sol:166–193`)

```solidity
function redeemDueInterestAndRewards(address user, bool redeemInterest, bool redeemRewards)
    external
    nonReentrant
    updateData
    returns (uint256 interestOut, uint256[] memory rewardsOut)
```

- **Caller**: any address. There is no `onlyOwner` / `onlyFactory` / role check on this entry. **A third party may call it for the hook** without hook-initiated transaction.
- **`user` parameter**: the earning address whose `userInterest` / `userReward` mappings are settled and paid out. The hook address is the earning address per PRD §7.1.3.
- **Recipient rules** (verified at `InterestManagerYT.sol:43–60` for interest, `RewardManagerAbstract.sol:44–66` + `PendleYieldToken.sol:421–473` for rewards):
  - Interest: `_transferOut(SY, user, interestAmount)` after fee to treasury. **`user` is both claimer and recipient.**
  - Rewards: `_doTransferOutRewards(user, user)` — internally `__doTransferOutRewardsLocal(tokens, user, receiver=user, …)`. **`user` is also the receiver.**
- **Order in body** (`PendleYieldToken.sol:174–193`): rewards are computed and transferred **before** interest, because the comments at `:165–166` require updating accrued reward strictly before transferring interest (preserves the proven `totalSyRedeemable` invariant).
- **Fees**:
  - Interest fee: `IPYieldContractFactory(factory).interestFeeRate()` (WAD; `IPYieldContractFactory.sol:42–44`). Deducted at `InterestManagerYT.sol:53`: `feeAmount = interestPreFee.mulDown(feeRate)`; treasury = `IPYieldContractFactory(factory).treasury()`. **The fee is set by the factory, not by the SY or YT; G1 must confirm factory address and current rate.**
  - Reward fee: `IPYieldContractFactory(factory).rewardFeeRate()` (WAD; `IPYieldContractFactory.sol:46`). Deducted at `PendleYieldToken.sol:458`: `feeAmount = rewardPreFee.mulDown(feeRate)`. Same factory, same treasury.

### 3.2 Direct LP incentive claim from market (`PendleMarketV3.sol:237–239`, `PendleGauge.sol:43–48`)

```solidity
function redeemRewards(address user) external nonReentrant returns (uint256[] memory) {
    return _redeemRewards(user);
}
```

- **Caller**: any address. Permissionless.
- **`user`**: the LP-holder address whose `activeBalance` in `PendleGauge` (`PendleGauge.sol:29,62–72`) and reward index are settled.
- **Recipient**: `_doTransferOutRewards(user, user)` at `PendleGauge.sol:46`. **`user` is the receiver.**
- The hook is the LP holder per PRD §7.1.3. The hook calls `market.redeemRewards(hook)` to claim its LP-incentive share (PENDLE and any other `getRewardTokens`).
- `_redeemExternalReward` (`PendleGauge.sol:85–88`):
  ```solidity
  function _redeemExternalReward() internal virtual override {
      IStandardizedYield(SY).claimRewards(address(this));
      IPGaugeController(gaugeController).redeemMarketReward();
  }
  ```
  The first call (SY.claimRewards) is empty for PendleStakedNetSY; the second pulls PENDLE from the gauge controller. **For PendleStakedNetSY the LP incentive pool is effectively PENDLE-only.**

### 3.3 Router batch (`ActionMiscV3.sol:67–84`)

```solidity
function redeemDueInterestAndRewards(
    address user,
    address[] calldata sys,
    address[] calldata yts,
    address[] calldata markets
) external {
    for (uint256 i = 0; i < sys.length; ++i) {
        IStandardizedYield(sys[i]).claimRewards(user);
    }
    for (uintii = 0; i < yts.length; ++i) {
        IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true);
    }
    for (uint256 i = 0; i < markets.length; ++i) {
        IPMarket(markets[i]).redeemRewards(user);
    }
}
```

- **Caller**: any address (router has no role check on this entry).
- **`user`**: same parameter for all three loops. **Recipient is `user` for all three** (the underlying `_transferOut(SY, user, ...)` and `_doTransferOutRewards(user, user)` both use the same `user`).
- The router's loop calls `IPYieldToken.redeemDueInterestAndRewards(user, true, true)` — both interest and rewards, **with the recipient fixed to `user`**, not the router.
- The SY's own `claimRewards(user)` loop is **empty for PendleStakedNetSY** (returns `[]`).
- The hook may call this router to batch YT + market claims for gas efficiency. **No router-specific receiver selection** is supported: the hook is always `user` and always receiver.

### 3.4 Direct vs router path selection

| Need | Direct path | Router path |
|---|---|---|
| Hook wants only interest (in SY) for funding | `YT.redeemDueInterestAndRewards(hook, true, false)` | not supported (router bundles `true, true`) |
| Hook wants only rewards (PENDLE etc.) for forwarding to feeTo | `YT.redeemDueInterestAndRewards(hook, false, true)` or `market.redeemRewards(hook)` separately | `ActionMiscV3.redeemDueInterestAndRewards(hook, [], [YT], [])` or include `[market]` |
| Hook wants both interest and rewards in one tx | `YT.redeemDueInterestAndRewards(hook, true, true)` | `ActionMiscV3.redeemDueInterestAndRewards(hook, [], [YT], [])` |
| Force-claim by a third party (no hook participation) | same direct calls with `user=hook` | same router call with `user=hook`; rewards still go to `hook` |

The PRD R30 ("Anyone may trigger hook reward collection independently of LP activity… The caller acquires no entitlement and cannot change recipients.") is satisfied by the source: **the caller does not control recipients; `user` is the only recipient.** A third-party caller cannot redirect funds to themselves. Inference label: fact from source; consistent with PRD R30.

## 4. Interest vs incentives vs LP rights — what each returns, who pays fees

### 4.1 Interest (paid in the SY token, paid to `user`)

- **Source**: `userInterest[user].accrued` (SY unit) accumulated by `_distributeInterestPrivate(user, currentIndex)` at `InterestManagerYT.sol:63–80`. The accrued is updated on:
  - `_beforeTokenTransfer(from, to, _)` — both sides of any YT transfer (`:499–503`)
  - Explicit `redeemDueInterestAndRewards(..., true, _)` path — `_distributeInterest(user)` then `_doTransferOutInterest` (`:187–189`)
- **Formula** (`InterestManagerYT.sol:63–80`):
  ```solidity
  uint256 prevIndex = userInterest[user].index;
  if (prevIndex == currentIndex) return;
  if (prevIndex == 0) {
      userInterest[user].index = currentIndex.Uint128();
      return;          // first-touch, no interest yet
  }
  uint256 principal = _YTbalance(user);                  // = balanceOf(user) at YT
  uint256 interestFromYT = (principal * (currentIndex - prevIndex)).divDown(prevIndex * currentIndex);
  userInterest[user].accrued += interestFromYT.Uint128();
  userInterest[user].index = currentIndex.Uint128();
  ```
- **Index source**: `_getInterestIndex()` → `PendleYieldToken.sol:392–395`:
  - pre-expiry: `_pyIndexCurrent()` (`SY.exchangeRate()` capped below by `_pyIndexStored`, monotonic; see §6.2)
  - post-expiry: `postExpiry.firstPYIndex` (frozen)
- **Payout**: `InterestManagerYT._doTransferOutInterest(user, SY, factory)`:
  ```solidity
  uint256 interestPreFee = userInterest[user].accrued;
  userInterest[user].accrued = 0;
  uint256 feeAmount = interestPreFee.mulDown(feeRate);
  interestAmount = interestPreFee - feeAmount;
  _transferOut(SY, treasury, feeAmount);
  _transferOut(SY, user, interestAmount);
  ```
  The hook receives `interestPreFee * (1 - interestFeeRate)` raw SY units; treasury receives the fee.
- **First-touch semantics**: when `userInterest[user].index == 0`, no interest is paid yet — only the index is set. Until the next index advance, future claims return zero interest for that user. Inference label: fact from source.

### 4.2 Incentives (paid in reward tokens, paid to `user`)

- **Source**: `userReward[token][user].accrued` accumulated by `_distributeRewardsPrivate(user, tokens, indexes)` at `RewardManagerAbstract.sol:44–66`:
  ```solidity
  uint256 userShares = _rewardSharesUser(user);
  for (uint256 i = 0; i < tokens.length; ++i) {
      uint256 index = indexes[i];
      uint256 userIndex = userReward[token][user].index;
      if (userIndex == 0) userIndex = INITIAL_REWARD_INDEX.Uint128(); // = 1
      if (userIndex == index || index == 0) continue;
      uint256 deltaIndex = index - userIndex;
      uint256 rewardDelta = userShares.mulDown(deltaIndex);
      userReward[token][user] = UserReward({index: index.Uint128(), accrued: rewardAccrued.Uint128()});
  }
  ```
- **userShares for YT** (`PendleYieldToken.sol:480–484`):
  ```solidity
  return SYUtils.assetToSy(index, balanceOf(user)) + userInterest[user].accrued;
  ```
  The reward share is **SY equivalent of the user's YT balance at the user's last-indexed rate** plus already-accrued interest. **As PY index grows, assetToSy per unit decreases** (see §6.4). The net effect: rewards are accrued per PY balance * deltaIndex, where deltaIndex is the reward index advance.
- **Payout** (`PendleYieldToken.sol:421–473`):
  - Pre-expiry: each reward token's `rewardPreFee = userReward[token][user].accrued`; `feeAmount = rewardPreFee.mulDown(rewardFeeRate)`; `_transferOut(tokens[i], treasury, feeAmount)`; `_transferOut(tokens[i], receiver, rewardAmounts[i])`. **Receiver = user.**
  - If `selfBalance < rewardPreFee` and `allowedToRedeemExternalReward == true`, calls `_redeemExternalReward()` once — pulls fresh reward tokens from `SY.claimRewards(this)` and `gaugeController.redeemMarketReward()`. For PendleStakedNetSY, SY.claimRewards is empty; the gauge controller call is the actual PENDLE source.
  - Post-expiry: `postExpiry.userRewardOwed[token]` is reduced by the user's accrued; transfers use cached balances; no fee (the rewards were already settled pre-expiry). The remaining balance goes to treasury via `redeemInterestAndRewardsPostExpiryForTreasury()` (`PendleYieldToken.sol:199–226`).
- **No interest on rewards**: rewards do not earn additional rewards in the same distribution; the `userReward[token][user].accrued` is reset to zero and the index is advanced to the current global reward index. Next claim will accrue from that new index.

### 4.3 LP rights

- The hook is the LP holder per PRD §7.1.3. LP rights are **distinct from YT/interest rights**: LP accrues incentive rewards (PENDLE etc.) via the gauge controller, paid through `IPMarket.redeemRewards(hook)`.
- LP itself is not an interest-bearing instrument for the hook's funding of NET/sNET output. LP principal backs the position leg of HLP. LP **exit** is the `exitPreExpToSy` / `exitPostExpToSy` / `burn(receiver, receiverPt, netLpToBurn)` paths — not relevant to the SY-short claim phase.
- LP **transfer** does not happen in the family design (PRD R04: "Each DETF's economic portion follows only its actual hook LP"). The hook does not transfer LP to claim.

## 5. Direct vs router vs force-claim paths

| Path | Trigger | Recipient | Notes |
|---|---|---|---|
| **Direct YT interest** | hook detects H<d and triggers | `user` (= hook) | `redeemDueInterestAndRewards(hook, true, false)`; pays `interestPreFee*(1-interestFeeRate)` raw SY |
| **Direct YT reward** | hook decides to forward PENDLE etc. to feeTo | `user` (= hook); then hook forwards to feeTo under PRD §13 best-effort isolation | `redeemDueInterestAndRewards(hook, false, true)`; reward tokens (less `rewardFeeRate`) to hook |
| **Direct both** | combined | `user` (= hook) for both; hook forwards non-SY tokens | `redeemDueInterestAndRewards(hook, true, true)` |
| **Direct LP incentive** | hook decides to forward market PENDLE/other to feeTo | `user` (= hook); then forwarded | `market.redeemRewards(hook)`; reward tokens (less fee) to hook |
| **Router batch YT** | bundling | `user` (= hook) for everything | `ActionMiscV3.redeemDueInterestAndRewards(hook, [], [YT], [])` |
| **Router batch market** | bundling | `user` (= hook) for everything | `ActionMiscV3.redeemDueInterestAndRewards(hook, [], [], [market])` |
| **Router batch all** | bundling | `user` (= hook) for everything | `ActionMiscV3.redeemDueInterestAndRewards(hook, [], [YT], [market])` |
| **Force-claim by third party** | anyone calling `redeemDueInterestAndRewards(hook, …)` or `market.redeemRewards(hook)` | hook (caller does not receive funds) | PRD R30 permits this |

**Direct call**: hook pays gas; hook controls `redeemInterest`/`redeemRewards` flags; hook decides when to forward non-SY rewards to feeTo.

**Router call**: hook pays router gas; flag combinations are fixed (router's `redeemDueInterestAndRewards` always calls YT with `true, true`); routing is via router proxy; an extra approval for the router to call the YT is not needed (the YT function is permissionless); **the router is not a recipient**.

**Force-claim by third party**: anyone calls `redeemDueInterestAndRewards(hook, …)` with the hook as `user`. Funds go to the hook (not the third party). Third party pays gas. This matches PRD R30's "permissionless rewards collection… caller acquires no entitlement and cannot change recipients."

The hook must **distinguish interest SY from incentive tokens** when receiving claim payouts:
- Interest comes in as SY (the configured SY ERC20 token). Hook's BasicVaultRepo must already register SY as expected-held; the received SY becomes part of `H` after the once-only bookkeeping settles the receivable (`(E,R) → (E+c, R−c)`).
- Incentives come in as separate tokens (PENDLE and others from `getRewardTokens`). Hook must forward these to current `feeTo()` under PRD §13 best-effort isolation, retaining excluded payable on forwarding failure.

## 6. Current accrual, index update/cache/expiry, fee floors → net SY units

### 6.1 Index update cadence for the hook's interest claim

`PYIndexLib.newIndex(YT)` (used in router code at `ActionBase.sol:269,290,313`) and `_pyIndexCurrent` (`PendleYieldToken.sol:241–243,397–407`) both compute the current PY index. The YT's interest claim internally calls `_getInterestIndex()` → `_pyIndexCurrent()`:

```solidity
function _pyIndexCurrent() internal returns (uint256 currentIndex) {
    if (doCacheIndexSameBlock && pyIndexLastUpdatedBlock == block.number) return _pyIndexStored;
    uint128 index128 = PMath.max(IStandardizedYield(SY).exchangeRate(), _pyIndexStored).Uint128();
    currentIndex = index128;
    _pyIndexStored = index128;
    pyIndexLastUpdatedBlock = uint128(block.number);
    emit NewInterestIndex(currentIndex);
}
```

**Critical fact**: `IStandardizedYield(SY).exchangeRate()` for `PendleStakedNetSY` returns `_syncedIndex() * 1e9` (verified `PendleStakedNetSY.sol:108–111`). **`_syncedIndex()` projects the next epoch's rebase** (see verified source at `:113–125`). **Therefore, when the staking epoch has ended and `queuedProfit > 0` and `circulating > 0`, the YT's claim pays interest based on the projected post-rebase index, even though the actual `IStakedNet(sNet).index()` has not yet advanced.** The claim path does not call `rebase()` (the YT does not invoke `IStakedNetStaking(staking).rebase()`), so the on-chain sNET index does not actually advance because of the claim itself.

Inference label: fact from verified source cross-reference.

**Consequence for PRD §6.2**: the hook's quote (using `_syncedIndex`) and the actual payout (using `_pyIndexCurrent = max(SY.exchangeRate(), _pyIndexStored)`) **are the same projection**, so the quote/payout parity holds **for this branch**, in contrast to the SY-deposit/redeem asymmetry (see NetNet/Pendle post-extraction cross-review finding). The hook's `H+C-d>=1` raw SY unit remainder check applies to the post-claim state.

**Cache semantics**: `doCacheIndexSameBlock` is a per-YT immutable set at construction (`PendleYieldToken.sol:43,81`). When `true`, multiple calls to `_pyIndexCurrent()` in the same block return the cached `_pyIndexStored` and don't query `SY.exchangeRate()`. **The hook must call `pyIndexCurrent()` (or trigger an interest update via `redeemDueInterestAndRewards`) once per block to materialize the latest index.** Subsequent calls in the same block see the cached value. G1 must observe `doCacheIndexSameBlock` for the configured YT.

### 6.2 Monotonic non-decreasing PY index

`PMath.max(IStandardizedYield(SY).exchangeRate(), _pyIndexStored)` at `PendleYieldToken.sol:400` guarantees the PY index never decreases. The hook's interest claim at a later block can only equal or exceed the prior accrued rate, so no negative interest can accrue.

**Within a block**: the cached `_pyIndexStored` may lag the latest `SY.exchangeRate()` if `doCacheIndexSameBlock` is true. The hook should call `pyIndexCurrent()` (or trigger `redeemDueInterestAndRewards`) explicitly to refresh.

### 6.3 Expiry handling

`PendleYieldToken.isExpired()` (`MiniHelpers.isCurrentlyExpired(expiry)`, `:313–315`). Pre-expiry: `_pyIndexCurrent` is used. Post-expiry:
- `_setPostExpiryData` is called once on the first post-expiry entry (modifier `updateData`, also in `_beforeTokenTransfer`). It records:
  - `postExpiry.firstPYIndex = _pyIndexCurrent().Uint128()` — frozen index at expiry
  - `postExpiry.firstRewardIndex[token] = IStandardizedYield(SY).rewardIndexesCurrent()[i]`
  - `postExpiry.userRewardOwed[token] = _selfBalance(token)` — pre-expiry rewards stashed for user claims
- All post-expiry `_updateRewardIndex` returns the frozen reward indexes (`PendleYieldToken.sol:486–496`).
- Post-expiry interest: `_getInterestIndex` returns `postExpiry.firstPYIndex` (`:392–395`).
- Post-expiry `_doTransferOutRewards` (`:421–441`): uses cached balances; **no fee charged post-expiry** (rewards go to treasury later via `redeemInterestAndRewardsPostExpiryForTreasury`).
- Hook can still claim interest post-expiry using the frozen index — interest will be the user's YT balance at frozen index (`assetToSy(frozenIndex, balanceOf)` equivalent). Post-expiry YT transfers are blocked because `mintPY` is `notExpired` (`:91,110`); `_beforeTokenTransfer` still runs `_setPostExpiryData` if expired (`:500`).

### 6.4 Fee floors and net SY unit delivery

**Interest fee floor** = 0 (factory-set). Plan §6.4/§6.5 requires the hook to be aware of the rate and the **unit-side rounding**: `feeAmount = interestPreFee.mulDown(feeRate)` (PMath.mulDown = `floor(product / ONE)`). `interestAmount = interestPreFee - feeAmount`. The hook receives `interestPreFee * (1 - feeRate)` **floored to wei**. For `interestPreFee < 1`, `mulDown` returns 0 and the entire interest goes to the treasury. **This is a real rounding boundary:** when `interestPreFee * feeRate < 1`, the hook receives zero. The hook must treat sub-wei interest claims as not yielding funding.

**Reward fee floor** = 0 (factory-set). Same `mulDown` rounding for each reward token. Some reward tokens may have non-18 native decimals; `mulDown` operates on raw amounts so the rounding boundary is `interestPreFee * feeRate < 1` raw unit, irrespective of decimals.

**Treasury recipient**: `IPYieldContractFactory(factory).treasury()` (factory-set). **For PendleStakedNetSY, the factory is the Pendle Yield Contract Factory that created this YT** — not the hook's `feeTo()` from the Vault Fee Oracle. **This is a different recipient** from PRD §13's "current `feeTo()`" for other-attributable-reward tokens. The PRD §13 says "send all other attributable Pendle reward tokens to the current `feeTo()`" — for the **factory interest/reward fee** portion, this is paid to the **Pendle treasury**, not the hook's `feeTo()`. **The hook should not re-forward the factory fee to its own feeTo**; it should accept this fee as a Pendle-protocol-level deduction.

**Net SY units per interest claim**: `interestPreFee * (1 - interestFeeRate)` raw SY, where `interestPreFee` accumulates between claims as `principal * (currentIndex - prevIndex) / (prevIndex * currentIndex)` for each index advancement since the last touch. **No minimum claim amount** — a 0-amount claim is silently allowed (returns `interestOut = 0`, no transfer). The PRD §6.2 step 5 "If the actual net funding is too small or total remainder 0: revert" applies after the SY redemption step, not at the YT claim step.

## 7. Recipient rules and cross-component consistency

### 7.1 Hook is the earning address

Per PRD §7.1.3 "the underlying Pendle userInterest belongs to the hook address, not to individual hook-LP wallet addresses." Therefore:
- `userInterest[hook].index` and `userInterest[hook].accrued` track the hook's YT interest.
- `userReward[token][hook]` tracks the hook's YT/LP incentive.
- `activeBalance[hook]` (in `PendleGauge`) tracks the hook's LP position for veBoost.

For the family, the **only YT holder is the hook** (the hook retains YT from Keep-YT, separate from LP). The hook is the recipient of all claim payouts (interest SY + incentive tokens, less factory fees).

### 7.2 Recipient in path variations

| Path | Recipient of SY interest | Recipient of reward tokens | Recipient of LP PENDLE | Notes |
|---|---|---|---|---|
| YT.redeemDueInterestAndRewards(hook, true, false) | hook | n/a (not claimed) | n/a | SY interest only |
| YT.redeemDueInterestAndRewards(hook, false, true) | n/a (not claimed) | hook (less factory rewardFee) | n/a | Reward tokens only |
| YT.redeemDueInterestAndRewards(hook, true, true) | hook | hook (less factory rewardFee) | n/a | Both |
| market.redeemRewards(hook) | n/a | hook (less factory rewardFee) | hook | LP incentive via gauge |
| Router redeemDueInterestAndRewards(hook, [], [YT], [market]) | hook | hook (less factory rewardFee) | hook | Batched |

The hook then **forwards non-SY reward tokens** to current `feeTo()` from the Vault Fee Oracle, under the selected best-effort isolation (PRD §13 / plan §10). Forwarding failure keeps the excluded payable at the hook (no auto-claim retry from inside claim path; the hook's own retry is an outer flow).

### 7.3 Force-claim impact on interest rights

A third-party force-claim via `YT.redeemDueInterestAndRewards(hook, true, true)`:
1. Advances `userInterest[hook].index` to current `_pyIndexCurrent()`.
2. Credits `userInterest[hook].accrued += interestFromYT` for the advancement.
3. Resets `userInterest[hook].accrued` to 0 and transfers `interestPreFee * (1 - interestFeeRate)` SY to the hook.
4. Resets `userReward[token][hook].accrued` to 0 and transfers reward tokens to the hook.

After a force-claim, the hook's view of its `userInterest` and `userReward` reflects a clean state. **The hook cannot claim the same interest twice**; the accrued is reset on transfer. **The hook cannot be "frontrun"** in the traditional sense because the force-claim does not benefit the caller (funds go to the hook).

**However**: if the hook planned a careful sequence (quote → claim → recompute → redeem) and a third party force-claims between the quote and the hook's claim, the hook's claim may return zero interest. **The hook should detect this via a pre-claim quote using `userInterest(hook)` (a public getter at `InterestManagerYT.sol:31`)** and only trigger its own claim when there is sufficient accrued. Or the hook can monitor events: `RedeemInterest(hook, interestOut)` and `RedeemRewards(hook, rewardsOut)` at `IPYieldToken.sol:23,21` are emitted by any successful claim (whether hook-initiated or force-claim).

### 7.4 Effects of YT transfer on interest rights

`_beforeTokenTransfer(from, to, _)` at `PendleYieldToken.sol:499–503`:
```solidity
function _beforeTokenTransfer(address from, address to, uint256) internal override {
    if (isExpired()) _setPostExpiryData();
    _updateAndDistributeRewardsForTwo(from, to);
    _distributeInterestForTwo(from, to);
}
```

This **settles interest and rewards for both parties** before any YT transfer. The implications:
- If the hook transfers YT out, the hook's accrued interest is zeroed and credited to the hook via the transfer. **But the transfer itself does not transfer interest** — it distributes it into `userInterest[hook].accrued`, which is then paid out only when `redeemDueInterestAndRewards` is called.
- If the hook receives YT, the sender's accrued interest is credited and zeroed; the receiver (hook) gets its index updated and any new accrued.
- **The hook must not transfer YT** in normal operation (the family design has the hook as the sole YT holder from Keep-YT). Transferring YT would (a) distribute the hook's accrued interest (paying out without explicit claim), and (b) potentially move the YT out of the family's accounting.

Inference label: fact from source + family design implication.

## 8. Finite H/C once-only ledger with actual receipt reconciliation

### 8.1 Ledger state

Let:
- `H` = recognized eligible held SY (raw SY token balance at hook, after deducting booked reserves, fee payables, exclusive principal, transient Keep-YT, allocated principal-exit SY).
- `C` = remaining eligible net-claimable SY interest (the hook's `userInterest[hook].accrued` plus any in-flight forwarded YT reward for the same SY — but rewards are not SY, so `C` = `userInterest[hook].accrued` in raw SY units).

**H and C are independent raw-unit ledgers**, both denominated in raw SY units. **H is not `max(raw − booked, 0)`** — that is the **separate origin-independent public pretransfer rule** for public-supported pretransfer routes, not the eligible SY budget (PRD §6.3 / plan §6.5 §6.5.5). Reiterated per PRD NN-11: do not conflate these two ledgers. The PRD §6.2 eligible budget and the L2 public surplus are separate.

### 8.2 Pre-claim quote

- `userInterest(hook).accrued` is a public getter (`InterestManagerYT.sol:31`); returns `(uint128 lastPYIndex, uint128 accruedInterest)`.
- `userReward(token, hook).accrued` is also public (`IRewardManager.sol:5`).
- Hook can quote `C` (eligible net-claimable SY) from `userInterest(hook).accrued` (note: this is a `uint128` — the actual `_distributeInterestPrivate` writes `interestFromYT.Uint128()` to `userInterest[user].accrued += interestFromYT.Uint128()`; if the actual value exceeds `uint128.max` the cast reverts. With raw SY supply in `uint248`, the accrued is bounded; the conversion `interestFromYT = principal * (currentIndex - prevIndex) / (prevIndex * currentIndex)` with `principal ≤ uint248`, `deltaIndex ≤ uint128` (PY index is `uint128`) and `prevIndex*currentIndex` at least `1e18` gives a manageable bound).

### 8.3 Claim sequence when H < d

1. **Quote `d`** from the SY redemption branch inverse (§6 of the post-extraction cross-review): `d = ceil(y * 1e18 / i_branch)` with `y` from the Weighted quote and `i_branch` either `_syncedIndex` (NET) or `IStakedNet(sNet).index()` (sNET).
2. **Quote `H` and `C`**: `H = SY.balanceOf(hook) − bookedReserves − ...`; `C = userInterest(hook).accrued`.
3. **Check `H+C-d >= 1`**: if true, no claim needed; if false, trigger claim.
4. **Trigger `YT.redeemDueInterestAndRewards(hook, true, false)`** to claim interest (SY units, less factory fee). Optionally bundle LP-incentive claim via `market.redeemRewards(hook)` if the hook wants PENDLE etc. (forwarded to feeTo later).
5. **Measure actual SY received**: `received = SY.balanceOf(hook) − preBalance`. Expected: `interestPreFee * (1 - interestFeeRate)` raw SY.
6. **Reconcile ledger**: `(E, R) → (E + received, R − received)`. The receivable `R` is `userInterest(hook).accrued` (now zero after the claim) and `E` = `H + received`. The `userInterest[hook].accrued` is reset to 0 by the claim (verified `InterestManagerYT.sol:50–51`).
7. **Recompute `i_branch`**: any state change since the quote — `_setPostExpiryData` (no-op if not expired), `_updateSyReserve` (writes storage but no token move), `_pyIndexCurrent` cache update — does not move the SY balance. **The NetNet epoch is NOT advanced by the claim.** However, `_pyIndexCurrent` is called, which queries `SY.exchangeRate() = _syncedIndex() * 1e9` (projected index) and updates `_pyIndexStored`. **The hook's `i_branch` for NET redemption (using `_syncedIndex()`) is unchanged by the claim** because `_syncedIndex()` reads from `IStakedNet(sNet).index()` and `IStakedNetStaking(staking).epoch()` which the claim doesn't touch.
8. **Recompute `d`**: unchanged unless the user requested a different output amount.
9. **Check `H+C−d >= 1` again**: if the claim delivered enough, proceed to SY redemption; if not, revert (no retry, no PLP/YT fallback, no liquidation).
10. **Proceed to SY redemption** via `SY.redeem(receiver, d, tokenOut, minTokenOut, false)` from hook-held shares.

### 8.4 Origin-independent public pretransfer policy compatibility

L2 is closed (PRD §6.3 / plan §6.1 §6.5.5; NN-11). The eligible SY budget for funding NET/sNET output **is the hook's recognized eligible held SY + net-claimable SY interest**, **not** `max(SY.balanceOf(hook) - booked, 0)`. Public pretransfer surplus is **a separate ledger** that credits other routes' callers; it is **not** spent in the hook's NET/sNET output funding. The two ledgers share the same SY token but have **distinct roles**:

- `H` (eligible SY budget for NET/sNET output) = accounted SY at hook for strategy use.
- `max(raw − booked, 0)` (L2 public surplus) = unbooked SY at hook available for supported pretransfer callers.

When the hook receives a positive unbooked donation (or force-claim pretransfer to the SY/hook), it is L2 credit for **supported public pretransfer callers** — **not** for hook's NET/sNET funding (unless the hook itself is a supported pretransfer caller for some other route, which is not the selected family design). PRD NN-11 closes this: "Internal role/claim accounting remains once-only."

The hook's interest claim from YT is **not** L2 public pretransfer: it is a protocol-defined claim path with explicit recipients and fees. The interest SY lands as **settled receivable** in the hook's strategy books (part of `H` after settlement).

Inference label: fact + plan-rule consistency.

## 9. Same-token incentives and blanket eligibility

The PRD §13 closes reward routing: "Hold the market interest token; send all other attributable Pendle reward tokens to the current `feeTo()`." The market interest token for PendleStakedNetSY **is the SY token** (`PendleYieldToken.SY()` returns the SY address). The market SY is **the interest token**.

**Same-token incentive**: could a reward token coincide with the SY? For PendleStakedNetSY:
- `getRewardTokens()` of YT = `SY.getRewardTokens()` (verified `PendleYieldToken.sol:417–419`).
- For `PendleStakedNetSY`, `SY.getRewardTokens()` returns `[]` (verified `SYBaseUpgV2.sol:316–318`).
- `PendleGauge.getRewardTokens()` extends with `PENDLE` (`:102–106`).

**Therefore the SY's reward tokens list is empty** and **no same-token incentive exists** for the market interest token. The hook does not need to disambiguate SY from incentive tokens at the YT claim step. (The market's `getRewardTokens()` may include PENDLE — verified source has PENDLE as the gauge reward token.)

**The PRD's "interest token retention" policy** holds: hook receives interest SY; hook does not forward interest SY to feeTo (per PRD §13). Reward tokens (PENDLE and others) are forwarded to feeTo per PRD §13.

**No blanket eligibility**: the hook's `userInterest[hook].accrued` is computed specifically for the hook's YT balance; the hook's `userReward[token][hook]` is computed for the hook's YT balance + accrued interest, weighted by reward index advances. No other address's interest/rewards is captured by the hook's claim.

## 10. Supported claim phase when H < d

The actual claim **may collect more than the shortfall amount**:
- `redeemDueInterestAndRewards(hook, true, false)` claims **all accrued interest** up to the user's last-indexed rate. The hook cannot specify an amount; it claims everything.
- This is consistent with PRD/plan: "claim-only-if-short is a trigger policy, not an invented partial-claim selector; the actual API may collect more" (plan §6.5.5 step 4).

After the claim:
- The hook receives `interestPreFee * (1 - interestFeeRate)` SY. Some or all of this becomes part of `H` after settlement.
- Any excess above `d` remains in `H`. The hook does NOT need to deposit it back anywhere; it stays as accounted eligible SY for subsequent use.

**If the claim still leaves H+C < d**: revert the entire operation atomically. No second claim, no PLP/YT liquidation, no partial payout (plan §6.5.5 step 5/7).

## 11. Reward transfer failure: inside upstream claim vs downstream hook forwarding

### 11.1 Inside upstream claim path (factory fees)

The factory fees (interest and reward) are paid to the **Pendle treasury** (`IPYieldContractFactory(factory).treasury()`). The transfer happens inside `_doTransferOutInterest` / `__doTransferOutRewardsLocal` via `_transferOut(SY/token, treasury, feeAmount)`. If this transfer reverts (e.g., SY or reward token has a blacklist or transfer hook that rejects the treasury address), **the entire `redeemDueInterestAndRewards` reverts**, the user's accrued is **not** reset (it stays in the user's ledger because the revert undoes state), and the hook's claim reverts.

**This is unavoidable claim failure**: the hook cannot retry, claim a smaller amount, or skip the fee. The factory's fee transfer is **not** in the PRD §13 / plan §10 best-effort isolation exception; it is the **factory's protocol-level fee**.

**Mitigation**: the hook's pre-claim quote must observe the factory treasury address and the configured fee rates (G1 evidence). If the treasury address is a contract that reverts on receive, the claim reverts. **This is genuine claim-side failure; the PRD §6.2 step 5 "any required funding claim failure reverts" applies.** Inference label: fact from source.

### 11.2 Downstream hook forwarding (incentive tokens to feeTo)

After the hook receives incentive tokens (PENDLE etc.), the hook forwards them to current `feeTo()` per PRD §13. This forwarding is the **selected best-effort isolation**: failed forwarding retains the excluded payable and does not block the surrounding operation (plan §10). The forwarding itself is a `safeTransfer` (or equivalent) that catches the failure.

**Distinction**:
- Factory fee transfer inside claim: **not isolated** — failure reverts the whole claim and the hook's funding attempt.
- Hook's downstream forwarding to feeTo: **isolated** — failure keeps the payable and the funding operation continues.

The hook must therefore structure its claim path to:
1. Call `YT.redeemDueInterestAndRewards(hook, true, false)` for interest (mandatory for funding). If this reverts due to factory fee transfer failure, the whole money route reverts (plan §6.5.5 step 7).
2. Separately call `YT.redeemDueInterestAndRewards(hook, false, true)` for rewards, or `market.redeemRewards(hook)` for LP incentives. These may be skipped or wrapped in try/catch.
3. After receiving incentive tokens, attempt forwarding to `feeTo()` under the selected best-effort exception. Failure retains the payable.

**The router's `redeemDueInterestAndRewards` bundles both** (`true, true`). The hook may prefer direct calls to keep the interest and reward claims separate, **especially because the router's call reverts if the factory fee transfer fails for EITHER interest OR rewards**. Direct calls allow the hook to bundle reward claim in a way that catches revert without aborting the interest funding. Inference label: fact + design recommendation.

## 12. Claim phase advancing NetNet epoch?

**No.** The claim path does **not** call `IStakedNetStaking(staking).stake`, `unstake`, or `rebase`. Verified:

- `_pyIndexCurrent` (`PendleYieldToken.sol:397–407`) calls `IStandardizedYield(SY).exchangeRate()`. For PendleStakedNetSY this is `_syncedIndex() * 1e9` — a pure view. It does NOT mutate `IStakedNet(sNet).index()` or call `stake/unstake/rebase`.
- `_distributeInterestPrivate` (`InterestManagerYT.sol:63–80`) reads `_YTbalance(user) = balanceOf(user)` — pure balance read. Does not call staking.
- `_doTransferOutInterest` (`InterestManagerYT.sol:43–60`) does `_transferOut(SY, treasury, feeAmount)` and `_transferOut(SY, user, interestAmount)`. No staking call.
- `_doTransferOutRewards` (`PendleYieldToken.sol:421–473`) does `_redeemExternalReward()` (which calls `SY.claimRewards(this)` and `gaugeController.redeemMarketReward()` — neither touches NetNet staking) and `_transferOut(tokens[i], treasury/user, ...)`. No staking call.
- `market.redeemRewards` → `_redeemRewards` → `_updateAndDistributeRewards`, `_updateUserActiveBalance`, `_doTransferOutRewards` (in `PendleGauge.sol:43–48`). No staking call.

**Therefore**: an interest/reward claim by the hook does **not** advance `IStakedNetStaking(staking)._epoch.number` or update `IStakedNet(sNet).index()`. The **SY's `_syncedIndex()` projected post-rebase value is observed but not committed**. Subsequent `stake/unstake/rebase` calls (by anyone) would commit the new index and the cached `_pyIndexStored` would track it.

**Important consequence for the hook's NET output funding**: the claim does not produce actual sNET-backed value increase at the protocol level. The hook's claim only settles the bookkeeping. The next time someone calls `stake/unstake/rebase` on the staking contract, the actual `sNet.index()` advances and `sNet.totalSupply()` grows by the queued profit (mirroring the SY's projection). At that point, the hook's eligible held SY `H` (raw SY shares) **does not change** (the SY is a separate token from sNet; the SY's exchange rate grows as the SY's `_syncedIndex` advances, but the SY shares at the hook don't increase in count).

**For sNET branch**: the SY's `_redeem(sNet)` uses `IStakedNet(sNet).index()` (current, not projected). So even if the projected index is reflected in the SY's exchange rate, **the sNet redemption does NOT benefit from the projected index**. The hook's `i_branch` for the sNet branch is `IStakedNet(sNet).index()`, which only advances on actual stake/unstake/rebase.

**For NET branch**: the SY's `_redeem(net)` uses `_syncedIndex()` (projected). So NET output does benefit from the projected index, but the actual `unstake` inside the redemption will trigger `_rebaseIfDue` once, advancing the actual index. This is the same as the post-extraction cross-review finding.

## 13. NET/sNET SY index chronology, minimum/actual receiver receipts, positive H+C-d≥1, atomic failure

### 13.1 Index chronology across the claim-then-redeem sequence

Let `t0` = start of hook's ordinary money route. State at each phase:

- **t0**: pre-claim. `i_branch(0) = _syncedIndex()` (for NET) or `IStakedNet(sNet).index()` (for sNET). `userInterest[hook] = (prevIndex, accrued=0)` (assume first-touch after recent claim). `H(0)`, `C(0) = 0`.
- **t1 = claim**: `YT.redeemDueInterestAndRewards(hook, true, false)` called. `_pyIndexCurrent()` runs:
  - If `doCacheIndexSameBlock && pyIndexLastUpdatedBlock == block.number`: returns cached `_pyIndexStored` (no SY.exchangeRate call).
  - Otherwise: `PYIndex = max(SY.exchangeRate(), _pyIndexStored) = max(_syncedIndex() * 1e9, _pyIndexStored)`.
  - `_distributeInterest(hook)` runs: `interestFromYT = YT.balanceOf(hook) * (currentIndex - prevIndex) / (prevIndex * currentIndex)` (if `prevIndex != 0`).
  - `accrued += interestFromYT`; `index = currentIndex`.
  - `_doTransferOutInterest`: `interestPreFee = accrued`; `accrued = 0`; `feeAmount = interestPreFee * interestFeeRate` (rounded down); `interestAmount = interestPreFee - feeAmount`; transfers to treasury and hook.
- **t2 = post-claim**: `userInterest[hook] = (currentIndex, accrued=0)`. `H(2) = H(0) + interestAmount`. `C(2) = 0`. **`i_branch` unchanged** (claim does not touch staking).
- **t3 = redeem SY**: `SY.redeem(receiver=user, d, tokenOut, minTokenOut, false)`:
  - For NET: `_redeem` computes `amount = floor(d * _syncedIndex() / 1e18)`. Calls `IStakedNetStaking(staking).unstake(receiver, amount)`. Unstake calls `_rebaseIfDue()` once: if epoch ended with `queuedProfit > 0 && circulating > 0`, advances one epoch. `sNet.index()` becomes the new committed index.
  - For sNET: `_redeem` computes `amount = floor(d * IStakedNet(sNet).index() / 1e18)`. Transfers sNet from SY directly.
- **t4 = post-redeem**: `H(4) = H(2) − d`. `C(4) = 0` (claim was settled). The hook's eligible budget is `H(4) + C(4) = H(4)`. **Must satisfy `H(4) >= 1`** raw SY unit (positive remainder).

### 13.2 Minimum receiver and measurement

- For NET: `minTokenOut = y` (the user's requested native NET). SY enforces `amountTokenOut >= minTokenOut` (`SYBaseUpgV2.sol:269`). If `amount = floor(d * _syncedIndex() / 1e18) < y`, revert. The unstake may or may not actually deliver `amount` NET (the source's nominal check, not a delta check). **Hook must measure `net.balanceOf(receiver)` after the SY call and revert if `received < y`** (per plan §6.5.4).
- For sNET: same nominal `minTokenOut` and same balance-delta check on `sNet.balanceOf(receiver)`.

### 13.3 Positive H+C−d ≥ 1

- After settlement: `(H + C − d) >= 1` raw SY unit. This is a **strict inequality** (`>= 1` means at least 1 wei remains). **Plan §6.5.5 step 5 explicitly**: "At redemption require now-held H >= d and H+C-d>=1 raw SY unit. If insufficient, revert; no retry solver, ordinary PLP/YT liquidation or partial payout." Plan §6.5.3 also confirms: "For 0<I<=D, qMin reaches y exactly".
- The H + C − d >= 1 check **must use the post-claim, post-redeem state**, not the pre-claim state.
- For the pre-execution check: `d < H + C` (strict inequality; `H + C > d` implies at least 1 unit remains). Plan §6.5.5 step 3: "Require d < H+C and valid arithmetic/custody."
- For exact-out at `I > D` (index above 1e18), the post-redeem remainder may exceed 1 by an unpredictable amount. The minimal inverse `qMin` may overshoot. Plan §6.5.3: "For I>D, some targets have gaps: I=2D,y=1 gives qMin=1 and nominal output2. Minimum-sufficient is not exact final delivery. A direct exact-output payout must meet the required final net amount and input bounds; this round does not select gifting/warehousing excess or blanket removal of unrepresentable ERC4626 withdrawals."

### 13.4 Atomic failure scope

- **Atomic**: any failure reverts the entire hook's money route, including:
  - The YT interest claim (factory fee transfer failure).
  - The SY redemption (downstream `unstake` failure, `minTokenOut` check, `sNet.balanceOf(SY) < amount` for sNET branch).
  - Any DETF expansion settlement that precedes the money route (per plan §8.2).
  - Any TWAP capture/check that precedes.
- **Best-effort exception**: outgoing fee-reward forwarding to `feeTo()` (PRD §13). The hook's internal try/catch (or equivalent) for the token transfer is the **only** non-reverting exception.
- **Required failure inside the claim path**: factory fee transfer revert (covered above) and `userInterest[user]` uint128 cast overflow (extremely rare given bounded SY supply).
- **Not a required failure**: third-party force-claim (does not harm the hook).

## 14. Concrete before/after equations and numeric boundary vectors (plan only, not executable)

### 14.1 Claim phase numeric vectors

| Test case | Parameters | Expected | Notes |
|---|---|---|---|
| First-touch claim | `userInterest[hook].index == 0`, claim interest | `interestOut = 0` (interestFee * 0 = 0); no transfer | Verified: first-touch sets index but returns without paying |
| Index unchanged claim | `currentIndex == userInterest[hook].index` | `interestOut = 0` | Verified: `_distributeInterestPrivate` returns early |
| Small interest claim | `interestPreFee = 10 wei`, `feeRate = 1e17` (0.01 = 1%) | `feeAmount = 0` (10 * 0.01 = 0.1 → floor = 0); `interestAmount = 10` to hook | Wei-level rounding: hook gets all 10 wei, treasury gets 0 |
| Sub-wei interest | `interestPreFee = 99 wei`, `feeRate = 1e17` | `feeAmount = 0`; `interestAmount = 99` | Same rounding boundary |
| Boundary wei fee | `interestPreFee = 100 wei`, `feeRate = 1e17` | `feeAmount = 1e18 * 1e17/1e18 = 1 wei * 0.01 = floor(0.01) = 0`; `interestAmount = 100` | mulDown floors; 100 * 0.01 = 1.0 → floor = 1 if feeRate ≥ 0.01; below that, 0 |
| Realistic claim | `interestPreFee = 1e24`, `feeRate = 1e17` (1%) | `feeAmount = 1e22`; `interestAmount = 9.9e23` | Hook receives 99% |
| Force-claim by third party | third party calls `redeemDueInterestAndRewards(hook, true, true)` | hook receives interest + rewards; third party pays gas | `user` parameter is hook; recipient is hook |
| Same-block cache hit | `doCacheIndexSameBlock = true`, `pyIndexLastUpdatedBlock == block.number` | `_pyIndexCurrent` returns `_pyIndexStored` without querying SY.exchangeRate | Hook should call `pyIndexCurrent()` once per block to materialize |
| Post-expiry claim | `isExpired() = true`, `_setPostExpiryData` already called | interest computed using `postExpiry.firstPYIndex`; `_updateRewardIndex` returns frozen indexes; `_doTransferOutRewards` no fee | hook can still claim post-expiry using frozen index |

### 14.2 Claim + redeem composition numeric vectors

| Test case | Setup | Expected |
|---|---|---|
| H+ C > d, no claim needed | `H = 100`, `C = 0`, `d = 50` | proceed; `H+C-d = 50` ≥ 1 |
| H = d, C > 0 | `H = 100`, `C = 5`, `d = 100` | proceed (positive C remains); `H+C-d = 5` ≥ 1 |
| H < d, claim fills | `H = 50`, `C = 0`, `d = 100`; claim delivers 60 (after 1% fee, from `interestPreFee = 60.6`) | `H(2) = 110`, `H+C-d = 10` ≥ 1 |
| H < d, claim shortfall | `H = 50`, `C = 0`, `d = 100`; claim delivers 30 (after fee) | `H(2) = 80 < d`; revert entire route |
| H + C = d, no remainder | `H = 100`, `C = 0`, `d = 100` | revert (no positive remainder); plan §6.5.5 step 3 |
| H < d, claim delivers excess | `H = 50`, `C = 0`, `d = 60`; claim delivers 100 (factory fee 1) | `H(2) = 150`, `H+C-d = 90` ≥ 1; excess remains |
| I > D, exact-out overshoots | `I = 2e18`, `d = qMin = ceil(1 * 1e18 / 2e18) = 1` SY; forward output = floor(1 * 2e18 / 1e18) = 2 native | output 2 ≠ user-requested 1; exact-out must revert or accept plan §6.5.3 gap |

### 14.3 Index chronology numeric vectors

| Test case | Setup | Expected |
|---|---|---|
| Claim without rebase | `block.timestamp < epochEnd`; claim computes `interestFromYT = balanceOf(hook) * (currentIndex - prevIndex) / (prevIndex * currentIndex)` | interest paid based on current index (no epoch advance) |
| Claim with epoch end (no queue) | `block.timestamp >= epochEnd`, `queuedProfit == 0` | `_pyIndexCurrent` returns `_syncedIndex` = currentIndex (because queuedProfit == 0); interest computed against unchanged index |
| Claim with epoch end + queue + zero circulating | `block.timestamp >= epochEnd`, `queuedProfit > 0`, `circulating == 0` | `_syncedIndex` returns currentIndex; interest paid against current index; staking does not advance epoch (sNet.rebase skipped) |
| Claim with epoch end + queue + positive circulating | `block.timestamp >= epochEnd`, `queuedProfit > 0`, `circulating > 0` | `_syncedIndex` returns projected index (post-rebase projection); interest paid based on projected index; **no actual rebase happens during claim**; subsequent stake/unstake commits the new index |
| NET redemption after claim | `d` for NET output, `i_branch = _syncedIndex()` (still projected; not committed by claim) | `_redeem(net)` calls `unstake` which triggers `_rebaseIfDue` once, advancing actual index |

## 15. Exact proposed plan addition and finite remaining G1/source gaps

### 15.1 Proposed plan addition (text-level; do not apply)

Insert the following after plan v0.8 §6.5.5 (Held-first ordinary-output call sequence) as a new **§6.5.5a — Claim phase composition with YT and market**:

```text
#### 6.5.5a Claim-phase composition with YT, market and SY redemption

The SY's own reward surface is empty in the verified compilation
(SYBaseUpgV2.sol:309-333). All market interest lands on the hook only
through the YT contract; the market's PENDLE/other incentive tokens
land through IPMarket.redeemRewards. Both paths use the hook address
as the recipient and the factory fee rate/factory treasury as the
mandderatory factory-side deduction.

Direct paths (selected for full control):
  YT.redeemDueInterestAndRewards(hook, true, false)
      -> interest SY paid to hook, less factory interestFeeRate
      -> mandderatory factory fee transfer to factory treasury;
         revert undoes accrued reset
  YT.redeemDueInterestAndRewards(hook, false, true)
      -> reward tokens paid to hook, less factory rewardFeeRate
      -> mandderatory factory fee transfer to factory treasury;
         revert undoes accrued reset
  IPMarket(market).redeemRewards(hook)
      -> LP incentive tokens paid to hook, less factory rewardFeeRate
      -> also calls SY.claimRewards(yt) (empty for PendleStakedNetSY)
         and gaugeController.redeemMarketReward() (PENDLE source)

Router batch (gas efficiency):
  ActionMiscV3.redeemDueInterestAndRewards(hook, [], [YT], [])
      -> YT.redeemDueInterestAndRewards(hook, true, true) — both
  ActionMiscV3.redeemDueInterestAndRewards(hook, [], [], [market])
      -> market.redeemRewards(hook)

Force-claim by a third party (PRD R30):
  anyone calls the same paths with user=hook; hook is recipient;
  the caller acquires no entitlement and cannot redirect funds.

Claim path does NOT advance NetNet staking epoch:
  _pyIndexCurrent queries IStandardizedYield(SY).exchangeRate() which
  for PendleStakedNetSY returns _syncedIndex()*1e9 (projected).
  No call to IStakedNetStaking(staking).stake/unstake/rebase.
  The projected index is observed but the actual sNet.index() is not
  committed until someone calls stake/unstake/rebase.
  NET branch SY redemption calls unstake which DOES advance one
  epoch (one _rebaseIfDue), so the projected becomes committed.

Recipient rules:
  Interest SY -> hook (then part of H after (E,R)->(E+c,R-c))
  Reward tokens -> hook (then hook forwards to current feeTo()
                    under PRD §13 best-effort isolation;
                    forwarding failure retains excluded payable)
  Factory fees -> IPYieldContractFactory(factory).treasury()
                    (NOT the hook's feeTo; protocol-level deduction)

Claim phase sequence when H < d:
  1. Quote d from SY redemption branch inverse (NET: _syncedIndex;
     sNET: IStakedNet(sNet).index()) and H+C.
  2. If H+C >= d+1 (positive remainder guaranteed), no claim.
  3. Else call YT.redeemDueInterestAndRewards(hook, true, false).
  4. Measure actual SY received (balance delta). Expected:
     interestPreFee*(1-interestFeeRate); wei-rounded.
  5. Settle receivable: (E,R) -> (E + received, R - received) where
     R = userInterest(hook).accrued (now 0).
  6. Recompute i_branch (unchanged by claim), recompute d (unchanged
     unless user adjusted). Check H+C-d >= 1 again.
  7. If still short, revert entire operation (no retry, no PLP/YT
     liquidation, no partial payout).
  8. Proceed to SY.redeem(receiver=user, d, tokenOut, minTokenOut,
     false) from hook-held shares.
  9. Measure actual NET/sNet delta at receiver; revert if delta < y.
  10. Refunds, then full expected-set sync; atomic rollback on any
      required failure.

Failure scope:
  Atomic except for outgoing fee-reward forwarding to feeTo
  (PRD §13 best-effort). Factory fee transfer inside the claim is
  NOT best-effort: failure reverts the whole route.
  Third-party force-claim is not a failure for the hook.
```

### 15.2 Remaining source gaps (require G1 evidence, not claim-side design)

| Gap | Required for | Evidence path |
|---|---|---|
| `IPYieldContractFactory(factory).interestFeeRate()` for configured YT | Interest fee floor | G1: read factory contract at configured factory address |
| `IPYieldContractFactory(factory).rewardFeeRate()` for configured YT | Reward fee floor | G1: read factory contract |
| `IPYieldContractFactory(factory).treasury()` for configured YT | Recipient identification | G1: read factory contract |
| `PendleYieldToken.doCacheIndexSameBlock()` for configured YT | Same-block index caching | G1: read YT contract storage/constant |
| Configured YT and market addresses | Caller path | G1: read proxy configuration; PRD §4.1 PkgArgs |
| Deployed `IStakedNetStaking(staking).rebase()` behavior | NetNet epoch advancement | G1: observe deployed staking; verify one-epoch-per-call |
| Deployed `IStakedNet(sNet).index()` and `_syncedIndex()` parity | Projection match | G1: observe deployed sNET; verify constants/formula |
| Gauge controller address and `redeemMarketReward()` shape | LP incentive path | G1: read gauge controller deployment |
| Actual reward token list for the market (post-PENDLE) | Hook's feeTo forwarding | G1: observe market.getRewardTokens() |
| Deployed SY ERC20 decimals | Unit conversion | G1: observe SY.decimals() (must be 18 per the SY compilation's `getOrCreate(sNet, 18)`) |
| Whether `redeemDueInterestAndRewards(user, true, true)` triggers `_redeemExternalReward` even if all reward tokens are zero | Hook's gas accounting | G1: read YT source for the exact pre-expiry `_doTransferOutRewards` path |
| Whether `market.redeemRewards(hook)` will revert if `gaugeController.redeemMarketReward()` reverts | Hook's LP incentive safety | G1: read market source for the call site |
| Whether `userInterest[hook].accrued` can overflow `uint128` for the hook's YT balance | Claim phase revert | G1: read deployed staking to confirm supply bounds |

### 15.3 Things deliberately NOT in the plan addition

- No invented partial-claim selector. The source API does not accept an amount; it claims all accrued.
- No new Weighted inverse or fee change. The claim path is independent of the SY redemption inverse.
- No PLP/YT liquidation fallback when claim is short.
- No percentage reserve floor. The remainder check is binary: `H+C-d >= 1` raw SY unit.
- No re-implementation of `_distributeInterestPrivate` or `_doTransferOutInterest`. Use the source as-is.
- No router injection for receiver selection. The router always uses `user` as recipient.
- No authentication layer for force-claim. PRD R30 permits anyone to force-claim; the hook's funds are not at risk because the hook is always the recipient.

## 16. Source URL, paths, versions, access dates

- Primary evidence file: `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md` (2026-09-28; 25 decoded sources; target keccak256 `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`).
- Sourcify (round-trip + extraction manifest): <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources> — accessed 2026-09-28.
- Local Pendle V2 reference (`lib/crane/contracts/protocols/perps/pendle/`): Solidity pragmas `^0.8.17` (router/YT/Market) and `^0.8.0` (interfaces/helpers); snapshot accessed 2026-09-28.
- `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.33 (revised 2026-09-27).
- `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` v0.7→v0.8 (revised 2026-09-27; §6.5 rewritten 2026-09-28).
- `docs/strategies/ohm-style/netnet-pendle/PRD_OPEN_QUESTIONS.md` (2026-09-28 progress note for NN-07).

## 17. Status

- **L3 claim-phase composition**: source-derived path is closed (verified from local Pendle reference + verified SY extraction). Composed call graph, recipient rules, fees, and atomic-failure scope are specified in §15.1.
- **G1**: deployed-equivalence evidence is **not** closed. Factory fee rates, treasury, `doCacheIndexSameBlock`, configured YT/market addresses, deployed staking epoch/rebase behavior, gauge controller address, reward token list, and deployed SY decimals are all **G1 evidence** required for implementation. See §15.2.
- **L1 / L2 / NN-03**: retain their resolved dispositions; not reopened.
- **L4 / G0**: untouched by this round.
- **NN-07 / NN-10 / NN-14**: claim-phase source mapping closes the NN-07 "actual claim/fee graph" remaining item. NN-10 (reusable provider) is satisfied at source-mapping level; provider implementation is engineering work. NN-14 (historical claims and reward retries) is satisfied at source-mapping level for the pre-expiry path; post-expiry path is partially specified (frozen index, no fee).
- **No execution**: no shell, no tests, no deployment, no implementation, no plan/tracker edits, no delegation. This is documentation only.

## 18. Saved full-original path

`docs/research/netnet-pendle-claim-funding/minimax-original.md` (this file).

Stop at human checkpoint.