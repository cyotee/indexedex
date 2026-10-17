# Grok original — Stage-1 REQ-03 remaining gaps

- **Date:** 2026-10-14
- **Reviewer:** Grok (`xai/grok-4.7`). Independent first pass.
- **Question:** Which acceptance bullets of Stage-1 REQ-03 are still open, and what exact requirements would close only those gaps?
- **Controlling text:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` REQ-03, lines 223-235.
- **Answer:** The three test bullets are already satisfied in current source. The scanner now includes the two custody files the PRD said it missed. The remaining scanner clause, "the full D16 regression inventory," cannot be identified from REQ-03 or the current script. That sub-bullet is unverified. No new requirement is proposed. This reviewer did not run Forge.

## Bullet verdicts

| Acceptance bullet | Verdict | Evidence |
| --- | --- | --- |
| Ownership test uses an allowed contract caller, expects the precise share-accounting error, and asserts the other holder's shares are unchanged | already satisfied | `RebasingAwareERC4626_Adversarial.t.sol:50-60`. `AtomicPretransferCaller` is the caller. The expected error is `TransferDeltaInsufficient(shares, 0)`. Alice's share balance is unchanged. The bytecode check at `RebasingAwareStandardYieldTarget.sol:57-59` is still present and is not the error this test reaches. |
| Reentrancy test expects the nested-guard error and asserts no partial credit | already satisfied | `observeNestedDeposit` at `:28-32` expects `IsLocked`. `transferFrom` calls that observer before returning (`ReentrantERC20Harness.sol:58-74`). The outer call expects `TransferFromFailed` at `:140-141` because `bubbleRevert` rethrows the inner revert through the pull. Unchanged supply, shares, assets, and reserve are asserted at `:143-146`. Do not replace the outer error with a broader `expectRevert()`, and do not demand that the outer selector be `IsLocked` when the pull surfaces `TransferFromFailed` after the nested check has already run. |
| Minimality fuzz test expects the family's exact short-funding error and asserts shares, balances, and reserves unchanged on rejection and exact on success | already satisfied | `RebasingAwareERC4626_Fuzz.t.sol:57-100`. Rejection expects `MaxAmountExceeded(need - 1, need)` and asserts Alice's shares, total supply, Alice's assets, the vault's assets, and the asset reserve are unchanged. Success asserts the paid amount, minted shares, asset debit, vault asset credit, and booked reserve equal the quoted amounts. |
| Scanner selects the custody files that do not contain the APEX marker | already satisfied | `scripts/apex_bare_expectrevert_scan.sh:18-23` adds the adversarial file and the fuzz file by path, without requiring an APEX marker. |
| Scanner selects the full D16 regression inventory used for R2.4 | unverified | REQ-03 names the property and the old scanner gap. It does not list the inventory. The current script selects two directory roots, the two custody files, and any `test/foundry/spec` file whose text matches an APEX marker (`:14-26`). That is not, by itself, proof that every D16 regression file is included or that every included file is in that inventory. |

## Production guard

`RebasingAwareStandardYieldTarget.sol:57-59` still calls `LocalCreditLib.requirePretransferCaller` when `burnFromInternalBalance` is true and `msg.sender` is not the vault. No requirement is opened to weaken that check. The ownership test no longer depends on a code-less caller reaching the share-accounting error.

## Proposed requirements

None. A bullet the current test already satisfies is not reopened. The unverified scanner clause is not turned into a file list.

The document that would define the inventory is the locked D16 family and regression set in `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` and `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`. REQ-03 does not extract that list. A later requirement may compare the scanner's selected paths to that inventory only after the inventory is read from those documents. This draft does not invent the comparison set.

## Non-goals kept

- Do not weaken `requirePretransferCaller`.
- Do not replace the pinned tests with broader `expectRevert()`.
- Do not treat `test_ADV02_insufficientSharePretransferReverts` (`:113-125`) as a substitute for the ownership test. It remains a separate pinned control, and the ownership test now has its own pin.

## Evidence gap

No Forge run. A present assertion is not a pass. The scanner was not executed.

I did not run Forge.
