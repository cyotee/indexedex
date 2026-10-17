# Astra — Stage-1 REQ-03 cross-review

**Date:** 2026-10-14 review round. I read the three supplied originals in full as untrusted evidence and re-read the disputed tests, scanner, supporting call path, and controlling REQ-03 text. This is one cross-review; my original remains unchanged. No code or coordinator PRD was written.

## 1. Reentrancy: retain partial, but do not require the wrong outer selector

**Agree with Kimi's gap diagnosis and MiniMax's partial verdict; dissent from Grok's already-satisfied verdict. Retain Astra-REQ03-1, Medium, test-oracle impact only.**

Re-read `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:28-32`: the exact nested-result assertions execute inside the callback, followed by an unconditional revert. The outer test at `:128-146` expects `TransferFromFailed` and checks rollback. `contracts/test/stubs/ReentrantERC20Harness.sol:68-75` propagates observer failures, and `lib/crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol:248-252` converts a failed token call to that same outer error.

The problem is not that `IsLocked` appears in a helper rather than on the outer test line. It is that a failing helper assertion can be normalized into the expected outer result. My original's native reverting-assertion analysis remains applicable; actual installed-runner behavior was not executed here. The callback also lacks an independent occurrence witness, so an earlier transfer failure must not be accepted as proof that the nested guard ran.

**Required outcome:** prove that the nested money call was attempted and returned exactly `IsLocked`, through an observation/assertion mechanism that the outer error normalization cannot erase. Preserve the existing no-partial-credit assertions. Confidence is high on the source-level masking path; no production lock defect is claimed.

Two peer fix directions need correction:

- **MiniMax G2:** REQ-03 line 232 does not demand that the outermost selector be `IsLocked`. Production wraps the failed token pull. Merely making the token return success after observing a nested failure would not make the outer call revert with `IsLocked`. Do not change production error propagation or weaken the test to satisfy a literal reading of one expectation line. Keep the legitimate outer transfer-error expectation where appropriate and separately verify the nested result.
- **Kimi P-1:** storing `(ok, reason)` on the test contract immediately before the observer reverts does **not** preserve it. That storage write is in the reverting callback subtree and rolls back, even though the storage belongs to the test contract. Use genuinely surviving observation or a separate successful observation control alongside the rollback control; do not prescribe ordinary storage-before-revert as the solution.

## 2. Minimality success: withdraw my mandatory total-supply addition

**Agree with Grok, MiniMax, and Kimi that this bullet is already satisfied in the current test source. Withdraw Astra-REQ03-2 as a mandatory REQ-03 remediation.** This corrects my original interpretation; it does not erase the original finding.

Re-read `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol:57-101` and controlling PRD `:233`:

- Lines 70-84 pin the exact short-funding error and unchanged recipient shares, total supply, caller/vault assets, and reserve.
- Lines 96-100 assert exact payment, recipient shares, caller debit, vault credit, and reserve on success.
- `contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol:62-74` deploys a fresh vault and funds underlying tokens, not pre-existing vault shares. The absolute recipient-share assertion fits this fixture.

The factual observation in my original remains true: success does not assert total supply. However, REQ-03 asks for exact shares, balances, and reserves on success; these are explicitly checked, and it does not separately mandate a global issuance-conservation assertion. The hypothetical extra-mint scenario in my original is a possible strengthening, not sufficient grounds to impose additional work under this bounded requirement.

**Disposition:** no new requirement for the fuzz success half. Preserve both existing halves; no broader fuzz fixture, total-supply requirement, or production mint change is opened here. Source satisfaction is not a passing-run claim.

## 3. Scanner: confirmed exclusions, but required-inventory membership remains unverified

**Agree with Kimi that the cited files escape the current selection. Dissent that this alone confirms a violation of the “D16 regression inventory used for R2.4” clause. Retain my unverified full-inventory disposition.** Grok's distinction is appropriate. MiniMax's inventory-evidence caveat is also appropriate, but does not support an unconditional file-list expansion.

Re-read evidence:

- `scripts/apex_bare_expectrevert_scan.sh:14-26` selects two roots, two explicit custody files, and qualifying APEX-marked files.
- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:332,335,383,409` contains bare expectations. Its path is outside the roots and explicit custody list, and a search matching the scanner's marker-boundary semantics found no qualifying APEX marker.
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:131,143` likewise contains bare expectations, is not explicitly included, and has no APEX marker.

**Confirmed fact:** these are exclusions containing unpinned negatives. **Unverified proposition:** that these exact files belong to the approved current regression inventory used as R2.4 remediation evidence. D16 family membership is not by itself the missing file-level evidence mapping. Kimi's own original acknowledges that the definitive inventory was not derived. The user's instruction requires marking that sub-bullet unverified rather than inventing the inventory.

The appropriate next evidence is the current D16/R2.4 suite mapping established under `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` and its referenced evidence inventory, with applicable later scope decisions. If that mapping includes the cited files, their exclusion becomes a confirmed bounded scanner gap. Until then, do not mandate those files or all sibling tests as inventory members merely because a search found bare expectations.

Also correct MiniMax G4's output criterion: scanner lines 36-41 write **violation sites**, not every selected clean file. Requiring one row per inventory file in that output would change its meaning. Coverage should be compared against the selected-path set or an appropriate selection manifest, not inferred from absence in the violations report. The two originally named custody files are already explicitly covered at lines 18-23; leave that fix intact.

## Consolidated disposition and unresolved dissent

| REQ-03 bullet | Astra final cross-review position |
|---|---|
| Ownership negative | Already satisfied; unchanged from original. |
| Reentrancy exact nested guard plus no partial credit | Partial; retain Astra-REQ03-1 with the oracle-focused requirement above. |
| Minimality rejection and success | Already satisfied; withdraw Astra-REQ03-2 as required work. |
| Scanner custody inclusion / full D16 inventory | Named custody inclusion satisfied; cited exclusions confirmed; full required-inventory coverage unverified. |

Remaining dissent is with Grok on the nested-error oracle and with Kimi on promoting scanner exclusions to confirmed required-inventory omissions without the mapping. I also reject the ineffective outer-selector/storage-before-revert remedies identified above. No production guard changes, broader `expectRevert()`, invented D16 list, or new product work are proposed. Independent runtime outcomes remain unverified.

I did not run Forge.
