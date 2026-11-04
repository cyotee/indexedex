# Member response - minimax

## Identity

- Run ID: `se-fullspread-blockers-resolutions-20261103`
- Profile: research
- Council kind: full
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth
- Runtime identity beyond the requested string: not exposed, and not written here
- Peers read before submission: no
- Owned path written: `members/minimax/response.md`
- Authority of this file: advice only. It locks nothing, it does not authorize implementation, and it does not authorize a PRD edit.

## Question and scope

For each open finding F1 through F15 in `docs/reviews/se-fullspread-blockers-review-r2-20261102/REMEDIATION_PRD.md`, what one sentence should be locked so two implementors would not diverge.

Each entry below gives one recommended sentence, ready to paste into the blockers file and then into the single PRD pass. Where I rejected an alternative, it is named in one line with the reason. Observation is separated from inference: the "Observation" lines are what I read in the admitted files or in the repository, and the "Inference" lines are what I conclude from them.

No owner lock is reversed here. The sleeve stays dropped, the fee stays taken from new shares and clamped at 30%, a pass-through takes no fee, shares stay raw liquidity, a both-token maintenance call does not swap, the quote stays the mathematical result, `PkgInit.wrappedNative` stays removed, the owner stays set at initialization to `feeTo()`, and an overstated maximum does not pull a shortfall.

## Sources read

- `docs/research/se-fullspread-blockers-resolutions-20261103/brief.md`
- `docs/reviews/se-fullspread-blockers-review-r2-20261102/REMEDIATION_PRD.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- `docs/vaults/PRETRANSFER_DIRECTIVE.md`
- Repository confirmations for citations these proposals depend on: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`, `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `contracts/interfaces/detf/IDetf.sol`.

Not read: any member response or feedback file under `docs/reviews/se-fullspread-blockers-review-r2-20261102/members/` or `docs/reviews/se-fullspread-blockers-review-20261102/`.

---

## F1. Overstated pretransfer maximum: the missing snapshot and execution branch

**Location.** B-13, and the same words in `docs/vaults/PRETRANSFER_DIRECTIVE.md`.

**Observation.** B-13 locks: "If the maximum is larger than the unbooked balance, refund the unbooked balance. Do not refund maximum minus used in that case, and do not pull the shortfall." The already-locked list also says "A pretransfer uses the unbooked held balance up to the caller's maximum." The directive adds the staging sentence ("That balance may be staged for another call. The vault has no instruction to process it.") and the swap-shape sentence ("The swap is shaped so a remainder of the call is in the token the caller provided."). No sentence names the amount consumed before the refund is computed, the recipient, or the preview branch.

**Recommended sentence.**

> A pretransfer call snapshots the unbooked held balance of the provided token at entry and is credited with the lesser of the caller's declared maximum and that snapshot; when the declared maximum is within the snapshot the refund is the declared maximum minus the amount used, in the provided token, to the payer, and the remainder of the snapshot stays staged; when the declared maximum is larger than the snapshot the refund is the whole snapshot that the call did not use, in the provided token, to the payer, and the vault never pulls the shortfall; the same snapshot, credit, and refund arithmetic is used in the previews and in the minimum-amount checks, and the directive's staging sentence and swap-shape sentence stay in force on every route that accepts `pretransferred`, including a pretransferred donation and any bundle leg that admits it.

**Inference.** The owner's two clauses survive intact: an overstated maximum never pulls a shortfall, and the refund in that branch is the unbooked balance that the call did not use, which is the whole unbooked balance when the call consumed none of it. What the sentence lacked was the amount used and the funding constraint: once any of the unbooked balance is consumed, refunding all of it cannot be funded from that balance, so the refund has to be the unconsumed part. Two implementors reading the same sentence today can therefore differ on the input the call receives.

**Rejected alternative.** Return the entire unbooked balance and consume none of it: it leaves the call with no credited input, and it is the branch the funding constraint rules out.

## F2. Whether a liquidity-adding user route collects fees, and what it does with them

**Location.** B-02 ("A deposit, a withdrawal, and `exchangeIn` do not call `compound()`") and the booking section ("A withdrawal's `modifyLiquidity` collects fees. Book those fees.").

**Observation.** The blockers file states collection for the withdrawal path only. The repository settles the mechanical question: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:190` calls `position.update(...)` on every `modifyLiquidity`, and line 193 returns the accrued fees as `feeDelta` regardless of the sign of `liquidityDelta`; `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:120` folds them into the caller's single net delta (`callerDelta = principalDelta + feesAccrued`) and line 132 credits that net delta to the caller; `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:77-102` computes the fees from the pre-update liquidity and advances `feeGrowthInside0LastX128` and `feeGrowthInside1LastX128` on every call, and the `State` struct at line 20 has no owed-token fields, so the accrual cannot be deferred to a later read.

