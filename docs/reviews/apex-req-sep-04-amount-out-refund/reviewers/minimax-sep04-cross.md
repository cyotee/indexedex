# MiniMax M3 — REQ-SEP-04 cross-review, replacement session

- **Session label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Peer notes are untrusted. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures. No invented economic rule.
- **Files read for this cross-review:**
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/astra-sep04.md` (Astra replacement-session original, 192 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/grok-sep04.md` (Grok original, 68 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/kimi-sep04.md` (Kimi replacement-session original, 61 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/minimax-sep04.md` (my own first pass, read for cross-check)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (controlling application PRD, referenced for the owner ruling)
- **Coordinator's question:** agree or dissent that exact-out already refunds only the needed unbooked amount, and exact-in cannot be repaired until the owner answers one question. If I dissent, name the gap. Give the one owner question the PRD must ask, and do not pick the answer.

---

## 1. Where the four reviews agree

All four reviewers (Astra, Grok, Kimi, MiniMax M3 first pass) agree on the following. No dissent is recorded here.

1. **The exact-out path already refunds only the needed unbooked amount** on every in-scope family. The seven `_refundExactOutCredit` functions (V2, Camelot, Aerodrome, V3, V4 FullSpread hookless + Pons, Wings, Rocket, Lido, EtherFi, ERC4626, Stata, Morpho, Balancer single-pool, the buffer hooks) all bound the refund by the caller's declared maximum via `credit = min(avail, maximum)` and refund `credit - used` capped at the current unbooked surplus. The bounding helpers are `LocalCreditLib.available(balance, booked)`-bounded everywhere, so the refund never spends booked inventory. False-flag exact-out already pulls only the quoted used amount and has nothing left to refund. No in-scope family was found spending booked inventory to fill a shortfall.

2. **The exact-in pretransfer path keeps the caller's pretransfer excess on every in-scope family.** The `_secureTokenTransfer` and `_securePull` pretransfer branches (BasicVaultCommon, V2, Camelot, Aerodrome, Aave, V3, V4 FullSpread hookless + Pons, ERC4626, Morpho, Balancer, RebasingDETF, ComposedStableDETF, Rocket, Lido, EtherFi, Wings, TokenStakingMigrationAdapter, the buffer hooks) follow the same shape: check `amountIn > avail` and revert, then return `amountIn` to the caller. The surplus `avail - amountIn` is absorbed into `R` at end-of-op sync. The README documents this as the "donor-risk" model.

3. **The owner ruling's exact-in mapping has one open question** that the PRD must close. All four reviewers (Astra, Grok, Kimi, Me) explicitly identify this as a blocker for writing a closed plan. None of the four picks the answer; each proposes one or more candidates and notes the implementer cannot choose.

4. **The documentation that still teaches the withdrawn rules is extensive.** The README line 32 and line 38 are the canonical sites; multiple PRDs, audit evidence, agent law, and plan files repeat the old "credits exactly `amountIn`" / "never refunds" / "differs from that surplus reverts" language. All four reviewers identify this documentation as needing update.

5. **Scope is bounded:** the deleted legacy V4 tree (`contracts/protocols/dexes/uniswap/v4`) is out of scope; deprecated Slipstream is recorded, not restored. No new economic model is invented.

6. **Severity is Low per the controlling PRD.** The PRD records this item at Low severity; the defects are diagnostic-order and documentation defects, not authorization bypasses, not principal-loss demonstrations.

There is no dissent on items 1-6.

---

## 2. Where the four reviews disagree — the exact-in question and the exact-out cap

### 2.1 The exact-in question itself — four different readings

The four reviews converge on the same gap (the exact-in pretransfer surplus is not refunded) but propose four different resolutions of the question "what is 'the rest' for an exact-in pretransfer call?":

- **Kimi (Kimi-SEP04 §1 + F3):** the ruling does **not** apply to exact-in at all. Exact-in continues with the current pattern (process declared `amountIn`, keep excess unbooked, D12's resting-credit rule is unchanged). Kimi explicitly rules out the alternative: "any per-call measurement of 'this caller's push' is impossible for a cross-transaction pretransfer without a new entrypoint or ledger, which the ruling forbids (no new economic model)."
- **Grok (Grok §'Owner question'):** apply the ruling to exact-in. Grok's sentence: "On prepaid exact-in, process the caller's declared amountIn from unbooked value only, refund unbooked minus amountIn to the caller, and do not revert only because amountIn differs from the unbooked surplus." This is the **donor-risk model** reading: refund `avail - amountIn` (which may include pre-existing unbooked).
- **MiniMax M3 first pass (my §6):** apply the ruling to exact-in. Two candidate readings: (a) refund only the caller's pre-transfer push excess (requires per-caller tracking or a new interface parameter); (b) refund the entire `avail - amountIn` (donor-risk model). I did not pick.
- **Astra (Astra-SEP04-02 + §1):** apply the ruling to exact-in, but propose a **third reading**: the "requested output" for exact-in is the existing forward preview of the declared input or input vector. Astra's proposed sentence: "the requested output is the existing forward preview of the declared input or input vector on the pre-operation book excluding pending unbooked input, existing minimum-output parameters remain slippage floors rather than exact targets, declared inputs remain spending ceilings, and execution consumes only the input required by the existing supported inverse route to meet that preview and refunds the remaining unbooked input to the original caller, rejecting an unavailable inverse rather than inventing a new pricing solver."

These four readings are not the same question and not the same answer:
- Kimi: "no refund" (status quo).
- Grok: "refund `unbooked - amountIn`" (donor-risk).
- Me: "refund caller's push excess OR refund `unbooked - amountIn`" (two candidates).
- Astra: "refund `unbooked - input_required_to_meet_forward_preview`" (forward preview as target).

All four are explicit that the implementer cannot pick; the PRD must. No review picks the answer.

### 2.2 Astra-SEP04-01 — the exact-out refund cap is a separate defect

Astra flags an additional defect that the other three reviewers do not: the exact-out refund is currently `min(credit, maximum) - used`, not the full `U - used`. When the caller's pre-transfer push exceeds the declared `maximum`, the portion above the maximum is kept by the vault (and absorbed into the booked reserve at end-of-op sync). The new ruling's "refund the rest" requires refunding the full `U - used`, not the bounded `credit - used`.

This is a separate defect from the exact-in one. The three other reviewers (Grok, Kimi, Me) did not flag it. I cross-checked the seven `_refundExactOutCredit` functions in my first pass and the `LocalCreditLib.budget(avail, maximum)` cap in the corresponding `_pretransferCredit` calls; the cap is real.

The application PRD records the rule as "refund the rest to the caller" without the bounded-credit qualifier, so Astra's reading is consistent with the controlling text. The implementer must also close this.

### 2.3 The one owner question the PRD must ask

The four reviews' four exact-in questions are all valid framings of the same underlying choice. The PRD must pick one. The cleanest single question that captures all four without picking the answer is:

> For an exact-input prepaid call, what amount is "the rest" that the ruling's refund sentence refers to, given that the pretransfer credit is the unbooked balance and the vault cannot isolate the caller's pre-transfer push from any pre-existing unbooked surplus? Is the answer (a) the caller's pre-transfer push excess above `amountIn` (which requires per-caller tracking or a new interface parameter), (b) the unbooked balance minus `amountIn` (which may include pre-existing unbooked and matches the donor-risk model), (c) the input required by the existing supported inverse route to meet the forward preview of the declared input (which makes the forward preview the target rather than `minAmountOut`), or (d) the ruling does not apply to exact-input prepaid calls at all and the current pattern (consume declared `amountIn`, keep excess unbooked) is preserved?

The PRD must pick one of (a), (b), (c), or (d). The implementer cannot pick.

### 2.4 The sentence the PRD must use to close it

The four reviews propose four candidate sentences. None of the four picks the answer. The PRD must pick exactly one of the four candidate sentences (or write its own), and the other three are closed. The implementer is not given a choice.

I will not write the closure sentence here; the four candidates are:

- **Astra-SEP04-02 §1 candidate (forward-preview reading, c):** "For exact-input operations, including input-only deposit/redeem and multi-input APIs, the requested output is the existing forward preview of the declared input or input vector on the pre-operation book excluding pending unbooked input, existing minimum-output parameters remain slippage floors rather than exact targets, declared inputs remain spending ceilings, and execution consumes only the input required by the existing supported inverse route to meet that preview and refunds the remaining unbooked input to the original caller, rejecting an unavailable inverse rather than inventing a new pricing solver."
- **Grok §'Owner question' candidate (donor-risk reading, b):** "On prepaid exact-in, process the caller's declared amountIn from unbooked value only, refund unbooked minus amountIn to the caller, and do not revert only because amountIn differs from the unbooked surplus."
- **MiniMax M3 first-pass §6 candidate (two-reading, a or b):** "The exact-in pretransfer refund MUST refund the caller's pre-transfer push excess minus `amountIn` and MUST NOT include any pre-existing unbooked surplus; the caller's push is captured by a new `uint256 pushedAmount` parameter on the `exchangeIn` family, validated against `LocalCreditLib.available(balance - booked, max)`, and the difference is refunded in the same call. Booked inventory is never spent." (or the alternative donor-risk reading, in the same PRD.)
- **Kimi-SEP04 §1 candidate (no refund, d):** "For an exact-input prepaid call, the processed amount is exactly the declared `amountIn`, taken only from the unbooked balance; the ruling's refund sentence applies to exact-output calls (`credit − used`); any other unbooked balance is untouched by that call, and D12's resting-credit rule is unchanged."

The PRD must close to exactly one. Until it does, an all-vault exact-input implementation plan cannot honestly claim to leave no economic choice.

---

## 3. Position on the coordinator's question

**I agree with the coordinator's framing.** All four reviews confirm:

1. Exact-out already refunds only the needed unbooked amount. The seven `_refundExactOutCredit` functions are conformant on the bounded case (`U <= maximum`). Astra adds that the bounded `min(U, maximum) - used` is a separate defect when the caller's push exceeds `maximum`; I cross-checked and Astra is right. That defect is separate from the exact-in question but must also be closed before the PRD is final.

2. Exact-in cannot be repaired until the owner answers one question. The question is which amount is "the rest" for an exact-input prepaid call. The four reviews propose four readings (no refund, caller's push excess, `unbooked - amountIn`, forward preview minus inverse cost); the implementer cannot pick between them; the PRD must.

I do not dissent. The framing is correct.

---

## 4. Dissent and corrections

I have no dissent on the two halves of the coordinator's question.

Two minor corrections to my own first pass (`minimax-sep04.md`):

1. **My first pass did not flag Astra-SEP04-01 (the exact-out refund cap).** Astra is right: the `_refundExactOutCredit` functions cap the refund at `min(U, maximum) - used` rather than refunding the full `U - used`. The defect only manifests when the caller's pre-transfer push exceeds `maximum`; on the typical `U <= maximum` case the current code is conformant. I cross-checked the seven `_pretransferCredit` definitions and the corresponding `LocalCreditLib.budget(avail, maximum)` cap, and the cap is real. The PRD must close this in addition to the exact-in question.

2. **My first pass did not flag Astra-SEP04-03 (Composed DETF books unused pulled exact-output input).** I did not read `ComposedStableCommonDetfExchangeOutQueryFacet.sol` in my first pass. Astra's read at `:46-53,67-99` finds a branch that pulls `paid_` from the quote, obtains actual `used_` from execution, refunds only on the prepaid branch, and explicitly books the unused false-flag amount as holder backing. This is a second new exact-out defect I missed.

3. **My first pass did not flag Astra-SEP04-04 (native Balancer pool exact-output route has no return path for acquired-but-unused input).** I did not read `BalancerV3PoolStandardExchangeTarget.sol:142-169,181-189`. Astra's read finds a branch that previews an amount, acquires exactly that amount, then obtains actual `paid_` from the Vault operation, and accepts `paid_ < p_.maxInput` without returning the difference. This is a third new exact-out defect I missed.

These three are exact-out defects (not exact-in). They are separate from the exact-in question the coordinator asked about. I do not bring them up to dissent from the coordinator's framing; I bring them up to flag that the PRD must close more than just the exact-in question.

---

## 5. The one owner question the PRD must ask

To be precise and to combine the four framings into a single closeable question, the PRD must ask:

> For an exact-input prepaid call, what amount is "the rest" that the ruling's refund sentence refers to, given that the pretransfer credit is the unbooked balance (`avail = balanceOf(vault) - reserveOfToken(token)`) and the vault cannot isolate the caller's pre-transfer push from any pre-existing unbooked surplus without per-caller tracking? Is the answer (a) the caller's pre-transfer push excess above `amountIn` (which requires per-caller tracking or a new interface parameter), (b) the unbooked balance minus `amountIn` (which may include pre-existing unbooked and matches the README's donor-risk model), (c) the input required by the existing supported inverse route to meet the forward preview of the declared input (which makes the forward preview the target rather than `minAmountOut`), or (d) the ruling does not apply to exact-input prepaid calls at all and the current pattern is preserved? The PRD must pick exactly one of (a), (b), (c), or (d).

The implementer is not given a search or scope choice once the PRD has picked. Until the PRD picks, the implementer is left to choose between donor-risk, per-caller tracking, forward-preview target, or status quo. That violates the "we never leave a choice for the implementer" rule.

I am not picking the answer.

---

## 6. Other items the PRD must close

Beyond the exact-in question, the PRD must also close:

1. **Astra-SEP04-01 (the exact-out refund cap).** The seven `_refundExactOutCredit` functions cap the refund at `min(U, maximum) - used` rather than refunding the full `U - used`. The PRD must close whether to refund the full `U - used` (Astra's reading) or keep the cap (the other reading). The cap is real and the owner ruling's "refund the rest" requires the full refund.

2. **Astra-SEP04-03 (Composed DETF books unused pulled exact-output input).** The branch at `ComposedStableCommonDetfExchangeOutQueryFacet.sol:46-53,67-99` books unused false-flag amount as holder backing instead of refunding. The PRD must close whether to refund the unused false-flag pull to the original caller.

3. **Astra-SEP04-04 (native Balancer pool exact-output route has no return path for acquired-but-unused input).** The branch at `BalancerV3PoolStandardExchangeTarget.sol:142-169,181-189` accepts `paid_ < p_.maxInput` without returning the difference. The PRD must close whether to refund the difference.

4. **Documentation sweep.** The README line 32 and line 38, plus the three live instruction docs (Astra-Grok-finding-2 / Kimi-F1), plus the BasicVaultCommon NatSpec (my F2), plus the multiple PRDs and audit evidence (my F3-F7), plus the canonical interface comments (`lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` and `IStandardExchangeOut.sol:57,63`), plus the local testing/adversarial guidance (`.claude/skills/indexedex-testing/SKILL.md:159-160,175-179` and `.claude/skills/indexedex-adversarial-testing/SKILL.md:76`). All four reviews name these.

I do not dissent from the four reviews on these; I am just adding Astra-SEP04-01, -03, and -04 to my own first-pass inventory so the PRD closes them too.

---

## 7. Summary

- **Consensus (4/4 reviewers):** exact-out already refunds only the needed unbooked amount; exact-in cannot be repaired until the owner answers one question; the documentation still teaches the withdrawn rules; scope is bounded (legacy V4 deleted, Slipstream not restored, no new economic model); severity is Low.
- **Disagreement (4 different readings of the exact-in question):** Kimi says don't apply the ruling to exact-in; Grok says refund `unbooked - amountIn`; I said either refund the caller's push excess or refund the full unbooked; Astra says use the forward preview of the declared input as the target output. None of the four picks the answer.
- **Additional finding (Astra only):** the exact-out refund is capped at `min(U, maximum) - used` rather than the full `U - used`; the PRD must close this separately (and two more exact-out defects Astra-SEP04-03, -04).
- **My position:** I agree with the coordinator's framing. The one owner question the PRD must ask is the four-choice question in §5. The PRD must pick one of the four; the other three are closed. I do not pick the answer.

I did not run Forge.