# Member response

## Identity

- Run ID: apex-012-prd-clarity-20261024
- Member label: minimax
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/minimax/response.md
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

**Question.** Is `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` clear enough that two implementers would build the same V3 and V4 Upper Lower Wings accounting? Report quality and clarity defects, and list every requirements question whose answer would change the implementation. Do not invent a new product design.

**Required target.** `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` (read in full; 99 lines).

**Optional context (as context, not as authority).**
- `docs/security/audit/second_review/REMEDIATION_TRACKER.md`, section `APEX-2026-012: apportioned reserve` (owner ruling 2026-10-23), used only to check that the PRD does not contradict the recorded decision.
- V4 Upper Lower Wings sources under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`, used only to judge whether the PRD leaves an implementer free to diverge.

**Standing constraint honored.** V3 FullSpread is treated as context that must not be converted into, or stand in for, the V3 Wings family. Nothing in this response treats the V3 FullSpread implementation as the Wings design.

## Evidence

**Read as required target.**
- `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`, all sections: Required outcome (l. 11), Owner ruling (l. 15), Accounting (l. 27), Entry (l. 41), Exit (l. 49), Rate checkpoint (l. 64), What this does not close (l. 72), Tests (l. 80), Non-goals (l. 96).

**Read as admitted optional context.**
- `REMEDIATION_TRACKER.md`, section `APEX-2026-012: apportioned reserve`. Disclosure: I read the whole tracker file, not only that section; the other sections (054, 037, 010, 011, migration checkpoint) informed my reading of scope and containment wording only and are not evidence for any finding below.
- V4 Wings sources, specifically: `...EconomicTarget.sol` (getRate l. 27-30, quoteRate l. 32), `...Money.sol` (deposit l. 112-139, redeem l. 141-181, `_fund` l. 190, `_swapDeficit` l. 219, `requiredInput` l. 244, `preview` l. 266), `...LiquidationQuote.sol` (`quote` l. 108, `_sell` l. 298, `MAX_STEPS = 512` l. 25), `...Harvest.sol` (`totalInventory` l. 108, `harvest` l. 118, `close` l. 136, `place` l. 147, `liquidFloor` l. 157), `...Accounting.sol` (`issue` l. 18, `entitlement` l. 24, `liquidTarget` l. 41), `...Projection.sol` (`value` l. 71, `transition` l. 88), `...Common.sol` (`quoteRequest`, `execute` l. 41-43, `ManagerAlreadyUnlocked` l. 39), `...Repo.sol` (three position slots, salts, `local0`/`local1`), `...Geometry.sol` (core/upper/lower ranges), `...Inventory.sol`, `...Types.sol`, `...DFPkg.sol` (init, share decimals), `interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol` (`liquidationValue`), `test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol`.

**Context read outside the admitted scope, disclosed and demoted.** To test whether the PRD leaves the V3 side free, I also opened the V3 FullSpread files, the V3 companion PRD, and the shared V3/V4 remediation PRD. Findings that rest on these files are marked `context` in the evidence class and are constructed so that the conclusion also follows from the PRD and the V4 sources alone.

**Method and limits of the evidence.** Static reading only. No `forge build`, no `forge test`, no `forge script`, no install, no deploy, no wallet operation, no commit. No peer response, feedback, draft, resolution, or `RUN.md` content was read before this file was written. Every "impact" below is a reasoned consequence of the cited text, not an observed runtime result.

## Assumptions

1. The PRD is the only normative specification for the new accounting. The tracker records the owner decision and points at the PRD; it does not itself fix a formula.
2. The PRD is read as binding on both families independently (l. 17), so a rule stated once applies to V3 and V4 alike unless a section says otherwise.
3. "Position" is read as deployed liquidity plus idle balances, per l. 29 and l. 24 ("core and both wings").
4. "Fraction of the position" in the Tests section (l. 82) is read as a fraction of liquidity, because l. 86 states the fraction invariant in liquidity terms ("B's fraction of the remaining liquidity"). Where the PRD's own wording permits the token-amount reading instead, I treat that as a defect, not as a settled interpretation.
5. The V4 Wings family as it exists today is the baseline the PRD changes: three vault-owned pool positions (core, upper, lower), idle `local0`/`local1` balances, a liquid-floor sleeve, and a `getRate` derived from the whole-book quote.
6. The still-in-force shared V3/V4 remediation PRD is treated as context that the APEX-012 PRD does not explicitly override. If the owner intends APEX-012 to supersede it, several D-series findings get weaker, not the PRD's internal gaps.
7. Reviewer competence is assumed for both hypothetical implementers; the finding is that the text, not the readers, decides.

## Coverage

Covered: the whole PRD; the tracker decision section; the V4 Wings family source that the PRD must be implementable against, read end to end for the rate, money, harvest, accounting, projection, geometry, repo, and package layers; the four interfaces the PRD's named functions live in.

Not covered, and not claimed: runtime behavior (no execution of any kind), the deployed Wings instances on chain, the launch scripts and stage wiring, the DETF/bond consumers of `getRate` and `quoteRate`, the fee-oracle sleeve configuration used in tests, the APEX-2026-024/025/026/040 work, and any peer output.

## Conclusions

**Answer: no. The PRD is directionally clear and mechanically underdetermined.** It fixes the economic direction well enough to be implementable at all: the money path stops reading the whole-book liquidation quote, a share becomes a fraction of the position, the other token converts only inside the acting holder's own entry or exit, and the rate becomes a counter-based number that cannot be moved by an outsider's swap. The Tests section (l. 86-94) is genuinely discriminating: it forbids constant-payout assertions, forbids running the V3 half against FullSpread, and turns the exit into a share-fraction proof. That part is good work and it is what makes the remaining gaps visible rather than hidden.

What is missing is everything that turns "a fraction of the position" into arithmetic. The PRD states invariants (l. 43, 47, 51, 58) but never states the quantity that shares are minted against, the quantity that `settledTarget` holds, or the quantity a redeem slice is taken from. On the V4 side those three quantities are computable today only from the quote the PRD bans (Money l. 132, l. 160-161; Accounting l. 18, l. 24), and the PRD does not replace them with formulas. Concretely:

- 11 defects, of which 5 are load-bearing contradictions or omissions inside the PRD and 6 are gaps that surface only when the PRD is read against the V4 source it must change.
- 10 requirements questions survive the "two answers change the contract, tests, or vault behavior" bar.

Two implementers following this PRD today would agree on the architecture and disagree on the numbers. They would disagree on how many shares a deposit mints, on what `getRate` returns after the first deposit, on whether the redeeming holder receives a share of the idle sleeve, on what a deposit does while the pool is locked, on whether the transition-quoting surface is rewritten or left as is, and on what the V3 family even is. Every one of those is a different contract, a different test expectation, or different vault behavior, so none of them can be closed by "careful reading".

The single highest-leverage addition is one line in the Accounting section stating the share basis and the minting formula (`ΔS = S · ΔL / L_pre`, liquidity units, pre-add positions), because the exit slice, the entry swap sizing, the "must not increase" invariance at l. 47, and the fraction invariants at l. 86 and l. 91 all collapse onto that one definition. The second is one line defining `settledTarget` as a stored counter with a per-operation credit/debit table, because l. 35 and l. 90 are otherwise unfalsifiable.

The V3 half is not implementable from this PRD at all. It mandates a new family (l. 23, l. 8) and specifies none of its geometry, custody, interface, bootstrap, or locked-pool behavior, while the shared remediation PRD still mandates a constant-product model for the new V3 family (context). "One family passing does not close the other" (l. 6, l. 82) is the right instinct, but the PRD gives the V3 half no shared observable to test against, so the V4 result cannot be transferred even in principle.

Nothing in this response proposes a different economic design. Every fix direction below names the missing statement, not a new mechanism.

### Requirements questions

Each question below has two answers that produce different contracts, different tests, or different vault behavior. The smallest closing clarification is stated for each.

**RQ1 — What is the share-minting formula for a deposit, and in what unit is the "position" measured?**
- Divergence: (a) liquidity-fraction minting, `ΔS = S · ΔL / L_pre`, where `L` is the sum of slot liquidity before the add; (b) settled-target-fraction minting, `ΔS = S · Δt / settledTargetBefore`, where `Δt` is the target retained after the entry swap. (a) makes the minted count depend on the entry swap's realized output, which depends on live pool depth; (b) makes the minted count independent of the other token the depositor contributed, so the depositor's share fraction of the position no longer equals their minted fraction. Both readings satisfy l. 43's prose and produce different supply, different entitlements, and different `getRate`.
- Smallest clarification: "Shares minted = `S · ΔL / L_pre`, where `L` is the total deployed liquidity of the vault's positions before the add and `ΔL` is the liquidity added by this deposit; the position basis is liquidity, not token amounts."

**RQ2 — Does the share basis and the redeem slice include the vault's idle (undeployed) balances, or only deployed liquidity?**
- Divergence: (a) liquidity only, so the idle sleeve is unowned by shares and stays with remaining holders; (b) position including idle, so a redeeming holder takes a pro-rata slice of the sleeve. The V4 family deliberately keeps an idle target sleeve out of the pool (`Harvest.liquidFloor`, `Accounting.liquidTarget`), so this is not hypothetical: the two answers pay different target amounts on exit and leave different residual state.
- Smallest clarification: "The share basis is deployed liquidity only; idle balances are not apportioned and remain with the remaining holders after a redeem."

**RQ3 — What exactly is `settledTarget`, and what are its credit and debit rules per operation?**
- Divergence: (a) a pure accumulator that moves only on vault operations, as l. 66 says ("counter", "credit updates the counter"); (b) a stored balance of the vault's target holdings refreshed at operation boundaries, as l. 29 and l. 37 read. Under (a) the counter permanently diverges from the target actually held, because an exit's fill and an entry's conversion never touch it; under (b) an outsider's swap changes the counter at the next operation, which l. 37 forbids. Also unresolved: whether a deposit credits the gross target deposited or only the target retained after the entry swap, and whether the credit for a vault-executed swap includes the LP fee the vault earns on its own trade.
- Smallest clarification: "`settledTarget` is a stored counter. It is credited only by target actually added to the position by a deposit, by target received from a swap the vault executed (excluding LP fees the vault earns on that swap), and by target fees actually collected at harvest; it is debited by target paid to a redeemer. It is never recomputed from holdings."

**RQ4 — How much of the deposit is swapped on entry, and how is the added pair made proportional to the existing positions?**
- Divergence: (a) swap a fixed fraction of the deposit; (b) compute the proportional addition at the pre-swap tick and swap exactly the target needed to complete that pair. The two produce different minted share counts, different resulting mixes, different counter credits, and different residual idle balances for the same deposit. The PRD says only "swaps part of that deposit" (l. 43).
- Smallest clarification: "The vault sizes the entry swap from the proportional addition computed at the pre-swap tick, and swaps exactly the target amount required to complete that pair; the swapped fraction is not fixed."

**RQ5 — What happens on deposit and redeem while the pool cannot be modified (V4 PoolManager unlocked, V3 bound pool locked)?**
- Divergence: (a) both revert; (b) deposit mints without the entry swap; (c) redeem pays the slice's target from idle balances without removing liquidity or swapping. The PRD's exit mandates a liquidity removal and a swap, which is impossible in the locked state, and the PRD says nothing about it; the still-in-force shared remediation PRD requires funded local sleeve operations to remain supported while the pool is locked (context). The three answers differ in both contract behavior and test expectations.
- Smallest clarification: "When the pool or PoolManager is locked, deposit reverts with `BoundPoolBlocked` and redeem reverts with `BoundPoolBlocked`; no partial local-sleeve path exists on the money path." (or the chosen alternative, stated once for both families).

**RQ6 — What does `minimum` mean on redeem, and is the exit swap exact-in or exact-out?**
- Divergence: (a) `minimum` is the total target paid to the redeemer (slice target plus swap proceeds); (b) `minimum` constrains only the swap proceeds. And (i) exact-input with a derived price limit versus (ii) exact-output versus (iii) exact-input with a post-check differ in partial fills, rounding, and in what happens to unsold other token. The current V4 API treats `minimum` as total assets out (Money l. 141, l. 162), the PRD's wording is "the exiting holder's minimum target out" (l. 62), and test 7's revert assertion (l. 92) is satisfiable under more than one reading.
- Smallest clarification: "`minimum` is the total target paid to the redeemer. The exit swap is exact-input of the slice's other token; unsold other token remains in the vault and is not paid to the redeemer."

**RQ7 — What are the projected-state semantics of `quoteRate`?**
- Divergence: (a) `quoteRate` ignores the supplied transition state and returns `settledTarget · 1e18 / totalSupply`; (b) it projects the counter and supply over the supplied state. Today `quoteRate` decodes the state and returns the projected book value (`EconomicTarget` l. 32), and a hook-leg helper calls it specifically to obtain a post-transition rate; a rate-provider surface exposes it too (context). The PRD's "read that counter and the supply" (l. 68) supports (a) and breaks (b), without saying whether that break is intended.
- Smallest clarification: "`quoteRate` ignores the supplied state and returns the stored counter over current total supply; consumers that require a projected rate are updated in the same change." (or state that the projected variant is kept and how it is computed from the counter).

**RQ8 — Is the transition/quote surface rewritten on the new accounting, or removed from the new families?**
- Divergence: (a) rewrite `quoteState`, `quoteTransition`, `quoteAssets`, and the projection so they mirror the money path; (b) leave them as is; (c) drop the transition facets from the new families. Today the projection values the book with the same liquidation quote the PRD bans (`Projection.value` l. 71-76, `transition` l. 102/111), so (b) leaves the vault's own query surface predicting payouts the money path will not produce, and the PRD's test list has no transition case to catch it.
- Smallest clarification: "The transition quoting surface is rewritten on the apportioned accounting and its predicted share counts and payouts must equal the money path's results for the same inputs."

**RQ9 — What are the V3 Wings family's geometry, position custody, bootstrap share rule, and locked-pool behavior?**
- Divergence: any two of (a) three vault-owned pool positions matching the V4 core/upper/lower geometry; (b) a single full-range position with a different notion of "wings"; (c) a different custody mechanism (vault-owned pool position versus an external position manager); and independently, a first-deposit share count of (i) 1:1 with the deposited target, (ii) liquidity-denominated, or (iii) a bootstrap with dead shares. These produce different contracts, different supply scales, and different first-deposit rates. The PRD asserts the family does not exist and mandates building it (l. 8, l. 23) but specifies none of it, and its shared test set presumes a "core and both wings" position shape the V3 side never defines.
- Smallest clarification: "The V3 Wings family holds three vault-owned pool positions with the same core/upper/lower geometry as V4, adapted to the V3 pool's mint/burn/collect callbacks; the first deposit mints one share per deposited target unit and mints no dead shares; the V3 locked-pool policy equals the V4 one."

**RQ10 — Does a harvest that closes and re-places a converted wing change `settledTarget` or the share basis?**
- Divergence: (a) no: harvest changes the counter only by collected target fees, and a wing close/re-place changes neither the counter nor the fraction basis; (b) yes: the counter tracks the target content of the position, so a close/re-place changes it. The V4 harvest closes converted wings and re-places the inventory (`Harvest.harvest`, `place`), which changes deployed liquidity and the position's token content without any token moving to a holder; l. 66 and test 9 (l. 94) constrain the harvest but do not settle this.
- Smallest clarification: "Harvest changes `settledTarget` only by target fees actually collected. Closing and re-placing a wing changes neither `settledTarget` nor any holder's share fraction."

## Review findings

### D1 — The share-minting basis is never stated, and l. 43 and l. 47 are not simultaneously satisfiable as written

- **Location:** PRD l. 43 ("Shares are minted from the liquidity actually added against the position that existed before the add") and l. 47 ("The number of shares minted for a given target deposit must not increase because an outsider added liquidity for the duration of the call and then removed it"), read with l. 24 ("A deposit adds liquidity in proportion to those existing positions") and l. 86/l. 91.
- **Invariant or requirement:** A depositor's minted shares must equal their fraction of the post-deposit position, and the minted count must not depend on live external pool liquidity.
- **Impact:** The PRD mixes two bases. Read as a liquidity basis, `ΔS = S · ΔL / L_pre`: the entry swap's realized other-token output depends on the pool depth at execution time, so an outsider who adds liquidity to make the swap cheaper increases `ΔL` and therefore the minted count, violating l. 47. Read as a target basis, `ΔS = S · Δt / settledTargetBefore`: the minted count ignores the other token the depositor just contributed, so the depositor's fraction of the position is no longer their share fraction, violating l. 43 and l. 91. A bootstrap deposit has no pre-add position at all, so neither basis has a denominator. Two implementers pick different bases and produce different supply, different minted counts for the same deposit, and different downstream entitlements, and each can claim to have satisfied l. 43.
- **Fix direction:** State the minting formula, the unit of the position basis, the read order relative to the entry swap, and the first-deposit rule. One sentence fixes l. 43, l. 47, l. 86, and l. 91 together.
- **Evidence class:** PRD source reading; V4 source reading for the arithmetic that must be replaced (`Money` l. 132-133, `Accounting.issue` l. 18). Static reading, not runtime proof.

### D2 — `settledTarget` is used as a rate numerator but is never defined as a quantity with a state transition

- **Location:** PRD l. 33-37 (Accounting) and l. 66 (Rate checkpoint, "Write the settled target counter at the end of deposit and redeem").
- **Invariant or requirement:** `getRate` must equal `settledTarget · 1e18 / supply` (l. 35, restated as test 5 at l. 90), and must not move because of outsider activity (l. 37, l. 39).
- **Impact:** Two readings coexist in the text. As an accumulator (l. 66's "counter", "credit updates the counter"), it never reflects the target an exit fill left with the remaining holders, nor the target an entry swap converted, so `getRate` drifts further from reality with every operation and test 5's equality is only checkable against the vault's own stored number. As a refreshed balance of target actually held (l. 29, l. 37's "the tokens the vault's liquidity and idle balances hold"), an outsider's swap changes the counter at the next operation, which l. 37 forbids and test 4 does not cover (test 4 only reads between operations). Also unspecified: whether a deposit credits gross deposited target or only the target retained after the entry swap, whether a vault-executed swap's credit includes the LP fee the vault earns on its own trade, and what the counter is on a vault initialized with an existing position.
- **Fix direction:** Define `settledTarget` as a stored counter and give a per-operation credit/debit table, including the harvest fee case and the bootstrap case. State that it is never recomputed from holdings or from the tick.
- **Evidence class:** PRD source reading. Static reading.

### D3 — The position is described in token amounts while minting and slicing are described in liquidity; the two are never reconciled

- **Location:** PRD l. 29 ("The position has two actual token amounts... the tokens the vault's liquidity and idle balances hold") and l. 31 ("Each share owns `1 / S` of the position") against l. 43 (minting from "the liquidity actually added") and l. 53 (the slice's "actual target and other token in that liquidity at the current tick").
- **Invariant or requirement:** "A share is a fraction of the position" (l. 13, l. 24) and the fraction invariants in tests 1, 6, and 7 (l. 86, l. 91, l. 92).
- **Impact:** A liquidity fraction equals a token-amount fraction only at a fixed price. After any market move, a holder's fraction of liquidity and fraction of token amounts differ, so "fraction of the position" has two defensible readings. Test 1 states the invariant in liquidity terms ("B's fraction of the remaining liquidity", l. 86) and test 6 says only "Their fraction after the mint" (l. 91), which an implementer can read as token amounts. Two implementers therefore assert different quantities in the same-named test, and one of them can pass a test that does not prove the other's property. The PRD's own preamble that "apportioned value" means "the holder's fraction of the position" (l. 82) does not disambiguate the unit.
- **Fix direction:** State that the fraction invariant is a fraction of liquidity, and that token-amount fractions are explicitly not invariants (a move in price changes them).
- **Evidence class:** PRD source reading; V4 source reading for the three-slot liquidity model (`Repo` positions, `Inventory.principal`). Static reading.

### D4 — The redeem slice is "the position" in l. 51 but "that liquidity" in l. 53, and the idle sleeve is a live part of the position

- **Location:** PRD l. 51 ("Redeeming `s` shares removes only `s / S` of the position") against l. 53 ("Burn that slice. The tokens received are the actual target and other token in that liquidity at the current tick").
- **Invariant or requirement:** The exiting holder takes exactly their fraction; remaining holders keep theirs (l. 58).
- **Impact:** The V4 family intentionally holds idle balances outside the pool: the liquid-floor sleeve reserves a fraction of target as `local0`/`local1` and only the remainder is deployed (`Harvest.liquidFloor` l. 157, `Accounting.liquidTarget` l. 41). If the slice is liquidity-only, the exiting holder never receives any of the sleeve and the remaining holders absorb it; if the slice is position-wide, the exit must also pay out a pro-rata share of idle balances, which changes the target paid, the idle residual, and the counter debit. Nothing in the PRD says which, and l. 29 puts idle balances inside "the position".
- **Fix direction:** One sentence: state whether the redeem slice and the share basis include idle balances, and if not, say who owns the idle sleeve.
- **Evidence class:** PRD source reading; V4 source reading (`Harvest.liquidFloor`, `Accounting.liquidTarget`). Static reading.

### D5 — Entry swap sizing is "part of that deposit", and the single-sided-in-other-token case is uncovered

- **Location:** PRD l. 43 and l. 45; l. 24 ("A deposit adds liquidity in proportion to those existing positions"); l. 20 ("Do not hold only a single-sided target position").
- **Invariant or requirement:** A deposit adds liquidity in proportion to existing positions and opens no new range.
- **Impact:** "Part of that deposit" has no rule. Swapping a fixed fraction, swapping to match the existing composition, and swapping to match the existing liquidity mix are three different contracts with three different minted counts and three different resulting mixes. The proportional add also has an ordering problem the PRD does not address: the entry swap moves the price in a pool where the vault is itself the liquidity provider, so the composition measured before the swap and the composition after it differ, and "the position that existed before the add" (l. 43) is read differently depending on which side of the swap the implementer measures it. Finally, l. 45 covers the position being single-sided in target; a position single-sided in the other token is not covered, and the literal text (swap only "if the position is already two-sided") leaves that deposit adding target to an other-token-only position, which breaks proportionality.
- **Fix direction:** State the swap-sizing rule and the measurement order, and extend l. 45 to cover the single-sided-in-other-token case.
- **Evidence class:** PRD source reading; V4 source reading for the self-LP swap mechanics (`Common.execute`, `Harvest.place`). Static reading.

### D6 — The exit swap's execution mode, limit derivation, and residual handling are unspecified

- **Location:** PRD l. 54, l. 62 ("It does not use `MIN` or `MAX` as a price limit that ignores the slice. Slippage protection is the exiting holder's minimum target out.").
- **Invariant or requirement:** The exit sells only the slice's other token, at the pool's real price and fee, and reverts if the holder's minimum target is not met.
- **Impact:** The PRD rejects the `MIN`/`MAX` price limit used by the current code path (the V3 sibling's `_swap` uses `TickMath.MIN_SQRT_RATIO + 1` / `MAX_SQRT_RATIO - 1`, context; the V4 path's `_swapDeficit` uses `TickMath.MAX_SQRT_PRICE - 1` bounds, `Money` l. 219-238) but does not say what replaces it. Exact-input with a limit derived from `minimum`, exact-output, and exact-input with a post-check give different partial-fill behavior, different rounding, and different treatment of unsold other token. It is also unstated whether `minimum` is the total target paid or only the swap proceeds (see RQ6), and l. 62 says "the exit reverts and no shares are burned", which leaves the revert point and the burn order to the implementer (l. 53 burns liquidity first, l. 56 burns shares last).
- **Fix direction:** State the swap mode, how the price limit is derived from `minimum`, what happens to unsold other token, and that `minimum` covers the total target paid.
- **Evidence class:** PRD source reading; V4 source reading for the current bound-price swap (`Money` l. 219-238). Static reading.

### D7 — The V3 Wings family is mandated with no geometry, custody, interface, bootstrap, or locked-pool rule

- **Location:** PRD l. 8, l. 23, l. 82, and Non-goals (l. 96 onward); the accounting rules that a V3 implementation must satisfy are stated only for "the position" in the abstract (l. 29, l. 24).
- **Invariant or requirement:** "The accounting, entry, exit, and rate rules below apply independently to the Uniswap V3 Upper Lower Wings vault and the Uniswap V4 Upper Lower Wings vault" (l. 17), and the same test set runs on both (l. 82).
- **Impact:** The PRD states that no V3 Wings vault exists and that one must be built, then specifies none of it: not the ranges, not how many positions, not who owns the liquidity, not the function surface, not the first-deposit share count, not the locked-pool policy, not which V4-specific mechanics carry over (liquid floor, wing conversion at harvest, position import, the `liquidationValue` view). The shared test set presumes a "core and both wings" position shape (l. 24) that the V3 half never defines, so "one family passing does not close the other" (l. 6, l. 82) has no shared observable to transfer, and the V3 half cannot be implemented from this document at all. Separately, the still-in-force shared V3/V4 remediation PRD mandates the new V3 family use "the same V2-style constant-product/proportional-ownership model" (context), which APEX-012 does not say it supersedes; an implementer who follows that PRD would build a constant-product V3 vault and call it compliant.
- **Fix direction:** State the V3 position geometry and custody, the bootstrap share rule, and the locked-pool policy, and say explicitly that the apportioned accounting supersedes the constant-product mandate for this family.
- **Evidence class:** PRD source reading for the gap itself; the V3 family and shared-PRD observations are context read outside the admitted scope, flagged as such.

### D8 — "The V3 ban includes `slot0`" contradicts the exit rule that requires the current tick

- **Location:** PRD l. 18 ("On V3 that ban includes `slot0` and a simulated swap through the current book") against l. 53 ("The tokens received are the actual target and other token in that liquidity at the current tick") and l. 62 ("The swap uses the pool's real price and fee").
- **Invariant or requirement:** Deposit, redeem, and `getRate` must not be priced from the live book; the exit must nonetheless split the slice into its two token amounts at the current tick.
- **Impact:** On V3 the slice composition and the swap price both require reading the pool's current tick. A literal reading of l. 18 forbids any `slot0` read on the deposit/redeem path, which makes l. 53 and l. 62 unimplementable; a charitable reading forbids only valuation-by-tick, which is what the PRD intends. The two readings produce different V3 contracts, and the literal one is unbuildable.
- **Fix direction:** Restate l. 18 as a ban on valuation (deriving a price or a book value from the tick), explicitly permitting composition reads required to split a slice and to execute a real swap.
- **Evidence class:** PRD source reading. Static reading.

### D9 — The transition/quote layer still values the book with the banned quote, and the PRD never reconciles it

- **Location:** PRD l. 68 ("`getRate` and `quoteRate` read that counter and the supply"), l. 70 (`liquidationValue` "if it remains"), against the V4 projection the PRD does not mention: `Projection.value` l. 71-76 (`Quote.quoteInventoryAt`), `Projection.transition` l. 102 and l. 111 (`Accounting.issue` / `Accounting.entitlement` on that value), and the transition target's `quoteState`, `quoteTransition`, `quoteExternalDeposit`, `quoteExternalExchange`.
- **Invariant or requirement:** The money path must not use the whole-book quote; the vault's own query surface should not contradict it.
- **Impact:** The multi-asset transition surface prices the book with the same quote the PRD bans, so as written the vault would keep a second, quote-based valuation and expose predicted share counts and payouts that the new money path does not produce. The PRD offers three implementer choices with no guidance: rewrite the projection, leave it, or drop the transition facets. Each yields a different vault surface and different consumer behavior, and the PRD's test list (l. 86-94) contains no transition case, so nothing in the acceptance set would catch the inconsistency. The same applies to `liquidationValue`, whose "if it remains" leaves a quote-served view whose relationship to the new accounting is undefined.
- **Fix direction:** State whether the transition quoting surface is rewritten on the apportioned accounting, whether `liquidationValue` remains, and if so that it is explicitly a preview that never mints or burns.
- **Evidence class:** V4 source reading, PRD source reading. Static reading.

### D10 — `quoteRate`'s projected-state contract is redirected to a static counter without a decision

- **Location:** PRD l. 68; current implementation `EconomicTarget.quoteRate` l. 32-38 (decodes the supplied state and returns the projected book value), and the rate-provider and hook-leg consumers of that function (context).
- **Invariant or requirement:** `getRate` and `quoteRate` read the counter and the supply.
- **Impact:** `quoteRate(exchange, asset, state)` exists to answer "what is the rate after this projected transition". If it now returns a static counter over current supply, the projected argument is ignored and every consumer that asks for a post-transition rate gets a pre-transition number. The PRD does not say whether that is intended, whether the projected variant is kept, or which consumers are updated. The two answers differ in the vault's own code and in downstream rate reporting.
- **Fix direction:** State the projected-state semantics of `quoteRate` explicitly and list the consumers that must change with it.
- **Evidence class:** V4 source reading for the current semantics; the consumer impact is context read outside the admitted scope.

### D11 — Harvest's effect on the counter and on the share basis is underdetermined, and the harvest's own re-placement is unaddressed

- **Location:** PRD l. 22 and l. 66 (harvest rules), test 9 (l. 94); against `Harvest.harvest` / `Harvest.place` / `Harvest.close` and `Harvest.liquidFloor` (l. 157).
- **Invariant or requirement:** Harvest may credit target tokens actually collected, must not sell the other token, must not set the counter from a live reading of composition at the current tick, and must not change the share fraction.
- **Impact:** The current V4 harvest closes a converted wing and re-places the inventory, which changes deployed liquidity and the position's token content without any token moving to a holder. The PRD forbids selling the other token at harvest (already true of the current code: the harvest library never swaps) but is silent on whether a close/re-place changes `settledTarget` or the liquidity basis of every share. "Target tokens the vault actually collected" is also ambiguous between fees transferred into the idle balance and fee growth not yet collected. Separately, the PRD never says whether harvest is still allowed to re-range positions at all under the new accounting, nor whether the idle sleeve that the floor logic maintains is still a supported mechanism. These choices change the counter, the share fractions, and test 9's expected numbers.
- **Fix direction:** State that harvest changes the counter only by target fees actually collected, that a wing close/re-place changes neither the counter nor any holder's fraction, and whether re-ranging at harvest remains in scope.
- **Evidence class:** PRD source reading; V4 source reading (`Harvest.harvest`, `Harvest.place`, `Harvest.close`). Static reading.

## Limits

- Static reading only. No contract was compiled, no test was written or run, no script was simulated, no deployment or wallet operation occurred, and no file outside this owned response path was modified. Nothing here is runtime proof, and no finding asserts a runtime outcome.
- The primary evidence is the PRD text and the V4 Wings sources the PRD must change. The V3 FullSpread files, the V3 companion PRD, and the shared V3/V4 remediation PRD were read to test whether the V3 side is implementable; they are context, not authority, and the findings that use them (D7, and the V3 parts of D8) are constructed to hold from the PRD and the V4 sources alone.
- The tracker was read in full rather than only in its APEX-2026-012 section; only that section is treated as admitted context, and no finding depends on the tracker's other sections.
- I did not read any peer response, feedback file, the coordinator's draft or resolution, `RUN.md`'s run record content, or the eventual final artifact, and I did not launch sub-agents.
- I did not evaluate whether the apportioned-reserve accounting is the right product design; the question was clarity and implementability, and no alternative economics is proposed here.
- The defect list is what a single careful reader found by static reading; it is not a claim that the list is complete. Requirements questions RQ1 through RQ10 are the ones whose two answers change the contract, the tests, or the vault's behavior; smaller stylistic ambiguities are left out by design.
