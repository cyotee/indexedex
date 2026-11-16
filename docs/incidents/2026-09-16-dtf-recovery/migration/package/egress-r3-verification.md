# Independent Migration egress r3 verification

Date: 2026-11-10.

**Verdict: ready-for-bounded-implementation.**

The complete `egress-contract-r3.md` supplies a coherent construction for the
original required new-instance receipt, bond, parent and two-SY boundary.
No additional construction blocker was found. N1 is corrected by keeping
reward gons in protocol custody and gating actual RT/native reward delivery.
N2 is corrected by removing the unrequested fresh-market deployment graph,
not by pretending its controller admits that graph. The retained F1-F3
obligations are satisfied by coherent native RT units and sentinel, old-holder
reward custody, and the actual standard bearer internal-SY contract.

This is a construction verdict, **not policy approval, production acceptance,
implementation authorization, or runtime E5 closure**. It does not authorize
the producer's edits, a Pendle rollout, an operational allocation, deployment,
funding or activation. Task 3/task 5 and E4/E5 remain incomplete until the real
implementation and proxy evidence exist. Source E1/E2 and actual recovery E3
remain open, with every original category retained.

Independent evidence is exclusively under
`evidence/egress-r3-verification/`. Its modules import neither the producer's
models nor prior verifier models. The producer's execution receipts were
read as inputs, not adopted as this reviewer's observations.

## 1. Findings and mandatory-correction dispositions

**Additional construction findings: none.** The following resolves the
specific prior objections against the actual r3 boundary, rather than
declaring all prior requirements satisfied by a green arithmetic run.

| Obligation | Independent disposition |
| --- | --- |
| **N1: no newly delivered reward receipt before activation** | Corrected. R3 sections 3/5/6 require activation at both public reward claims and typed receipt payout/mint boundaries. RT supply is zero in Stage 1. Wallet/SY checkpoints move existing physical gons into receipt custody; new fee/creator allocations are issued there and retain the allocation-time beneficiary. Existing NFT/right transfer does not mint/deliver a new reward token. Every closed-stage reward claim in the independent sequences rejects, while mature principal succeeds. |
| **N2: fresh factory is not admitted by unchanged controller** | Correctly removed from the required graph, not repaired by assertion. The real controller still rejects a market admitted only by the fresh factory. No new controller, voting contract, governance action, skipped/caught harvest or shared-source edit is needed for the retained Migration graph. No new market/PY lifecycle is claimed delivered. |
| **F1: standard index creates unfunded native-token claims** | Corrected at the retained SY API. With q=W=1e18 gons per native RT, `I=1+Q-k` makes the actual consumer expression `floor(s*deltaI/W)` a native **RT** amount. It is not a native sDETF amount. Initial sentinel is 1; `I<=Q<2^128`. RT represents already escrowed gons, not another staking liability. Optional narrow consumers still have accrued-width/floor limits, expressly not claimed solved. |
| **F2: transferred principal takes backing for old retained claims** | Corrected. Checkpoint before every affected share mutation assigns all prior earnings to the old holder's R2 and moves corresponding physical gons to receipt custody. Principal transfer moves only x shares backed by x*k. Zero-share old holders retain payable R2/RT/R0; a different principal receiver gets no old reward. Independently executed full departure, further funded appreciation and old-holder payment succeed. |
| **F3: actual router/operator cannot spend the proposed ticket** | Corrected by restoring the required standard source rule, not by extending tickets. `redeem(...,false)` burns caller shares; `true` burns actual SY-held shares. Router pull and YT/market upstream push therefore have the right last-hop source without inventing a source-owner argument or upstream allowance. An unrelated caller may burn deliberately self-held bearer shares; demanding the opposite would reinstate the rejected draft-only ticket policy. Underlying inventory is never a substitute for issued shares. |
| **Principal, funding, rounding and retirement retained from earlier work** | Preserved with the brief's correction to draft-only stronger rules. Native principal uses exact n*k packets; real funded two-floor allocation/rebase remains canonical. Canonical own-account/final-position sub-native retirement is admitted under its actual conditions. Deferred rewards and RT quantum residue are not arbitrarily retired. A q-sized fraction can exceed one native payable unit when k<q. |
| **Current-owner pooled genesis** | Closed owner decision, correctly reflected in r3. Current Crane owner alone selects/executes genesis amounts and anchor; contributions/later ordinary donations remain permissionless. No BOOTSTRAP-AUTH question is reopened. Actual E4 execution remains unproved. |

