# Astra — REQ-06 execution confirmation

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewers' notes were read for this confirmation. Read the controlling PRD, final implementation plan and existing execution report in `docs/reviews/apex-req-06-max-redeem/`. The execution report and saved log are untrusted evidence, not an independent run.

## Verdict

**The prescribed source changes were applied accurately, but validation is not green: a retained SharedFacet test expectation conflicts with the new balance-returning behavior.** The executor reports stopping as the plan required. Do not represent this as a successfully regression-validated completion.

The remaining gap is a **test expectation / plan-consistency defect**, not an absent maxRedeem change or a reason to restore a receipt cap, smaller-share search or shortfall branch. The final plan explicitly required retaining the failing assertion, so this is not an unauthorized deviation by the executor.

## Current-source checks

### Production behavior: confirmed

Read `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` in full.

- **73–76:** `maxRedeem` calls `_requireFamily()` and directly returns `ERC20Repo._balanceOf(owner)`, exactly as required. There is no receipt read, zero-preview condition, early balance branch or search in the function.
- Both `_redeemFitsReceipts` and `_largestRedeemableShares` are absent. A scoped search of `contracts/**/*.sol` returned no references to either name.
- **67–70:** `maxWithdraw` remains `previewRedeem(maxRedeem(owner))` after family validation.
- **96–98:** `previewRedeem` still delegates to `convertToAssets`.
- **128–146,148–166:** `withdraw` and `redeem` retain their existing max checks, preview calculation, share consumption and receipt transfer. No new capacity cap or shortfall branch appears in them.
- The inspected neighboring function bodies match the pre-edit source directly read earlier in this session, with expected line shifts after deletion. No whole-repository historical diff was independently computed; the report's broader no-other-production-change statement remains a scope claim rather than independently authenticated history.

The existing max comparisons inside withdraw/redeem are not newly introduced receipt caps. Changing maxRedeem's return necessarily changes what the unchanged maxWithdraw composition can return. A frozen function body does not imply a frozen return value when its callee changes.

### Named behavior tests: confirmed

File: `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol`.

- **189–204:** the formerly capped case now asserts `maxRedeem(_actor()) == balance` at **202** and `maxWithdraw(_actor()) == fullPreview` at **203**. The old cap computation, capped redemption and dependent `paid` assertions are gone; no dangling payout local remains.
- The fixture through the existing full-preview-versus-held assertion remains at **191–201**, as the **final plan at 46** expressly ordered. This confirmation follows that final plan, not my earlier draft's different removal boundary. No new shortfall rejection expectation was added.
- **207–225:** the existing zero-preview fixture now expects the owner's balance at **224**, while retaining the zero asset-preview/maxWithdraw assertions as directed.
- **171–187:** `test_maxRedeem_fullBalancePayableAtNonIntegralRate` remains present and matches the previously inspected content.

The retained test names and one assertion message still refer to the older cap terminology, but the final plan selected those existing tests without requiring renames. That wording is not the cause of the failed validation discussed below.

### SharedFacet: requested edit present; earlier retained assertion blocks it

File: `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:167–188`.

- The fixture deposits before checking the caps at **179**.
- **183** correctly compares maxRedeem with `IERC20(se2).balanceOf(u)`.
- The old `redeem(1)` and zero-maximum `ERC4626ExceededMaxRedeem` expectation are gone.
- **182** still expects zero maxWithdraw; **185–186** still expect `withdraw(1)` to fail at a zero maximum, exactly as final plan **73** instructed.

The separate exclusion at `APEX_D46_CapacityFixtures.t.sol:82–83` remains a `ShortRedeemERC4626` assertion, not a cap added to the shared target. No change to that unrelated contract is warranted.

## Astra finding — REQ06-CONF-1: retained zero-withdraw oracle prevents validation closure

- **Defect class:** Stale test expectation / final-plan consistency gap.
- **Severity:** Low.
- **File and line:** `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182`; related old zero-maximum expectation at **185–186**. The instruction to preserve them is `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.plan.md:73`.
- **Intended behavior:** The owner requires maxRedeem to return the account's share balance, while leaving the implementation of maxWithdraw unchanged. That implementation returns the preview of this balance. Tests must not demand the withdrawn receipt-cap result.
- **Facts:** Current source contains the balance return and the retained zero-maxWithdraw assertion. The saved execution record reports that assertion failing with a nonzero maxWithdraw result in both the SharedFacet suite and its inherited recurrence suite. The new maxRedeem assertion at 183 is after the failed assertion, so it was not reached in those reported runs.
- **Broken invariant:** The retained test assumes zero maxWithdraw follows from zero held receipts even though maxWithdraw is now composed with the full owner balance. This is inconsistent with the required change and prevents a green selected regression run.
- **Impact class:** Regression validation blocked / intended maxRedeem assertion not exercised in the failing fixture; not demonstrated asset loss or missing production cap.
- **Fix direction:** Keep the production balance return and unchanged neighboring implementations. Return to the coordinator for an explicit test-only amendment that aligns the retained maxWithdraw assertion with `previewRedeem(balanceOf(u))` and removes or revises the obsolete zero-maximum withdrawal expectation. Do not add a new shortfall expectation, change custody, restore a receipt cap or silently edit beyond the executed plan. Then perform the newly authorized validation; no such edit or run is done here.
- **Confidence:** High on the source dependency and contradictory retained oracle; the exact runtime result is corroborated only by saved evidence, not independently reproduced.

The later `withdraw(1)` expectation is also based on zero maximum, but the saved failing run stops at 182. I do not claim it independently executed or identify its eventual revert bytes from that run.

## Saved validation evidence

`EXECUTION_REPORT.md` exists. Its **16–20** command matches final-plan **82–85**: the changed production target plus the complete ERC-4626 spec directory, with no individual-test filter. It records initial compilation followed by a host proxy crash, then a same-command retry exiting **1**, with **173 passed, 2 failed, 0 skipped** across 22 suites.

Direct search of `forge-validation-unsandboxed.log` corroborates:

- The three named maxRedeem behavior tests have saved pass entries at **86–88** and **175–177**, covering the two behavior suites.
- The retained zero-maxWithdraw test fails at **204** and **236**, showing `99900099900099900099 != 0`.
- **271** records the aggregate 173/2/0 result.

`ReceiptBackedERC4626_APEX_Recurrence.t.sol:7,10` directly imports and inherits `ReceiptBackedERC4626_SharedFacet_Test`, explaining why one inherited test defect appears twice. These are not evidence of two independent production defects.

The report at **36** says further remediation stopped, preserving the plan's failure gate at **88**. The current retained assertion is consistent with that stop. Historical command authorization, no subsequent edits and whole-tree scope are not independently authenticated by source reads. A saved Forge log is not an independent reviewer rerun.

## Disposition and examined files

Source-edit conformance is confirmed for maxRedeem, both helper deletions and the named balance assertions. No new production receipt cap or shortfall branch was found. **Validation remains blocked by REQ06-CONF-1.** The correct next step is coordinator disposition of that test-only inconsistency, not production repair or an unqualified completion claim.

Files examined without another scoped implementation defect: the production target in full; the behavior tests at **171–235**; the separate capacity fixture at **79–85**; and the recurrence inheritance declaration. The SharedFacet range contains the retained oracle gap above. Also read the final plan, controlling PRD and execution report in full, and inspected the saved-log result lines. All supplied inputs were present; the assigned output was absent before writing. No other reviewer artifact was read.

Only this assigned Markdown report was created. No code, test, PRD, final plan, execution report, original review, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
