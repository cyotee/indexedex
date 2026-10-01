# Astra — bounded cross-review

2026-09-25. Read the complete Grok, MiniMax M3 and Kimi K3 ORIGINAL reports together; no cross-review artifacts read. Originals remain unchanged. No shell, tests, code/config changes, delegation or deployment. No independent runtime model/provider attestation was exposed; Astra remains the assigned label.

References: **P** = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.17; **M** = sibling `NETNET_PENDLE_OPERATION_MATRIX.md`. **G/M3/K** = `docs/research/netnet-pendle-readiness-2026-09-25-{grok,minimax,kimi}-original.md`, respectively. Line numbers are local snapshots, not immutable pins.

## Readiness and agreements

**I retain Astra's original verdict: sufficient direction for a separately authorized gated planning document, insufficient evidence for a frozen executable plan.** Grok rejects “implementation-plan ready” (G:13,116); MiniMax conditions planning on authority, singleton and oracle closure (M3:165). That is partly terminology, but real dissent remains if they prohibit documenting unresolved gates in a plan. A plan may specify deliverables and stop conditions without inventing product choices. P:883 expressly assigns remaining specification to separately authorized planning; P:657 withholds approval of an executable plan until material gates close. Neither authorizes implementation.

All three originals support preserving the expansion/custody selections, correcting matrix lag, and treating shared-book conservation and native-note liveness as engineering obligations. That agreement is evidence of overlapping review findings, not proof of safety or a resolved council consensus.

## Attributed corrections

1. **Reject MiniMax's owner-only hook mandate.** M3:115 prescribes `ownerOnlyLiquidity` on and MultiStepOwnable. P:102,165–173 expressly selects public shared HLP and introduces no runtime administration. Even current Universal alignment distinguishes public and restricted modes (`contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1165–1171`); DETF hook ownership does not imply restricted LP access. The custom package must implement authorization over actual shares, not import an owner-only product policy. Nor do reference I/O tables become mandatory custom-family scope merely by reuse (M3:113,136).

2. **Reject Kimi's implied deterministic price-decay question.** K:28,51 infers prolonged above-peg trading and asks to confirm a long decay with always-on expansion. P:399 explicitly says staking-only minting does not add tokens to the reserve or rewrite TWAP history. Trading TWAP and owned-reserve synthetic price are different quantities; opening price alone proves neither their future path nor that contraction stays unavailable. Conditional expansion funding is already selected (P:375–393). Retain dilution/market-response analysis, drop the owner reconfirmation. My original warning about this distinction stands.

3. **Correct MiniMax's fixed funding waterfall.** M3:72 converts possible steps into an ordered sequence. P:309 explicitly says the waterfall “is not fixed.” Income claims, SE unbuffering, HLP redemption and conversions are candidate realization steps subject to ownership, funding and callback constraints. The plan must derive their ordering; the report supplies no selected waterfall or conservation proof.

4. **Drop Grok's empty-target reconfirmation.** G:94 asks revert-only versus later seed. P:577 already requires atomic revert when the chosen entry cannot execute and leaves a separately approved seed path outside current selection. K:37 and M3:94 correctly recognize the existing handling. Implementation must validate that behavior; a new seed design requires new scope, not a readiness question.

5. **Drop additional-eligibility reconfirmations.** G:96 and K:55 ask about extra contraction conditions. P:338–340 requires the selected price branch plus valid execution and explicitly forbids invented policy. There is no need to confirm “none.” New controls require concrete research and an explicit proposal. Likewise K:53's request to approve cap-free O(log n) arithmetic is engineering, not an owner/legal question (P:389). Exact rounding equivalence still needs proof.

6. **Narrow Grok's contraction-price question.** G:92 offers a different mark as an owner alternative. P:124,313,399,407 already specifies post-expansion supply and owned-reserve synthetic pricing. The precise NET-rated construction remains unresolved; engineers should specify that selected model before escalating a concrete incompatibility, not reopen TWAP versus synthetic by default.

7. **Correct MiniMax's owner/engineering classification.** M3:42–56 both labels almost every O-item human input and calls TWAP window/failure semantics freely planning-deferrable. Repo layout, singleton proof, binding query, custody design and arithmetic are engineering tasks. Window approval and unavailable-oracle behavior have explicit parameter/product consequences (P:397–411). A proposed self-leg component “S” is not selected (M3:131); P:159 leaves representation to engineering and distinguishes owned HLP from reserve self-leg DETF. Token-policy tension is an acknowledged authority gate, not an internal logical contradiction (M3:24); exemption is not required (P:353,359).

## Changes and limits to Astra's position

Peer findings strengthen the need for a shorter owner queue. I now explicitly classify empty-target rejection and absence of unselected eligibility controls as settled baseline behavior. My original report did not demand their reconfirmation; this sharpens, rather than replaces, it. No peer evidence disproves my original oracle-outage/funded-exit dependency concern, zero-share initialization risk, near/after-maturity duration cases or permissionless-rollover protection concern.

Grok/Kimi's spot checks are corroboration, not deployed equivalence. My first-pass source observation remains: `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–153` allows arbitrary note recipients and aggregate redemption. No original demonstrates bounded adversarial note growth. MiniMax's proposed external-bond deferral (M3:133) would change selected scope; escalate demonstrated incompatibility, do not silently remove the feature.

## Final prioritized decision checkpoint

1. **Authority:** obtain scoped custom-family supersession before implementation; a gated plan must identify—not assume—this approval.
2. **Owner parameters after engineering proposals:** TWAP window/history/invalid-data behavior, especially effects on funded exits and observation recovery; weights and collective rollover execution protections; unresolved non-PENDLE destinations/compensation if applicable.
3. **Engineering stop/go gates:** shared custody/pricing/funding ledger; zero-interest first bond; zero-share staking; duration compatibility, including already-mature contributions; native-note liveness; exact-output and full V2 parity; dependency/singleton verification.
4. **Planning deliverables:** synchronize M to v0.17; specify arithmetic, authority/callback graph, view/selector mapping, deployment pins and A01–A45 evidence with quantitative pass criteria. Preserve my original finding of stale NetNet language in the Universal companion at line 111.

No new rate, price-decay target, owner-only HLP policy, seed route, funding waterfall, certification prerequisite or extra contraction gate is needed. Confidence is high on these textual corrections; technical feasibility and economic soundness remain unproven. Return to moderator and stop after this single cross-review.
