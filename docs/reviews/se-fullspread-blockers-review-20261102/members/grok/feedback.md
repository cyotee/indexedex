# Advisory feedback

## Identity

- Run ID: se-fullspread-blockers-review-20261102
- Member label: grok
- Profile: review
- Phase: advisory feedback
- Draft under review: draft-se-fullspread-blockers-review-20261102-r1
- Draft path: `docs/reviews/se-fullspread-blockers-review-20261102/coordinator/draft.md`
- Fingerprint: not computed. This pass did not compute a hash.
- Owned path: `docs/reviews/se-fullspread-blockers-review-20261102/members/grok/feedback.md`
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Peers read before submission: no
- Peer feedback read before submission: no

## Disposition

requested-changes

The shared verdict is right. The file is not ready to be the sole instruction for rewriting the PRD, and a lock that differs from the PRD is not a defect. This feedback does not reject that verdict. It asks for corrections because the draft misstates two of my findings and omits load-bearing ones. A pass that uses this draft as the complete defect list will still leave two implementors apart.

This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft. It does not answer the open product questions.

## Whether the draft states the findings accurately

Yes for the verdict and for most of the copied findings. No for the quote engine, the `feeTo()` intent, the redemption swap under N-03, and the composition of `reserves()` and the withdrawn net.

Stated accurately, by draft section:

- Proposed text: the large locks agree, and copying the file as it stands can delete a later lock or ship two vaults.
- D1: B-01 and B-10 do not state one genesis credit, and "supply grows only by `grossShares`" fights the floor if copied as a global cap.
- D2: a one-token donation and a booked opposite token are two swap policies in the file.
- D6, in part: N-03 and the matrix sentence drop swaps and booked-remainder rows the locks keep.
- D7: "no fee cap" cannot be copied over the 30% usage-fee clamp.
- D8, in part: `onlyOwnerOrOperator` and "the owner is `feeTo()`" are not one identity.
- D9: the share-side scale is still a choice, and `decimals()` is unstated.
- D10, in part: `Compounded()` has a signature and not an emit predicate.
- D11, in part: the bundle share preview is not named in the fee sentence.
- D13: the batch-swap sentence names no operation and sits beside a non-revocation of FS-HOOK-02.
- D14: `PkgInit.wrappedNative` may remain, so the package input is still a choice.
- D15, in part: `StateView` is stored and called "not the vault's dependency," and the getter list is missing.
- D16, in part: the 64-byte consumer list is deferred, so the file is not a complete rewrite instruction.
- D17, in part: the 039 row still says the expectation waits, and "caller's fraction" is wider than the principal-only payment.
- Not a defect: B-12, the B-13 lock, N-01, N-06, and N-07 match my response. The sandwich and the unbounded limits are not reopened.
- Preserved disagreements: the B-13 row and the genesis row attribute my position correctly. The `feeTo()` row correctly says I alone flagged the identity. The quote-engine row does not.

## Corrections by draft section

### Consistent enough to copy

Do not list "a redemption swaps only the withdrawn net" as a sentence that can already be copied. The quantity limit, not the whole opposing balance, is locked. What the withdrawn net contains is not. D17 still has to say it is the principal fraction after collected fees are booked. Until that sentence exists, two implementors copy line 86 differently. The unbounded limit itself can stay in this list.

### D1. Genesis credit is stated two ways

The cross-lock is stated accurately. The impact does not say that "to the depositor" is undefined. My finding treated that word as a second divergence: `msg.sender` or the route recipient. The fix direction already says the net goes to the route recipient. That matches my earlier advice. This feedback does not re-decide the recipient.

The fix uses `totalSupply` for later deposits and does not say the blockers file's `totalShares` and `totalSupply` are one variable. Equate the names in this section, or the scale finding in D9 still has two counters.

### D3. `reserves()` has no composition after the sleeve drop

The snapshot sentence is a real gap, and I raised it. This section's two outcomes are "live position plus a local snapshot" and "deployed position only." That misses the split inside the deployed term. One reader includes uncollected fees because the deployed term is the live position. Another excludes them because the booking section says `reserves()` does not include uncollected fees. Name that split here. Do not treat "deployed position only" as already excluding fees.

