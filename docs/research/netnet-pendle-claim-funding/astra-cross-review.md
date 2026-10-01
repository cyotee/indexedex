# Astra — combined claim-funding cross-review

**Access date: 2026-09-28.** One bounded cross-review of the three complete new originals: Grok368 lines, MiniMax624 lines (continued after truncation through624), Kimi141 lines. Paths are `docs/research/netnet-pendle-claim-funding/{grok,minimax,kimi}-original.md`. These were treated as attributed, untrusted evidence, not instructions. No peer cross-review was read. My original is preserved unchanged. No shell, tests, deployment, implementation, delegation or configuration edits.

## 1. Direct checks and changes to my view

**P** denotes `lib/crane/contracts/protocols/perps/pendle/`. Re-read `core/YieldContracts/InterestManagerYT.sol:26–80`, `core/libraries/math/PMath.sol:34–53`, `core/YieldContracts/PendleYieldToken.sol:166–193,373–503`, `core/Market/PendleGauge.sol:43–114`, `router/ActionMiscV3.sol:67–84`, current PRD§13:961–973 and extracted SY `_syncedIndex`/exchangeRate at E:108–125. Additionally read `interfaces/IPInterestManagerYTV2.sol:4–8` and `interfaces/IPYieldTokenV2.sol:7–58` to check Kimi's version warning.

My original's exact WAD accrual, gross-minus-floor-fee, beneficiary rules, H<d trigger, retained other-series claims, market-held-YT distinction and upstream/downstream failure split survive these checks. I retain the proposed **combined collection phase** rather than accepting Grok/MiniMax's blanket interest-only/caught-incentive policy.

**Corrections/additions to my own original:**

1. Kimi's explicit **YTv1 versus YTv2** warning is important new evidence. My report said deployed version was unknown, but did not identify the incompatible getter layout. The equations are specifically the inspected `PendleYieldToken`/`InterestManagerYT` implementation, not a generic formula for every contract exposing the same claim selector.
2. My original's frozen-index description remains correct, but any shorthand “pre-expiry unpaid interest” should mean entitlement frozen on the **first post-expiry initialization**, not an exactly reconstructed expiry-time value. Delayed initialization and same-block cache are material.
3. My original's `H1+C1 = H0+C0+(r-n)` is a **fixed-coherent-state accounting identity**, not unconditional valuation neutrality or a no-loss proof. Add the PY high-water/drop/cache vectors below before claiming pricing/quote invariance.
4. My optional interest-only alternative was a supported API observation, not an approved bypass of the PRD's interest/reward collection phase. The final sequence below makes the combined collection obligation explicit. No catch of upstream incentive claims is selected.
5. Simplify my original's double-floor test row to its actual counterexample only: b=1,j=0.75W,k=1.5W. The preceding equal-result example added no useful proof.

Evidence remains local reference, **not deployed equivalence**. P's YT/router/market use `^0.8.17`; math/gauge/interfaces use `^0.8.0`. External SY compilation identity remains chain4663 proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`, service implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, exact-match47105638, solc0.8.30+commit.73712a01/optimizer1,000,000/Cancun/viaIR=true. URL <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources> was consulted through the local extract, not freshly fetched. No new external documentation claims or Context7 lookup needed.

## 2. Formula disputes — source wins

Let W=10^18; b raw user YT balance; j stored user index; k the **execution interest index**; a stored gross accrued SY.

```text
delta = 0                         if j==k or j==0
delta = floor(b*(k-j)*W/(j*k))     otherwise
gross = a + delta
fee = floor(gross*f/W)
netClaimable = gross - fee
```

For j==0, source initializes index to k, not historical interest. For j==k it leaves accrual unchanged. In either case the claim still pays any **already stored a** after fee. “Index unchanged ⇒ total claim zero” is false without a==0. MiniMax:136,459–460 confuses no *new* accrual with no payout.

### WAD factor and mulDiv

Agree with Grok:139–151 and retain Astra. Kimi:36,60,93 omits the WAD numerator; MiniMax repeatedly omits it in prose/equations despite quoting the correct source at119. `PMath.divDown(x,y)` multiplies x by W before division. b=1000,j=W,k=2W yields500 raw SY, not0.

