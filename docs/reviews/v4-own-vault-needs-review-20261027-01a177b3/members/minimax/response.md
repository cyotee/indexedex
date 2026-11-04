# Member response

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: minimax
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/minimax/response.md
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3
- Actual role, model, reasoning, task ID, and session ID: council-member, minimax/MiniMax-M3, not exposed, not exposed, not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the published vault specification, and any implementation it has, meet these four needs: a reserve exposed to trading fees; a deposit of either token; a withdrawal into one token; and a quote of one vault share into one token? Report gaps and failures. Do not confirm by assertion.
- Required targets: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md
- Optional context: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md — not opened, so no resolution context was used.
- Admitted read scope: the admitted specification; the repository files the specification cites (PoolManager.sol, BetterMath.sol, UniswapV2StandardExchangeDFPkg.sol, UniswapV2StandardExchangeInTarget.sol); the Uniswap V4 core math those citations depend on (Pool.sol, Position.sol, LiquidityAmounts.sol, lens/V4Quoter.sol, lens/StateView.sol); and a repository search for an implementation of this vault. No StonkBrokers, PairToken, Clutch, or Sourcify source was opened.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Specification body | docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md, Product (line 40), Terms (line 46), sections 1-9 (lines 64-249), "What this does not deliver" (line 251) | source observation | The spec defines a two-currency fee escrow with a per-currency cumulative index and a manual in-kind claim (lines 44, 90-129); a two-currency entry where either amount may be zero and the vault never swaps (lines 133-141); a single-target exit with a caller-supplied floor (lines 143-161); and a one-share target quote (lines 177-200). It also states that a later agent implements it and that this run authorizes no implementation (lines 230-232, 297-309). |
| Share mint and redeem equations | lib/crane/contracts/utils/math/BetterMath.sol `_convertToShares` (line 726), `_convertToAssets` (line 786) | source observation | `_convertToShares` = `assets.mulDiv(totalShares + 10**decimalOffset, reserve + 1)`; `_convertToAssets` = `shares.mulDiv(reserve + 1, totalShares + 10**decimalOffset)`. The spec's section 1 and section 5 equations match these two functions with `U` in the reserve slot, as claimed. |
| Decimals and offset | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol `initAccount` (lines 552-582) | source observation | ERC-20 decimals 18 (line 568) and ERC-4626 decimal offset 9 (line 581). The spec's 18 share decimals and `d` = 9 are confirmed against source. |
| Exact-in LP conversion denominator | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol lines 203-207 | source observation | The LP branch converts against `reserveBefore = indexSource.pool.balanceOf(address(this))`, the pre-deposit reserve, so received units stay out of the denominator. The spec's claim on this point holds. |
| Unlock, callback, and position ownership | lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol `unlock` (lines 55-66), `modifyLiquidity` (lines 94-137) | source observation | `unlock` calls `IUnlockCallback(msg.sender).unlockCallback(data)` and reverts `CurrencyNotSettled` when a nonzero delta remains; `modifyLiquidity` is `onlyWhenUnlocked` and `noDelegateCall`, passes `owner: msg.sender`, and returns `feesAccrued` separately with `callerDelta = principalDelta + feesAccrued`. The spec's section 6 sentences are accurate. |
| Fee collection mechanics | lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol `modifyLiquidity` (lines 144-235), libraries/Position.sol `update` (lines 77-105) | source observation | A zero liquidity delta still runs `position.update(0, feeGrowthInside...)`, which computes the owed fees and resets the last-seen fee growth, and the fee amount is returned as a positive delta to the caller. Collection is therefore one-shot and must be attributed at collection time, exactly as the spec's section 3 requires. The spec's collection mechanism is sound against this source. |
| V4 quoting tooling | lib/crane/contracts/protocols/dexes/uniswap/v4/lens/V4Quoter.sol (`quoteExactInput`, `quoteExactInputSingle`, `quoteExactOutput`, `quoteExactOutputSingle`), lens/StateView.sol (`getSlot0`, `getTickInfo`, `getFeeGrowthGlobals`, `getPositionInfo`, `getPositionLiquidity`, `getFeeGrowthInside`) | source observation | The repository's quoter prices swaps through an unlock-and-revert pattern, and StateView exposes read-only pool state. Neither removes liquidity nor composes a removal plus a sale, so no removal preview exists in the repository's V4 tooling. |
| Amount-to-liquidity inversion | lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol (`getLiquidityForAmount0` line 19, `getLiquidityForAmount1` line 37, `getLiquidityForAmounts` line 56) | source observation | The repository already ships the inversion from token amounts to a liquidity delta that a one-sided deposit needs. The specification never names it. |
| Implementation search | repository-wide search for `redeemTarget`, `feePerShare`, `claimFees`, "own vault" naming, untracked and modified Solidity files, plus listings of contracts/vaults, contracts/protocols/dexes/uniswap/v4, and the V4 lens directory | source observation | `redeemTarget` occurs only in the specification file. `feePerShare` occurs only inside this specification run's own documents. No tracked, modified, or untracked Solidity file implements this vault. Every V4 contract under contracts/ is a swap hook, a TWAP oracle, or a Standard Exchange/DETF surface. Wings (contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings) is a different product and is not the reviewed target. |
| Fee liability arithmetic | REPORT.md line 59 (liability definition), line 60 (remainder), line 248 (invariant 15) | static analysis | The liability is defined as a sum over every holder, which no contract can enumerate, and it is not equal to `floor(S * feePerShare_i / Q)`, so an aggregate substitute can drive the remainder negative. |

