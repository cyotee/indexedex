# MiniMax M3 — REQ-ADJ-01 cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the REQ-ADJ-01 originals. Re-read the redeem body to confirm the "allowance" clause in my own first pass. Close one exact NatSpec replacement. No implementer choice.
- **Method:** Read the three peer originals (`astra-adj01.md`, `grok-adj01.md`, `kimi-adj01.md`). Re-read the redeem body at `RebasingAwareStandardYieldTarget.sol:45-67` to verify whether "allowance" is present in the visible code.
- **Untrusted:** the three peer originals, treated as model content.
- **Forge:** Not run. No code edit. No PRD/plan rewrite.

---

## 1. Re-read of the redeem body — coordinator's note confirmed

The coordinator's note is correct. I retract my first pass's "via allowance or ownership" clause.

The redeem body at `RebasingAwareStandardYieldTarget.sol:45-67` is:

```solidity
    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut,
        bool burnFromInternalBalance
    ) external nonReentrant returns (uint256 amountTokenOut) {
        if (amountSharesToRedeem == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        address asset_ = address(RebasingAwareERC4626Repo._asset());
        if (tokenOut != asset_) {
            revert IStandardExchangeErrors.InvalidRoute(address(this), tokenOut);
        }
        if (burnFromInternalBalance && msg.sender != address(this)) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
        }
        RebasingAwareERC4626Common.ShareSource source = burnFromInternalBalance
            ? RebasingAwareERC4626Common.ShareSource.PublicBalanceExactBurn
            : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
        address owner = burnFromInternalBalance ? address(this) : msg.sender;
        amountTokenOut = RebasingAwareERC4626Common.executeRedeem(
            amountSharesToRedeem, receiver, owner, minTokenOut, source, true
        );
    }
```

There is no `allowance`, `transferFrom`, or `approve` call in this body. The `Source.CallerOrApprovedOwner` enum name suggests allowance-or-ownership semantics in the downstream `executeRedeem`, but the visible body of `redeem` here does not spend allowance. The owner selection at `:63` (`address(this)` or `msg.sender`) and the source selection at `:60-62` are the only flag-driven logic in the function.

My first pass at `minimax-adj01.md` stated: "when false, `owner` is `msg.sender` and the burn is from the caller's balance via allowance or ownership." The phrase "via allowance or ownership" is not visible in the redeem body. I retract it. The replacement should describe only what the visible code does: select an explicit holder and pass it to `executeRedeem`.

All three peer originals (Astra, Grok, Kimi) correctly avoid the word "allowance." They describe the second branch as "from `msg.sender`'s shares," "the caller's balance," or "the holder is the caller" — all phrasings consistent with the visible code and free of the "allowance" over-specification.

---

## 2. Headline — agreement

All three peer originals agree on "No blocking question" and provide a NatSpec replacement that:
1. Describes explicit-holder redemption (PRD `:159`),
2. Does not claim a current self-call path,
3. Documents the `msg.sender == address(this)` exemption condition without asserting reachability (PRD non-goal `:161`),
4. Does not mention "allowance" — the redeem body does not show an allowance spend.

I agree with the headline. I retract my own first pass's "allowance" clause.

---

## 3. Per-reviewer synthesis

### Astra (`astra-adj01.md`, 56 lines)

- **Headline:** "No blocking question."
- **Replacement (7 lines):**
  ```
  /// @param burnFromInternalBalance When true, redeem exactly `amountSharesToRedeem` from vault-held
  ///        shares with no share refund (API-12); when false, redeem from `msg.sender`'s shares.
  ///        Redemption passes the selected holder explicitly to internal settlement; it does not
  ///        make an external self-call. For true, transfer-and-consume must be atomic; staged use
  ///        is at integrator risk. When true and `msg.sender != address(this)`, callers with no
  ///        bytecode revert `EOAPretransferNotAllowed()`. The existing `msg.sender == address(this)`
  ///        exemption from that caller check is retained; this does not assert a reachable self-call path.
  ```
- **Notes:** Most detailed. Documents the explicit-holder passing, the atomicity requirement, the EOA rejection, the exemption, and explicitly states "this does not assert a reachable self-call path." Does not use the word "allowance."
- **Source evidence:** Reads `RebasingAwareERC4626Common.sol:399-430` for the internal settlement and confirms the explicit-holder wording matches the body.

### Grok (`grok-adj01.md`, 31 lines)

- **Headline:** "No blocking question."
- **Replacement (4 lines):**
  ```
  /// @param burnFromInternalBalance When true, the explicit holder is the vault: burn exactly
  ///        `amountSharesToRedeem` of its shares and refund nothing (API-12). When false, the explicit
  ///        holder is `msg.sender`. A true flag from any other caller must transfer and consume in the
  ///        same call; a caller with no bytecode reverts `EOAPretransferNotAllowed()`.
  ```