No mulDivDown routine is called at this source line. Mathematically it is a single floor on the full expression, **within the original checked-intermediate domain**. A full-width mulDiv implementation used to calculate a view must not advertise success outside the source's b*(k−j), product*W, j*k, uint128 cast/addition and fee-product domain. It is not `floor(bW/j)-floor(bW/k)`, nor an arbitrary two-stage mulDown/divDown chain. b=1,j=0.75W,k=1.5W gives source0 versus difference-of-floors1.

### Fee rounding

Retain Astra/Grok/Kimi's **gross−floor(fee)**. MiniMax:238–244 reverses the dust effect and its numeric table mislabels1e17 as1%. For integer gross g and0≤f≤W, net equals `ceil(g*(W-f)/W)`, not generally its floor. g=19,f=0.05W gives fee0 and net19, whereas floor(g*0.95)=18. g=10,f=1e17 gives fee1/net9; g=99 gives fee9/net90; g=100 gives fee10/net90. No fractional raw “60.6 wei” gross is a source integer.

C must be **current NET-of-fee SY per actual source**, not stale userInterest.accrued or gross with a promised later adjustment. Kimi:37's “or gross” alternative is not interchangeable at the strict funding boundary. MiniMax:305,313,318 is incorrect. If C contains net n and claim clears that entitlement, remove n, not n+fee (Kimi:63). If actual receipt differs from extinguished entitlement, recompute native remaining claims; do not leave the missing delta as a fictional receivable.

## 3. PY index, ratchet, cache, expiry and chronology

Before expiry: cached stored value if enabled and already updated this block; otherwise checked uint128 `max(SY.exchangeRate(),stored)`. After expiry: frozen firstPYIndex, initialized through the first post-expiry `updateData`/transfer path. A second `pyIndexCurrent()` cannot force a refresh past an active same-block cache; reject MiniMax:216/222's suggested refresh guarantee. This is not simply `_syncedIndex()*1e9` in all states.

The named SY exchangeRate reads/projected `_syncedIndex` without staking calls. Claim can write PY cache and pay SY without advancing NetNet epoch. Retain all originals' conditional call-graph finding, but keep external controller/ve/token implementations as bindings to verify, not universal non-reentrancy/liveness assumptions.

### No unconditional no-loss or valuation-neutrality theorem

Kimi:47,75,118 says ratcheting is no-loss and claims necessarily leave y/d/pricing unchanged; MiniMax:214 equates SY projection and PY claim index. Those conclusions are too strong.

- Stored PY index can exceed current SY exchangeRate after a rate/projection drop. The max preserves the high-water mark; claim accrual then uses that mark, while executable SY redemption uses its current branch index.
- `_syncedIndex` itself is not a monotone state variable: before processing, its projected result depends on supply, queued profit and circulating balance; changes in those inputs can change a later projection even without a committed index decrease. Actual reachability/cost of such a trajectory needs analysis, not an assertion of exploitation or impossibility.
- Same-block cache can preserve an earlier PY value while SY execution changes. Frozen expiry index may also differ from live execution rates.
- Reconciliation from stale/gross C, force-claims, fees or source-version mismatch changes the eligible budget/pricing. A claim phase can also update market gauge active balances and reward state.

**Narrow statement that is valid:** with accurate pre-claim *net* C computed from the exact same state/cache/fees/rights, exact measured static-SY receipt r=n, no other transitions and unchanged provider rate, replacing C by H preserves that SY book's total and its deterministic valuation. The isolated current-SY YT claim does not inherently change Ic or Ip. Ratchet risk does not prove that isolated claim mutates SY rates; it defeats the broader assertions that current rate equals claim index or that all composed quotes are value-invariant. Keep the planned recomputation and source-state checks.

NET redemption can process one overdue epoch and make the next uncached pre-expiry projection/claim larger. Grok:229 and MiniMax:428 must not hard-code Cafter=0 for the entire portfolio or assume redemption cannot create new current claimability. Source C for the just-claimed YT is zero immediately at the settled index, **not necessarily after subsequent state changes**. Other YTs' claims never vanish merely because one was settled.

## 4. Transfers, expiry and market/gauge rights