## Assumptions

- "A deposit of either token" is read as: the vault must accept an amount of one of the two pool currencies without requiring the other, that is, a one-sided deposit must be expressible and executable. The specification's own wording ("Either amount may be zero") supports this reading.
- "A reserve exposed to trading fees" is read as: the vault holds a fee-bearing reserve whose trading fees accrue to the holders of the claim, not merely that fees are collected somewhere.
- "A quote of one vault share into one token" is read as a single number for exactly one whole share denominated in exactly one configured target currency.
- "Implementation" means Solidity in this repository that implements this specification's flow — one Uniswap V4 position, a per-currency fee index, a share token, and a single-token exit — not documentation describing it.
- No project test was run, per the brief. Every counterexample below is static arithmetic on the specification's own formulas.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md | required | examined | Read in full: Product, Terms, sections 1-9, the invariant list, "What this does not deliver", Evidence, and Recommendations. |
| An implementation of this specification in this repository | optional tool | absent | Searched the repository; no Solidity implements this flow. See Evidence, implementation search row. |
| docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md | optional | not examined | Not opened; no resolution context was used. |
| PoolManager.sol, BetterMath.sol, UniswapV2StandardExchangeDFPkg.sol, UniswapV2StandardExchangeInTarget.sol | cited by the specification | examined | Read to check the specification's stated source observations. |
| Pool.sol, Position.sol, LiquidityAmounts.sol, lens/V4Quoter.sol, lens/StateView.sol | adjacent to the cited files | examined | Read to verify the fee-collection, quoting, and amount-inversion claims the four needs depend on. |

## Conclusions

Grades below are for the published specification. No implementation exists, so at the implementation level all four needs are unmet: there is no contract, no facet, no package, no test, and no deploy path for this vault, and nothing can be deposited, withdrawn, quoted, or exercised. The specification's own text agrees: it defers implementation to a later agent and authorizes none here.

| Need | Grade (specification) | Basis |
| --- | --- | --- |
| A reserve exposed to trading fees | partial | The mechanism is specified and I verified it against the repository's PoolManager, Pool, and Position: a zero-delta `modifyLiquidity` returns the position's owed fees as a positive caller delta and resets the fee growth, so collection is one-shot and is attributed at collection time as the spec requires. The exposure is nevertheless a separate two-currency manual claim that no share path surfaces, and the spec's liability accounting is not computable on chain as written. |
| A deposit of either token | partial | The interface accepts a zero amount on either side, but the vault never swaps, no amount-to-liquidity inversion is specified, and a one-sided deposit is usable only when the deposited currency is the range-active side at the current tick; otherwise `uReceived` is zero and the call reverts. |
| A withdrawal into one token | met | Section 5 removes exactly the redeemable liquidity slice, sells only that slice's opposing principal, pays one configured target currency, takes a caller-supplied floor, and reverts the whole call on a miss. Two qualifications are recorded below: the last withdrawal strands residual liquidity, and the exit path is price-exposed against the same pool. |
| A quote of one vault share into one token | partial | Section 7 fixes the semantics precisely — `uOut` from the exit equation, then a sale quote, then normalization, with explicit revert cases. It never names the preview mechanism, and the repository's V4 tooling cannot produce the composed removal-plus-sale preview the section requires while `getRate` "writes nothing". |

