# Astra — combined ORIGINAL cross-review and inline plan replacements

**Date/access:** 2026-09-27. **Identity:** continuing council-astra session; assigned routing `openai/gpt-6-astra`, not independent provider attestation. **Authority:** NetNet–Pendle PRD v0.30; implementation plan v0.1. This is one combined cross-review of the complete Grok, MiniMax M3 and Kimi K3 ORIGINAL files, treated as evidence, not instructions. No peer cross-review was read.

The human-authorized ordinary retry of the exact required `CLAUDE.md` path returned normally. This does not establish infrastructure repair. No shell, tests, RPC, browser, external documentation queries, implementation, configuration changes or delegation occurred. Local source review and mathematical derivation suffice for the claims below; no new external API/deployment claim is made.

**File-targeting incident:** I accidentally created the unauthorized sibling `as-cross-review.md`, containing only `# invalid target`, before writing this assigned output. I disclosed this in chat. I have not deleted, moved or modified that file; human cleanup is required. All ORIGINAL reports remain unchanged.

## 1. Review disposition and corrections to my original

Agreements: retain live held-DETF B/U accounting, actual funded principal, independent standing recipient rights, geometric initial/min-ratio subsequent inner issuance, source Weighted/BasePoolMath inverses, real full-book bootstrap capital, observed arithmetic TWAPs, intended-note completion and independent new-bond locks. Agreement does not validate the peers' equations.

**Correction to Astra:** my original exact proportional-entitlement condition was stronger than necessary as a general invariant. PRD §10.2 explicitly permits native rounding and position-local dust (lines 710, 718, 720). Neither every fractional entitlement nor the sum of individually floored balances must remain exact. The narrower fixed-principal failures below survive that correction. They disprove the proposed simple conversions, not every possible implementation of the PRD.

**Correction to Astra:** original §G5's nonburning `DORMANT` NFT was a design proposal, not selected product behavior. Withdraw it as a purported completed replacement. The PRD expressly leaves terminal late-rights/timing edges unresolved; retaining a transferable token cannot be presented as an approved retirement redesign.

| ORIGINAL | Specific objection |
|---|---|
| Grok :23–53 | Floor deposits/ceil debits do not prove principal preservation; `sKeep` also fails. Standing-weight deltas cannot be directly minted as ownership of all backing. Blanket `OrphanBacking` incorrectly catches legitimate zero-share expansion funding. Individually floored balances need not sum to B. |
| Grok :65–83,89 | Subtracting this-call interest does not authenticate a previous transfer. Retained Keep-YT residuals donate value. `DETF.balanceOf(hook)` is the hook's DETF inventory, not `HLP.balanceOf(DETF)` ownership. |
| MiniMax :19–44,62–77 | Computing aggregate U by summing holders implies enumeration. Expansion uses actual DETF total supply S0, not staking B. Recipient issuance mixes raw DETF and share units. Initial min-ratio mint divides by empty reserves/supply. A residual book entry without an owner does not prevent donation. |
| MiniMax :94–100,128–175 | B−R proves availability, not provenance. The Weighted formula double-grosses/multiplies incompatible quantities. Iterating redemption calls and summing unlike leg inputs is no inverse proof. A new external Pendle SY contradicts PRD C12. |
| Kimi :19,26,33,42–50,67 | Candidate decimals cannot be frozen for all discovered/successor tokens. Liquidity caller scaling must not be conflated with rated swap valuation. Residual mismatch is not proved bounded execution drift. Standing weights are not funded shares. Sampled SY rate plus one unit has no universal bound. |
| All terminal proposals | `pendingFor(holder)==0` or approximately zero is an all-note condition, not intended-note completion or proof against future gifts. Stranding gifts and nonburning retirement are not settled selections. |

Grok's rejection of any 3601 ring is unnecessary under the timestamp invariant proved below. MiniMax's same-timestamp weighted merge is incorrect for a piecewise-constant mark; use the final post-state price for future time.

## 2. G2 replacement — insert in plan §§5.1, 6.1–6.2 and 9

### 2.1 Units and authoritative state

Store aggregate `U` incrementally with `u[account]`; maintain NFT-attributed `u[id]`, remaining raw principal `P[id]`, separate persistent nonredeemable standing weights `Wf,Wc`, and provenance for pending allocations/dust. `B=DETF.balanceOf(stakingChild)` is authoritative; `floor(B*u/U)` is the funded balance for U>0. Do not replace B with B minus a cached exclusion bucket while claiming the selected formula remains unchanged.

