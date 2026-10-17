# MiniMax M3 — REQ-ADJ-01 implementation plan (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Controlling PRD:** `docs/reviews/apex-req-adj-01-self-call-comment/REMEDIATION_PRD.md` (50 lines, read in full). Where this plan conflicts with that PRD, the PRD controls.
- **Scope:** Comment-only edit at `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44`. No function-body change. No self-call. No exemption deletion. No test. No Forge.
- **No code edit. No PRD/plan write. No Forge. No exploit procedures.**

---

## 0. Preconditions — verified by direct re-read

The PRD's stop rule (`:41`): "If lines 41–44 or 57–63 no longer match the text read for this PRD, stop and report." I re-read both ranges. **No drift.** The plan proceeds.

### 0.1 Lines 41-44 (current NatSpec, verbatim)

```solidity
    /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
    ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. Burns exactly `amountSharesToRedeem` from vault-held shares
    ///        and refunds nothing (API-12). The vault's own self-call path is unaffected.
```

Matches the PRD's expected starting state. The offending sentence at line 44 ("The vault's own self-call path is unaffected.") is present and is what this plan removes.

### 0.2 Lines 57-63 (exemption and holder selection, verbatim)

```solidity
        if (burnFromInternalBalance && msg.sender != address(this)) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
        }
        RebasingAwareERC4626Common.ShareSource source = burnFromInternalBalance
            ? RebasingAwareERC4626Common.ShareSource.PublicBalanceExactBurn
            : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
        address owner = burnFromInternalBalance ? address(this) : msg.sender;
```

Matches the PRD's expected starting state. The exemption at `:57-58` is preserved (PRD non-goal); the source/owner selection at `:60-63` is preserved (PRD `:38` "Do not change the function signature or body").

### 0.3 What is NOT edited

- Function signature at `:45-51` (parameters, modifiers, return): unchanged.
- Function body at `:52-66` (validation, exemption, source/owner selection, `executeRedeem` call): unchanged.
- Every other contract in the rebasingVault package: not edited.
- Tests: not edited, not added.
- Production calls to this function: not added.
- The `RebasingAwareERC4626Common.executeRedeem` settlement path: not edited.
- The `RebasingAwareERC4626Repo._asset()` accessor: not edited.

---

## 1. The exact NatSpec replacement

The PRD's REQ-ADJ-01-1 acceptance bullet (`:27-36`) selects the replacement text verbatim. The implementer copies this block exactly, with no wording alternative, no sentence alternative, and no rephrasing. Replace the four-line NatSpec at `RebasingAwareStandardYieldTarget.sol:41-44` with this six-line NatSpec:

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault and redemption burns
    ///        exactly `amountSharesToRedeem` of its shares and refunds nothing (API-12). When false, the
    ///        explicit holder is `msg.sender`. This function does not call `address(this)`. Transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        a caller with no bytecode reverts `EOAPretransferNotAllowed()`. This comment does not claim
    ///        that the `msg.sender == address(this)` exemption is reachable.
```

The leading 4-space indentation of each `///` line matches the current source style. The blank line at `:40` before the comment is preserved. The function signature at `:45-51` and the function body at `:52-66` are unchanged.

### 1.1 What every clause maps to in the unchanged body

- "When true, the explicit holder is the vault" — pinned at `:63` (`owner = ... ? address(this) : ...`).
- "redemption burns exactly `amountSharesToRedeem` of its shares" — pinned at `:64-66` (the `executeRedeem(amountSharesToRedeem, ...)` call) combined with `:61` (`ShareSource.PublicBalanceExactBurn`).
- "refunds nothing (API-12)" — pinned by the absence of any refund branch in the function body.
- "When false, the explicit holder is `msg.sender`" — pinned at `:63`.
- "This function does not call `address(this)`" — pinned by the absence of any `this.redeem(...)` or `address(this).redeem(...)` call in the function body and the file at large.
- "Transfer-and-consume must be atomic; staged use is at integrator risk" — pinned by the `nonReentrant` modifier at `:51` and the `LocalCreditLib.requirePretransferCaller` check at `:58`.
- "When true and `msg.sender != address(this)`, a caller with no bytecode reverts `EOAPretransferNotAllowed()`" — pinned at `:57-58` (the `&&` guard; the `EOAPretransferNotAllowed` selector is in `ISecurePullErrors` which `LocalCreditLib.requirePretransferCaller` reverts).
- "This comment does not claim that the `msg.sender == address(this)` exemption is reachable" — pinned by the absence of any production self-call established in the file (PRD `:50`).

The implementer cannot choose any clause differently. The replacement is the only shape that satisfies the PRD's three acceptance bullets and the four non-goals.

### 1.2 What the PRD's "Dissent" block (`:44-46`) rejects

