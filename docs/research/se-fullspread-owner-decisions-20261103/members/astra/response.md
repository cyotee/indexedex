# Independent assessment of the F1-F12 owner decisions

## Identity

- Member: astra.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime role, model, reasoning setting, and provider/account route: not exposed.
- Runtime task/session identity: not exposed as verified identity metadata.
- Context: fresh; no earlier conversation continued.
- Peers read before submission: no.

## Question and targets

For each owner decision on F1 through F12, is there a problem with the decision, and did the owner misunderstand the recommendation?

The comparison is between the verbatim owner responses in `docs/research/se-fullspread-owner-decisions-20261103/brief.md` and the full recommendation sentences in `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md`. Earlier locks are used to identify silent reversals, not to prevent an explicit new owner decision.

## Evidence

The following are source observations from this fresh pass:

- Read the complete brief and recommendation report. The report calls its sentences proposals, not existing owner locks. Its F6 expressly proposes narrowing the earlier no-shortfall-revert sentence.
- Read `docs/vaults/PRETRANSFER_DIRECTIVE.md` and the complete `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`. The latter's B-13 and donation/compound booking section distinguish unbooked pretransfer credit from booked balances; its B-11 ties `Compounded()` to deploying fees.
- Read `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:50-68`. Line 56 expressly permits consumption of unrecorded staged balances, excludes booked backing, and requires enough present unbooked input to cover the declaration.
- Read `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:45-179`, `libraries/Pool.sol:130-379,430-484`, `libraries/Position.sol:1-104`, and `libraries/SwapMath.sol:40-109` under that same V4 directory. These show fee realization on position modification, distinct swap/add amounts, partial swap completion at the price limit, and the already-unlocked entry checks.
- Read `lib/crane/contracts/access/operable/OperableRepo.sol`, `OperableTarget.sol`, and `lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol:1-140`. The operator mappings can be reused, but existing owner guards use stored ownership, including a guard inside the function-specific operator setter.

The conclusions below label reasoning beyond those observations as inference. These are static reads, not execution evidence.

## Assumptions

- An unqualified acceptance adopts the full report sentence, not merely the brief's short locator.
- A contradictory qualification cannot silently be discarded in favor of the opening acceptance. “Changed the recommendation: yes” can therefore describe an operative restatement that differs from the proposal even when the owner says they agree; it does not assert that the change was intentional.
- The 48% suggestion is a proposed algorithm to investigate, not an established mathematical result or an instruction to hardcode 48%.
- A missing implementation does not itself make a product decision defective. “Problem: yes” below identifies ambiguity, an incompatible protocol requirement, or an accepted sentence that remains unclear; it does not request implementation.

## Coverage

All twelve decisions are assessed separately. The principal misunderstandings are F1's transfer-notification reading, F2's conflation of collecting with compounding, and F6's application of deposit balancing to an exit. F5 also retains an amount-definition problem in the recommendation itself; that is not an owner misunderstanding. F7 intentionally changes the event rule but leaves its mixed-balance predicate unclear. F12 is an explicit policy change, not a misunderstanding or a silent reversal.

The PRD, prior member responses, current peers, and coordinator artifacts were not read. No new product choice is made for F13-F15.

## Conclusions

### F1. Pretransferred balance measurement

- **Misunderstood: yes.**
- **Problem: yes.**
- **Changed the recommendation: yes.**

**Source observation:** The report's F1 at `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md:21` measures each input's currently unbooked balance at call entry, before pulls or use. It does not request notification when a transfer happens, identify a previous sender, or assign balances to individual depositors. The owner's objection at `docs/research/se-fullspread-owner-decisions-20261103/brief.md:98` addresses those different mechanisms.

