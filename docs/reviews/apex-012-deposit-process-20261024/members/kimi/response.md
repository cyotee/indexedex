# Member response

## Identity

- Run ID: apex-012-deposit-process-20261024
- Member label: kimi
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-deposit-process-20261024/members/kimi/response.md
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Three questions, in order:

1. Why did the prior review treat a deposit as a sale of target for the other token, and does the existing Wings deposit process sell target?
2. If `Quote.quote` is removed from the share mint and the rest of the existing deposit sequence is kept, is that process valid under the preserved rulings?
3. If not, what is the smallest deposit process that is valid — without adding an entry swap unless a preserved ruling requires it?

Targets read:

- `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` (Entry section and ruling text)
- `contracts/.../upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` (`_deposit`, `_harvest`, `_place`, `_swapDeficit`, plus `_fund`/`_redeem` for reachability)
- `contracts/.../upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol` (header, `harvest`, `placement`, `place`, `_add`)
- `docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md`
- `docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md`
- `contracts/.../upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol` (`issue`)

## Evidence

What the code does (V4 Wings, current source):

- `Money._deposit` executes exactly this sequence: `_pull(assets_, pushed_)` (target in), bootstrap backing if supply is zero, `_harvest()`, `value = supply == 0 ? 0 : Quote.quote(Common.quoteRequest()).value`, `shares_ = Accounting.issue(supply, value, assets_)`, minimum/exact checks, `_changeTarget(assets_, true)`, `ERC20Repo._mint`, `_place()`, and a final nonzero-local-target check. No `Common.Kind.Swap` operation is constructed anywhere in this path.
- `Money._harvest` runs `Harvest.harvest(Harvest.snapshot())`; `Money._place` runs `Harvest.placement(Harvest.snapshot())`. Both execute the returned plan via `Common.execute`.
- `Harvest.sol` header: "Ordinary harvest never swaps. The plan contains exact manager mutations and a projected portfolio." In the body, `harvest`, `placement`, `close`, `place`, and `_add` emit only `Common.Kind.Modify` operations (remove liquidity, add liquidity). No swap is planned or executed.
- The only opposing-token sale in the vault is `Money._swapDeficit`. It is called only from `Money._fund`, and `_fund` is called only from `Money._redeem`. The deposit path cannot reach it.
- `Harvest.placement` -> `place` -> `_add(plan_, slot, geometry.<core|upper|lower>, floor)`: when `positions[slot].liquidity != 0`, `_add` replaces the geometry range with the existing position's range (`range_ = Types.Range(position.lower, position.upper, true)`). When `positions[slot].liquidity == 0` and supply is positive, `_add` keeps the fresh `Geometry.ranges(book.price, book.spacing)` range and, if affordable, appends a positive-delta `Modify` — opening a position at a new, current-tick-derived range.
- An empty slot while supply is positive is reachable: `_affordableLiquidity` returns 0 when tick-capacity room is 0 or local balances are insufficient, so a slot closed by harvest is not necessarily reopened by harvest's own `place`; the next deposit's `_place()` then has fresh target available and opens that slot at the current geometry range.
- `Accounting.issue(supply, value, credit)` is `supply == 0 ? credit : mulDiv(supply, credit, value)` — the mint is a pure ratio of supply, a value input, and the target credit. Any value source with the same units slots in without changing the equation's shape.

What the PRD and council record say:

