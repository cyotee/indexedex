# Independent T5-EGRESS correction verification

Date: 2026-11-10.

**AdversarialVerify: needs-fix.**

R2 fixes the original unit mismatch and retained-claim ownership arithmetic
under its proposed wide consumers, and its external-adapter custody step fixes
the ticket sender mismatch. It does not yet establish a compliant, complete
implementation boundary. It permits delivery of newly issued reward receipts
before activation without an admitted exception to the payout rule, and its
fresh market factory is not sufficient to authenticate the market to the
unchanged gauge controller. The latter can prevent the first LP mint, before
the purported supported market exit is reachable.

These are construction findings, not deployed exploits or E5 acceptance.
No owner question is answered. E1/E2, actual recovery E3, BOOTSTRAP-AUTH and
runtime E4/E5 remain open. This report authorizes no implementation,
deployment, shared-source edit, expanded protocol rollout or unrelated work.

## 1. Findings

### N1 - Preactivation reward-token delivery is not reconciled with the payout requirement

**Severity: high; normative integration blocker.**

**Location:** `egress-contract-r2.md:219-263` (section 4.3),
`:305-376` (sections 5.1-5.2), and section 1's replacement of native reward
claims with RG materialization.

The governing Plan is
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`.
MIG-P08 at line 24 requires activation for **every new-instance reward payout**.
Line 73 explicitly says that sending fee/creator staking receipts is already
a payout and blocking their subsequent redemption is insufficient. Section
4.1, line 157, and task 5, line 414, require protocol custody of those
attributed rights rather than early receipt delivery. Section 8.2, line 522,
prohibits Stage-1 routes paying new-instance rewards.

R2 changes that boundary, rather than merely changing a stored index:

1. `claimRewards(a)` is callable by anyone before activation.
2. It consumes the beneficiary's domain-2 credit and mints an actual ERC20
   reward token to that beneficiary.
3. The concrete YT reward consumer transfers that token to the old user and
   treasury through its existing reward-payment route. Its first expiry
   checkpoint also materializes it during Stage 1.
4. The recipient now holds newly delivered, transferable reward receipts.
   Only the subsequent RG-to-sDETF redemption checks activation.

**Independent witness:** ten principal units plus ten funded reward units,
at production Q, leave `5*10^36` reward gons after the principal exits. At a
10% YT reward fee, before activation the construction newly delivers
`4.5*10^36` RG to the user and `0.5*10^36` RG to treasury, while clearing the
YT's domain-2 credit. The user can transfer all its RG to another account.
Native redemption is correctly rejected while locked; after activation the
assignee receives 9 sDETF and treasury receives 1, both actually unstaked in
the model. Backing ends at zero. See
`evidence/egress-correction-verification/audit-session.mjs`,
`firstPayoutAndReceiptBoundary`, and `results.md`, supplementary result.

This is **not** a demonstrated preactivation native-DETF drain. It is a
demonstrated newly issued reward-token payment at the boundary that r2 says
is the standard reward contract. The distinction matters:

- Transferring an existing NFT/right, or owner-authorized reassignment of
  already attributed locked gons while custody and the payout gate remain
  intact, is not rejected by this review.
- R2's permissionless issuance/delivery through the standard reward claim
  route is not established as that permitted assignment merely by calling RG
  a "right" or by keeping its native redemption locked.
- No admitted requirement was found that exempts this newly delivered ERC20
  reward receipt from MIG-P08. The explicit receipt-delivery prohibition
  prevents assuming that only underlying-native redemption counts as payout.
- Domain-1 DETF fee/creator allocations remain escrowed in r2; this witness
  does **not** claim those allocations were converted to RG. The witness's
  fee is the separate, source-defined YT treasury fee. The all-rewards rule
  still applies to the newly earned SY rewards from which it is paid.

**Required correction:** reconcile standard-consumer accrual/expiry and
retained ownership with activation-gated reward delivery inside the
construction. Keep successful mature principal access and owner-authorized
locked-right transfer; do not solve this by disabling all claims/exits or
relabeling reward issuance. Retain accrued beneficiary obligations in
protocol custody until permitted payout, and specify the corresponding
consumer settlement contract. This is enforcement of the admitted
requirement, not a request for a new owner-policy answer.

### N2 - Fresh market registration does not establish gauge-controller admission

**Severity: high; concrete caller/deployment blocker.**

**Location:** r2 sections 5.1, 6.2 and 8, especially
`egress-contract-r2.md:327-334,418-451,549-557`.

Source aliases in this report are relative to the phase-03 worktree:

- `P/` = `lib/crane/contracts/protocols/perps/pendle/`
- `C/` = `contracts/vaults/detf/common/`

**Read source chain:**

1. `P/core/Market/v3/PendleMarketFactoryV3.sol:39-63,69-101`
   binds a gauge controller at factory construction and passes it to every
   market created from the selected split code. Creating a market records it
   only in that factory's own `allMarkets`; `isValidMarket` reads that set
   at `:113-116`.
2. `P/core/Market/v3/PendleMarketV3.sol:96-110,347-356` invokes the gauge
   hooks during the initial reserve/user LP mint.
   `P/core/erc20/PendleERC20.sol:211-220` runs the before hook before
   crediting LP supply.
3. `P/core/Market/PendleGauge.sol:84-86,109-114` harvests SY and calls
   `gaugeController.redeemMarketReward()`. The source reward manager does
   this on the first update of a block,
   `P/core/RewardManager/RewardManager.sol:27-35`. R2 explicitly preserves
   once-per-block harvesting for unrelated PENDLE.
4. `P/LiquidityMining/GaugeController/PendleGaugeControllerBaseUpg.sol:42-77`
   authenticates the **market caller** using its cache or four immutable
   factory registries. Failure reverts `GCNotPendleMarket(msg.sender)`.
   The guard is applied at `:85`, before the zero-reward handling at
   `:89-93`.

**Counterexample configuration permitted by r2's stated boundary:**

```text
Fnew = the required fresh local market factory
GC = an existing source-compatible controller
GC's four factory registries do not include Fnew
M = Fnew.createNewMarket(localPT,...)
Fnew.isValidMarket(M) = true
GC.isValidMarket(M) = false
each GC factory's isValidMarket(M) = false
GC rewardData[M].accumulatedPendle = 0
```

The first otherwise valid LP mint takes the above hook chain and reverts
`GCNotPendleMarket(M)`, even with no PENDLE emissions. The complete
transaction, including any preceding SY reward harvest, rolls back. A
standalone zero-balance `redeemRewards(user)` can reach the same rejection.
Local adapter validation against Fnew does not authenticate M to GC.

The independent predicate/custody witness reproduces that result with four
separate rejecting registries and a locally registered market. The
counterfactual admitted control pays 5,000 principal and 9,000 correctly
owned native rewards; it does not pretend that changing a model set is an
available controller registration method.

**Impact:** the advertised fresh market graph has no demonstrated usable
initialization/LP-transfer/reward path for this valid dependency selection.
Both market LP exit and a complete reachable market PT-swap lifecycle remain
unproved. R2's 360 arithmetic sequences and source LP output ratio do not
exercise this admission boundary.

**Required correction:** specify and prove admission of the fixed fresh
factory/market by the actual selected gauge controller, through an existing
authorized mechanism, as part of the complete local integration contract.
Record its exact dependencies and initialization/caller identities. Do not
silently skip PENDLE harvesting, catch the rejection, alter shared controller
source, assume an external governance action, or introduce an unrequested
controller/voting deployment. If that cannot fit the bounded correction,
revise the reward integration rather than claiming market support.

This finding is a source-backed counterexample to completeness, not a claim
about any particular deployed controller or a prediction that every possible
new controller configuration fails.

## 2. Disposition of all original findings

| Original finding | Independent r1 reproduction | R2 disposition |
| --- | --- | --- |
| F1: native over-accrual | Ten shares, `k=Q/2`: source `floor(10*(Q-k-1)/10^18)` records `4,999,999,999,999,999,999` native sDETF against 10 funded units. | **Arithmetic repaired, compatibility conditional.** `I=1+W*(Q-k)` yields exactly `5Q` native RG, worth 10 native sDETF at this k. The separate first-payout witness actually pays 9+1, not just a valuation. Stock consumers reject the widened index. N1/N2 prevent accepting the replacement integration. |
| F2: lost retained claim | A perfect 10-native old-user claim survives PY burn, but r1 moves its backing with SY: old backing 0, new-holder backing 10. | **Ownership arithmetic repaired.** R2 settles all old SY reward gons before transferring only principal. Ten principal units leave to another receiver, which gets zero old reward; the old user retains `5Q`. Funding 10 after the principal exit lowers k to Q/4; the old user actually receives and unstakes 20, once. Final backing 0. N1 concerns payout timing, not a newly found duplicate in these equations. |
| F3: operator mismatch | Direct pull creates `(router,user)`, while old redeem checks `(router,router)`. YT/market pushes to SY create `(YT,YT)` / `(market,market)`; neither old redeem nor `redeemInternal(source,...)` authorizes the router. | **Ticket construction repaired for the specified local adapter.** Upstream sends to external R, then R transfers its received principal to SY and consumes `(R,R)`. Direct pull consumes `(R,user)`. Stock routes still fail, explicitly. Market completeness remains blocked by N2; no generic external-router acceptance is claimed. |

Source contracts, not the bare SY interface, supply the consumer arithmetic:

- `P/core/RewardManager/RewardManagerAbstract.sol:16-29,35-64` defines
  sentinel 1, pre-balance accrual and uint128 stored index/accrued fields.
- `P/core/libraries/math/PMath.sol:20,34-38,48-52,175-177` defines WAD
  multiplication/division and checked uint128 conversion.
- `P/core/YieldContracts/PendleYieldToken.sol:479-503` computes reward shares
  from SY-equivalent YT balance and checkpoints before YT mutations.
- `P/core/YieldContracts/InterestManagerYT.sol:63-79` and
  `P/core/StandardizedYield/SYUtils.sol:7-20` give zero interest and 1:1
  principal at a constant W rate. That constant rate remains **not rejected**.
- `PendleYieldToken.sol:124-153,317-339,421-476` separates principal burn
  from retained user reward payment; the latter pays native units of the
  listed reward token.

R2's production-Q index is
`500000000000000000000000000000000000000000000000000001`,
which cannot fit uint128. `5Q` itself does fit uint128; this review does not
repeat the producer's corrected evidence mistake about that amount. Larger
ordinary accruals can also overflow the stock accrued field. The wide local
implementation is a proposed replacement, not an unchanged consumer.

## 3. Caller and payment coverage

The ledger/caller evidence is arithmetic and symbolic caller identity, not
an EVM substitute. Every positive row below includes principal payment and
the owned funded reward payment, where nonzero rewards exist.

| Graph | Actual source identities and proposed boundary | Observed independent result |
| --- | --- | --- |
| Direct pull | `ActionBase.sol:94-103` pulls user -> SY as router. R instead finishes with `redeemInternal(user,...)`. | Principal 5; old-user reward 10. Wrong input owner, wrong ticket operator/owner and min-output failure reject. Two old adapter shares survive. |
| YT upstream push | `ActionMiscV3.sol:39-46` / `ActionBase.sol:117-129` / `PendleYieldToken.sol:317-339`: actual sender is YT. R uses explicit-amount `redeemPYMulti([R],[py])`; YT sends to external R; R creates and consumes its own ticket. | Principal 5; retained old-user reward 10. Wrong caller/owner and minimum rollback; old adapter shares preserved. Full old-user principal exit and later 20-unit reward also pass independently. |
| Market LP upstream push | `ActionAddRemoveLiqV3.sol:307-323` currently requests SY at SY. R requests SY at R. `PendleMarketV3.sol:129-145` is the sender; `MarketMathCore.sol:153-175` determines SY/PT outputs. | **Conditional on gauge admission:** 5,000 principal, 9,000 user reward, with locked minimum-LP rewards kept separate. Wrong caller/owner, minimum failure, prior adapter inventory and modeled reserve rollback checked. Actual fresh-factory graph fails N2. |
| Market PT upstream push | `ActionSwapPTV3.sol:43-55` requests SY at SY; `PendleMarketV3.sol:159-183` sends it and optionally invokes caller callback. R changes receiver to R and supplies empty callback data. | Caller/ticket reasoning is valid for an actual returned output. **No independent successful source-math swap execution:** logarithmic pricing/state updates were read at `MarketMathCore.sol:180-383`, not replaced with an LP ratio or invented quote. A complete fresh-market lifecycle is also blocked by N2. This row is not PASS. |
| Router-funded self-deposit | R actually funds `SY.deposit(SY,...)`, creating `(R,R)`; existing self inventory is excluded. | Supplement pays 5 principal and, after funding during transit, 5 native reward to the input user. Wrong operator/owner, input/output minima, approval cleanup, gated payout and full rollback pass in the model; final backing/tokenized supply 0. |
| Two owners / two operators | Alice's two 2-share tickets belong to R1/R2; Bob's 6-share ticket belongs to R1. | Attempt to borrow from another ticket rejects. Ten principal paid; Alice/Bob later receive 4/6 native rewards; final backing 0. |

Input authority is the real caller's token allowance, not a free owner argument.
SY uses Crane's maximum-allowance decrement
(`lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:157-166,297-301`).
Pendle PT/YT/LP preserve maximum allowance
(`P/core/erc20/PendleERC20.sol:276-285`). Finite symbolic allowance checks do
not prove the real contracts implement either behavior; the adapter must keep
this distinction.

No generic right to spend `balanceOf(SY)` is restored. YT or market sending
straight to SY still cannot lend its ticket to R. An arbitrary payout receiver
does not authenticate ownership. Old adapter shares and prior pending rights
are outside the operation's output/transit budget.

## 4. Independent arithmetic and adverse-state coverage

Complete execution receipts and limitations are in
`evidence/egress-correction-verification/results.md`. The four pre-existing
verifier modules were completely inspected, independently executed and not
modified; this session added `audit-session.mjs`. No producer model is imported
by these verifier modules.

| Concern | Evidence-backed coverage |
| --- | --- |
| Changed SY semantics | 608 independent sequences at Q=1000 and production Q, principals 1..16, every zero/full/intermediate split, two funding magnitudes, mixed deposits, return transfers and repeated indexes. Total successful native principal 8,352; native rewards 4,912; 1,134 nonzero owner remainders retained. Old r1 SY cases are not reused as proof of the changed ownership boundary. |
| Initial sentinel / late cohort | Index starts at 1 with zero initial accrual. New users checkpoint at current index before balances increase. Late Bob gets no prior accrual. Alice's old claim survives transfer; fee plus user RG equals materialized backing. |
| Retained claims / expiry | Full principal departure leaves the old user's claim funded. First expiry reserves actual RG; later newly earned RG goes to treasury, not appreciation of reserved RG. Principal 10 still exits; old user/treasury later actually receive 14/4 native units; fractional RG remains owned. |
| Consumer fractions | Source market allocation uses active supply; two nondivisible deltas leave per-user numerators `W-1` and `W-2`. Their consolidation supports one whole gon, retaining the remaining numerator and actual inventory. No old-user numerator is deleted at zero shares. |
| Same-block market changes | Two deltas 4 and 6 accrue 10 under r2's proposed RG cadence; the old cached checkpoint exposes only 4 before the modeled balance change. This supports the necessity of a cadence difference, not runtime proof of the fork. PENDLE cadence must remain separate. |
| Native payout dust | A 776-gon residual is retained, transferred and later pays 2 after real funding. At fixed k, full payable redemption burns only `floor(g/k)*k`; immediate repeat is zero. |
| Roles / owner changes | Old same-address fee/creator allocation remains 1,581 gons after subsequent roles change; activated release pays 4, leaves 85, repeats zero. This is domain 1, not YT's current-treasury fee. No activation scan or owner retargeting is introduced. |
| Multiple internal balances / approvals | Independent owner/operator tickets conserve principal; wrong pair cannot use aggregate self inventory. Max SY approval decreases by the spend. New self-deposit uses actual funding and clears its temporary approval. |
| Transit reward ownership | Five current-operation shares and two old adapter shares produce separately attributed transit gons, not one total pending-balance delta awarded to the new caller. Supplement adds a nonzero native payout witness. |
| Rollback | 608 full-model minimum failures, plus caller and supplementary failures, restore modeled funding, balances, allowances, reserves, consumer accounting, tickets, RG and outputs. This assumes EVM atomicity and uncaught failure propagation; it does not prove deployed propagation. |
| Saturation / widths | At k=1 another 50 funding units remain canonical native dust. All issued gons can exit without resetting k. Full-precision reward quotients fit where naive intermediate multiplication overflows. No all-lifetime uint256 proof is claimed. |
| Unchanged principal/bond equations | Original independently verified mature-principal/rebase/exit/activation evidence stands: 10 principal, separate original-bond/post-claim rewards 25/5, total 40 funded units paid. R2 leaves these equations unchanged. The new run checks their algebra, not a fresh actual bond lifecycle. |
| Eligibility / ordinary products | R2 expressly leaves legacy eligibility and domains 0/1 unchanged. No original-payer, wrapper-only ancestry, mutable approver or ordinary-product substitution was added by this verifier. Mandatory local new-instance consumers are an integration restriction, not closure or narrowing of legacy E1/E2. |

The funding and backing oracle was checked directly against
`C/core/DETFFundedStakingMath.sol:46-94` and
`C/claimToken/DETFFundedStakingRepo.sol:109-139,185-201`.
R2 preserves `B=floor(T/k)+Da+Ds` and burns exactly `n*k` for native principal.
Its SY change moves old growth to escrow before principal transfer; tokenized
RG is a claim on that same escrow, never additional physical gons.

No new solvency or double-attribution counterexample was found in these
bounded revised-SY equations. That result cannot settle N1's payout boundary
or N2's missing authenticated production dependency.

## 5. Implementation boundary and scope assessment

**The boundary is named but not complete enough to freeze.**

R2 sections 6/8 correctly name a local
`M/sy/UniswapV4DetfMigrationSYEgressAdapter.sol` and its interface/repo/facet/
package, where M is
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
The direct pull, explicit PY amount, market output to external R, and own-ticket
onward redemption are narrow corrections supported by the read call identities.
They need no shared-router edit or arbitrary executor. Validating local
factory provenance, measured operation deltas and minima remains mandatory.

The reward correction is substantially larger:

- `M/sy/rewards/UniswapV4DetfMigrationRewardGons{Repo,Target,Facet,DFPkg}.sol`
  and its interface introduce an actual 45-decimal ERC20, receipt liability E,
  fixed mint/burn custody methods and a new activation-phase participant.
- `M/sy/pendle/UniswapV4DetfMigrationRewardManagerAbstract.sol`,
  `UniswapV4DetfMigrationRewardManager.sol`,
  `UniswapV4DetfMigrationYieldToken.sol`,
  `UniswapV4DetfMigrationGauge.sol` and
  `UniswapV4DetfMigrationMarketV3.sol`, with local reward/YT interfaces,
  replace storage widths, reward arithmetic, remainder ownership and RG
  harvest cadence.
- `M/sy/UniswapV4DetfMigrationSYIntegrationFactoryService.sol` adds two fresh
  factory configurations and their owner/fee/treasury/expiry/ve/gauge
  dependencies, plus corresponding parent/package initialization bindings.

The narrow source fields and nonvirtual/private YT implementation explain why
one-gon ERC20 units cannot simply be dropped into the unchanged consumers.
They establish necessity **conditional on choosing that representation**.
They do not establish that a new token plus the five-contract consumer import
spine and fresh protocol factories is the minimal authorized Migration
integration. N1 challenges the representation's admitted payout contract;
N2 exposes a necessary external dependency missing from its supposedly
complete deployment boundary. Shared-source immutability alone resolves
neither issue.

No source-compatible stock consumer is approved here. R2 honestly says the
stock narrow YT/market and original internal-burn router calls remain
unsupported. Its replacement operation/ownership behavior is therefore an
explicit production contract to prove, not optional adapter prose. The
review does not silently waive market/PY operations or authorize a wider
Pendle/controller project to make the replacement work.

Before freezing the corrected boundary, it must discharge N1/N2 and retain
the demonstrated exact-principal and reward-ownership equations. It must also
pin the actual external entry for RG's "receipt synchronization path"
(r2:517-518): the current receipt `_synchronize` is internal
(`C/claimToken/StakedDETFTarget.sol:241-246`), and r2's proposed tokenized
redemption deliberately does not synchronize. This is an explicit remaining
call/phase specification obligation, not evidence of an executed deadlock.
An implementer must not invent an arbitrary parent-caller exemption to fill it.

Runtime obligations remain distinct: real receipt/SY/RG custody and
post-burn/post-mint supply checks; callback/phase enforcement; final receipt
withdrawal synchronization; exact configured output tokens, fee/decimal
conversion and rollback; local wide interface compilation; real factory/
gauge calls; permits; initialized reciprocal bindings; actual selector
removal; all-uint256 limits and gas. No conditional arithmetic result closes
any of these.

## 6. Inputs, integrity, completion and limits

Required inputs were present, not assumed:

- Complete correction brief, including its two r2 review-focus requirements;
  complete phase03 implementation and original phase briefs.
- Complete `implementation-handoff.md`, governing Migration Plan,
  final 701-line r1, complete original independent `egress-verification.md`,
  and complete r2.
- Every file in original `evidence/egress/`,
  `evidence/egress-verification/`, and producer `evidence/egress-correction/`,
  including actual models, runners and result receipts.
- Concrete consumer/reward/math/router/factory/controller source cited above,
  current receipt/SY funding and exit source, and applicable repository rules.

The r1 fingerprint
`5104e78908e38274c987b7e8dfcd2e291373d984c78d919908a5f11f4bcb0506`
is the supplied historical identity; this session did not recompute it or
rewrite r1/prior verification/evidence. Producer execution results were read
as inputs, not reported as this verifier's executions.

Both independent finite resident evaluations completed normally in Bun 1.4.4.
Fresh LSP diagnostics for the new 178-line evidence script reported zero
diagnostics. It contains 163 nonblank/noncomment lines, one bounded
verification role, deterministic integer inputs, no external data parser,
no production seam and no dependency installation. These checks do not imply
Solidity compilation or a runtime SUT pass.

Authored files are only this report, owned
`evidence/egress-correction-verification/audit-session.mjs`, and owned
`evidence/egress-correction-verification/results.md`. Existing verifier scripts
were preserved. No production/test/config edits, Forge, installs, Git,
commits, broadcasts, external messages or delegation ran.

**Clean resource completion:** no task-owned process, monitor, RPC/node,
listener, temporary directory, cache, dependency or worktree was created.
There is no pending runtime. Shared Crane, warm artifacts and other lanes
were untouched.

**Final AdversarialVerify: needs-fix.** Every original finding has a
source/evidence-backed disposition. The revised arithmetic has positive
principal and correctly owned funded reward witnesses, but the proposed
payout policy and complete market integration boundary are not accepted.
The decision rejects arithmetic-only approval and an implicitly expanded
protocol deployment, while preserving the verified principal-ledger results.
This closes the independent verification deliverable only; it does not close
T5-EGRESS or authorize unrelated work.
