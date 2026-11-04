# Independent first pass — kimi: do actual deposit and slice-exit swaps eliminate APEX-2026-012?

Run root: `docs/research/v4-swaps-independent-redo-20261026-01a17791/`
Companion executable evidence: `members/kimi/model.py` (pure stdlib, exact rational
arithmetic, per-token conservation asserted in every scenario; `python3 model.py`).
No prior council research, handoffs, or peers were read. No tests/builds were run
(member boundary); all production-reachability statements are source-level.

## Verdict

**Swapping during deposit and exit eliminates APEX-012 only in one specific form:
a price-free matched-ratio entry mint plus pro-rata slice settlement on exit, with
fail-closed behavior while the manager is unlocked, and no liquidation quote anywhere
in the money path.** The exit-side half of APEX-012 (unfunded payout from an inflated
quote) dies under slice settlement alone — depth inflation then buys the attacker
exactly nothing (model B: attacker net is invariant across 0x/1x/9x/99x added depth).
But "add real swaps, keep quote-priced entitlements" (variant 2) fails: the entry-side
quote is still manipulable and extractive (model C: +5.8% of a 50-unit deposit per
cycle under a 10% push, +15% under a 100% push, incumbents losing pro-rata). The
literal executed-price mint `m = S·D/(A_T + p_exec·A_O)` (variant 3) fails on
opposing-heavy books (model D, book 100/400: pusher nets +4.70, incumbents −6.97).
The matched-ratio vector mint (variant 4 made precise) is incumbent-neutral to
machine precision under arbitrary price pushes and any depth (models D-matched, F),
and the manipulator strictly loses fees. The same-pool TWAP (variant 5) is usable
only as a user-protection execution guard, and only after the APEX-050 fix; under
the single-venue premise it is circular (no external arbitrage defends it), so it
can rate-limit acceptance of a moved price but can never prove the price honest.

## 1. Source observations (what the code actually does)

Primary sources read in full: `CLAUDE.md`; the audit diff review
`docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`
(APEX-011, 012, 024, 025, 026, 040, 050); all of
`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` (Money,
Accounting, LiquidationQuote, Inventory, Common, Harvest, Geometry,
ExecutionDelegate, EconomicTarget, In/Out targets);
`contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol` and
`libraries/UniswapV4TruncatedTwapOracleLib.sol`; the Wings PRD
`docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`; the audit
PoC sources under `docs/security/audit/second_review/indexedex-2ba07631-pocs/`
(read, not executed).

The money path, as written:

- **Deposit** (`Money._deposit`, Money.sol:120-140): pull target tokens, harvest,
  then `value = Quote.quote(Common.quoteRequest()).value`, mint
  `m = supply==0 ? assets : floor(S·D/V)` (`Accounting.issue`), place.
- **Redeem** (`Money._redeem`, :147-181): harvest, `V = Quote.quote(...)`,
  entitlement `E = floor(s·V/S)` (`Accounting.entitlement`), fund the payout from
  the local sleeve and, if needed, by closing positions and dumping the *entire*
  opposing balance exact-in at a MIN/MAX price limit (`_swapDeficit`, :219-233).
  While the manager is unlocked, payout is from the sleeve only, bounded by
  `_localTarget() >= required` (:167-170).
- **The quote** (`LiquidationQuote._quote`): reads live `getSlot0` (:146) and
  `getLiquidity` (:151), removes only this vault's own positions, then simulates
  selling the *whole* opposing inventory through the remaining live depth
  (`_sell`, :298-334). `Common.quoteRequest()` hard-codes `stepLimit = 512`.
- **APEX-012's theft mechanism**: `V` is computed from transient state (JIT
  liquidity added unsettled inside the attacker's own `unlock`, or settled
  flash-funded depth, or an in-session price push), but the payout is real tokens
  from the book/sleeve. `HolderValueLoss` (:174-177) compares two quotes taken in
  the same inflated state, so it cannot see the inflation. Closed form from the
  audit: `profit = D·(V1 − V0 − D)/(V0 + D)`; the PoC's reported numbers
  (V0 = 998045067650, V1 = 2139175794077, D = 1e12) give minted = 1001958761596,
  paid = 1070634405955, profit = 70634405953 — my scenario A reproduces all three
  from the closed form to within integer rounding, corroborating the reported
  PoC outputs without executing them.