- PRD Entry section: "If the position is already two-sided, the vault swaps part of that deposit into the other token against the same pool, then adds the resulting pair as liquidity. Shares are minted from the liquidity actually added against the position that existed before the add. The depositor does not receive a gift of other token that was already in the position."
- PRD Entry section: "A deposit adds liquidity in proportion to those existing positions. It does not open a new range."
- Prior council report (`REMEDIATION_PRD.md`), requirements question 1 (Counter): "After a deposit that spends some target in the entry swap, is `settledTarget` credited the gross deposit or the deposit net of target spent?" — the question is built on the entry swap. Question 4 (Entry swap) asks how much is swapped and from what the size is read.
- Open questions file, question 1, owner correction 2026-10-24: "a deposit does not sell target for the other token. This question is invalid while it assumes that sale. The existing deposit process is the reference unless a council shows that process is invalid under the preserved rulings."
- Preserved rulings (council report "Preserved owner rulings", restated in the open-questions preamble): other token is not sold by harvest or rebalance; a share is a fraction of every position the vault holds, including idle balances; a later deposit does not open a new range; `getRate`/`quoteRate` read the settled counter, not `slot0`; the remaining position may fill an exit sale; deployed vaults are not upgraded; a new V3 Wings family is built and V3 FullSpread is untouched.

## Assumptions

- "Quote.quote removed from the share mint" is read as: the `value` input to `Accounting.issue` is replaced by the settled-target counter the PRD defines (`settledTarget`), since the PRD names that counter as the only permitted rate basis. The shape of `issue` is unchanged.
- The first deposit (supply == 0) is exempt from "a later deposit does not open a new range" by that ruling's own wording; what opens the first ranges is open question 7 and is out of scope here.
- The PRD Entry sentence "the depositor does not receive a gift of other token that was already in the position" is treated as part of the still-open Mint question (open question 2), not as a preserved ruling: it appears in neither preserved-ruling list, and its enforcement mechanism in the PRD was the entry swap whose premise the owner rejected. The dilution it describes is noted under Limits, not counted as a violation.
- Whether deposit keeps calling `_harvest()` first is open question 8; harvest never swaps, so either answer does not change the conclusions.

## Coverage

- Read in full: the PRD, the open-questions file, the prior council report, `Money.sol`, `Harvest.sol`, `Accounting.sol`.
- Deposit path traced line by line; redeem path traced only far enough to establish that `_swapDeficit` is redeem-only.
- Not examined: V3 (no V3 Wings source exists), runtime behavior (no Forge run, per instruction), `Common.execute` internals beyond the operation kinds it is fed, peer responses (forbidden).

## Conclusions

**Q1 — Why the prior review treated a deposit as that sale, and whether the existing deposit sells target.**

The prior review took the sale from the PRD text, not from the code. The PRD Entry section prescribes an entry swap in so many words — "the vault swaps part of that deposit into the other token against the same pool" — and the council's Counter question ("after a deposit that spends some target in the entry swap, is `settledTarget` credited the gross deposit or the deposit net of target spent?") plus Entry-swap question 4 were built directly on that sentence. The 2026-10-24 owner correction rejected the premise and made the existing code the reference.

The existing Wings deposit does not sell target for the other token. Separating code from PRD: the code's deposit path (`pull -> harvest -> quote -> issue -> credit -> place`) contains no swap operation; harvest's own header states "ordinary harvest never swaps" and its planners emit only `Modify` operations; the sole opposing-token sale, `_swapDeficit`, is reachable only through `_fund`, which only `_redeem` calls. The PRD's Entry sentence describes a swap the code never performs. The prior review priced the PRD's sentence, not the vault.

**Q2 — Is the existing deposit sequence, minus `Quote.quote` in the mint, valid under the preserved rulings?**

No — one step violates a preserved ruling. The violation is not the mint and not a missing swap. It is `_place()`:

- Preserved ruling: "A later deposit does not open a new range" (council report preserved-rulings list; open-questions preamble; PRD Entry: "It does not open a new range").
- `_deposit` calls `_place()` unconditionally after the mint. `Harvest.placement` -> `_add` opens a position at a fresh `Geometry.ranges(price, spacing)` range for any slot whose liquidity is zero, and empty slots with positive supply are reachable (capacity or balance starvation after a harvest close).
- So a later deposit can open a new, current-tick-derived range. That is exactly what the ruling forbids.

