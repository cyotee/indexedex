# Astra — independent original: Pendle claim-funded SY settlement

**Access date:** 2026-09-28. New independent first pass in the retained Astra session. Current PRD v0.33 and implementation plan v0.8 govern; earlier-round conclusions are not evidence for this new question. No other researcher's new artifacts were read. Research only: no shell, tests, deployments, implementation, delegation or configuration edits. Only this assigned report is written.

## 1. Evidence, versions and principal conclusion

Read current `CLAUDE.md`, the family PRD, plan §6.4–6.5 and tracker; canonical Crane testing and local adversarial guidance directly. Production-first tests below are proposals, not executions. **P** below means `lib/crane/contracts/protocols/perps/pendle/`; all such source is **local reference, not verified deployed binding**. Most YT/router/market bodies have Solidity pragma `^0.8.17`; gauge/reward/math helpers use `^0.8.0`. File names identify local `PendleMarketV3` and `ActionMiscV3`, not the version of a chain4663 deployment. No upstream commit pin was established.

**E** means `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md`. Current plan §6.5 records chain4663 candidate SY proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`, implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, Sourcify exact-match47105638, external compiler0.8.30+commit.73712a01/optimizer1,000,000/Cancun/viaIR=true. That compilation evidence does not verify the YT, market or gauge controller. URL: <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources>, accessed as local evidence/current plan on2026-09-28, not freshly fetched. No new external library documentation claims were required; analysis used source directly, including vendored SafeERC20 whose header says last updatedv4.9.3.

**Main finding (source fact):** cash interest for the hook's retained YT is claimed by `YT.redeemDueInterestAndRewards(hook,true,...)`, paid **in SY directly to hook**. Anyone can trigger it for hook but cannot redirect the proceeds through a receiver argument. `market.redeemRewards(hook)` instead claims LP incentive rewards using gauge active balances; it neither burns LP nor pays out the LP's SY/PT reserves. For this exact external SY's empty reward list, matching local YT has no incentive tokens, and matching local market has only the controller's `PENDLE` token. No second “market-held YT interest” entitlement belongs to the hook merely because it owns LP.

**Important integration result:** a YT claim can update its PY index using the SY's **projected** exchangeRate without processing a NetNet epoch. Therefore it can make SY interest claimable before a NetNet rebase actually executes. The next NET SY redemption processes at most one epoch; direct sNET redemption does not. PY index, current sNET index and projected SY index are distinct state variables with distinct cache rules.

## 2. Entrypoints, caller, beneficiary and permitted composition

| Exact entrypoint | Call authority / beneficiary | Effect |
|---|---|---|
| `YT.redeemDueInterestAndRewards(address user,bool redeemInterest,bool redeemRewards) external returns(uint256 interestOut,uint256[] rewardsOut)` | No caller==user or allowance requirement. Any caller for any user. Interest and rewards pay user, not caller or arbitrary receiver. Both flags false reverts. | Updates reward accounting first; optional incentive transfer; optional interest accrual/fee/SY payout; updates SY reserve after success. |
| `market.redeemRewards(address user) external returns(uint256[] memory)` | Any caller for user; user receives rewards. | Updates reward index/user accrued, refreshes active balance, transfers accrued incentives. No LP burn. |
| Router `redeemDueInterestAndRewards(address user,address[] sys,address[] yts,address[] markets) external` | Public, user forwarded unchanged. No return amounts. | Ordered loops: each SY.claimRewards(user), each YT claim(user,true,true), each market.redeemRewards(user). No catch/minimum/shortfall parameter. |
| Router `multicall(Call3[] calls) external payable returns(Result[] res)` | Self-delegatecall batch with per-call allowFailure. | Required claim steps must not use allowFailure=true. No new arbitrary-target delegation granted to hook. |
| `YT.pyIndexCurrent() public returns(uint256)` | Permissionless; nonReentrant; not view. | Updates/caches PY index, not a claim or NetNet rebase. |
| `YT.setPostExpiryData() external` | Permissionless; no-op pre-expiry. | Initializes frozen expiry data after expiry. |
| `YT.redeemInterestAndRewardsPostExpiryForTreasury()` | Permissionless trigger, treasury recipient fixed by YT factory. | Treasury rights only; not hook's C. |

Sources: `P/interfaces/IPYieldToken.sol:35–59`; `P/core/YieldContracts/PendleYieldToken.sol:166–193,199–258`; `P/core/Market/v3/PendleMarketV3.sol:237–244`; `P/core/Market/PendleGauge.sol:43–48`; `P/router/ActionMiscV3.sol:67–84,251–288`; `P/interfaces/IPActionMiscV3.sol:157–162`.

For an owned hook address, direct calls are sufficient—no transfer of YT/LP to the router, staking, or YT contract is needed to collect. Choose fixed configured addresses and hook beneficiary; do not allow user-supplied alternate beneficiaries or arbitrary claim targets in the family API.

**Proposed concrete phase for this reference binding:** when H<d, call retained/current series' YT with `(hook,true,true)` and corresponding market with `(hook)` in a fixed validated order; source-match the same series and SY. For the active-only operation the graph has one YT call and one market call. Historical collection is an explicitly selected validated series, not an implicit scan of every market. The router batch with `sys=[]`, `yts=[YT]`, `markets=[market]` has equivalent beneficiaries/order but loses direct return values and adds router binding. Direct calls improve isolated receipt measurement. Calling the actual SY's empty claim API is unnecessary for funding.

The market call is incentive collection required by this proposed combined collection phase, **not a second source of interest SY**. If the moderator instead selects a separate interest-only funding phase `YT(hook,true,false)` and separate incentive management, that is a real supported API, not a shortfall-amount claim. Preserve the PRD's collection obligations explicitly rather than silently omitting market rewards. Neither variant may catch a required claim failure. No caller may pass an amount to partially withdraw only d−H: these APIs collect all accrued selected entitlements.

## 3. Exact current accrual and net SY equation

`P/core/YieldContracts/InterestManagerYT.sol:26–80` stores `userInterest[user]={uint128 index,uint128 accrued}`. Let W=10^18, b=raw YT balance of hook, j=stored user index, a=stored gross accrued SY, and k=interest index used by the actual claim:

```text
if j == k: gross = a
else if j == 0: gross = a; set user index to k; no retrospective accrual
else: delta = floor(b * (k-j) * W / (j*k)); gross = a + delta
fee = floor(gross * factory.interestFeeRate() / W)
net = gross - fee
```

On interest claim, set accrued=0; transfer fee SY to factory.treasury(); transfer net SY to hook. Return `interestOut=net`, emit interest/fee events. The fee is applied once to **total gross accrued**, not independently to each earning interval, and is not the hook fee oracle's usage/seigniorage fee. `P/core/libraries/math/PMath.sol:34–52` confirms mulDown/divDown and checked multiplications. Preserve the single expression's floor; `floor(bW/j)-floor(bW/k)` is generally not identical.

Before expiry, k is `_pyIndexCurrent()`:

```text
if cacheEnabled && lastUpdatedBlock == block.number:
    k = storedPYIndex