**Inference:** A call-entry measurement is not a new transfer standard. The owner may reject that implementation prescription, but the reason supplied misunderstands it. Accepting the risk that another caller uses a non-atomic pretransfer is consistent with the existing rule, not a new defect: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` already says unrecorded balances may be consumed by the next contract caller.

There are two different meanings of “overstates.” A caller who supplied 10 but declares 20 when 30 unbooked tokens are held has not exceeded the aggregate available balance. The recommendation does not protect the other 20 against that caller. A caller declaring 40 against that same 30 has exceeded aggregate availability. The existing refund/no-pull lock still covers the second case (`IMPLEMENTATION_PLAN_BLOCKERS.md:282-284` in the full-spread directory). The reply explains acceptance of the first case but rejects the proposed mechanism without clearly settling whole-call treatment of the second, particularly in a bundle.

**One missing fact:** When any declared pretransferred maximum exceeds the total available unbooked balance, is the entire call refund-only before any leg is processed? This is the still-unsettled branch, not a request for transfer attribution or a new token standard.

### F2. Fees during user operations

- **Misunderstood: yes.**
- **Problem: yes.**
- **Changed the recommendation: yes.**

**Source observation:** The accepted report sentence requires booking fees collected by an add without deploying them or crediting them to the caller (`REPORT.md:27`). The owner's restatement says fees are left untouched during every operation except donation and compound (`brief.md:102`).

The protocol does not offer an add/remove switch that leaves the same position's accrued fees untouched: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:108-120` combines the principal delta and accrued-fee delta. `libraries/Pool.sol:184-193` updates the position and returns its fees, and `libraries/Position.sol:92-102` calculates those fees and advances the fee-growth checkpoints. The existing withdrawal lock also explicitly requires booking collected fees (`IMPLEMENTATION_PLAN_BLOCKERS.md:256`).

**Inference:** Not calling `compound()` is compatible with collecting and parking fees. Literally leaving accrued fees uncollected during a liquidity modification is not the behavior of the protocol read. One implementor could interpret “untouched” as “not redeployed”; another could try to suppress collection or omit the required booking. The opening acceptance and its restatement therefore do not yet make one copyable instruction.

**One missing fact:** Does “untouched” mean “automatically collected fees are booked, but are not deployed, refunded, or credited to the user”? That would distinguish the accepted recommendation from the incompatible literal reading.

### F3. Booked total after maintenance

- **Misunderstood: no.**
- **Problem: no.**
- **Changed the recommendation: no.**

**Source observation:** The owner accepts the report's actual-held-balance rule, zero-add skip, and failure reversion without qualification (`brief.md:106`; `REPORT.md:33`). The prior booking lock already says to book the actual held balance rather than a calculated leftover (`IMPLEMENTATION_PLAN_BLOCKERS.md:254`).

**Inference:** This is copyable. The booked total is the final balance, not that balance added again to an earlier booked amount. Skipping a computed zero-sized add does not mean swallowing a failed nonzero operation.

**One missing fact:** None for this decision.

### F4. Position ratio

- **Misunderstood: no.**
- **Problem: no.**
- **Changed the recommendation: no.**

**Source observation:** The accepted sentence defines the ratio using current square-root price, stored ticks, and liquidity consumption, excluding fees and booked balances (`REPORT.md:39`; `brief.md:110`). The local add calculation reads current price and ticks and computes the corresponding token deltas (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:207-240`).

**Inference:** This gives implementors a common geometric reference rather than the ratio of arbitrary held balances. Reading it immediately before the proportional add also avoids treating a pre-swap ratio as necessarily the final add ratio.

**One missing fact:** None for this definition.

### F5. One-token swap sizing

- **Misunderstood: no.**
- **Problem: yes.**
- **Changed the recommendation: no.**

**Source observation:** The owner accepts F5 without qualification (`brief.md:114`). The full recommendation, unlike its short locator, says: “The swap input is the amount that add requires of the processed token” (`REPORT.md:43`). It also says to maximize the following integer liquidity and that the swap output is the other token consumed by the add.

The protocol calculates swap input, output, fees, and resulting price separately (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol:64-105`). The add then calculates token requirements at the resulting price and stored range (`libraries/Pool.sol:207-240`); the swap writes its resulting price at `libraries/Pool.sol:445`.

**Inference:** The objective is understandable, but the quoted amount identity is not generally the same objective. The processed token is spent in two places: the swap and the subsequent add. The swap's input cost is not generally equal to the processed-token amount consumed by that add. One implementor could enforce that literal equality; another could solve for the swap cost needed to acquire the add's required opposite-token output while retaining enough processed token for the add. Price movement and fees make those different calculations. This is a defect in the accepted recommendation's wording, not evidence that the owner misunderstood it.