The governing payout requirement is Plan MIG-P08 and sections 4.1/5.5,
including the explicit statement that delivery of staking reward receipts
already counts as payout. The original internal-balance requirement is
FundedPlan section 7.1, not r1/r2's tickets. Exact independent source
expressions and locations are recorded in `evidence/egress-r3-verification/source-evidence.md`,
S01-S28.

## 2. Scope, authority and inputs

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
Read in full: the named `phase03-egress-r3-brief.md`, actual Migration
implementation plan, `ownership.md`, `bootstrap.md`, `children.md`,
`implementation-handoff.md`, r1, r2, both independent reports, r3 and all
five files in `evidence/egress-r3/`. The complete immutable
`evidence/egress-verification/reference.mjs` imported by the producer was
also inspected. Its functions were not imported into this verification.
Long/truncated required passages were reopened in bounded chunks.

The expressly required brief and Plan were read at their main-checkout paths;
the Plan was absent from the worktree artifact inventory. All authored files
are inside this task's allowed worktree report/evidence boundary. Repository
routers, assistant rules, applicable DETF law, canonical Crane architecture,
deployment/testing/adversarial guidance, IndexedEx testing/adversarial
guidance, and Bun/JavaScript evidence discipline were loaded.

Source aliases in this report:

- `C/` = `contracts/vaults/detf/common/`
- `D/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- `M/` = proposed `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `K/` = `lib/crane/contracts/`
- `P/` = `lib/crane/contracts/protocols/perps/pendle/`
- `Plan` = `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`
- `FundedPlan` = `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`

The source was independently read; prior agents' locators or architectural
choices are not evidence of operational authority.

### Original scope remains intact

Plan MIG-P01-P05/P09-P15, original entitlement quoting/proportional delivery,
configuration-versus-consumption, staged recovery and irreversible activation
are not replaced by this egress review. In particular, no original-payer-only
rule, mutable postactivation attribution approver, omitted generation,
preminted entitlement or new deadline is introduced.

All Plan section 3 categories remain required: both liquid DETF generations,
both NFT models, current and earlier receipts, legacy SY, TokenStaking and
claim-vault rights, underlying SE shares and fungible LP tokens. Legacy SY
recovery is not optional merely because a **new** Pendle market is optional.
No source row or any of the Plan's 53 acceptance dispositions is closed by
this review.

The plan/source requires both SY wrappers and their actual standard APIs:
FundedPlan:322-351; `contracts/interfaces/IDETFStandardizedYield.sol:13-17`;
`C/sy/DETFSYDeploymentLib.sol:15-27`. Neither those sources nor the complete
Migration Plan requires a new Pendle protocol deployment.

The one RT is an engineering dependency of the **selected** separate-reward
construction, not a claim that IStandardizedYield mandates a nonempty reward
list or that the owner requested another protocol. Its purpose is concrete:
a native fixed-gon token can preserve future funded appreciation after the
holder's principal shares leave, while the standard reward index accrues
native token quantities. R1's rebasing-sDETF reward declaration did not do
that. The smaller q=W quantum avoids the draft-only one-gon index overflow
without discarding exact underlying beneficiary gons.

## 3. Independent state and arithmetic evidence

The independent oracle uses eagerly attributed SY earnings at each funding
event. It does not reproduce the producer's lazy lastK implementation or
import its entitled-slot model. It reconciles actual modeled physical
custodian balances, principal basis, bond attribution, SY earnings, three
beneficiary domains, tokenized gons, self-owned reserve U, native backing,
two dust classes and cumulative native input/output.

At completed transitions:

```text
T = sum physical receipt gons
B = floor(T/k) + allocationDust + stakingDust
actual funded input - actual native output = B
G[receiptEscrow] = sum(R0+R1+R2) + RT.totalSupply*q + U
G[stakingSY] = sum(shares)*k + unsettled earned SY gons
G[bond] = sum position gons
ordinary wallet G >= liquidBasis*k
```

