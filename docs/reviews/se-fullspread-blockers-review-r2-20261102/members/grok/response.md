# Member response

## Identity

- Run ID: se-fullspread-blockers-review-r2-20261102
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/se-fullspread-blockers-review-r2-20261102/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Is the current `IMPLEMENTATION_PLAN_BLOCKERS.md` consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?
- Required targets: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`
- Optional context: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`; `docs/vaults/PRETRANSFER_DIRECTIVE.md`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- Admitted read scope: the required target and the three optional context files. Repository search was used only to confirm two citations inside the blockers file. A locked owner sentence is not a defect merely because it differs from the PRD. The blockers file is the later authority.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Blockers file, all 397 lines | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` | source observation | Every B-01 through B-13 decision, the donation and compound booking lock, N-01 through N-07, the matrix and audit sections, and the already-locked list were read. Owner answers dated 2026-11-01 and 2026-11-02 are in the file. |
| Full-spread PRD, all 452 lines | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | source observation | Read as the document the blockers file says the later council pass will edit. Differences from a locked sentence were not treated as defects. |
| Pretransfer directive, full file | `docs/vaults/PRETRANSFER_DIRECTIVE.md` | source observation | B-13 incorporates this file. The overstated-maximum refund and the "not sent to `msg.sender`" sentence are both in it. |
| Function review, full file | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | source observation | The 2026-11-02 reserves paragraph matches the blockers wrap. Older sleeve, permissionless-`compound`, and local-plus-deployed sentences are still in that file. They were not used as current requirements. |
| Rate-provider citation | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol` | source observation | `PkgArgs` carries `reserveVault`, `rateSubject`, and `rateTarget`, as B-08 says. Other text in that file was not used as a requirement. |
| Preview-width citation | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | source observation | `previewExchangeIn` still returns one `uint256 amountOut`. That matches the blockers file's "old 32-byte return" claim. Other text in that file, including its pretransfer comment, was not used as a requirement. |
| Public query | not used | source observation | No web or documentation query was sent. |
| Earlier review | `docs/reviews/se-fullspread-blockers-review-20261102/` | not examined | Not admitted. Not read. |
| Peer responses | this run's `members/*/response.md` | not examined | Not read before submission. |
| Cited unlock report | `docs/research/se-v4-unlock-sleeve-20261102/REPORT.md` | not examined | Named in B-09. Not admitted. Not read. The B-09 lock was judged from its own sentences. |

## Assumptions

