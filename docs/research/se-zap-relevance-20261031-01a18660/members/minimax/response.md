# MiniMax response — SE zap relevance

## Identity

- Role: MiniMax member of the research council for run `se-zap-relevance-20261031-01a18660`.
- Requested route: `minimax/MiniMax-M3` with adaptive thinking (brief, roster table).
- Actual Native identity: not exposed.
- Assignment followed: I read the brief and the admitted files, verified the Weir source myself, wrote only this file, did not read peers, did not edit any PRD, review file, or project code, did not implement anything, and launched no sub-agents.

## Question and targets

Three questions, from the brief's "What the recommendation must decide":

1. Does Weir configure `maxZapBps` and `maxZapTickMove`? Name the Weir controls that do exist for a zap. Separate Weir from the full-spread PRD.
2. Are those two caps relevant to the design being adopted — a single-position full-spread Standard Exchange vault that still has single-token `exchangeIn`? Do a size-bps cap and an entry tick-move cap do work in that product that Weir's own swap limits do not already do? No invented numbers.
3. What can a caller do with `previewZapCredit`'s per-currency split that `previewExchangeIn` does not already let them do? Does that use survive if unused input is refunded, as Weir does, rather than booked?

Out of scope by the brief: the locked drops of `previewWithdrawalMode` and `wrappedNative()`. This response recommends nothing about implementation and locks no PRD decision.

Targets read: the brief; the Weir import PRD (WI-08 through WI-26 and the struct and acceptance rows I needed); `WeirVaults.sol` and `base/WeirBase.sol` (deposit, withdraw, zap paths); the frozen Weir source snapshot; the full-spread PRD (`PkgArgs`, FS-OWN-09, FS-OWN-10, plus the named overrides and tables I needed to answer the three questions); the admitted ROI report; and the PairToken stage-one PRD's zap-cap paragraphs as the origin of the two names.

## Evidence

### E1 — Weir configures neither cap, and never did

- `contracts/protocols/strategy/weir/WeirVaults.sol`:
  - `DepositParams` (lines 50-60): `key`, `amount0`, `amount1`, `zap`, `minShares`, `recipient`, `deadline`, `hookData`.
  - `WithdrawParams` (lines 62-71): `key`, `shares`, `zapTo`, `min0`, `min1`, `recipient`, `deadline`, `hookData`.
  - No cap field, no storage slot, no constructor argument, no setter. The only hard cap in the contract is `MAX_PERF_FEE_BPS = 1_000` (line 36), a fee cap; `MIN_SHARES = 1_000` (line 37) is a genesis floor; `perfFeeBps` defaults to 500 (line 82).
  - Neither the string `maxZapBps` nor the string `maxZapTickMove` occurs in the file.
- Frozen upstream snapshot `docs/research/weir-source-import-prd-20261029-01a18660/source-snapshot/sources/src/WeirVaults.sol.txt` (sha256 `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180`): the same two structs field for field, and neither string occurs. The caps were never in Weir upstream, so this is not an artifact of the import.
- Local import `WeirVaults.sol` (sha256 `de30fefa21f59d70ef2a890e0b2b19fba179d3f7644c7bdd477c20e290bb2487`) differs from the frozen snapshot only in import paths, the free `ModifyLiquidityParams`/`SwapParams` type resolution, and the authorized stack-depth refactor that hoists `_deposit`'s locals into a `DepositFrame` struct. The zap-relevant struct fields are identical, so my reading of the local copy is a reading of the Weir behavior being adopted.
- Weir import PRD `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md` (649 lines): zero occurrences of `maxZapBps`, `maxZapTickMove`, `MaxZap`, `Max Zap`, or "tick move". WI-09 (line 150) freezes the struct tuples exactly as above (rows at lines 156-157). The only cap the PRD names is the performance-fee hard cap (WI-22, line 210).
- This is the brief's requested check, done directly rather than taken from the coordinator: the negative result holds for the import PRD, for the local source, and for the frozen upstream.

### E2 — The controls Weir actually has on a zap

