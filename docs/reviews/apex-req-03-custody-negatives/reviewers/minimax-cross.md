# MiniMax M3 — REQ-03 cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No peer cross or REMEDIATION_PRD.md under `apex-req-03-custody-negatives/` was read or written. I re-read the disputed source and tests directly.
- **Target:** current IndexedEx working tree, current state 2026-10-14.
- **Question:** agree or dissent on (1) the reentrancy bullet, (2) the fuzz success half, (3) the scanner gap framing.

## Re-reads this round

- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:26-33, 128-147` (reentrancy helper and outer test)
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol:57-101` (fuzz exact-out test, both halves)
- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:328-345, 376-391, 405-420, 555-565` (Kimi's cited escape file)
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:128-150` (Kimi's cited escape file)
- `scripts/apex_bare_expectrevert_scan.sh` (full read, 47 lines)
- Grep for `APEX` in the two cited escape files: 0 matches each.

## (1) Reentrancy bullet — partial, not already satisfied

**Agree with Astra and Kimi. Dissent from Grok.**

The current test pins `SafeTransferLib.TransferFromFailed.selector` at the outer `expectRevert` (line 140). The harness sets `setBubbleRevert(true)` (line 133) so that the nested callback's revert reason bubbles up through `transferFrom`. The inner `observeNestedDeposit` (lines 28-33) asserts `IsLocked` at line 31, but that assertion fires inside the reentrancy frame and the test as written does not load-bear it:

- If the inner `wrapped.deposit` reverts with `IsLocked` (the intended case), the bubble carries it through `transferFrom`, which then reverts with `TransferFromFailed`. Outer expectRevert matches.
- If the inner `wrapped.deposit` reverts with any other reason (or the inner `assertEq` at line 31 fails because the inner reason is wrong), the bubble still carries that reason up, `transferFrom` still reverts with `TransferFromFailed`, and the outer expectRevert still matches.
- The post-state at lines 143-146 (supply, shares, vault assets, reserve all unchanged) does not distinguish these cases either, because a failing callback leaves the same unchanged state as a successful nested-guard rejection.

Grok's position is that the test is "already satisfied" because the inner observer exists. But the PRD bullet says the reentrancy test "expects the nested-guard error." Reading the bullet strictly, the outer `expectRevert` is the named expectation. Reading it loosely, the test as a whole, including the inner helper, must pin the nested-guard error somewhere. The current test's inner helper does pin it, but the outer surface does not, and a future change to the harness could swallow the inner pin without the outer surface detecting the change. R2.4's stated intent — "a test named for an ownership or reentrancy property must reach that property" — requires the named property to be load-bearing at the test-oracle level.

Kimi's framing is the most accurate: "the `:31` `IsLocked` equality cannot currently fail the test." The inner pin is informative, not load-bearing.

I do not propose a new requirement shape this round. My own original already proposed G2, and the peer requirement P-1 (Kimi) is the more rigorous form: store the nested `(ok, reason)` outside the wrap, assert it after the outer call. Both are about moving the pin out of the swallowed frame. I agree with P-1's shape and severity. The implementation can choose between (a) recording the inner `(ok, reason)` on the test contract before the deliberate re-bubble at line 32, and (b) restructuring the harness so the outer revert is the nested `IsLocked` directly. Either shape satisfies the bullet.

**Verdict: partial. The reentrancy bullet is not already satisfied.**

## (2) Fuzz success half — partial, not already satisfied

**Agree with Astra. Dissent from Grok and Kimi.**

The PRD bullet says "asserts shares, balances, and reserves are unchanged on rejection and exact on success." The current test's rejection half at `F:80-84` does assert five state values including total supply: `totalSupply` is checked at line 81. The success half at `F:96-100` asserts:

- `paid == need` (line 97)
- recipient's `balanceOf(alice) == shares` (line 98)
- `asset.balanceOf(alice) == aliceAssets - need` (line 99)
- `asset.balanceOf(vault) == vaultAssets + need` (line 100)
- `reserveOfToken(asset) == vaultAssets + need` (line 101)

The success half does NOT assert `totalSupply`. `supplyBefore` is captured at line 65 but only used in the rejection half at line 81. The PRD's "shares" in the bullet's enumeration reads as the total issued share count, not just the recipient's balance: the rejection half treats it that way, and "shares, balances, and reserves" lists three distinct quantities.

Grok's table lists "shares, total supply, Alice's assets, the vault's assets, and the asset reserve" for the rejection half. The success half list in Grok's table omits total supply. Grok does not propose adding it; he treats the success half as already covered by the recipient-share assertion. Kimi makes the same move: "asserts `paid == need` and exact mint/debit/credit/booking." Neither peer proposes the total supply assertion on success.

Astra's framing is correct: the success half is partial because it does not constrain additional issuance elsewhere. The production mints `shares` to the receiver at `RebasingAwareERC4626Common.sol:392` (Astra's read), so a future change that minted to multiple accounts would escape the recipient-share assertion. The total supply assertion is a defensive coverage check, not a demonstrated defect. The fix is to add `assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding mints the quoted shares to total supply")` to the success half, alongside the existing assertions.