**Recommended sentence.**

> A deposit, a bundle deposit, and a share-minting `exchangeIn` each collect the position's accrued fees when they modify the position, and the disposition is the one the withdrawal already has: the collected fees are booked as a local remainder under the booking rule, they are not credited to the depositor, not refunded to the payer, and not part of the share credit; none of those routes calls `compound()` or deploys the booked remainder, and an underlying-to-underlying `exchangeIn` does not modify the position and therefore collects nothing.

**Inference.** The fee accrual on a liquidity-increasing modification is unavoidable, so "does not call `compound()`" cannot stand in for a fee sentence, and "leave them unpaid" is not available because the fee growth advances at the deposit itself. Booking the collected fees is the only disposition consistent with the existing booking rule, which already books a withdrawal's collected fees and forbids a user route from deploying or swapping a booked remainder.

**Rejected alternative.** "The deposit does not collect fees, so the fee state is untouched": it contradicts `Pool.sol:190` and `Position.sol:101-102`, which show the accrual happening on the deposit whether the vault intends it or not.

## F3. One booked total, and the zero-added-liquidity outcome

**Location.** Booking section: the excess sentence, then "Book the actual held balance after the deposit, not a calculated leftover."

**Observation.** The section contains two assignment sentences: one that books the excess of the other token after the matched pair is deposited, and one that books the actual held balance after the deposit. Nothing says which one is the total, and nothing says what happens when the permitted deposit adds no liquidity. The same section locks "A failed step reverts", "Do not invent an extra attempt, a fallback, or a swallowed failure to force a cleaner result", and "A remainder of that simplest deposit is booked."

**Recommended sentence.**

> The booked total after a `donate()` or a `compound()` is the actual token balance the vault holds after the deposit, read at that point, so the excess sentence describes the matched pair and is not a second booking step and is not added to that total; a deposit that succeeds but adds no liquidity is not an error: the call books the actual held balances and returns, it makes no further attempt, and it does not swallow a failed step, because a step that fails reverts the call.

**Inference.** The later sentence is the one that is consistent with the locked rule that a stray transfer is booked and with the directive's staged balances, so it governs the total and the earlier sentence is read as describing the matched pair. The zero-liquidity case has to be named because "exact exhaustion" reads both as a required result and as a sizing target, and the lock already says a failed step reverts, so the only remaining outcome for a successful but empty deposit is to book and return.

**Rejected alternative.** Keep the excess sentence as a second assignment and add it to the actual balance: it double-counts the booked remainder and contradicts the locked sentence that books the actual held balance.

## F4. The one figure that "the position ratio" names

**Location.** Booking section: "swap toward the position's ratio" and "the proportionally smaller amount relative to the position ratio".

**Observation.** The same phrase is used for two decisions: choosing the scarcer token and sizing the balancing swap. The blockers file does not define the figure. FS-OWN-33 in the PRD uses a different phrase for the deposit target, "so the deposit matches the pool ratio".

**Recommended sentence.**