These are exact integer identities, not external token-transfer observations.
Source funding uses `Q=1e36`, scale `1e54`, the two allocation floors, ceiling
rebase, then role issue: `C/core/DETFFundedStakingMath.sol:46-94`;
`C/claimToken/DETFFundedStakingRepo.sol:185-201`. Persistent role weights
follow `C/core/DETFSeigniorageShareLib.sol:18-33`.

The final standalone finite run used **Bun 1.4.2, exit 0**:

| Witness | Independent observed construction result |
| --- | --- |
| Genuine modeled creation clock, unlock-1/unlock/unlock+1, long Stage 1 | Principal 0 before cliff, 10 at cliff, repeat 0. Combined reward request rejects atomically. Later direct principal exit pays 10, not the grown receipt balance. |
| Original bond versus principal claimant | Original bond retains 5Q gons; claimant retains Q. Further actual model funding and activation pay 25 and 5 to their separate owners; total output 40, final backing 0. |
| Standard reward units and old-holder departure | Sentinel 1; at k=Q/2, index `500000000000000000000000000000000001`, claim `5e18` native RT backed by 5Q gons. Ten principal goes to a different receiver. Further funding and activation permit old consumer user/treasury payments 18/2; repeat 0, final backing 0. |
| Mixed cohorts and all split points | 920 sequences with principal 1..20, every split, two funding magnitudes, later deposits, transfer back, zero/self transfers and receipt/native output forms. Aggregate principal paid 15,080; rewards 9,984; 1,788 nonzero owner-residue observations remain booked. |
| Rollback and hidden payout negatives | Every mixed sequence rejects a preactivation SY reward claim and restores the entire speculative funding/redemption state after a failed final minimum. RT supply remains zero while closed. EVM exception propagation is an assumption of these snapshots. |
| Quantum and native rounding | 555,555,555,555,555,554 sub-RT gons remain owned and later pay that many native units at k=1 through the specified remainder API. RT redemption with a different payout receiver leaves its fraction with the RT owner, not that receiver. |
| Canonical retirement | Fully paid bond and full active wallet exits retire only their admitted fractions, leaving 2 native canonical dust in each example. The wallet pays 8 native units. Stage-1 deferred reward balances are not retired. |
| Captured roles | Equal old fee/creator beneficiary retains exact gons through later role changes, receives no closed-stage receipt delivery, then receives 1 native unit once and retains its modulus. |
| Direct/internal/parent composition | Approved router pays 5 principal while preserving 2 old self shares; old holder later gets 10 reward. Parent pays only its new 7-unit packet and preserves old basis 2; original holder later receives 7 reward. |

Full numeric output, reproduction command, diagnostic failures and limits are
in `evidence/egress-r3-verification/results.md`.

### Conservation and exact-once conclusions

Subtracting n*k physical gons lowers aggregate native liability by exactly n.
Checkpoint does not create principal. With principal gone, remaining reward
gons still participate; the withdrawn principal does not.

Standard claim changes `R2 -> E` by m*q and mints exactly m RT. RT redemption
changes `E -> native receipt + R0` with `m*q = nativePaid*k + retainedGons`.
The same gons are never added to T twice. The remainder extension spends
only `R2%q`, not whole standard-claim backing. Immediate repeated claims pay
zero at the unchanged index.

Canonical retirement is permitted by FundedPlan:192-196 and
`C/claimToken/DETFFundedStakingRepo.sol:109-139`;
`C/bondNft/DETFFundedBondTarget.sol:200-208`. It is not permission to destroy
all sub-RT amounts or another position's pooled residue. R3 explicitly makes
that distinction; r1's absolute no-retirement rule is not retained as owner law.

## 4. Complete retained interface and money-path boundary

In this table, **constructed** means source-grounded accounting/caller
contract with the bounded evidence above, not an installed selector or a
successful real reserve transaction.