Everything else in the sequence passes the preserved rulings: no other-token sale anywhere in the path (ruling: harvest does not sell); mint from `settledTarget` gives every holder `shares / supply` of every position including idle (fraction ruling); a counter-based mint makes shares independent of temporary external liquidity (PRD Entry, test 3); replacing the quote with the counter satisfies the `getRate`/no-`slot0` ruling on the deposit side. Minting before placement is also the right order under a counter-based mint: the mint no longer needs to measure liquidity added, so the "shares follow liquidity actually added" versus "same shares with or without temporary liquidity" conflict does not arise on this path.

**Q3 — The smallest valid deposit process.**

Keep the existing sequence with two changes, neither of which is a swap:

1. Mint from the settled counter: `shares = Accounting.issue(supply, settledTarget, assets)`, i.e. `supply == 0 ? assets : mulDiv(supply, assets, settledTarget)`; then credit the counter, `settledTarget += assets`, at the end of deposit (the PRD rate-checkpoint rule). The depositor's fraction of every position, including idle, is `shares / newSupply`.
2. Restrict `_place()` during deposit to slots that already hold liquidity, adding only to those existing ranges; skip empty slots and leave the unplaced target idle. Idle target is already part of the position under the fraction ruling, so skipping costs no holder anything. First-deposit range opening stays as it is today, pending open question 7.

No entry swap is added. No preserved ruling requires one: the only violation found is the new-range opening, and its fix is to not open the range. The PRD's entry swap existed to prevent a gift of pre-existing other token to the depositor; with the swap premise rejected, that concern belongs to open question 2 (Mint), not to this process.

## Review findings

**Finding 1 — Deposit placement opens a new range for an empty slot while supply is positive.**

- Location: `UniswapV4UpperLowerWingsStandardExchangeVaultMoney._deposit` (unconditional `_place()` after the mint) -> `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.placement` -> `place` -> `_add`, where a slot with `position.liquidity == 0` keeps the `Geometry.ranges(book.price, book.spacing)` range and appends a positive-delta `Modify`.
- Ruling: "A later deposit does not open a new range" (preserved owner ruling, council report and open-questions preamble; PRD Entry: "A deposit adds liquidity in proportion to those existing positions. It does not open a new range.").
- Impact: a deposit arriving while any of the three slots is empty (reachable after a harvest close whose `place` could not reopen the slot for capacity or balance reasons) opens a fresh range keyed to the current tick. The deposit no longer adds only to the positions that existed before the call, so the new holder's claim is not a pure fraction of the pre-existing position, and the deposited target is deployed by a current-tick read the accounting rulings otherwise keep off the money path.
- Smallest valid deposit process: pull target -> harvest (unchanged; it never swaps) -> mint `shares = supply == 0 ? assets : mulDiv(supply, assets, settledTarget)` -> credit `settledTarget += assets` and mint -> place only into slots with existing liquidity, using those positions' existing ranges; skip empty slots and leave the residual target idle -> existing nonzero-local-target floor. No entry swap; the named ruling is fixed by skipping the empty slot, not by converting anything.

## Limits

- Static reading only; no Forge run, per the instruction. Reachability of the empty-slot state is argued from `_affordableLiquidity`'s zero-liquidity returns and the harvest close/place flow, not demonstrated on chain.
- A counter-based mint while the position holds unsold other token dilutes old holders' claim on that other token (their target claim is exact; their other-token fraction shrinks). I did not count this as a violation because the no-gift sentence is not in either preserved-ruling list and its PRD remedy was the rejected swap; it is the substance of open question 2 and must be settled there.
- V3 was not assessed; no V3 Wings source exists.
- The Counter-question sub-questions (counter clearing at zero supply, debit overflow, LP-fee credit on the vault's own swap) remain open and are not answered here; the deposit process above touches only the deposit-side credit rule the PRD already states (target deposits move the counter).