**One missing fact:** Which quantity is meant by “the amount that add requires”: the opposite-token output to acquire, or the processed-token amount to spend on the swap? The sentence must identify that quantity without equating two distinct expenses.

### F6. Unconverted exit principal

- **Misunderstood: yes.**
- **Problem: yes.**
- **Changed the recommendation: yes.**

**Source observation:** F6 is about an exit: convert all unwanted withdrawn principal into the selected token or revert `AmountOutNotMet`, with rollback and no residual payment, booking, or abandonment (`REPORT.md:49-51`). The owner's acceptance instead explains sizing a swap to leave a provided-token remainder and suggests investigating 48% (`brief.md:118`).

V4 can stop a swap at its price limit with an amount still remaining (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:348-349`); the returned delta reflects the amount actually processed (`libraries/Pool.sol:457-466`).

**Inference:** The explanation describes a balancing swap before an add, which belongs to F5. An exit does not retain the unwanted token to pair with swap output in a later add. Intentionally swapping only a fraction of unwanted exit principal leaves exactly the residual F6 prohibits. The protocol's partial-fill possibility also means a proposed deposit-sizing algorithm does not eliminate the exit failure branch.

The statement is therefore changed as written, despite its opening acceptance. If the qualification was intended solely for F5, F6 could remain accepted unchanged; this assessment cannot silently relocate the qualification. Nor does the tentative 48% suggestion establish a new F5 algorithm.

**One missing fact:** Does the owner accept the all-unwanted-principal-or-`AmountOutNotMet` exit rule, with the remainder/48% discussion applying only to deposits and maintenance adds?

### F7. Compounding and donation events

- **Misunderstood: no.**
- **Problem: yes.**
- **Changed the recommendation: yes.**

**Source observation:** The report proposes an event conditioned on positive added liquidity and newly collected fees, excludes later deployment of previously booked fees, and expressly declines a donation event (`REPORT.md:55-57`). The owner instead identifies deployment as the trigger, includes deployment of booked tokens, and explicitly requests `Donation()` (`brief.md:122`). These are recognizable changes, not an apparent acceptance followed by an unrelated explanation.

However, the locked booking rule combines fees, donation remainders, and stray transfers; it books actual final balances (`IMPLEMENTATION_PLAN_BLOCKERS.md:250-254`). B-11 says `Compounded()` means fees were compounded, not merely that any maintenance liquidity was added (`IMPLEMENTATION_PLAN_BLOCKERS.md:234-240`).

**Inference:** Emitting for later deployment is feasible. The remaining problem is what qualifies as fees after balances have been combined. “Because we're depositing fees” and “when we deploy booked tokens” are not equivalent predicates under the current booking rule. One implementation could emit for deployment of a donation-only booked remainder; another could require evidence that some deployed amount originated as fees. The additional example mentioning collected fees must likewise not become an emission for collection alone when those fees remain booked.

The donation event is an intentional extension and is not a defect merely because the recommendation excluded it. I do not reinterpret the written `Donation()` as an unspecified demand for event arguments.

**One missing fact:** Does any positive deployment of booked tokens qualify for `Compounded()`, including booked tokens with no fee origin, or must a positive deployed fee-origin amount be identifiable? This assessment chooses neither rule and does not authorize a fee-origin store.

### F8. Seven-address initialization write

- **Misunderstood: no.**
- **Problem: no.**
- **Changed the recommendation: no.**

**Source observation:** The owner accepts the canonical instance initialization write (`brief.md:126`; `REPORT.md:61`). It retains package immutables and excludes an additional duplicate instance store, matching B-07's distinction between package bindings and instance initialization.

**Inference:** This removes the apparent contradiction between writing the Protocol Aware Repo and forbidding a second copy. The accepted storage rule is copyable; no new address source or storage location needs to be chosen.

**One missing fact:** None.

### F9. Getter ownership

- **Misunderstood: no.**
- **Problem: no.**
- **Changed the recommendation: no.**

**Source observation:** The owner accepts the assignment of the named selectors to Crane facets, the prohibition on family-only duplicates, and preservation of unrelated absence assertions (`brief.md:130`; `REPORT.md:65`). B-07 already specifies those facets and the single-position state.

**Inference:** This is a clear decision about selector ownership. It does not silently restore a sleeve getter or require a competing family implementation. I have not treated the planned facets as already implemented or tested.

**One missing fact:** None.

### F10. Donation signature

- **Misunderstood: no.**
- **Problem: no.**
- **Changed the recommendation: no.**

**Source observation:** The owner accepts the nonpayable three-argument signature, no return value, false-only share donation, and unchanged no-argument `compound()` (`brief.md:134`; `REPORT.md:69`).

**Inference:** The signature decision is copyable. A share donation's specific burn-only sentence governs that branch; the underlying-token pull sentence does not turn it into a transfer of shares to the vault. The accepted reference to F1 leaves pretransferred underlying donations dependent on F1's unresolved excess-maximum treatment. That dependency is not a second signature defect and is not silently resolved here.

**One missing fact:** None for the signature; the execution dependency is the single fact identified under F1.

### F11. Borrowed-unlock routes

- **Misunderstood: no.**
- **Problem: no.**
- **Changed the recommendation: no.**

**Source observation:** The report states the permitted borrowed `exchangeIn` paths, identifies single-output `exchangeBundleOut` as its assumed one-token exit, and lists the routes that remain rejected (`REPORT.md:75-77`). The owner accepts without naming a different selector (`brief.md:138`).

The manager checks whether the lock is open, not whether the current caller originally opened it (`lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:45-64`). Position modification uses `msg.sender` as position owner and accounts its delta to that caller (`PoolManager.sol:108-132`). Both modification and swap require the already-open flag (`PoolManager.sol:94-98,136-140`).

**Inference:** The accepted route matrix is compatible with the manager behavior read, provided the vault follows the stated borrowed path and settles its own deltas. Acceptance resolves the explicitly offered single-output-selector assumption; asking the owner to choose that selector again would invent an unanswered question. The exit's residual handling still depends on F6, not on a different unlock permission.

**One missing fact:** None for route admission; F6's separate exit-completion ambiguity remains.

### F12. Live `feeTo()` ownership

- **Misunderstood: no.**
- **Problem: no.**
- **Changed the recommendation: yes.**

**Source observation:** The owner explicitly says they reconsidered and wants owner controls to follow the currently configured `feeTo()`, with new ownership modifiers and reuse of Operable storage if possible (`brief.md:142`). This deliberately replaces the stored-owner/no-live-read proposal (`REPORT.md:81`); it is not a silent reversal.

`lib/crane/contracts/access/operable/OperableRepo.sol:29-35` stores global and function-level operator permissions separately from ownership. Its existing combined guard nevertheless reads `MultiStepOwnableRepo._owner()` (`OperableRepo.sol:211-217`). Its function-operator setter also performs a stored-owner check internally (`OperableRepo.sol:103-108`), and both public setters use `onlyOwner` (`OperableTarget.sol:47-70`). The underlying owner guard compares the caller with the stored owner (`lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol:108-121`).

**Inference:** The policy is implementable, and the requested new ownership integration acknowledges that it differs from the existing guard. Reusing the operator mappings is possible; reusing every existing guard and setter unchanged is not. In particular, changing only an outer modifier would leave the function-specific setter's internal stored-owner check in place. That is a concrete integration constraint, not a defect in the owner's live-ownership decision or a reason to retain the rejected initialization snapshot.

The reply does not decide an additional operator-reset policy when `feeTo()` changes. I do not invent one or call its absence a defect in the decision actually made.

**One missing fact:** None for the live-owner rule and reuse of global/function operator authorization; unchanged reuse of the stored-owner guards must not be mistaken for satisfying it.

F13-F15 were not decided; silence is not acceptance.

## Limits

This is an independent static assessment, not a protocol execution, proof of a swap-sizing algorithm, or implementation review. No Forge commands, tests, installs, Git operations, sub-agents, or peer-response reads were performed. Source reads were from the live local tree, not an atomic repository snapshot. No public search or private-source submission to a search service was needed.

Only the assigned Astra response file was written. The brief, run record, draft, PRD, blockers file, prior resolution report, and other members' files were not edited.

This response does not authorize implementation or a PRD edit.