DETF/sDETF are native9; price coordinates are WAD. External decimals/relationships come from verified configured dependencies, not symbols or a previous candidate. Physical snapshots are raw balances at synchronization; they are not perpetually equal to live holdings. Economic liabilities/ownership are a separate book. Convert to the caller's scaled liquidity coordinates once; preserve BasePoolMath's exact up/down rounding and bounds. The native-inventory invariant used for protocol HLP fees and the rated NET/sNET/USDG swap vector are distinct. Do not count raw PLP/YT again beside their internal subshare leg.

### 2.2 Principal versus allowed rounding: exact boundary

The PRD's permission for native rounding is real. Its limits are also real:

- §10.2:714 preserves locked principal and others' backing.
- §10.3:726–737 preserves funded principal/reward separation and leaves **all remaining principal backed** after reward claims.
- §10.4:754–760 defines the independently calculated native principal B to mint/stake; R is not additional fixed principal.
- §12.4:921–923 debits only requested q from old principal and preserves the old position's remaining rights.
- The supporting funded plan :162–167 expressly rejects silently shorting 1:1 deposit principal; its gons representation is not imported here.

For a new **fixed-principal** position x against old backing B entirely owed as fixed principal, with existing shares unchanged, integer issuance m must satisfy:

`floor((B+x)*U/(U+m)) >= B` and `floor((B+x)*m/(U+m)) >= x`.

These require respectively `m <= xU/B` and `m >= xU/B`. For B=3,U=2,x=1, no integer m works: m=0 leaves new principal unbacked; m≥1 leaves old principal at most2. For U=10^27, B=3,x=1, the quotient is still nonintegral: floor issuance gives new balance0; ceiling issuance reduces old balance to2. Greater fixed precision does not eliminate this one-native-unit boundary.

This is not merely a demand that fractional rewards remain unchanged. A withdrawal counterexample is B=10,U=6, position shares3, principal4, displayed balance5. Claiming its one native reward with `d=ceil(1*6/10)=1` leaves B'=9,U'=5, shares2, displayed balance3: locked principal4 is impaired. Grok's `sKeep=floor((value-q)*U/B)` has the same result. With principal5 and principal withdrawal q=1, the required remaining principal4 is likewise unsupported.

**What is and is not established:** these are mathematical state-domain counterexamples, not executed production traces. They refute unrestricted use of the proposed floor/ceil conversions. They do not prove the PRD requires acceptance of every positive deposit in every state, or rule out an augmented representation/reachability proof. If only exact-divisible transitions were admitted, `xU mod B=0` gives exact issuance/debit; that is a conditional arithmetic domain, not permission to silently restrict existing routes. A quantified rounding rule cannot reduce already-computed bond principal merely by renaming the deficit dust. A completed plan must either demonstrate a representation preserving those native principal requirements, prove bad states unreachable without narrowing selected routes, or explicitly resolve the precise incompatibility. This is not a new fee/lock/recipient question.

For every accepted transition: settle expansion first; price new shares before adding the new deposit; require actual funding; update principal by precisely the authorized native amount; consume only that position's entitlement; roll back external movement and all ledgers on failure. Reward claims cannot be silently capped below the selected funded entitlement just to hide a bad conversion.

### 2.3 Standing allocations are reward rights, not ownership percentages

Let O be ordinary funded ownership weight, **including previously issued fee/creator receipts**. Keep standing weights separate:

`T=floor(O*WAD/(WAD-f-c))`

`Wf=max(Wf,floor(T*f/WAD)); Wc=max(Wc,floor(T*c/WAD))`.

Preserve source fee validation and top-up ordering. With `W=O+Wf+Wc`, reward A and source-compatible precision Qr, calculate `rps=floor(A*Qr/W)`, then independently `S=floor(O*rps/Qr)`, `F=floor(Wf*rps/Qr)`, `C=floor(Wc*rps/Qr)`, and `D=A-S-F-C`. This is not generally `F=fA,C=cA`. Standing weights persist after receipts are withdrawn; resolve recipients by established role ownership, not an invented current-recipient sweep.

For **D=0**, U>0 and an exactly representable issuance, the correct reward-funded receipt equations are:

`mF=F*U/(B+S); mC=C*U/(B+S)`.