- **Notes:** Most concise. Captures the two flag cases with explicit holders and the EOA rejection. Does not document the exemption condition in the comment; instead states "Reachability of the exemption is not established. That is not a question for this comment." This is a legitimate position (do not assert reachability in a comment that lives above the exemption code) but it is a thinner treatment than Astra's or Kimi's.

### Kimi (`kimi-adj01.md`, 39 lines)

- **Headline:** "No blocking question."
- **Replacement (6 lines):**
  ```
  /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
  ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
  ///        revert `EOAPretransferNotAllowed()`. When true, redemption burns exactly `amountSharesToRedeem`
  ///        with the vault (`address(this)`) named explicitly as the holder, and refunds nothing (API-12).
  ///        When false, the holder is the caller. The `msg.sender == address(this)` exemption skips the
  ///        caller check; no current self-call route into this function is claimed.
  ```
- **Notes:** Most faithful to the original comment's structure. Keeps the first two lines of the original (flag condition, atomicity, EOA rejection), then adds the explicit-holder sentences, then documents the exemption while explicitly stating "no current self-call route into this function is claimed." Does not use the word "allowance." The exemption sentence directly satisfies the PRD's "do not delete the exemption" non-goal by describing the exemption condition without asserting a self-call.

### Mine (this session's `minimax-adj01.md`)

- **Headline:** "No blocking question." Matches the three peers.
- **Retracted clause:** "the burn is from the caller's balance via allowance or ownership." The redeem body does not show an allowance spend. I retract.

---

## 4. Where I agree

1. **No blocking question.** All four reviewers converge.
2. **The "allowance" clause in my first pass was wrong.** The redeem body at `:45-67` does not spend allowance. I retract.
3. **The exemption should be documented in the comment, not removed.** The PRD's non-goal "Do not delete the `msg.sender == address(this)` exemption in this item" permits documenting the exemption condition in the comment. Three of three peers document the exemption (Astra, Kimi); Grok deliberately does not, citing "reachability is not a question for this comment." I align with the three-document position because the exemption exists in the code at `:57-58` and a comment that ignores the line it documents would be incomplete.
4. **The "refunds nothing (API-12)" clause is preserved by all three peers and by the original.** It describes the internal-balance burn surface. It does not change pretransfer semantics and is outside REQ-SEP-04's closed list.
5. **No self-call is added.** All three peers and my retraction agree: the function selects an explicit holder and passes it to `executeRedeem`; it does not call `address(this).redeem(...)`.

## Where I add precision

1. **Grok's deliberate omission of the exemption from the comment is defensible** but thinner than the other two. The exemption exists at `:57-58`; a comment that omits it leaves a reader to wonder why the `&&` guard exists. I do not register this as a disagreement — Grok's "reachability is not a question for this comment" is a legitimate scope line — but the closer replacement is the one that documents the exemption condition while disclaiming reachability, which is what Kimi does and what I close on below.
2. **Astra's phrasing "passes the selected holder explicitly to internal settlement" is precise** but introduces a `settlement` term not in the current comment vocabulary. It is not wrong, but a comment that mirrors the existing `(API-12)` reference is more conservative.

---

## 5. The one exact NatSpec replacement for lines 41-44

I close on the following replacement, which is Kimi's text verbatim with no edits. I adopt it as the single converged shape because:

- It preserves the original comment's first two lines (flag condition, atomicity, EOA rejection) verbatim, which is useful content that the original author wrote.
- It adds the explicit-holder sentences that the PRD `:159` requires, with `(address(this))` named for the true case and "the caller" for the false case.
- It documents the exemption at `:57-58` (the `&&` guard condition) without claiming a self-call.
- It explicitly states "no current self-call route into this function is claimed" — the reachability non-goal in comment form.
- It does not use "allowance" — the redeem body does not show an allowance spend.
- It does not propose a self-call, does not change the production body, does not delete the exemption, does not redesign custody.

### The exact replacement

Replace the current four-line NatSpec at `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44` with this six-line NatSpec (line count is not constrained; the content is):

```solidity
    /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
    ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. When true, redemption burns exactly `amountSharesToRedeem`
    ///        with the vault (`address(this)`) named explicitly as the holder, and refunds nothing (API-12).
    ///        When false, the holder is the caller. The `msg.sender == address(this)` exemption skips the
    ///        caller check; no current self-call route into this function is claimed.
```

Nothing else in the file changes. The function body, the exemption at `:57-58`, the source/owner selection at `:60-63`, and the `executeRedeem` call at `:64-66` are unchanged. The other contracts in the rebasingVault package are not edited.

