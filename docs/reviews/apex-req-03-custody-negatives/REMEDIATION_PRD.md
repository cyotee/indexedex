# Remediation PRD — close the remaining REQ-03 custody-test gaps

- **Status:** DRAFT
- **Date:** 2026-10-14
- **ID:** REQ-03
- **Origin:** Stage-1 REQ-03 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`, lines 223-235.
- **Review target:** Current custody tests and `scripts/apex_bare_expectrevert_scan.sh`.
- **Astra participation:** Substantive first pass and substantive cross-review. Session `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No resubmission. Cap not used.
- **Other reviewers:** Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi K3 is the labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. All four cross-reviews completed.
- **Execution evidence:** No Forge run in this round. A present assertion is not a pass.
- **Completeness review, 2026-10-14:** Four independent first passes and four cross-reviews. Astra and Grok found two remaining mechanism choices. MiniMax and Kimi called those coding details. The owner rule is that an implementer does not choose. Both choices are now specified in REQ-03-R1 and REQ-03-R3. No implementer decision remains.
- **Implementation plan:** [REMEDIATION_PRD.plan.md](./REMEDIATION_PRD.plan.md) names the observation test, the two fields, the salt, the finish witness, and the commands. An implementer follows that plan and does not choose again.

Writing this PRD does not authorize editing tests, source, config, or scripts in this session. A later session must be explicitly asked to implement it.

## Required outcome

Only the gaps below remain. The ownership test is already satisfied and is not reopened. The production bytecode check stays. No broader `expectRevert()` is added.

## Already satisfied, not reopened

- **Ownership.** `test_ADV_cannotBurnOtherHolderViaInternalSy` uses a contract caller, expects `TransferDeltaInsufficient(shares, 0)`, and asserts the other holder's shares are unchanged (`RebasingAwareERC4626_Adversarial.t.sol:50-60`). The bytecode check at `RebasingAwareStandardYieldTarget.sol:57-59` remains. Do not weaken it so a wallet test can pass.
- **Minimality rejection.** `testFuzz_FUZZ02_exactOutMinimals` expects `MaxAmountExceeded(need - 1, need)` and asserts shares, total supply, assets, and reserve unchanged on rejection (`RebasingAwareERC4626_Fuzz.t.sol:70-84`).
- **Named custody inclusion.** The scanner already names the adversarial file and the fuzz file without requiring an APEX marker (`scripts/apex_bare_expectrevert_scan.sh:18-23`).

## REQ-03-R1 — The nested-guard pin must be able to fail the test

- **Severity:** Medium
- **File and line:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:26-32` and `:128-146`.
- **Intended behavior:** REQ-03. The reentrancy test expects the nested-guard error and asserts no partial credit. A test named for that property must reach it. An unrelated failure must not keep the test green. The locked contract is the rebasing ERC-4626 vault under test, `wrapped` in `test_ADV03_reentrancyDuringDepositReverts`. The nested call is a second `deposit` on that same vault while its own lock is held. This is not an underlying protocol vault, and it is not the Uniswap V4 Upper Lower Wings vault.
- **Broken requirement or invariant:** `observeNestedDeposit` asserts `IsLocked` inside the callback, then reverts. The file says a wrong nested error fails inside that frame and the vault then reports `TransferFromFailed`. The outer test expects that same `TransferFromFailed`. A wrong nested reason, or a failed assertion about that reason, can still become the error the outer test accepts. The unchanged-state assertions do not identify the nested error.
- **Owner ruling, 2026-10-14:** Let the deposit finish. The observation test is a separate call from the rollback test.
- **Acceptance criteria:**
  - The production deposit path is still used. The vault is not mocked. The locked contract is the rebasing vault under test, not an underlying vault and not a Wings vault.
  - In the observation test, add a callback named `recordNestedDeposit` in `RebasingAwareERC4626_Adversarial.t.sol`. It uses the same low-level nested `deposit` call as `observeNestedDeposit`. It writes `nestedAttempted = true` and `nestedReason = reason` on the test contract, then returns without an assertion and without a revert. After the outer deposit finishes, the test asserts `nestedAttempted` and asserts `nestedReason` equals `abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)`. A wrong nested error, or a nested success, fails this test. Do not use an event, another contract, or a harness change for that record.
  - Reuse `ReentrantERC20Harness` unchanged. Keep `bubbleRevert` true. Point only the observation test at `recordNestedDeposit`. The existing rollback test continues to use `observeNestedDeposit`.
  - The existing rollback test stays. Its outer call still reverts `TransferFromFailed`, and its no-partial-credit assertions for supply, recipient shares, vault assets, and reserve stay. That test does not have to carry the nested-error pin.
- **Non-goals:** Do not change production pull wrapping or the bytecode check. Do not require one call both to revert and to leave a readable record. Do not make the outer selector `IsLocked`. Do not replace either test with a bare `expectRevert()`.

## REQ-03-R2 — Exact success must include total supply

- **Severity:** Low. Astra's cross-review withdrew this as mandatory, reading "shares" as the recipient balance already asserted at `RebasingAwareERC4626_Fuzz.t.sol:97`. Grok, MiniMax, and the Kimi replacement kept it because the rejection half treats total supply as part of the named state and the success half does not. This draft includes the one assertion. It is coverage precision, not a claimed extra mint.
- **File and line:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol:65` and `:96-100`.
- **Intended behavior:** REQ-03. On success, shares, balances, and reserves are exact. The rejection half already asserts total supply unchanged.
- **Broken requirement or invariant:** `supplyBefore` is captured and checked on rejection. The success half checks the recipient's shares, the paid amount, both asset balances, and the reserve. It does not check total supply.
- **Acceptance criteria:**
  - After the successful exact-output call, total supply equals the captured supply plus the requested shares.
  - The existing rejection assertions and the existing success assertions stay.