Retain Astra's donated/transferred market-held-YT case; reject Kimi:31/85's categorical “does not exist” and narrow Grok:80. The market normally reserves PT+SY, but can receive ERC20 YT. In `InterestManagerYT` the excluded `address(this)` is **the YT contract**, not the market address. YT claim(user=market) pays market, not hook; no inspected method reallocates that right to hook merely because hook owns LP. Market excess SY is subject to treasury skim, not ordinary cash funding.

MiniMax:293–295 claims transfers zero/pay accrued interest. False: `_beforeTokenTransfer` checkpoints reward/interest into their mappings; it does not invoke payout. Sender retains accrued rights, recipient's own existing accrual is also retained, and future accrual reflects changed balances. Post-expiry transfers are not banned by mintPY's notExpired modifier (MiniMax:234). Claims still apply the frozen index and payout **interest delta plus stored accrued**, not `assetToSy(frozen,balance)` principal.

Post-expiry YT incentives still pay the reward fee: `_doTransferOutRewards(...false)` calls `__doTransferOutRewardsLocal`, which reads rewardFeeRate and applies the fee regardless of that external-claim boolean (`PendleYieldToken:421–469`). MiniMax:161/233/467/617's no-fee claim is wrong. Its:160/400 also imports the market's gauge-controller call into YT `_redeemExternalReward`; YT:475–476 calls **SY only**.

`market.redeemRewards(user)` is public, with payout to user. It checkpoints accrual at **old activeBalance**, then recomputes that user's ve-adjusted active balance and totalActiveSupply, then pays. Force-claim can therefore change future reward weight without transferring LP. “No harm/front-running possibility” (MiniMax:277/451/600) is unsupported; recipient protection alone is not a timing/economic neutrality proof. Kimi:55/108's “pro-rata all LPs” must be “pro-rata active reward shares,” with floors/cache/zero-total-supply behavior. There is no YT factory reward fee on this market payout; reject MiniMax:177/264/517.

## 5. Calls, booleans and failure isolation — substantive dissent

The local router batch **always** invokes YT(user,true,true), then market.redeemRewards(user), after any SY calls. It cannot be described as rewards-only for YT (MiniMax:97). Direct true,false is supported, but not guaranteed independent of rewards:

- YT always runs `_updateAndDistributeRewards(user)`; pre-expiry it can call SY.rewardIndexesCurrent even when reward payout is disabled.
- First post-expiry initialization calls `_redeemExternalReward()` and freezes reward indexes **before** the claim body, even on true,false.
- The current named SY has empty/no-op rewards, but that is a verified-binding condition, not a generic property of the selector.

**Reject Grok:68,210,243–250 and MiniMax:388–391 as normative recommendations.** Upstream incentive-claim failure is not the downstream forwarding exception. PRD:415 requires collection of available interest/rewards when short; PRD:971–973 limits nonblocking treatment to outgoing fee-reward delivery while required upstream dependencies function. An incentive transfer failing inside YT/market can revert a required combined phase without contradicting that policy. Catching an isolated upstream reward claim would broaden the exception.

I retain direct `(true,true)` YT plus market claim as a concrete faithful combined phase, no catches. For this exact empty-YT-reward binding true,false and true,true have the same token payout, but true,true still follows its additional factory getter path; do not claim identical failure/gas behavior universally. Interest-only could be explicitly scheduled with all incentive obligations retained, **not silently selected solely to evade a broken required claim**. This remains disagreement with Grok/MiniMax, not a discovered source ambiguity. Kimi correctly distinguishes fatal upstream from nonblocking hook forwarding.

Same-token absence is **conditional**: empty SY rewards means empty YT rewards, and market rewards are the controller-designated PENDLE address. Prove that address differs from SY before stating no SY-incentive collision; names do not prove inequality. The gauge reward accountant assumes its entire reward-token balance is reward inventory, so PENDLE==reserve SY would require specific compatibility review. No blanket incentive eligibility follows. This preserves my original qualification over all three peers' stronger absence claims.

## 6. H/C and force-claimed unbooked surplus

H is recognized eligible held SY, not raw minus the entire booked reserve. C is source-specific current net receivables. U=max(raw−booked,0) is separate origin-independent supported pretransfer availability.

