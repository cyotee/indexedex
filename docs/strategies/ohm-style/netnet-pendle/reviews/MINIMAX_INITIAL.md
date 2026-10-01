# MiniMax M3 — Initial PRD review (≤400 words)

- Source: `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD_INITIAL.md` v0.1, dated 2026-09-21.
- Reviewer: MiniMax M3 (council, independent pass).
- Verdict: reviewable PRD draft; not execution-ready.

## Verdict

Faithfully captures human selections (R01–R13); correctly flags FoT/rebasing policy conflict (Section 2); separates queued vs prospective epoch state (Section 9); accurately frames mandatory reinvestment and the wrapper engineering blocker (Section 12). Several MUST-FIX items below; rest is polish.

## MUST-FIX edits

1. **Section 2 (line 22)** — sharpen "An active tax exemption does not itself change the repository policy": the FoT ban carve-out is repository-level; NetNet's whitelist action is **separate and additive**. Add: "Neither is sufficient alone; both are required."
2. **Section 8 (line 127)** — "This design does not depend on NetNet granting an exemption" is correct **for the SE/hook leg** but asymmetric for third-party LPers adding to the V2 pair, who will still be taxed. Note the asymmetry: the IndexedEx SE absorbs tax on its own transfers; it cannot change how external parties are taxed on their adds/removes.
3. **Section 9 (line 141)** — "D50 first-bond clock remains in effect for non-NET-synchronized expansions; new family adds a separate clock." Explicit guard to prevent silent re-anchoring.
4. **Section 12 (line 192)** — engineering blocker text correctly identifies DoS; **add the architectural consequence**: "Wrapper must decouple per-position control from the upstream `notes[to]` array; a wrapper alone without a custody-side selection mechanism cannot prevent this."
5. **Section 4 (line 65)** — "Projected changes through one facade must be visible when another facade quotes the same transaction." Strengthen by linking to `IStandardExchangeTransitionQuote` interface as the contract surface (`contracts/interfaces/IStandardExchangeTransitionQuote.sol:17-58`).

## OPTIONAL edits

6. **Section 5 acquisition table (line 76)** — "Pricing, incentive treatment, cliff versus linear release" — add "Eligible inputs must resolve to live pair/PT/YT addresses; arbitrary future PT/YT do not auto-appear in fixed route tables."
7. **Section 11 (line 161)** — define "validate target": list the bounded checks (factory provenance; SY/PT/YT identity; expiry; liquidity; fee/curve).
8. **Section 14 O04** — bound the hook choice to the four named variants (Orbital / Curve-stable / Balancer-style V4 / Weighted), not "or supported variants" open-ended.
9. **Section 16 E02** — line range `1007–1125` is reasonable; cross-check §24.4 starts ~1007, D43 ~1087, D51 fallback ~1106.
10. **Section 17** — add explicit review output paths: this review saved at `docs/strategies/ohm-style/netnet-pendle/reviews/MINIMAX_INITIAL.md`.

## Save decision

This review is saved to `docs/strategies/ohm-style/netnet-pendle/reviews/MINIMAX_INITIAL.md` using a permitted document tool. Initial PRD and consolidated PRD are not edited.

## Notes on evidence

- `INET.sol:31-77` — verified tax getters.
- `NET.sol:121-145,184-252` — verified tax predicate and exemption flow.
- `Staking.sol:129-150`; `IStaking.sol:27-35`; `Distributor.sol:43-98` — verified queued vs prospective semantics.
- `BondDepository.sol:88-198`; `IBondDepository.sol` — verified note aggregate-redeem and 2-day local / 5-day stale discrepancy.
- `DETF_ALIGNMENT_PRD.md` D32–D66 / §24 — current law reference.
- `DETF_INSTANCE_IO_ROUTING_PRD.md:1264-1438` — I/O and route references.

**Implementation unauthorized.**
