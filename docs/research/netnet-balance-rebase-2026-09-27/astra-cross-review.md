# Astra — bounded L1 combined cross-review

Continuing council-astra (`openai/gpt-6-astra` assigned routing, not provider verification). Read the FULL Grok, MiniMax M3 and Kimi K3 ORIGINALS together, as untrusted evidence; no peer cross-review read. Originals unchanged. Only this assigned report written. No execution, code/config changes, RPC, browser or delegation.

**Date discrepancy:** peers and the directory say 2026-09-27; my original says access2026-09-28 from the session environment. Earlier session messages also used September27. I cannot independently reconcile those timestamps. I preserve the original attribution rather than backdating it; this continuation uses the environment's September28. These are reported dates, not independently timestamped chain observations.

## Decision

The references establish working rebasing, not equivalence of all rebasing representations. **Do not close L1 using any peer candidate as written.** Grok/Kimi replace literal live-custody B/U with a refreshed divisor and preminted inventory; MiniMax has a direct other-holder reward-drain error. My original supplies a principal-safe reward-share-budget construction, but not a complete fixed-native-principal admission/dust algorithm. No finding here proves every possible balance-derived implementation impossible.

## 1. Agreements and source facts

All four distinguish raw principal from internal shares and reject holder enumeration. NetNet's exact-native primitive is valuable:

`balance=floor(g/K)` and native transfer x moves `x*K` gons, so displayed balance changes exactly x at fixed K.

Actual source: `lib/crane/contracts/protocols/pol/net/src/StakedNET.sol:58–77,127–136`. `Staking.sol:119–125` **transfers** sNET back into inventory and pays NET; it does not burn total gons. A full displayed exit leaves `g mod K`, which can become nonzero after rebase even though transfers use exact multiplication. Kimi's “sub-unit dust cannot exist” and full-exit-burn description are incorrect.

`StakedNET.sol:25–49,83–99` has fixed TOTAL_GONS, initially5e18 fragment units assigned to Staking, a uint128 supply cap, and an explicit write to `gonsPerFragment`. Calling this a scalar rather than an index does not remove the refresh. No-perholder-loop is not no-authoritative-refresh. Rebase contains multiple integer divisions and a cap; the peers' aggregate-exactness/one-floor bounds are not established merely by quoting its comments.

## 2. Grok/Kimi: the proposed equivalence is false

For T=10,B=3,g=3:

`floor(g/floor(T/B))=floor(3/3)=1`, but `floor(B*g/T)=floor(9/10)=0`.

This is an arithmetic identity refutation, **not a claim T10 is NetNet's production precision**. Whenever T=qB+r, r>0, choosing g=q gives the same mismatch: divisor display1 versus direct-ratio display0. A production reachability argument must therefore establish a specific invariant, not assert the expressions are identical.

The denominator also changes meaning. NetNet T includes its entire preminted inventory. PRD U is aggregate funded ownership. With fragment inventory F0, K=T/F0 initially, one user staking x receives xK gons while actual backing B=x. Substituting U=T yields `floor(x*x/F0)`, not x. For F0=5e18 and x=1e9, it yields0 native units instead of1e9. Excluding inventory fixes this initial comparison, but U is then circulating gons, not constant T; after funding, equality with a rounded divisor is still unproved.

Grok :75,88,136 alternates between gons, fragments and `B≈circulating`; approximate equality does not justify an exact floor identity. Kimi :31–55 expressly stores F/K and updates it on funding, which conflicts with PRD :702–714's live balance formula and no authoritative refresh. Direct custody growth without that write changes PRD balances but not their proposed divisor balances.

**Recipient double allocation:** Kimi :43–45 rebases the full reward Δ to ordinary circulation and then additionally issues fΔ/cΔ recipients' fragments. With old funded circulation100, Δ10, f20%, c0, this creates110 ordinary claims plus2 recipient claims against110 backing. In a live-B/U reinterpretation it instead dilutes ordinary claims: it is not the asserted exact1:1 allocation. Moreover fixed fΔ is not persistent standing-weight allocation. A separate P field cannot repair either error.

## 3. MiniMax: reward claims must debit ownership

MiniMax :112–123 transfers rewards while leaving all shares unchanged. Seed two holders with principal100 each and equal100Q shares, then fund20: B220, U200Q, each displays110. First holder takes reward10 with no share debit: B210 and both now display105. The second holder has lost5 of its reward to the first claimant. Repeated claims worsen the imbalance. This works at arbitrarily high Q and follows the proposed ordinary funding sequence.

Its recipient top-up also sets receipt ownership without using Δ in the issuance calculation (:95–108); describing it as “new backing only” does not make that true. Excluding previously issued recipient receipts from ordinary weight is additionally inconsistent with the standing-allocation reference.