**Reject Kimi:64–71's booking BEFORE available-credit calculation.** It contradicts its own acknowledgment of L2. Capture supported declared public credit against U before syncing/bookkeeping that would remove it; no provenance exception for forced interest receipts. A caller who consumes those units is credited according to that route, not simultaneously as inherited interest cash. Refresh upstream C to prevent duplicate entitlement. This is neither automatic appropriation of all surplus as H nor a new witness/receipt-provenance requirement.

MiniMax:319/551 uses H+C sufficiency as the **no-claim trigger**. Wrong: claim iff H<d after aggregate viability checks. H=8,C=3,d=10 needs a claim even though total11 is sufficient. H=d,C=1 needs no funding claim. Raw physically held fee payables do not change either result.

Grok's source-scoped C:=0 wording is generally sound immediately after settling one YT; its aggregate shorthand must preserve Cother. Kimi must not subtract c+fee from a net C. My original preserves actual cleared entitlement versus actual receipt and other-series claims; retain it. Previously force-claimed cash may be recognized once after supported credit handling, with attribution rules, not permanently forbidden from all later eligible accounting as MiniMax:335 suggests.

## 7. Final exact safe sequence — specification, not execution

For the inspected YTv1-shaped binding and the current combined collection requirement:

1. Validate configured series/beneficiaries/limits and protect callbacks; capture valid public pretransfer U/declared credit **before sync**. Execute required existing epoch/TWAP/expansion pre-steps. Reconcile force-claims with current source state and credit consumption once.
2. For every source included in this same-SY funding budget, compute k by exact max/cache/frozen rules; derive gross and **net** C_i with source fee floors. Keep H eligible/excluded roles separate. Historical different-SY claims are not addable native units without a separately specified conversion.
3. Quote y in the existing Weighted coordinate/native fee order; derive raw d independently via plan§6.5's actual output hops/index. Require valid domains and d<H+ΣC_i. If H≥d, skip funding claim. No reserve-percentage floor.
4. If H<d, claim the fixed selected validated series phase: `YT.redeemDueInterestAndRewards(hook,true,true)` then `market.redeemRewards(hook)`. No approvals/position transfer needed, no shortfall amount argument, no catch. A mapped router batch with empty sys and these addresses uses identical beneficiary/flags; required multicall allowFailure must be false. No implicit unbounded historical scan.
5. Measure each actual receipt separately. Replace only each settled source entitlement; preserve other remaining C_i. For one claim net n and receipt r, H'=H+r and C'=Cother+newly recomputed residual, not C−r if source cleared n. Book non-interest receipts as excluded payables; do not mislabel them as SY interest.
6. Attempt downstream forwarding of attributable fee tokens to current feeTo in the selected isolated manner. Only this outgoing transfer failure is retained for retry. Do not catch YT/market/controller failures under that name.
7. Recompute affected source/price/provider/index/d state. Require H≥d and H+ΣC_i−d≥1. If still short, revert; no retry solver, second guessed redeem, principal liquidation or partial payout.
8. Hook calls `SY.redeem(receiver,d,tokenOut,minNominal,false)`. Check actual SY debit and final recipient net receipt, input maxima and exact-output representation/residual rules; nominal SY min alone is not enough. NET may process one overdue epoch; sNET does not. Use a narrow/rebase-adjusted receipt window.
9. Re-evaluate affected post-redemption C under actual cache/expiry rules; require eligible post H+C≥1. Do not have used speculative future accrual to satisfy the earlier pre-redemption checks. Refund authorized unused input, then full expected-token synchronization. Any required failure unwinds inputs, claims, payout/burn, epoch/cache, ledgers and observations.

No ordinary PLP/YT sale, new fee, doubled Weighted/SE fee or universal owned-HLP shortcut is introduced. The phase is source-compatible **conditional on G1**, not certified production-safe merely by consensus.

## 8. Numeric vectors — unexecuted corrections/additions