- **Structural fact that matters for any swap-based redesign**: while the manager
  is unlocked, the vault cannot execute any mutation or swap —
  `Common.execute` reverts `ManagerAlreadyUnlocked`, and the PRD (A3/S3) forbids
  nested unlocks. Slice settlement is therefore only available in idle mode.
  Blocked-mode behavior must be re-specified; the current S3 rule (compute the
  live entitlement, pay from the sleeve if covered) is precisely the APEX-012
  in-unlock vector and cannot survive.

## 2. The five candidate rules, each with mint equation, cutoffs, execution rules

Notation: book totals `B_T`, `B_O` = local balances + removable principal at the
current price + uncollected own-position fees (`Harvest.totalInventory` /
`Inventory.principal(roundUp=false)` + `earnedFee`), measured pre-operation with
pending caller credit excluded (PRD C1/C2). Supply `S`, deposit `D` (target),
exit `s` shares, `f = s/S`. Pool fee γ.

### Variant 1 — status quo (APEX-012). Mint `m = S·D/V`, payout `E = s·V/S`,
`V = B_T + sellSim(B_O | live depth)`. **Unsafe** — the audit's High stands;
scenario A reproduces it.

### Variant 2 — real swaps added, quote-priced entitlements retained.
The swap changes pool state but the mint/payout still divide by the live quote.
**Unsafe.** Exit-side depth games stop paying (model B), but the entry side is
still a quote: pushing the price down lowers `V`, inflates `m`, and slice exits
then pay real value against the inflated share count (model C: attacker net
+2.91/+7.42/+11.17 on D=50 for 10%/50%/100% pushes, +22.77 on D=150; incumbents
lose 1.1–1.2× the attacker's gain; every ledger closes per token). Swaps are not
a fair-mint invariant; the quote is the vulnerability wherever it remains.

### Variant 3 — literal executed-price mint `m = S·D/(A_T + p_exec·A_O)`,
pre-swap book, `p_exec` from the vault's own entry swap (50% of D swapped).
**Unsafe in general.** The denominator is manipulable through `p_exec`, and the
compensating effect (the vault buys opposing cheap when the price is pushed)
only offsets it when the book's opposing leg is small relative to the swap.
Model D under a 100% push: balanced book 100/100 → pusher −7.70 (backfires);
target-heavy 400/25 → −23.07 (backfires); opposing-heavy 100/400 → **+4.70,
incumbents −6.97 (extracts)**. Direction-dependent safety is not safety. The
formula also mis-sizes under any rule that lets `p_exec` come from a small swap:
the price of a dust trade is cheap to push while the denominator discount applies
to the whole `A_O`.

### Variant 4 — price-free matched-ratio vector mint + slice settlement (the form that works).

**Entry (idle only).** Pull `D`; harvest. If `B_O = 0` set `x = 0`; else choose
the swap size `x ∈ [0, D]` solving `(D − x)/B_T = y(x)/B_O`, where `y(x)` is the
actual executable output of selling `x` target into the pool (computable with the
existing bounded stepper; bisection over `x`, ≤ 512-step quotes per probe — same
work budget class as the current quote). Execute the swap, receive actual `y`.
Mint `m = min(floor(S·(D−x)/B_T), floor(S·y/B_O))` (the min absorbs integer
rounding conservatively). Bootstrap (`S = 0`): `m = D`, current rule. Place per
existing `Harvest.place`. *Fee cutoff:* the entry swap's LP fees are inside `y` —
the entrant bears their own conversion cost (this requires naming an amendment to
owner ruling O4, which currently forbids reducing credited caller input; see §5).
Own-position LP fee growth accrues to the book, not the entrant. *Inventory
cutoff:* pending credit excluded pre-harvest (C2); totals are the post-harvest
removable basis above.

**Exit (idle only).** Burn `s` after funding: harvest; decrease each owned
position `j` by `floor(f·ℓ_j)` liquidity and collect (removal before sale, so the
vault never sells into its own just-removed depth; rounding floors favor
incumbents — the residual stays owned in the position); the realized opposing
slice is sold exact-in through the same pool with a caller/`minOut` or
reference-bounded price limit; pay `E = slice_T + actualProceeds`. Mutation
budget: harvest closes (≤2) + 3 decreases + 1 swap + placements fits the existing
`Common.execute` envelope (≤8 ops per batch, ≤16 mutations per session) in at
most two batches. `HolderValueLoss` becomes obsolete and should be replaced by a
**price-free conservation check**: post-operation book totals must satisfy
`B_i′ ≥ ceil((1−f)·B_i) − ε_i` for each token `i`, with `ε_i` the summed
removal/sale rounding floors. That check is unmanipulable precisely because no
price enters it.

**Blocked (manager unlocked).** No swap may execute (Common.execute reverts).
Rule: deposits proceed only if `B_O = 0` (then `x = 0`, `m = floor(S·D/B_T)`);
redemptions revert (fail closed). This is a named change to PRD A3/S3, which
today mandate live-entitlement sleeve payouts — the APEX-012 in-unlock variant.
With a 0% scripted sleeve the in-unlock variant is already inert, but the settled
variant is not; only fail-closed blocked exits plus slice-settled idle exits
remove both.

**Safety invariant (exact, price-free).** Under this rule every depositor
acquires exactly the fraction `f_D = (D−x)/(B_T + D − x) = y/(B_O + y)` of *each*
token of the book, and every exiter removes exactly `f = s/S` of each token
(modulo floors that favor incumbents). Therefore incumbents' per-token holdings
after any entry or exit are *token-for-token unchanged* — no valuation function,
price, depth, or fee parameter appears in the statement, so no manipulation of
pool state can violate it. The pool only determines how much target the exiter's
opposing slice fetches, and that amount is paid by the pool's LPs (real,
settled), not by the book. Model F confirms the exactness: incumbent welfare
delta is +0.0000 at every deposit size and depth, and the honest round trip nets
the cycler −0.23% to −0.30% of D (exactly the swap fees). Model D-matched: under
a 100% price push the attacker nets −1.97 / −1.78 / −2.15 across the three book
compositions; incumbents exactly neutral.

