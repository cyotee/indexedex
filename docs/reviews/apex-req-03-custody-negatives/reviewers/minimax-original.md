# MiniMax M3 — REQ-03 coverage gap original

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent first pass. No peer artifacts were read. No reviewers/ directory was opened. I did not write `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`.
- **Question:** Which acceptance bullets of Stage-1 REQ-03 are still open in the current tree, and what exact PRD requirements would close only those gaps?
- **I did not run Forge.** I re-read the controlling PRD section, the named test files, the scanner, the production guard, and a small slice of the D16 inventory document.

## Re-reads this round

- `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:223-235` (REQ-03 controlling text)
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol` (full read, 225 lines)
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol` (full read, 220 lines)
- `scripts/apex_bare_expectrevert_scan.sh` (full read, 47 lines)
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:38-67` (production guard)
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:325-340` (D16 inventory)
- `docs/audits/apex-2026-09-17-review-open-items.md:11, 21` (D16 reinforcement)

## Bullet-by-bullet verdict

### Bullet 1 — ownership test

> The ownership test uses an allowed contract caller, expects the precise share-accounting error, and asserts the other holder's shares are unchanged. (PRD line 231)

Current test: `RebasingAwareERC4626_Adversarial.t.sol:50-61` (`test_ADV_cannotBurnOtherHolderViaInternalSy`).

- Allowed contract caller: yes. `AtomicPretransferCaller caller = new AtomicPretransferCaller();` at line 55, then `vm.prank(address(caller))` at line 56.
- Pinned error: yes. `vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, shares, 0))` at line 57.
- Other holder's shares unchanged: yes. `assertEq(IERC20(address(vault)).balanceOf(alice), aliceShares, "other holder shares unchanged")` at line 59, plus the reserve unchanged assertion at line 60.

The original PRD criticism ("uses bare `vm.expectRevert()` and calls internal-balance redeem as `bob`") is resolved. The contract caller, the pinned share-accounting error, and the other-holder assertion are all in place.

**Verdict: already satisfied.**

### Bullet 2 — reentrancy test

> The reentrancy test expects the nested-guard error and asserts no partial credit. (PRD line 232)

Current test: `RebasingAwareERC4626_Adversarial.t.sol:128-147` (`test_ADV03_reentrancyDuringDepositReverts`).

The test:

1. Sets the harness to reenter into `observeNestedDeposit` (line 132) and to bubble reverts (line 133).
2. Calls `wrapped.deposit(10e18, alice)` (line 141).
3. Expects `SafeTransferLib.TransferFromFailed.selector` (line 140).
4. Asserts supply, alice shares, vault assets, and reserve are all unchanged (lines 143-146).

The original PRD criticism ("The reentrancy test accepts any revert.") is partially resolved: the test now pins a specific error rather than a bare revert. But the PRD bullet says "expects the nested-guard error." The nested-guard error is `IReentrancyLock.IsLocked`. The test pins the **outer** error `SafeTransferLib.TransferFromFailed`. The `observeNestedDeposit` helper at lines 28-33 does assert that the nested call reverts with `IsLocked`, but that assertion fires inside the token's callback, not at the outer `expectRevert` line. The `setBubbleRevert(true)` at line 133 makes the nested `IsLocked` bubble up through `transferFrom`, after which `transferFrom` itself reverts with `TransferFromFailed`. The outer `expectRevert` therefore pins the bubbled-outcome error, not the nested-guard error.

Two readings of "expects the nested-guard error" are possible:

- **Strict reading:** the outer `expectRevert` should pin `IReentrancyLock.IsLocked.selector` directly. The current test does not do that. The strict reading fails.
- **Loose reading:** the test as a whole, including the inner `observeNestedDeposit` positive assertion at line 31, must pin the nested-guard error somewhere. The current test does pin it at line 31, but it also accepts the `TransferFromFailed` outer error, which is a separate failure mode that is not the nested guard.

The original PRD bullet is paired with "and asserts no partial credit" — the test does assert no partial credit (lines 143-146). The pinning part is the question. I record this as **partial** because the outer `expectRevert` pins a different error than the bullet names, and the "no partial credit" assertion is the second half of the bullet. A reader verifying REQ-03 by reading the outer `expectRevert` line alone would not see the nested-guard pin.

**Verdict: partial.** The "no partial credit" half is satisfied. The "expects the nested-guard error" half is satisfied only via the `observeNestedDeposit` inner helper, not via the outer `expectRevert`.

### Bullet 3 — minimality fuzz test

> The minimality fuzz test expects the family's exact short-funding error and asserts shares, balances, and reserves are unchanged on rejection and exact on success. (PRD line 233)

Current test: `RebasingAwareERC4626_Fuzz.t.sol:57-101` (`testFuzz_FUZZ02_exactOutMinimals`).

- Rejection half (lines 64-85):
  - Pinned error: `vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, need - 1, need))` at line 70. The selector and the two arguments identify the family's exact short-funding error.
  - State unchanged: `assertEq(IERC20(address(vault)).balanceOf(alice), sharesBefore, "short funding mints nothing")` at line 80, supply unchanged at line 81, alice assets unchanged at line 82, vault assets unchanged at line 83, reserve unchanged at line 84. All five states asserted.