| Vector | Required result |
|---|---|
| WAD accrual b1000,j=W,k=2W,a0,f0.1W | delta500,fee50,C450. Missing WAD would incorrectly give0. |
| Single floor b1,j0.75W,k1.5W | delta0; difference of rounded principal equivalents gives1 and is wrong. |
| Stored a7,j=k,f0 | claim7 despite zero new accrual. j0 initializes index with delta0; payout of pre-existing a still follows source. |
| Fee g19,f0.05W | fee0/net19, not floor(net factor)=18. g20 givesfee1/net19. |
| Two claims g10 each,f0.05W | combined net20 versus one g20 claim net19; fee timing not universally neutral. |
| H8,C_A3,C_B4,d10; settle A only | H11,C_B4 remains; post redemption total5, not1 or0. |
| H8,C3,d10 | claim required despite aggregate11; H10,C1,d10 skips claim and retains claimable1. |
| Net n3, actual receipt2 and claim source cleared, H8,d10,Cother0 | H10,C0 fails remainder; no invented C1 from short receipt. Full rollback. |
| Pre-existing force-claim3 creates raw−booked3; eligible declared credit3 | capture credit before sync; native claim cleared; do not also create H3/C3. |
| Rate drop toy: stored PY2W,user j=W,b1000; live SY rate1.5W,fee0 | actual max givesdelta500; using live rate alone gives333. Claim itself need not change live rate; claimed SY's live value is not a guaranteed old high-water value. |
| Cache storedW already updated, live rate2W | current block delta0 for jW; another pyIndexCurrent cannot force refresh. Later uncached claim may accrue500 for b1000. |
| Expiry freeze2W, live3W,user jW,b1000 | delta500 under frozen2W, not666; first frozen value is initialized after expiry, not reconstructed exactly at expiry. |
| Market old active100, LP100, no ve boost at claim | pending rewards earned with100; then active refreshes to40. Force-claim can change future weight. |
| YT transferred to market | market can accrue as YT user; claim pays market, no automatic hook right. |
| Interest-only first post-expiry with reverting SY.claimRewards | still reverts via initialization. false reward flag is not universal upstream isolation. |
| Required market reward claim reverts | prior in-transaction YT collection rolls back. Hook→feeTo transfer alone fails | retain excluded payable and continue if all required steps succeed. |

Toy rate/index trajectories are arithmetic tests, not proof of a realizable profitable attack. No tests were written or run.

## 9. Resolved source mapping versus remaining gaps and dissent

**Resolved for inspected implementation:** selector/caller/recipient and boolean behavior, WAD accrual/fee floors, first-index handling, max/cache/expiry, transfer checkpointing, market active-balance incentive mechanics, and fatal upstream versus isolated downstream failure boundary. MiniMax's incorrect formulas and ledger/call sequence do not justify its claimed L3/NN07 closure.

**Important source/version gap accepted from Kimi:** `IPInterestManagerYTV2.userInterest` returns `(uint128 lastInterestIndex,uint128 accruedInterest,uint256 lastPYIndex)` while the inspected V1 body stores `(uint128 index,uint128 accrued)`. V2 preserves the claim signature (`IPYieldTokenV2:36–38`) but that does not establish the same interest algorithm. No V2 implementation body was inspected. If configured YT is V2, obtain that actual body and derive its computation before using this V1 C formula. Do not decode the first two words under the wrong semantic names merely because an ABI call can succeed.

**G1 remains:** actual YT/market versions/code identities, all relationships and observed cache/expiry/factory fee/treasury state, controller/ve/PENDLE identities and transfer behavior, NetNet/SY binding and balances. Full provider rounding, owned-HLP realization and exact-output residual/domain composition remain beyond this local claim edge. No full L3/G1 closure. G0/L4 distinct; L1/L2 resolved and NN03 closed.

**Remaining dissent:** Grok/MiniMax's broadened caught-upstream-reward policy is not accepted; Kimi's automatic pre-credit force-claim booking, categorical no market-held YT, missing-WAD equations and unconditional valuation neutrality are not accepted. All three support the core recipient/claim selector distinction, but agreement does not validate their disputed additions. Confidence is high in the source corrections, conditional in deployed applicability, and explicitly limited on economic consequences of PY ratchet/projection trajectories. Original preserved; this is Astra's single combined cross-review and final stop for moderator/human.
