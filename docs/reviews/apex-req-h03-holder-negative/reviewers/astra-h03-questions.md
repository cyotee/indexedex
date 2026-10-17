# Astra — REQ-H03 requirements check

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. I read `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` in full. No other reviewers' notes were read for this check.

**No blocking question.**

The owner ruling at lines 20–22 expressly supersedes the earlier panic-only recommendation. The requirements leave no unresolved behavior or remediation choice:

- **Burn implementation, lines 28–36:** read `currentBalance`, reject insufficiency with exactly `IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount)`, otherwise update the balance once, subtract supply, and emit the existing transfer event in that order. Remove the commented helper call and old inline subtraction. Do not call `_decreaseBalanceOf` or introduce its zero-address rejection.
- **Boundaries, lines 36–37:** other named ERC-20 functions remain unchanged; no catch, supply-short custom error, holder redesign or withdrawn V4 work. The shared-library change is explicitly targeted, not an unresolved scope question.
- **Test, lines 45–50:** the import path and full expected error encoding are fixed; the redeem call, three balance assertions and code-less ordinary-success tests remain unchanged. Different runtime revert bytes require stopping and reporting, not selecting another error.

The unverified runtime reachability at lines 57–59 is an explicit validation limit with a prescribed stop condition, not a missing owner decision. No additional product scope or implementation alternative is proposed. No separate implementation plan or audit report was supplied, as the PRD states; none is assumed.

This is a requirements-clarity conclusion, not implementation verification or authorization. Earlier Astra reports remain historical assessments of the prior test-only scope; they were not rewritten. Only this assigned Markdown report was created. No code, test, PRD or configuration was edited, and no delegation, shell, build or deployment was performed.

I did not run Forge.
