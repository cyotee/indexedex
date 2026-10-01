# Astra — targeted computed-live-divisor analysis

Continuing council-astra, assigned `openai/gpt-6-astra` routing, not provider attestation. Bounded mathematical follow-up, not a new council round. Only this assigned file written. No code, execution, shell/tests, RPC, browser, configuration changes or delegation. Reported environment date2026-09-28; prior report/directory date discrepancy remains unresolved, not rewritten.

## Verdict

**Yes: this is a concrete, useful amendment candidate.** In the positive B/U domain its deposit, transfer and native-withdrawal algebra is correct. It preserves computed native principal without an authoritative stored divisor or holder enumeration. It also allows paying the full currently displayed native reward without the deferral in my earlier share-budget candidate.

**No: it is not the current PRD formula, nor yet a complete zero-share/dust/full-exit specification.** Allocation dust, newly released quantization surplus on withdrawals, finite-unit saturation, and U=0 ownership require explicit treatment. Those are the remaining issues of this particular proposal, not an impossibility assertion about rebasing.

## 1. Domain and invariants

Assume B>0, U>0, nonnegative integer u_i summing to U, and actual custody-backed operations. Define, on every read:

`K=ceil(U/B)`, `v_i=floor(u_i/K)`, `L=floor(U/K)`.

Then `K>=1` and `sum(v_i)<=L<=B`. All quotients/products below require checked/full-precision implementation; these are integer equations, not code. Define `e=KB-U`. Because K is the ceiling, `0<=e<B`.

This distinguishes aggregate redeemable liability L, sum of individually displayed balances, and physical backing B. They need not coincide. Keeping `totalSupply=B` as backing metadata would not make B the redeemable liability; that interface meaning must be explicit.

## 2. Exact deposit and transfer proofs

Deposit x>0 actual native units, issuing m=xK raw units:

`U'=U+xK=K(B+x)-e`, `B'=B+x`.

Since `0<=e<B<B'`, `ceil(U'/B')=K`. Old displays are unchanged and the receiving account increases by exactly x, even if it already has a remainder: `floor((u+xK)/K)=floor(u/K)+x`. This is a real exact-native solution, not a high-precision approximation.

A native transfer x moves xK raw units between accounts; B/U/K do not change, so sender/receiver displays change by exactly -x/+x. Check ownership/allowance and settle required expansion before either operation.

## 3. Native withdrawals, principal and rewards

For `x<=floor(u/K)`, pay x and burn xK raw units. If B',U'>0:

`U'=K(B-x)-e`, hence `K'=ceil(U'/B')=K-floor(e/B')<=K`.

Every untouched holder's displayed balance cannot fall. At the old K the withdrawing account's display would be exactly v-x; at the recomputed K' it is at least v-x. Thus:

- Principal debit q changes P to P-q and preserves remaining backing.
- Reward claim `x=v-P` leaves P unchanged and backed; the complete currently displayed reward can be paid.
- The debit may release additional funded surplus by lowering K; the caller's display need not decrease by exactly x. This differs from the source's fixed-K ordinary withdrawal.

If B'=0, validity forces U'=0. If U'=0 but B'>0, do not calculate K=0 and divide by it: this is a separate residual-ownership branch.

## 4. Recipient allocation: proven when allocation dust is zero

Apply the existing separate standing weights and two-stage S/F/C/D allocation first. With D=0, let `b=B+S`, `k=ceil(U/b)`, and issue Fk/Ck raw units to the established recipients after funding all A=S+F+C.

Write `e_t=kb-U`, with `0<=e_t<b`. Final state is:

`B'=b+F+C`, `U'=U+(F+C)k=kB'-e_t`.

Therefore the recomputed divisor is exactly k. Existing raw ownership receives the ordinary backing increase; each recipient's balance increases by exactly its native F/C issuance at that k. No ordinary holder enumeration, stored reward divisor or double allocation is needed. Previously held recipient receipts participate ordinarily; standing weights themselves remain nonredeemable.

**D>0 breaks the claimed final-divisor identity.** Example, all in native/raw integer units:

`B=2,U=5,O=5,Wf=15,Wc=0,A=2`.

Using source precision1e54 gives S0,F1,D1. Old K3; target k=ceil(5/2)=3. Issue3 fee units; final B4,U8 gives **K'=2**, not3. Old ownership rises from floor(5/3)=1 to floor(5/2)=2 although its allocated S was zero. Allocation dust has crossed into ordinary value rather than remaining reserved for later weighted allocation.