**Why the naive alternatives leak (the concavity wedge).** Quote-priced entry
with slice exit pays the exiter `f·T + g(f·O)` which exceeds the pro-rata
whole-book quote `f·V` whenever `O > 0` and depth is finite, because CPMM
proceeds are concave: `g(f·O) ≥ f·g(O)`. Model B at zero manipulation: a
deposit→slice-exit cycle at `f ≈ 0.5` extracts +2.15 on D=190 (1.13%) against
10x external depth, +6.52 (3.4%) at 2x depth, independent of attacker depth
games (κ = 0…99 identical). The matched mint kills the wedge by making entry and
exit the same basis (the pro-rata vector), which is why F is exactly neutral.

### Variant 5 — same-pool TWAP as the pricing reference.
The **actual** oracle is not safe to reference: APEX-050 (read in source,
`UniswapV4TruncatedTwapOracleLib.sol:86,98-107`) credits the whole idle gap with
the live poked tick; a single in-unlock push-poke-restore moves `consult(W)` by
the full ±9116-tick clamp (2.488x, model E reproduces the audit's figure) and
resets `writeAge`. The **corrected** rule (credit the gap with `prevTick`;
extrapolate with `prevTick` on reads; no write while unlocked; minimum covered
span) makes the single-transaction poke exactly zero-effect (model E) and forces
the manipulator to hold the price across real time. Under this brief's premise —
one venue, no external market — there is no arbitrage that defends the price, so
even the corrected TWAP only bounds the *speed* at which a moved price becomes
the accepted reference; it cannot bound correctness. Consequence: the TWAP is
acceptable as an execution guard (exit-swap price limits / depositor minOut,
where the harm of manipulation falls on the voluntary transactor) and must not
be load-bearing for incumbent solvency. Under variant 4 it isn't.

## 3. Executed numerical evidence (model.py; exact rationals; per-token
conservation asserted; fees 0.3% on input; full-range single-segment pool)

Book = local (T, O); external depth `ext` per side; welfare aggregation at the
initial price `p0` is a labeled convention; all attacker results are fully
flattened through the same pool (no residual token vectors).