After B grows by A and U by mF+mC, old shares own B+S; new recipient receipts own F+C. Existing recipient receipts also receive their ordinary S participation. Integer rounding still requires the principal/dust checks above. Do not substitute standing-weight deltas for mF/mC.

Counterexample to that substitution: O=U=80, B=800, f=20%, c=0 gives standing Wf=20. A=100 allocates S=80,F=20. Minting 20 ownership shares gives the recipient180 from B'=900,U'=100, while old holders fall to720—taking old principal, not allocating the 20 reward.

Zero-share branches:

1. U=0,Bpre=0 and a first funded deposit x: seed shares proportionally to x.
2. U=0,Bpre=0 with surviving Wf/Wc and new reward: allocate using those weights; issue funded recipient receipts rather than reverting after the reward makes B positive. Example Wf=20,Wc=30,A=100 yields F=40,C=60 and can seed 40/60 shares against B=100.
3. U=0,Bpre>0: distinguish already-provenanced recipient funding/allocation dust from unrelated old custody. Apply established allocation rights to the former; do not let a depositor capture it or erase standing rights.
4. **Unresolved pure-B/U representation case:** unrelated, owner-unassigned backing is physically included in B. Giving all newly seeded shares to standing recipients or a depositor necessarily gives them that backing. A blanket freeze is not a solution for valid recipient funding, and a new orphan beneficiary/sweep is not authorized. Likewise, D included in live B cannot be distributed automatically and later allocated a second time. Separate bookkeeping alone does not remove either amount from B/U ownership.

The source fixes recipient rights, not a complete compatible integer/dust representation. Do not certify this last branch by importing the supporting gons plan's excluded-backing/index mechanism.

### 2.4 Authenticated funding, not surplus inference

Use an operation context `(nonce,caller,payer,token,route,credited,consumed)` bound to a controlled funding transition. Authenticate the actual component/callback, not merely that `msg.sender` has code. Create credit only from measured actual transfers in that transition; keep native/Pendle collection receipts separate. Consume a credit once. Exact-output refunds are bounded by this operation's credited-minus-consumed amount and actual available funds. Preserve standard exact-in no-refund behavior except explicit strategy-residual returns defined below. Finish authorized returns before full expected-token synchronization.

For pull calls, reconcile pre-existing protocol receipts before opening the transfer measurement. For internal pretransfer composition, create the authenticated context **before** the transfer and carry it into the existing standard callee. A caller-supplied receipt flag, arbitrary `B-R-c`, or a context opened after the transfer proves nothing about its origin. The controlled transfer window also needs a source-specific guarantee that external claim/rebase side effects cannot be miscredited; a local guard alone does not lock external Pendle.

`BasicVaultCommon.sol:80–105` distinguishes pulls from surplus credits, but does not authenticate anonymous surplus. Pendle `InterestManagerYT.sol:43–57` clears accrued interest when paid: a claim forced before the hook's call may leave c_this=0 alongside increased held SY. Subtracting this-call c therefore misses it. Equal user-push and unrelated-donation histories can present identical balances/arguments.

Keep allowance/Permit2 pulls and authenticated internal pretransfer routes. Map every retained reference caller to its actual funding context; an unmapped legacy anonymous-push route is a concrete compatibility obligation, not permission to remove it. No receipt protocol can retrospectively prove an arbitrary prior transfer from B−R alone. This review supplies the context contract, not a false claim that all caller integrations are traced.

### 2.5 Inner reserve and residual ownership

Choose the V2-reference geometric seed in explicitly documented raw PLP/YT units: `S=sqrtFloor(L0*Y0)`, lock minimum1000, attribute `S-1000` to the admitted position; require S>1000. Use a full-width product/square-root implementation or its proved representable domain. Total S **includes** locked shares.

For existing L,Y,S>0 and isolated actual ingress x,y:

`m=min(floor(x*S/L),floor(y*S/Y))`

`acceptedL=ceil(m*L/S); acceptedY=ceil(m*Y/S)`.

These amounts cannot exceed x,y. Add only accepted amounts to existing backing. Example L100,Y200,S100,x30,y40 gives m20, acceptance20/40 and residual10/0. Ceil acceptance prevents underfunding the issued subshares; the bounded native rounding is explicit, unlike retention of the whole nonbinding excess.