else:
    k = max(SY.exchangeRate(), storedPYIndex)
    checked cast k to uint128
    store k and current block
```

Source: `PendleYieldToken.sol:392–407`. This is a monotone high-water PY index, not necessarily the latest SY exchange rate. A same-block cache can intentionally keep an older value after some other call changes the SY exchange rate. Do not use current exchangeRate alone to estimate C. Read the actual cache flag/block/stored index. `offchain-helpers/router-static/base/ActionMintRedeemStatic.sol:103–115` models this max/cache result, but calls exchangeRate even before its cache check; an actual cached YT call can avoid that external read. Avoid changing failure dependencies by blindly substituting that helper.

The public `userInterest` value alone is stale accrued storage, not net claimable. C must include the current incremental floor and current factory fee, after current balance/transfer checkpoints. Factory rates/treasury are mutable reference state (`PendleYieldContractFactory.sol:58–63,169–191`), not assumed historical constants. Retained claims across multiple YTs sum **per-series net results**, with one fee floor per actual claim, never a fee on an aggregate across factories/series.

Arithmetic domain: preserve b*(k−j), that product*W, j*k, gross+delta, gross*feeRate, all uint128 index/accrued casts and additions. Valid matched source normally keeps k≥j; do not clamp inconsistent negative deltas to zero. A safe custom view can calculate wide intermediates but must report actual source execution failure when the source's checked intermediates fail. Net availability also requires actual YT-held SY and successful treasury/user transfers; a formula is not backing proof.

## 4. Expiry, historical rights and checkpoint effects

Expiry is `expiry <= block.timestamp` (`P/core/libraries/MiniHelpers.sol:5–10`). The claim's `updateData` modifier first initializes post-expiry state if necessary and finally synchronizes YT's SY reserve (`PendleYieldToken.sol:52–56`). `_setPostExpiryData` calls external SY reward collection once, freezes `firstPYIndex` at then-current max/cache PY index, freezes reward indexes and snapshots reward balances (`:373–385`). It does not reconstruct the index at the exact expiry timestamp if nobody touched the contract then.

Thereafter user interest accrual uses frozen `firstPYIndex`, not continuing exchangeRate (`:392–395`). Pre-expiry unpaid interest remains claimable after expiry, including when hook's current YT balance is zero but stored accrued is positive. Post-expiry growth does not extend user YT interest indefinitely. PT principal realization is a different path: current-index user payout versus frozen-index gross difference accrues to treasury (`:317–355`); it is not ordinary-output cash and must not be added to C.

YT transfers/mint/burn checkpoint rewards **before** interest for sender and recipient at their pre-transfer balances (`:499–503`; `InterestManagerYT:37–40`). Accrued interest and reward storage remain assigned to addresses: transferring YT does not transfer the sender's already accrued claim. The recipient's future rights start from its checkpointed index. Zero-balance former holders may still claim accrued amounts. Zero address and YT contract itself are excluded from distribution. HLP transfer economics are implemented by the hook's own share accounting; they do not cause the underlying YT balance/claim owner (hook) to change.

Anyone may force-claim for hook. That cannot redirect native YT proceeds but clears accrued and transfers to hook without invoking a hook accounting notification. It can also checkpoint rounding earlier, changing floor dust or per-claim fee rounding. A subsequent hook claim may legitimately return zero. Never retain the old receivable and count the already received SY again.

## 5. LP incentives are not interest or withdrawable LP reserves

`PendleMarketV3` holds/prices **PT and SY**, not a normal YT reserve (`:40–42,85–123,276–290`). `readTokens()` returning YT is a relationship getter, not evidence that market owns YT. `burn` pays reserve SY/PT only on a corresponding LP burn (`:129–145`), which ordinary claim funding must not perform.

The market's `PendleGauge` updates incentives from SY rewards and the gauge controller, then distributes by **activeBalance**, not unconditionally h/H (`PendleGauge.sol:43–106`). Precisely:

```text
newActive = min(lpBalance,
    floor(lpBalance*40/100)
    + [floor(floor(totalLP*veBalance/veSupply)*60/100) if veSupply>0])