| Surface | Units, identities and required behavior | Independent assessment |
| --- | --- | --- |
| Bond creation | Actual parent -> bond pull -> exact receipt stake; native principal and principal*k gons; fresh timestamp and internally supplied 90-day cliff. | Constructed. Source exact-funding pipeline is `C/bondNft/DETFFundedBondTarget.sol:94-130`; actual issuance integration still needs the real parent route, not impersonation. |
| Bond principal/rewards/combined | NFT holder or approved operator; recipient distinct from authority; position/aggregate effects precede typed receipt delivery. Rewards-only/combined reject while closed; mature principal succeeds. | Constructed. `:139-208` supplies authority/debit/retirement; Migration policy must replace actual delivery. Separate original/post-claim rights independently paid. |
| Three NFT transfer selectors | Transfer remaining position/clock, no new reward receipt; reserved-role transfer changes future allocations only. | Preserved. `:220-252`; real receiver callback precedes ownership mutation (`K/tokens/ERC721/ERC721Repo.sol:153-169`). Guarding the actual callback remains unexecuted. |
| Receipt exact-in and exact-out | Native 1:1 direct DETF/sDETF conversion; same basis cap; allowance cannot unlock rewards; actual pull, deadline, minimum/maximum and hard true-pretransfer rejection. | Constructed on `C/claimToken/StakedDETFTarget.sol:147-166,200-246`. No extra parent/SY exact-out selector is inferred. |
| Receipt transfer/transferFrom and permit | Stage-1 old growth moves to R0; n principal moves with n*k. Active native value can move under the specified basis update. Max and owner-as-spender allowances decrement. | Constructed; `K/tokens/ERC20/ERC20Repo.sol:157-166,297-301`. ERC2612 writes allowance only (`ERC2612Target.sol:39-58`); signature execution remains unrun. |
| Receipt balance/state/price previews | `balanceOf=floor(G/k)` remains physical; `egressState` separates executable principal from latent/deferred growth; protected custodian public authority is zero. | Truthful declared distinction. Price previews are not account authorization. An implementation must not derive wallet growth from protected pooled backing. |
| Receipt reward funding and role release | Real parent-only funding; capture role owner at allocation; escrow Stage-1 gons, preserve later participation; release only to recorded beneficiary after activation. | Constructed; common source immediately delivers ordinary role receipts and therefore needs the selected override (`StakedDETFTarget.sol:169-189`). No captured ownership is recalculated at activation. |
| R0/R2 assignment | Actual attributed owner assigns exact gons; custody stays escrowed; no RT mint, principal credit or native allowance authorization. R1 remains fixed. | Compatible existing-right transfer, distinct from N1's newly issued token delivery. |
| Parent stake/unstake | Parent settles, pulls exact current receipt packet, unstake spends exactly it; raw or configured output receives only its operation budget. | Constructed; `D/UniswapV4DetfTarget.sol:344-374`. Old parent inventory is not authority or subsidy. |
| Parent ordinary acquisition/bonding | Stage-1 gate before primary versus swap, including receipt-directed acquisition and LP bond payment. Ordinary active purchases retain their unmarked linear terms/order. | Required, not waived; `D/UniswapV4DetfTarget.sol:200-230,261-324,527-595,714-724`. |
| Staking SY direct DETF/sDETF deposit | Actual funding first; pin final k after acquisition; checkpoint receiver; mint n nine-decimal principal shares backed by n*k. Receipt input leaves sender's old growth in R0. | Constructed. Source three acquisition branches are `C/sy/DETFSYTarget.sol:196-217`; no old backing/native rebase delta is input credit. |
| Staking SY configured acquisition | Stage-1 unavailable before parent mint/swap selection. Active acquisition uses actual route output, then final-index accounting and minimum shares. | Source-conditioned route contract, not a simulated price or waived call. |
| SY transfer/transferFrom | Settle each distinct old account before balance change. Shares convey future principal participation, not already-accrued R2. | Constructed, including late cohorts and zero/self transfers. Same ownership order as `P/core/StandardizedYield/SYBaseWithRewards.sol:74-95`. |
| External SY redeem | Caller owns burned shares; selected receiver owns only principal output. | Constructed. Caller/receiver distinction preserved. |
| Internal SY redeem | Actual issued SY at SY is the source; input allowance authenticates an atomic router's pull, not an enduring ticket. A funded self deposit supplies only its returned new share budget. | Constructed; `C/sy/DETFSYTarget.sol:94-121`, `P/router/base/ActionBase.sol:94-103`. Wrong external source/allowance rejects, deliberate bearer self balance remains publicly burnable. |
| Staking SY -> receipt | Fixed staking-SY-only method moves x*k gons and x liquid principal to receiver; receiver can unstake x. | Constructed. Direct receipt output bypasses parent, so its own gate/custody checks are indispensable. |
| Staking SY -> DETF | Burn exactly x*k, reduce backing by x, transfer x held DETF. | Constructed. It must not invoke pooled/full-account retirement. |
| Staking SY -> every other configured output | Withdraw x DETF to SY; approve exactly x; execute actual parent route; clear allowance; enforce final minimum and propagate failure. | Input-budget/source contract verified; real primary/swap output, fees, decimals and liquidity remain runtime obligations. No fabricated rate or all-output PASS. |
| Raw SY | Actual raw backing equals shares; no staking/reward ledger. DETF plus configured directions; receipt not an automatic raw route. Same external/self source selection. | Source-grounded unchanged principal behavior; configured receipt input/output uses actual parent principal-aware composition. `C/sy/DETFSYRepo.sol:38-69`. |
| SY rate/previews/metadata | Both nine decimals; staking principal rate W, asset `(TOKEN,DETF,9)`, yield token sDETF; principal direct previews x, configured previews actual parent route. Raw yield token DETF, W rate. | Coherent retained declaration. `SYUtils.sol:7-20` gives 1:1 conversion at W. Ordinary appreciated-SY rate remains ordinary, not globally replaced. |
| Reward list/index/accrued/claim/event | Staking list `[RT]`, RT 27 decimals, q=W gons/native RT, index `1+Q-k`; accrued/claim/event amounts native RT. Raw arrays remain empty. | F1 corrected. `IStandardizedYield.sol:105-130`; actual consumer sentinel/unit at `RewardManagerAbstract.sol:16-64`, `PMath.sol:20,34-38`. `RT!=yieldToken`. |
| Remainder and RT redemption | Native-sDETF extension is explicitly separate from RT-valued standard claim. Fixed receipt/SY/RT callers; RT owner, not payout receiver, keeps fractional R0. | Constructed, with positive q>k payment and differing-receiver residue evidence. No minter setter or generic execution authority. |
| Self-held SY earnings | Before transfer, old holder retains R2. During deliberate self custody, earned gons go to protocol U; neither next redeemer nor depositor receives them. Self reward claim/accrued returns zero. | Explicit standard boundary, not user escrow. Source reward manager excludes itself (`RewardManagerAbstract.sol:35-44`). U remains funded in T and is not destroyed, swept or described as user dust. |
| Donations, protected balances and residuals | Preserve bond-first live donation/Permit2 routes; separate donation budgets, recovery custody, principal and reward backing. Migration sweeps use operation budgets, including self-call paths. | Mandatory source-grounded boundary, not solved by this arithmetic run. `C/bondNft/DETFFundedBondTarget.sol:212-218,260-389`; `D/UniswapV4DetfCommon.sol:483-544`. |
| Empty/standing-only participation | Empty means T+F+Cw=0; advance empty baseline before adding principal; retained gons or standing weights are real participation. | R3 retains the necessary parent policy. Do not rely on locked-child sync to settle preceding participants. |
| Metadata and ordinary isolation | Marked cliff/locked reward presentation; unmarked active bonds and ordinary packages retain their specified behavior. | Required at real metadata/rendered surface. Current linear renderer is `C/bondNft/DETFFundedBondMetadata.sol:30-35,63-96,136-150`. No ordinary test was weakened. |

