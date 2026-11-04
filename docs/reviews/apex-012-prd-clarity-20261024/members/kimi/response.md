# Member response

## Identity
- Run ID: apex-012-prd-clarity-20261024
- Member label: kimi
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/kimi/response.md
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Question: is `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` clear enough that two implementers would build the same V3 and V4 Upper Lower Wings accounting? Reported here: quality and clarity defects, and every requirements question whose two answers would change the contract, tests, or vault behavior.

Primary target (read in full): `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`.

Context (labeled as context, not part of the verdict target):

- The APEX-2026-012 row of `docs/security/audit/second_review/REMEDIATION_TRACKER.md`. It restates the same design in one row (apportioned reserve on both families, build V3 Wings, counter-based `getRate`, conversion only on the acting holder's entry/exit) and adds nothing that resolves the questions below.
- V4 Wings sources under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`, read only to judge whether the PRD leaves an implementer free to diverge: `...EconomicTarget.sol`, `...LiquidationQuote.sol` (head), `...Geometry.sol`, `...Accounting.sol`, `...Harvest.sol` (head), `...InFacet.sol`, `...OutFacet.sol`, `interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol`, `interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic.sol`, plus the Crane generic surfaces `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` and `IStandardExchangeOut.sol`. I also confirmed by directory listing and grep that no `upperLowerWings` exists under `.../uniswap/v3/`; the V3 tree is FullSpread only, matching the PRD's "V3 source" claim.

## Evidence

Anchors used (PRD headings; file facts from static reading):

1. PRD "Accounting": the position is liquidity **and idle balances** ("the tokens the vault's liquidity and idle balances hold"); `getRate = settledTarget * 1e18 / supply`; settled target "changes only when ... a target deposit, target paid to a redeemer, or target the vault itself received from a swap it executed."
2. PRD "Entry": "Shares are minted from the liquidity actually added against the position that existed before the add." No formula is given.
3. PRD "Exit": burn `s/S` of the position, sell only that slice's other token, pay burn target plus delivered swap target, minimum-target-out slippage, "does not use `MIN` or `MAX` as a price limit that ignores the slice."
4. PRD "Rate checkpoint": counter written at end of deposit and redeem; harvest may credit collected target fees; "`liquidationValue`, if it remains..."
5. PRD "Owner ruling"/"V3 source": build a new V3 Upper Lower Wings family "with the same accounting"; V3 FullSpread stays untouched.
6. PRD "Tests": nine tests; test 1 keys on "B's shares divided by the new supply equal B's fraction of the remaining liquidity"; test 5 pins the rate formula and donation neutrality.
7. V4 current code facts:
   - `EconomicTarget.getRate` = `Quote.quote(...).value / supply`; `quoteRate` decodes a projected `Projection.State` and values `Projection.value(q) / q.book.supply`.
   - The book is three slots (`Position[3]`): full-range core plus strictly separated upper/lower wings derived from current sqrt price (`Geometry.ranges`).
   - Current mint math is value-based: `Accounting.issue` returns `supply == 0 ? credit : supply * credit / value`, where `value` is quote-derived. The PRD bans that input, so no existing mint formula carries over.
   - The vault keeps oracle-driven idle target (`Accounting.liquidTarget`, `sleeveState`, `liquidReservePercentageOfVault`); idle balances are a real, designed state, not an edge case.
   - `Harvest.snapshot()` reads slot0 and the planner "close[s] converted wings, pair[s] local inventory, place[s] residuals"; ordinary harvest never swaps.
   - The family interface exposes `liquidationValue()`; the generic Crane entry point `IStandardExchangeIn.exchangeIn` is exact-in with `minAmountOut`, while `IStandardExchangeOut.exchangeOut` is **exact-output**: the caller names an exact `amountOut` of target and a `maxAmountIn` of shares.

## Assumptions

- The PRD is the sole normative spec; the tracker row and V4 sources are context for divergence risk only.
- V4 sources as of 2026-10-24 represent the family the PRD rewrites; statements about pool mechanics (a swap crossing the vault's own ranges pays target out of the vault's remaining liquidity) are reasoned from Uniswap V4 semantics and the read sources, not executed.
- "Same accounting" for the new V3 family does not by itself imply any geometry, integration surface, or interface.
- APEX-2026-024/025/026/040 are out of scope per the PRD and are referenced only where the PRD's own text leans on them.

## Coverage

- Read in full: the PRD; the tracker 012 row; `Geometry.sol`; `Accounting.sol`; both family interface files; `InFacet.sol`; `OutFacet.sol`; relevant sections of `IStandardExchangeIn.sol`/`IStandardExchangeOut.sol`.
- Read in part (head/signatures): `EconomicTarget.sol`, `LiquidationQuote.sol`, `Harvest.sol`.
- Not read: `InTarget`/`OutTarget` execution internals, `InExecutionBase`, `ExecutionDelegate`, `Rebalance*`, `Projection.sol`, `Money.sol`, `Inventory.sol`, the TestBase, and V3 FullSpread internals beyond the directory listing. This is enough to judge spec ambiguity; it is not enough to prove any mechanic at runtime.

## Conclusions

The PRD is unusually clear about the *economic intent*: no live whole-book quote on deposit/redeem/`getRate`, a settled-target counter as the rate, slice-only exit sales, no split quote/zap replacement, and no gifting of pre-existing other token to entrants. On that level two implementers would build the same *policy*.

They would not build the same *contracts*. The PRD never states (a) the share-mint formula over a three-range book with idle balances, (b) the exact counter delta per operation, (c) whether idle target is paid on exit and whether the liquid-reserve sleeve survives, (d) how the exit's "redeem `s` shares with a minimum target out" maps onto the exact-output `exchangeOut` interface the family currently ships, or (e) anything structural about the new V3 family beyond "same accounting." Each of these admits two defensible readings that produce different contracts, different test outcomes, or different vault behavior. Verdict: the PRD is sufficient to authorize the design direction; it is not sufficient to produce convergent implementations of both families without the clarifications below.

### Requirements questions

Each question's two answers produce different contracts, tests, or vault behavior. The smallest clarification that would close each is stated; none proposes a different economic design.

1. **Share-mint formula on deposit.** "Minted from the liquidity actually added against the position that existed before the add" — over three ranges plus idle balances this is not a formula. Readings diverge on: aggregate vs per-range liquidity ratio, and whether idle target/other balances and uncollected fees enter the base (excluding them gifts or dilutes idle inventory on every mint). Smallest clarification: one equation, e.g. `minted = S * addedLiquidity / existingLiquidity`, naming the aggregation rule and stating whether idle balances are included or excluded.
2. **Counter delta on deposit.** Does a target deposit raise settled target by the gross deposit, or by the deposit net of the portion swapped into the other token? Gross keeps the counter an accounting figure (consistent with "does not include unsold other token" only under one reading); net makes it track held target. Different `getRate` after every two-sided entry. Smallest clarification: state `settledTarget += <exact amount>` for deposit.
3. **Counter delta on redeem when the remaining position fills the slice sale.** The PRD says the counter changes by "target paid to a redeemer" and by "target the vault itself received from a swap it executed." On exit the vault both pays and receives target in one operation, and when the vault's own remaining liquidity takes the fill, target also leaves through the LP side — a flow that fits neither phrase. Readings: decrement by gross payout only (remaining holders' counter share drops, compensated by other-token inventory — consistent with "their token mix may change"), or net the swap's self-fill, or recompute held target. Each gives a different counter and different test-1/test-2/test-5 numbers. Smallest clarification: state `settledTarget -= <exact amount>` for redeem and define whether the exit swap's gross receipt is ever credited.
4. **Idle target on exit.** The position is defined as liquidity **and idle balances**, but the exit steps pay only the burned slice plus swap proceeds. Does the redeemer also receive `s/S` of idle local target? The current vault deliberately holds an oracle-driven idle sleeve (`liquidTarget`, `sleeveState`), so this is a designed state, not a corner case. Smallest clarification: one sentence stating whether idle target is paid pro-rata on exit.
5. **Liquid-reserve sleeve survival.** Does the oracle-driven sleeve percentage remain in the new accounting — i.e., does part of each deposit stay idle rather than being added as liquidity? Keeping it changes deposit placement and mint base; removing it changes vault behavior and the `sleeveState` surface. Smallest clarification: keep/remove statement.
6. **Exit entry-point semantics.** `IStandardExchangeOut.exchangeOut` is exact-output: the caller names exact target out and caps shares in. The PRD's exit is exact-in shares with a minimum target out ("Redeeming `s` shares", "the exiting holder's minimum target out", revert if the swap cannot deliver it). These do not map onto each other; an implementer must either reinterpret the exact-output interface or change it. Smallest clarification: name the function and the slippage parameter the exit exposes.
7. **Swap price-limit rule and entry protection.** "Does not use `MIN` or `MAX` as a price limit that ignores the slice" says what not to do, not what to do: an unrestricted limit with a post-swap minimum-out check, and a slice-derived limit, both satisfy the sentence and behave differently under manipulation. The entry swap has no stated protection at all. Smallest clarification: state the constraint for both swaps (e.g., unbounded limit plus min-out enforcement, and whether entry carries a min-out).
8. **Entry swap sizing and the third composition case.** "Swaps part of that deposit into the other token" — the size of "part" is unspecified (current composition ratio at the live tick? proportional to the target wing? a fixed fraction?), and the PRD handles two-sided and single-sided-target positions but not a position single-sided in the *other* token (price beyond the target wing). Smallest clarification: state the sizing rule and the behavior for the other-token-only case.
9. **V3 family structure.** The new V3 Wings family is specified only as "the same accounting." Nothing states its geometry (full-range core plus adjacent upper/lower wings per V4 `Geometry.ranges`?), its position-management surface (NFPM vs custom wrapper), fee-tier handling, initialization, or interface parity with the V4 family. Two implementers cannot build the same V3 vault or TestBase from this. Smallest clarification: state that V3 mirrors the V4 geometry and name the V3 integration surface and required interface parity.
10. **Bootstrap.** With supply zero the PRD fixes only `getRate = 1e18`; the first deposit's mint amount and initial placement are undefined, and "adds liquidity in proportion to those existing positions" is vacuous when no positions exist. APEX-2026-040 covers dead-share and rounding, not the base rule. Smallest clarification: state the bootstrap mint (e.g., shares = deposit amount) and the initial placement ranges.
11. **`quoteRate` semantics.** "`getRate` and `quoteRate` read that counter and the supply" — for `quoteRate(exchange, asset, state)`, which currently decodes a projected book, it is unstated whether the projected state's supply is used or the live supply, and whether the Projection preview survives at all. Smallest clarification: one sentence defining `quoteRate` under the counter design.

## Review findings

### D1 — Counter update rules are internally ambiguous on the exit path
Location: PRD "Accounting" (settled-target paragraph) and "Rate checkpoint", read against "Exit" step 2 ("The remaining vault position may fill that sale. That is intended."). Invariant: one counter, one `getRate`, reproducible by any implementer. Impact: when the remaining position fills the slice sale, target leaves the vault through both the payout and the LP side of the pool; the PRD's two credit/debit phrases ("target paid to a redeemer", "target the vault itself received from a swap it executed") do not determine the resulting counter, so two implementers emit different `getRate` values after any internally-filled exit and tests 1, 2, 4, and 5 produce different numbers. Fix direction: replace the prose with explicit per-operation delta equations (this is a clarification, not an edit applied here). Evidence class: static reading of the PRD plus Uniswap V4 mechanics visible in the read sources; not runtime proof.

### D2 — Share-mint rule is not a formula and no existing formula survives
Location: PRD "Entry" ("minted from the liquidity actually added"), read against `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.issue` (`supply == 0 ? credit : supply * credit / value`, value quote-derived) and the three-slot book in `Geometry.ranges`/`LiquidationQuote.Request.positions[3]`. Requirement: identical deposits mint identical shares regardless of implementer. Impact: the current mint is value-based, which the PRD bans; the replacement is unspecified across three ranges plus idle balances, so share supply after identical deposit sequences diverges, and every later fraction assertion (tests 1, 3, 6) diverges with it. Fix direction: state the exact mint equation and its treatment of idle balances and uncollected fees. Evidence class: static reading of PRD and code.

### D3 — Exit semantics conflict with the shipped exact-output interface
Location: PRD "Exit" (steps and slippage paragraph) read against `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` (`exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, ...)` — exact output) and `OutFacet` exposing only `exchangeOut`/`previewExchangeOut`. Requirement: the exiting holder redeems `s` shares with a minimum target out. Impact: one implementer keeps the exact-output interface and reinterprets "minimum" as the exact `amountOut` (a stricter, different behavior: revert unless the slice delivers exactly the asked amount); another adds or switches to an exact-in redemption. Different external contracts and different test harnesses. Fix direction: name the exit entry point and its slippage parameter in the PRD. Evidence class: static reading of PRD and interface source.

### D4 — The new V3 family is specified only as "same accounting"
Location: PRD "V3 source" and "Owner ruling" ("Build a new Uniswap V3 Upper Lower Wings family to this accounting"), read against the confirmed absence of any `upperLowerWings` under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` (directory listing and grep; FullSpread only). Requirement: one family passing does not close the other; both families run the same nine tests. Impact: geometry, position-management surface, fee-tier handling, and interface parity are all implementer inventions; two implementers cannot produce the same V3 vault, and the "run this set on ... the new V3 Wings vault" gate is not executable as specified. Fix direction: state that V3 mirrors the V4 wing geometry, name the V3 integration surface, and require interface parity. Evidence class: static reading plus directory evidence.