```

The old active balance earns pending rewards before being refreshed. Total active supply changes by new−old. Market token transfer hooks distribute rewards before transfer and refresh active balances after (`:108–114`; `PendleMarketV3:338–356`). Sender's already accrued gauge rewards do not travel with LP; this differs from the custom hook's selected accrued-value-follows-HLP policy, which must continue tracking the hook's own underlying claims.

`RewardManager.sol:16–76` claims external rewards at most once per block, then for each token:

```text
newRewards = actualMarketRewardBalance - lastBalance
if index == 0: index = 1
if totalActiveSupply != 0: index += floor(newRewards*W/totalActiveSupply)
lastBalance = actualMarketRewardBalance
userAccrued += floor(userActiveBalance*(index-userIndex)/W)
```

User index0 is treated as initial index1 (`RewardManagerAbstract.sol:44–64`). Zero totalActiveSupply causes no index increment, while lastBalance still absorbs receipts; do not allocate those receipts retroactively to the next LP. On payout, clear user accrued and subtract that amount from lastBalance before transfer. No YT interest-fee deduction occurs on this market reward transfer; do not charge it twice or reuse the YT formula here.

The market/controller path is `_redeemExternalReward()` → `SY.claimRewards(market)` → `gaugeController.redeemMarketReward()`. Controller requires a recognized market as caller and pays caller market, not arbitrary hook (`PendleGauge:85–88`; `LiquidityMining/GaugeController/PendleGaugeControllerBaseUpg.sol:53–64,85–96`). Controller accrued PENDLE increases by `speed*(min(now,incentiveEndsAt)-lastUpdated)` (`:151–156`), with its own funding and arithmetic requirements. Users do not call controller for hook rewards directly.

**Market-held YT:** if YT is actually donated/transferred to market, it can accrue as user=market in the YT ledger. Anyone can claim that interest **to market**. There is no inspected market method passing that SY through as hook's YT interest or distributing it pro-rata to LPs. The market's `skim()` sends excess SY/PT over stored reserves to market treasury (`PendleMarketV3:224–230`). Do not include such market-owned YT claims in hook C. A different deployed implementation would require its own proof.

## 6. Incentive-token collision and failure domains

In the actual StakedNetSY compilation, reward token/index/claim methods return empty arrays (E:309–333, preserved in plan§6.5). Matching local YT simply obtains its reward list from SY (`PendleYieldToken:417–419`). Thus this YT's incentive list is empty. Matching market list is SY list plus controller PENDLE, deduplicated (`PendleGauge:102–106`): **one controller-specified token**, not an arbitrary basket.

No actual deployed equality between that token and SY was established. Do not invent blanket SY-incentive eligibility. Verify controller.pendle() differs from market SY; if it coincides, RewardManager's assumption that the entire reward-token balance is reward inventory (`RewardManager:38–49`) collides with market-held reserve SY. That is a concrete conditional binding incompatibility requiring analysis, not license to treat reserve SY as incentives. Other future SYs may expose rewards but are not this compilation. Held same-token incentives remain separately attributable under current PRD; spendability is not inferred from retention.

For a general YT with reward tokens, order matters: `_updateAndDistributeRewards` runs even with redeemRewards=false. It updates external indexes; if redeemRewards=true, all reward payouts occur **before interest payout** (`PendleYieldToken:174–189`). Reward accrued uses `floor(rewardShares*deltaRewardIndex/W)`, where rewardShares=`floor(YTbalance*W/userInterest.index)+grossAccruedInterest` (`:479–495`; `RewardManagerAbstract:47–64`). Each reward gross pays `floor(gross*rewardFeeRate/W)` to YT factory treasury and remainder to user; if local funds are insufficient, external SY claims may run (`:443–476`). This is a separate fee from the interest fee.

**Upstream failure:** SY reward collection/index calls, gauge reward transfers, YT incentive treasury/user transfers, interest treasury transfer or interest user transfer can revert the required claim. There is no upstream per-token catch. TokenHelper uses safeTransfer (`P/core/libraries/TokenHelper.sol:23–40`); vendored `lib/crane/contracts/external/openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol:26–28,117–124` bubbles failed calls/false returns, without proving net economic receipt. Any such failed required phase must propagate and unwind the whole family operation. In particular router multicall allowFailure=true is not a permitted workaround.

**Downstream forwarding exception:** only after rewards successfully reach hook does hook attempt its own transfer of fee-destined tokens to dynamic feeTo. That transfer can fail and leave an excluded payable without blocking an otherwise valid operation, as already selected. This does not make an upstream claim failure nonblocking. For the current empty-YT-reward binding, the YT interest call avoids incentive-transfer risk structurally, but its required SY/treasury transfers can still fail; the market's PENDLE phase remains coupled to upstream controller/token availability. NN03 does not demand survival of broken essential dependencies.

## 7. Do claims advance NetNet epochs?

**For the inspected reference composed with the named SY compilation: no direct NetNet epoch advancement occurs in these claims.** YT calls SY.exchangeRate(), which is view and uses `_syncedIndex()` projection; it does not stake/unstake/rebase (E:108–125). YT writes its own PY cache/accrual/reserve, not NetNet's epoch. Actual SY reward methods are empty. Market rewards call that empty method plus controller/vePENDLE machinery; no inspected direct staking call exists in that graph. This conclusion remains conditional on binding those deployed dependencies and their actual implementations.

Consequences:

1. A due profitable NET epoch may already raise PY interest accrual via projected exchangeRate, even while sNET.index() remains unchanged.
2. Claim transfers **static SY shares** from YT to hook, not native NET/sNET; no SY redemption happens during the claim.
3. NET redemption after claim computes Ip afresh and calls unstake, processing at most one overdue epoch. If still overdue afterward, another exchangeRate query may project another epoch and create additional pre-expiry YT claimable accrual on the next uncached update.
4. Direct sNET redemption uses Ic and makes no staking call. Same-block PY cache can retain the earlier projected value despite intervening state changes. Do not use PY index as the SY→sNET conversion index.
5. At/after expiry the user-interest index stays frozen even if NET redemption advances epoch. Recompute only rights that actually remain eligible; do not create post-expiry user interest from the new live rate.

The offchain helpers named “Static” are not all views: `ActionInfoStatic.getUserPYInfo` actually invokes claim(true,true), and `getUserMarketInfo` invokes market.redeemRewards (`:56–95`). They are useful simulated calls offchain, but calling them in a transaction performs claims. Do not use them inside an ostensibly read-only/funding-free quote phase. No onchain test/simulation was executed here.

## 8. Once-only finite ledger and composition with plan v0.8

Use a finite per-validated-series record keyed by `(YT,market,SY,hook)`; keep only raw custody in BasicVault and economic roles separately. No authoritative cloned Pendle index replacing source state. Define:

- B = actual hook SY balance; R = booked raw snapshot.
- H = recognized eligible held SY (not B−R).
- C = sum of currently executable **net** hook-owned YT interest claims for this SY, after current fees/cache/expiry; exclude claims owned by market, other LPs, fee payables, principal-exit SY and transient Keep-YT SY.
- F = booked excluded payables/other excluded held roles (not all necessarily one beneficiary).
- U=max(B−R,0) = supported public pretransfer credit availability, regardless of origin.

Always determine valid public pretransfer credit before a sync that would erase it. A pre-existing forced claim changes native userInterest and B but does not invoke the hook. Refresh C from native state, not last local expectation. If an eligible caller consumes the unbooked receipt under L2, those units are its contribution/payment according to the route; they cannot simultaneously be inherited cash interest H or an outstanding C. This is an intentional allocation rule, not an attack to repair with payer authentication. Consumed/refunded credit follows existing rules. Unconsumed recognized balances must receive their actual eligible/excluded role once; an unrelated donation cannot be swept merely because some reward token address matches.

For one in-operation measured YT claim, let C0 contain its source-derived net expected n, let actual hook SY delta be r, and let Cother be other remaining eligible claims. With no other change:

```text
before: B0, H0, C0 = n + Cother
native: accrued gross cleared; fee to Pendle treasury; r SY received by hook
after:  B1=B0+r; H1=H0+r; C1=Cother
H1+C1 = H0+C0 + (r-n)
```

Do not write `C1=C0-r` merely because r was received: native entitlement was cleared by the actual claim; a short receipt does not leave the difference claimable. Re-read native state/other accrual and reconcile explicitly. With actual known SY ordinary transfers, source return n and isolated balance delta should agree; a mismatch is not silently accepted as a second receivable. A required funding shortfall reverts.

For fee-destined reward receipt z: increase B_token and excluded payable by measured z; successful forwarding lowers both by actual transfer, failed forwarding preserves payable and custody. Do not increase H for PENDLE or reward USDG. Forced prior receipts require reconciling changed native reward accrued and unbooked/public-credit consumption before establishing payable; historical origin does not override L2.

### Proposed fixed sequence (no new economics)

1. Authenticate limits and callback phase; capture supported public surplus credit; perform required epoch/TWAP/expansion pre-steps. Reconcile old force-claims and current native entitlements without double credit.
2. Quote NET/sNET output in existing Weighted coordinate/native fee order. Independently derive d raw SY under plan§6.5's final-hop inverses/actual transfer predicates. Require d<H+C and valid arithmetic. If H≥d, **no funding claim**. Ordinary output never burns PLP/YT.
3. If H<d, execute the configured direct YT/market phase above with hook beneficiary. Register known reward tokens before final full-set sync. Snapshot isolated receipt balances; compare source returns and actual deltas. APIs collect all selected accrued amounts, not d−H.
4. Refresh C from source, book actual eligible interest, excluded rewards and any claim fees once. Attempt only downstream fee forwarding under the selected exception. Do not catch upstream required failure.
5. Recompute affected pricing, conversion index, d and current C after preceding state changes. Require now-held H≥d and H+C−d≥1 raw SY unit. Positive Cremaining can support the remainder when H=d. No percentage reserve floor or repeat-claim/redeem solver.
6. Hook calls `SY.redeem(receiver,d,NET_or_sNET,minNominal,false)`. It burns hook-held shares, not shares at SY. SY checks nominal amount only after external payout; enforce final actual receiver net delivery separately. NET route may process one epoch; sNET route does not. Preserve exact-output representability/residual limits already identified in plan v0.8, rather than silently dropping required routes.
7. Read actual SY debit and post-state C when redemption changes relevant index state; Hafter=Hbefore−actualDebit. Require coherent eligible Hafter+Cafter≥1. Do not fund an upfront shortfall with speculative future accrual generated by redemption; the pre-redemption checks must already pass.
8. Commit once, refund permitted unused input, full expected-token sync. Required failure rolls back input, upstream claim, burn, payout, epoch/cache/ledger and observations; only failed outgoing fee forwarding leaves a retained excluded payable on successful route completion.

NET pricing remains PLP/YT-derived even when this cash budget is small. Market incentive collection neither decrements position principal nor increases ordinary SY unless an actual eligible source receipt does. Actual owned-HLP realization/rollover remain distinct scopes with BasePoolMath modes, not a universal h/H funding shortcut.

## 9. Numeric boundary vectors — planned, not run

All values below are raw integer units except explicitly WAD indices/fees. Toy fee rates illustrate floors, not live oracle observations.

| Vector | Expected result |
|---|---|
| YT interest b=1000,j=W,k=2W,a=0,f=0.1W | delta500; fee50; net450 SY. Claim clears gross accrued, pays treasury50 and hook450. |
| Floor identity counterexample b=1,j=0.6W,k=1.5W | source delta=floor(1)=1; difference of independently floored principals gives1−0=1 here; use b=1,j=0.75W,k=1.5W for distinction: source floor(2/3)=0 versus1−0=1. Preserve source expression. |
| Fee floor gross19,f=0.05W | fee0,net19, not18. Gross20 gives fee1,net19. |
| Claim timing gross10+10 at f=0.05W | two separate claims net10+10=20; one combined gross20 claim net19. Forced timing can affect fee dust; local stale sums are not authoritative. |
| j=0,b>0 | initialize index only, no retrospective interest from genesis. |
| Cache storedW/current exchangeRate2W, already updated this block | k=W and no new interest this block; next uncached update can use2W. |
| Expiry firstPYIndex2W, live rate3W,j=W,b=1000 | user interest uses2W→500 gross, not approximately666; subsequent growth not user C. |
| Transfer b=1000 at j=W then k=2W | sender accrues500 before transfer; recipient receives YT with new checkpoint; sender retains500 gross claim despite zero YT balance. |
| H=100,C=450,d=549 using first vector | claim→H550,C0; redeem549→H1. YT/LP quantities unchanged. |
| H100,C450,d550 | reject complete drainage before claim; equality is not sufficient. |
| H=d,C=1 | no funding claim; remainder exists as eligible receivable. |
| H100,expected C450 but r449 and native claim cleared,d549 | H549,C0: reject zero remainder; do not fabricate C1=1. Whole operation rolls back. |
| External force-claim of450 | B increases450,C drops450. If later public pretransfer consumes450, do not also add inherited H450. Next YT claim can return0. |
| Market rewards totalActive100,receipt10,userActive40,index delta0.1W | user earns4 reward units before refresh; not10 and not a cash-interest SY claim. No YT interest fee on market payout. |
| Market totalActive0 with reward10 | lastBalance absorbs10 without index increment; next entrant cannot immediately claim the old10 via that update. |
| Empty SY reward list | YT rewardsOut empty; market list contains only controller PENDLE. Need actual address inequality against SY before claiming no collision. |
| Due NET epoch, YT claim | PY index may increase via projected exchangeRate; NetNet epoch number unchanged by claim. NET redeem then advances at most one; sNET redeem leaves it unchanged. |
| Upstream PENDLE transfer fails in required market phase | entire phase and earlier YT claim revert, not successful held-SY funding with ignored market failure. |
| Hook→feeTo PENDLE transfer fails after successful phase | interest funding can proceed; PENDLE stays booked excluded payable for retry. |
| Receiver old sNET holdings and earlier rebase | narrow payout window excludes old balance growth from new receipt; post-route sync alone is insufficient. |

Test real deployed proxy/production paths under separate authorization; use local reference differential tests and independently block-pinned fork parity as distinct evidence tiers. Add variants for `redeemInterest/redeemRewards` flags, user≠caller, historical expired YT, zero balance/accrued, repeated same-block claims, multiple series' fee floors, callback reentry and full rollback. No tests have been implemented or executed by this report.

## 10. Exact proposed plan addition (not applied)

Insert **§6.6 “Pendle claim phase and net-SY entitlement”** immediately after§6.5.8, with these normative paragraphs:

> Use the configured YT's `redeemDueInterestAndRewards(hook,true,true)` and configured market's `redeemRewards(hook)` as the direct combined collection phase, in that order, only for the selected validated series. These calls pay hook regardless of caller and have no partial-amount parameter. The equivalent router batch is `redeemDueInterestAndRewards(hook,[],[YT],[market])`; it supplies no return amounts and no shortfall selector. All required calls propagate failure. A selected interest-only variant must explicitly use YT's true/false flags and retain separate incentive-collection obligations; it must not silently catch or omit failed required reward collection.
>
> Source-map C from hook-owned YT userInterest, current YT balance, the actual cached/max PY index or frozen expiry index, and current factory interestFeeRate. Preserve `floor(b*(k-j)*1e18/(j*k))`, total accrued before fee, `floor(gross*feeRate/1e18)`, and native checked/cast bounds. Refresh stale claims after force-claims or transfers. Market LP incentives use gauge activeBalance/reward index and are not interest SY or withdrawable LP principal. Do not count market-held YT claims as hook entitlement.
>
> For the named external SY's empty reward surface, YT incentive tokens are empty and local market incentives comprise controller PENDLE only, subject to deployed binding verification. Verify token identities; do not manufacture same-SY incentive eligibility. Upstream reward/index/controller/treasury/user-transfer failure is a required claim failure, unlike the separately isolated hook-to-feeTo forwarding failure.
>
> H is recognized eligible held SY, not raw-minus-booked public surplus. Capture supported origin-independent pretransfer credit before sync. A force-claimed receipt can be public unbooked credit, but native receivable and cash/credit must be reconciled once. After an in-operation claim use actual receipt and actual cleared/remaining entitlement, not `C-=receipt` when receipt differs from extinguished claim. Recompute indices/fees/C/d and enforce held H>=d and total H+C-d>=1 before redeeming. Claims read/project SY.exchangeRate and may update PY caches without advancing NetNet epoch; the later NET SY redemption can advance one epoch, while sNET redemption does not. Re-evaluate affected post-redemption C without spending unmaterialized future claims.

Link source equations/entrypoint table and numeric vectors from this report; keep§6.5's existing final-redemption custody/minimum/receipt rules unchanged. Update the exact claim-selector row of§6.5.7 from “unmapped” to “local source composition mapped, configured deployment/state equivalence pending.” This does not close provider rounding, owned-HLP realization, exact-output residual rights, full L3 or G1. Moderator owns any final plan/tracker edits; this report makes none.

## 11. Finite remaining gaps, assumptions and confidence

**G1 binding/state evidence needed:** exact deployed market implementation and gauge variant; YT implementation version/cache behavior/factory/expiry; SY/PT/YT relationships and factory recognition; factory fee rates/treasury at observation block; gauge controller/ve token/PENDLE identities and code; same-token collision check; current userInterest/reward indexes/active balances/reserves; current SY proxy and NET staking equivalence/state. The local folder's V3 label and external SY exact-match do not certify these dependencies.

**Narrow source/integration work remaining:** chosen direct combined versus explicit interest-only scheduling in family implementation; exact existing operation receipt/force-claim reconciliation at callback-safe boundaries; fully mapped historical-series retirement; source-pinned controller variant and its upstream dependency graph; actual per-token failure-isolation implementation for downstream forwarding. The finite local graph above establishes no arbitrary external-dependency liveness guarantee. Full selected owned-HLP/Keep-YT/exact-output route composition remains separate.

**Assumptions:** ordinary configured SY transfers are the named static-share implementation; no unverified token address aliases; supported operations use validated series and hook beneficiary; no unstated call to staking by external controller/ve implementations. Claims about no NetNet epoch advancement are direct call-graph conclusions under those bindings, not universal claims about arbitrary malicious dependencies.

**Counterarguments addressed:** “market redeemRewards pays SY interest” is false for this reference/empty-SY-reward binding; “userInterest.accrued is all claimable” ignores current accrual and fees; “exchangeRate update rebases NetNet” confuses a view projection with stake/unstake; “force claim protects origin” conflicts with selected public pretransfer policy; “safeTransfer/minimum return proves net receipt” is not a balance measurement; “best-effort forwarding permits swallowing upstream failure” changes the selected exception.

**Confidence:** high for inspected entrypoints, caller/recipient rules, local interest/reward equations and transfer/checkpoint order; high conditional confidence for composition with plan v0.8's named SY; unresolved deployed equivalence and exact family receipt implementation. No full L3/G1 closure, passing tests, economic safety or profitability claimed. L1/L2 remain resolved; NN03 closed; G0/L4 unaffected. Submitted as Astra's original only, then stop for the moderator/human.