- Success half (lines 86-100):
  - Reverts to snapshot (line 85) and re-runs with `need` instead of `need - 1`.
  - `assertEq(paid, need)` at line 96, alice shares match minted (line 97), alice assets debited (line 98), vault assets credited (line 99), reserve equals `vaultAssets + need` (line 100). All four states asserted exactly.

The original PRD criticism ("accepts any revert and checks only the successful return value") is fully resolved. Both halves pin a specific error and assert state.

**Verdict: already satisfied.**

### Bullet 4 — scanner coverage of the full D16 inventory

> The scanner selects the full D16 regression inventory used for R2.4, including custody files that do not contain the APEX marker. (PRD line 234)

Current scanner: `scripts/apex_bare_expectrevert_scan.sh:14-26`.

- Two fixed roots: `test/foundry/spec/hooks/uniswap/v4/standardExchange` (line 15) and `test/foundry/spec/vaults/standard/exchange/protocols/uniswap` (line 16). These cover the hook/SE families and the Uniswap protocol exchange vault tests.
- Two fixed custody files: `RebasingAwareERC4626_Adversarial.t.sol` (line 19) and `RebasingAwareERC4626_Fuzz.t.sol` (line 20). The original PRD criticism ("the scanner's fixed roots plus an APEX text filter do not include these custody files") is now resolved because these two files are explicitly added.
- APEX content filter: any file under `test/foundry/spec` that contains the regex `APEX` (line 25). This is a content-based filter, not a directory-based filter.

The D16 inventory is defined in `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:335` (D16 row). It enumerates SE vaults (FullSpread V3/V4, ERC-4626 SE, Morpho Blue SE, RebasingAware custody SE/SY, Uniswap V2 SE, Camelot V2 SE, Aerodrome V1 SE, Slipstream SE, Lido wstETH SE, Rocket Pool rETH SE, EtherFi weETH SE, Aave V3 Stata SE, Aave Cross-Version Loop, Balancer V3 packages), hook families (orbital, weighted, curve quad, Balancer quad, single-CP, dual-CP, non-CP `single/`), DETF targets, and Balancer SE rate providers.

I cannot confirm from inspection that the scanner covers every D16 family's regression tests:

- The hook root covers the seven SE buffer families under `contracts/hooks/uniswap/v4/standardExchange/`, which matches the D16 hook list.
- The Uniswap exchange root covers FullSpread V3, FullSpread V4, and Uniswap V2 SE tests. It does not directly name Lido, Rocket, EtherFi, Morpho, Camelot, Aerodrome, Slipstream, Aave V3 Stata, Aave Cross-Version Loop, or Balancer V3 SE tests.
- The two custody files are now in the path list. The original concern is resolved.
- The APEX content filter catches files that mention "APEX" in their content, but the PRD's requirement is to cover files that "do not contain the APEX marker" — the filter is a partial mitigation, not a coverage guarantee.

The "D16 regression inventory" is the regression tests for every D16 family. I cannot identify the complete set of test files corresponding to every D16 family from the controlling PRD REQ-03 or the current scanner alone. The D16 inventory document (`apex-2026-09-17-remediation-and-regression-tests.md:335`) names families, not test files. Mapping families to test directories requires a separate inventory.

**Verdict: partial.** The two named custody files are now covered. Whether every D16 family's regression tests are covered is unverified without running the scanner and checking its output against a family-to-test-file map that is not present in the cited PRD or current script.

## Bullet verdict table

| Bullet | Verdict | Notes |
|---|---|---|
| 1. ownership test | already satisfied | contract caller, pinned `TransferDeltaInsufficient`, alice-share assertion all in place |
| 2. reentrancy test | partial | no-partial-credit half satisfied; "expects nested-guard error" satisfied only via inner `observeNestedDeposit` helper, not via outer `expectRevert` |
| 3. minimality fuzz test | already satisfied | rejection half pins `MaxAmountExceeded` and asserts five state values; success half asserts four state values exactly |
| 4. scanner coverage | partial | two named custody files now covered (original criticism resolved); full D16 inventory coverage not verified |

## Proposed requirements for the still-open gaps

### G2 — Reentrancy test outer expectRevert must pin the nested-guard error