### D5 — Swap protection is specified only by prohibition
Location: PRD "Exit" ("does not use `MIN` or `MAX` as a price limit that ignores the slice") and "Entry" (no slippage statement at all). Requirement: the exit sale uses the pool's real price with the exiting holder's minimum out. Impact: "unbounded limit plus post-swap min-out check" and "slice-derived price limit" both satisfy the text and behave differently when the pool is adversarially moved inside the transaction; entry swaps are sandwich-exposed under one reading and protected under another. Fix direction: state the concrete constraint for both swaps. Evidence class: static reading.

### D6 — Idle balances are in the position definition but absent from the exit payout
Location: PRD "Accounting" (position = liquidity and idle balances) vs "Exit" steps 1-3 (burn slice, sell slice, pay burn target plus swap proceeds), read against the current vault's designed idle sleeve (`Accounting.liquidTarget`, `EconomicTarget.sleeveState`). Invariant: a share is a fraction of every position the vault holds. Impact: paying or withholding `s/S` of idle target changes every redemption amount and the counter; the PRD's own definition of the position supports both readings. Fix direction: state whether idle target is paid pro-rata on exit and whether the oracle sleeve survives the redesign. Evidence class: static reading of PRD and code.

### D7 — Test assertions rely on the undefined aggregation rule
Location: PRD "Tests" 1 ("B's shares divided by the new supply equal B's fraction of the remaining liquidity") and 2 ("target removed by burning B's liquidity"), read against the three-range book. Requirement: tests must be writable unambiguously. Impact: "fraction of the remaining liquidity" over core plus two wings is per-range, aggregate, or value-weighted depending on the unresolved mint/burn rule (D2); the assertions as written cannot be checked without that decision, so two test authors write different tests. Fix direction: resolve D2 and reference the aggregation rule in the test text. Evidence class: static reading.

