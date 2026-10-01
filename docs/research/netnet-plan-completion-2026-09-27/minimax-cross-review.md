# MiniMax M3 — Plan-Completion Cross-Review (Bounded Round)

> Cross-review of three peer originals. Read together; no peer cross-review consulted. My `minimax-original.md` is baseline. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Live B/U floor/ceil obstruction is real — my counterexample correctness

**User-confirmed obstruction.** Astra's B=3, U=2, deposit x=1: floor(1·2/3) = 0 (zero shares, revert) or floor-equivalent m=1 dilutes old position to floor(4·2/3)=2 < principal 3. **Floor-only m cannot simultaneously honor old principal ≥ previous and new balance ≥ 1.** Same direction in second counterexample (B=10, U=6, positionShares=3, lockedPrincipal=4, claimReward=1, total value=5; partial-reinvest q rounds same way).

**Implications for the in-place spec.**
1. **Deposit floor cannot be silently substituted for "non-dilutive."** Either (a) integer exactness is non-automatic; the share calculation must floor the deposit to a minimum integer that preserves `value_new >= x` AND `value_old >= old_principal`; or (b) deposit must be backed by a non-stake balance that does not participate in the B/U fraction (e.g., "soft" deposit as held-but-not-staked, similar to GenesisBond founding semantics). The plan cannot mark this "finished" by stating floor semantics without selecting a minimum-share protection.
2. **Reward burn floor/ceil on NFT position:** the burn `s_burn` MUST satisfy `floor(B·s_burn/U) ≥ q` where q = requested reinvestment. My original's `s_burn = s - s_keep` algorithm does **not** preserve this guarantee by default; it must compute `s_burn = ceil(q · U / B)` from the desired `q` (not subtract from `s`), then verify `floor(B·s_burn/U) ≥ q`. Extra native from the floor stays in custody for remaining shares.
3. **Native rounding allowed ≠ principal lost.** Native-rounded dust on a fractional share is permitted; principal floor-then-floor against the user's locked principal is a different object that must be checked explicitly.

**Grok's burn-share formula (corrected):**
```
require value >= P && q <= P && q > 0
sKeep = (value == q) ? 0 : floor((value-q) · U / B)
sBurn = s - sKeep
require floor(B · sBurn / U) >= q
```
This is the right shape but does not solve the B=3, U=2, deposit1 case for the depositor. It solves the **burn side**; the deposit side remains integer-exact-dependent.

---

## 2. Standing weights ≠ receipt shares — don't mint fee ownership out of pre-existing principal