> The position ratio is one figure: the ratio of the two token amounts per unit of liquidity implied by the PoolManager's current square-root price, and it is the figure used both to pick the scarcer token in a both-token booking and as the target of the one-token balancing swap; the deployed position's token amounts and its unpaid fees are not that figure and are not used to pick the scarcer token.

**Inference.** The swap executes at the pool's price, so a target taken from the position's stored amounts plus its asymmetric unpaid fees could not be the same figure as the price the swap actually gets, and two implementors reading "position amounts" and "position amounts plus unpaid fees" would pick different scarcer tokens. The full-range position's own ratio and the pool ratio coincide apart from fees, which is why the fees have to be excluded rather than the position.

**Rejected alternative.** Use the deployed position's token amounts plus its unpaid fees: it makes the swap target differ from the price the swap executes at, so the two decisions could pick different tokens.

## F5. The one-token swap size, and whether "about half" survives

**Location.** Booking section ("One token: swap toward the position's ratio, as a one-sided user deposit does") and PRD FS-OWN-33 ("A one-sided share mint swaps about half of the excess through the pool so the deposit matches the pool ratio.").

**Observation.** The booking lock defines the maintenance swap by reference to the user deposit, so the size has to be the same rule on both or the maintenance path is undefined. FS-OWN-33 says "about half of the excess" without naming the excess or a computable amount. The booking rule adds that the remainder must be in the token being processed.

**Recommended sentence.**

> The one-token balancing swap is sized by the target pair and not by a fixed fraction: the vault swaps the amount of the processed token that the ratio requires to leave the deposited pair at the position ratio, which in the frictionless case is half of the processed token's declared amount, and it books the processed-token amount the swap leaves over, because that amount is the remainder the directive's swap shape puts in the token the caller provided; "about half of the excess" is retired as a sizing rule because it names no computable amount, and the same sizing rule governs the one-token maintenance path, which the booking lock defines as "as a one-sided user deposit does".

**Inference.** The invariant the locks actually carry is the deposited pair's ratio, and that invariant is what an implementor can compute and test. "About half" cannot be tested and two implementors will read it differently, so it has to be retired rather than carried forward; because the maintenance path is defined by reference to the user deposit, the size cannot be pinned for one route and left open for the other.

**Rejected alternative.** Keep "about half of the excess" and define it as exactly half of the declared processed-token amount: it fixes the fraction but not the deposited pair's ratio, so the swap result and the remainder still differ between implementors, and it silently converts an owner sentence into a constant.

## F6. The one-token exit: scope the no-shortfall-revert sentence, and name the residual

**Location.** B-02 ("A redemption swaps only the withdrawn net") and the already-locked list ("A redemption on the vault's own unlock pays the principal fraction. Collected fees are booked and are not part of the swapped amount. It does not have a leftover shortfall revert.").

**Observation.** The no-revert sentence was written for the sleeve case, and the sleeve was dropped. FS-OWN-30 in the PRD names the surviving check: "A caller-set minimum still reverts `AmountOutNotMet` or `MinAmountNotMet`." The booking rule books a withdrawal's collected fees and says "Pay the caller only the principal fraction."

**Recommended sentence.**

> The no-leftover-shortfall-revert sentence covers the vault's inability to pull the exiting holder's full deployed fraction from the pool, and it does not cover the swap result: if the redemption swap does not convert the whole unwanted principal, the unconverted amount stays in the vault as a booked remainder and is not paid to the caller, and the caller's own minimum check still reverts `MinAmountNotMet` or `AmountOutNotMet` when the delivered amount falls short of it.

**Inference.** Scoping the sentence keeps the owner's lock intact for the case it was written for, and it removes the reading under which every shortfall revert in the exit path disappears. Booking the residual follows the rule the withdrawal path already uses for collected fees and keeps the exit from inventing a second local term.

**Rejected alternative.** Copy the no-revert sentence without its scope: it deletes the minimum-check revert on a one-token exit and lets an under-delivered exit succeed silently.