## 5. Real caller and component admission

### Internal owner/operator boundaries

For direct pull the source chain is user -> router -> `transferFrom(user,SY,x)`
-> old `redeem(...,true)`. For PY the chain is user PT/YT -> YT ->
**YT's** SY transfer to SY -> router internal redeem. Market burn/swap
similarly makes the **market** the sender. Read call sites:
`P/router/ActionMiscV3.sol:18-23,39-46`,
`P/router/base/ActionBase.sol:94-129`,
`P/router/ActionAddRemoveLiqV3.sol:307-323`,
`P/router/ActionSwapPTV3.sol:43-55`,
`P/core/YieldContracts/PendleYieldToken.sol:317-339`,
`P/core/Market/v3/PendleMarketV3.sol:129-145,159-183`.

R3's required direct SY handoff works without assigning another sender's
ticket to the router. Principal amount is explicit/returned for this operation,
never the aggregate SY self balance. Retained reward owner is the pre-transfer
SY holder, not router, final receiver or original payer inferred from logs.
The independent upstream rows establish only this last hop. They do not
establish a stock market or PY lifecycle.

### Retained deployment graph

| Component | Necessity and actual admission route | Limit |
| --- | --- | --- |
| Existing manager/registry, fee oracle, CREATE3 and callback factory | Plan section 2/task 3; registry `deployPkg` requires real manager owner/operator and registers declaration; `deployVault` checks authorized caller plus requested package registration/enabled status. `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:44-76,141-165`; `D/UniswapV4Detf_Pkg_FactoryService.sol:16-32`. | This does not confer registry authority on Migration owner. Real authorized deployment remains a prerequisite, not a model-granted permission. |
| Migration parent and real reserve hook/SEs | Plan package/bootstrap; hook must contain one parent self leg and have parent as owner. Actual first join is full-book and liquidity-owner gated. `D/UniswapV4DetfProcessArgsLib.sol:26-64`; weighted `UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:142-147`. | Configured routes/providers, hook completion, underlying liquidity and recovery assets must actually exist. No simulated capital/admission closes E4. |
| Bond package/child | Plan task 5; registered selected bond package, exact parent binding and three guarded transfer replacements. `C/bondNft/DETFNFTVaultDFPkg.sol:48-53,83-117`; `D/UniswapV4DetfTarget.sol:810-830`. | Migration policy/metadata and real cliff issuance are not yet deployed. |
| One funded receipt | Plan task 5; existing generic selected package uses callback factory, parent/bond/oracle args and once-initialized common funding state. `C/claimToken/RebasingClaimTokenDFPkg.sol:39-59,137-149`; `D/UniswapV4DetfTarget.sol:833-849`. | It is not a new registered-vault category or second staking pool. |
| Raw/staking SY | Plan egress coverage/FundedPlan 7.1; actual selected registered package creates both modes and stores their distinct identities. `C/sy/DETFSYDFPkg.sol:41-51,99-117`; `DETFSYDeploymentLib.sol:15-27`. | Narrow declaration extensibility and actual Migration selectors must accompany changed behavior. |
| Local RT child | Required by this selected fixed-gon reward boundary, not by a Pendle rollout. New local generic DFPkg can use existing callback `deploy(pkg,args)`, then once-bound receipt/parent. Receipt caller admission remains false until the parent's fixed RT pointer exists. `K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-231`. | RT implementation, selected facets, reciprocal binding and atomic completion still must be built/verified. Source availability does not prove a deployed instance or authorize arbitrary registered actors. |
| YT/PT, new market/factories, gauge, ve/voting, new router | No original required deployment edge. Their source is a compatibility probe, not an adopted product dependency. | No controller/gov action, new protocol import spine or optional consumer acceptance is claimed. |