A bookkeeping label cannot prevent that while K uses all live B. Using `ceil(U/(B+S+D))` would explicitly allocate D to ordinary backing instead; that is a change from the reference's separate allocation-dust policy, not an algebraic repair. Excluding D from B or issuing ownership for a dust bucket likewise needs an explicitly adopted rule.

## 5. Full exit: safety versus semantic ambiguity

At entry write `u=xK+r`, `0<=r<K`. Paying x and atomically removing all u preserves others' principal: `U-u<=K(B-x)`, so the remaining divisor cannot increase. However, **retiring the old subnative r after a recomputation may erase newly whole native value**.

Example B10,U21,K3; exiting owner u5, other owner u16. The first owner displays1. A partial withdrawal1 burns3, leaving B9,U18,K2: its remaining2 units now display1. It can withdraw that additional1, ending B8,U16,K2. Conversely, an atomic full-exit rule paying the original display1 and removing all5 units leaves B9,U16,K2; the caller receives only1.

Thus snapshot-full-exit and sequential native withdrawals differ by a whole native unit. Both remain funded, but they allocate formerly undisplayed surplus differently. Do not call the removed remainder subnative at the *post-withdrawal* divisor. Specify whether full exit prices at entry and retires entry fractions, or retains newly redeemable value; no silent extra payout, sweep or iterative completion claim is proved here.

## 6. Empty state, saturation and no hidden cap

- B=U=0: choose an explicit raw-unit normalization Q>=1; funding x with xQ units gives K=Q. The supporting source uses1e36, but adopting that value is a specification choice, not proof of an unlimited numeric horizon.
- U>0,B=0: invalid funded-positive-liability state for this definition; no division or fabricated fallback. Under the proven funded transitions, B reaches0 only with U0.
- U=0,B>0: K would be0. A first depositor cannot safely inherit all existing backing. Provenanced recipient funds can seed recipient units at an explicit common normalization, but unrelated residual ownership is not supplied by the formula.
- **U<B implies K1:** L=U; further ordinary reward deposits do not increase displayed balances at all. Ordinary deposits add x to both U and B, so cannot remove this existing surplus gap. High initial Q postpones this saturation; it does not eliminate it without a proved operating domain or a further representation change.
- Even before saturation a last whole-balance exit can leave positive B: B4,U6,K2 gives a sole holder display3. Paying3/burning6 leaves B1,U0. That residual is not free first-depositor credit.

No economic supply/epoch cap is introduced by this analysis. Finite raw units nevertheless limit the quantization mechanism. Do not claim every funded reward eventually becomes claimable merely because arithmetic fits uint256.

## 7. Exact amendment required and source comparison

Current `NETNET_PENDLE_DETF_PRD.md` v0.30 :702–714 says `fundedBalance=floor(B*u/U)` and funded rebasing supply=B. The proposed replacement is `K=ceil(U/B)` and `fundedBalance=floor(u/K)`, with aggregate redeemable liability `floor(U/K)`. Example B3,U10,u4: current display1; proposed K4/display1, but aggregate liability2 rather than backing3. With u3, current display0 versus proposed0; more generally the formulas are not identical (B3,U10,u7: current2 versus proposed1).

The candidate **preserves intent** of live custody observation, unchanged ordinary raw units on funding, exact native admission/transfer/payout and principal protection. It **changes** quantization, backing-versus-liability/supply meaning, withdrawal-triggered surplus release, and empty/full-exit dust semantics. It cannot be silently selected under the existing formula.

The supporting funded-staking plan :151–194 has stored K, exact xK operations, `Knew=ceil(Q/(oldLiability+ordinaryReward))`, and separately tracked allocation/rebase/unsolicited buckets. The candidate borrows its safe ceiling/multiplication arithmetic, but derives K from all live B and consequently releases surplus on withdrawals and donations without a stored-K distribution event. That distinction is substantive.

**Recommended disposition:** present this as an explicit minimal *balance-formula amendment candidate*, with the proven positive-domain/D0 transitions above. Do not mark L1 fully closed until the amendment also selects the supply meaning, D>0 treatment, full-exit convention, U0 residual ownership and saturation behavior. These are concrete consequences of the proposed formula, not requests to redesign the whole product. No amendment or implementation is authorized by this report.

Evidence: current PRD :700–720 and `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md:151–227` directly reread. Earlier direct source: `DETFSeigniorageShareLib.sol:18–33`; NetNet `StakedNET.sol:58–99,127–136`. High confidence in integer proofs/counterexamples; no execution or deployed-contract conclusion.
