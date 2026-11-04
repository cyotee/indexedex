# Identity

- Member: kimi
- Profile: research
- Phase: one advisory review of the frozen draft
- Requested role: council-member
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity: not exposed
- Peers read before submission: no

# Draft under review

- Path: `docs/research/se-fullspread-hook-matrix-20261104/coordinator/draft.md`
- Draft ID: `draft-se-fullspread-hook-matrix-20261104-r1`
- Coordinator-supplied SHA-256: `0ee55f1e89a984afe5b6f20fe2491b7220f7114bd1ea8120da99aaf57482932c`
- The exact draft opened successfully. The supplied hash was not recomputed.

# Disposition

requested-changes

# Concerns

1. **Replacement for plan section 12, opening row-file instruction.** “Add one row file beside each live behavior below” contradicts the later Weighted `_N3.t.sol` and Balancer `_5.t.sol` files. An implementer following the opening sentence could omit the larger-leg setups that FS-HOOK-01 requires. Replace it with “Add the row files named below beside each live behavior, including the separately named larger-leg rows.”

2. **Curve quad, Directions.** “One named raw token” does not name which of the two raw tokens is the counterparty. Two implementers can bind different pairs. Bind the exact-input face/raw directions to the first raw token in the ascending sorted record, and use that same named raw leg for the associated assertions.

3. **Balancer quad, Directions for the 5-leg row.** “One named raw token” likewise leaves three possible raw counterparties. Bind the face/raw directions to the first raw token in the ascending sorted 5-leg record. The 2-leg row is already unambiguous.

# What was not adopted from others

The draft does not adopt my original per-topology currency1 rate-target repetition for `single/`, the Weighted 3-leg file, or the Balancer 5-leg file. It also makes Orbital `poolKey12` a transfer control rather than a V4 conversion pair. These are not defects under this review: `single/` has no provider field, the larger-leg files expressly rely on the base file's two target pools, and `poolKey12` contains no V4 leg.

No peer response or peer feedback was read, so no other member's omitted recommendation is assessed.

# Limits

This is one advisory review of the frozen draft only. The requested corrections are limited to an internal contradiction and missing bindings that two implementers could copy differently; no rejected alternative is treated as a defect. This feedback does not authorize implementation, does not replace the draft, and does not start a second review round. No tests were run.