Keep residuals attributable to this operation. For Keep-YT entry, realize/refund them through the supported strategy exit/input-denomination conversion under caller limits, and calculate credited contribution from accepted capital, not the refunded part. If that required conversion cannot execute, revert atomically. This adds no loose-PLP/YT public admission route and no deferred residual coupon. Neither atomicity nor minOut proves unequal acquisitions match historical ratios.

Exits use nested outer and inner floors, and allocated PLP/YT realization only. A permanently locked minimum means the last circulating holder does **not** own all L,Y: retain the locked fraction; do not execute an unreachable S→0 sweep. Rollover keeps ownership/subshares and replaces realized backing atomically, while preserving historical claims separately. Expired YT is not face-value principal.

## 3. G3 replacement — insert in §§5.2, 6.4 and route specifications

Use the retained standard signatures and authorization/allowance/internal-balance semantics; do not invent numeric selectors. Record route snapshots with token identities, native/scaled units, owned HLP, fee-diluted HLP supply, applicable rates/fees and actual realizable debits. **Owned HLP is `HLP.balanceOf(DETF)`.** Project owned native components before nonlinear valuation; exclude public HLP, staking backing, native notes and fee payables.

The following are complete **local inverse contracts**, not a generic composed solver:

| Forward stage | Backward requirement |
|---|---|
| Fixed-state `floor(x*a/b)`, a,b>0 | `ceil(y*b/a)` |
| NET transfer `g-floor(g*t/D)`, y>0, 0≤t<D | Minimum gross `floor((y-1)*D/(D-t))+1`; y=0 gives0 |
| Weighted swap | Scale output up → `computeInGivenExactOut` → descale input up → source `grossUpExactOut`, exactly once |
| HLP single-token exact output | Actual BasePoolMath :277–342 with scaled caller state, invariant-derived taxable imbalance and upward HLP debit |
| Quote-only contraction uplift | `ceil(qQuoteRequired*WAD/(WAD+p))`, then verify the forward floor; reinvestment uses no uplift |

For NET tax, D10000,t500,y19 requires gross19/net19; blindly using ceil(yD/(D−t)) gives20 and is not the minimal inverse. Resolve active exemption/tax predicates per transfer; do not reuse a cached taxed assumption or add hook-level tax again.

Compose backward from the final requested native output **only through the actual selected dependency graph**; then replay every forward rounding, fee, state mutation, custody debit and output constraint on the same projected snapshot. Execute with max-input/min-output limits and verify delivered output; atomic revert on shortfall. Identify ownership of every residual explicitly rather than giving it to all HLP by default. Ordinary NET/sNET output uses eligible SY, held first then claim if short, and leaves a positive raw-SY budget; it cannot liquidate PLP/YT as a fallback. Owned-reserve burn realization is a separate composition, capped by its actual HLP debit, and consumes/burns q rather than the quote-only uplift.

**Conditional missing evidence:** an external SY's sampled preview rate is not proof that its finite-size redemption is linear, nor that one extra unit suffices. Actual configured conversion source may provide a linear inverse; use it if established. Otherwise WeightedMath does not solve that stage. Similarly, a joint-position exact-input quote and a sequence of redeem calls do not establish a closed composed inverse. No new external SY, generic amount search or silent unsupported withdrawal is authorized.

The three originals do not finish the exact retained-selector inventory, immutable child-init graph, or every route's actual conversion call graph. Those are unfinished engineering deliverables, **not demonstrated product impossibilities or new owner questions**. Do not label a method for enumerating selectors as the completed inventory. The narrow evidence needed is the actual configured stage implementation and its source-mapped inverse/realization, not a new economic policy.

## 4. G4 replacement — insert in §§8 and activation specification

### Bootstrap and expansion

Use PRD §10.4's exact native order:

`Q(x)=floor(nativeToWad(pair,x)*1e9/P0)`;
`G=Q(A)`; `Uquote=Q(floor(A*M/WAD))`;
`principal=floor(Uquote*(WAD-p)/WAD)`;
`reward=floor(Uquote*p/WAD)+floor(G*p/WAD)`.

Mint only G+principal+reward. Additional reference legs are `wadToNative_i(floor(G*P0_i/1e9))`. NET opening is1000e18, creation1e18. Do not invent missing other-leg price bindings from symbols or a claimed sNET1:1 spot. Feed actual conversion receipts into the full four-custody-leg initializer, including actual direct SY capital with zero earned interest. Outer HLP issuance is source invariant V minus minimum1000 and requires every scaled leg positive. The inner geometric minimum is distinct. The buyer's principal is funded before its immediate reward allocation. Failure rolls back activation and all minting. Partial first-mint helpers do not activate this product.

