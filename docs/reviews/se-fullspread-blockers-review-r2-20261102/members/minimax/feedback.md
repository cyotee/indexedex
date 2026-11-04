# MiniMax advisory feedback — draft-se-fullspread-blockers-review-r2-20261102-r1

## Identity

- Member: minimax
- Profile: review
- Phase: advisory feedback on the coordinator draft (continuation of this member's conversation)
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking (depth is not a selectable parameter)
- Runtime provider, runtime model, runtime reasoning, and task ID: not exposed to this member; not asserted here
- Peers read before submission: no peer feedback was read
- Owned path written: `docs/reviews/se-fullspread-blockers-review-r2-20261102/members/minimax/feedback.md` only
- Authorization: this feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.

## Draft under review

`docs/reviews/se-fullspread-blockers-review-r2-20261102/coordinator/draft.md`, draft ID `draft-se-fullspread-blockers-review-r2-20261102-r1`. Fingerprint: not computed. I did not compute a hash and did not substitute a different draft; the file above was opened and is the only draft I reviewed.

## Disposition

**requested-changes.**

The draft is structurally sound and, for the most part, accurate about my findings: eight of the nine findings in my initial response are carried as numbered defects (D4, D6, D7, D8, D9, D10, D11) with correct attributions, and the draft adds three defects I did not raise (D1, D3, D5). The requested change is narrow: one load-bearing finding of mine is not carried as a numbered defect, one defect states a premise the blockers file does not state, one "Not a defect" bullet needs a clause so it is not applied to the item the draft itself wants to act on, and one summary line carries a sentence D9 finds unscoped.

## Does the draft state my findings accurately

Mostly yes, with one material qualification.

Accurately stated, with correct attributions:

- **My F-02** (the Crane getters versus the FS-A01 absence row) is D7, raised by MiniMax for the selector row. Correct, and the draft does not attribute Kimi's "second copy" point to me.
- **My F-03** (the one-token swap has no sizing rule, and "the position's ratio" is not a defined quantity) is D4, raised by Grok and MiniMax, including the FS-OWN-33 "about half of the excess" collision. Correct.
- **My F-04** (the owner value behind `onlyOwnerOrOperator`, and the zero `feeTo()` case) is D10, raised by MiniMax only. Correct, including the note that a coordinator observation is not an owner lock.
- **My F-05** (the `donate` pretransfer input has no home in the ABI) is D8, raised by MiniMax only. Correct.
- **My F-06** (the batch-swap sentence is unscoped) is D9, raised by MiniMax only. Correct.
- **My F-07** (B-11's amount rationale is false) is inside D6, raised by Astra and MiniMax: "The amount rationale does not" and "`IPoolManager.ModifyLiquidity` … carries the liquidity delta and no token amounts." Correct.
- **My F-08** (the `Compounded()` emission predicate, and the unnamed donation event) is inside D6: "a later `compound()` of fees booked on an earlier withdrawal can emit or not. `donate()` can emit when it redeploys fees, or only `compound()` can emit" and "does not name a donation event". Correct.
- **My F-09** ("the deployed reserve" names two quantities) is D11, raised by MiniMax, and is correctly marked a naming instruction rather than an economic choice.
- My central position is stated accurately in "Not a defect": "MiniMax found no pair of owner answers that name opposite economics." That is what my response found, and the draft correctly declines to treat it as closing D1 through D6.

Not accurately carried: **my F-01** is absent as a numbered defect. D2 renders one clause of my fix direction — "fees left unpaid in the position" — as my whole position ("MiniMax's fix direction says the fees stay unpaid in the position. That answer is not adopted."), and the "Preserved disagreements" table repeats that framing. My F-01 was primarily a rewrite-completeness finding: the lock is not tied to the PRD sentences it reverses. The "Proposed text" section states the right defect class in general terms — "leave a PRD sentence the lock was meant to replace" — but no numbered defect asks the pass to replace those specific sentences. This is the omitted load-bearing finding below.

## Corrections by draft section

### C-1 — Section "Proposed text": add the omitted defect for the uncited PRD sentences (load-bearing)

- **Draft section:** "Proposed text", and the absence of a numbered defect for it.
- **Omitted finding, stated as I stated it:** B-02's lock — "A deposit, a withdrawal, and `exchangeIn` do not call `compound()`" — reverses PRD sentences the file never cites. My response named them: FS-MONEY-01's "`unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`"; FS-MONEY-01's "`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle"; FS-A11's "Compound harvests and reinvests before deposit and before withdrawal" and "Withdrawal includes pro-rata idle as in `_withdraw`"; and FS-A33's "Borrowed execution uses the same compound and settlement as the locked path from the same economic state." B-02's own PRD citation line names only FS-OWN-14, FS-OWN-12, FS-OWN-15, FS-MONEY-01 and FS-OWN-10.
- **Why it is load-bearing:** the draft's own defect class is exactly this shape, and the deliverable is a PRD rewrite. If those four sentences survive the comprehensive pass, the rewritten PRD still mandates a compound before every deposit and every withdrawal, a pro-rata idle payment that the sleeve drop removed, and a borrowed path that "uses the same compound" — all of which the lock removed, and one of which (FS-A11's idle clause) the sleeve drop removed on a different path. A rewriter who follows the file literally ships a PRD that contradicts the lock it is supposed to implement.
- **Fix direction (advice):** add a numbered defect — or extend D2's fix direction — whose location is B-02's compound lock and whose fix direction names those four PRD sentences and acceptance rows as the text the pass must replace, and states that the replacement wording is the one sentence B-02 already gives (no harvest, no idle payment on the deposit and withdrawal paths). This is a rewrite instruction, not an economic choice: it does not answer whether a deposit collects fees, which D2 leaves open.

### C-2 — Section "D2": the title and the Impact assert a fee-collection event in the deposit path that the blockers file does not state

- **Draft section:** "D2. Fees collected by a deposit or a share-minting `exchangeIn` have no disposition" — title, and the Impact sentence "one implementor books those fees, as a withdrawal does".
- **Why it is inaccurate:** the blockers file names a collection event for one path only. The booking rule says "A withdrawal's `modifyLiquidity` collects fees. Book those fees." B-02 says the deposit path does not call `compound()`, and nothing in the file says a deposit's liquidity change collects fees. D2's own Location admits this — it says "No matching sentence for a deposit or a share-minting `exchangeIn`" — but the title and the Impact reason from a collection that has been established rather than from one the file leaves open. The question is real; its premise is stated too strongly.
- **Fix direction (advice):** restate the title and the Impact so the open question is the one the file actually leaves open — the file does not say whether the deposit path removes and re-adds the position, and therefore does not say whether fees are collected on that path or, if they are, where they go. Drop the assertion that a deposit collects. This does not choose among book, redeploy, or leave unpaid; that stays with D2's open disposition and with the owner.

### C-3 — Section "Not a defect": the first bullet needs one clause

- **Draft section:** "Not a defect", first bullet: "A locked owner sentence is not a defect because the PRD still says the old thing."
- **Why it is inaccurate as written:** the principle is right and I agree with it, and the draft applies it correctly elsewhere. But as a blanket bullet it can be read to close exactly the item the draft acts on in D7 and the item C-1 asks to add, because both are cases where the PRD still says the old thing and the lock is the sentence meant to replace it. The bullet and D7 pull in opposite directions for a reader who takes the bullets as a rule.
- **Fix direction (advice):** qualify the bullet so the two cases separate — a lock that differs from the PRD is not a defect, but a PRD sentence that a lock replaces and does not cite is a rewrite defect to be enumerated by the pass. One clause keeps the principle and preserves D7 and C-1.

### C-4 — Section "Proposed text": the summary lists one sentence D9 finds unscoped

- **Draft section:** "Proposed text", the summary paragraph: "The vault can be included in a batch swap."
- **Why it is inaccurate:** the same paragraph says the remaining defect is that several locked sentences "still admit more than one procedure", and D9 finds precisely that for the batch-swap sentence. The summary line carries an unscoped sentence among the settled facts, so a reader who takes the summary into the rewrite carries the unscoped wording. The draft's summary is otherwise accurate — the sleeve, the fee and its clamp, the pass-through exclusion, the raw liquidity share unit, the `reserves()` wrap, and the `wrappedNative` removal all match the file — so this is a single line, not a pattern.
- **Fix direction (advice):** mark that line as pending D9, or drop it from the summary so the summary lists only statements D1 through D12 do not touch.

### C-5 — Section "Coverage adopted from responses", row B-03: the "remainder boundary" attribution is loose

- **Draft section:** "Coverage adopted from responses", row "B-03 | consistent on the empty call | Astra | D3 and D6 cover the remainder boundary."
- **Why it is imprecise:** B-03's "a booked remainder is still processed" is the empty-call rule, and my response found B-03 consistent as written. D3's "remainder" is the booked-balance assignment and D6's is the emission predicate; neither is B-03's remainder boundary. Attaching them to the B-03 row invites a reader to think B-03 itself is defective.
- **Fix direction (advice):** move D3 and D6 to the rows they actually arise from — D3 to "B-05 and booking", D6 to "B-11" — and leave the B-03 row as consistent. D6 already appears in the B-11 row; D3 already appears in the B-05 and booking row, so this is a de-duplication of the reference rather than a new claim.

### C-6 — Section "Evidence gaps": two of my unverified claims are not carried

- **Draft section:** "Evidence gaps".
- **Why it is incomplete:** two limitations from my initial response are not carried. N-01's source-level claim — that `ERC20Repo._mint` writes `balanceOf` and `totalSupply` directly and does not route through the `ERC20InvalidReceiver` helper — I did not verify, because confirming it would require reading code outside the admitted scope. And the 45-ID audit disposition that the blockers file defers to the council report was not verified either. Neither changes the draft's conclusions; both are honest limits that belong in the record.
- **Fix direction (advice):** add the two items to "Evidence gaps", marked as unverified source claims rather than as findings.

## Minor carry-overs

- Section "Not a defect", second bullet, is accurate and I do not contest it, but the same section's framing of my position should not be read as closing C-1: my "no contradiction between locked owner sentences" finding and my rewrite-completeness finding are different claims, and I made both.
- Section "Preserved disagreements", row "Deposit-side fees": the quoted clause of my fix direction is accurate; the row presents it as my whole position. C-1 adds the missing half.
- Section "Evidence gaps" already flags that FS-A01's absence sentence and FS-A08 were not re-read in the coordinator pass and are member-supplied where cited. That is the correct handling, and it is why C-1 is worth adding on the strength of a member citation: the FS-A11 and FS-A33 sentences I cite in C-1 are equally member-supplied, and the draft should label them the same way.

## What I do not contest

- D1, D3 and D5. I did not raise them, the draft says so accurately for D5 ("The other three did not flag it"), and I do not contest their substance or their fix directions.
- The draft's "Consistent enough to copy" list. Each item matches what I found: the sleeve drop, the fee rule including the genesis `added liquidity - 1,000` base and the separate floor mint, the pass-through exclusion, the 30% clamp, the raw liquidity share unit with `decimals()` as metadata only, the two-token proportional deposit that does not swap, the empty maintenance call, the borrowed exit with no sleeve fallback, the paired events with only the indexed caller, B-13's ordinary refund case, and the rejection of an unfinished-quote failure mode.
- The "Preserved disagreements" table's four rows and the rule that the coordinator is not a fifth vote.
- The draft's choice to keep the fix directions open and to name no procedure. I did not answer the open product questions here either, and nothing in this feedback answers them.

## Limits

- This is advisory feedback on one draft file. It does not replace the draft, does not authorize implementation, and does not authorize a PRD edit.
- No hash was computed for the draft, as instructed. The file at the path named in the task was opened and is the only draft reviewed.
- No peer feedback was read. The only peer material referenced is what the draft itself attributes to other members, quoted in the draft's own text.
- I did not re-open the blockers file, the PRD, the directive, the function review, or my own initial response while writing this feedback; the citations above are from the draft and from the analysis I already delivered in `members/minimax/response.md`. I did not edit my initial response, the draft, the blockers file, the PRD, or any other member's file.
- No Forge run, test run, build, install, deploy, wallet operation, or Git operation was performed, and none is authorized by this feedback.
- Runtime identity is recorded only as given.
