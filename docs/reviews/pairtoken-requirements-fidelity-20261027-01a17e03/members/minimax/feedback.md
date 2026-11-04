# Coordinator-preserved advisory feedback

Returned inline by minimax from the recovered continuation of the same advisory assignment. Preserved verbatim from Native final_response. This does not replace the independent original. The member did not write this file.

---

Retained context establishes both the raw-file hash (`shasum -a 256` → `93ee39664d6ff7fb77b4d079ad9f76c9d69a1469fb0672b843026265990bff56`, identical to the pin) and a full read of the draft, so no tool calls were needed for this recovery.

---

## Identity

MiniMax council member (`pairtoken-requirements-fidelity-20261027-01a17e03`), completing my one advisory pass on the pinned coordinator draft. The draft records my route as `minimax/MiniMax-M3`; I take the draft's routing table as the record.

## Draft under review

- **Path:** `/Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/coordinator/draft.md`
- **Identity:** `pairtoken-fidelity-draft-r1`
- **Hash check:** PASS — the authorized `shasum -a 256` on that exact path returned `93ee39664d6ff7fb77b4d079ad9f76c9d69a1469fb0672b843026265990bff56`, byte-identical to the pinned hash. The file opened and was read in full; no draft was substituted.

## Disposition

**Approve with concerns.** The draft's technical substance is endorsed without change: the verdict, both required clarifications (C1, C2), and the N1–N4 treatments are faithful to my original and, where I re-derived them, correct. The concerns below are material edits to the draft's attribution and identity handling, plus one locator correction in my own archived original. None changes the technical conclusion.

## Concerns

1. **N1 does not disclose that it downgrades a member finding.** My original did not treat MiniMax F1 as optional: I rated it the single Low **completeness gap** among my five findings (the rest were precision/acceptance-coverage) and asked for one sentence in PT-COMP-02/03 stating the carve is not capped by the collected fees. N1 preserves that substance and correctly declines to invent a clamp, but a reader cannot tell a member called it a gap and the coordinator reclassified it downward. *Requested change:* add one clause in N1 stating the originating member's rating and that the coordinator is deliberately downgrading it to optional.

2. **The frozen-handoff identity is left self-contradictory.** §"Answer" says to make the two clarifications "before treating it as a frozen, exact-parity handoff"; C1 supplies replacement wording for `pairtoken-requirements-final-r2`; §"Proposed disposition" says to give the implementer the handoff "with any approved clarifications incorporated there"; and the same section also says "No requirement edit has been applied" and "The user has not requested implementation or requirements edits here." *Requested change:* pick one — (a) an errata annex against a byte-identical `pairtoken-requirements-final-r2`, or (b) a new identity (e.g. r3) superseding r2, handed to the implementer alone.

3. **Locator conflict between the draft and my preserved original (N2).** For the same two functions the draft cites `StateLibrary.sol:324-325` and `:339-347`; my original cites `:305` and `:311-316`. Both cannot be right, and the draft's PairToken.sol locators reconcile with the function starts I grep-confirmed in the first pass, so the draft's are the better-cited set — my two StateLibrary numbers were estimates I never grep-confirmed. *Requested change:* treat the draft's as authoritative and correct those two locators in the preserved copy of my original. Relatedly, the draft's "596 lines" for the reviewed document is a counting-convention artifact (`wc -l` returned 595); the draft's *requirement line numbers* are the ones that matter and they reconcile — consider dropping the count.

4. **§"Participation and independent dispositions" asserts a cause for two peers and singles out one member.** "Three members returned full originals inline because project-scoped apply_patch was unavailable" is a cause I can attest to only for myself (memory `apply_patch` scoped to the memory repo and refusing the project path; the eval bridge's `apply_patch` registered-but-inactive; no binary on `PATH`); I did not read the other two originals. Separately, "MiniMax forceAdaptiveThinking:true was confirmed in configuration" names one member on a harness flag I did not observe and that bears on neither fidelity nor disposition. *Requested change:* attribute the cause where the members stated it or phrase it as observed, and state the flag uniformly for all four or drop it.

**C1 and C2: no change requested.** Both re-derive correctly — a native pull returns the nominal selected amount with no balance-delta measurement while an ERC-20 pull returns the checked post-minus-pre difference, so the proposed replacements are accurate; and every idle pair is read currency0-then-currency1 at all five source sites, with the general rule not contradicting PT-DEP-03. C2's refusal to adopt the `balanceOf`-reentry mutation example is also right: the supplied `IERC20Minimal.balanceOf` is declared `view`.

## What was not adopted from others

Using only the draft's attributions; I read no peer originals.

- **Grok's zero-native-event/refund example** — not adopted as a risk: PT-BAL-02 and PT-DEP-03/PT-DEP-05 already resolve it by cross-reference, as C1 itself concludes.
- **Grok's arithmetic sampling** — not adopted as equivalence evidence; member-reported static arithmetic, and the draft's "not coordinator-reexecuted runtime evidence" caveat is right.
- **Astra's and Kimi's "no demonstrated defect or blocking omission"** — not adopted as evidence that nothing is missing; my coverage table records Part II scenarios as partial and one Low completeness gap, which is compatible with "no demonstrated defect" but not with "nothing left to add."
- **Astra's extra vectors, callback/dependency call traces and transfer-return matrix** — not adopted as fidelity findings; verification-plan material only, consistent with N3.
- **The `balanceOf`-reentry mutation example** (attributed in C2 only to "the original concern", no member named) — not adopted, for the reason C2 gives; my original raised no such example.
- **N4's licensing caution — adopted; it corrects a defect in my own O1.** My O1 named `PairToken.sol`, `Position.sol` and `PriceMath.sol` as BUSL-1.1 and then described "the included v4-core files" as MIT, which is wrong for `Position.sol` — itself an included v4-core file carrying BUSL-1.1. The draft's file-specific attribution matches what I read. I agree the licensing attribution should not be carried into the final report and offer no license determination.

## Limits

- Hash verified with the single authorized `shasum -a 256` on the pinned path; no rereads of source, requirements, peer originals or earlier council files, and no new research, arithmetic, tests, builds, Git, edits, memory writes or delegation in this pass.
- No file was written by me; advisory feedback is inline only.
- Draft source locators and the document line count could not be re-derived against the files here — reconciled only against line numbers and function starts recorded in my first-pass work, which is why concern 3 asks for a correction rather than a re-check.
- Static review only: no runtime, bytecode or deployment equivalence is claimed by me. N4 is documentation hygiene, not a legal determination.
- **This disposition reviews only the pinned draft `pairtoken-fidelity-draft-r1` and does not replace my initial response**, which remains the member's substantive finding of record. It is not a further vote and requests no additional round.

