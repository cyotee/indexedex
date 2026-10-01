# Kimi K3 — ORIGINAL: NN-02 external NetNet note custody/claim liveness

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only, not provider attestation |
| Date | 2026-09-27 |
| Scope | NN-02 only. Research only: no RPC/shell/tests/code/config, no delegation, no peer outputs this round. Constants edit by the implementation agent is observed as reported; it does not close NN-01 live checks and changes nothing below. |
| Sources | `BondDepository.sol` (full 200 lines, this session), `IBondDepository.sol` (full 55 lines, this round), `Constants.sol` (full, prior), PRD §§12/14 C08, tracker NN-02 (lines 45, 74–78). No external lookups needed — local code analysis only. |

## 1. NN-02 in plain English

NetNet's bond contract lets users buy "notes" that pay out NET over a vesting period. Our design wants a wrapper NFT whose contract holds such notes, harvests the vested NET, and must always be able to do so. The problem: **the note list is a public scratchpad.** Anyone can add notes to *any* address, the list only ever grows, and the only way to collect money is a function that walks the *entire* list. So a stranger can bloat our wrapper's list, making every future collection more expensive — potentially so expensive the transaction no longer fits in a block, stranding unclaimed value. NN-02 asks: can our wrapper design, *without changing NetNet's contract*, either genuinely bound that work or prove the risk is quantifiable and acceptable — or must the feature go back to the owner?

## 2. Structural facts (source-grounded, `lib/crane/contracts/protocols/pol/net/src/`)

1. **Arbitrary-recipient appends:** `deposit(marketId, amount, maxPriceWad, to)` pushes `notes[to]` (`BondDepository.sol:104–140`); `to` is unconstrained, no callback, no opt-out.
2. **All-note scan, no pruning:** `redeem(to)` loops every note of `msg.sender` (:143–153). Fully claimed and zero-payout notes remain in the array forever; only `claimed` is updated.
3. **`pendingFor` also scans all notes** (:156–166) — free as an off-chain `eth_call`, unusable on-chain at scale.
4. **No alternative claim path:** no per-note redeem, no range/batch redeem, no note transfer, no minimum payout (only `amount != 0`, :109; `payout = mulDiv(valueWad, NET_UNIT, price)` :126 can round to ~0). `_checkEpochCap` (:183–189) caps payout *value* per epoch (25 bps of supply, `Constants.sol:79`) — never note *count*.
5. **Attribution data exists without scanning:** `mapping(address => Note[]) public notes` (:54) generates a per-note `notes(address,uint256)` getter; `noteCount` exists (:168–170); `deposit` **returns the new index** (`noteId = notes[to].length`, :130); and every claim emits per-note `BondRedeemed(depositor, noteId, payout)` (`IBondDepository.sol:18`).
6. **Vesting discrepancy confirmed at the exact source:** interface NatSpec says "5-day linear vesting (DEFAULT — TUNE BEFORE DEPLOY)" (`IBondDepository.sol:5`) vs `Constants.sol:76` `BOND_VEST = 2 days` — the PRD §12.1 2d/5d gap is code-vs-prose, deployed value still pending NN-01.

## 3. The decisive reframe: donation economics vs dust grief

A note with payout > 0 is **real NET gifted to the holder**: the payer's principal goes to the treasury (:116/:121) and the payout is minted for the note (:129). Spamming a wrapper with nonzero notes is economically irrational — it donates value. The genuine residual attack is **zero/dust-payout notes**: each costs the attacker ~1 unit of quote token (1 micro-USDG) plus one L2 transaction, and adds a roughly constant per-iteration cost (a few hundred warm gas; `Note` spans 3 slots, :35–40) to *every future* `redeem` by that holder — including the unavoidable final one. So:

- **Absolute non-boundedness is structural and real:** nothing stops array growth; there is no wrapper-side reject.
- **But the failure is quantified economic feasibility, not mathematical impossibility:** there is a finite note count N* at which `redeem` exceeds the Orbit per-transaction gas limit — analytically estimable now, measurable later (NN-18). The failure mode is *stranded unclaimed value if N crosses N* before the final claim*, never theft, and pushing N toward N* costs the attacker roughly N L2 transactions — vastly more than the victim pays per claim.

## 4. Can any wrapper-only design bound the work? (evaluated, not selected)