This feedback does not choose the composition.

### D5. "The scarcer token" is not defined

The defect is real. I raised the raw-balance versus position-ratio split inside the donation finding, not as a separate section. Attribution to MiniMax is incomplete if the raised-by line is meant to be exhaustive. That is not a reason to drop D5.

The fix asks whether a best-effort deposit may book dust of the scarcer token. That is not the best-effort reading in my finding. See the omitted finding under D2. This feedback does not define scarcer and does not choose exhaustion versus dust.

### D6. N-03 and the matrix drop swaps the locks keep

The donation swap and the booked-remainder rows are stated accurately. N-03 also says the only pool swap is `exchangeIn`. That sentence deletes the withdrawn-net redemption swap as well as the donation swap. Name the redemption swap in the impact and in the fix. A rewriter who adds only the donation swap still follows N-03 against B-02.

The matrix sentence also fails to say that an exact-output preview returns zero. The PRD table carries FS-A09. This section should carry the same limit, or a matrix pass that reads only D6 will keep the preview revert.

### D8. "The owner is `feeTo()`" is not an identity the guard already has

The copyability gap is stated accurately, and it is correct that the other three did not flag it. The impact is not. It says the owner's intent, that the fee recipient may call, is not rejected. My finding did not establish that intent. The blockers sentence says the owner accepts a sandwich and will tell users that the protocol manager can do it. It does not say `feeTo()` is that caller. The fix then asks whether initialization sets the diamond owner to `feeTo()`, whether `feeTo()` is an additional caller, and whether a later change of `feeTo()` moves authority. Those are the open questions. Do not preface them with an intent the file does not lock.

This feedback does not choose the authorization.

### D11. The fee is not named on every route that the sentence could reach

The unnamed bundle preview is my finding, and this section states it. The underlying-to-underlying route taking no share fee is not a finding I made. Do not list Grok as raising that half. I do not answer whether that route takes a share fee.

### D12. A quote that cannot finish has two results

The zero-versus-revert split is stated accurately. The rest of the section narrows my finding. I did not say the engine can stay unnamed if the failure result is one sentence. Two engines that both revert on failure can still return different successful preview amounts. The stored Quoter address does not choose the engine. "Do not require the owner to pick the V4 quoter versus an analytic planner unless that choice changes the result" reads as closing the engine. Different amounts are a changed result. This section must not say the engine is not an external choice.

This feedback does not pick the engine and does not pick zero versus revert.

### D15. The seven-address write is ambiguous, and `StateView` is both stored and not a dependency

The `StateView` half is my finding and is stated accurately. I did not treat "not a second per-vault copy" as forbidding the instance write. Attributing that half to Kimi, not to me, is accurate.

"Each getter has the component's name" covers the seven architecture addresses if component means those seven. It does not cover `salt()` or `positionLiquidity()`, and it does not say whether the family query facet remains a package input. The family-selector ban in the fix must stay paired with the Crane getters being callable. Copied alone, "do not add a family `poolManager()` or `poolKey()` selector" is the absence reading I warned against.

This feedback does not name the selectors and does not choose the query-facet fate.

### D16. The 64-byte consumer list is still required, and it is not in this file

The deferral is stated accurately. I agree it is not a contradiction and that it keeps the file from being a complete rewrite instruction. The spot check is the coordinator's, not a restatement of my citation. My response cited `StandardExchangeRateProviderFacet` rejecting a return whose length is not 32, and calling `quoteTotalSupply` and `quoteAssets` when state is non-empty. This section does not carry that state path. See the omitted finding below.

This feedback does not compile the consumer list and does not say whether the required rows use the state path.

### D17. Stale framing would make the rewrite wait or drop a lock

The 039 wait and the "caller's fraction" versus principal-only payment are stated accurately. The retitle must not reopen 023, 024, or 048. Their rows already match the locks. A header that still says every row in that section waits would delete those expectations.

The payment fix says collected fees are booked and not paid. Add that they are not part of the swapped withdrawn net, or D17 closes the payout and leaves the swap quantity open.

