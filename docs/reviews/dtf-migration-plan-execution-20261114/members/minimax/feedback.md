# Identity

- Run ID: `dtf-migration-plan-execution-20261114`
- Member label: `minimax`
- Phase: `advisory review`
- Requested role: `council-member`
- Actual role, model, reasoning, task ID and session ID: not exposed
- Fresh or continued: continued
- Initial response path: `docs/reviews/dtf-migration-plan-execution-20261114/members/minimax/response.md`
- Initial response preserved: yes
- This file replaces a missing initial response: no
- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no
- Owned path: `docs/reviews/dtf-migration-plan-execution-20261114/members/minimax/feedback.md`

# Draft under review

- Draft ID: `draft-dtf-migration-plan-execution-20261114-r1`
- Path: `docs/reviews/dtf-migration-plan-execution-20261114/coordinator/draft.md`
- Coordinator-supplied SHA-256: `fe07f9fa6ed3e8e2b875d4fcfa8884a1b9aedd62196128bd868dbb3af0ff414c`
- Fingerprint status: the draft's own fingerprint line reads `not computed`. I did not recompute the hash and I do not record the supplied value as independent verification. I am not asserting the file matches that digest; I am reporting on the file I was able to open at that path.
- The file opened successfully. I reviewed it as read.

What I independently re-verified against the repository at HEAD (`c33f70683cbaabfedc2dbce1142fdd65660d4cf3`) rather than accepting the draft's or any member's characterization:

| Draft item | Locator as stated in draft | My verification |
| --- | --- | --- |
| D1 | `docs/incidents/2026-09-16-dtf-recovery/migration/` holds only `operator-runbook.md` and `quote-evidence.md` | Confirmed by directory listing; `find . -name 'verification.md'` over the repository returns no match. Absence of `source-manifest.json`, `source-route-matrix.md`, `surrender-spec.md`, `package-evidence.md`, `verification.md` and of a fork-run receipt set confirmed. |
| D2 | `quote-evidence.md` lines 1-8 and 165-175 | Line 6 carries the `DoneClaim` disclaimer ("not completion of task 2 ... E3 ..."). Line 167 carries "There is no identified production recovery binding" and the list of models "**not implemented or certified**". The draft's characterization is accurate. |
| D4 | `scripts/recovery/dtf-migration/execution.ts` lines 98 and 185; `preparation.ts` lines 110 and 134 | All four locators confirmed exactly: `fullTask9: "open"` on the simulate return (98), on the receipt return (185), in the prepared domain (110), and in the `blocked.json` payload (134). |
| D5 | Plan section 4 names `TestBase_UniswapV4DetfMigration_Adversarial.sol` | Plan line 218 names it verbatim. `git ls-files` shows adversarial bases across other families but no `TestBase_UniswapV4DetfMigration_Adversarial.sol`. Absence confirmed. |
| D6 | Diff of `UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`; `rawOutput` at lines 156-160 | The before/after semantics are confirmed: the old direct-pair branch assigned `Math.descale` and reverted only on `amountOut >= rawReserves`; the new shared `rawOutput` adds `if (amountOut == 0) revert Math.ZeroAmount()`. **The line locator is wrong** — see Concern 2. |
| D7 | `MigrationLegacyNftLib.preview` rejects `tokenId_ < 3`; `_configureNftEntitlements` applies `input_.tokenId < 3` without a collection test; "Plan line 171" | Both code checks confirmed as I read them in the initial pass. Plan line 171 is exactly the Weighted NFT row reading "Fixed-principal position; reserved IDs are not user purchases". **The section-6 citation for the actual-state rule is wrong** — see Concern 3. |
| D8 | `_administrationSelectors` allocates 16; two removable facets declare eight functions each; runbook says "all eleven" and "all twelve" | Confirmed: `selectors_ = new bytes4[](16)` at `UniswapV4DetfMigrationAllocationTarget.sol:282`; the two facets expose 8 + 8; runbook line 985 reads "all eleven" and line 1179 reads "all twelve". I also verified independently that the union of the two facets' `facetFuncs()` equals all 16 entries, so the cut is complete and this is a stale census only. |

Draft verdict text, findings D1-D8, the preserved-disagreements table, the coverage table and the limits section are, on everything I checked, accurate and faithful to the source material.

# Disposition

**support-with-reservations**

I support the draft's proposed text and its eight findings. The negative sentence is correct, each finding I re-verified stands on its locator, the disagreements are preserved rather than smoothed, and the draft correctly refuses to convert static reading into a passing test run or into authorization.

My reservations are three precision points, all in the "Preserved disagreements" table and in two locator citations. None of them changes the verdict, and none of them requires re-running any part of the review. They are recorded as advice below; I have not edited the draft, `RUN.md`, the resolution, the final, or any project code.