R3's order is implementable without a predicted circular identity: wire
bond/receipt, create once-bound RT and store it once, then deploy both SYs
and verify fixed bindings before completing the parent. Existing package
postDeploy performs parent-context child wiring
(`D/UniswapV4DetfDFPkg.sol:227-239`). Generic callback factory deployment
does not require Pendle admission. The temporary hook must be removed;
stored factory context is not a one-use permission token
(`DiamondPackageCallBackFactory.sol:343-451`,
`PostDeployAccountHookFacet.sol:19-23`).

## 6. Negative integration cases are not waived calls

1. **All-revert substitute rejected.** The independent bond/receipt/SY
   sequences actually pay mature principal while closed and owned rewards
   after activation. R3 is not accepted because every exit reverts.
2. **Hidden payout rejected.** A newly issued transferable RT is a reward
   delivery even if its redemption is locked. R3 makes that issuance itself
   activation-gated. Relabeling r2 issuance as right assignment would fail.
3. **Unrequested deployment rejected.** A fresh factory's `allMarkets` set
   does not satisfy the unchanged controller's four immutable registries.
   Its guard runs before zero-reward handling:
   `PendleMarketFactoryV3.sol:39-63,69-116`;
   `PendleGaugeControllerBaseUpg.sol:42-93`. Independent rejection also
   rolls back the preceding modeled SY harvest; no counterfactual admission
   set is changed to manufacture success.