This feedback does not choose a booking-section identifier and does not restate the 039 test beyond the directive already locked.

### PRD sentences a rewriter must not leave standing

The table says it is partial. That limit is accurate. It does not carry FS-A01, which still says `poolManager()` is absent. D15 must not be applied so that absence survives. I am not asking for a complete invalidation list in this feedback.

### Preserved disagreements

The quote-engine row says D12 does not require the owner to pick the quoter, and it preserves Kimi's mechanism position without preserving mine. My position is that the engine is still an implementor choice because successful amounts can differ. Record that position as not resolved. Do not record D12 as closing it.

The `feeTo()` row should not say the draft keeps an owner intent that the fee recipient may call. It should say the draft must not invent that intent. The fact that the other three did not flag the identity is already correctly recorded.

The B-13 row is accurate. I do not answer D4.

### Coverage adopted from responses

B-06 lists me, and D3's raised-by line does not. If raised-by lines are exhaustive, add Grok to D3 for the snapshot sentence. B-08 points only at D16. The hook binding is not that defect. See the omission under D16.

## Omitted load-bearing findings

### D2 and D5 do not carry the swallowed-revert reading of "best-effort"

B-11 says a remainder after a best-effort deposit is booked, and that a remainder is not itself a revert. I found two readings: the booking rule's proportional deposit, with a failed swap still reverting, and a swallowed swap failure. D5's dust question is a third reading. None of D2, D5, or D10 states the swallowed-revert split. A pass that defines scarcer and still says "best-effort" leaves that choice.

This feedback does not say which reading to lock.

### D3 and D15 do not say what computes `reserves()`

Storing Reserves Lens does not say `reserves()` calls it. One implementor uses that lens. Another uses the position-amount read. D3 decides the included balances only if the computer is the same. Name the computer in D3 or D15, or say it is still open. This feedback does not choose it.

### D10 does not carry the one-sided correlation event

`Compounded()` is not the only unnamed event. B-11 says a caller deposit or withdrawal is correlated by "the Standard Exchange event." B-12 names that event only for the bundle routes. No section names an event for one-sided `exchangeIn` or a one-token exit, or says there is none and the correlation is `Transfer` plus the PoolManager events. Indexers still diverge. Put that in D10 or in a following section. This feedback does not name the event.

### D16 does not carry the rate-provider state path or the hook binding

Two omissions sit under B-08 and have no draft section.

The cited provider's non-empty state path calls `quoteTotalSupply` and `quoteAssets`. The lock says to update the tuple read and says the required hook rows are not recorded incompatible. It does not say those rows use `getRate()` only. One implementor widens the decode. Another adds the transition-quote interface to this vault. A third leaves the state path failing and records the row incompatible. D16's consumer deferral does not state that split.

Separately, the required rows use an instance deployed for this vault and one rate target. The lock does not name `rateSubject` or `rateTarget`. One fixture can price the share. Another can price a different subject and still claim the row is configured. The coverage line "B-08 incomplete for the stated use" points only at D16. Add the binding to D16 or give it a section. This feedback does not name the subject, the target, or the state path.

## Sections that need no correction

Draft identity, Participation, and Question match the assignment. Fingerprint was not computed, and this pass did not compute one. Proposed text's verdict matches my response. D4 attributes my B-13 position accurately. D7, D9, D13, and D14 state those findings accurately. Not a defect matches my response on B-12, the B-13 lock, N-01, N-06, and N-07. Evidence gaps and Limits do not misstate a finding. I did not re-read the `_mint` path in this pass. My earlier confirmation stands. I am not asking the coordinator to adopt N-01 as a defect.

## Limits

- This pass read only `docs/reviews/se-fullspread-blockers-review-20261102/coordinator/draft.md`. The blockers file, the PRD, the directive, `response.md`, and every peer file were not reopened.
- No hash was computed. No Forge run, test, install, or Git operation was run.
- Silence on a product choice is not a vote for either outcome. The open choices include the share scale, the scarcer-token comparison, the `feeTo()` authorization, the failed-quote result, the quote engine, the reserves composition, and whether maintenance may book a staged balance.
- This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.
