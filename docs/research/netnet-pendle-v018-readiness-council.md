# NetNet–Pendle v0.18: consolidated council readiness review

Research-only review of the current 950-line PRD. Eight calls completed: four independent passes in the preserved sessions, followed by four same-session combined cross-reviews. Each cross-review read the other three complete original reports, never earlier cross-reviews. Originals remain unchanged. No PRD, code, instruction or configuration edits; no shell, tests, deployment or transactions.

## Verdict

**Ready to draft a gated, specification-first implementation plan; not ready to freeze an executable specification.** Owner approval, one-hour arithmetic windows, the two price series, existing-hook retrofit boundary, generalized fee routing and removal of missed-epoch compounding are settled. Do not ask the owner to approve them again.

The strongest immediate defects are contradictory operative requirements beneath the v0.18 precedence banner and an explicitly unconfirmed catch-up equation. Engineering feasibility is a separate issue from approval.

## Evidence notation and scope

- P: `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md`, v0.18.
- M/Q: sibling `NETNET_PENDLE_OPERATION_MATRIX.md` and `REQUIREMENTS_QUESTIONS.md`.
- U: `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md`, currently **v0.5**, not v0.2.
- A: `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md`.

The moderator re-read CLAUDE, P's current amendment and acceptance/open-item tables, U's current version and decisions, and A's current decisions. Full PRD, additional canonical skills, family documents and source inspection are recorded in the individual reports; prior directly read guidance remains context. Citations are local line snapshots, not immutable revision pins. Researcher-reported access date is 2026-09-25; the supplied moderator environment date is 2026-09-26. Neither is a chain observation timestamp.

## 1. Quality and clarity

The amendment is appropriately explicit about owner decisions versus assistant interpretations (P:18–83). Custody, token entitlements, atomic failure and acceptance coverage remain strengths. However, it is an amendment layered above stale instructions rather than a reconciled specification.

| Required cleanup | Evidence |
| --- | --- |
| Replace retired compounded expansion in operative requirements and examples | P:189,440–460,580,715 |
| Replace A40, which still requires compounding and forbids linear catch-up | P:769 versus P:55–79 |
| Incorporate both one-hour series into R53, oracle section and A44 | P:190,464,773 versus P:26–41 |
| Generalize reward requirements, harvest section and A11 | P:150,167,699,718,740 versus P:43–51 |
| Close obsolete O01 approval request, retaining dependency verification | P:711 versus P:24 |
| Synchronize matrix/question tracker | M:3,49,54,85,88,104; Q:7,28 |
| Correct Universal document's stale claims about NetNet compounding | U:11,17–19; do not change Universal policy by implication |

P:20 resolves precedence, so these are not competing owner choices. Nevertheless, the wrong tests could be generated from the retired A40. Reconcile operative R/O/A rows and separate historical narratives before freezing the plan. This review does not perform that edit.

## 2. Immediate human checkpoint: catch-up equation

P:59–71 labels `pendingMint = floor(S0*n/200)` a working interpretation and explicitly asks for confirmation before freezing. It applies 0.5% per missed processed NET epoch to the supply at the start of this settlement, under the retained valid hook-TWAP >1 gate.

**Question:** Is that batch-local linear formula intended, including its settlement-frequency consequence?

With nine-decimal DETF and unchanged price eligibility, no other issuance/burns:

| Schedule | Minted amounts | Total expansion |
| --- | --- | --- |
| Two epochs settled together, starting at 1,000 DETF | `floor(1,000e9 * 2 / 200) = 10e9` raw units | **10 DETF** |
| Each epoch settled separately | `5e9`, then `floor(1,005e9 / 200) = 5.025e9` raw units | **10.025 DETF** |

This is exact at nine decimals, not merely a real-valued approximation. Batch-local noncompounding still compounds across actual settlements because each later settlement starts from a larger minted supply. It is an economic consequence, not proof of an exploit or profit.

