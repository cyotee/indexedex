# Astra — v0.18 bounded cross-review

Read all three complete OTHER ORIGINAL reports together; no cross-review artifact read. Originals preserved. Research only: no shell, tests, delegation, code/config edits or deployment. This report is the sole write. No independent runtime model/provider attestation was exposed.

**References:** P = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md`; U = `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md`; ALIGN = `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md`. G/M/K = `docs/research/netnet-pendle-v018-readiness-{grok,minimax,kimi}-original.md`. Current P:1–83, ALIGN:1–30/D61/§24.7.2 and U:1–33,168–187 were rechecked directly. These are local snapshots, not deployed evidence.

## Verdict and agreements

**Retain Astra's original verdict: write a gated, specification-first plan now; do not freeze unresolved executable semantics.** All originals recognize that v0.18 controls, the body/companions are stale, family approval and one-hour arithmetic windows are settled, and conservation/native-note liveness remain engineering gates. They differ on when planning can begin and what requires owner policy. I do not adopt a requirement to close every policy detail before documenting the gated plan; P:59 explicitly calls the equation a working interpretation “for planning,” requiring confirmation before freezing (P:71).

Agreement does not certify security, solvency, gas feasibility or economic soundness.

## Corrections grounded in current text

1. **D9 is not current owner-only law.** K:43,67 proposes recording/reconfirming a D9 departure; M:104 repeats a D9 reconciliation. ALIGN:9 explicitly supersedes conflicting D1–D31 with D32–D66/§24. D61 at ALIGN:101 and §24.7.2:1167–1169 permit public owned/authorized LP joins/exits when unrestricted. No special D9 exception or fresh approval is needed. NetNet public shared HLP remains selected. “Encapsulation reconciles” is not the explanation; later law supersedes the old restriction.

2. **Universal is v0.5, not v0.2.** K:4–5,49 cites an obsolete version and its old line 111. Current U:7 says 0.5. Astra and MiniMax correctly identified its new cold-window policy and shared-staking changes. U:11,17–19 still misstates NetNet as compounded; that is stale cross-family text, not authority to undo P:55. U:178 explicitly consumes cold-start epochs without later payment; U:25,31,184 adds fee-share economics. None becomes NetNet policy by shared naming. P:20,39 protects the family boundary. The old “coefficient still unspecified” claim is not a current U defect.

3. **Family approval is real; council execution remains prohibited.** M:5 says no implementation was authorized, citing P:9, which says the opposite about the family. Distinguish approval of the family from this research task's restrictions (P:9,14,24). No extra scope approval is needed for the selected custom family or interface specification. Existing-hook retrofits remain separate (P:35).

4. **Do not reopen caps or unrelated reward destinations.** M:98 offers capped and flat-0.5% alternatives, while P:57,71,73 excludes silently adding those. M:78 wrongly suggests cap-removal emphasis was removed. M:100's forward/split choices for the retained token would revise the selected exception, not simply implement classification. P:45,49 requires preserving the exception and separately defining permissible use of same-token incentives.

## Economic and entitlement questions

**Catch-up cadence — retain Astra's finding.** P:66 proposes `floor(S0*n/200)`. With 1,000 DETF and unchanged eligibility, batching two epochs yields 10 DETF; settling individually yields 5 then 5.025. These amounts are representable with nine decimals. Thus batch-local noncompounding coexists with compounding across actual settlements. This is arithmetic inference, not proof of exploitable profit. Formula confirmation should explicitly include this consequence; no original peer analysis refutes it.

**Unavailable history is not merely a storage decision.** I disagree with K:69's unconditional engineering-only classification and G:104's suggestion that only the equation can require owner freeze. P:39 says skipping while allowing claims was not selected. Consuming the marker permanently forfeits catch-up; preserving it while allowing participation changes may award old epochs to new holders; reverting may block funded exits or observation recovery. Engineering must first produce an operation/marker/ownership table. If alternatives change entitlement or availability, the owner selects among them. No silent adoption of U:178.

**Synthetic consumers — narrow my original owner queue.** G/K correctly treat consumer inventory as engineering. M:102,116's request to confirm an empty set “today” asks the owner to establish a code fact. Engineers should inventory consumers and retain existing instantaneous gates/finite-size quotes unless changed (P:41). Ask the owner only about a proposed switch with economic consequences—not about whether the new view may simply be exposed.

**Retained-token incentives — distinguish provenance from policy.** K:25's “not-interest” is a correct accounting label, not a complete allocation/use policy. P:49 forbids calling incentives accrued YT interest and also forbids automatically forwarding them despite the token exception. Engineering verifies reward lists and segregates provenance. Escalation is necessary only if supported markets present the collision and the proposed treatment changes LP/fee entitlement or the interest-only spending rule. Canonical-address discovery is verification, not automatically an owner question (M:101).

## Minimal human checkpoint and remaining dissent

1. **Confirm the proposed single-catch-up equation with batch-cadence consequences.** Rate/window/gate and no-cap/no-replay selections remain intact.
2. **Approve the unavailable-history operation/marker policy after engineering analysis.** Distinguish valid zero expansion from unavailable history and preserve explicit entitlement reasoning.
3. **Conditional escalations only:** a proposed synthetic-TWAP replacement of an economic gate; retained-token incentive use if it occurs and cannot be resolved within selected rights; any demonstrated feasibility conflict requiring changed scope.

Observation structures, selectors, address/reward discovery, bounded arithmetic, singleton proof, callback sequencing, zero-interest bootstrap, V2 parity and native-note liveness are engineering deliverables—not additional approvals. Reconcile operative R/O/A text and companions before freezing acceptance tests. Keep my original whole-call liveness and externally changing valuation concerns: eliminating epoch replay does not solve dependency loops or prove faithful price history.

I narrow my earlier four-question owner list by making synthetic-consumer and reward-collision escalation conditional. I retain disagreement with blanket “engineering-only” treatment of entitlement-changing oracle failure policy. High confidence in textual/arithmetic corrections; no live-chain or executed feasibility evidence. Return to moderator and stop after this single continuation.