## F7. The `Compounded()` predicate and a rationale that is true

**Location.** B-11 ("Emit `Compounded()` with no fields when fees are compounded into the reserve. Amounts come from the PoolManager events."), and the booking section (`donate()` also compounds).

**Observation.** `PoolManager.sol:124` emits `ModifyLiquidity(id, msg.sender, tickLower, tickUpper, liquidityDelta, salt)`, which carries the liquidity delta and no token amounts, and `PoolManager.sol:190` emits the `Swap` event with its token amounts. `Position.sol:77-102` advances the fee-growth accumulators on every modification and stores no owed tokens, so the position's unpaid fees become zero once any route modifies the position. B-11 has no predicate for a call that deploys a booked remainder, a donation, a mixed balance, or one that adds no liquidity, and it does not say whether `donate()` emits.

**Recommended sentence.**

> `Compounded()` is emitted exactly once per maintenance call, `compound()` or `donate()`, that deploys idle balance into the deployed reserve by adding liquidity to the position, and it is not emitted by a deposit, a bundle deposit, a share-minting `exchangeIn`, or a withdrawal, because those collect fees and book them without deploying idle, it is not emitted when the call adds zero liquidity, and it is not emitted by a call with no fees, no donation, and no booked remainder; the empty signature is justified because the amounts are readable off-chain from the PoolManager's `Swap` event and the position's token-amount and fee-owed reads, `ModifyLiquidity` carries only the liquidity delta, and the vault therefore restates no amount and adds no field.

**Inference.** Deploying idle into the reserve is the one quantity the vault can observe without new state, and it resolves the four cases at once: a compound that redeploys previously booked fees, a donation-only deploy, and a mixed balance each emit once, while a call that adds zero liquidity does not. A fee-content predicate was considered and dropped, because once a withdrawal has collected the fees the position's unpaid-fee read is zero and the collected fees carry no tag in the single booked counter, so an implementor could not compute it. The amount rationale is replaced because `ModifyLiquidity` carries no token amounts, so the old sentence's stated source is false for every deposit that adds liquidity.

**Rejected alternative.** Emit only when the deployed balance is known to contain fees: after a withdrawal collects the fees there is no tag for them, so the predicate is not computable from the locked state.

## F8. The seven-address write: one storage home

**Location.** B-07 ("When the package initializes a vault instance, it writes those immutable addresses into the Uniswap V4 Protocol Aware Repo. The repo is not given a second per-vault copy of the addresses.").

**Observation.** "Second copy" can be read as forbidding the instance write the preceding sentence requires, or as forbidding a duplicate of the addresses somewhere else. B-07 also locks that the getters on that facet are externally callable on this vault and that the vault's own family query facet must not expose a family `poolManager()`.

**Recommended sentence.**

> The seven Uniswap V4 architecture addresses have exactly one storage home, the Uniswap V4 Protocol Aware Repo, written once when the package initializes the vault instance; the full-spread vault's own storage holds no copy of them, the position and protocol getters read the Crane pairs, and "no second copy" forbids a duplicate of the addresses in the vault's own repo or facet, not the initialization write.

**Inference.** The prohibition only has one purpose if it points at a duplicate in the vault's own storage, since the instance write is required by the sentence before it, and the getters are locked as externally callable, so a copy in the family facet is the thing that must not exist.

**Rejected alternative.** Read "no second copy" as forbidding the per-instance write into the aware repo: that contradicts the sentence immediately before it and would leave the facet's getters with nothing to read.

## F9. The selector row that FS-A01 still asserts

**Location.** B-07 (the Crane pairs serve the getters) against PRD FS-A01.

**Observation.** FS-A01 in the PRD reads: "`poolManager()`, family-only `poolKey()`, `rateAsset()`, `getRate()`, `basket()`, and every Standardized Yield selector are absent." B-07 locks that the Protocol Aware facet's getters are externally callable on this vault and that the position getters are the `UniswapV4SinglePositionAware` pair, which stores the pool key, the ticks, and the salt. FS-FACET-01's `queryFacet` row already says only that no family selector is installed.