- `zap:bool` opt-in (WeirVaults.sol line 54).
- Post-trade floor: `minShares`, checked as `shares < p.minShares || shares == 0` reverting `Slippage()` (line 180). It is a floor on the entrant's own result, applied after the swap.
- Deadline: `checkDeadline` reverting `Expired()` (WeirBase.sol).
- Structural swap size: `_balance` (lines 387-411) swaps at most half of the excess on the larger side — `x = (a0 - a1 expressed in token0) / 2`, or `x = (a1 - a0in1) / 2`. The zap swap is therefore bounded by 50% of the larger-side input. Hard-coded, not configurable, and relative to the caller's own deposit, not to pool reserves.
- Price limit: `_swap` (lines 413-426) passes `sqrtPriceLimitX96 = MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1`, the widest possible limit. Weir has no tick-move bound; a zap swap may traverse the whole range.
- One swap per operation, no retry, no alternate route (WI-19, PRD line 202; WI-20, PRD line 204).
- Unused input is refunded, not booked: `deposit` pulls both declared legs (lines 172-173) and sends `amount - used` back to `msg.sender` (lines 182-183). WI-12 (PRD line 180) and WI-15 (line 186) freeze that: "refund unused input to `msg.sender`" and "The outer refund SHALL remain declared input minus used input".
- Withdrawal side: `zapTo` 0/1/2 with `BadZap()` above 2, `min0`/`min1` minima, deadline; the withdrawal zap also uses the extreme price limit.
- Weir exposes no zap preview at all. Its view surface is `vault`, `vaultCount`, `previewRedeem`, `pendingFees` (WI-10 inventory, PRD lines 162-176). There is no `previewZapCredit`, no deposit preview, and no zap quote function.

### E3 — Where the two names come from, and what they mean there

From `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`:

- Immutable instance parameters, not mutable factory getters: S1-X05 (line 112), "Immutable instance parameters for the same limits, validated and included in instance identity." Validation at lines 181-182: `maxZapBps` positive and at most 10,000; `maxZapTickMove` nonnegative and representable as the baseline tick bound.
- Size cap semantics, S1-OP-02 step 3 (line 541): `0 < amountIn <= floor(inputReserve * maxZapBps / 10000)`, against the pre-entry-swap reserves.
- Tick cap semantics, S1-OP-02 step 6 (line 546): `abs(tickAfter - tickBefore) <= maxZapTickMove`, around the entry swap only.
- Coupling: `maxZapBps` also drives the compound quarter-cap (line 610, "estimate times `maxZapBps / 10000 / 4`"), and lines 619-620 state "`maxZapBps` controls both entry size and the quarter-sized compound cap; `maxZapTickMove` governs only entry swaps". The entry tick guard is explicitly not a compounding guard.
- Public surface: `maxZapBps()` and `maxZapTickMove()` (lines 859-860), and `previewZapCredit(address tokenIn, uint256 amountIn) returns (uint256 shares, uint256 credit0, uint256 credit1, uint256 uncredited0, uint256 uncredited1)` (lines 863-866), with the note at lines 873-875 that it "uses the same planner" and "exposes final share credit and uncredited residual, not an additional deposit route".

### E4 — The full-spread PRD, not Weir, carries the two caps

- `PkgArgs`, full-spread PRD FS-PKG-01 (lines 181-187): "PkgArgs is the PairToken set", listing `PoolKey poolKey`, `string name`, `string symbol`, `uint16 maxZapBps`, `int24 maxZapTickMove`. The two fields reach the full-spread package as deployment arguments.
- FS-PKG-02 (line 202) validates them at initialization: "Zap limits that are not a positive in-range fee bound and a nonnegative tick bound. `InvalidZapLimits`." FS-A03 (line 346) covers that revert.
- The inherited text still carries the tests. The inherit list (line 85) keeps "S1-OP-01 through S1-OP-05 except the named sentences above", and FS-X04 (line 30) narrows only the partial-fill domain of S1-OP-02: "This narrows S1-OP-02's partial-fill domain. It does not change S1-ACC-07 share credit." Steps 3 and 6 are not named as removed.
- FS-OWN-10 (line 64): "`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` stay open."
- One distinction the owner should not lose: `PkgArgs.maxZapBps` is a package input, `maxZapBps()` is a getter. The full-spread PRD has the first and leaves the second open; Weir has neither.

### E5 — `previewZapCredit`'s content, and what the full-spread family locks about the residual

