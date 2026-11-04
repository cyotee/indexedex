# Initial response

## Identity

- Member: grok
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Runtime identity not given in the assignment: not exposed
- Peers read before submission: no

## Question and targets

Question: for each open finding F1 through F15 in `docs/reviews/se-fullspread-blockers-review-r2-20261102/REMEDIATION_PRD.md`, what one sentence should be locked so two implementors would not diverge?

Targets read: that report's findings, and the whole of `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`. The blockers file is the lock authority.

Optional context read because a proposal cites it: `docs/vaults/PRETRANSFER_DIRECTIVE.md`; `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` in the full-spread directory; `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` in that directory. Repository reads used only to confirm a citation a sentence depends on are listed under Evidence.

These proposals do not authorize implementation, a PRD edit, or an owner lock. They do not replace the blockers file, the PRD, or the published review.

## Evidence

Observation, blockers file: the sleeve is dropped; the usage fee is taken from new shares and clamped at 30%; a pass-through takes no usage fee; shares are the raw liquidity number; a both-token `donate` or `compound` does not swap; the quote is the mathematical result; `PkgInit.wrappedNative` is removed; initialization sets the owner to `feeTo()`; an overstated maximum does not pull a shortfall. None of the sentences below reverse those locks.

Observation, directive: if the maximum is within the unbooked balance, the refund is that maximum minus the amount used, in the provided token, and the surplus above the maximum may be staged for another call, which the vault has no instruction to process. If the maximum is larger, refund the unbooked balance, do not refund maximum minus used, and do not pull the shortfall. The swap is shaped so a remainder of the call is in the token the caller provided. The vault does not ask where the tokens came from.

Observation, `IStandardExchangeInMulti`: the declared input is processed only when present unbooked input covers it; a difference between the declaration and the whole surplus does not by itself revert; tokens above the declaration are not refunded. `previewExchangeInManyToOne` has no `pretransferred` argument. Shared `previewExchangeIn` signatures read in this pass take token, amount, and token out, and no `pretransferred` argument.

Observation, `Pool.sol` lines 185-193 and `Position.sol` lines 88-99: `modifyLiquidity` calls `position.update` and returns `feesOwed` as `feeDelta` for a nonzero liquidity change as well as a zero change. `update` computes fees from the pre-update liquidity and writes the fee-growth checkpoint. A zero `liquidityDelta` on a position whose liquidity is already zero reverts `CannotUpdateEmptyPosition`. A positive delta on zero existing liquidity returns zero fees.

Observation, `IPoolManager.sol` lines 79-82: `ModifyLiquidity` carries pool id, sender, ticks, `liquidityDelta`, and salt. It carries no token amounts. `Swap` carries token amounts. A both-token maintenance call does not swap, so that event is not emitted for that call.

Observation, `WeirVaults.sol` lines 369-376 and 387-411: a computed liquidity of zero skips `modifyLiquidity`. `_balance` swaps half the value-excess of the larger token, and swaps nothing if that half rounds to zero. That is the source of the PRD's "about half." It is not a post-swap guarantee that the leftover is only in the input token.

Observation, PRD line 114: FS-OWN-33 says a one-sided share mint swaps about half of the excess so the deposit matches the pool ratio. The blockers file does not replace that sentence. It says a one-token maintenance swap goes toward the position's ratio, as a one-sided user deposit does, and that the remainder must be in the token being processed.

Observation, PRD lines 264-273, 403, and 425: FS-MONEY-01 says `unlockCallback` calls `_compound` before deposit and withdrawal, and `_withdraw` pays pro-rata idle. FS-A11 says withdrawal includes pro-rata idle and compound runs before deposit and withdrawal. FS-A33 says borrowed execution uses the same compound as the locked path.