- **Non-goals:** Do not change production minting. Do not widen the fuzz domain. Do not treat this as evidence that an extra mint exists.

## REQ-03-R3 — Bind the scanner to the R2.4 inventory

- **Severity:** Medium
- **File and line:** `scripts/apex_bare_expectrevert_scan.sh:14-26`. Cited escapes, not a complete inventory: `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol` bare `expectRevert` sites, and `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:131` and `:143`.
- **Intended behavior:** REQ-03. The scanner selects the full D16 regression inventory used for R2.4, including custody files that do not contain an APEX marker.
- **Broken requirement or invariant:** The script selects two directory roots, the two named custody files, and files whose text matches an APEX marker. The two cited files contain bare `expectRevert()`, are outside those roots, are not the two named custody files, and were reported to have no APEX marker. Whether every such file belongs to the approved R2.4 inventory was not derived. Family membership alone is not that inventory.
- **Owner ruling, 2026-10-14:** Do not hallucinate filenames, and do not leave the search to the implementer. The PRD writers searched. The implementer selects the directories below and does not decide which families belong.
- **Searched inventory:** These directories exist and contain the named D16 families' regression tests. The two roots already in the scanner stay. Add the rest.
  - Already selected: `test/foundry/spec/hooks/uniswap/v4/standardExchange` and `test/foundry/spec/vaults/standard/exchange/protocols/uniswap`.
  - `test/foundry/spec/vaults/standard/erc4626`
  - `test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue`
  - `test/foundry/spec/protocols/staking/rebasingVault`
  - `test/foundry/spec/protocol/staking/rocket-pool`
  - `test/foundry/spec/protocol/staking/lido`
  - `test/foundry/spec/protocol/staking/etherfi`
  - `test/foundry/spec/protocol/lending/aave/v3.6`
  - `test/foundry/spec/protocol/lending/aave/cross-version`
  - `test/foundry/spec/protocol/dexes/uniswap/v2`
  - `test/foundry/spec/protocol/dexes/camelot/v2`
  - `test/foundry/spec/protocol/dexes/aerodrome/v1`
  - `test/foundry/spec/protocols/dexes/aerodrome/slipstream`
  - `test/foundry/spec/protocol/dexes/balancer/v3`
  - `test/foundry/spec/protocols/dexes/balancer/v3`
  - `test/foundry/spec/vaults/detf`
- **Acceptance criteria:**
  - Add each directory on this list that is not already in `roots` to the existing `roots` tuple in `scripts/apex_bare_expectrevert_scan.sh`, in the listed order. Do not add a second selection list or an external inventory file. Leave the `custody` tuple and the APEX-marker scan unchanged.
  - A nonzero `--check` result caused only by existing bare `expectRevert()` calls in newly selected directories is the expected end state of this item. Do not rewrite those tests here, and do not drop a directory to make the check pass.
  - The scanner selects every directory in that list, recursively, with or without an APEX marker.
  - `ERC4626StandardExchange_Routes.t.sol` and `RebasingAwareERC4626_Accounting.t.sol` are selected because their directories are on the list.
  - The two custody files already named in the script stay selected.
  - The scanner still rejects a bare `expectRevert()` in a selected file. It does not rewrite those tests in this item.
- **Non-goals:** Do not add a directory that is not on this list. Do not drop a directory that is on this list. Do not weaken the bytecode check. Do not treat a clean scanner output as proof that an unselected file was checked.

## Dissent

- **REQ-03-R1 fix shape.** MiniMax's first draft would make the outer selector `IsLocked` by changing the harness. Astra, Grok's cross-review, and Kimi reject that. The outer wrapped error may stay. The nested pin must survive the wrap. Ordinary storage written inside the reverted callback does not survive it.
- **REQ-03-R2.** Astra's cross-review treats the missing total-supply assertion as optional strengthening. This draft keeps it because the rejection half already uses total supply and the success half drops it. No production mint defect is claimed.
- **REQ-03-R1 and REQ-03-R3 mechanism.** Astra and Grok's completeness cross-review found two remaining choices: where the observation record is stored, and whether the scanner uses the existing `roots` tuple. MiniMax and Kimi treated those as coding details. Owner rule for this draft: no implementer choice. Both are now specified above.

## Non-goals for the whole draft

No production change. No weaker bytecode check. No broader `expectRevert()`. No Forge run in this review session. No live-instance change. Implementing this PRD requires a separate request.