The recipient-share assertion is not a substitute for the total supply assertion. The two answer different questions: "did the receiver get the right amount?" vs. "did the share ledger end at the right total?" Both are required by the PRD bullet as I read it.

I do not propose a new requirement shape this round. My own original did not call this gap out; the cross-review corrects that. The implementation should add the total supply assertion in the success half. The severity is Medium (matches REQ-03); the impact class is false-positive security coverage, same as the other bullets.

**Verdict: partial. The fuzz success half must also assert total supply.**

## (3) Scanner gap — confirmed by cited escaping files, not only unverified

**Agree with Kimi. Dissent from Astra and Grok.**

I re-read Kimi's two cited escape files and verified the claims:

- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:332, 335, 383, 409, 559` — five bare `vm.expectRevert()` calls. The file's directory is `test/foundry/spec/vaults/standard/erc4626`, which is under neither fixed scanner root. Grep for `APEX` in the file: 0 matches. The ERC-4626 SE is a D16 family (per `apex-2026-09-17-remediation-and-regression-tests.md:335`).
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:131, 143` — two bare `vm.expectRevert()` calls. The file is in the same directory as the two named custody files but is not itself named in the script. Grep for `APEX` in the file: 0 matches. This is a custody sibling file, exactly the class the PRD bullet gestures at.

Both files demonstrably escape the scanner's selection rule. The script's two fixed roots do not include them; the APEX content filter does not match them (no APEX marker). They are real, named, cited escape instances. The "unverified" framing by Astra and Grok understates the actual evidence: the gap is not a hypothesis; it is observed.

Astra's framing — "no missing-file finding or unconditional scanner rewrite is proposed" — is correct as a final disposition (the P-2-style requirement should define the inventory first, then compare). But the gap itself is not unverified. Two files are demonstrated escapes. The open question is the size of the gap, not whether a gap exists.

Grok's framing — "REQ-03 does not extract that list" — is correct that the PRD does not enumerate the inventory. But the PRD also does not require the reader to extract the list before saying a gap is unverified. The bullet's plain language is "the scanner selects the full D16 regression inventory." If the scanner demonstrably does not select a file that is a D16 family regression test, that is a failure of the bullet regardless of whether the full inventory is enumerated. The bullet is partial; the inventory is unverified for the rest of the D16 families, but the two cited escapes are confirmed.

I agree with Kimi's P-2 shape: define the D16 R2.4 inventory from the locked plan and the evidence bundle, then expand the scanner's selection rule to cover the inventory, with the two cited escaping files as named members. I do not propose a different requirement this round.

**Verdict: confirmed. The scanner gap is observed, not just unverified.**

## Material peer claims not separately re-read

- I did not re-read every line of the three peer originals. I re-read the disputed source and tests.
- I did not re-read the locked plan's D16 decision rows in full (`apex-2026-09-17-remediation-and-regression-tests.plan.md`). I used them only to identify where the D16 inventory is defined, not to derive the inventory itself. I agree with all three peers that the full inventory cannot be derived from REQ-03 alone.
- I did not re-run the scanner. The two cited escape files were verified by line read and APEX-count grep, not by executing the script and inspecting its output.

## Unresolved dissent

- The reentrancy bullet framing: Grok and I disagree. The bullet text says "expects the nested-guard error." I read that as a load-bearing requirement on the test surface, not as a property of an inner helper that is unreachable from the outer `expectRevert`. Grok reads it as the latter. I do not see a path to consensus without a PRD amendment. Severity remains Medium.
- The fuzz success-half framing: Grok and Kimi treat "shares" as recipient balance; Astra and I treat "shares" as total supply. The PRD bullet is ambiguous. I lean toward the total supply reading because the rejection half treats "shares" that way and because the bullet lists "shares, balances, and reserves" as three distinct quantities. Grok and Kimi do not record the gap. I do not see a path to consensus without a PRD amendment. Severity Medium, same as the other bullets.
- The scanner-gap framing: Astra and Grok treat the gap as unverified; Kimi and I treat the gap as observed, with the rest of the inventory unverified. The two cited escape files are the evidence for the observed portion. Severity Medium, same as the other bullets.

## Evidence gaps

- I did not run Forge. No execution, no scanner run, no Foundry assertion behavior verified at runtime. The reentrancy swallowing analysis is inference from the code shape and Kimi's documented comment, not an executed result.
- The full D16 R2.4 inventory is not derived. I have not enumerated every D16 family regression test file. The two cited escape files are confirmed; the rest is unverified.
- I did not body-read the other rebasingVault sibling files (Kimi noted "nine further rebasingVault spec files also contain bare `expectRevert()`"). I accept the count on the strength of the grep but did not verify each.
- The `ERC4626StandardExchange_Routes.t.sol` file path is under `vaults/standard/erc4626`, which is not one of the two fixed scanner roots. I did not check whether the file's directory was ever a scanner root in a prior version of the script.

I did not run Forge.