- PairToken issuance: for a zap, `C_i = G_i` only (line 473). `J_i`, the caller inventory remaining after paying actual principal costs, is booked as an explicit no-extra-shares contribution to the basket (lines 491-493): "previews and events must expose the uncredited remainder."
- The full-spread family inherits that: FS-MONEY-01 (line 214), "Issuance is S1-ACC-02 and S1-ACC-07. Zap shares are credited against attributable removable-principal growth `G_i`. `J_i` is booked without extra shares." Dispositions table (line 98): "Entry remainder | Inherited `J_i` booking plus FS-X04 full selected-swap consumption."
- FS-X04 (line 30): "Addition remainder `J_i` stays booked to shared backing without extra shares, and previews disclose it." FS-A07 (line 350) keeps it: "A full selected swap can still book `J_i` without extra shares and without a second-token payout."
- `previewExchangeIn` in this family returns `(amountOut, amountRefunded)` (FS-OWN-08, lines 38 and 60) — one same-token refund. The admitted ROI report agrees: "previewExchangeIn returns shares and a same-token refund. It does not return that split."

## Assumptions

- "The design being adopted" is the single-position full-spread Standard Exchange vault in the FS PRD, not the Weir vault under `contracts/protocols/strategy/weir/`. The brief says so, and the two use different issuance models.
- S1-OP-02 steps 3 and 6 remain in force in the full-spread family, because the inherit list keeps S1-OP-01 through S1-OP-05 and FS-X04 names only the partial-fill domain. If the owner intends to drop the size test or the tick test, that is a decision to state explicitly, and E4 changes.
- "Weir's own swap limits" means the two in E2: the extreme price limit and the half-of-excess swap size. Weir has no size cap and no tick cap to inherit.
- I read FS-OWN-10's "stay open" as covering the public selectors and getters, since the same PRD keeps the two values in `PkgArgs` and validates them at init. If it instead means the caps themselves are undecided, then `PkgArgs` and `InvalidZapLimits` are internally inconsistent in that PRD, and that inconsistency is the owner's to resolve.

## Coverage

Covered: Weir's cap surface and its real zap controls, from source, import PRD, and frozen upstream; the origin and semantics of the two names; the full-spread PRD's treatment of both caps and of `previewZapCredit`; the residual policy the split depends on; the ROI report's verdicts as prior art.

Not covered: the SE interface's own return shapes beyond FS-OWN-08 — the bundle preview's return shape is not pinned in the admitted text, so I cannot rule out that `previewExchangeBundleInForSingleOut` already discloses the split; the numeric value of any cap; Weir's economics under adversarial conditions; whether the family keeps the stage-one compound quarter-cap; implementation cost and gas.

## Conclusions

### Q1 — Does Weir configure `maxZapBps` and `maxZapTickMove`? No.

Weir configures neither, and upstream Weir never had them (E1). The two names arrive from the PairToken stage-one set and reach the full-spread package as `PkgArgs` constructor inputs with `InvalidZapLimits` validation (E3, E4). The distinction the brief asks for is real: `PkgArgs.maxZapBps` is a package input, and `maxZapBps()` is a getter; the full-spread PRD has the first and leaves the second open, while Weir has neither.

Weir's actual zap controls are: the `zap` flag; `minShares`, a post-trade floor reverting `Slippage()`; `deadline`; the hard-coded half-of-excess swap size relative to the caller's own input; the widest-possible price limit, which is the absence of a tick bound; one swap per operation with no retry and no routing; and a refund of unused input to the payer. None of these is a reserve-relative size cap or a tick-move cap.

### Q2 — Are the two caps relevant to the adopted design? Yes, with one decision to state and one conditional to check.

They do work in the full-spread product that nothing else in the entry path does.

- The size cap is a pre-trade, reserve-relative bound on how much of the pool's input-side liquidity a single entry may consume. Weir's half-of-excess rule bounds the swap relative to the caller's deposit, so a large deposit into a shallow pool passes Weir's rule and can move the price arbitrarily far. In the full-spread family the entrant's own swap also shifts the incumbent's measurement basis, because shares are credited against `G_i` measured at the post-swap price `P*`.
- The tick cap is a price-displacement bound on the entry swap. Weir's extreme `sqrtPriceLimitX96` explicitly permits unlimited displacement, and the entry minima cannot substitute for it: a minimum decides whether the caller accepts the outcome after the fact, whereas only the tick cap bounds how far one entry may move the market.
- They are complementary rather than redundant. The size cap is relative to reserves; the tick cap is relative to displacement. A small trade in a thin pool can cross many ticks; a large trade in a deep pool can move few ticks.

