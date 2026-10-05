# Astra — Aperture feasibility: single combined cross-review

**2026-10-03.** Continued Astra session. Read all three complete current originals together: Grok replacement, MiniMax M3 and Kimi K3. No peer reviews or syntheses read. Originals preserved. Research only; no tests, execution, implementation, delegation or gas measurement. Findings remain attributed; no consensus claim.

## 1. Decisive conclusion

**The fixed-segment whole-book equation remains quadratic in the continuous model, including arbitrary F/prior E, a fixed set of multiple owned positions and proportionate own-LP fee recovery after V4 protocol take.** MiniMax's cubic/quartic/quintic and Abel–Ruffini objections are incorrect. Grok supplies a correct restricted zero-protocol-fee derivation; Kimi identifies the correct degree but uses the wrong own-fee coefficient. My original sqrt-price formulation survives independent expansion; below I give a simpler gross-input formulation that exposes the cancellations and includes prior swap prefixes.

This resolves a continuous algebra question—not integer optimality, execution parity, liveness or economic safety. Aperture remains V3 code requiring a V4 port. Its general path discovers the terminal segment; a certified single-segment variant can avoid that discovery. Neither version automatically removes Orbital's outer inversions or permits a nested unlock.

## 2. Re-derivation in gross input, with both directions and protocol fees

All quantities in this section are **continuous approximations in raw currency units**, with sqrt price s normalized out of Q96. No placement or liquidity change occurs during a segment. Let:

* L>0: all active pool liquidity;
* ℓ: sum of vault-owned active liquidity, ρ=ℓ/L;
* f<1: combined swap-fee fraction; g=1−f;
* φ: directional V4 protocol fraction of gross input;
* a,b: incumbent input/output backing at this segment start, including F, earlier E and previous-segment changes, excluding caller credit;
* d: caller input remaining; e: caller output already accumulated;
* u: additional gross input spent in this segment; v(u): additional output.

Within the segment:

```
v(u) = β*u/(L+γ*u)

token0→token1: β=L*g*s², γ=g*s
token1→token0: β=L*g/s², γ=g/s
```

Principal increase on the incumbent input side is `ρ*g*u`. Own LP recovery is `ρ*(f−φ)*u`, **not** `ρ*f*(net input)`. Therefore

```
α = ρ*(1−φ)
B_in(u)  = a+α*u
B_out(u) = b−ρ*v(u)
C_in(u)  = d−u
C_out(u) = e+v(u)
```

Local source substantiation: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol:35–46` applies protocol fee first and computes combined pips with the specified floor; `utils/UniswapV4Quoter.sol:214–225` subtracts protocol take before Q128 LP growth. In the exact implementation, fee/protocol/growth floors replace these smooth proportional terms. The polynomial is a candidate model, not those integer operations.

Let `P=b*L`, `Q=b*γ−ρ*β`. Expanding

`(d−u)*(b−ρ*v) − (e+v)*(a+α*u) = 0`

and multiplying **once** by positive `L+γ*u` gives:

```
A*u² + B*u + C = 0