- The pretransfer directive is in force in full because B-13 names it as the project directive. The shorter echo in B-13 does not delete directive sentences it omits.
- "Two implementors would diverge" means two readers can move different tokens, book different balances, or update different consumers without contradicting a more specific sentence in the blockers file.
- A note that explicitly leaves library organization or quote machinery to the engineer is not a product defect when the observable result is locked.
- None of these assumptions hides a missing target. All four admitted files were read.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `IMPLEMENTATION_PLAN_BLOCKERS.md` | required | examined | Whole file, including 2026-11-02 owner answers, notes N-01 through N-07, and the already-locked list. |
| Full-spread PRD | optional | examined | Whole file, as the rewrite target. Used to see which locks replace a sentence and which locks leave a hole. Not used to fault a lock for differing from it. |
| `PRETRANSFER_DIRECTIVE.md` | optional | examined | Whole file, because B-13 cites it. |
| `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | optional | examined | Whole file, because the reserves lock says it replaces that file's local-plus-deployed sentence. |

Checked against the question, and not filed as defects:

- B-01 and B-10 agree. Fee shares come out of `grossShares`. The 1,000 floor is a separate mint to `address(0)`, not part of `grossShares` and not a fee base. Later supply grows by `grossShares` only. The 30% clamp (`3e17`) is the fee both the netting formula and the named previews use. A pass-through, including underlying-to-underlying `exchangeIn`, takes no fee. `decimals()` is metadata and does not scale the stored balance.
- B-02, B-04, and B-09 agree. There is no sleeve, no sleeve target, and no `UnderlyingUnavailable` for an unpullable borrowed fraction. Zero deployed liquidity with positive supply is not given a denominator. A redemption swaps the withdrawn net only. The unbounded price limits stay. The accepted 023 remainder is a sandwich of the owner or operator's own `compound()`, and the absence test must not claim that exposure is gone.
- B-03's "corrected" label is a lock in substance. Its no-fee, no-donation, no-remainder return matches B-11. `Compounded()` has no fields and is emitted when fees are compounded into the reserve. A call that compounds no fees does not emit it. A remainder does not by itself revert.
- B-05 and the booking lock agree that a one-token call may swap donated tokens, fees, or a booked remainder, and that a combined balance of both tokens is a proportional deposit and does not swap. Neither call swaps the deployed position. `donate` reverts when `totalSupply` is zero, before a swap.
- B-06 is copyable. No view has a coded vault revert. An unsupported route, including `previewExchangeOut`, returns zero. `exchangeOut` still reverts `ExchangeOutNotAvailable()`. `reserves()` and `reserveOfToken` are the live deployed read, including unpaid fees, with no local term and no snapshot. An out-of-gas revert is left as an EVM error. Inventing a catch-and-return-zero would add a failure mode the lock does not define.
- B-07 is copyable if the whole paragraph is kept. Seven architecture addresses are deployment arguments, not `ROBINHOOD_MAIN.sol` constants. Initialization writes them into the Protocol Aware Repo. The adopted reading is that the package which initializes the vault holds those immutables, the Crane facet exposes them, and "no second per-vault copy" forbids a second store in the family repo. Family `poolManager()` and family-only `poolKey()` are not added. `positionLiquidity()` wraps `StateLibrary.getPositionInfo`. `localReserves()` is not restored.
- B-08 is copyable for the vault. This vault does not implement `getRate()`, does not store a provider, and does not install `StandardExchangeRateProviderFacet`. The hook uses an external `IStandardExchangeRateProviderDFPkg` instance. The cited `PkgArgs` fields exist. "May" in the body is the product capability; line 396 and "the owner locked those scenarios" make the two-pool, two-`rateTarget` row required. The consumer list is a separate finding below.
- B-11 and B-12 are copyable. `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` have no other arguments. Amounts stay in the PoolManager events and the ERC-20 `Transfer`.
- N-01 through N-05 and N-07 do not reopen a choice. N-04 locks the quote as the mathematical result and forbids a step cap, a spacing rule, and a quoter-versus-planner product choice. N-06 leaves library assignment to the engineer and says the owner is not asked to design the libraries. That is organization, not a second money rule.
- The already-locked list restates the bodies. It does not silently restore the sleeve, the extra fee mint, the local reserve term, or the amount-bearing `Compounded` event. Where a restated sentence is itself unclear, the finding below cites both places.

## Conclusions

- Answer: no. The locked answers agree on the sleeve drop, the netted usage fee, the raw-liquidity share unit, the view non-revert, the Crane facet homes, the external rate provider, and the paired-event shapes. They are not yet a sufficient sole source for one PRD rewrite. Five locked sentences can be executed in more than one way, and the file itself requires a preview-consumer enumeration it does not contain.
- The PRD still states the sleeve, the extra fee mint, the local-plus-deployed reserve, permissionless `compound`, `UnderlyingUnavailable`, decimal scaling of the share formula, and a reverting `previewExchangeOut`. Those differences are not defects. The blockers file is the later authority. A rewrite that copies the locks over those sentences is the edit this file already orders. This response does not make that edit.
- Peers were not read. This is not council consensus.
- This response does not authorize implementation or a PRD edit.

Adopted readings that are not findings:

- `Compounded()` follows the positive predicate on B-11: emit only when fees are compounded into the reserve. A call whose fee tokens are entirely re-booked does not emit. The shorter "compounds no fees" sentence is the no-fee call, not a second rule that emits whenever fee tokens were present.
- "The earlier exclusion is removed" in B-02 removes the exclusion of this vault from a batch swap. It keeps the borrowed-unlock path. It does not, by itself, allow `donate`, `compound`, or the bundle routes to run while the manager is unlocked.
- Before the first deposit, `compound()` with no fees, no donation, and no booked remainder returns unchanged. A stray that is none of those three is not booked by that call.
- A share donation still burns shares and does not withdraw. `donate()` also compounds, so held fees and a booked remainder on that call follow the booking rule. The share itself is not swapped.

## Review findings

### Overstated pretransfer maximum has no single refund

- Location: `IMPLEMENTATION_PLAN_BLOCKERS.md` lines 282, 284, and 390; the same rule in `docs/vaults/PRETRANSFER_DIRECTIVE.md` lines 9 and 15. Line 378 names the payer for unused input generally.
- Invariant or requirement: one locked attribution rule must tell two implementors the amount used, the amount refunded, and the recipient when the caller's maximum is larger than the unbooked balance.
- Impact: the within case is copyable: refund is maximum minus used, in the provided token, and the rest of the sitting unbooked balance stays staged. The over-maximum case is not. "Refund the unbooked balance" and "do not refund maximum minus used" can be copied as three different procedures. One uses nothing and sends the entire sitting unbooked balance to the payer. That can send another party's sitting tokens away, and it collides with line 284 if the payer is `msg.sender`, because the unbooked remainder is not sent to `msg.sender`. One caps use at the unbooked balance and refunds only the unused part of that balance. That is solvent, but it is not what "refund the unbooked balance" says once `used` is nonzero, and the sentence "do not refund maximum minus used" assumes there is an amount used. One reverts. The lock says refund, and it says not to pull the shortfall. The directive's contrast, that the within case does not refund the whole remaining unbooked balance, makes the whole-balance reading look intended, which makes the insolvent and the "not sent to `msg.sender`" readings worse. B-13's echo also drops the directive's swap-shape sentence and its staging sentence. Those stay in force by the incorporation at line 276, but copying only line 282 loses them. Two PRD editors cannot copy one formula from this text.
- Fix direction: replace the over-maximum sentence with one formula before it is copied. State `used`, the refund amount, and the recipient. If the call uses nothing, say it does not move the sitting balance, and do not say it refunds that balance to the caller. If use is capped at the unbooked balance, say the refund is the unbooked balance minus used, paid to the payer in the provided token, and that tokens above the caller's maximum are not sent to `msg.sender`. Do not leave both formulas in the file. Advice only. This response does not edit the directive or the blockers file.
- Evidence class: source observation of the locked sentences; inference that both readings survive in the same section.

### Deposit and exchangeIn leave collected fees unspecified

- Location: `IMPLEMENTATION_PLAN_BLOCKERS.md` lines 78, 250, 254, and 256. The already-locked restatement is line 385.
- Invariant or requirement: every `modifyLiquidity` that collects fees needs one disposition. The withdrawal disposition must not be the only one if deposit and `exchangeIn` also collect.
- Impact: line 78 says a deposit, a withdrawal, and `exchangeIn` do not call `compound()`. Line 256 says a withdrawal's `modifyLiquidity` collects fees, books them, and pays only the principal fraction. Line 254 says those three routes do not deploy or swap a booked remainder. Nothing says what a deposit, a bundle deposit, or a share-minting `exchangeIn` does with fees its own `modifyLiquidity` collects. Three procedures fit the written sentences. Separate those fees and book them, as the withdrawal does. Let the liquidity-add delta net them into the position, which deploys fee value without calling `compound()`. Leave them unbooked, in which case B-13 lets the next pretransfer use them up to the caller's maximum. A pass-through underlying-to-underlying `exchangeIn` is not this gap if it does not modify the position. A route that does modify the position is. Two implementors can ship different fee movements and both claim the lock.
- Fix direction: add one sentence for fees collected by a deposit, a bundle deposit, and an `exchangeIn` that modifies liquidity. Say they are booked, redeployed in that call, or left unbooked. If they are left unbooked, say so against the pretransfer rule rather than implying it. Do not treat "does not call `compound()`" as that sentence. Advice only.
- Evidence class: source observation of the locked sentences; inference from the absence of a deposit-side booking sentence.

### Booking records either the excess or the held balance

- Location: `IMPLEMENTATION_PLAN_BLOCKERS.md` lines 252 and 254. Restated at line 385.
- Invariant or requirement: after `donate` or `compound` deposits, one rule must name which token balances become the booked remainder, and whether that record replaces or increments the prior booked amount.
- Impact: line 252 says to book the one-token remainder, which must be in the token being processed, and to book the excess of the other token on the both-token path. Line 254, locked the same day, says to book the actual held balance after the deposit, not a calculated leftover, including a stray transfer. A reader can treat line 254 as the measurement rule for the excess line 252 identified. Another can set the booked amount of every vault token to that token's post-deposit balance, including dust the scarce-token rule said would be fully used. Another can book only the excess token's actual balance and leave dust in the other token unbooked. "Held balance" does not say whether a non-vault token has a booking slot. "Book that remainder" reads as an increment. "Book the actual held balance" reads as a replacement. Incrementing by a balance that still contains the old booked tokens double-counts. The withdrawal sentence at line 256 is specific and should not be rewritten into this rule. The deposit rule itself cannot be copied as one assignment.
- Fix direction: keep the scarce-token sentence as the deposit target, and replace the recording sentence with one assignment. For each vault token, the booked remainder becomes that token's balance after the `donate` or `compound` deposit, including a stray transfer of that token, or name the single token whose balance is recorded. Say a non-vault token is not booked, if that is the rule. Say the assignment does not apply before the withdrawal pays the principal fraction. Advice only.
- Evidence class: source observation of the two locked sentences; inference that they are not the same assignment.

### Scarce token has no position-ratio formula

- Location: `IMPLEMENTATION_PLAN_BLOCKERS.md` line 252. The one-token clause on that line points at the existing one-sided deposit. PRD FS-OWN-33, which this file does not replace, says that deposit swaps about half of the excess so the deposit matches the pool ratio.
- Invariant or requirement: the both-token path must identify one scarce token with a ratio two implementors compute the same way.
- Impact: "the proportionally smaller amount relative to the position ratio, not the smaller raw balance" rejects a raw-balance comparison and still does not name the ratio. The pool price, the position's current token amounts, and those amounts plus unpaid fees are three different ratios. They pick different scarce tokens when the balances are near the boundary and unpaid fees sit on one side. The one-token clause can follow the existing one-sided deposit rule, including that rule's "pool ratio." The both-token sentence says "position ratio" and does not say it is the same figure. FS-OWN-33's "about half" is a pre-existing PRD phrase this file did not reopen; it is not the defect. The new scarce-token sentence is.
- Fix direction: name the ratio in the sentence that will be copied. If it is the current pool price for the full-range position, excluding unpaid fees, say that, and say the scarce token is the one with the smaller balance divided by that price weight. If unpaid fees are in the ratio, say that instead. Do not leave "position ratio" beside an unreplaced "pool ratio" without saying they are the same figure. Advice only.
- Evidence class: source observation of line 252 and of FS-OWN-33; inference from the three ratio definitions the words allow.

### One-token exit forbids a shortfall revert and names no residual

- Location: `IMPLEMENTATION_PLAN_BLOCKERS.md` lines 86 and 380. PRD FS-A08, which this file does not name, says a single-token exit pays only the selected token or reverts.
- Invariant or requirement: once a leftover shortfall revert is forbidden, the one-token exit still needs one disposition for principal the swap does not convert.
- Impact: line 86 defines the withdrawn net as the principal fraction and excludes collected fees and a booked remainder. Line 380 pays that fraction, books collected fees, and says the redemption does not have a leftover shortfall revert. The sentence does not say the unbounded swap always consumes the unwanted principal, and it does not say what the caller receives if it does not. An editor can keep FS-A08's revert, narrowing line 380 to the old sleeve shortfall. Another can delete every shortfall revert because line 380 is later. The second editor then has to pay the residual unwanted token to the caller, book it, or leave it unbooked. Those are different token movements. This is not a claim that the pool returns a partial fill. The lock creates the question by forbidding the revert and not answering it.
- Fix direction: narrow "no leftover shortfall revert" to the sleeve case it replaced, and keep a named revert when a one-token exit cannot pay only the selected token. Or delete that revert and say the unconverted principal is paid to the caller in that token, or booked. One of those sentences can be copied. Both cannot stay implied. Advice only.
- Evidence class: source observation of lines 86 and 380 and of FS-A08; inference that the later no-revert sentence does not choose among the residual dispositions.

### Preview consumers are required and not listed

- Location: `IMPLEMENTATION_PLAN_BLOCKERS.md` lines 15, 196, and 396.
- Invariant or requirement: the file orders the PRD pass to enumerate every consumer of the old 32-byte preview return. That list has to be one list, or two editors will update different consumers.
- Impact: this is an acknowledged deferral, not a hidden contradiction. Line 15 forbids making the list in this file and still makes the enumeration part of the comprehensive PRD edit. Line 196 says the accepted preview returns `(uint256 amountOut, uint256 amountRefunded)` and that the rate provider and every other consumer must read that tuple. Line 396 repeats the assignment. The live `previewExchangeIn` citation still returns one `uint256`, so the width claim matches that interface. The file does not name the consumers. Two editors can treat the silence as "no list yet, so do not guess," or they can each invent a different list and call the rewrite complete. The first is the only reading that does not diverge, and it means this file is not yet a sufficient sole source for that clause of the rewrite. PRD FS-OWN-08 already states the tuple return and says the other-vault migration is not started. It also does not contain the consumer list.
- Fix direction: before the comprehensive PRD edit is treated as complete, lock the consumer enumeration from a code search. Do not invent it from this file, and do not read the instruction "do not make that list here" as "there are no consumers." This review did not perform that search. Advice only.
- Evidence class: source observation of the deferral and of the live one-word preview return; inference that an unlisted enumeration cannot be copied.

## Limits

- Runtime or extraction proof: none. No Forge, tests, installs, Git, wallets, or deploys were run. Static reading is not execution proof.
- Not examined: peer responses; `docs/reviews/se-fullspread-blockers-review-20261102/`; the unlock report cited in B-09; the council report cited at the top of the blockers file; live PoolManager and quoter code. The two citation files were used only for the `PkgArgs` fields and the preview return width.
- Not a defect: a locked sentence that differs from the PRD or from a 2026-11-01 sentence still present in `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`. The function review still contains the sleeve and the local-plus-deployed paragraph beside the later reserves wrap. The blockers file is the later authority.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, a PRD edit, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