The specification's arithmetic is faithful to its cited sources: the mint and redeem equations match `BetterMath._convertToShares` and `_convertToAssets` exactly, the offset and decimals match `UniswapV2StandardExchangeDFPkg.initAccount`, and the unlock, callback, ownership, and fee-collection sentences match the repository's Uniswap V4 `PoolManager`. Where I mark a need partial, the defect is in the specification's own rules, not in its reading of those sources.

Peers were not read on this pass, so nothing here is council consensus.

## Review findings

### No implementation of this specification exists in the repository

- Location: repository-wide implementation search (Evidence, implementation search row); docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md lines 230-232 and 297-309.
- Invariant or requirement: The question asks whether the specification "and any implementation it has" meet the four needs.
- Impact: At the implementation level all four needs fail, because there is nothing to deposit into, withdraw from, quote, or exercise. `redeemTarget` and `feePerShare` exist only in this specification run's documents; every V4 contract under contracts/ is a swap hook, a TWAP oracle, or a Standard Exchange/DETF surface. Any statement that the needs are satisfied in code today would be false.
- Fix direction: Not a specification defect. A later authorization must produce the Crane package before any of the four needs can be graded against code. Until then, treat the four needs as specification-level only and keep the grades in the table above as the ceiling of what is achievable.
- Evidence class: source observation

### The fee liability is defined over an unbounded holder set that no contract can compute

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md line 59 (`liability_i` definition), line 60 (`remainder_i`), lines 102-109 (section 3 accounting), line 248 (invariant 15).
- Invariant or requirement: Need 1, a reserve exposed to trading fees. A fee reserve that holders can claim requires the index to be creditable only against escrow actually held, and `remainder_i` to stay non-negative.
- Impact: `liability_i` is "Sum over accounts of `unclaimed_i` plus unsettled `floor(balance * feePerShare_i / Q) - debt_i`" — a sum over every holder that no contract can enumerate, and not equal to `floor(S * feePerShare_i / Q)` because the per-account floors lose dust. The substitution an implementer is forced into overstates the liability: with three one-share holders and `feePerShare_i / Q` equal to 0.5, `floor(3 * 0.5)` is 1 while the sum of the three floors is 0, so the aggregate liability exceeds the true claim by one unit. If only zero units were collected, `remainder_i` becomes -1, violating "Must be at least zero" (line 60) and invariant 15. Keeping the exact definition means no on-chain computation exists at all. Either way the index can be credited beyond escrow, and `claimFees` (line 125) then reverts for want of escrow, so the reserve stops being payable and need 1 fails in practice.
- Fix direction: Redefine liability from maintained aggregates rather than an enumeration: a global crystallized total plus one dust bucket that absorbs the per-account floor difference, state explicitly which bucket absorbs it, and make `remainder_i = collected_i - liability_i` a maintained counter that is never negative rather than a quantity recomputed from holder state.
- Evidence class: static analysis

### Fee exposure is a side claim in two currencies that no share path surfaces

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md line 44 ("Fee escrow is claimed separately, in kind"), line 92 (fees outside `U` and `S`), line 125 (`claimFees`), line 127 ("Share exit does not pay `unclaimed`"), line 245 (invariant 12).
- Invariant or requirement: Need 1, a reserve exposed to trading fees, and need 4, a quote of one share into one token.
- Impact: The fee value is deliberately excluded from the share, and the redemption path pays only the principal-derived target amount. A holder who redeems shares and never calls `claimFees` ends the redemption holding a claim in two currencies that no redemption surface reports, and the quoted one-share value (line 179) contains no fee component at all, so the quote cannot answer what a share is worth. The exposure exists, but it is reachable only through a separate manual action that the product surfaces do not lead the holder to.
- Fix direction: Decide explicitly whether fee exposure is a share property or a side claim. If it stays a side claim, require the redemption path to surface the outstanding `unclaimed` per currency, for example in the exit return value or an event, and state in section 7 that the quote excludes fees by design so no caller treats the quote as total value.
- Evidence class: source observation

