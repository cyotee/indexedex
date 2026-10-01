# Astra — ORIGINAL in-place plan completion analysis

2026-09-27. Read implementation plan v0.1 (all 542 lines), PRD v0.30's operative accounting/lifecycle/source-map provisions, current CLAUDE and canonical architecture/testing guidance. Prior history retained; no current-round peers read. Routing `openai/gpt-6-astra`, not provider attestation. No execution, code/configuration edits, external queries or delegation. Only this report written.

## Delivery and limit

The following text supplies inline replacements for plan §§5–10, not instructions to author another annex. **I cannot honestly mark all G2–G5 complete:** exact native principal preservation with unrestricted integer B/U share issuance has a concrete rounding obstruction. Anonymous pretransfer provenance also cannot be inferred from an undifferentiated balance surplus. These are specific mathematical/information limits, not missing-code objections. Other completed formulas and transitions below can be incorporated now. G0 and actual G1 remain external prerequisites.

## G2 replacement: staking arithmetic, allocations and receipts

### State and elementary transition contract

Store internal shares `u[account]`, `U=sum(u)`, per-NFT outstanding native principal `P[id]` and attributed shares, persistent nonredeemable standing weights `Wf,Wc`, and separately identified rounding/allocation liabilities. B is **always live held DETF**, not an accounted-backing replacement. Displayed balance remains `floor(B*u/U)` for U>0.

Settle expansion before participation changes. No rewards are claimable until actually funded. Reinvestment debits only requested `q<=P[id]` and that position's corresponding shares/backing; its reward rights and future native note remain. New bond receives independent shares/principal/tokenId. All state changes and external composition roll back together.

**Exact arithmetic condition—not a safe rounded substitute:** for deposit x at B,U>0, preserving every existing proportional entitlement while crediting x requires new shares

`m = x*U/B`.

For withdrawal x, the analogous exact proportional debit is `d=x*U/B`. Full-precision mulDiv prevents intermediate overflow but does not make a noninteger quotient integral.

**Counterexample:** one old position owns all U=2 shares, B=3 native DETF, and has principal3. New position deposits1. Minting m=0 credits it0; minting m>=1 gives the old position at most `floor(4*2/3)=2`, below its principal3. No integer m satisfies both. In general, old balance>=B requires `m<=xU/B`; new balance>=x requires `m>=xU/B`. Thus equality is necessary. Increasing fixed precision does not eliminate nondivisibility (e.g. B=3,U=10^27,x=1).

This is **conditional on finite integer shares and exact non-dilution/native-principal guarantees**, not proof that every augmented representation is impossible. A principal guarantee outside the B/U balance formula, a rounding subsidy, rational-share representation or restricted deposit domain is an additional design/behavior—not silently equivalent. Do not declare `ceil(xU/B)` safe for other principals or `floor(xU/B)` exact for the newcomer. Plan §9 must state this obstruction rather than mark arbitrary rounding “finished.”

### Standing allocation: the part that is determined

Reuse `DETFSeigniorageShareLib.sol:18–33`: `T=floor(O*WAD/(WAD-f-c))`; top up Wf/Wc toward `floor(T*f/WAD)` and `floor(T*c/WAD)`, never reduce them on exit. O is actual ordinary ownership weight, including previously issued recipient receipts; standing weights are not token backing.

The supporting funded-staking plan `:198–227` allocates via `rps=floor(A*1e54/(O+Wf+Wc))`, then independently floors each weighted allocation. It is **not** a fixed fA/cA split. Preserve recipient rights and ordering; do not import its gons-index update.

For an exact allocation with B'=B+A after funding and recipient target F+C, unchanged ordinary shares require recipient-share total

`mTotal=U*(F+C)/(B'-F-C)`,

split proportionally between recipients. Again, integer exactness is not automatic. Allocation dust physically included in live B must have an explicit corresponding share entitlement; it cannot simultaneously be already distributed by B/U and later allocated again.

At U=0, B=0, first stake can initialize shares proportionally to x. At U=0, B>0, assigning the next depositor all shares gifts it old backing. Standing recipients after prior full exit retain weights, but that does not itself specify ownership of arbitrary orphan backing or quantization dust. This branch must not fabricate a sweep, index, or recipient. Tests must include the B=3,U=2 case, all-stake-exited reward, orphan backing and repeated reward-only claim/deposit sequences.

