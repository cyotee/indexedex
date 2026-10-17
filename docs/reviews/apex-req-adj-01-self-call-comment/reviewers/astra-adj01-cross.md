# Astra — REQ-ADJ-01 replacement-session cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes my original `astra-adj01.md`, which remains preserved. I read all three supplied originals in full: `grok-adj01.md`, `minimax-adj01.md`, and `kimi-adj01.md`. They are untrusted evidence. No peer cross-review artifact was read.

## Closed replacement

**No blocking question.** Replace only the NatSpec block currently at `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41–44` with exactly:

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault (`address(this)`):
    ///        burn exactly `amountSharesToRedeem` from vault-held shares with no share refund (API-12).
    ///        When false, the explicit holder is `msg.sender`. This function passes that holder to
    ///        internal settlement and does not call `address(this)`. For true, transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        callers with no bytecode revert `EOAPretransferNotAllowed()`. The existing `msg.sender == address(this)`
    ///        exemption from that caller check is retained; no reachable self-call path is asserted.
```

This is the single selected wording, not a menu. It refines my original to name both holder addresses explicitly and use the requested statement that this function does not call `address(this)`. It makes no allowance claim. Preserve every other source line, including the signature, function body, caller-check exemption, source selection and custody semantics. Do not add a self-call, remove an exemption, or add/change tests. If the named comment/body anchors drift before implementation, stop and report rather than choose another edit.

## Direct evidence

Freshly re-read target **41–67**:

- **57–58:** the bytecode caller check runs only for `burnFromInternalBalance && msg.sender != address(this)`.
- **60–63:** the true branch chooses the public-balance exact-burn source and vault holder; the false branch chooses `CallerOrApprovedOwner` but explicitly sets the owner to `msg.sender`.
- **64–66:** settlement receives that selected holder through `RebasingAwareERC4626Common.executeRedeem`. This body contains no external call to `address(this)`.

The original pass read the internal settlement at Common **399–430** and the controlling application PRD REQ-ADJ-01 at **152–161**. The requirements remain comment-only correction, explicit-holder teaching, preservation of the exemption, and no custody redesign. No production self-call into this function was established. The local no-self-call statement is not a global proof that the exemption can never be reached.

## Agreements and objections

### Grok — agree with holder semantics; amend wording

Agree with `grok-adj01.md:14–20` and the true/false holder distinctions. Its replacement at **23–26** omits the explicit statement that the function does not call `address(this)` and omits the staged-use risk warning. “Same call” is also less precise than atomic transfer-and-consume: transfer and redemption may be separate subcalls within one atomic transaction. Use the closed wording above instead.

### MiniMax replacement — reject allowance and guard claims

Reject `minimax-adj01.md:60,82` saying the caller's burn is “via allowance or ownership.” The enum's general name does not establish an allowance path for this redeem body, which fixes the ordinary holder to `msg.sender`. The correction must not teach an extra route that this function does not show.

Reject **60–61,83** saying the caller check is skipped *only* when the flag is true and the caller is the vault. It is also skipped when the flag is false. Its following unconditional bytecode-rejection sentence could therefore misdescribe ordinary code-less callers. State the exact positive guard condition as in the selected text.

Reject **85** as a justification: `nonReentrant` does not enforce atomicity between an integrator's prior transfer and redemption. Atomic transfer-and-consume is the preserved integration requirement, with staged use remaining integrator risk—not a property supplied by the lock alone. Its proposed block also lacks the requested explicit no-self-call statement.

### Kimi replacement — agree on explicit holder and reachability restraint; tighten condition

Agree with `kimi-adj01.md:10–12,21–23` on explicit holder selection and avoiding a claim that the exemption is reachable. The proposed bytecode-rejection sentence at **19–20** should be explicitly scoped to the actual true/non-vault guard rather than relying on the opening sentence for context. Add the direct statement that this function does not call `address(this)`.

The statement at **11** that a self-call path “does not exist” is stronger than the established evidence if read globally. The source proves no self-call in this body; the PRD leaves exemption reachability unestablished. The closed wording preserves that distinction. No cross-item V4 work is relevant to this comment repair.

## Retained Astra finding — ADJ01-1

- **Title:** NatSpec presents explicit-holder redemption as a current self-call path.
- **Severity:** Low.
- **File and line:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:44`.
- **Intended behavior:** REQ-ADJ-01 requires explicit-holder documentation without adding a self-call or removing the existing caller-check exemption.
- **Broken invariant:** The comment asserts a current self-call path that the inspected body does not implement and whose reachability was not established.
- **Impact class:** Documentation accuracy / maintenance misdirection; not a demonstrated money-path defect.
- **Fix direction:** Apply only the exact NatSpec replacement above, leaving executable code unchanged.
- **Confidence:** High on the local comment/code mismatch; global exemption reachability remains unverified.

No substantive revision to the original finding is needed. The selected wording is an explicit refinement of Astra's original recommendation. Peer allowance/guard misstatements are rejected; no claim is made that peers have revised their originals.

## Disposition

The target's **45–67** executable body was examined without another scoped defect established; the issue remains its comment at **41–44**. All requested original reports were present. The assigned output was absent before this write. Only this Markdown cross-review was created; no code, source comment, PRD, original review, test, configuration or instructions were edited. No delegation, shell, build, deployment or tests were used. Return to the coordinator/human and stop.

I did not run Forge.