Two qualifications. First, the size cap's practical bite depends on the deployed book relative to pool liquidity; where entries are small relative to the pool, its value is a hard, auditable bound rather than a routine constraint. I propose no number, and the FS PRD already requires a positive in-range value with no silent default. Second, in stage one `maxZapBps` also drove the compound quarter-cap; the admitted ROI report records that nobody adopted that coupling for this family. The full-spread family should therefore state explicitly that its size cap is entry-only, or decide the coupling on purpose rather than by inheritance.

### Q3 — What does the per-currency split add over `previewExchangeIn`, and does it survive a refund policy?

Two distinct uses, with different durability.

1. Per-currency attribution of what actually bought shares, `credit0` and `credit1`. `previewExchangeIn` returns the share output and one same-token refund; it does not break the entry down by currency. The split lets a caller compute the effective per-currency cost per share and see how much of the non-input currency was absorbed, and at what rate.
2. Disclosure of the booked, no-extra-shares remainder, `uncredited0` and `uncredited1`. This is what `previewExchangeIn` cannot express at all, because in this family the residual is booked to shared backing rather than paid back to the caller.

On the brief's conditional: the booked-residual policy is not an unlocked premise for this family. It is locked — inherited `J_i` booking in FS-MONEY-01 and the dispositions table, plus FS-X04's "Addition remainder `J_i` stays booked to shared backing without extra shares, and previews disclose it", with FS-A07 preserving it. Use 2 therefore has a live reason to exist here, and it is exactly the content that FS-X04's "previews disclose it" sentence needs a preview to satisfy.

But the split is not policy-independent. If the family ever moves to Weir's shape, with unused input refunded to the caller instead of booked, then `uncredited0` and `uncredited1` are zero by construction and the disclosure value of the split collapses into use 1, which a refunding preview already conveys through its single same-token refund. At that point a separate `previewZapCredit` would no longer earn its own surface and should be re-decided rather than kept by inertia.

One more separation for the owner: Weir itself supplies none of this. Weir mints from liquidity (`L`, then `T/Lp`), refunds the unused input, and has no `G_i`/`J_i` credit model and no zap preview at all. `previewZapCredit` has content only if the full-spread Standard Exchange keeps the S1-ACC-07 `G_i`/`J_i` issuance model, which the FS PRD states it does. Importing Weir's deposit path does not create the subject matter of the preview.

### Bottom line

Weir configures neither cap; the full-spread PRD does, as package inputs, with the public getters still open. Both caps do real work in the adopted Standard Exchange product that Weir's controls and the entry minima do not, provided the family states that the size cap is entry-only. The per-currency split adds per-currency attribution plus the booked-remainder disclosure that `previewExchangeIn` cannot express; the disclosure half rests on the locked booked-remainder policy, and would lose its reason to exist under a Weir-style refund.

## Limits

- Research only. No implementation was run and no tests were executed. No PRD, review file, or project code was edited. This response authorizes no code change and locks no PRD decision; `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` remain open in the full-spread PRD under FS-OWN-10.
- Scope of reading is wider than the brief's enumerated admission for the full-spread PRD and the PairToken PRD. I read the FS-OWN and FS-X blocks, FS-PKG-01/02, FS-MONEY-01, FS-RATE-01, the dispositions and acceptance tables, and the PairToken zap-cap and issuance paragraphs, because the three questions could not be answered from the `PkgArgs` list and FS-OWN-09/FS-OWN-10 alone. Those wider reads are cited where they carry weight above.
- One narrow primary-source check outside the admitted list: the frozen Weir snapshot under `docs/research/weir-source-import-prd-20261029-01a18660/source-snapshot/sources/`, used to confirm the local import is the Weir behavior being adopted. It strengthened E1 from "the local file has no caps" to "Weir upstream never had caps".
- I did not consult the SE interface report that FS-OWN-08 cites, so `previewExchangeIn`'s exact parameter list and `previewExchangeBundleInForSingleOut`'s return shape are unverified. If the bundle preview already returns the credit and uncredited pairs, both Q3 uses shrink and `previewZapCredit`'s case weakens further.
- The full-spread vault is known to me only through its PRD. I have not seen it deployed or traded, so the practical bite of the size cap is reasoned expectation, not observation.
- I did not re-derive the ROI report's verdicts. They are cited as prior art on cost and on the compound quarter-cap coupling, not as authority for anything above.