| Option | Bounds attribution? | Bounds `redeem` gas? | Verdict |
| --- | --- | --- | --- |
| Per-position escrow contracts | Isolates per position; multiplies attacker cost per target | No — each escrow's array still grows | Necessary hygiene, insufficient alone (PRD §12.3 already says this) |
| Precomputed (CREATE3) escrow addresses | Neutral | Worse — publicly derivable, enables *pre*-griefing before first use | Use anyway (deploy path), but do not count on secrecy |
| **Purchase-time index recording** (store `noteId` returned by `deposit`; read own notes via public getter) | **Yes — O(own purchases)** | No | **Fully wrapper-side win:** valuation/reconciliation never scans the array |
| Event-based reconciliation (`BondRedeemed` per-note) | Yes, off-chain/post-hoc | No | Complements index recording |
| Amortized / cadence-controlled claims | Reduces *number* of O(N) scans | No — terminal redeem still O(N) | Cost-shaping only |
| Voluntary-gift (donation) treatment of unsolicited notes | Yes — resolves provenance question | No | Correct accounting stance; attacker principal becomes revenue |
| Local cap "wrapper refuses beyond K notes" | — | No — cannot refuse upstream appends; only detects | Rejected as a bound (PRD forbids label-as-solution); useful only as a **monitoring threshold** |
| Minimum payout / batch or per-note redeem | — | Would solve | **Upstream change; unavailable. Do not assume.** |
| Monitored headroom vs analytic+measured N* | — | Detects approach to ceiling | Risk management, not a bound |

**Bottom line:** a wrapper-only design *can* bound all wrapper-side work — attribution, valuation, expected-claim accounting — to O(own purchases). It *cannot* bound the upstream `redeem` scan. What it can add is a **quantified feasibility envelope**: attacker-cost model (≥1 tx + ≥1 quote unit per note, nonzero notes self-defeating), analytic N* with later measured confirmation (NN-18/NN-19), `noteCount` monitoring at every claim, early/periodic claims so value is extracted while N ≪ N*, and a pre-claim headroom check before the terminal redeem.

## 5. Conditional resolution proposals (not owner decisions)

- **Proposal A — wrapper-only with quantified envelope.** Per-position escrow via the registry/CREATE3 path; purchase-time index recording; donation treatment of unsolicited value; monitoring against documented N*; claim cadence rules; pre-terminal headroom check. Residual risk, stated honestly: a financed attacker can strand a position's unclaimed value by pushing N past N* faster than the cadence extracts it — probability/severity bounded by attacker budget vs. L2 gas economics. Closure requires the analytic model + later gas evidence + **owner acceptance of that residual**.
- **Proposal B — scope change.** Defer or descope the external-bond wrapper (e.g., owner-accepted limit on positions/payout policy acknowledging dust-grief residual) if the residual is unacceptable.
- **Proposal C — upstream.** NetNet adds per-note/range redeem or minimum payout. Unavailable today; must not be assumed.

PRD C08/NN-02's own rule governs: A is a legitimate closure candidate *only because* it quantifies rather than hand-waves; if the owner rejects the residual, the feature returns as B.

## 6. Narrow human checkpoint

One question: **"Is Proposal A — the wrapper-only design whose attribution work is bounded but whose upstream claim cost is attacker-influenced, mitigated by monitoring, claim cadence and a measured gas ceiling, with the residual stranding risk documented — acceptable as the NN-02 closure basis, or should the external-bond feature be deferred/descoped?"** No addresses, economics, or other NN items decided.

## 7. Optional UNAPPROVED PRD clause (additive, for §12.3)

> **Quantified liveness envelope (UNAPPROVED).** The upstream note array is append-only for arbitrary recipients; `redeem` scans all of the holder's notes, and no per-note, batch, minimum-payout or pruning mechanism exists in the inspected source (`BondDepository.sol:54,104–153,183–189`). The wrapper bounds its own attribution and valuation work to O(own purchases) via purchase-time note-index recording and the public per-note getter; it treats unsolicited note value as donations with provenance. The upstream scan itself is unbounded by design; the wrapper therefore operates under a quantified envelope: an analytically derived and later measured maximum redeemable note count N*, `noteCount` monitoring at every claim, a claim cadence that extracts value while N ≪ N*, and a headroom check before each terminal claim. Nonzero-payout spam is economically self-defeating (it donates NET). The residual risk — a financed attacker stranding unclaimed value by exhausting N* — is documented and accepted by the owner as the basis of this feature, or the feature is deferred; no hypothetical upstream selector is assumed.

## 8. Limits

All code facts read directly this session from the local tree; source/deployed equivalence on chain 4663 remains pending NN-01 (the reported constants edit does not discharge it). No gas measurement performed — N* is framed analytically; measurement is NN-18/NN-19 work. No mathematical-impossibility claim is made beyond the structural facts; no recovery API is invented. External-bond economics, NFT lifecycle (NN-15) and purchase composition remain other items.
