# Advisory feedback - member minimax

## Identity

- Run ID: `se-fullspread-blockers-resolutions-20261103`
- Draft reviewed: `docs/research/se-fullspread-blockers-resolutions-20261103/coordinator/draft.md`, ID `draft-se-fullspread-blockers-resolutions-20261103-r1`
- Fingerprint: not computed. I did not compute a hash.
- Phase: advisory, continuing this MiniMax member conversation
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth
- Runtime identity beyond the requested string: not exposed, and not written here
- Peers read before submission: no
- Owned path written: `members/minimax/feedback.md`

## Disposition

**requested-changes**

Ten of the fifteen sections state my proposal accurately and I support them as written: F2, F3, F4, F5, F8, F10, F12, F13, F14, F15. Two sections state my position accurately but do not adopt it, and I accept the non-adoption on the merits with one correction each: F6 and F11. Three sections need correction before the owner sees them, because the sentence as written still leaves two implementors diverging: F1, F6, and F7, plus F9 for an omission and F11 for a contradiction.

This advisory does not treat the draft as an owner lock, does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.

## Does the draft state my proposal accurately

| Section | Accurate? | Note |
| --- | --- | --- |
| F1 | No | The draft and the "Preserved disagreements" table misdescribe my sentence. Correction C1. |
| F2 | Yes | Matches, including the pass-through exclusion. |
| F3 | Yes | More precise than mine: it says not to call `modifyLiquidity` when the deposit would add no liquidity. I accept that. |
| F4 | Yes | Same figure, and it adds the exclusion of booked balances. |
| F5 | Yes | Same sizing rule; the "about half" retirement is stated for both paths. |
| F6 | Yes | "MiniMax proposed booking it and is not recorded as support" is accurate. Correction C2. |
| F7 | Yes | "MiniMax would also emit for a donation-only deploy and is not recorded as support" is accurate. Correction C3. |
| F8 | Yes | Same reading. |
| F9 | Yes | Accurate as far as the absence row goes. Omission O1. |
| F10 | Yes | Same signature. The Evidence gaps bullet about my claim can now be closed. |
| F11 | Yes | "MiniMax named `exchangeIn` and the four reverting routes, and did not name the exit" is accurate; I accept the inclusion. Correction C4. |
| F12 | Yes | Same, including the zero case and the operator branch. |
| F13 | Yes | Same two names. |
| F14 | Yes | Same four sentences named. |
| F15 | Yes | Same completion rule. |

## Corrections, by draft section

### C1 - F1 section: the branch outcome, the preview, the route scope, and my proposal's description

**What the draft says.** "After the no-bytecode check and before any pull or use, snapshot each pretransferred input's unbooked balance. If any declared maximum exceeds its snapshot, process no leg, use no token, pull no shortfall, and refund that snapshot to the payer in the provided token. Previews and minimums follow that branch. Undeclared balances stay. The within-maximum case is unchanged: refund the maximum minus the amount used, and leave the rest." The attribution line reads: "MiniMax's sentence can be read as processing up to the snapshot and refunding only what was not used. That reading is not adopted, because a refund of the unbooked balance cannot be funded after part of it has been used."

**What I withdraw.** The economic objection. The shared Standard Exchange interface states, in the `pretransferred` parameter doc for `exchangeIn` (`lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56`): "The declared input is processed only when present unbooked input covers it." That is the Standard Exchange family's own rule for a declared input the unbooked balance does not cover, and it supports the draft's "process no leg" branch over my reading. I also accept that the draft's branch is the only one the directive's literal sentence can express without inventing a partial-processing rule.

**What the draft gets wrong about my proposal.** My sentence is not "processing up to the snapshot and refunding only what was not used". It states two branches: the within-maximum branch refunds the declared maximum minus the amount used and leaves the rest staged, which is the branch the draft adopts verbatim, and the overstated branch refunds the whole snapshot that the call did not use and never pulls the shortfall. The draft's stated reason, that a refund of the unbooked balance cannot be funded after part of it has been used, applies to neither branch: the draft's branch uses nothing, and my branch refunds only the unconsumed part. As written, the F1 section and the "Preserved disagreements" table record my position as something I did not propose, and the owner would read it that way.