- **Severity:** Medium (matches REQ-03 Medium; the inner helper is not visible at the outer expectRevert line, so a reader verifying the bullet by reading the test surface would not see the pin)
- **File and line:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:128-147` (`test_ADV03_reentrancyDuringDepositReverts`); the `observeNestedDeposit` helper at `:28-33` and the harness setup at `:128-135`.
- **Intended behavior (from REQ-03 PRD line 232, paraphrased):** "The reentrancy test expects the nested-guard error and asserts no partial credit." The original criticism was that the test accepted any revert; the fix is to pin the nested-guard error specifically.
- **Broken requirement or invariant:** The outer `expectRevert` at line 140 pins `SafeTransferLib.TransferFromFailed.selector`. The nested-guard error (`IReentrancyLock.IsLocked.selector`) is asserted inside `observeNestedDeposit` at line 31, which is the harness's callback target, not the test's outer expectation. The bullet names the outer expectation. A second read of the bullet by an auditor following the line numbers would find the wrong selector at the outer line.
- **Impact class:** False-positive security coverage on a test named for a reentrancy property. The inner helper is real evidence; the outer expectation is not the named pin.
- **Acceptance criteria:** The outer `expectRevert` in `test_ADV03_reentrancyDuringDepositReverts` pins `IReentrancyLock.IsLocked.selector`, and the no-partial-credit assertions at lines 143-146 remain. The test's helper and harness setup are not weakened. The fix does not relax the production guard at `RebasingAwareStandardYieldTarget.sol:57-58`. The fix does not introduce a new `try`/`catch` in production.
- **Non-goals:** Do not weaken the EOA guard. Do not replace the test with a bare `expectRevert()`. Do not add a `try`/`catch` to suppress the production revert. Do not change the harness's `setBubbleRevert(true)` behavior in a way that hides the nested revert from the outer assertion.
- **Fix direction (not exploit):** Reorder the test so the outer `expectRevert` matches the nested revert. One safe shape: have the harness bubble only the `IsLocked` revert and not translate it into `TransferFromFailed` — for example, by returning success on `transferFrom` when the inner call reverts with `IsLocked` — so the outer `expectRevert` can pin `IsLocked` directly. Another shape: have the harness reenter into a path that does not call `transferFrom` (so the outer revert is the nested `IsLocked`). The fix must not require the test to know the inner `setReenter` target.

### G4 — Scanner must cover the full D16 regression inventory

- **Severity:** Medium (matches REQ-03 Medium)
- **File and line:** `scripts/apex_bare_expectrevert_scan.sh:14-26`; the D16 inventory is defined at `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:335`.
- **Intended behavior (from REQ-03 PRD line 234, paraphrased):** "The scanner selects the full D16 regression inventory used for R2.4, including custody files that do not contain the APEX marker." The original criticism was that the fixed roots plus the APEX text filter missed the custody files; the fix is the full D16 inventory.
- **Broken requirement or invariant:** The current scanner has two fixed roots (hook/SE families and Uniswap exchange), the two named custody files, and an APEX content filter. The D16 inventory at `apex-2026-09-17-remediation-and-regression-tests.md:335` lists SE vaults (Lido, Rocket, EtherFi, Morpho, Camelot, Aerodrome, Slipstream, Aave V3 Stata, Aave Cross-Version Loop, Balancer V3 packages), DETF targets, and Balancer SE rate providers whose regression test trees are not enumerated in the cited PRD or current script. Whether the two fixed roots or the APEX content filter cover all of these trees is unverified from inspection alone. The PRD bullet says the scanner must "include custody files that do not contain the APEX marker"; the original custody files are now in the path list, but the broader D16 coverage is not demonstrated.
- **Impact class:** False-positive security coverage on tests not selected by the scanner. A bare `expectRevert()` outside the two fixed roots and outside the APEX-matched set would not be flagged.
- **Acceptance criteria:** A documented family-to-test-file map is recorded in this PRD or an evidence file. The map enumerates every D16 SE vault, hook family, DETF target, and rate provider from `apex-2026-09-17-remediation-and-regression-tests.md:335` and the corresponding regression test file or directory. The scanner's `roots`, `custody`, and APEX match, taken together, cover every entry in that map. The `apex_bare_expectrevert.txt` output includes a row for every test file in the map. The current submission's inventory is preserved, not weakened.
- **Non-goals:** Do not weaken the EOA guard. Do not change the APEX regex. Do not delete the two fixed roots. Do not add a `try`/`catch` in production. Do not remove the two named custody files from the path list.
- **Fix direction (not exploit):** Add a D16 inventory section to the controlling PRD or its evidence file that names the regression test file or directory for every D16 family. Update the scanner to include any family whose test tree is not already covered by the two fixed roots or the APEX content filter. Record the family's path in the script as a third list (parallel to `roots` and `custody`) so the coverage is explicit and reviewable.

## Evidence gaps

- I did not run Forge, so the current scanner's actual `apex_bare_expectrevert.txt` output is unverified. I cannot confirm whether a bare `expectRevert()` exists in any D16 family test outside the two fixed roots.
- I did not enumerate every D16 family regression test file. The D16 inventory at `apex-2026-09-17-remediation-and-regression-tests.md:335` names production source contracts, not test files. Mapping D16 source to D16 test trees requires a separate document that the controlling PRD REQ-03 does not supply. This is the evidence gap that prevents bullet 4 from being verified.
- Whether `vm.expectCall` counts a call that reverts is not independently verified. The reported green run for the existing reentrancy test is consistent with Foundry's behavior, but a stricter pin to `IsLocked` may require a different harness shape.
- The `RebasingAwareStandardYieldTarget.sol:57-58` production guard is unchanged and remains the project rule. None of the proposed fixes touches it.

I did not run Forge.