| Scenario | Result |
|---|---|
| A: status quo closed form vs PoC | minted/paid/profit match 1001958761596 / 1070634405955 / 70634405953 (±2 wei) |
| B: slice exit, settled depth κ = 0/1/9/99x, D=190, book 100/100, ext 1000 | attacker +2.153/+2.151/+2.152/+2.153 — **invariant in κ**; incumbents −4.66 at p0 in all cases |
| B: shallow (ext 200) | attacker +6.52; incumbents −17.83 at p0 |
| C: quote entry + slice exit, push 10/50/100%, D=50 | attacker **+2.91 / +7.42 / +11.17**; incumbents −3.70 / −9.11 / −13.59 |
| C: D=150, push 100% | attacker +22.77; incumbents −27.02 |
| D: literal variant 3, push 100% | 100/100: −7.70 (inc +5.51); 400/25: −23.07 (inc +19.35); 100/400: **+4.70 (inc −6.97)** |
| D: matched variant 4, push 100% | −1.97 / −1.78 / −2.15 attacker; incumbents **+0.0000** in all three books |
| D2: fixed 49/50/51% entry swap, honest pool, book 400/25 | claim skew between the two legs +1396% / +1456% / +1519%; matched sizing 0.00% |
| F: matched entry + slice exit, honest cycle D=10…380, ext 1000 and 200 | cycler −0.30%…−0.23% of D (fees only); incumbents +0.0000 everywhere |
| E: TWAP poke, actual vs corrected | consult(1800) shifts 9116 ticks (2.4882x) vs 0 ticks (1.0000x) |

## 4. Which part of APEX-012 disappears under slice-only settlement, and what remains