Expansion is `floor(S0*n/200)` on actual starting DETF total supply, one full-precision operation, not B and not a loop. Consume completed epochs once even when the gate mints zero. No imported uint128 supply cap. The result and updated supply must fit their declared widths; a genuine representation failure reverts atomically, not caps/discards epochs. Check actual oracle duration bounds without extending a selected lock or fabricating a calculation duration.

### Two exact-window observed series

For each independent series store ordered `(uint64 timestamp,uint256 cumulativeHi,uint256 cumulativeLo,uint256 postPriceWad)`. Initialize only at a valid activation mark, cumulative0, without earlier history. On a checkpoint at t, accumulate the prior recorded price over elapsed seconds **before** mutation. At the same integer timestamp, retain cumulative and replace only postPrice with the final authoritative mark. No weighted merge and no caller-supplied mark.

Consult at t: extend the last cumulative to t; find the latest stored observation j with `tj≤t−3600`; compute `Cboundary=Cj+pj*(t−3600−tj)`; return `floor((Cnow−Cboundary)/3600)`. If no predecessor exists because valid history is too short, return ready=false. Invalid/no-live contexts and dependency failures are not measured zero or automatically warm-up.

**3601-entry ring proof:** coalescing permits at most one record per distinct integer second. If 3601 records are retained, newest minus oldest timestamp is at least3600, so oldest≤newest−3600≤consultTime−3600. The latest boundary predecessor is therefore retained. Before filling, retain every record. Quiet periods require counterfactual extension, not synthetic observations. A same-second update must not consume another ring slot. This bound fails without coalescing.

Two uint256 limbs suffice: uint256 price integrated over a monotone uint64 timestamp horizon is below 2^320. The 3600-second difference is below `(2^256)*3600`; division fits a uint256 average. Use checked wide arithmetic and reject timestamp regression/out-of-domain casts. Suggested semantic signatures, to be declared once on the shared interface: `consult() returns (bool ready,uint256 priceWad,uint64 timestamp)` and `latestObservation() returns (uint64 timestamp,uint256 cumulativeHi,uint256 cumulativeLo,uint256 postPriceWad)`. Checkpointing stays authenticated/internal.

This is the exact integral of the **recorded piecewise-constant series**. External-only Pendle valuation changes are observed at the next checkpoint, not reconstructed historically. Capture synthetic on every state-changing expansion check, including no-due/zero-mint; separate spot/synthetic readiness and policies. Unready hook history allows due expansion; unready synthetic history selects swap. Equality at1 is not the below-peg branch.

## 5. G5 replacement — insert in §7.3, not a new retirement policy

Store existence/completion validity separately from numeric noteId/epoch; zero noteId is valid, and unlockEpoch0 means assigned Pendle maturity.

| Transition | Required effect |
|---|---|
| Purchase | Atomic holder/tokenId association, actual returned intended noteId, purchase epoch and funded native purchase; holder owner remains NFT contract. |
| Intermediate collection | Measure new redemption receipts, distinguish old balances, atomically contribute/mint/stake intended proceeds and attributable excess as old-NFT principal; no lock restart. |
| Intended completion | Only after successful final contribution and intended claimed==payout, record resulting processed epoch E once and unlock E+1; no gifted-note completion test. |
| Reward claim | Only funded rewards; principal remains backed and lock unchanged. |
| Partial/all funded-principal rebond | Purchase-epoch check plus normal authority/settlement; q≤P, debit q and corresponding old entitlement, incentive-free actual-q burn, new tokenId with independent destination-type lock. No unnecessary native redeem/full-collection prerequisite. |
| Ordinary principal release | Applicable processed-epoch or assigned-maturity gate; settle first. |
| Drained candidate | Intended complete, release condition satisfied, no remaining funded principal/rewards or already-recognized unsettled obligations. This is necessary, not sufficient proof that arbitrary future gifts cannot arrive. |

Do not use aggregate `pendingFor` as completion/retirement barrier, an approximate off-chain zero as an on-chain fact, or absence of current pending notes as proof of no prospective rights. Do not automatically burn and strand recognized rights, sweep gifts, transfer holder ownership or introduce nonburning retirement as settled behavior.