**Recommended sentence.**

> FS-A01's selector-absence clause is restated by the pass as follows: `poolManager()`, `poolKey()`, `positionLiquidity()`, `tickLower()`, and `tickUpper()` are absent as full-spread family selectors on the query facet and are present as the externally callable getters of the Uniswap V4 Protocol Aware Facet and the Uniswap V4 SinglePositionAware Facet, which are package inputs on this vault, while `rateAsset()`, `getRate()`, `basket()`, and every Standardized Yield selector stay absent.

**Inference.** The locked policy is settled; what is missing is the row that carries it into the acceptance list, so this is a rewrite instruction and not a decision. The absence clause as written is about family selectors on the query facet, which is what the Crane pairs replace, and the row must say so or a rewriter copies a clause the lock has already superseded.

**Rejected alternative.** Leave FS-A01 as written: it asserts an absence the lock has already replaced, and a pass that edits only the cited IDs ships a PRD that contradicts B-07.

## F10. The `donate` signature that carries the pretransfer rule

**Location.** Booking section ("`donate()` also compounds. It uses tokens already transferred when `pretransferred` is set, and pulls the directed amount otherwise.") against `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` ("`donate(token, amount)` stays.").

**Observation.** The function review is dated 2026-10-30; the booking lock is dated 2026-11-02 and is the lock authority. The Standard Exchange convention carries the flag per route: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:20` has `bool pretransferred` in `InArgs` and line 66 as a route parameter. The sibling Standard Exchange family already declares a family-level donation with the flag: `contracts/interfaces/detf/IDetf.sol:240`, `function donate(IERC20 token, uint256 amount, bool pretransferred) external;`. No Crane Standard Exchange interface declares `donate`, so the route is a family route.

**Recommended sentence.**

> The `donate` route carries the pretransferred flag on its own parameter list, so its selector is `donate(IERC20 token, uint256 amount, bool pretransferred)` and the 2026-10-30 function-review line "`donate(token, amount)` stays" is replaced by it; the flag is not taken from a shared Standard Exchange argument struct, because `donate` is a family route that no shared interface declares, and the locked rule that `donate` uses already transferred tokens when `pretransferred` is set and otherwise pulls the directed amount is what the flag carries.

**Inference.** The booking lock postdates the function review and requires the flag, so the signature has to change rather than the rule; the sibling DETF donation already uses that exact parameter list, so this stays inside the Standard Exchange convention instead of inventing a family-specific shape.

**Rejected alternative.** Keep `donate(token, amount)` and read the pretransferred branch from somewhere else: the route has no parameter to carry the branch, so one implementor adds the flag and changes the selector while another has no input for the locked rule.

## F11. The batch-swap sentence: which routes it covers

**Location.** B-02 ("This vault can be included in a batch swap with other Uniswap V4 pools. That is not a revert. The earlier exclusion is removed. The borrowed-unlock path stays.") against PRD FS-A22 and FS-X01.

**Observation.** The PRD already names the borrowed-unlock scope: FS-X01 covers the canonical exact-input `exchangeIn`, and FS-UNLOCK-01 says `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` keep `ManagerAlreadyUnlocked()` on that path; FS-A22 asserts the same four routes revert. The blockers file removes the earlier exclusion without naming the routes, so copied as written the sentence can reopen FS-A22 for the bundle, donation, and compound routes or can be read as covering `exchangeIn` alone.

**Recommended sentence.**

> The batch-swap sentence covers the canonical exact-input route only: `exchangeIn` may execute while the PoolManager is unlocked by an outer batch swap and takes the borrowed-unlock path; `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` keep reverting `ManagerAlreadyUnlocked` while the manager is unlocked, so FS-A22 and FS-UNLOCK-01 survive unchanged.

**Inference.** The owner's sentence removed one exclusion and did not remove the others; naming the routes keeps the removal and keeps FS-A22's four routes intact, and the borrowed-unlock path the sentence points at is the `exchangeIn` path the PRD already defines.

**Rejected alternative.** Read the batch-swap sentence as covering every route: that would silently drop FS-A22's four `ManagerAlreadyUnlocked` reverts, which the owner never decided to remove.

## F12. The owner read at initialization: a stored value, and the zero case

**Location.** B-02 ("When a new proxy is initialized, set its owner to the address returned by `feeTo()` on the Vault Fee Oracle. That is the owner `onlyOwnerOrOperator` uses.").

**Observation.** The sentence is an instruction to write a value at initialization. It does not say whether a later change of `feeTo()` moves the owner, and it does not say what the owner is when `feeTo()` is `address(0)` at initialization. The same lock keeps operators authorized for `compound()` and `donate()`.

**Recommended sentence.**

> The owner is read from `feeTo()` once, at initialization, and stored on the new proxy; a later change of `feeTo()` does not move the stored owner and the vault never reads `feeTo()` again for authorization; if `feeTo()` is `address(0)` at initialization the stored owner is `address(0)`, the owner branch of `onlyOwnerOrOperator` then matches no caller, and the operator branch is unchanged.

**Inference.** "Set its owner to the address returned by `feeTo()`" is a write at initialization, so a live read on every call is a different instruction, and it is the one an implementor would otherwise write. Storing `address(0)` keeps the locked instruction intact and fails closed on the owner branch without adding a validation error the locks do not contain, and it leaves the operator path the owner authorized working.

**Rejected alternative.** Revert initialization when `feeTo()` is `address(0)`: that adds a validation error no lock names and makes a fee-less vault unusable.

## F13. Two names for two quantities

**Location.** B-10 ("The deployed reserve is one raw liquidity number") against B-06 ("`reserves()` wraps the deployed-reserve reads, which are token amounts plus unpaid fees").

**Observation.** The same phrase names the raw liquidity number that the share formulas use and the per-token amounts that the views return. The two are different quantities: the liquidity number is the share-mint and share-burn denominator, and the view returns the position's current token amounts plus unpaid fees.

**Recommended sentence.**

> The raw liquidity number is called deployed liquidity and is the denominator of the share mint and the share burn; the per-token amounts returned by `reserves()` and `reserveOfToken()` are called deployed token reserves and are the position's current token amounts plus unpaid fees; the two are different quantities, and no view returns the liquidity number as a token amount.

**Inference.** This is a naming instruction and not an economic choice: it keeps both locks and stops a rewriter from making `reserves()` return the liquidity number, which would break the view's stated unit.

**Rejected alternative.** Keep one name for both: the phrase then means whatever the rewriter needs it to mean in each sentence, which is how the two drifted apart in the first place.

## F14. The PRD sentences the no-compound lock removes

**Location.** B-02 ("A deposit, a withdrawal, and `exchangeIn` do not call `compound()`").

**Observation.** The lock's PRD line does not name the sentences it removes. Re-read in the PRD: FS-MONEY-01 says "`unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`" and "`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle"; FS-A11 says "Withdrawal includes pro-rata idle as in `_withdraw`... Compound harvests and reinvests before deposit and before withdrawal."; FS-A33 says "Borrowed execution uses the same compound and settlement as the locked path from the same economic state." A pass that edits only the cited IDs leaves all three standing.