4. **Required stock harvests are not silently skipped.** First expiry calls
   `SY.claimRewards(YT)` before storing expiry data
   (`PendleYieldToken.sol:373-385,473-476`). Market mint/transfer reaches
   SY/controller harvesting (`PendleMarketV3.sol:96-110,347-356`;
   `PendleGauge.sol:84-86,109-114`;
   `RewardManager.sol:27-35`). R3's Stage-1 claim rejection can block these
   optional uses. They are expressly unsupported, not presented as delivered
   by a fake zero reward or catch-and-continue.
5. **Index fit is not blanket stock compatibility.** A representable native
   principal `680564733841876926928` can accrue more RT than uint128 accepts.
   Separately floored stock updates can credit 0 where their merged update
   credits 1. R3 preserves exact fractions at its own boundary and does not
   promise downstream exact fractions or impose an economic cap to fit
   optional consumers.

The third-party limitations do not excuse an incorrect declared
IStandardizedYield API. The retained API itself has coherent units,
sentinel, ownership, event amounts and self/caller semantics as section 4
establishes. The exclusions concern additional protocol lifecycles, not
renaming a mandatory Migration call as optional.

## 7. Cross-proxy ordering and irreversible activation

The following are implementable constraints, not observed runtime locks:

- Receipt public entries announce Synchronizing before calling parent.
  Parent funding may enter receipt during that phase, take its local
  accounting lock, and restore the saved phase. Restoring Idle would expose
  a callback window. The independent conditional checks distinguish these.
- Parent settles old participation before new bond/stake funding. Existing
  locked-parent no-op remains receipt/bond-only
  (`D/UniswapV4DetfMaintenanceTarget.sol:16-27`).
- Bond/SY effects debit authoritative attribution before typed receipt
  custody calls. Receipt authenticates actual fixed caller, expected k,
  physical inventory and the caller's post-effects attribution.
- SY acquisition fixes k after actual acquisition. SY redemption finishes
  source accounting before onward parent routing. Only that fixed SY's
  matching synchronization/acquisition/payment edge is admitted; a hostile
  token caller cannot borrow its phase.
- RT redemption explicitly enters the synchronized receipt method. Receipt
  settles first, checks activation, fixes k, invokes fixed receipt-only RT
  burn, verifies post-burn supply/E, and pays. R2's missing external
  synchronization edge is no longer assumed.
- Preserve bond-first donation -> parent join/notify. Pre-locking the parent
  forwarding facade would deadlock the existing cycle. Parent ERC20 backing
  transfers/allowances cannot be treated as forbidden independent economic
  callbacks.
- Current-owner activation requires all five fixed children idle. Safe NFT
  receivers run before ownership mutation, so real callback-owner activation
  negatives are mandatory; a per-proxy lock alone does not prove them.

Activation transfers no assets, mints no RT, resets no index/clock and scans
no beneficiaries. The cut must resolve each selector's actual owning facet,
remove the complete administration surface including itself, use no
initializer/delegatecall payload, and finalize without an intervening callback.
Zero-address cuts are skipped by actual Crane code; wrong owning facets
revert (`K/introspection/ERC2535/ERC2535Repo.sol:104-116,155-169,245-270`).
Current-owner equality and actual pending-owner acceptance semantics remain
unchanged (`MultiStepOwnableRepo.sol:108-122,253-274`).

This is not a runtime proof that no initializer/restoration edge survives.
The final routing map and callback-factory completion must be inspected on
the actual proxies. Factory redeployment returning an existing address is
not an upgrade or fresh initialization witness.

## 8. Bounded implementation and remaining acceptance contract

R3 section 8's proposed paths are sufficient at construction level:

- New `M/claimToken/UniswapV4DetfMigrationStakedDETF{Repo,Target,Facet}.sol`
  and interface for basis, custody, E/U and typed phases.
- New `M/bondNft/UniswapV4DetfMigrationBondNFTRepo.sol`,
  `UniswapV4DetfMigrationBondNFTVault{Target,Facet,DFPkg}.sol`, interface
  and Migration metadata Target/Facet.