Disappears: the *unfunded-payout* channel — both the in-unlock JIT variant and
the settled flash-depth variant pay out of the book against a fictional quote;
slice settlement pays only realized proceeds, so quote inflation cannot manufacture
payouts (model B κ-invariance). The whole-balance MIN/MAX-limit dump of APEX-024
is also gone as specified (the exit sells only the exiter's own slice), and the
APEX-026 quote DoS leaves the money path entirely (no quote is needed to enter
or exit).

Remains, with owners:
1. **Entry-side quote manipulation** if any quote survives in the mint (variant 2,
   model C; variant 3 on opposing-heavy books, model D). Closed only by variant 4's
   price-free mint.
2. **Blocked-mode payouts**: must fail closed or the in-unlock variant persists
   verbatim (named PRD A3/S3 change).
3. **Vault-flow sandwiching**: the entry swap and the exit slice swap are
   predictable trades; front-/back-running them taxes the *transacting user*
   (depositor receives less `y`; exiter receives fewer proceeds), never incumbents
   (the invariant is per-token). This is the APEX-024/025 family relocated from
   "reserve extraction" to "user-level MEV", mitigated by price limits off the
   corrected same-pool TWAP and by the user's own `minimum_`. Severity drops with
   trade size relative to depth.
4. **Bootstrap/rounding**: APEX-040's dust-supply + donate trap is orthogonal
   (matched mint still rounds `S·D/B_T`); the audit's round-trip guard or a
   minimum first deposit is still required.
5. **Rate/query surfaces**: `getRate`, `preview`, `liquidationValue`, rebalance
   validation still read the live liquidation quote. Issuance no longer needs it;
   per the standing `getRate` convention (normalized actual one-whole-share
   withdrawal-and-sale preview, separate from issuance), `getRate` should become
   the simulated `f = 1/S` slice-exit preview — which is exactly the
   slice-settlement semantics — while integrators must stop treating it as
   manipulation-proof NAV. APEX-026's 512-step DoS still applies to any surface
   that keeps the whole-book walk.
6. **Self-fill on exit slices**: the vault's remaining positions are in-range
   during the exit sale and absorb part of it at market terms — incumbents then
   hold more opposing and less target than a purely external sale would leave.
   Token-vector neutrality of *claims* is unaffected (the trade happens at market
   inside the pool), but the composition shift should be disclosed; removing all
   owned liquidity before every slice sale is the alternative and costs
   APEX-023-style churn. I judge market-term self-fill acceptable; flagging for
   the council record.

## 5. Named requirement changes (recommendations only — no implementation authorization)

- **PRD V1/V4/V5 (valuation basis)**: replace whole-book liquidation-quote
  pricing in the money path with matched-ratio vector mint (entry) and realized
  slice settlement (exit). The quote survives only in view/rate surfaces.
- **O4 (costs)**: amend so that the entrant's own conversion cost is borne by the
  entrant's flow (it is inside `y`); vault-maintenance costs stay on reserves
  (A4/S2 unchanged). If O4 cannot be amended, the vault would have to top up `y`
  from reserves to `y_gross`, which reintroduces a price and a repeatable
  reserve-drip vector — I recommend the amendment.
- **A3/S3 (blocked mode)**: live-entitlement sleeve payouts while unlocked are
  the APEX-012 in-unlock vector; fail closed (revert) for redemptions and for
  deposits whenever `B_O ≠ 0`.
- **V3/RV-6 (bootstrap)**: keep `m = D` at `S = 0` plus the APEX-040 round-trip
  guard; matched mint degenerates correctly at `B_O = 0` (`x = 0`).
- **SEC-08**: the required witness changes from "no manipulation-derived overmint"
  to the price-free invariant: incumbents' per-token totals after any entry/exit
  equal pre-operation totals minus exactly the exited fraction, within summed
  rounding floors.

## 6. Strongest counterargument to this verdict

1. **Composition is not value.** My invariant is per-token; users care about
   value at a reference price. Entries and exits move the pool price (the
   depositor's swap, the exiter's slice sale, self-fill composition shifts), so
   an incumbent's unchanged token vector can be worth less at post-operation
   market prices. This is inherent to any AMM-resident book and is bounded by the
   transacting flow's own impact — but it means "manipulation-proof" is proven
   only in the per-token sense, and value-based statements still need a
   reference, which under the single-venue premise is circular. If the owner
   demands value-based non-dilution at a reference price, variant 4 does not
   provide it and nothing built on this pool alone can.
2. **Model fidelity.** The numeric evidence is a full-range single-segment CPMM
   with aggregate books, not the production three-position stepper over V4
   integer deltas. Partial-decrease rounding, wing-boundary composition
   discontinuities, and fee-growth-on-decrease accounting could shift dust-level
   value between parties; I argued (not demonstrated) these floors favor
   incumbents. No EVM execution backs any proposed variant — members run no
   tests — so production reachability of the fix is as unverified as production
   reachability of my model's simplifications.
3. **Availability regression.** Fail-closed blocked mode and swap-dependent
   entries make every money transaction heavier (bisection + swaps) and make
   blocked-mode exits impossible where S3 currently guarantees sleeve payouts.
   A council could reasonably judge this a product regression that APEX-012's
   cheaper fixes (isUnlocked gate + reference-bounded quote, the audit's own fix
   list) avoid — at the price of retaining a manipulable-ish quote bounded by a
   circular reference.

## 7. Assumptions

- Single liquidity venue; the pool's TWAP is the only reference (brief premise).
  No external feed, no free external liquidation.
- Full-range single-segment CPMM approximation with γ = 0.003 on input
  (the audit PoC family tier); all-full-range LP accounting is exact.
- Vault book modeled as local (T, O) — a real post-harvest state; the
  liquidation quote aggregates the same two totals, so conservation structure
  is unaffected; magnitudes only would move with positions.
- No FoT/rebasing tokens, hookless underlying pool, integer flooring immaterial
  to sign conclusions (stated per result where relevant).
- Attacker: unprivileged, own or flash capital, can swap/LP/poke; cannot censor
  others' transactions across blocks.

## 8. Evidence gaps — what remains unproved

- No production-code execution of any variant (member boundary); the audit PoCs
  were read, not re-run. Their outputs were taken as reported, with scenario A
  providing closed-form corroboration of APEX-012's headline numbers.
- Concentrated multi-tick walks, both-wing activation with one-sided positions at
  boundary prices, and per-position partial-decrease rounding are argued, not
  modeled per-position.
- Gas and the 512-step budget for the entry-size bisection and the three
  decreases + swap per exit are unmeasured.
- Corrected-TWAP guard parameters (window, deviation bound, minimum span) are
  unspecified; multi-block drift profitability under the single-venue premise is
  not quantified (needs an honest-flow model).
- Whether O4's wording forbids charging the entrant's conversion to the entrant
  is an owner-ruling question, named above.
- A finite parameter sweep is not a safety proof; the safety claim for variant 4
  rests on the price-free per-token invariant (§2, variant 4), and the numeric
  scenarios are witnesses/counterexamples, not the proof.

## 9. Reproducibility

`python3 members/kimi/model.py` — standalone, stdlib-only, exact rational
arithmetic; asserts per-token conservation across attacker/book/external-LP in
every scenario; prints the tables summarized in §3. Scenarios: A (closed form vs
PoC), B (slice exit vs depth inflation κ-sweep, plus shallow-depth), C (variant-2
entry manipulation counterexample), D (variant 3 vs variant 4 under a 100% push,
three book compositions), D2 (fixed 49/50/51% vs matched sizing), E (actual vs
corrected TWAP poke), F (honest-cycle neutrality of the recommended design).