**Moderator correction:** MiniMax's cross-review incorrectly floors 5.025 whole DETF to 5 and claims cadence invariance. Kimi's cross-review repeats that whole-token-floor mistake while retaining the cadence concern. A:73 specifies nine decimals; floors apply to raw units. Astra/Grok's 10-versus-10.025 result is correct. Preserve the erroneous reports as attributed evidence, not adopted requirements.

Do not silently introduce a fixed lifetime supply base, flat one-time 0.5%, cap or restored compounding as a fix. Removing epoch replay does not prove absence of overflow or dependency-related blocking (P:73).

## 3. Oracle availability: engineering proposal, then policy decision

Window and arithmetic method are settled. P:39 leaves unavailable-history behavior open, and P:472–478 otherwise requires settlement before participation changes.

Engineering should first supply an operation table covering first-hour initialization, invalid valuation, rollover, and relevant failure cases, with marker and ownership consequences:

- **Revert:** can block funded withdrawals/claims or observation recovery.
- **Defer without consuming epochs:** must prevent new participants capturing old entitlement and preserve settlement accounting.
- **Consume with zero expansion:** permanently removes catch-up for those epochs.

These are not interchangeable implementation details. Owner approval is needed where the selected outcome changes availability or entitlement; no need to demand a choice without an engineered proposal. A gated plan may carry the decision as an explicit stop condition. Do not import U:178's Universal cold-window policy into NetNet.

Also specify price definitions, non-swap update points, cumulative units, history availability, same-block behavior, boundary retrieval and callback-safe consultation. No-trade time can extend the last valid price, but external rebases/rates/claims may change the underlying valuation; a synthetic series cannot be called accurate solely because the hook observes swaps.

## 4. Conditional clarifications, not a new broad questionnaire

### Synthetic TWAP consumers

P:41 retains the hook TWAP expansion gate and does not designate replacement consumers for the synthetic average. Engineering should inventory each gate/view and retain instantaneous baselines unless explicitly changed. If a named economic gate is proposed to switch to the synthetic average, obtain the corresponding product decision. Exposing a TWAP does not replace finite-size execution quotations.

### Retained-token incentive receipts

P:45 settles the designated yield-token exception and forwarding of other attributable rewards. Do not reopen those destinations. Engineering must bind actual token identities and verify whether a supported market can emit the retained token as an incentive as well as deliver yield/interest.

If so, specify accounting and permitted use without silently calling incentives accrued YT interest or forwarding them despite the selected token exception (P:49). Escalate only if the treatment changes entitlements or the interest-only trading rule. No live market exhibiting this collision was verified in this round. Token-address discovery itself is not an owner preference question.

## 5. Engineering gates for the plan

These remain significant but should not be handed to the owner as algorithm-design questions:

- One physical custody, claim, fee and pricing ledger for the direct-custody Weighted hook, including owned-reserve burn quotation and exact-output funding.
- Bounded native-note collection despite arbitrary recipient deposits and aggregate upstream redemption; per-position escrow is not alone a proof (P:687–691).
- Zero-interest/full-book bootstrap and pre-activation public liquidity behavior.
- Zero-share staking, existing balances, dust, final withdrawals and separate bond-reward allocation.
- Reference bond minimum-duration compatibility with next-epoch and already-mature contributions.
- Full custom V2 feature parity, permissionless rollover protections and child/callback authority.
- Dependency pins, actual market configuration, SE binding and singleton enforcement.
- Whole-operation gas/availability, not just expansion arithmetic. Astra inspected `lib/crane/contracts/protocols/pol/net/src/Staking.sol:134–150` (one processed epoch per invocation) and `BondDepository.sol:104–165` (arbitrary note recipient and aggregate scan). No execution or deployed-equivalence proof was obtained.

## 6. Cross-family and reviewer corrections

**D61, not an extra approval:** A:9 supersedes conflicting D1–D31 and A:101 explicitly allows public owned/authorized LP operations with unrestricted configuration. Kimi withdrew its initial D9 exception question. MiniMax's continuing encapsulation prescription is not adopted as a demonstrated implementation design. No extra public-HLP approval is needed.

