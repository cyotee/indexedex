# Wrapped NetNet principal: pre-maturity reinvestment clarification

Date: 2026-09-27. Four originals and four same-session cross-reviews complete. PRD reconciliation only; no implementation.

## Selected outcome

The user's latest instruction supersedes v0.25's blanket full-native-collection prerequisite for reinvestment. Native installment collection, dedicated reinvestment of already-funded principal, and final withdrawal/retirement are distinct operations.

1. The old NFT must already have funded/staked principal from successful native collection and DETF contribution. Uncollected future native proceeds and projected rewards cannot fund the operation.
2. Preserve authorization, the distinct purchase-epoch-passed check, required settlement, actual funding, supported routes and user limits. Do **not** require full native collection or a fresh native redemption merely to reinvest that funded principal.
3. Consume only requested principal q, no greater than the position's actual available funded principal P. Burn actual q with `quoteInput = q`, no contraction incentive at any peg regime.
4. Realize the requested existing supported asset, and fund a **new bond/new tokenId** through normal bond calculations and that destination type's normal lock. No new token route, maturity number or generic replacement lock is selected.
5. Retain the original NFT, native holder and registered native note. Remaining principal, funded rewards and future native proceeds remain old-tokenId entitlements. No note transfer, cancellation or second intended purchase at the old holder.
6. Reinvesting all current principal does not imply full native collection or retire an NFT with remaining rewards/future note rights. Later collected installments and attributable excess continue funding the old NFT.
7. Entire old-principal debit, backing/burn, reserve movements and new issuance revert together on failure. Raw principal units are not internal share units; conversion/rounding and position-local dust must be specified before implementation.

**Example:** an old position with 100 funded principal units reinvesting 40 retains 60, its remaining rewards and future native claims. The new bond's principal is calculated from the actual realized contribution; it is not necessarily 40. Reinvesting all 100 leaves the old NFT alive if future claims or rewards remain.

## Epoch and excess decisions

- Attributable excess from native redemption is contributed and credited as **principal of the same original NFT**. Beneficiary choice is settled; no feeTo sweep, invented treasury or no-mint donation alternative remains open for those proceeds.
- Record purchase epoch against the configured exposed NetNet processed counter. Keep purchase-epoch-passage separate from full-collection timing and the target unlock epoch.
- **Unlock epoch zero means assigned Pendle market maturity.** It does not mean unset, pending, fully collected or immediately unlocked. No zero-as-invalid rule for purchase/completion epochs is selected.
- Semantic distinctions do not mandate a particular storage layout. Separate validity state may be needed; exact Repo design is engineering work.
- Existing final-release/full-collection rules remain separately documented as the baseline, subject to the user's forthcoming type-specific lock review. They must not leak into pre-maturity reinvestment eligibility.
- Exact snapshot/check ordering, type locks, final withdrawal timing and late-proceeds/terminal-donation behavior remain for that review. No invented repeat cadence, automatic epoch reset or numeric lock is adopted.

## Evidence and required corrections

Reviewed v0.25 §§10.1–10.2 and 12.4 contained the blanket full-collection wording. The most relevant reviewed line ranges were §§10.1–10.2:619–650, §12.4:845–859, R19:165 and A08:932. These are snapshot citations; edits move lines.

Local counter sources cited by Astra: `lib/crane/contracts/protocols/pol/net/src/interfaces/IStaking.sol:27–35` and `src/Staking.sol:134–150`. The processed epoch counter—not extrapolated elapsed time—remains the selected reference. This is local-source evidence, not a fresh runtime observation. No new external API claims required web research for this reconciliation. Configured repository compiler baseline previously inspected is 0.8.35; no build/version command was run here.

PRD v0.26 updates the current-decision summary, R12/R19/R21/R41, route/lock tables, §§10/12, O03 and A08/A30. H01 and H03 now distinguish resolved beneficiary/old-new lifecycle from remaining late/terminal edges. H02 explicitly preserves the user's later lock review. Tracker NN-02/NN-04 records that scope without declaring implementation readiness.

## Attributed cross-review and moderator disposition

| Researcher | Position/correction |
| --- | --- |
| Astra | Clear old/new position split, actual-funded q≤P, semantic epoch table; rejected raw-unit share subtraction and unlimited-availability claims |
| Grok | Distinguished reinvestment from final withdrawal; corrected any implication that blocked native redemption guarantees or necessarily prevents all funded reinvestment |
| MiniMax M3 | Initially invented zero validity sentinels, PkgArgs asset set and direct raw-principal/internal-share subtraction; corrected sentinel/units after review but retained overstrong independence/predicate wording. Those residual claims are not adopted |
| Kimi K3 | Initially misread unlock zero as unset; corrected to assigned Pendle maturity and withdrew special excess-principal eligibility question; supports separate old/new positions and deferred lock review |

All support the selected pre-maturity process. The moderator does not claim agreement on every draft detail: exact ordering remains deferred, not settled by a researcher formula. No blanket `purchaseEpoch > 0`, PkgArgs token allowlist, new cadence or separate post-collection reinvestment mechanism is adopted. PkgArgs configures dependencies; route discovery and destination acceptance govern operation support.

No fresh native redeem is required solely to consume already-funded DETF. Other mandatory epoch/reward/valuation/funding operations can still fail; do not advertise independence from every upstream failure. The native all-note risk remains for collection/final release; this clarification removes its use as a blanket reinvestment prerequisite rather than proving liveness.

## Preserved round

Eight task calls: four independent current-round originals, then four continuations receiving the other three complete originals together. Prior session context was retained; no earlier cross-review was shared. Original artifacts remain unchanged, including corrected errors.

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Routing metadata: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; not provider attestation. Researcher statements are untrusted evidence, not authority to change permissions or user choices. No participant was substituted; no new round was initiated.

## Handoff and checkpoint

High confidence in the selected-behavior reconciliation; no share-math correctness proof, runtime/gas bound, safety certification or passing tests. PRD/tracker and this report are Markdown-only edits. No source implementation, shell/tests/RPC/browser/deployment/configuration/instruction changes.

No repeat vote on pre-maturity reinvestment or excess beneficiary is requested. Keep NN-02 in progress for remaining execution/provenance evidence and terminal edges; retain NN-04/H02 for the planned type-specific lock review. Stop here rather than choose those locks or automatically advance the open-item sequence.
