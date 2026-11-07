# Member response — minimax

## Identity

- Member: minimax
- Run ID: se-fullspread-remediation-readiness-20261106
- Phase: initial independent response
- Requested role: council-member
- Requested model: minimax/MiniMax-M3
- Write: not exposed for any runtime identity not given
- Profile: research

## Question and targets

- Question: is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, as now written, ready to be the source from which one remediation implementation plan file is written, with no further owner product decision required?
- Required target, read in full: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, current file including the 2026-11-06 owner lock.
- Optional context used: the family PRD, the family plan, and `docs/research/se-fullspread-remediation-readiness-20261105-r2/REPORT.md`, read only to test whether the current remediation PRD still needs an owner choice.
- Not read: peer responses, other member directories, `docs/reviews/se-fullspread-plan-execution-20261104/coordinator/questions.md`, member question files, and any other earlier readiness report.

## Fingerprint

- Coordinator-supplied specification fingerprint: `93907efa35b135f33f3c893390fcc2154bae1f011d1f74718f1a245a51853d07`
- Independent fingerprint: not computed. A repeated value is not verification.

## Verdict

ready

This is not a verdict that the code is ready to implement, and it does not authorize implementation, tests, deployment, or Git. It does not write the plan file. The prior run's ready verdict is not this verdict; this one rests on the current text.

Two careful authors can write one remediation implementation plan from the current remediation PRD, using the family plan and family PRD only as the base it amends, without asking the owner another product question.

## Evidence

### The sizing choice is one instruction, and the removed method is named as removed

The 2026-11-06 lock, `Rule`, states the method in one sentence: swap 49% of the processed input, then deposit. Do not iterate, do not size an exact output, do not solve a closed-form root, do not walk ticks to find a better split. F4 records that the reviewed sizing loop is not the method and that the required method is 49% of the processed input, so the removed sizing method is not a requirement the plan author must still satisfy. There is no fraction to choose, no ladder to test, no solver to select.

The base already matches that instruction, so the plan author copies one fraction instead of resolving two texts. Family PRD `FS-OWN-33` (line 246) is `Locked 2026-11-06` and carries the same 49% sentence with the same prohibitions; the family PRD precedence clause (line 5) states that the 2026-11-06 lock sets the FS-OWN-33 swap at 49% of the processed input and replaces the open testing ladder; family plan section 2 (line 19), section 10 (line 192), section 13, and section 16 item 4 (line 494) carry the same instruction.

### The out-of-range branch has one specified outcome

The lock, `Boundary`, fixes what happens when the price is not strictly inside the position, including exactly at either boundary: do not swap; the position wants only one token; if the caller provided that token, add it with no swap and refund what the add does not take; if the caller provided the other token, do not swap it; a share mint refunds it; a donate or compound books it; no new error. The lock, `Scope`, limits the rule to a one-sided share mint and a one-token `donate` or `compound`, and states that it is not a bundle deposit and not a one-token exit. One branch, one outcome per route, one refund rule. The same text is in family PRD `FS-OWN-33`.

### The collapsed candidate is decided, including the one place two sentences could be read as competing

The lock, `Collapsed candidate`, states that zero active liquidity is not the boundary case, and that if the 49% swap cannot be formed or the following add cannot consume its output, the vault returns the input and keeps no swap: a share mint refunds that input and mints nothing, a donate or compound books it and does not refund it.

