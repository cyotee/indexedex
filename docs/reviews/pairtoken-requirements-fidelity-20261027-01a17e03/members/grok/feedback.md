# Coordinator-preserved advisory feedback

Returned inline by grok from the recovered continuation of the same advisory assignment. Preserved verbatim from Native final_response. This does not replace the independent original. The member did not write this file.

---

I read this as the unfinished advisory disposition, already hash-checked and read. I'll stop when the six sections are returned.

## Identity

- Run ID: pairtoken-requirements-fidelity-20261027-01a17e03
- Member label: grok
- Phase: one advisory review of the pinned draft. This does not replace the initial response.
- Peers and originals re-read: no
- File written: no

## Draft under review

- Path: /Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/coordinator/draft.md
- Identity: pairtoken-fidelity-draft-r1
- Hash check: exact match. `shasum -a 256` on that path returned `93ee39664d6ff7fb77b4d079ad9f76c9d69a1469fb0672b843026265990bff56`.

## Disposition

Approve with concerns.

C1 and C2 adopt both Low corrections from the original. The lead answer does not flatten that into unqualified approval of the unchanged wording, and it does not treat the coordinator as a fifth vote. One clause of the proposed C1 replacement should be tightened before it is frozen. No further round is requested.

## Concerns

### C1 proposed ERC-20 clause says "increase"

- Location: Recommended clarifications, C1, the proposed PT-DEP-05 sentence: "an ERC-20 pull returns its measured balance increase."
- Concern: The original asked for the checked balance difference, including zero. A successful ERC-20 pull can return zero when the balance does not rise. "Increase" can be read as excluding that receipt. The rest of C1 is a faithful adoption: pull-returned amounts, nominal native return, PT-BAL-02 left in place, and the zero-native event/refund case correctly described as a misreading rather than a guaranteed funding failure.
- Requested change: In that sentence, say "checked balance difference, including zero" rather than "measured balance increase." The PT-EVENT-02 sentence can keep "measured ERC-20 receipts" if receipt means that difference.

No other change is requested. C2's decision not to treat a reentrant `balanceOf` mutation as established is accepted. The ordering pin itself was adopted, including the paired-entry price-after-idle distinction and Deploy's already-held price.

## What was not adopted from others

Using only this draft's attribution:

- MiniMax F1 is acknowledged as a conditional uncapped-fee consequence and is not elevated to a blocking gap. No fee clamp is adopted.
- MiniMax F2 is not adopted as a correction to the slot formula. The draft treats `abi.encode` and `abi.encodePacked` of two 32-byte words as the same preimage.
- MiniMax F3-F5, Astra's extra vectors, and the qualitative boundary note attributed to Grok are verification-plan recommendations, not findings that the requirements are false or incomplete.
- MiniMax O1's licensing attribution is not adopted. The draft offers no license determination.

## Limits

- This pass reviewed only the hash-matched draft. Source, requirements, originals, peer files, and the feedback path were not reopened.
- Coordinator locators outside the original, including PairToken.sol:271-274, were not re-verified here.
- Other members' routes, files, and verbatim archival were not checked. The draft's statement that this member returned inline is accurate. Its claim that the coordinator preserved that text verbatim is not confirmed by this pass.
- N1's numerical example was not re-derived against source. It is the draft's conditional illustration, not an original finding.
- No legal clearance, clean-room certification, or implementation authority is added. Static reading remains not runtime proof.