Grok's "top-up only, never reduce, O > 0 path": `sF' = max(sF, floor(U'·f/1e18))`, `sC' = max(sC, floor(U'·c/1e18))`. **This mints recipient shares from Δ backing only, never from pre-existing B** — `U` is recomputed post-issuance; the existing principal's value is preserved by B/U rebasing after the new shares are accounted. **My original said the same thing but did not make the "no mint from pre-existing principal" guarantee explicit.** Add the rule: **recipient share issuance can only be sourced from the new mint Δ into custody, never by re-pricing existing U downward.**

Kimi's `When O==0: U′ = U, no issuance; Δ accrues to existing shares via B — no later depositor is enriched`: this is the matching edge case. **Both peers agree.** My original's wording was equivalent but ambiguous about the O=0 edge.

---

## 3. Exact-output backward composition needs exact configured conversion

**Kimi: linear/sampled-rate fix-up with bounded one-unit re-verify.** Grok: nonlinear SY redeem without source inverse is **conditional blocker — do not binary-search**.

**My original §B.2 listed steps but did not enumerate the fix-up rule.** Update:

For linear `out = floor(in · a / b)`: `in_required = ceil(out · b / a)`; forward-verify `floor(in_required · a / b) ≥ out`; if not, `in_required += 1` and re-verify. **Bounded to at most one unit.** Document as a one-step linear fix-up, NOT a search loop.

For nonlinear / no source inverse (e.g., configured SY redeem preview is not closed-form): **conditional blocker**. Do not invent a search, do not call it `unsupported`, do not skip the route. Mark the route as needing source-verified inverse in NN-10 evidence; otherwise that leg is not deployable in this round.

For ERC4626 `withdraw(assets) → DETF → sNET`: composition is `withdraw(assets) → burn q → NET-via-Weighted-book → sNET-via-SY-redeem`. Each leg is closed-form (or fix-up); the composition is sequential, not a single nonlinear inverse. **Per the user: NO binary search, NO forbidden solver.** Confirmed.

---

## 4. Anonymous pretransfer surplus cannot prove payer identity

Astra: "Two histories — user-funded push versus equal unrelated donation — can expose identical destination balances and caller arguments. A stale flag or later sync cannot prove sender provenance."

**My original §A.4 already identified this.** Confirmed. The plan must NOT treat `balanceOf - booked` alone as proof of user-funded input. Two safe paths:
1. **Pull mode** (snapshot before `transferFrom`, credit delta only — already in `BasicVaultCommon.sol:80–105`).
2. **Authenticated push** via an atomic user-authorized funding boundary (e.g., user has signed a deposit message; the hook receives via a recognized entry-point that records `payer`).

**Anonymous pretransfer credit from arbitrary surplus** is rejected as a funding-input proof. The plan should state this as a conditional G2 mapping: the existing `BasicVaultCommon` pull path is supported; anonymous-push with unverified surplus is **not** a path to user funding credit.

---

## 5. Inner PLP/YT: geometric first-mint + min-ratio later + locked minimum + last-exit not division-by-zero

**My original §A.3 had two errors.** Corrected:

**First mint (`S == 0`):** `S₀ = sqrt(L₀ · Y₀) − 1000` (geometric). **Both legs required positive.** **Locked minimum 1000 units prevents last circulating sweep** — once an LP exits, the locked minimum remains; subsequent mints do not relock. **Not a V2-style `pair.mint` unequal-contribution donation:** the geometric formula absorbs both legs exactly; leftover under min-ratio goes to sub-reserve as residual, **not** to existing LPs.

**Later mint:** `s_mint = min(floor(dL · S / L), floor(dY · S / Y))`. Residual `dL − useL`, `dY − useY` stays in sub-reserve as book entry; NOT donated. **Caller does not receive HLP from residual.**

**Last exit (`s_burn == S`):** pay the entire remaining `(L, Y)` directly to the redeemer; do NOT divide by S. Sub-native dust retires with it. **Critical for preventing the last-share divide-by-zero in proportional exit.**

---

## 6. TWAP ring with integer-timestamp coalescing + predecessor proof

**Astra's concrete algorithm:**
- State: `(timestamp, cumulativeHi, cumulativeLo, postPriceWad)` per observation.
- **Coalesce all writes with the same integer timestamp** (no zero-duration rewrite of prior history).
- Consult at `t`: extend C using the latest observation's `postPrice`; locate the latest observation at or before `t − 3600`; extend it to that boundary; subtract and divide by 3600.
- **3601-entry ring sufficient** under the one-record-per-distinct-integer-second invariant: 3601 retained timestamps span at least 3600 seconds, hence retain a boundary predecessor. Evict only points older than the sentinel.

**My original §C.4 had the basic TWAP formula but missed:**
1. The coalesce-same-timestamp rule (line 156 of plan §8: "no zero-duration change rewrites prior history" — this matches Astra).
2. The two-limb cumulative (cumulativeHi, cumulativeLo) to span uint64 timestamps × uint256 prices without overflow.
3. The predecessor proof for the 3601-entry ring under the integer-timestamp invariant.

**Update the in-place spec** to include these three elements; otherwise the ring may produce wrong TWAP under same-second back-to-back writes or under long quiet periods.

---

## 7. Terminal NFT retirement — DORMANT vs burn

**Astra says DORMANT (NFT kept, holder kept); Kimi says burn NFT from Drained state.** These are different choices. The plan must select ONE.

**Selection (recommend Astra's DORMANT) per the user's caution against "forfeiture or never-burn redesign":**
- **Keep NFT as DORMANT, do not burn.** Late native proceeds arriving at the holder are recognized as same-NFT principal (per H01) and remain stranded-but-redeemable as long as the holder is alive and not transferred to a walleted owner.
- **Do NOT transfer holder ownership to a retirement wallet** (per Kimi + my original §D.3).
- **Do NOT reuse holder for a second intended native purchase** (per Kimi).
- **DORMANT → late gifts → still claimable.** NFT retirement is implicit at end-of-life; the dormant state preserves the entitlement handle.

This is **not a forfeiture or never-burn redesign**; it is preserving the tokenId handle for late gifts. **Astra's "without burning the transferable NFT or changing permanent holder owner" wins.**

---

## 8. Conditionally irreducible items (per peer consensus, not papered over)

- **G0/G1 unpassed.** No production code.
- **Nonlinear SY redeem without source inverse:** conditional blocker; do not binary-search; do not call `unsupported`; mark for NN-10 source-verification.
- **Live B/U integer exactness obstruction:** Astra's B=3, U=2, deposit1 counterexample is a real obstruction to floor-only mint; implementation must select either exact-deposit floor with minimum-share protection OR non-stake deposit boundary. **Not papered over; flagged as a G2 implementation decision.**
- **Oracle BondTerms vs next-epoch scale:** conditional NN-04 dependency; only escalates if a future-selected per-type lock exceeds `minLockDuration` (revert at `UniswapV4DetfCommon.sol:104–109`).
- **TWAP predecessor proof** is documented in the algorithm; ring cardinality is implementation-bounded, not a gas proof.

---

## 9. Itemwise final corrections to my original

| Section | Correction |
| --- | --- |
| §A.2 deposit | floor-only mint cannot be silently treated as non-dilutive; either exact-deposit floor with minimum-share protection or non-stake deposit boundary. B=3, U=2, deposit1 is a real obstruction. |
| §A.2 burn | `s_burn = s − s_keep` is wrong shape; use `s_burn = ceil(q · U / B)` and verify `floor(B · s_burn / U) ≥ q`. |
| §A.2 standing top-up | Make explicit: recipient issuance sources only from new Δ, never by re-pricing existing U down. Confirm O=0 edge. |
| §A.3 first mint | Use geometric `S₀ = sqrt(L₀·Y₀) − 1000`, NOT V2-style min. Both legs positive. |
| §A.3 last exit | When `s_burn == S`, pay remaining `(L, Y)` directly; no division by S. |
| §A.4 pretransfer | Anonymous-push from unverified surplus is **not** a path to user funding credit. Pull-only or authenticated push. |
| §B.2 exact-out | Add bounded one-unit fix-up rule for linear paths; conditional blocker for nonlinear. |
| §C.4 TWAP | Add coalesce-same-timestamp; two-limb cumulative (Hi/Lo); predecessor proof for 3601-entry ring under integer-timestamp invariant. |
| §D.3 retirement | Select DORMANT (NFT kept, holder kept); do NOT burn. Late gifts remain claimable. |
| §D.5 direct donations | Already correct; donations are physical custody only, not contribution credit. |

---

## 10. What is solved (do not reopen)

- Outer HLP caller scaling at boundaries; rated-WAD units; identity-bound weights `[5e17, 2e17, 1e17, 2e17]`.
- Weighted exact-out at Weighted layer (closed-form via `WeightedMath.computeInGivenExactOut` + `grossUpExactOut`).
- ERC4626 withdraw composition is sequential leg composition, not a single nonlinear inverse.
- Composed path: tax gross-up if tax-bearing; SY redeem at sampled rate (linear path); PLP/YT exit via direct `exitPreExpToSy` / `exitPostExpToSy` (no binary search); sNET stake 1:1.
- V2 SE full parity preserved (`UniswapV2StandardExchangeDFPkg.sol` + 7 transition selectors + ERC4626 binding predicate).
- Custom NetNet SY must be built; vendor templates are reference patterns only.
- First-bond G/U/B/R with separate floors; full-book first mint required (`firstJoinMustBeFullBook`); zero earned interest.
- TWAP = arithmetic price × time (NOT tick, NOT log); ring structure from `UniswapV4TruncatedTwapOracleLib.sol:16–70` adapted; no fabricated historical prices; zero history ≠ below peg.
- 9-dec → WAD scaling once at `_quoteCtx:185`; pending expansion via supply adjustment only.
- Holder Package standard calcSalt; `providedSalt = bytes32(tokenId)` unchanged; one intended purchase per NFT; `noteId = notes[to].length` post-push.
- Partial reinvestment (Path A): consumes `q ≤ funded`; no full-collection prerequisite; no E+1 wait; no new lock on old NFT.
- Live B/U model selected from PRD §10.2 wording; StakedNET (gons) and RebasingDETFToken (cached-rate) are demonstrably different and rejected as substitutes.
- No binary search / shared-law forbidden solver introduced.
- No new external SY / no generic FoT framework / no new governance / no replacement economic model.

---

## 11. Conditional irreducible blockers (acknowledged, not papered over)

- **G0/G1 unpassed** — no production code; not a PRD gap.
- **Nonlinear SY redeem without source inverse** — conditional blocker; do not binary-search; mark for NN-10 source-verification.
- **Live B/U integer exactness obstruction** — implementation must select exact-deposit floor with minimum-share protection OR non-stake deposit boundary; not papered over.
- **NN-01 LIVE verification** — engineering evidence (not PRD gap).
- **Oracle BondTerms vs next-epoch scale** — only escalates if a future-selected per-type lock exceeds `minLockDuration`.

---

## 12. Confidence and evidence limits

- **High** all cited source lines (PRD §§4–13, `BondDepository.sol`, `UniswapV4DetfCommon.sol`, `DETFMintSplitLib.sol`, `WeightedBufferHookMath.sol`, `BasicVaultCommon.sol`, `FeeCollectorDFPkg.sol`, `DiamondPackageCallBackFactory.sol`, `StakedNET.sol`, `RebasingDETFTokenRepo.sol`, `InterestManagerYT.sol`, `UniswapV4TruncatedTwapOracleLib.sol`) verified by direct read or prior council round.
- **High** the live B/U integer exactness obstruction is real and decisive (Astra's counterexample is reproduced).
- **High** standing-recipient issuance sources only from new Δ; preserves existing U/B principal.
- **Medium** that the bounded one-unit fix-up is safe for typical linear paths.
- **Low** on whether a future selected per-type lock fits `minLockDuration`.
- **Not claiming** G2–G5 annexes are "finished"; these are spec replacements conditional on G0/G1.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-plan-completion-2026-09-27/minimax-cross-review.md`. Originals untouched.