The only overlap a careful reader can construct is a first deposit whose candidate collapses, because the same paragraph ends with the floor rule: a first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`, and that is not a refund. That sentence decides the overlap against the base rule rather than leaving it open. Family PRD `FS-MONEY-01` (line 414) already states that on the first deposit added liquidity less than or equal to `MIN_SHARES` is rejected with `MinLiquidityNotMet()` and that the first add must exceed 1,000, and family PRD line 326 lists that error. A collapsed first deposit adds no liquidity, so the floor rejection stands where the floor applies, and the collapse refund applies where the floor does not reject the deposit. The plan author writes both sentences as stated and does not have to rank them for the owner.

### The exit basis is named in four parts, and the base agrees

The lock, `Exit receipt`, and owner item 3 give the receipt in the same four parts: swap proceeds, withdrawn requested-token principal, that holder's requested-token fee portion, and that holder's requested booked claim. It is not the swap proceeds alone and it is not a stale preview, and an incomplete exit raises `AmountOutNotMet` and does not burn. Family PRD `FS-OWN-30` carries the identical statement, including that the returned `amountOut` is that payment and that `minAmountOut` binds it.

Family plan section 9 still carries the narrower 2026-11-05 wording, "the swap proceeds plus the withdrawn amount sent to the recipient". That is a precedence question the admitted base already answers, not an open product choice: the family PRD precedence clause puts the 2026-11-06 lock above the 2026-11-05 lock, and F2's fix direction defers to the 2026-11-06 lock by name. The plan author copies the four-part receipt and the `AmountOutNotMet` rejection, which is what F1 and F2 together require.

### The gas set is enumerated, and the ceilings are unchanged

Owner item 5 requires a gas test for every supported economic money and maintenance route, withdraws the count of six, names the seven standalone routes (`exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`), states that `setOperator` and `setOperatorFor` are appointment calls rather than routes, requires a composed measurement for each section 12 row the plan names, and keeps 11,900,000 for a cold standalone body, 12,000,000 for a composed transaction, and 5,000,000 for a preview. Withdrawing a count and then enumerating is not a contradiction, and the family plan section 13 and section 2 carry the same list and the same ceilings. Family plan section 16 item 6 already names the same set, so the plan author writes seven standalone measurements plus the composed rows the plan section 12 names.

### Each remaining item carries a copyable requirement

F5 and owner item 1: the six infrastructure bindings are components, each is checked for code, a missing or code-empty value reverts `InvalidComponent` with no partial diamond. F6: remove the booked getter, and add no production booked view to satisfy a parent. F7: check the parent interface requirement before removing the capacity declarations; that is a code check the text assigns, not an owner choice. F8 and owner item 2: keep the weighted two-leg `setUp` override, and the three-leg file stays the `n == 3` override. F9 and owner item 4: add the missing FS-A01 through FS-A04 assertions and do not add an `exchangeRate` test. F10: assert the exit rejection in `Money.t.sol`. F11: a measurement for each named standalone route and each named composed row, with an oversized route recorded as unresolved rather than passed.

### The scope of the one plan file is stated, including what it does not close

The lock, `Migration scope`, states that this remediation does not walk the preview-consumer index and does not certify that migration, that the family plan still requires it, and that this pass does not close it. The plan author therefore knows what the remediation file covers and what stays with the base plan. Nothing in that boundary needs an owner decision.

### The PRD's unresolved list holds no open product choice

The list is marked not adopted and not rejected, and I checked each item against the current text. The zero-added-liquidity bypass is answered by the lock's floor sentence and `FS-MONEY-01`, as above. The share-burn allowance note is settled by the base: family plan section 7 states that share burns use the caller's own share balance or allowance and that parked shares are not that credit, so the note describes a code-to-text gap, not a choice. The migration and index-anchor items are excluded from this pass by the lock itself. The remaining items are code-verification questions of the kind a plan author resolves while reading the files, not owner product decisions.

### The prior report's open choices are closed in the current text

I read `docs/research/se-fullspread-remediation-readiness-20261105-r2/REPORT.md` only to test whether it left a choice open. It named two: the standalone gas set, closed by owner item 5, and the route outcome for an out-of-range starting price, closed by the lock's `Scope` and `Boundary` paragraphs. Its verdict is not this verdict, and I did not carry it over.

## Coverage

| Target | Status | Reason |
| --- | --- | --- |
| `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` | examined in full | Read whole, including the 2026-11-06 owner lock. Fingerprint recorded as coordinator-supplied, not computed. |
| Family PRD `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | partially examined | Read the precedence clause, the goal and delta tables, `FS-OWN-24` through `FS-OWN-33`, the section 2 authority table, and searched the family tree for `MinLiquidityNotMet`, `MIN_SHARES`, `1_000`, `FS-OWN-33`, `quadratic`, and `48%`. Used only to test the sentences the remediation PRD depends on. |
| Family plan `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | partially examined | Read sections 1, 2, 9, 10, the section 12 fixture rules, section 13, and sections 15 to 16, and searched for `quadratic`, `ladder`, `48%`, `allowance`, and the rounding sentences. Used only to test the sentences the remediation PRD depends on. |
| `docs/research/se-fullspread-remediation-readiness-20261105-r2/REPORT.md` | examined in full | Used to test whether an owner choice remained open. Its verdict is not this verdict. |
| Code files named in the remediation PRD's findings | not examined | The question is whether the text is ready, not whether the defects still exist in the tree. |
| Peer responses, question files, member directories | not read | Out of scope for this pass. |

## Assumptions

- "One remediation implementation plan file" is a delta over the family plan and family PRD, as the question states, so a requirement that the base already carries does not need to be restated in the remediation file.
- The plan author reads the family PRD and family plan as the admitted base, as the brief permits.
- This verdict concerns the product completeness of the text only.

## Limits

- Static reading only. No forge, cast, anvil, npm, bun, install, deployment, wallet, or Git action was run, and none was authorized.
- I did not open the Solidity files the remediation PRD cites, so I did not verify which of the eleven items still exist in the current tree, and I make no claim about code readiness.
- Agreement with the base text is not proof that the base text is right; it only shows the source set is consistent enough to write one plan from.
- `IMPLEMENTATION_PLAN_BLOCKERS.md` is not an admitted source for this run and was not used as one. Incidental search output showed its older 48% ladder wording; the family PRD precedence clause already names that file as overridden by the 2026-11-06 lock, so it does not reopen the sizing choice.
- The prior readiness report's ready verdict is not evidence for this verdict. The 2026-11-06 lock is what closed the sizing question, and the prior report does not cover the current text.

## Conclusion

The current remediation PRD names one sizing instruction, one out-of-range branch, one collapsed-candidate rule, one exit receipt basis with its error, one enumerated gas set with its ceilings, one component-check rule, one exchange-rate withdrawal, one scope exclusion for the migration, and a copyable fix direction for each of the eleven items it carries. No product choice in it is open, contradictory, or too unclear to copy. The 2026-11-06 lock replaced the earlier sizing sentences without reopening a question, and the removed sizing method is not required. A later author can write one remediation implementation plan file from this PRD, using the family plan and family PRD only as the base it amends, without asking the owner another product question.

This response does not write the plan, does not authorize implementation, and does not certify the code.