MiniMax :28–33 misreads wsNET: index=1e18 gives1 share for native input1, not zero; `wrap` checks positive input, not positive output. Its cited inverse expression is reversed. These are source/arithmetic corrections, not product disagreements.

## 4. wsNET/Pendle rounding is not a fixed-principal guarantee

`src/perp/WrappedStakedNET.sol:48–85` floors both conversions. At index1.5e9, x1e9 native sNET mints666666666666666666 ws units; full unwrap pays999999999 native sNET. The loss is **one whole raw9-decimal unit**, not necessarily subnative. This is a conversion result, not a claim about current on-chain index or a deployed defect.

Pendle SYBase burns specified shares and checks implementation output minima; it does not require lossless original-native-principal recovery. The first-pass inspected Aave adapter uses nearest-half-up despite a helper named `FromAssetUp`; its underlying normalized-income semantics cannot simply be replaced by B/U. Decimal wrappers' explicit dust receivers are not authorized custom-family beneficiaries. Kimi's partial external SY address/API assertion does not establish its conversion implementation. No newly verified external SY source changes my original conclusion.

## 5. Maximum justified plan-compatible arithmetic

Keep live B, aggregate U, account u and native principal P. Standalone share admission `m=floor(xU/B)` preserves old backing/share rate; redemption of d shares for `floor(Bd/U)` does likewise. Neither alone guarantees independently fixed native principal for the new position.

My reward-share-budget construction remains mathematically sound **under its starting funding condition**:

`p=ceil(PU/B)`; `x=floor(B*(u-p)/U)`; if x>0, debit `d=ceil(xU/B)` and pay x; otherwise leave shares untouched.

Then d≤u−p and `(B-x)/(U-d)≥B/U` for a nonempty remainder. At least p shares remain and still back P; other holders' rate cannot fall. An empty-pool exit is handled separately by full redemption. This proves safety, not complete source parity.

**Correction/qualification to Astra:** the possible gap from `floor(Bu/U)-P` is not universally bounded to one native unit. That bound needs an established share-price domain, e.g. B/U≤1. High initial precision is not a perpetual invariant under uncapped funding. There is also no established deadline at which deferred value becomes payable.

At B6,U4Q,u2Q,P2,Q10^27, a displayed reward1 cannot be paid with the simple upward share debit without violating remaining principal; my budget quotes0 and retains the position. This state follows candidate deposits2+2 and ordinary funding2, not NetNet's inventory/index rules. The arithmetic example does not prove its reachability under every configured recipient policy.

**PRD interpretation:** :710,718,720 permits native rounding/position-local dust. It does not explicitly authorize delaying an already displayed whole-unit reward; :737 preserves principal. The selected `DETFFundedStakingMath.sol:110–116` defines native rewards as value minus remaining principal. Therefore I cannot silently declare my conservative budget equivalent to that source claim. Conversely, the PRD does not promise every fractional entitlement is exact; that stronger earlier inference remains withdrawn.

## 6. Standing rights, remaining limit and minimal clarification

Preserve separate persistent Wf/Wc; O includes all funded ownership, including old recipient receipts. Apply source top-ups and independently floored S,F,C,D allocations. For D0 and exact representability, new funded receipts require `mF=FU/(B+S)`, `mC=CU/(B+S)`, not standing-weight deltas. At U0/Bpre0 with weights20/30 and A100, seed funded recipients40/60. No blanket queue or orphan rejection may erase those rights. Unassigned positive B and allocation dust still need a compatible ownership representation; none of the peer sources closes it.

**Minimal clarification, only if the conservative reward route is desired:** “Does permitted native rounding allow an early reward claim to retain an otherwise displayed whole raw unit when required to preserve principal, while keeping that entitlement attached to the position, rather than paying the reference's full native `value−P` now?” No arbitrary tolerance or waiting guarantee is implied. This answer would resolve the reward-claim semantic edge only—not principal admission or orphan ownership. Redefining computed native principal downward or switching to explicit-index inventory requires a separate express change, not an inference from 'reuse'.

**Unresolved dissent:** Grok/Kimi call their index/inventory proposals equivalent; the equality and denominator checks above reject that conclusion. MiniMax calls unchanged-share reward extraction correct; the funded two-holder example rejects it. No peer provides the complete desired algorithm. L1 remains a narrow unproved integration, not a general rebasing impossibility or a reason to redesign the whole system.

Source authority: PRD v0.30 :700–737; plan v0.2 §9; directly reread NetNet paths above and `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:96–116`. Supporting first-pass references: `DETFSeigniorageShareLib.sol:18–33`, funded-staking plan :198–227; Pendle `core/StandardizedYield/SYBase.sol:37–76`. Public documentation URLs retained from the original: https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield and https://docs.netnet.capital/official-channels . No new external API claim or fetch this cross-review. High confidence in checked algebra/source distinctions; no executed or deployment correctness claim.