### Why every clause is pinned

- "Integrating-contract flag only when true and `msg.sender != address(this)`" — pinned at `:57-58` (the `&&` guard).
- "Transfer-and-consume must be atomic; staged use is at integrator risk" — pinned by the `nonReentrant` modifier at `:51` and the `LocalCreditLib.requirePretransferCaller` check at `:58`.
- "Callers with no bytecode revert `EOAPretransferNotAllowed()`" — pinned at `:58`.
- "When true, redemption burns exactly `amountSharesToRedeem` with the vault (`address(this)`) named explicitly as the holder" — pinned at `:63` (`owner = ... : address(this)`) and `:64-66` (the `executeRedeem` call passing `amountSharesToRedeem` and `owner`).
- "refunds nothing (API-12)" — pinned by the absence of any refund branch in the function body and the `PublicBalanceExactBurn` source at `:61`.
- "When false, the holder is the caller" — pinned at `:63` (`owner = ... : msg.sender`).
- "The `msg.sender == address(this)` exemption skips the caller check" — pinned at `:57-58` (the complement of the `&&` guard).
- "no current self-call route into this function is claimed" — pinned by the absence of any `this.redeem(...)` or equivalent in the function body and the entire file (no production self-call into this function was established, per PRD `:157`).

The implementer cannot choose any clause differently. The replacement is the only shape that satisfies the PRD's three acceptance bullets, preserves the two non-goals, and matches the production body byte-for-byte.

---

## 6. What would change this answer

I would re-open the answer only if:

1. The redeem body shows an allowance spend that I missed. — Not true. The body at `:45-67` has no `allowance`, `transferFrom`, or `approve` call.
2. The exemption's condition is different from what the comment states. — Not true. `:57-58` reads `if (burnFromInternalBalance && msg.sender != address(this))`; the skip is the complement.
3. The holder selection at `:63` is not `address(this)` for the true case. — Not true. `:63` reads `address owner = burnFromInternalBalance ? address(this) : msg.sender;`.
4. The PRD requires a different comment shape (e.g., no exemption mention, or no API-12 reference, or no holder naming). — Not true. The PRD's three acceptance bullets and two non-goals are satisfied by the closed replacement.

None of these is true. The answer stands.

---

## 7. Findings

### Cross-ADJ01-1 — Retraction of "allowance" clause in my own first pass

- **Severity:** N/A (retraction, not a new defect).
- **File and line:** `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/minimax-adj01.md` (the replacement text I drafted at "The exact replacement NatSpec for lines 41-44").
- **Broken instruction:** "the burn is from the caller's balance via allowance or ownership." The redeem body at `RebasingAwareStandardYieldTarget.sol:45-67` does not show an allowance spend. The phrase "via allowance or ownership" is an over-specification. I retract.
- **Impact class:** Documentation accuracy. A reader following the comment would look for `allowance` in the redeem body and not find it.
- **Fix direction:** Use the closed replacement in §5. It describes the second branch as "the holder is the caller" without invoking the word "allowance."
- **Confidence:** High on the source trace; high on the over-specification.

### Cross-ADJ01-2 — Closed replacement converges

- **Severity:** N/A (closure, not a defect).
- **File and line:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44`.
- **Verification:** All three peer originals provide NatSpec replacements that satisfy the PRD's three acceptance bullets and two non-goals. My retraction of the "allowance" clause aligns with all three peers. The closed replacement in §5 is Kimi's text verbatim; it preserves the original comment's first two lines, adds the explicit-holder sentences, documents the exemption condition, and explicitly states "no current self-call route into this function is claimed."
- **Impact class:** No remaining ambiguity. The implementer can copy the closed replacement verbatim.
- **Confidence:** High on the source trace; high on the PRD alignment.

---

## 8. Dissent or unresolved items

**Dissent from my own first pass:** The "allowance or ownership" clause was over-specified. The redeem body does not show an allowance spend. I retract and adopt the closed replacement in §5.

**Agreement with the three peer originals:** All three peers agree on the headline (No blocking question), the four substantive points (explicit-holder, no self-call, exemption documented or explicitly omitted, no allowance), and the fact pattern. The variance is in comment length and style, not in content.

**Unresolved item:** None. The closed replacement in §5 is the single converged shape.

---

## 9. Files examined (this cross-review)

- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/astra-adj01.md` — read in full (56 lines).
- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/grok-adj01.md` — read in full (31 lines).
- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/kimi-adj01.md` — read in full (39 lines).
- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/minimax-adj01.md` — re-read for self-consistency. Not treated as a peer.
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` — re-read at `:45-67` to confirm the "allowance" retraction.
- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` — already read in the previous turn; not re-loaded.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.