**What the sentence still leaves open.** Three things, each of which is a divergence:

1. The outcome of the call in that branch is not named. "Process no leg, use no token, pull no shortfall, and refund that snapshot" describes a returning call, but a deposit that processes no leg produces no shares, and it is not stated whether the call returns with zero output or reverts. A reverting call cannot refund anything, because the refund reverts with it, and a staged pretransfer would then be stranded in the vault with no reclaim path. That is the case the directive's refund sentence exists for.
2. "Previews and minimums follow that branch" is not implementable as written. The accepted preview `previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)` (`lib/crane/contracts/interfaces/IStandardExchangeIn.sol:45-48`) carries no `pretransferred` input, and the staged balance is the caller's, not the vault's, so a preview cannot know the branch will apply. Read literally, the sentence would make every ordinary preview report a branch that only applies to a staged pretransfer.
3. The branch is not carried to the routes the review required. The r2 finding states that the chosen branch "has to cover a pretransferred donation and any bundle leg that admits pretransfer", and that copying only the B-13 echo drops the directive's staging sentence and its swap-shape sentence, which stay in force because B-13 incorporates the directive.

**Correction.** Replace the F1 sentence with:

> After the no-bytecode check and before any pull or use, snapshot each pretransferred input's unbooked balance. If any declared maximum exceeds its snapshot, the call processes no leg and burns no shares: it pulls no shortfall, refunds that snapshot to the payer in the provided token, and returns without processing, so a staged pretransfer is not stranded; the caller's minimum-out check still applies to the zero output and reverts with the family's minimum error when one is set; the previews report the ordinary pull case, because the accepted preview carries no `pretransferred` input and the branch is an execution-time fact enforced by that minimum check; the within-maximum case is unchanged: refund the maximum minus the amount used, in the provided token, and leave the rest staged; this branch applies on every route that accepts `pretransferred`, including a pretransferred donation and any bundle leg that admits it, and the directive's staging sentence and swap-shape sentence stay in force.

And correct the attribution line and the "Preserved disagreements" row to state my proposal as the two-branch sentence it is, with the note that the draft's branch is adopted on the strength of the shared interface's "processed only when present unbooked input covers it" and not on the ground given.

**Rejected alternative for the call outcome.** Revert instead of returning: the refund reverts with the transaction, so a staged pretransfer is stranded in the vault, and the directive's refund sentence would have no effect in the only case it names.

### C2 - F6 section: the revert needs its error

**What the draft says.** "The no-leftover-shortfall-revert sentence removes only the former sleeve top-up. A one-token exit must convert all unwanted withdrawn principal into the selected token or revert without burning shares. It does not pay, book, or abandon that residual."

**What I accept.** The branch, not the alternative. My proposal booked the residual, and the draft's revert is better for the exiting holder: under my proposal the unconverted unwanted token lands in a booked remainder that only the owner or an operator can deploy, so a holder who is not the operator strands a slice of their own principal in a place they cannot redeem it. The revert keeps the holder whole and leaves them free to exit again or take the bundle route. I withdraw my proposal on this point.

**What the sentence still leaves open.** It names a revert and no error. The PRD already names the exit's minimum failures (`AmountOutNotMet` and `MinAmountNotMet`, FS-OWN-30), and the family has no other error for "the exit could not deliver the selected token", so an implementor must either reuse a minimum error for a condition that is not the minimum check, or declare a new error the locks never authorized. That is exactly the divergence the F6 question exists to close.

**Correction.** Add to the F6 sentence:

> A one-token exit must convert all unwanted withdrawn principal into the selected token or revert without burning shares, and that revert uses the family's existing exit minimum error, `AmountOutNotMet`, with no new error declared for it; the caller's own minimum check still reverts `MinAmountNotMet` or `AmountOutNotMet` when the delivered amount is below it; it does not pay, book, or abandon that residual.

**One trade-off the owner should see, in one line.** A thin pool can leave a residual that makes the one-token exit revert where the booked-residual branch would have completed, so this branch trades exit liveness for keeping the holder's principal whole.