### D8 — "`liquidationValue`, if it remains" is optional language for a tested component
Location: PRD "Rate checkpoint" and "Tests" preamble ("Do not mock the vault, the quote, the pool, or the rate provider"), read against `IUniswapV4UpperLowerWingsStandardExchangeVault.liquidationValue()`. Impact: keep-or-delete optionality produces different V4 interfaces, and the text says nothing about whether the new V3 family must expose the same quote surface; the test preamble implies the quote still exists to be unmocked. Fix direction: make retention mandatory or remove it, and state the V3 parity requirement. Evidence class: static reading.

### D9 — Harvest scope is bounded only by two prohibitions
Location: PRD "Rate checkpoint" and "Non-goals" ("No harvest, rebalance, or keeper call that sells the position's other token"), read against `Harvest.sol`'s documented planner behavior ("close converted wings, pair local inventory, place residuals"; ordinary harvest never swaps). Impact: one implementer keeps the geometry-maintenance harvest (closing converted wings and re-placing residuals — which moves liquidity between ranges and therefore changes what "the position" is at the next checkpoint); another strips harvest to fee collection. Both satisfy the stated prohibitions and produce different position evolution and different test-9 outcomes. Fix direction: enumerate the harvest mutations that remain allowed and state when collected target fees enter the counter. Evidence class: static reading of PRD and code.

## Limits

Static reading only. No `forge build`, `forge test`, install, deploy, or commit was run, and none of the findings is runtime proof. Execution internals of `InTarget`/`OutTarget`, `ExecutionDelegate`, `Rebalance*`, `Projection`, `Money`, `Inventory`, and the TestBase were not read; a fuller read could add defects but is not needed to establish the divergence points above. Statements about swap/pool mechanics are reasoned from Uniswap V4 semantics and the read sources. This response does not propose a different economic design; every fix direction is a clarification of the design the PRD already states.
