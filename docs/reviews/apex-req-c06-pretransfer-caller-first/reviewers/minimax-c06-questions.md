# MiniMax M3 — REQ-C06 targeted question, replacement session

- **Label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. No peer notes were read. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures.
- **Target:** `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md`, read in full (98 lines, DRAFT 2026-10-15).
- **Coordinator's question:** does the council have any owner question that must be answered before a later plan can be written? "We never leave a choice for the implementer." If the PRD already closes every edit, test assertion, and exclusion, write "No blocking question." If one owner decision remains, state that one question and the one sentence that would close it.

---

## Closing of the source-level questions (the implementer is not left to choose)

The PRD at `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` closes every source-level decision the implementer would otherwise face on this item. I walked the PRD top to bottom against the coordinator's "we never leave a choice for the implementer" rule and verified each section:

1. **Review target (`:7`):** "Every in-scope production call of `_pretransferCredit` that still runs before `LocalCreditLib.requirePretransferCaller`." Closed.
2. **Required outcome (`:19-23`):** the closed sentence at `:23` is a single declarative paragraph that fixes the repair scope (21 sites in 7 files), the fix direction (true-flag-only caller check before measurement and any consuming plan), the retention rule (existing credit comparison stays, false flag does not gain the check), the leave-alone set (10 caller-first sites), the recorded-not-edited set (EtherFi, Slipstream), the deleted-tree exclusion (`contracts/protocols/dexes/uniswap/v4`), and the no-further-search rule ("assign no further site search to the implementer"). Closed.
3. **Repair table (`:29-37`):** 7 files, 21 line numbers, each pointing at the credit-measurement line. `:27` says "If a named line no longer assigns `_pretransferCredit`, stop and report. Do not choose another site." Closed.
4. **Exact edit (`:41-51`):** the insert template is given verbatim, the `pretransferred` vs. `prepaid` guard choice is named per site, the V3 mint function gets the explicit relocate (move the line-109 caller check to before line 102) rather than the add, and the V3 mint's later `if (amountIn > credit) revert ...;` and `pullAmount = credit;` stay. The import instruction (`Add the LocalCreditLib import only where the file does not already import it`) is closed. The negative instructions (`Do not insert the check inside the later if (pretransferred) block. That block is after the measurement. Do not move the input-ceiling comparison, the quote, the refund, or the settlement. Keep _requirePrepaidCredit, _secureTokenTransfer, _securePull, and _secureSelfBurn unchanged, including the second caller check already inside them.`) are closed.
5. **Leave alone (`:57-62`):** the 10 caller-first sites are enumerated with the line numbers of their caller check and measurement. Closed.
6. **Do not edit `contracts/protocols/dexes/uniswap/v4` (`:64`):** closed.
7. **Recorded, not edited (`:68-69`):** EtherFi lines 61 and 84 are recorded as the same source defect and excluded by the application non-goal. Slipstream line 85 is recorded and excluded by the deprecation non-goal. Closed.
8. **Acceptance criteria (`:73-78`):** six closed bullets. Bullet 6 (`"One family's test does not close another. The later plan names the existing production-proxy test for each of the seven files. It does not invent a file during implementation."`) is the one place the PRD defers to the plan; the PRD does not name the tests. See "Deferral to the plan" below.
9. **Non-goals (`:82-88`):** seven closed bullets. The do-not-edit EtherFi/Slipstream/legacy V4 line and the do-not-add-`catch` line are closed.
10. **Dissent (`:92-94`):** the three reviewer positions (my first pass's narrow limit, Kimi's refund-only-sites open reading, Grok's inclusion of EtherFi) are reconciled in this draft with the rationale recorded. Closed.
11. **Verification (`:98`):** "Tests use the production proxy. A test-contract caller is not the code-less assertion. Report the commands actually run. A present assertion is not a pass until that run is reported." Closed for the PRD; the implementation runs and reports.

There is no source-level decision left to the implementer. Every named site, every fix direction, every guard choice, every leave-alone site, every recorded-but-not-edited site, every test rule, and every non-goal is in the PRD.

---

## Deferral to the plan (not an owner question)

Acceptance criterion 6 (`:78`) says: "The later plan names the existing production-proxy test for each of the seven files. It does not invent a file during implementation." The PRD does not name those tests; it delegates the naming to the plan. This is a deferred task, not a deferred owner question:

- The plan author can run a search to identify the existing production-proxy test for each of the seven files. The test directories mirror the source structure (`test/foundry/spec/protocols/dexes/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/`, `test/foundry/spec/protocols/dexes/uniswap/v3/`, `test/foundry/spec/protocols/dexes/uniswap/v2/`, `test/foundry/spec/protocols/dexes/camelot/v2/`, `test/foundry/spec/protocols/staking/{rocket-pool,lido}/`). Each family has an existing `_IFacet_Test` or behavior test that exercises the `_pretransferCredit` paths the PRD is fixing. The plan author names the specific test file per file.
- The implementer runs the tests the plan names. The implementer does not search.
- The PRD's "It does not invent a file during implementation" rule is the closure on the test-creation choice. The implementer does not write a new test.

The owner has not been asked to choose between test files, and no owner decision would change which test is the right one. The plan author's search is a documentation task, not an owner question.

---

## Other deferred items that are not owner questions

- **Toolchain and artifact workflow:** the PRD does not specify Foundry version, `cache_path` / `out` paths, or the `forge-artifacts.py` invocation. The repository's `CLAUDE.md` and `INDEXEDEX_AGENT_LAW.md` govern these, and the PRD does not override them. No owner question.
- **The `If a named line no longer assigns _pretransferCredit, stop and report. Do not choose another site` rule at `:27`:** this is itself a closure — the implementer stops and reports, and the owner then decides whether the source drifted. No owner question before the plan is written.
- **Whether the search instruction at `:7` is exhaustive enough:** the cross-review history in this directory confirms 21 sites in 7 files plus the recorded EtherFi and Slipstream sites. The PRD's "assign no further site search to the implementer" rule at `:23` closes the search choice.

---

## Answer

**No blocking question.**

The PRD at `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` closes every edit, every test assertion, and every exclusion that a later plan or implementer would face on this item. The implementer is not left to choose. The plan author can write the plan by:

1. Naming the existing production-proxy test for each of the seven files in the repair table (`:29-37`) by searching the test tree at the directories listed in the Deferral section above.
2. Writing the plan around the PRD's closed sentence at `:23` and the PRD's exact edit at `:41-51`.
3. Running the test plan on the production proxy per the verification section at `:98`.

No owner decision is required before that work. If the owner later wants to amend the recorded EtherFi or Slipstream treatment, that is a separate decision recorded as an amendment and not a blocker for the current plan. The PRD's status remains DRAFT; moving it to ACCEPTED is an owner signature on a document that already has nothing left to ask.

I did not run Forge.