Observation, PRD lines 130, 287, and 414: the already-unlocked path is permitted for canonical `exchangeIn`. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked`. FS-A20 says a borrowed `exchangeIn` that sets `pretransferred` reverts.

Observation, PRD line 393: FS-A01 asserts that `poolManager()`, family-only `poolKey()`, `rateAsset()`, `getRate()`, `basket()`, and every Standardized Yield selector are absent. The report said this absence clause was not re-read in finalization. It is present in the file read for this response.

Observation, function review and pair-token interface: `donate(token, amount)` is the recorded signature, and `IUniswapV4PairTokenStandardExchangeVault.donate` is `donate(address,uint256)` external payable, selector `0xe69d849d`, with no flag. No shared Standard Exchange `donate` read in this pass already carries `pretransferred` without changing that selector. `IStandardExchangeInMulti` carries `pretransferred` as a function argument.

Observation, `MultiStepOwnableRepo._initialize` lines 83-85: the initializer stores the address it is given and does not reject `address(0)`. `OperableRepo._onlyOwnerOrOperator` lines 211-218: the caller passes if it is the stored owner or an operator. A stored owner of `address(0)` does not make that guard revert for an operator.

## Assumptions

- A later blockers sentence governs where an earlier sentence in the same file would otherwise be copied against it. A PRD sentence the blockers file has not yet cited is not a reason to reverse a blockers lock.
- "Payer" in the pretransfer refund is the caller that declared the maximum. The vault does not discover a token sender, and the output recipient is a different argument.
- The one-token exit is `exchangeIn` with the share as input, because the PRD does not install Weir's `withdraw` or `zapTo`.
- Weir's half-excess formula is evidence of what "about half" refers to. It is not itself a blockers lock.

## Proposals

### F1. Overstated-maximum refund

Observation: the lock says to refund the unbooked balance when the maximum is larger, and not to pull the shortfall. It does not say whether that balance is used first. The directive's staging sentence and swap-shape sentence stay in force because B-13 incorporates the directive.

Inference: refunding the original unbooked balance after using part of it cannot be funded from that balance. The branch that refunds the snapshot, and uses none of it, is the one that matches both "refund the unbooked balance" and "processed only when present unbooked input covers it," on a donation and on a bundle as well as on a single leg.

Recommended sentence: Snapshot each provided token's unbooked balance before any pull or use, after the existing rejection of a caller with no bytecode; if any pretransfer maximum exceeds its snapshot, process no leg, use no token, pull no shortfall, do not revert for that difference itself, and refund each overstated snapshot, plus each within-maximum leg's declared amount only, to the payer, who is the caller that declared the maximum and not the output recipient or a discovered token sender, reporting that zero use, those refunds, and zero output from execution, from the caller's existing minimum check, and from the pretransfer preview that reads the same current unbooked balance, while the pull-path preview, which has no `pretransferred` argument, is not that preview, whereas a maximum within its snapshot is processed, refunds only maximum minus the amount taken into the route, in the provided token, does not refund or process the surplus above that maximum, shapes a swap, on a route that swaps, so the refundable remainder is in the provided token, and on a processed donation books a taken amount that cannot be deployed instead of refunding it.

Rejected alternative: process up to the unbooked balance and refund only what remains, because that spends the balance the lock says to refund and cannot fund a refund of the original snapshot.

### F2. Fees on a liquidity-adding user route

Observation: a nonzero `modifyLiquidity` settles `feesOwed` through `position.update`. A deposit, a bundle deposit, and a share-minting `exchangeIn` add liquidity that way. A pass-through does not modify the position. The withdrawal lock already books fees collected by `modifyLiquidity` and pays only principal. User routes do not call `compound()` and do not deploy a booked remainder.

Inference: "leave them unpaid in the position" does not survive that call. Booking the fee delta, and keeping it out of the user's figures, is the disposition that matches the withdrawal sentence without calling `compound()` or charging the usage fee on a pass-through.

Recommended sentence: A deposit, a bundle deposit, and a share-minting `exchangeIn` collect position fees as the `feeDelta` of their `modifyLiquidity`, book that delta for both tokens, and do not include it in the caller's consumed input, refund, or share credit, and that booking is not a `Compounded()` emission and does not deploy or swap those fees; a pass-through `exchangeIn` does not modify the position, does not collect position fees, and still takes no usage fee; none of these routes call `compound()`.

Rejected alternative: leave the fees unpaid in the position, because `position.update` settles them on the liquidity change and that state does not survive the call.

### F3. Booked total and zero added liquidity

Observation: the later booking sentence says to book the actual held balance after the deposit, not a calculated leftover. The excess sentence says the scarcer token is fully used and the excess of the other token is booked. `Position.update` reverts `CannotUpdateEmptyPosition` on a zero liquidity change when the position is empty. Weir skips `modifyLiquidity` when computed liquidity is zero; that skip is evidence, not the lock.

Inference: the later sentence is the booked total. The excess sentence is the sizing target of the one permitted deposit, not a second amount to add. Calling `modifyLiquidity` with zero liquidity can revert merely because nothing was deployed, which the remainder lock forbids.

Recommended sentence: After `donate` or `compound`, the booked total of each token is the vault's ERC-20 balance of that token after the one permitted deposit has settled, not a calculated excess and not an amount added to a prior balance; the excess sentence is only the sizing target that the scarcer token is fully used, inexact exhaustion is not a second deposit and not a revert, and if that deposit would add no liquidity the call does not call `modifyLiquidity`, books that actual balance, and does not retry, swap an already both-token balance, or swallow a revert of a step it did take.

Rejected alternative: book the calculated excess as the total, because that reverses the later lock that the booked amount is the actual held balance, not a calculated leftover.

### F4. Position ratio

Observation: the booking section says "position ratio" and does not define it. FS-OWN-33 says the one-sided deposit matches the pool ratio. Pool price, current position amounts, and those amounts plus unpaid fees can pick different scarcer tokens.

Inference: for this full-range position the liquidity composition at the current price is the pool price ratio. Unpaid fees and booked remainders are not part of that composition.

Recommended sentence: The position ratio is the current pool price ratio, the token amounts a full-range liquidity add consumes at the current sqrt price, excluding unpaid fees and booked remainders, and that is the only ratio a one-sided user deposit and a one-token maintenance call use.

Rejected alternative: use position amounts plus unpaid fees, because that can pick a different scarcer token and it is not the liquidity composition the deposit matches.

### F5. One-token swap size

Observation: FS-OWN-33 says "about half of the excess." Weir `_balance` implements that as half the value-excess, with no guarantee that the leftover is only in the input token. The booking lock says the maintenance swap is as a one-sided user deposit does, and that the remainder must be in the token being processed. N-04 forbids choosing a V4 quoter against an analytic planner as a product rule.

Inference: one size has to serve both paths, or the "as a one-sided user deposit does" lock is false. A size that can leave an output-token remainder reopens the remainder sentence. "About half" does not survive as the amount.

Recommended sentence: For a one-sided user deposit and for a one-token `donate` or `compound`, the amount swapped is the greatest input that the mathematical result of the operation leaves fully consumed on the output side by the following liquidity add, rounded down so any remainder is in the input token, and if that rounded input is zero the call swaps nothing; FS-OWN-33's "about half of the excess" does not survive for either path, Weir's divide-by-two is not the amount, a V4 quoter is not chosen over an analytic planner as the product rule, a user-deposit remainder is still refunded to the payer, and a maintenance remainder is still booked.

Rejected alternative: keep "about half" for the user deposit and an exact-ratio swap for maintenance, because the booking lock says those swaps are the same and half the value-excess does not keep the remainder in the processed token.

### F6. Unconverted exit principal

Observation: the already-locked list says a redemption pays the principal fraction and does not have a leftover shortfall revert. FS-A08 says a single-token exit pays only the selected token or reverts. The no-revert sentence is stated as a redemption rule, not only as a sleeve rule. The sleeve stays dropped.

Inference: scoping the no-revert sentence down to the dropped sleeve would reverse that redemption sentence. Booking or leaving the unconverted principal does not pay it. The residual has to be paid, and it has to go to the same recipient as the selected-token output.

Recommended sentence: If a one-token exit swap, on the vault's own unlock or a borrowed unlock, does not convert all of the withdrawn principal into the selected token, pay that unconverted residual to the exit's output recipient in the unconverted token, do not book it, do not leave it, and do not revert; the no-leftover-shortfall-revert sentence stays in force for that residual and is not narrowed to the dropped sleeve, and FS-A08's revert does not survive for it.

Rejected alternative: revert when conversion is incomplete, because that reverses the locked sentence that the redemption has no leftover shortfall revert.

### F7. `Compounded()` predicate and amount rationale

Observation: `ModifyLiquidity` has no token amounts. A both-token compound does not swap, so no `Swap` event carries the added amounts. The lock says `Compounded()` has no arguments and is emitted when fees are compounded into the reserve, not when a maintenance call compounds no fees. `donate()` also compounds. The deployed reserve is liquidity, not a swapped balance.

Inference: the amount rationale cannot be copied. Replacing it does not add fields and does not reverse the no-argument signature. Fungible mixed balances cannot be traced unit by unit, so the predicate is the presence of a fee component plus liquidity actually added.

Recommended sentence: Emit the no-argument `Compounded()` once when `donate` or `compound` adds a positive liquidity delta and the processed balance included a positive collected or previously booked fee in either token; do not emit for a donation-only deploy, for a call that adds no liquidity, or for a call that compounds no fees, do not add fields, do not name a donation event, and do not treat `ModifyLiquidity` or a required `Swap` as the amount record.

Rejected alternative: keep "amounts come from the PoolManager events" as the rationale, because `ModifyLiquidity` carries no token amounts and a both-token compound emits no `Swap`.

### F8. Seven-address write

Observation: B-07 requires one initialization write of the seven package immutables into the Uniswap V4 Protocol Aware Repo, and then says the repo is not given a second per-vault copy.

Inference: "second" cannot forbid the write the previous sentence requires. It forbids another store of the same seven addresses for that vault.

Recommended sentence: The canonical write is the one initialization write of the seven package immutables into the Uniswap V4 Protocol Aware Repo for that vault instance, and "second per-vault copy" forbids any other store of those seven addresses for the same vault, including a duplicate slot in that repo, and does not forbid the initialization write.

Rejected alternative: read "second copy" as forbidding the instance write, because that deletes the write the previous sentence requires.

### F9. Crane getters replace the absence clause

Observation: FS-A01, read in this pass at PRD line 393, asserts that `poolManager()` and family-only `poolKey()` are absent, and also asserts that `rateAsset()`, `getRate()`, `basket()`, and Standardized Yield selectors are absent. B-07 says the Crane Protocol Aware getters and the `UniswapV4SinglePositionAware` getters are externally callable, and that no family-only `poolManager()` or `poolKey()` is added.

Inference: replacing the whole absence row would drop absences the locks still require. The rewrite replaces only the clause that contradicts B-07.

Recommended sentence: The PRD pass replaces the FS-A01 absence assertion for `poolManager()` and family-only `poolKey()` with the B-07 sentence that the Crane Protocol Aware facet getters and the `UniswapV4SinglePositionAware` getters are externally callable on this vault and that no family-only `poolManager()` or `poolKey()` is added, and it leaves that row's absences for `rateAsset()`, `getRate()`, `basket()`, and Standardized Yield selectors in place.

Rejected alternative: delete the whole FS-A01 absence row, because that would drop absences the locks still require.

### F10. `donate` signature

Observation: the function review and the pair-token interface record `donate(address,uint256)` with no flag. The booking lock says `donate()` uses tokens already transferred when `pretransferred` is set, and pulls the directed amount otherwise. The shared money route that already has this rule carries it as a function argument. `compound()` has no donation input.

Inference: a two-argument selector has no input for the locked rule. Saying the flag already lives on a shared interface, without changing this selector, does not match the signature that was read.

Recommended sentence: The family signature is nonpayable `donate(address token, uint256 amount, bool pretransferred)`, `compound()` keeps no arguments, `pretransferred` false pulls `amount`, and `pretransferred` true uses the already transferred unbooked balance up to `amount` under the overstated-maximum rule, which refunds the snapshot and deploys nothing when `amount` exceeds that snapshot; this replaces `donate(token, amount)` because that signature has no input for the locked `pretransferred` rule and its payable form accepts native ETH, which this vault does not accept.

Rejected alternative: keep `donate(address,uint256)` and read a shared-interface flag that does not change the selector, because this family's donate selector has no such flag and the booking rule would have no input.

### F11. Batch-swap scope

Observation: B-02 says this vault can be included in a batch swap and that is not a revert, the earlier exclusion is removed, and the borrowed-unlock path stays. FS-A22, FS-X01, and FS-UNLOCK-01 still name `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` as reverting `ManagerAlreadyUnlocked`. FS-A20 still rejects a borrowed `exchangeIn` that sets `pretransferred`.

Inference: the removed exclusion is the ban on including this vault's swap in a batch. It is not a deletion of the four named reverts. Canonical `exchangeIn` is the borrowed path, including a share mint, a pass-through, and a one-token exit.

Recommended sentence: While the PoolManager is already unlocked, canonical `exchangeIn`, including a share-minting `exchangeIn`, an underlying-to-underlying pass-through, and a one-token exit, may proceed on the borrowed path and must not revert `ManagerAlreadyUnlocked`, and `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`; this scopes the removed batch-swap exclusion to `exchangeIn`, does not restore a ban on including this vault in a batch swap, and does not delete the FS-UNLOCK-02 borrowed-path checks, including `pretransferred` false.

Rejected alternative: let bundle, donate, and compound proceed while unlocked, because the owner removed the exclusion of this vault from a batch swap, not the FS-A22 reverts.

### F12. Owner after initialization

Observation: the lock writes `feeTo()` into the owner at initialization and says that is the owner `onlyOwnerOrOperator` uses. The initializer stores the address it is given, including `address(0)`, without a zero check. The guard admits an operator when the stored owner is `address(0)`, and `address(0)` cannot call.

Inference: a live read of `feeTo()` on later calls is a different instruction. Reverting initialization on zero adds a failure the lock does not state. A later oracle change does not rewrite a value that was written once.

Recommended sentence: Initialization stores the address returned by `feeTo()`, including `address(0)`, and does not revert because that address is zero; a later change of `feeTo()` does not move the stored owner, later calls do not live-read `feeTo()` for the owner, and `onlyOwnerOrOperator` still admits an operator when the stored owner is `address(0)`.

Rejected alternative: live-read `feeTo()` on every owner check, because the lock is a value written at initialization and a live read is not that instruction.

### F13. Two reserve names

Observation: B-10 uses one raw liquidity number as the share denominator. B-06 says `reserves()` wraps the position's current token amounts plus unpaid fees, and a booked remainder is not in that read.

Inference: one name for both quantities lets a rewriter make `reserves()` return liquidity. The fix is a name, not a new economic rule.

Recommended sentence: Call the one raw liquidity number used as the share denominator deployed liquidity, and call the token amounts plus unpaid fees that `reserves()` wraps deployed token reserves; `reserves()` returns deployed token reserves, not deployed liquidity.

Rejected alternative: make `reserves()` return the liquidity number, because that collapses the two quantities B-10 and B-06 already separate.

### F14. PRD sentences the no-compound lock removes

Observation: B-02 says a deposit, a withdrawal, and `exchangeIn` do not call `compound()`, and its PRD line does not name FS-MONEY-01, FS-A11, or FS-A33. Those three, re-read in this pass, still say compound runs before the user route, withdrawal pays pro-rata idle, and borrowed execution uses that compound.

Inference: a pass that edits only the cited IDs leaves those sentences in force. Replacing them is a rewrite instruction. It does not decide F2.

Recommended sentence: The PRD pass replaces FS-MONEY-01's sentence that `unlockCallback` calls `_compound` before deposit and withdrawal, FS-MONEY-01's sentence that `_withdraw` pays pro-rata idle, FS-A11's pro-rata idle and compound-before-deposit-and-withdrawal sentences, and FS-A33's sentence that borrowed execution uses the same compound, with the B-02 lock that a deposit, a withdrawal, and `exchangeIn` do not call `compound()` and with the booking rule that a withdrawal pays only the principal fraction, and this replacement does not decide whether those routes collect fees.

Rejected alternative: leave those PRD sentences standing because B-02 does not cite them, because a pass that edits only cited IDs would still compound on the user path.

### F15. 32-byte consumer list

Observation: B-08 says the accepted preview is `(uint256 amountOut, uint256 amountRefunded)`, the PRD pass enumerates every consumer of the old 32-byte return, and this lock does not make that list. The report says the missing list is pass work, not a start gate and not a defect in the hook-scenario lock.

Inference: two editors can otherwise invent different lists and call the rewrite complete. The sentence tells the pass to write the list in the PRD and tells this file not to supply it.

Recommended sentence: The comprehensive PRD pass is not complete until it writes, in the PRD, every consumer of the old 32-byte preview return and points each at the 64-byte tuple `(uint256 amountOut, uint256 amountRefunded)`; this blockers file does not contain that list, inventing one from it does not complete the pass, and the missing list is not a gate before the pass starts and is not a defect in the B-08 hook-scenario lock.

Rejected alternative: treat the missing list as a defect that blocks the hook-scenario lock, or as a list this file must supply, because the lock says the pass enumerates the consumers and this lock does not make that list.

## Coverage

| Finding | Sentence proposed | Lock preserved |
| --- | --- | --- |
| F1 | Overstated maximum is not processed; snapshot refunded to the payer | No shortfall pull; staging and swap-shape stay for the within-maximum case |
| F2 | User liquidity add books `feeDelta` apart from the user's figures | No `compound()` on the user route; pass-through takes no usage fee |
| F3 | Actual post-settlement balance is the booked total; zero liquidity skips the modify | No extra attempt; both-token call does not swap; a taken step that reverts is not swallowed |
| F4 | Position ratio is the current pool price ratio, excluding fees and booked remainders | Same ratio as the one-sided deposit |
| F5 | One rounded-down mathematical swap size for the user deposit and one-token maintenance | Remainder stays in the input token; quote method is not a product choice; "about half" does not survive |
| F6 | Unconverted principal is paid to the output recipient | No leftover shortfall revert; sleeve stays dropped |
| F7 | One no-argument emission when fees were in the balance and liquidity was added | No fields; no donation event; both-token call still does not swap |
| F8 | One initialization write; "second" means no other store | The required instance write stays |
| F9 | Replace only the FS-A01 `poolManager()` and family-only `poolKey()` absence | Crane getters stay callable; other absences stay |
| F10 | Nonpayable three-argument `donate`; `compound()` stays argument-free | `pretransferred` rule has an input; no native ETH |
| F11 | Batch inclusion is `exchangeIn` only | FS-A22 reverts stay; exclusion is not restored |
| F12 | Store `feeTo()` once, including zero; operators still pass | Owner is set at initialization, not live-read |
| F13 | Deployed liquidity versus deployed token reserves | Share denominator stays raw liquidity; `reserves()` stays token amounts plus unpaid fees |
| F14 | Pass replaces the four named compound and idle sentences | Does not decide F2 |
| F15 | Pass writes the consumer list in the PRD | This file does not invent it; not a start gate |

No finding was skipped. No second sentence is offered as an acceptable alternative.

## Limits

- Static reading only. No Forge, tests, installs, or Git were run. A sentence fitting the locks is not proof that the economics execute.
- Peers were not read. This response does not adopt or reject another member's sentence except where the published report itself records that a prior answer was not adopted.
- The 32-byte consumer list was not made.
- The F5 sentence names the amount and the rounding direction. It does not choose a quoter against an analytic planner. Two integer solvers that both round down can still differ by a wei until the later plan writes one formula; that wei is not permission to restore "about half."
- Weir's two-wei subtraction before `getLiquidityForAmounts` was observed and is not adopted. The blockers file does not state it.
- These proposals do not authorize implementation, a PRD edit, or an owner lock. They do not replace the blockers file or the published review.