# Concerns

## C1. The gas row attributes to me a position that the runbook's deployment section narrows, and it points at the wrong place in the file

- **Draft section:** "Preserved disagreements" table, row "Historical parent-deployment gas".
- **Why two readers could diverge, and why the locator is wrong.** The row records that "MiniMax treats the runbook's 42,985,865 and 44,353,454 figures, against a recorded 32,000,000 limit, as an open feasibility gate", and attributes the counter-position to a constraint in "the runbook opening". The constraint is not in the opening. The runbook's opening (lines 1-8) is the scope statement. The split-deployment text is in the section **"Bounded deployment and interrupted preparation"**, lines 63-84, and reads: "The registered Migration package now requires `prepareSyChildren(fullArgs)` before `deployVault(fullArgs)`. Preparation constructs the bound, unreserved bond and both empty SY children; the final transaction creates and publishes the complete parent." and "Deployment simulation, estimation, signing and resumed intents are constrained to 32,000,000 gas per transaction. A larger Anvil block limit is not a larger permitted deployment envelope." In the initial response I read only lines 1-60 of that file, so I cited the historical monolithic figures (line 853 and the closing paragraph) without the current two-transaction path in view. That was my gap, not the draft's. A reader of the draft row can plausibly conclude that a member asserts the *current* deployment exceeds the target limit, which the runbook text contradicts; the row's own "Not resolved" cell already says "The historical monolithic figure is not proof that the current two-step deployment exceeds 32,000,000", so the row simultaneously asserts and withdraws the point. The open item that genuinely survives is narrower: no mined bound is recorded for the current two-transaction path.
- **Requested change (advice, not an edit):** in that row, replace "the runbook opening" with the section and line range — "Bounded deployment and interrupted preparation", lines 63-84 — and state explicitly that the current deployment path is split and each transaction is constrained to 32,000,000 gas, so the 42,985,865 and 44,353,454 figures describe the superseded monolithic path. Reduce the surviving open item to the absence of a recorded mined bound for the current path, which is already covered by the absent `migration/verification.md` (D1). If the row is retained as a disagreement, describe it as a disagreement about how much weight the superseded figures carry, not as an open question about whether the current path is bounded.

## C2. D6's `rawOutput` line locator is wrong by three lines

- **Draft section:** D6, "Location".
- **Why the locator is wrong.** The draft states "Current `rawOutput` at lines 156-160". In `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol` at HEAD, `rawOutput` is declared at **lines 159-163**. Lines 156-157 are the tail of the neighbouring `exactInputBudget` helper (`if (budget >= ratedOut) revert Math.WouldZeroReserve();` and its closing brace). A reviewer following "lines 156-160" would read two lines of the wrong function and the first two lines of `rawOutput`, and would miss the `Math.ZeroAmount()` revert on line 162, which is the entire substance of the finding. The direct-pair call site is line 170, inside `_outputBudget` declared at line 165.
- **Requested change (advice, not an edit):** restate D6's locator as `rawOutput` at lines 159-163, reached from the direct-pair branch at line 170 in `_outputBudget` (line 165). While the finding is being edited, name the second consumer explicitly: `UniswapV4DetfMigrationSnapshotLib.sol` line 173 calls the same `Claim.rawOutput`, which is why the helper carries the zero-revert and why the fix direction must separate the frozen-evaluator behavior from the ordinary live path rather than remove the check.

## C3. D7 cites the wrong plan provision for the "actual state" rule

- **Draft section:** D7, "Requirement".
- **Why the locator is wrong, and why two readers could diverge.** The draft states "Section 6 rejects burned or empty positions by actual state, not by an unstated earlier-collection id floor." Section 6 ("Planned callable surfaces and routing") contains no such sentence; its NFT surrender row says "verify remaining position", which is weaker and does not state the burned/empty rule. The rule the finding is measured against lives in **MIG-P04** in the section 1 table ("A burned, nonexistent or empty old NFT earns no migration credit ... Check the actual position at surrender; configuration is not proof that principal remains") and in **section 5.4** ("Read the authoritative state in the same protected operation that takes custody ... Burned/nonexistent NFTs and reward-only positions fail even if configured"). A reader who checks section 6 will not find the requirement and may reasonably think D7 overstates it; a reader who checks MIG-P04 and 5.4 will see that the divergence is real and sharp.
- **Requested change (advice, not an edit):** cite MIG-P04 and section 5.4 for the actual-state rule, and keep section 6 out of that citation. If D7's argument needs the section 3 "both NFT models" row, cite that separately. The substance of D7 — that the weighted-specific reserved-ID note at plan line 171 is applied in code to both collections, and that the earlier collection's token 0-2 occupancy was never read — should stay exactly as written.