### C3 - F7 section: the predicate is not computable, and the rationale is only half replaced

**What the draft says.** "Emit the no-argument `Compounded()` once when `donate` or `compound` adds positive liquidity and the processed balance included a collected or previously booked fee. Do not emit for a donation-only deploy, for zero liquidity added, or for a call that compounds no fees. Do not add fields. Do not name a donation event. `ModifyLiquidity` does not carry the token amounts, so it is not the amount record." And: "Astra's fee-origin counters are not adopted. They are a new store the locks do not have."

**The contradiction.** The predicate turns on knowing that the processed balance "included a ... previously booked fee". The locked booking rule keeps one booked counter, and the booking sentence "Book the actual held balance after the deposit, not a calculated leftover" books a donation, a stray transfer, and a withdrawal's collected fees into the same balance. After a withdrawal collects the fees, the position's unpaid-fee read is zero, because `Position.update` advances the fee-growth accumulators on every modification (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:101-102`), and the `State` struct at line 20 carries no owed-token fields. Nothing in the locked state distinguishes a previously booked fee from a previously booked donation. So the "previously booked fee" case of the predicate cannot be computed, and the only thing that makes it computable is the fee-origin store the draft rejects two sentences later. The draft cannot reject the store and require a predicate that needs it.

**Correction.** Either state a computable predicate, or state the store. The computable form, which keeps the owner's "fees are compounded into the reserve" wording for the case that matters and covers the previously-booked-fee case without a new store:

> Emit the no-argument `Compounded()` once when `donate` or `compound` adds positive liquidity and the call's own liquidity modification collected a nonzero fee amount, which the vault reads as the position's fee-owed amount before that modification; do not emit for a donation-only deploy, for zero liquidity added, for a call that compounds no fees, or for a call that adds liquidity without collecting a fee; do not add fields and do not name a donation event; `ModifyLiquidity` does not carry the token amounts, so it is not the amount record, and the amounts are read off-chain from the PoolManager's `Swap` event and the position's token-amount and fee-owed reads.

If the owner instead wants the previously-booked-fee case to emit, the sentence has to say that the vault keeps the collected fees distinguishable from the rest of the booked balance, and that is a new store and has to be authorized as one.

**The rationale, one line.** The draft replaces the false rationale with a negative statement only. The r2 finding asked for a rationale that is true, and the PRD pass needs the positive half as well: the amounts are readable off-chain from the PoolManager's `Swap` event and the position's token-amount and fee-owed reads, which is why the event carries none.

### C4 - F11 section: the one-token exit is in the wrong group, and the selector is not named

**What the draft says.** "While the PoolManager is already unlocked, canonical `exchangeIn` may proceed, including a share mint, an underlying-to-underlying pass-through, and a one-token exit. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`."

**The problem.** A one-token exit is a redemption, not an `exchangeIn`, so listing it inside the `exchangeIn` group is wrong on its face, and the only redemption selector the PRD's money facet installs is `exchangeBundleOut` (`FS-FACET-01`), which the same sentence lists as reverting `ManagerAlreadyUnlocked`. The PRD's one-token exit is the single-token form of that redemption (`FS-A08`: "Single-token exit pays only the selected token or reverts"), and B-09 locks that "a one-token exit pulls the caller's deployed fraction and swaps only the withdrawn net, on that same open flag". So the sentence as written asks for two opposite behaviours from one selector and is not copyable, and an implementor has to guess whether the one-token exit is a distinct route or a single-token call of `exchangeBundleOut`.

**Correction.** Name the selector and the argument shape:

> While the PoolManager is already unlocked, canonical `exchangeIn` may proceed, including a share mint and an underlying-to-underlying pass-through, and the one-token exit proceeds on that same open flag as B-09 locks; the one-token exit is `exchangeBundleOut` called with a single output token, and that call is the exception to the rule below; `exchangeBundleInForSingleOut`, `exchangeBundleOut` with both output tokens, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`.

If the owner reads the one-token exit as a separate selector rather than a single-token `exchangeBundleOut`, the sentence must say so instead, because `exchangeBundleOut` and the one-token exit cannot both be "the same selector with one token and two tokens" and "one that reverts and one that proceeds" without the exception being written down.

## Omitted load-bearing parts, by draft section

**O1 - F9 section: the position getters' new home is not named.** The section replaces the FS-A01 absence assertion for `poolManager()` and family-only `poolKey()` and says those values are exposed by the Crane Protocol Aware facet and `UniswapV4SinglePositionAware`. It does not say where `positionLiquidity()`, `tickLower()`, and `tickUpper()` live, and FS-A01 does not assert their absence, so the absence row is not where that change lands. B-07 locks that the position getters are the `UniswapV4SinglePositionAware` pair and that no family-only selector is added on the full-spread query facet, and FS-OWN-06 puts the ticks in the Position Repo. A rewriter who only replaces the absence row can leave those three getters in the family query facet and still satisfy the F9 sentence, which is not what B-07 locks. The F9 sentence should add that `positionLiquidity()`, `tickLower()`, and `tickUpper()` are likewise served by `UniswapV4SinglePositionAware` and are not installed on the full-spread query facet.

**O2 - F2 section and Evidence gaps: the fee-delta evidence is available.** The draft's gap note says "Agreement on F2 is not proof that a deposit's liquidity change returns a fee delta." That evidence is in the local Uniswap V4 port and can be cited rather than left open: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:190` calls `position.update(...)` on every `modifyLiquidity` and line 193 returns the accrued fees as `feeDelta` whatever the sign of `liquidityDelta`; `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:120` folds them into the caller's single net delta (`callerDelta = principalDelta + feesAccrued`) and line 132 credits that net delta to the caller. The gap note should say the mechanic is read from source and still unexecuted by a fork test, rather than left as an open disagreement.

**O3 - F10 section and Evidence gaps: my claim is now verified.** The draft records that "MiniMax's claim that no shared interface declares `donate` was not re-read in this coordinator pass. It remains member-supplied." It is now checked: a search of all 151 files under `lib/crane/contracts/interfaces` returns no `donate` declaration, and the only `donate` declarations under `lib/crane/contracts` are Balancer V3 router and pool-cow functions, unrelated to the Standard Exchange. The sibling Standard Exchange family declares the same three-argument shape at `contracts/interfaces/detf/IDetf.sol:240`, `function donate(IERC20 token, uint256 amount, bool pretransferred) external;`, which supports the draft's sentence. The Evidence gaps bullet can be closed, and it is worth keeping the DETF citation in the F10 sentence because it is the existing family precedent for the signature.

## Where I accept the draft over my own proposal

Stated plainly, so the owner can weigh it:

- **F1, the branch.** The draft's "process no leg" is better grounded than my partial-processing reading, because the shared Standard Exchange interface says the declared input is processed only when present unbooked input covers it. I withdraw my objection to the branch and keep only C1.
- **F3, the zero-liquidity case.** The draft says not to call `modifyLiquidity` when the deposit would add no liquidity. Mine said only that such a deposit is not an error. The draft's form is more precise and avoids a zero-delta modification that would accrue the position's fees into a delta the call must then settle.
- **F6, the revert.** The revert keeps the exiting holder's principal whole, where my booked remainder strands a slice of it with only the owner or an operator able to deploy it. I withdraw my proposal and keep only C2.
- **F7, the intent.** The draft's fee-content predicate is closer to the owner's wording than mine. I keep only C3, which is that the draft's version needs a store it rejects, and I offer the computable alternative rather than my donation-only emission.
- **F11, the one-token exit.** The coordinator is right that B-09 already uses the open unlock for a borrowed one-token exit, and my sentence simply failed to name it. I keep only C4.

## Limits

- Static comparison of the coordinator draft against my own response, the admitted blockers file, and the admitted PRD. The draft was not edited, no owner lock is asserted here, and no implementation or PRD edit is authorized.
- No peer feedback was read, no sub-agent was launched, and no Forge, test, install, or Git operation was run.
- The fingerprint of the draft was not computed.
- The F2, F6, F7, and F10 points rest on reads of the local Uniswap V4 port and the shared Standard Exchange interfaces, cited by path and line in the text above; none of them was executed.
