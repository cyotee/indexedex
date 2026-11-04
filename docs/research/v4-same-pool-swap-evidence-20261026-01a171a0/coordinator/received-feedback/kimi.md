# Coordinator receipt of Kimi advisory feedback

Native task st_01a1773f, epoch 1. Inline delivery because project-scoped apply_patch was unavailable. This is the complete member-authored feedback, not a rewrite. It does not replace the initial response.

---

# Advisory feedback - kimi

## Identity

kimi, author of the initial this advisory continues (task st_01a1773f). This file does not replace my initial response; it reviews only the coordinator draft named below. Delivered inline because project-scoped apply_patch is absent in this session; I did not use write/edit and do not claim to have written `members/kimi/feedback.md`. Coordinator may file this at `coordinator/received-feedback/kimi.md`.

## Draft under review

- Draft ID: draft-v4-same-pool-swap-evidence-20261026-01a171a0-r1
- Path: `/Users/cyotee/Projects/indexedex/docs/research/v4-same-pool-swap-evidence-20261026-01a171a0/coordinator/draft.md`
- sha256 verified against the exact bytes: `54172c64b0cefb36c78d9c677062f14e833f42acfc0d365064a28ca4e480898f` - matches the assignment. This is the draft I was asked to review.

## Disposition

**support.**

## Concerns

none.

## What was not adopted from others

I did not read peer originals or peer feedback, so I can only observe what the draft itself says it declined: Domain L's lender existence, Domain N and Grok's grid magnitudes (labeled member-reported/unrechecked), MiniMax's idle-book profit surviving default-spacing wings (labeled a reachability gap), and my own `+9627.8` as closed target profit. On that last point the draft's treatment of my evidence is accurate and stricter than my prose: the rechecked row decomposes as target delta `-9833.90` plus opposing residual `+19461.68`, and `conv = dT + dO` checks arithmetically at `9627.78`; my original labeled convention value as an upper bound elsewhere in the text but did write "+9,627.8 T" in one verdict sentence, and the draft is right to refuse that label. The default literal row (`+1127.47` / `-1955.08` / `-827.61`), the baseline closed row (`+18055.89`, incumbents `0.208020 -> 0.189964`), and the proportional attack rows (`+115.12` conv with `+636.86` residual at fee 0; `-470.48` at 0.1% fee) all match my original's numbers, and unrechecked items of mine (W4/W5, the slice-exit variant of W2, the TWAP replica, the 0 ppm invariant witness) are labeled as member-reported rather than silently adopted as rechecked. No disagreement of mine is erased: the disagreements table carries my positions on 49/50/51 sizing and on getRate.

On getRate specifically, I accept the draft's correction as an improvement over my Section 6. The source at `EconomicTarget.sol:29-32` returns the whole-book liquidation quote over supply; that is a mass-exit per-share value with whole-book sale impact amortized into every share, not a one-share-sized withdrawal-and-sale execution preview, which would sell only one share's slice and typically pay more. My identification of the two overstated the equivalence; the draft preserves the requested one-share semantics as a constraint without converting it into implementation authority, and correctly notes it does not authorize the distinction. One nuance I add for the record, not as a requested change: because the whole-book quote amortizes maximal impact, the current getRate is conservative relative to the requested one-share preview, which matters for how downstream consumers should interpret the direction of the error.

## Limits

- I verified the draft's hash and the internal arithmetic of the recheck rows that adopt my numbers (the two `conv = dT + dO` identities at P0=1 and the quoted baseline/proportional rows). I did not re-execute my model for this advisory; the session kernel that held it was reset, and the draft labels its own re-execution separately from mine, so no number is being adopted as rechecked on my say-so.
- The draft does not turn the research conclusion into implementation authority: it states "not implementation authority," "no project code, configuration, or Git action is authorized," and keeps audit PoCs as reported-not-rerun. I find no instance of the draft claiming a raised quote or a convention-valued residual as realized profit.
- The draft's framing of the missing astra initial ("absence is not agreement," partial full council) is consistent with the brief's no-substitution rule.
- My support covers fidelity of evidence handling and labeling. It is not an independent endorsement of the coordinator's own model rows (the single-interval immediate-deposit model), which I did not research and do not vouch for beyond noting the draft labels them as coordinator arithmetic with disclosed domain.