**Universal is v0.5:** moderator verified U:7. Kimi corrected its initial v0.2 references during cross-review. U's new fee/creator internal-share and zero-share rules (U:25,31), cold-window behavior and synthetic-TWAP expansion input are not automatically NetNet requirements. Plan shared-component reuse without silently importing conflicting policy.

| Researcher | Initial position | Cross-review disposition |
| --- | --- | --- |
| Astra | Gated planning possible now; four narrow question areas; highlighted cadence and shared-source drift | Reduced consumer/reward questions to conditional escalation; retained oracle entitlement concern |
| Grok | Gated planning; equation is immediate owner question | Adopted cadence and U v0.5 boundaries; other policy choices follow engineering proposals |
| MiniMax M3 | Three owner blockers before readiness; engineering gates remain | Retained earlier decision timing; corrected U version but introduced erroneous whole-token cadence rounding |
| Kimi K3 | Equation first; most other work engineering; optional D9 question | Withdrew D9 question, corrected U version, adopted engineering-first policy escalation; partial arithmetic wording remains wrong |

**Unresolved dissent:** when to ask for oracle/reward policy—now as blockers, or after engineers present concrete cases. Moderator recommendation is the latter. This does not permit implementing arbitrary defaults. All support gated versus frozen readiness, but there is no unanimity on every finding or sequencing condition.

## 7. Evidence limits and confidence

High confidence in current-document contradictions, selected choices, nine-decimal cadence arithmetic and D61 precedence. Moderate confidence in completeness of integration risks. No claim of deployed equivalence, gas feasibility, solvency, security or peg effectiveness.

Sources are unpinned local snapshots. Earlier source registers identify DETF/Weighted wrapper pragmas `^0.8.0`, vendored Balancer V3 math `^0.8.24`, and Pendle source `^0.8.17`; these are not verified running compiler/deployment versions. Grok reports Context7 retrieval for Uniswap `/uniswap/docs` and Pendle `/websites/pendle_finance` on 2026-09-25. No exact fresh primary-source URL was supplied in its result; this consolidation does not promote that retrieval to independent deployed/API verification. Its external-doc observations are not needed to establish the PRD findings.

Runtime: same-session continuations succeeded with the four named researcher targets. This round's continuation metadata exposed session/subagent identities but not independently attested provider IDs; prior task metadata reported the prescribed models. Kimi reports high variant. No participant failure occurred. MiniMax reported using its available document-writing tool. Prior peer context persists in resumed sessions; independence means no new-round peer artifacts were read before all originals were collected.

## 8. Preserved artifacts and sessions

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](netnet-pendle-v018-readiness-astra-original.md) | [Cross-review](netnet-pendle-v018-readiness-astra-cross-review.md) | `ses_f25fade8cffeMRUhowWuAOImOG` |
| Grok | [Original](netnet-pendle-v018-readiness-grok-original.md) | [Cross-review](netnet-pendle-v018-readiness-grok-cross-review.md) | `ses_f25f63f70ffe9CGLHPAkwydF3V` |
| MiniMax M3 | [Original](netnet-pendle-v018-readiness-minimax-original.md) | [Cross-review](netnet-pendle-v018-readiness-minimax-cross-review.md) | `ses_f25f3b310ffeMer1lyRloa9O4M` |
| Kimi K3 | [Original](netnet-pendle-v018-readiness-kimi-original.md) | [Cross-review](netnet-pendle-v018-readiness-kimi-cross-review.md) | `ses_f25ef8556ffejQT9yEGeMtcgdV` |

## 9. Human checkpoint and implementation handoff

Confirm the proposed catch-up equation with its cadence consequence. Then authorize document reconciliation and/or a gated plan: replace retired operative requirements, synchronize companions without changing Universal decisions, specify engineering deliverables and return consequential policy choices for approval. The plan should map current requirements to measurable acceptance evidence and stop on failed feasibility gates.

This review changes neither the PRD nor implementation. Family approval remains recorded; research-only council permissions remain unchanged. Stop for the human response.
