# Astra — NN-02 combined cross-review

2026-09-27. Read complete ORIGINAL Grok (103 lines), MiniMax M3 (124), and Kimi K3 (64) reports together as untrusted evidence. No peer cross-review read. Originals unchanged. Continued Astra session; assigned routing `openai/gpt-6-astra`, not provider verification.

## Verdict and agreement

**Keep NN-02 open and investigate; do not approve a purported sweep-based solution or demand immediate risk acceptance/deferral.** The common source-backed finding remains: arbitrary-recipient appends and permanent all-note scans make upstream collection depend on third-party history. Local purchase caps, frequent claims and isolated custody do not enforce a bound on that history.

Rechecked `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–199`, its interface `:28–54`, and PRD `788–812`. The NFT must control the entitlement; **its ERC-721 contract need not itself be the native note-holding address**. Controlled escrow remains a possible containment design, not a selected implementation or liveness proof.

## Corrections to MiniMax M3

1. **Reject “sweep excess,” “instant-sweep,” and “resets on sweep.”** `redeem(to)` (`BondDepository.sol:143–153`) scans all notes of **msg.sender**, updates claimable entries, then transfers the aggregate vested NET to `to`. That argument selects the cash recipient—not a note subset, a different note owner, or an array reset. No pruning occurs. Sending the aggregate to `feeSink` would include registered principal, not just gifts, and could violate PRD atomic reinvestment and exclusive NFT ownership. Even a separate post-redemption allocation cannot reduce native array length.
2. **A singleton depository does not prevent multiple custodians.** `notes[to]` is keyed by arbitrary address (`:130–138`). Per-position escrow is technically investigable; the defect is that each escrow remains appendable. MiniMax §4(A)'s “not feasible wrapper-only” rationale is wrong.
3. **No selected feeTo gift policy.** Native unsolicited-note proceeds are not automatically fee-destined Pendle rewards. Attribution and permitted destination require a concrete specification, not an imported §13 sweep rule.
4. **No established costs or safe cap.** “Few hundred thousand gas,” illustrative 50-note caps and owner-attested gas ratios do not establish a bound. A `MAX_REDEEM_NOTES` check can refuse an overgrown claim; it cannot make that claim executable. Owner acceptance cannot turn false mechanics or unmeasured numbers into proof.
5. `noteCount` exists in the concrete contract (`:168–170`), not in the inspected `IBondDepository` declaration. Keep the ABI inventory accurate.

## Corrections to Kimi K3

- **Nonzero gifts are not necessarily irrational or self-defeating.** An attacker can spend a small amount to obstruct a much larger position, have outside incentives, or aim at disruption rather than direct extraction. Nor is the capital cost necessarily one micro-USDG per note: both USDG and LP payment routes exist, and payout rounding depends on state.
- **One note need not require one transaction.** A caller contract can make multiple deposit calls within one transaction's budget; do not assume one transaction's fixed overhead per appended note.
- **Gas estimates and N* are not established.** Three-slot conventional packing of the Note fields does not determine per-iteration gas. Distinct notes can require cold reads; already-claimed, unexpired and positively claimable notes execute different work. The complete atomic reinvestment also needs budget. “A few hundred warm gas” is not a safe estimate. No numerical threshold, attacker cost or failure probability was derived or measured.
- **Own-note bookkeeping is useful but narrower than claimed.** Recording returned indices and reading registered notes can avoid scanning unrelated notes for registered-position valuations. It does not prove *all* attribution/reconciliation bounded: redemption still mixes proceeds, and events provide post-hoc evidence rather than a completed on-chain allocation algorithm. Gifts are not automatically protocol revenue.
- A positive upstream minimum payout alone would not solve lifetime accumulation. Cadence, monitoring and headroom checks detect/shape exposure but guarantee no successful terminal claim. `pendingFor` is not operationally unlimited merely because an off-chain call has no transaction fee.

## Corrections to Grok and Astra

Grok accurately reports denied source reads; my direct checks supplement, not retroactively validate, its evidence. Its immediate “descope or accept OOG” checkpoint is premature before quantitative investigation. Potential positive-payment cost does not require a large bond purchase; zero-payout cases require evaluation.

**Astra correction:** my own original checkpoint also offered an overly early either/or between residual-risk analysis and requiring an upstream bound. Replace it with the investigation checkpoint below. My scoped conclusion remains: none of the evaluated wrapper mechanisms enforces an attack-independent upstream-work bound; this is not a theorem excluding every conceivable construction.

## Recommended next human checkpoint

**Approve further specification investigation—not risk acceptance or implementation—of per-position custody and registered-note bookkeeping, alongside a quantified native-scan threat model?** Require outputs before choosing any scope/risk change:

- authorized claim/custody flow and unsolicited-proceeds attribution preserving principal and selected atomic reinvestment;
- both payment markets, zero/positive payouts, precreation appends, claimed history and delayed final claims;
- a stated exposure horizon, transaction budget and parameterized gas model, with later authorized measurements explicitly pending;
- attacker payment/gas/throughput assumptions and failure containment, without presumed rationality or invented recovery endpoints.

Only after that evidence should the owner evaluate explicit residual-risk acceptance, an independently authorized upstream capability change, or deferral. No proposal currently closes NN-02.

**Limits:** high confidence in rechecked local facts; deployed equivalence, gas bounds and economic feasibility remain pending. Constants edits do not close NN-01. No shell/RPC/tests/code/configuration/delegation or external API claims; only this report written. Return to moderator and stop.