**Recommended sentence.**

> The single PRD pass replaces the compound and pro-rata-idle sentences in FS-MONEY-01, FS-A11, and FS-A33 with the B-02 and booking locks: `unlockCallback` does not call `_compound` before a deposit or a withdrawal, a withdrawal pays only the exiting holder's principal fraction and books the fees its `modifyLiquidity` collected, and borrowed execution uses the same no-compound path as the locked path; no other sentence in the PRD re-enables a compound on a user route.

**Inference.** The lock is a removal, and a removal has to name what it removes, or the pass edits only the cited IDs and ships a PRD that still compounds before a deposit and still pays pro-rata idle. This sentence is a rewrite instruction and it does not answer the fee disposition in F2.

**Rejected alternative.** Rely on the cited IDs alone: the three sentences above are not among them and would survive the pass unchanged.

## F15. The 64-byte preview consumers are pass work

**Location.** B-08 ("The rate provider, and every other consumer of the old 32-byte return, must be updated to read that tuple. The single council PRD pass enumerates those consumers. This lock does not make that list.").

**Observation.** B-08 states that the pass enumerates the consumers and that this lock does not make the list. The blockers file's own instructions require the pass to enumerate every consumer of the old 32-byte preview return, because the accepted preview is now the 64-byte `(uint256 amountOut, uint256 amountRefunded)` tuple. The list itself does not exist in any admitted file.

