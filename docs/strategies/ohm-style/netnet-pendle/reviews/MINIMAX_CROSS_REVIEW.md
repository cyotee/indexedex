# MiniMax M3 — Cross-review (≤300 words)

- Source: cross-review of Astra and Grok initial-PRD first-pass reviews (v0.1).
- Reviewer: MiniMax M3 (council, in-session cross-review).
- Verdict: (a) reviewable PRD draft — ready for consolidated handoff; (b) execution-ready only after O01–O05 resolved.

## Accept (peers)

**Astra #1** (reentry accounting boundary, §108, 186–190): correct — external notes are exclusive NFT property pre-reentry; post-reentry minted DETF/staked receipts belong to the NFT, not the common reserve.

**Astra #2** (atomic attribution snapshots, §65, 100, 110–112, 139, 155): correct — coherent snapshots per composed operation; do not silently reattribute unsolicited notes to next depositor.

**Astra #3** (separate NFT transfer policy from custody feasibility, §215, 217): correct — owner chooses transferability; custody feasibility is engineering gate.

**Grok #1** (§2/R05 explicit NET/USDG pair): correct — clarify in §2 that the V2 pair tokens are NET/USDG; sNET rebase ban is a route constraint, not a paired token.

**Grok #2–4, #6** (R11/O02/§10/§4/O01): already correctly flagged as OPEN in the draft; reinforce.

**Grok #5** (§12 engineering gate for wrapper rejection): correct — confirmed upstream cannot block.

## Retract (my own MUST-FIX)

**My #1** (mandatory NetNet exemption): retracted. The user explicitly selected taxed nonexempt operation. NetNet whitelist is **optional optimization**, not a precondition. FoT policy carve-out is repository-level (still required); NetNet exemption is additive, not mandatory. Remove "neither is sufficient alone; both are required."

**My #3** (second expansion clock): retracted. The new family **supersedes** D50 first-bond clock for itself; do not add a parallel clock. Section 9 line 141 already guards against silent re-anchoring of the new family's clock.

**My #5** (`IStandardExchangeTransitionQuote` link): sharpen, do not require. Useful cross-reference but not blocking.

## Sharpened external note reentry ownership

Wrapper NFT is the sole owner of: (a) `notes[wrapper]` entries at `BondDepository.sol:54`; (b) reinvested `detfToken`; (c) `sDETF` staking receipts. Wrapper transfer = transfer of all three atomically.

## Verdict

**(a) Reviewable PRD draft — ready for consolidated handoff. (b) Execution-ready only after O01–O05 resolved.** History preserved.

## Save

This review is saved to `docs/strategies/ohm-style/netnet-pendle/reviews/MINIMAX_CROSS_REVIEW.md`. Initial PRD and consolidated PRD are not edited.

## Notes on evidence

- `INET.sol:31-77` — verified tax getters.
- `NET.sol:121-145,184-252` — verified tax predicate and exemption flow.
- `Staking.sol:129-150`; `IStaking.sol:27-35`; `Distributor.sol:43-98` — queued vs prospective semantics.
- `BondDepository.sol:88-198`; `IBondDepository.sol` — note aggregate-redeem, 2-day local / 5-day stale discrepancy.
- `DETF_ALIGNMENT_PRD.md` D32–D66 / §24 — current law reference.
- `DETF_INSTANCE_IO_ROUTING_PRD.md:1264-1438` — I/O and route references.

**Implementation unauthorized.**