**Precisely unresolved in current product authority:** PRD :935–937 retains H01 late-proceeds timing/direct-donation classification and H03 terminal residual/late-gift handling. Existing E+1 applies to intended completion; it does not uniquely settle the release rule for subsequently funded excess. A finalized irreversible retirement transition also needs an authorized disposition of surviving/prospective same-holder rights. This is an expressly retained product edge, unlike routine ABI/state-layout work. The table above is complete through the drained candidate; claiming a selected final transition would manufacture policy. No general lock/beneficiary questionnaire is needed.

## 6. Acceptance vectors and evidence ledger

These are analytical requirements, not executed tests:

- B3/U2/x1 and B3/U10^27/x1 with fixed principal; reward claim B10/U6/u3/P4/x1; two-holder floors whose sum is below B. Prove principal, not a spurious sum-of-floors equality.
- Standing O80/B800/A100/f20%; U0/Wf20/Wc30/A100; surviving roles after all receipts exit; positive unassigned B; allocation dust over repeated rounds without double allocation.
- Forced interest before user call with c_this0; equal-surplus donation versus authenticated user receipt; same-call valid pretransfer; replay/wrong payer/sibling callback; exact-output refund cannot spend prior custody.
- Geometric seed L1,000,000/Y4,000,000 gives total S2,000,000, lock1000 and admitted1,999,000; later mismatch20/40 acceptance with10/0 residual; last circulating holder cannot take minimum-locked backing; conversion failure restores all inputs.
- Tax19 example; linear floor inverse; Weighted/BasePoolMath directed-rounding source comparisons; nonlinear SY disproving sampled extrapolation; every supported route's composed forward delivery and owned-HLP limit.
- Activation with zero earned interest but positive contributed SY; G1000/Uquote1100/p10% yields principal990/reward210/total2200; S0=1000e9,n3 expands15e9. These numerical percentages are examples, not fee defaults.
- Oracle3599/3600, same-second replacement, every-second ring wrap, sparse/quiet histories, external-only repricing, invalid context versus genuine warm-up, rollback and independent histories.
- Purchase100/intermediate105/final106/unlock107; all-current-principal rebond leaves old NFT alive; unsolicited notes do not reset completion; late principal and irreversible retirement remain explicitly unresolved rather than tested against an invented policy.

### Sources, versions, confidence

All paths are relative to `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex`; inspected 2026-09-27. Primary local source URL: `file:///Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` (v0.30). Companion plan has the same directory and filename `NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (v0.1, all542 lines read). No source commit or live runtime identity was independently pinned by this review.

- PRD :700–774,878–939,995–997,1126–1129; plan :188–254,289–357.
- `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`:151–227: exact-native supporting guarantees, distinct standing weights/dust; gons not selected here.
- `contracts/vaults/detf/common/core/DETFSeigniorageShareLib.sol`:18–33: top-up algebra, not redeemable receipt issuance.
- `contracts/vaults/basic/BasicVaultCommon.sol`:46–54,80–105,108–137: full sync, actual pull versus surplus, refund boundary.
- `lib/crane/contracts/protocols/perps/pendle/core/YieldContracts/InterestManagerYT.sol`:43–79: claim clearing, net fee and index accrual.
- `lib/crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Pair.sol`:269–285,312–323: geometric/min-ratio mint, permanent minimum, proportional burn.
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol`:209–242: local exact-output order and full initial invariant.
- `lib/crane/contracts/protocols/pol/net/src/NET.sol`:121–145: floor tax and net transfer.
- Canonical direct reads: `CLAUDE.md`, `docs/agent/SKILL_CATALOG.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, Crane architecture/testing/adversarial skills, local IndexedEx adversarial skill. No skill invocation.

**High confidence:** local source facts, conditional integer counterexamples, recipient-dilution error, provenance indistinguishability, inner residual error and ring-retention proof. **Conditional/inference:** exact representation feasibility, configured conversion composition and domain reachability. **Not established:** current chain state, configured external SY inverse, complete selector/init graph, execution/gas/security/economic soundness. G0/G1 remain external prerequisites. Narrow unresolved cases above must not be relabeled completed because all participants supplied text. Moderator may incorporate valid replacements directly into the existing plan; this report does not authorize editing or executing that plan.