### Pretransfer and force-claim receipt contract

Use an operation-scoped receipt `(nonce,payer,token,openingBalance,credited,consumed)` produced only by an authenticated measured funding transition. Pull mode snapshots before `transferFrom`, credits its actual delta, and consumes/refunds that receipt once. Native/Pendle claim paths have separate receipts and cannot generate user-funding credit. Finish refunds before full-set BasicVault synchronization.

`BasicVaultCommon.sol:80–105` supplies pull delta but anonymous push mode merely computes B−R. Two histories—user-funded push versus equal unrelated donation—can expose identical destination balances and caller arguments. A stale flag or later sync cannot prove sender provenance. Therefore legacy bare `pretransferred=true` cannot safely acquire user credit from arbitrary surplus without an independently authenticated funding boundary. The plan must either map each supported caller to such an existing atomic funding context or explicitly record the compatibility mismatch; it cannot claim a new receipt flag proves a prior transfer.

Pendle `InterestManagerYT.sol:43–57,63–79` zeros accrued interest when paid and computes fresh accrual from indices. Track receivable-to-held movement once; forced receipts and direct donations remain distinct. An operation initiated after an external force-claim must reconcile that state **before** measuring fresh user funding; a pre-existing legitimate transfer cannot simply be swallowed. No speculative balance-interface survival policy is introduced.

## G2/G3 replacement: inner shares and deterministic conversions

### Inner PLP/YT admission

For live reserves L,Y and supply S, actual isolated ingress x,y:

`m=min(floor(x*S/L),floor(y*S/Y))`;
`acceptedL=ceil(m*L/S)`, `acceptedY=ceil(m*Y/S)`.

These accepted amounts do not exceed x,y. Credit m; place `x-acceptedL,y-acceptedY` in a **this-call residual**, never the existing owners' uncredited backing. For NET/sNET-funded entry, realize that residual through the selected pre-expiry SY exit and redeem/refund in the supported input denomination, with caller limits. If that actual conversion is unavailable, the complete entry reverts; no donation or pending user balance. Direct loose-PLP/YT admission is not added.

Example L=100,Y=200,S=100,x=30,y=40 gives m=20, accepted(20,40), residual(10,0). Use native integer units in executable vectors. Initial geometric shares and minimum locking follow `UniV2Pair.sol:269–285`; outer HLP must not also count L/Y directly. Position exit preserves nested floors. Across atomic rollover, keep S/ownership fixed while replacing active backing, with expired YT/historical claims separately tracked—not assigned principal face value.

### Inverse primitives, without search

Implement internal mathematical contracts `quoteOwnedBurn(q,tokenOut,snapshot)` and `quoteInputForOutput(tokenOut,y,snapshot)` returning raw amounts plus the custody/HLP realization debit. These are specified helpers, not claims of existing selectors or new public contraction routes.

For fixed-state linear conversion `out=floor(in*a/b)`, exact-output funding input is `ceil(y*b/a)`; forward-check actual deliverability. For NET tax `net=g-floor(g*t/D)` and y>0, the **minimum gross** is `floor((y-1)*D/(D-t))+1`, for `0<=t<D`; this respects the actual floor tax (`NET.sol:131–144`). Example D=10000,t=500,y=19 gives gross19/net19, not blindly gross20.

Weighted layer: `WeightedMath.computeInGivenExactOut:199–234`; scale output up, invert, descale input up, and apply the source fee gross-up (`WeightedBufferHookMath.sol:209–227`). Burn uplift inverse: `q=ceil(qQuoteRequired*WAD/(WAD+p))`; forward-check. Reinvestment uses no uplift.

Build owned native components using owned HLP over **fee-diluted** supply before nonlinear valuation. NET position valuation must quote the allocated LP/YT on one post-burn market-state copy. HLP single-exact-output debits use actual BasePoolMath, not approximate wrapper fees. Ordinary NET/sNET instead debit shared SY and leave at least one raw eligible SY unit.