A = Q + α*β + e*α*γ
B = β*a − d*Q + P + e*(a*γ + α*L)
C = e*a*L − d*P
```

This covers **both directions** using their β,γ. At the first segment e=0,d=c. With no protocol take α=ρ, reducing to Grok's coefficients exactly. At zero total fee f=φ=0, the equation remains quadratic with arbitrary nonzero F and prior E; they appear through a,b rather than vanish.

**Hand-checkable example contradicting the sleeve-degree claim:** L=100, ℓ=50, s=1, f=φ=0, a=b=100, d=10,e=0. These backing amounts can comprise owned principal 25/25 in a position with sqrt-price endpoints 0.5 and 2, plus F=75/75. The polynomial is `100u²+19500u−100000=0`, with u=5. Output is 100/21; incumbent backing becomes 102.5 and 2050/21. Both contribution ratios are 2/41. Nonzero sleeves plainly do not force degree three. This is symbolic/hand arithmetic, not executed validation.

### Why multiple ranges do not raise degree inside the segment

Each active position contributes `l_j/t−l_j/b_j` token0 and `l_j*t−l_j*a_j` token1. Inactive positions contribute constants. Summing gives `D0=k0+ℓ/t`, `D1=k1+ℓ*t`. Fee recovery also uses aggregate active ℓ in the continuous model. Thus adding positions changes coefficients and introduces **new segment boundaries**, not additional polynomial powers inside a fixed active set. Exact fees must still be tracked per position/checkpoint because floors do not distribute over sums.

### Clearing denominators is not a degree proof

If a derivation unnecessarily multiplies by another `L+γu`, the resulting expression may look cubic while containing that nonzero factor. Similarly multiplying a sqrt-price equation by excessive powers of t can introduce extraneous t=0 factors outside the domain. Factor/cancel before declaring the true degree. Exact floor functions are not “degree 4+ polynomials”; they make a discrete, piecewise arithmetic predicate.

Even had the equation been cubic or quartic, both degrees admit general radical formulas. Abel–Ruffini does **not** prohibit them; it concerns the general polynomial of degree five or higher. Nor would merely exhibiting a quintic establish that this particular quintic lacks a special solution. MiniMax's claimed no-go argument supplies none of those prerequisites.

## 3. Monotonicity, continuity and degenerate roots

Define the pre-placement comparison

`G(u)=(d−u)B_out(u)−(e+v(u))B_in(u)`.

On a funded segment, u≤d, e≥0, a,b positive, B_out≥0, α,ρ≥0 and v'>0:

```
G' = −B_out − (d−u)*ρ*v' − v'*B_in − (e+v)*α < 0
```

Thus a sign bracket has at most one continuous physical root; a root exists in the permitted interval only if endpoint signs bracket it (including equality). A budget or 50 bp limit can end the admissible path before the root. A quadratic solver returning a number is not proof that it is in this interval.

At an initialized tick, principal amounts are continuous in the continuous model; accumulated fees and caller balances carry forward, while L and ℓ may change slopes. Recompute segment-start a,b,d,e after each committed prefix. Other LP ticks change L; own range boundaries can also change ℓ even if net aggregate liquidity change happens to cancel. Keep all relevant boundaries/checkpoints, not merely nonzero net-L changes.

For L=0, necessarily ℓ=0 for actual active positions: no division/root solve is valid, and traversing a liquidity gap may move price without spending budget. Therefore budget depletion alone does **not** prove bounded work. Boundary/word progress, finite price limits and explicit read/step caps are required. If no reachable funded bracket exists, fail honestly.

Degeneracies must be explicit: A=0,B≠0 gives a linear candidate; A=B=0,C≠0 gives no root; all zero requires direct economic classification. Signed coefficients, discriminant width and numerically stable root selection need proofs. Do not assume the upstream “+sqrt” branch is universally correct for extended coefficients. Validate roots against the original rational equation and valid price/input domain.

**Correction/strengthening of my original:** I asserted continuous monotonicity informally; the derivative above states its conditions. I still do **not** claim monotonicity/completeness of the exact post-placement integer acceptance predicate. Floors, checkpoint realization and discrete placement decisions require separate validation. A successful one-candidate certificate proves admissibility of that candidate, not that every feasible amount will be found.

## 4. Attributed mathematical agreements and corrections

### Grok replacement

Agree with its distinct continuous whole-book quadratic, separate caller/holder ownership, lack of an integer proof, and distinction between NFT sizing and common-share issuance. Its no-protocol formula `B_in=a+ρu`, `B_out=b−ρv` is correct under its stated smooth assumptions. My general α above closes its protocol-fee gap.

Its “does not cover wings” needs narrowing: its formula written for one in-range position does not implement wing transitions, but a fixed active set of wings is covered by aggregated ℓ and constants. Its sufficient domain restricted to the vault's interior is safe but unnecessarily narrow algebraically. A second position also does not inherently require a second salt when endpoints differ; identity is `(owner,lower,upper,salt)`. Distinct salts are needed to distinguish otherwise-identical owner/range keys or are a chosen organizational policy.

### Kimi K3

Agree with the no-degree-increase conclusion, the distinction between a verified candidate and universal liveness, and the need to separate placement. **Correct its own-fee term:** with zero protocol fee and net input n, fee is `f*n/(1−f)`, not f*n. For token0 input,

`ownFee0 = ℓ*(f−φ)/(1−f)*(1/t−1/s)`.

At φ=0 this is `ℓ*f/(1−f)*(1/t−1/s)`. With protocol take, using f alone credits protocol revenue to holders. Its claimed coefficient derivation therefore needs correction despite the correct degree conclusion. Its mixed Q96/real coefficient notation should also be replaced by one consistently scaled system.

“50 bp typically means 0–2 initialized ticks” is unsupported. A 0.5% price interval spans roughly 50 unit ticks; initialized-tick count depends on spacing and distribution, not simply market liquidity depth. D20 is an impact bound, not a substitute for work budgeting.

Collection must follow fixed caller credit, not “before credit/quote.” Current placement occurs before mint, not post-mint, and its loss is attributed before final share issuance (`HTransitionPlanner.sol:135–153`; implementation plan `:207–214`). Exact-in retain-and-book is current law, not an undecided refund choice.

### MiniMax M3

Reject its sleeve→cubic, own fees→quartic, wings→quintic and nonsolvability claims for the continuous fixed-segment problem. Its substitution conflates final price with the price change: `t=L*s/(L+g*u*s)`, while the numerator containing u*s² describes `s−t`, not t. It also mixes Q96-scaled sqrt price with normalized real equations without the corresponding scale factors.

Empty sleeve is **not necessary** for quadratic solvability. Conversely, setting F=0 alone is not sufficient to recover Aperture's exact position-ratio equation: own newly earned fees/prior earned assets can still change incumbent composition. “E≈0 on first deposit” is not an admissible accounting simplification for a live vault; first activation separately remains dual-funded F0.

For an exact reduction to the continuous single-position target, require incumbent backing proportional to that position's principal for every t in the segment—for example, that sole position with no F/prior E and no own LP fee recovery during this swap, excluding degenerate zero legs. Even there integer principal/share rounding and placement certification remain. “Dominated by D” is an approximation, not a sufficient exact domain.

## 5. Actual source flow and port corrections

Freshly re-read pinned [Automan.sol](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/base/Automan.sol) and [SwapRouter.sol](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/base/SwapRouter.sol).

* **Single pool-token input:** `mintOptimal` conditionally pulls each nonzero desired amount. One can be zero. Empty swapData calls `_optimalSwapWithPool`, which calculates the amount on-chain then executes it. Agree with Grok/Kimi; MiniMax's “mintFromTokenIn is the only scalar surface/no autonomous single-token path” is false.
* `mintFromTokenIn` is a separate unrelated-token routing interface with supplied allocations; its helpers themselves allow direct-pool paths when corresponding swapData is empty. Its existence cannot disqualify the simpler unilateral pool-token call.
* `getOptimalSwap` is an external view with no owner/controller gate in Automan. Owner setters do not gate that view. Automation removal/rebalance checks permit owner **or** controller; `mintOptimal` is not universally controller-only.
* The view returns four numbers; Automan executes swap, approval, mint/increase and refund. It does not choose new ranges: ticks are caller-supplied or read from the existing NFT.
* **Correct Kimi:** execution's sqrt-price limit is global MIN+1/MAX−1, not the calculated final sqrt price. The calculated price is not even used as the execution limit in `_optimalSwapWithPool`.
* **Correct MiniMax:** one direct pool swap can cross many ticks; it is not a “single-tick-boundary swap.” Its pseudocode reverses liquidityNet signs: subtract moving token0→token1/left, add moving right. Its comments also reverse the required asset below/above range: below needs token0, above token1.

### Core-compatible stepping and fee floors

The exact declared dependency [uni-v3-lib v3.0.3 TickBitmap](https://raw.githubusercontent.com/Aperture-Finance/uni-v3-lib/v3.0.3/src/TickBitmap.sol) was re-read. `nextInitializedTick` has an uncapped empty-word scan and assumes a next initialized tick exists. Negative compression floors toward negative infinity. Neither “finite range” nor an input budget is sufficient proof of safe termination for every state of these unchecked scans. Kimi's guaranteed/economically bounded termination needs those preconditions; MiniMax's empty/zero-L explanation is internally inconsistent (equal next price cannot trigger a not-equal break).

The initialized-tick jump can omit empty-word computational boundaries that the core processes. Cache bitmap reads if useful, but retain core step rounding. Source prefix fee gross-up is rounded up; some final-segment gross-up expressions use floor mulDiv. Fee growth has additional Q128 floors. Neither fork heritage, NatSpec nor `unchecked` makes these operations exact by assertion.

Crane `UniswapV4Quoter.sol:233–288` uses within-one-word steps, direction-correct crossing, and own-fee tracking. Use it as a source-exact forward certificate, not as a solver. Protocol fee calculation is `protocol+lp−floor(protocol*lp/1e6)` (`ProtocolFeeLibrary.sol:39–46`); ownership deducts protocol before LP growth (`Quoter:214–225`). V3 protocol fees, when enabled, are a share of V3 swap fees; they are not grounds to assume V4 protocol fees absent or merely additive.

## 6. V4 signs, unlock state and preview semantics

Context7 `/uniswap/v4-core` followed by fresh [PoolManager.sol](https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol) confirms:

* V3 positive amountSpecified is exact-in; V4 exact-in is **negative**.
* V4 caller BalanceDelta: **negative means owed to manager, positive means receivable**. MiniMax's opposite sign and proposed direct V3 output-negation port are wrong.
* ERC20 debt settlement requires sync **before** transfer, then settle. MiniMax's transfer→sync→settle sequence would snapshot after payment.
* `modifyLiquidity` callerDelta already includes feesAccrued. Position owner is msg.sender; Orbital cannot simply modify a position owned by the Hookless vault under Orbital's address.
* `unlock` rejects when already unlocked. `swap`/`modifyLiquidity` check the manager's **global unlocked state**, not that the immediate caller is the unlock initiator. Calls by another contract during that session are a possible protocol integration design, with caller-owned deltas/positions and complete settlement—not a nested unlock.

**Clarification to my original and Grok/Kimi shorthand:** the current product expressly chooses sleeve-only operations while the same manager is already unlocked. Aperture supplies no implemented active-session adapter, and this review does not authorize one. But global-state V4 semantics do not prove all active-session execution is impossible. A read-only sizing view can also be called while unlocked if its state inputs are coherent. It need not be precomputed before unlock, nor does computation itself trigger AlreadyUnlocked. A hypothetical change would need custody, transient liabilities, reentrancy and ownership review—not merely moving view timing.

No V4 lock constrains an unrelated V3 pool in general; a V3 call fails for its own ABI/pool/lock/funding reasons. MiniMax conflates these protocols when attributing a V4 `OnlyWhenUnlocked` failure to the V3 direct path.

Same-state preview/execution equality requires a faithful transition model and identical starting state, not Flashbots or a TWAP oracle. Conversely, two deterministic view calls returning the same value do not prove the model matches real execution. D30 requires exact deterministic integer parity, not an unexplained ±1 wei allowance.

## 7. Candidate certificate versus product liveness

The supported exact-input procedure remains: freeze credit/exclusions and checkpoints; identify a permitted segment with a core-compatible bounded walk or a one-step certificate; solve one analytic candidate; execute source-exact forward quotation and placement accounting; require funded deltas, positive shares, minShares, 1 bp alignment/share-flooring, 50 bp terminal **price** impact and 10 bp fee-inclusive fill protection; execute the committed plan and reconcile.

A fixed root±1 stencil is not automatically “not a probe sequence” because it has only a few candidates. If it explores economic amounts and selects a passing one, classify it honestly. A mathematically proved rounding correction can be arithmetic; absent such proof, choose one candidate and reject or obtain explicit approval for the bounded stencil. No local loop ban is being invented; this distinction follows the task's requested comparison.

Successful certification establishes the candidate's conditions. It does **not** establish that a passing nearby integer is found, that 1 bp survives tiny token units, or that repeated deposits provide useful service. Sizing before placement does not resolve terminal losses; placement's discrete branch can defeat a smooth root or monotone-sign argument. My original deliberately left these open; they are still release gates.

Maintain caller funding separate from incumbent repricing/own fees and collect E once after credit is fixed. Current exact-in residuals remain owned/booked, not refunded. MiniMax's credit−spent refund is not current Hookless law. D5's ownership rule need not change merely because the sizing algorithm changes; D17 exact-output eligibility is not granted by a forward quadratic. D20's 50 bp is not a new segment-width/typical-tick-count governor, and its 1 bp share alignment is not a price-impact test.

## 8. My revisions, license and evidence discipline

**My original preserved:** its sqrt-price whole-book coefficients are consistent with the gross-input expansion above under the same continuous assumptions. The α form makes protocol ownership and degree cancellation clearer and should be preferred for independent checking.

**My qualifications strengthened:** continuous monotonicity is now proved only on its stated funded domain; global termination needs missing-tick/zero-L/word bounds. “One certified candidate” is a sound reject policy but insufficient liveness evidence. Also, my sleeve-only description must be read as current product policy, not a universal V4 rule prohibiting all active-session callers.

Pinned [LICENSE](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/LICENSE) was freshly read: BUSL document, change date 2026-07-01, change license GPL-2.0-or-later. **Kimi's categorical “GPL means no source porting” is not justified.** Copyleft is an obligation to assess, not an inherent prohibition. Grok's no-copy caution can stand as a recommendation pending review, not a legal conclusion. Read dependency TickBitmap/SwapMath headers are GPL-2.0-or-later, not guessed GPL-3.0. Source reuse still needs version-specific and combined-work clearance.

An older Narya audit or repository deployment listing does not attest pinned c40aaa98… code or a V4 port. MiniMax's pinned-commit date claim is not relied upon; pin identity is sufficient here. Vendor gas comments, assumed typical tick counts and upstream approximate test assertions are not measurements or proofs. No complete maintained official V4 port was verified; “none exists” remains too strong.

## 9. Final feasibility answer and gates

| Target | Final Astra position |
|---|---|
| **One V4 hookless position** | Conditional yes after a real port: selected range, live fee/state reads, correct signs/settlement, bounded discovery or single-segment reject, exact integer certificate. Pinned V3 bytecode itself does not execute V4. |
| **Whole-book fungible vault** | Conditional yes at the continuous derivation stage. Arbitrary F/prior E, protocol fee and fixed active multi-position set do not destroy quadratic degree. Integer fee/checkpoint/placement behavior and useful-domain liveness remain unproved. |
| **Autonomous Orbital/SY** | Idle inner scalar calls can use the adapted planner without supplied swap sizing. Already-unlocked calls retain F1/F2 and actual local cover under current law. Outer face/claim inversions and `zapSplitWad` are not removed. A protocol-level active-session adapter would be a separate explicitly approved design. |

Scalar exits remain mandatory: exact-input redemption can remove predetermined pro-rata liquidity and forward-swap the known opposing entitlement; Aperture's zap-out is a precedent, not a general shares-for-exact-assets inverse. Existing exact-output limits remain until separately derived. No basket-only replacement, zero minima, gas-conditioned valuation or speculative sharesJ/sharesK fix is proposed.

**Ranked next work, not execution permission:**

1. Independently prove the gross-input and sqrt-price coefficients agree, including φ=0/on, ℓ=0/L, fixed wings and linear degeneracies.
2. Establish signed wide arithmetic, stable root selection and exact one-core-step candidate validation against actual core settlement; supply at least one nontrivial positive-fee/sleeve/own-LP success domain.
3. Prove/cap prefix traversal, missing ticks, empty words, zero-L gaps, own-boundary checkpointing and fee-floor differences; preserve terminal placement attribution and exact state parity.
4. Quantify reject-policy liveness using an independent exhaustive/reference solver later, not the same production helper. Verify manipulation/donation cycles and resulting ownership.
5. Close SE/SY/transition snapshots, configured held-rate projection, funding/refund invariants and outer inverses; preserve Pons separation. Measure complete nested calls under unchanged limits only after authorization.

**Human decisions:** bounded monotone segment discovery versus strict single-segment admission; whether a proved rounding stencil is acceptable; any maintenance separation needed. No ownership/protection relaxation is implicitly approved by an analytic formula. Current task PRD D1–8/D15–20/D25 and D27/D30 engineering/verification duties remain binding until amended.

All fresh accesses **2026-10-03**. External unnumbered source is cited by exact URL/function; local line evidence above is tool-provided. No ordinary path failed, no previously missing path retried, and no guard or SDK-unavailable event occurred. Confidence high in the polynomial-degree and source-flow corrections; medium-high in continuous derivation; unresolved in integer completeness, economic safety, port liveness and gas. **Return to moderator/human and stop. One cross-review only.**