# What was not adopted from others

- **No peer response or peer feedback file was read.** The only member-derived material I saw is what the coordinator reproduced inside this draft. I did not treat the draft's reproduction of a member position as that member's verified statement; I re-verified the underlying locators against the repository.
- **I did not adopt the draft's attribution of the gas point to me as a live member disagreement.** Concern 1 states why, and narrows my own initial F4 accordingly.
- **I did not adopt "Astra reported no ordinary-family regression in the 25 shared hunks" as covering D6's hunk.** I read the claim-lib diff myself in this pass. The old direct-pair branch assigned `Math.descale` and reverted only on `amountOut >= rawReserves`; the new shared `rawOutput` adds the `Math.ZeroAmount()` revert on a zero descale. That delta is real. The draft's decision to decline Astra's general report for this specific hunk is correct and I endorse it.
- **I did not adopt any position on D7's severity or on the earlier collection's reserved-ID occupancy.** Nobody read the earlier collection's token 0-2 state. D7 stands as the draft states it: a plan-text divergence with unread occupancy, not a demonstrated theft, and not a basis for either a stronger or a weaker claim.
- **I did not adopt the draft's "The four responses agree on that negative sentence" as independent evidence.** I verified only my own response. The agreement is the coordinator's characterization of its own inputs.
- **I did not adopt the draft's D2 library characterization without re-reading it.** I re-read `UniswapV4DetfMigrationSnapshotLib.sol` in the initial pass and confirmed the evaluator reads only the captured book with no live preview fallback, which is what D2 reports; I confirmed the document-side disclaimer separately at lines 6 and 167.
- **One item I did adopt, against my own initial coverage: D5.** The draft records that "MiniMax did not separately name it". That is accurate. My initial response did not raise the absent `TestBase_UniswapV4DetfMigration_Adversarial.sol`, and it should have: plan line 218 names it, and `git ls-files` confirms no such path in the migration tree. I have now verified both and adopt D5.
- **Not read and therefore not adopted at all:** the r20 draft PRD as a requirements source (plan section 1 governs); any claim about what the fork suites or the section 10 commands produce, since no member ran them.

# Limits

- **Advisory only.** This is not a veto, it does not authorize implementation, deployment, funding, activation, a plan edit, or any code or configuration change, and it does not replace the draft or the final artifact. It does not authorize the D1-D8 fix directions.
- **Static review.** I ran no `forge build`, `forge test`, `forge script`, fork suite, Bun script test, install, deploy or wallet operation, and I performed no Git write. Every statement above is a statement about source and committed documents, not observed runtime.
- **Hash not verified.** I did not recompute the coordinator-supplied SHA-256 and do not assert the file matches it. The draft's own fingerprint line reads `not computed`. I reviewed the file I opened at the stated path; if the coordinator's copy differs from that file, this feedback does not apply to it.
- **What I read for this pass:** the draft; the plan (sections already read in the initial pass, plus lines 171 and 218 re-read); `operator-runbook.md` lines 63-84, 953-970, 985, 1179 and the closing paragraph; `quote-evidence.md` lines 1-8 and 160-180; `scripts/recovery/dtf-migration/execution.ts` lines 92-102 and 180-190; `scripts/recovery/dtf-migration/preparation.ts` lines 105-140; the `UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol` diff between the two named commits; `UniswapV4DetfMigrationSnapshotLib.sol` line 173; `UniswapV4DetfMigrationAllocationTarget.sol` line 282; `git ls-files` output for adversarial bases.
- **What I did not read:** every peer response and peer feedback file; the `MIGRATION_DETF_DRAFT_PRD.md`; the `sy/`, `sy/rewards/`, `invariant/` migration subtrees; the V3 full-spread shared hunks; the operator script modules beyond the two D4 files; any test body end to end. My initial response's coverage limits stand unchanged, including that section 11 conditions C1, C6 and C7 are stated as blocking a positive "executed completely and correctly" sentence.
- **Residual uncertainties I did not resolve and do not assert:** whether D6's zero-output dust case is reachable by any production quote; the earlier collection's reserved token-ID occupancy; whether the absent `migration/verification.md` would contain a mined bound for the current split deployment; and whether the operator rehearsal described in the runbook has ever been run at the current commit.
- **Concern 1 narrows my own initial position.** My initial response F4 stated that the deployed instance may be undeployable on the target chain, citing the 42,985,865 and 44,353,454 figures. Having now read the runbook's deployment section, I would restate that finding as: the historical monolithic deployment is superseded by a split path that is per-transaction bounded at 32,000,000 gas, and what remains open is the absence of a recorded mined bound for that current path. The draft's decision not to let the historical figures stand as a current defect is right, and I record the correction on my side rather than against the draft.