**Conditional G1-linked obstruction:** a configured SY or allocated joint-position conversion known only through exact-input preview is not supplied with a general exact-output inverse by WeightedMath. Nor does its API promise linearity. The complete inverse is finished only for source-verified composable stages with such arithmetic; arbitrary nonlinear stages cannot be “solved” by an invented binary search, a larger minimum output, or an unsupported withdraw branch. No concrete deployed adapter/inverse has been established here. Likewise no source fixes a unique four-leg owned-burn realization waterfall merely from the synthetic mark. Do not present the helper contract above as a working implementation of that missing composition.

## G4 replacement: bootstrap and exact-window observation algorithm

Activation receives actual amounts for **all four custody legs**, including direct SY capital; it does not wait for earned interest. Mint G from the opening quote, join only actual capital+G, fund principal and then immediate rewards; commit activation only after success. Source: `UniswapV4DetfTarget.sol:629–693`; `DETFMintSplitLib.sol:45–52`. Preserve NET creation1/opening1000, weights50/20/10/20 and fee-source order. Quantities requiring an external conversion use its validated G1 quote; no illustrative FX number is a configuration value. The full-book initializer `WeightedBufferHookMath.sol:234–242` requires every scaled leg positive; partial initialization is not a bypass.

**Concrete observed-series algorithm:** each series stores `(timestamp,cumulativeHi,cumulativeLo,postPriceWad)`; coalesce all writes with the same integer timestamp. C accumulates the *previous recorded* price before mutation. Consult at t extends C using that recorded price. Locate the latest observation at or before t−3600, extend it to that boundary with its post-price, subtract and divide by3600. No earlier observation means unready; dependency failure is not unready.

A **3601-entry ring is sufficient under the explicit one-record-per-distinct-integer-second invariant**: 3601 retained timestamps span at least3600 seconds, hence retain a boundary predecessor; before filling, retain every observation. Long quiet periods use extension, not fake records. This is a retention proof, not a gas proof or a universal bound without coalescing. Ordered-history lookup is not an amount-search solver.

Two uint256 limbs suffice for the cumulative over a uint64 timestamp horizon and uint256 price: total integral is below 2^320. Same-timestamp writes update only post-price. Define `consult() -> (bool ready,uint256 twapWad,uint64 timestamp)` and `latestObservation() -> (uint64,uint256,uint256,uint256)` in the common interface; state-changing checkpoints are internal/authenticated, not caller-supplied prices. Test activation+3599/3600, every-second ring wrap, same-second changes, quiet gaps, external repricing at next checkpoint, and full transaction rollback. This computes the recorded piecewise-constant series—not an unsampled external-price integral.

## G5 replacement: preserve the entitlement handle

State `ACTIVE`, `FINAL_WAIT`, `DRAINABLE`, `DORMANT` plus separate completion validity. Final successful intended collection sets E+1 once; intermediates do not reset. Pre-maturity funded rebond ignores full-collection state, preserves purchase check, burns only requested old principal and creates a new tokenId with its own lock.

At completion/unlock with no funded principal/reward or recognized unsettled obligation, `retire(tokenId)` marks **DORMANT, without burning the transferable NFT or changing permanent holder owner**. This preserves the same-tokenId beneficiary handle for future native gifts; do not infer that no future note can arrive. A dormant position can still collect attributable native excess through the same atomic contribution path; no second intended purchase or fee sweep.

**Remaining exact semantic edge:** PRD H01 still does not determine whether newly funded post-completion excess inherits the old satisfied unlock or gets a fresh wait. Neither a source note's vesting end nor E+1 for the original final installment answers that question. The dormant representation prevents loss of rights but cannot choose the late-principal release rule without an economic assumption. If mandatory NFT burning is required instead of retained-token retirement, future late-gift ownership is an additional irreducible issue; transferring proxy ownership is not an authorized remedy.

## Status

These equations/state transitions belong **in the existing plan**, replacing annex requests. They supply substantial G2–G5 content but do not manufacture a finished proof for integer B/U exactness, anonymous-push provenance, unspecified nonlinear inverse/funding composition or terminal late-principal timing. G0/G1 remain external. No broad questionnaire, new fees, caps, cadence, lock default or external SY deployment is proposed. All tests described are required vectors, not executed results. High confidence in cited source facts and the conditional B/U counterexample; no identity/guard failure occurred.