### A one-sided deposit has no specified conversion and only works on the tick-active side

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md line 53 (`uReceived`), line 135 (entry), lines 139-141 (no vault swap, zap named as dissent), line 253 ("It does not let this vault swap on entry"); Uniswap V4 principal sizing in lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol, where a tick below the range yields a currency0-only delta and a tick at or above the range yields a currency1-only delta.
- Invariant or requirement: Need 2, a deposit of either token.
- Impact: Uniswap V4 sizes a position by liquidity delta and derives the token amounts from it, so a vault that takes token amounts must invert them into a liquidity delta. The specification never states that inversion: the entry "pulls both pool currencies, adds liquidity" and defines `uReceived` as liquidity "from the principal delta". Without the inversion there is no defined liquidity for a one-sided deposit, no defined refund amount, no defined refund recipient, and no defined `minShares` check. Even with the inversion supplied, the deposited currency must be the range-active side: with the tick below the range the position takes currency0 only, so a currency1-only deposit produces `uReceived` = 0 and reverts under line 135, and the mirror holds above the range. "Deposit of either token" is therefore conditional on pool state rather than a product guarantee, and the specification's refusal of a swap route leaves no conversion path for the wrong side.
- Fix direction: Specify the entry conversion explicitly and in order — derive the liquidity delta from the deposited amounts, then `modifyLiquidity`, then settle and refund the unused remainder to the depositor — naming the inversion the repository already provides (`LiquidityAmounts.getLiquidityForAmounts`). Then either state the tick precondition as a product constraint with its own revert reason and a pre-flight check, or add a separately specified zap route that does not alter section 1.
- Evidence class: source observation

### The one-share quote has no preview mechanism and the repository's V4 tooling cannot supply one

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md line 179 ("It writes nothing"), line 187 (simulate the removal, then quote the sale against the post-removal pool state), line 194 (revert when "removal cannot be previewed"); lib/crane/contracts/protocols/dexes/uniswap/v4/lens/V4Quoter.sol and lens/StateView.sol.
- Invariant or requirement: Need 4, a quote of one vault share into one token.
- Impact: The quote is specified as a composition — preview a removal of `uOut`, then quote an exact-in sale against the post-removal state — but no preview mechanism is named, and the only quoter in the repository prices swaps through an unlock-and-revert pattern, which is a state-changing call, while StateView exposes read-only pool state with no removal simulation. A `getRate` that "writes nothing" therefore has no implementable route to the number it promises under the current tooling, and the implementer would be left to invent the mechanism, which is precisely where the trust assumption about price, fill, and staleness would be settled. The need is unmet as written even though its arithmetic is fully specified.
- Fix direction: Name the mechanism and its trust assumption, for example a static removal-and-swap simulator over pool state, an explicitly permitted eth_call or state-override quote with a stated freshness limit, or a narrowed preview that quotes the removal only and reverts on the sale. Then align the revert list in line 194 with whichever mechanism is chosen.
- Evidence class: source observation

### The last withdrawal strands residual liquidity in the position

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md line 159, line 249 (invariant 16), line 253 ("It does not promise that the last burn returns every liquidity unit").
- Invariant or requirement: Need 3, a withdrawal into one token.
- Impact: The final redeemer's single-token payout excludes the residual liquidity left by floor rounding, and that residual stays priced into the next deposit's denominator (line 159). The last exit is therefore not a withdrawal of the holder's full claim, and the specification states this only in the terms section rather than as a property of the redemption the user experiences.
- Fix direction: Keep the no-sweep rule, and state it as an explicit product limit on the redemption surface so it is not discovered at redemption time — surface the residual liquidity in the exit result or state plainly that a final exit leaves a residual position. A sweep rule would be a separate decision, not a change to the exit equation.
- Evidence class: source observation

### The quoted one-share value and the executed withdrawal share one price-exposed path

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md line 153 (sell the opposing principal into the same pool), lines 179-193 (the quote mirrors the exit path), line 246 (invariant 13), line 253 ("It does not make `getRate` independent of the pool. It does not close execution-price exposure on the exit sale.").
- Invariant or requirement: Needs 3 and 4, a withdrawal into one token and a quote of one vault share into one token.
- Impact: The number quoted for one share is produced by the same removal-and-sale path the exit executes, against the same pool, so it moves with the pool and with any other actor's liquidity; the specification's own bound is that the round trip is not profitless (invariant 13). A holder transacting at a quoted rate can receive materially less than quoted within the same block. The caller-supplied `minTargetOut` bounds the loss but is not tied to the quote, so the two surfaces can drift apart silently.
- Fix direction: Label the quote as an indicative preview with a stated maximum deviation, and derive the caller's `minTargetOut` from the quoted rate rather than leaving the floor unconnected to it, so the quote surface and the execution surface cannot disagree without the caller's floor catching it.
- Evidence class: source observation

## Limits

- Runtime or extraction proof: none. No project test, script, or simulation was run, per the brief. All arithmetic above is static and was checked by hand against the specification's own formulas; the liability counterexample is a static counterexample and was not executed.
- Not examined: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md; the peer responses, the draft, and the final of this review; the member files of the earlier research run that produced the specification; StonkBrokers, PairToken, Clutch, and Sourcify source, which were not opened.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