- New `M/sy/UniswapV4DetfMigrationSY{Repo,Target,Facet}.sol` and interface;
  local `M/sy/rewards/UniswapV4DetfMigrationRewardToken{Repo,Target,Facet,DFPkg}.sol`
  and interface.
- Narrow implemented dispatch/declaration/rendering seams in
  `C/claimToken/{StakedDETFTarget,RebasingClaimTokenDFPkg}.sol`,
  `C/bondNft/{DETFFundedBondTarget,DETFNFTVaultDFPkg,DETFFundedBondMetadata}.sol`
  and `C/sy/{DETFSYTarget,DETFSYDFPkg}.sol`, preserving ordinary defaults.
- The named Migration parent repo/policy/package/interfaces/factories and
  Exchange/Bond/Maintenance/Query facets, with necessary narrow seams in
  `D/UniswapV4Detf{Common,Target}.sol`. No shared Crane edit, local Pendle
  import spine, egress adapter, ticket map or new protocol deployment.

The selection must replace actual inherited payout/transfer/redeem bodies;
adding same-named nonvirtual helpers or getters is not an implementation.
Current package declaration methods are nonvirtual
(`RebasingClaimTokenDFPkg.sol:76-85`, `DETFNFTVaultDFPkg.sol:68-75`,
`DETFSYDFPkg.sol:66-74`); actual added interfaces require corresponding
extensibility/cuts, not false ERC165 declarations.

The next authorized implementation must still demonstrate:

1. Real manager/registry-deployed parent/bond/SYs, funded receipt, RT and
   configured weighted hook/SEs, using actual artifact bytecode. Genuine
   independent issuance is the initial cliff caller; verified surrender
   follows when its separate prerequisites close. No test issuer, parent
   impersonation, SUT subclass, storage injection, etch or ordinary-child
   placeholder is acceptance.
2. Every row in section 4 through real selectors, both burn sources, actual
   configured output sets and supported receipt exact-out paths; actual
   input/output deltas, fee/decimal conversions, approval clearing and
   whole-transaction rollback.
3. Real cliff boundaries and prolonged Stage 1; zero newly delivered reward
   receipts/RT, successful mature principal, then actual current-owner
   activation and correctly owned exact-once reward/remainder payments.
4. Physical gon/backing invariants, fractional retirement conditions,
   mixed cohorts, role changes, self-held semantics, donations/idle inventory,
   wrong fixed caller, stale k, signatures, callback reentry and busy-child
   activation. Gas and uint256 limits need actual tests, not BigInt success.
5. Completed live loupe/declaration census and bytecode size; absent
   initializer/updater/old payout/restoration selectors; atomic failed/successful
   removal. Ordinary V4/common funded staking, linear bonds and appreciated
   SY regressions must remain green.

The ordinary source tests intentionally expect wallet appreciation and
own-fraction retirement
(`test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Accounting.t.sol:53-109`).
Those expectations remain ordinary behavior, not tests to edit away.
Artifact-first Solar build before the real tests remains repository law;
no Forge invocation was permitted or run here.

These are the existing production/proxy/gas/callback obligations, not new
policy choices or an expanded integration project. All original full-release,
legacy-fork, recovery and script gates remain in their original lanes.

## 9. Completion and resource limits

Delivered only this report and five owned evidence files:
`ledger.mjs`, `run.mjs`, `source-callers.mjs`, `source-evidence.md`,
`results.md`. Prior reports/evidence and the producer's r3 are immutable and
were not edited. All writes used apply_patch.

The independent finite monitor completed **exit 0**; no node, RPC endpoint,
listener, daemon, temporary directory, dependency, cache or worktree was
created. No owned runtime remains. No production/test/config edits, Forge,
installs, Git, commits, broadcasts, shared Crane writes or delegation ran.

LSP reference lookup timed out. Fresh evidence diagnostics timed out for
`ledger.mjs` and `run.mjs`; `source-callers.mjs` reported none. Successful
Bun execution is not a full static type-check, Solidity build or runtime
security result. No deployed source identity, actual configured quote,
permit, callback, gas or operational authority was verified.

**Final disposition: ready-for-bounded-implementation of r3's required
Migration accounting boundary.** No new owner decision is requested.
Source E1/E2, actual recovery E3, runtime E4/E5 and original implementation
completion remain open.