- "MiniMax's allowance clause is rejected because this function body does not show an allowance spend." — Confirmed by direct read of the redeem body at `:45-67`: no `allowance`, `transferFrom`, or `approve` call. The replacement contains no "allowance" word.
- "Kimi's first opening, which said the flag applies only when `msg.sender != address(this)`, is rejected because the flag can be true when the caller is the vault." — The closed replacement says "When true, the explicit holder is the vault" — the flag is true regardless of who the caller is; the exemption at `:57-58` only gates the pretransfer caller check, not the flag's effect on holder selection.
- "Astra's longer block is equivalent in substance." — The closed replacement is functionally equivalent to Astra's; the wording is the one the PRD selects.
- "This PRD selects the block above so the implementer has one text." — One text. No alternative.

---

## 2. Ordered steps

### Step 1 — verify the preconditions (already done in §0)

If, at implementation time, lines 41-44 or 57-63 no longer match the text quoted in §0.1 and §0.2, **stop and report.** Do not choose another sentence. The PRD's stop rule (`:41`) is explicit.

### Step 2 — replace the NatSpec

Apply the six-line replacement from §1 to `RebasingAwareStandardYieldTarget.sol:41-44`. The replacement covers exactly lines 41-44 of the current source; no surrounding text is touched. The blank line at `:40` is preserved. The function signature at `:45` immediately follows the new comment block.

### Step 3 — no other file

PRD non-goal (`:42`): "Do not edit any other file." No production caller, no test, no scaffold, no metadata, and no other contract in the rebasingVault package is edited.

### Step 4 — no self-call, no exemption removal, no test

- No `this.redeem(...)` or `address(this).redeem(...)` is added.
- The exemption at `:57-58` is preserved verbatim.
- No test is added or changed.

### Step 5 — no Forge command

PRD non-goal (`:42`) does not require a test. No test was added or changed. There is no "one Forge command" for this item. The implementer does not run Forge.

---

## 3. Stop conditions

The implementer stops and reports to the coordinator/human if any of the following is observed at implementation time:

1. **Line drift.** Lines 41-44 or 57-63 no longer match the text quoted in §0.1 and §0.2. The implementer does not choose another sentence. (PRD `:41`.)
2. **Wording substitution.** Any deviation from the six-line replacement in §1, including rephrasing, adding a sentence, or removing a sentence. The implementer copies the block exactly. The PRD's "Dissent" block rejects any alternative. (PRD `:44-46`.)
3. **Function-body edit.** Any change to the function signature at `:45-51` or the function body at `:52-66`. The PRD's acceptance bullet (`:38`) forbids this.
4. **Self-call added.** Any addition of `this.redeem(...)` or `address(this).redeem(...)` to make the old sentence true. The PRD's acceptance bullet (`:39`) forbids this.
5. **Exemption removed.** Any change to lines 57-58. The PRD's acceptance bullet (`:39`) forbids this.
6. **Other file edited.** Any change to a file outside `RebasingAwareStandardYieldTarget.sol`. The PRD non-goal (`:42`) forbids this.
7. **Test added or changed.** The PRD non-goal (`:40`) forbids this.
8. **Allowance claim.** Any "allowance," "approve," "transferFrom," or "spender" word in the comment. The redeem body does not show an allowance spend. The PRD's "Dissent" (`:45`) and non-goal (`:42`) reject this.
9. **Reachability claim.** Any sentence claiming the exemption is reachable or unreachable. The PRD's "Dissent" (`:46`) and non-goal (`:42`) reject this; the closed replacement explicitly says "This comment does not claim that the `msg.sender == address(this)` exemption is reachable."

If a stop condition fires, the implementer does not edit and does not choose a substitute. The coordinator/human decides the next step.

---

## 4. What this plan does not include

- No production logic change. The function body is unchanged.
- No self-call. The exemption's reachability is not asserted.
- No allowance claim. The comment contains no "allowance," "approve," or "transferFrom" word.
- No test edit or addition. The PRD forbids tests in this item.
- No new file. The PRD forbids editing any other file.
- No redesign of custody SY. The PRD non-goal (`:42`) forbids this.
- No "via IR" enabling, no `out/` or `cache_forge/` deletion. Not applicable because no Forge command is run.
- No `scripts/sync-crane-skills.sh` or `submodule-commit.sh`. Not applicable because the edit is comment-only in an IndexedEx-tracked file (not a Crane submodule change). The `lib/crane` gitlink is unchanged.

---

## 5. Done when

- The four-line NatSpec at `RebasingAwareStandardYieldTarget.sol:41-44` is replaced by the six-line NatSpec in §1.
- The function signature, the function body, the exemption at `:57-58`, and every other line in the file are unchanged.
- No other file is edited.
- No test is added or changed.
- No Forge run is performed.

---

## 6. Files examined (this plan)

- `docs/reviews/apex-req-adj-01-self-call-comment/REMEDIATION_PRD.md` — read in full (50 lines).
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` — re-read at `:40-69` to verify the preconditions and the exemption. The file was read in full (151 lines) in the first-pass review earlier this session.

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.