**Recommended sentence.**

> The consumer list for the accepted 64-byte `(amountOut, amountRefunded)` preview return is enumerated by the single PRD pass and not by this lock: the pass names every consumer of the old 32-byte return, including the rate provider, and a rewrite is not complete until that list exists in the PRD; no consumer list is invented from the blockers file, and the missing list is not a gate before the pass starts.

**Inference.** The finding is right that two editors can invent different lists and each call the rewrite complete, and the fix is that the list is a named deliverable of the pass rather than something this lock has to supply. Naming it as a pass deliverable is what the file already says, so this sentence makes the completion condition explicit without inventing content.

**Rejected alternative.** Have this lock enumerate the consumers: the blockers file has no consumer list to enumerate, and any list written here would be an invention the pass could not check.

---

## Coverage

| Finding | Lock it belongs to | What the sentence adds |
| --- | --- | --- |
| F1 | B-13, directive | Snapshot, both refund branches, recipient, preview, scope to every pretransfer route |
| F2 | B-02, booking section | Deposit, bundle deposit, and share-minting `exchangeIn` collect and book; pass-through collects nothing |
| F3 | Booking section | One booked total; zero-added-liquidity outcome; no second attempt, no swallowed failure |
| F4 | Booking section | One figure, the pool price ratio, for both decisions |
| F5 | Booking section, FS-OWN-33 | One swap size; "about half" retired; same rule for maintenance |
| F6 | B-02, already-locked list | No-revert sentence scoped to the pull case; residual booked; minimum check survives |
| F7 | B-11 | One emission predicate for the four cases; true rationale; no field added |
| F8 | B-07 | One storage home; what "second" refers to |
| F9 | B-07 against FS-A01 | The selector row restated to match the lock |
| F10 | Booking section, function review | One `donate` signature carrying the flag |
| F11 | B-02 | Routes inside a batch swap, routes that still revert |
| F12 | B-02 | Owner written once; later `feeTo()` change; the zero case |
| F13 | B-10 against B-06 | Two names, two quantities |
| F14 | B-02 | The PRD sentences the lock removes, named |
| F15 | B-08 | The consumer list is a pass deliverable with a completion condition |

Every finding F1 through F15 has one recommended sentence. No finding is skipped, no menu is offered, and no locked owner sentence is reversed.

## Limits

- Static reading only. No Forge run, no test run, no install, no deploy, no Git operation, no sub-agent, and no peer response was read.
- The repository confirmations cited for F2, F7, and F10 are reads of the local sources listed above, not executions.
- The proposed sentences are advice until the owner accepts them. This file locks nothing, it authorizes no implementation, and it authorizes no PRD edit; the PRD pass and the blockers-file update remain the coordinator's and the owner's to make.
- F9 cites FS-A01 and F5 cites FS-OWN-33 from the current PRD revision `fullspread-se-prd-weir-align-r1`; both rows were read in this pass.
- The F2 and F7 sentences depend on the fee accrual behaviour of the local Uniswap V4 port, which was read but not executed; a fork test is still the proof.
