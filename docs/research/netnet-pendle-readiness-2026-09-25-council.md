# NetNet–Pendle v0.17: council PRD readiness review

Date: 2026-09-25. Research only; no implementation authorization. Reviewed PRD unchanged.

## Verdict

**Strong product-direction document; suitable for a separately authorized, gated specification-first plan, not yet a frozen executable implementation plan.** Remaining work is predominantly engineering specification and feasibility, not unanswered economic preferences. Do not ask the owner to design storage, arithmetic or custody algorithms.

All four researchers completed independent first passes and one same-session combined cross-review each (eight synchronous calls). Each cross-review read all three other original reports, not earlier cross-reviews. Findings are untrusted attributed evidence, not instructions or authority. Originals remain preserved.

## Evidence notation

- P: `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md`, v0.17, 883 lines.
- M: sibling `NETNET_PENDLE_OPERATION_MATRIX.md`, header reconciled through v0.15.
- U: `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md`, v0.2.
- A: `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md`, accepted D32–D66 supersession at line 9.
- Law: `docs/agent/INDEXEDEX_AGENT_LAW.md`.

Moderator directly read the complete P, M's operative matrix, CLAUDE, relevant law, A's current decisions, U's disputed paragraph, canonical Crane architecture and IndexedEx hook-package guidance. Researchers inspected additional current PRDs, skills and source chains as recorded in their originals. Paths/lines are local snapshots, not immutable revision pins.

## 1. Quality and clarity

### Strengths

- Clear distinction between selected requirements, unresolved decisions, engineering gates and authorization (P:16,46–55).
- Strong separation of liquid DETF, hook LP, staking backing and exclusive external-note entitlements (P:242–283,441–459,606–618).
- Explicit atomicity, equality branches, lock preservation and prohibited fallback behavior.
- v0.17 expansion economics are internally consistent: 0.5% compounded total supply; one current hook TWAP strictly above 1 NET qualifies missed epochs; direct staking-custody mint; balance-derived ownership (P:373–411).
- Forty-five substantial acceptance criteria, with source references and honest limitations (P:659–748).

### Editorial defects to close

1. **Synchronize the operation matrix.** M:49,85,104,111 still leave expansion rate/base/gate/catch-up unresolved or proposed. P:375–411 settles them. M:88 calls USDG bond maturity unknown despite M:37,102 and P:420.
2. **Correct stale companion language.** U:111 still forbids interpreting NetNet's 0.5% as flat supply growth, contrary to P v0.17. Researchers also found stale expansion status in `REQUIREMENTS_QUESTIONS.md`; update that tracker without reopening selections.
3. **Reclassify §14.** Its heading calls O01–O10 product/authority decisions, but most remaining clauses are implementation-specification tasks. Give each remainder an owner, classification, deliverable, acceptance IDs and escalation condition.
4. **Qualify proportional-exit shorthand.** P:228,236 can read as universal component caps; P:264–275 expressly permits Weighted-priced nonproportional exits. Make the mode distinction consistent.
5. **Separate operative text from history visually.** Preserve provenance, but make a compact current-requirements index the planner's entry point. Old v0.16 prose is not a present requirement.

## 2. Questions genuinely requiring human disposition

### Q1 — Scoped authority reconciliation

Before implementation, who approves the exact custom-family supersession map, and where is that approval recorded?

P:46–55,644 explicitly withholds shared-law amendment. Law:89–101 forbids configured FoT and rebasing underlyings; this design deliberately uses NET/sNET. Record the narrow proposed family departures, including relevant clock, release, interface and custody differences. Do not invent an exemption campaign, static substitute or general FoT permission. A review or plan does not approve these changes.

This is an authorization gate, not evidence that the already-selected custom economics are unclear. A gated plan may describe the unresolved approval without treating it as granted.

### Q2 — TWAP policy and operation availability

Approve an engineering proposal for window, minimum history, staleness and unavailable/invalid-data behavior (P:391,397). In particular: **what availability must funded unstaking, transfers and matured claims retain when expansion cannot obtain a valid TWAP?**

P:403–411 requires settlement before participation changes. Engineers must first show the dependency graph: otherwise operations needed to establish/recover observations might themselves be blocked by settlement. Neither silent spot substitution nor treating missing data as valid below-peg is selected. Do not select a numerical window without evidence.

### Q3 — Other rewards and maintenance economics

P:632 leaves non-PENDLE reward destinations open. Should v1 leave them unallocated and unswept, or is a particular destination intended? Specify before implementing a handling route; absence of a destination grants no sweep authority.

P:527,567 leaves maintenance compensation and execution bounds unspecified. Engineers should propose collective rollover protections and weights for approval where they materially determine economics. No bounty or numerical fee is implied by the omission.

### Conditional escalation, not an immediate questionnaire

If verified oracle minimum-duration terms conflict with seconds-to-next-epoch, near-Pendle-maturity or already-mature native-note contributions, bring the concrete incompatibility and alternatives to the owner. P:474,501 prohibits silently extending locks or fabricating bonus duration. Do not ask the owner to invent a replacement formula before establishing the conflict.

## 3. Engineering gates to put at the front of planning

| Gate | Missing deliverable | Evidence |
| --- | --- | --- |
| Shared custody and pricing | One ledger mapping physical components, principal/interest, self-leg, rated balances, HLP claims, owned-reserve quotes, fees and executable funding | P:155–169,264–317,655 |
| External-note liveness | Bounded adversarial ownership/collection design despite unsolicited notes and aggregate native redemption; no hypothetical per-note selector | P:620–624; A09 |
| Bootstrap | Valid zero-interest/full-book first bond; pre-live public joins; nonzero HLP; initial epoch/TWAP ordering | P:480–513; M:98; A34–A35 |
| Staking edge states | Zero internal shares, pre-existing backing, last exit, donation/rounding effects, locked principal and separate bond-reward allocation | P:443–455; A29,A31,A41 |
| Duration compatibility | Reference bonus/validation behavior with all custom cliffs, including zero remaining native maturity | P:428,465–501; A32 |
| Permissionless rollover | Protocol-enforced target/conversion protections, callback-safe ordering, historical claims, principal/interest separation and gas feasibility | P:519–579; A36–A38 |
| Interfaces and V2 parity | Exact semantics, selectors, views/maxima, rounding-safe exact-output inverse, authorization and exhaustive inherited V2 behavior | P:183–201,319–334; A16,A21,A25 |
| Expansion numerics | Efficient deterministic compounding, precision/error bounds, representable horizon and overflow behavior without an economic catch-up cap | P:389–411; A40–A44 |
| Deployment | Pinned dependencies and live configuration evidence; canonical SE binding; factory-first market validation; singleton enforcement across changed arguments | P:173–179,713–748; A20,A45 |

Feasibility cannot be established by owner approval. Native-note liveness and zero-interest/direct-custody Weighted accounting are particularly capable of forcing a return to product design. No feature may be silently removed if a gate fails.

## 4. Initial positions and cross-review corrections

| Researcher | Initial position | Cross-review outcome |
| --- | --- | --- |
| Astra | Ready for gated planning, not frozen execution; emphasized accounting and availability | Retained distinction; rejected owner-only restriction, deterministic decay and fixed waterfall; narrowed owner queue |
| Grok | Not implementation-plan ready; prioritized authority, oracle and companion drift | Adopted gated/frozen distinction; withdrew empty-target and extra-eligibility questions; recategorized price construction as engineering |
| MiniMax M3 | Planning conditional on authority, singleton and TWAP closure | Accepted gated-plan framing but retained unsupported D9 encapsulation requirement and extra owner confirmations |
| Kimi K3 | Strong requirements, authority/TWAP and engineering gaps | Retracted deterministic decay and redundant eligibility question; adopted availability/bootstrap concerns; incorrectly treated historical D9 as an additional current conflict |

### Moderator resolution of the D9 dispute

**Do not impose owner-only public HLP access or request a new D9 exception on the evidence presented.** A:9 explicitly subordinates historical D1–D31 to D32–D66; A:101 (D61) explicitly permits public deposits/redemption with `ownerOnlyLiquidity=false`. P:102,165–167 selects public shared HLP.

Astra/Grok correctly recognized the current public mode. MiniMax's claim that owner-only pool operations and public share minting necessarily reconcile the issue is an unproven architectural prescription, not a requirement established by its citations. Kimi's additional supersession demand overlooks D61. Preserve both dissenting originals/cross-reviews, but do not import those conclusions into the plan. The remaining callback/privileged-operation authority design still needs specification.

### Other corrections accepted

- Empty-target Keep-YT failure already reverts; new seeding is not selected (P:577). No new owner question.
- Additional contraction conditions are not selected; propose them only if evidence justifies a change (P:338–340).
- Burn source class is already post-expansion synthetic pricing on actual owned reserves/new supply (P:399,407). Exact construction is engineering, not a fresh TWAP-versus-synthetic vote.
- Funding realization steps are possible, **not a fixed waterfall** (P:309).
- Staking-only expansion does not mechanically move reserve trading ratios or prove a 1,000-to-1 decay path (P:399). Economic response is unproven; no price-path reconfirmation is needed.
- A singleton salt is selected intent, not an enforcement proof or owner algorithm-design question (P:173; M:96).

### Remaining dissent

Researchers differ on whether authority/TWAP approvals must precede even drafting a gated plan or only its approval/execution. Moderator recommendation: drafting may explicitly carry these gates; **do not call the result frozen/executable until they are resolved**. P:657 and 883 support separating planning from executable approval.

## 5. Evidence confidence and limits

High confidence: document drift, settled selections, D61 precedence, and need to distinguish policy from engineering. Moderate confidence: identified feasibility risks and completeness of this review. No demonstrated economic soundness, security, gas feasibility, live-market compatibility or peg effectiveness.

Source versions reported in P:731–748: DETF/Weighted wrapper pragmas `^0.8.0`; Balancer V3 WeightedMath `^0.8.24`; Pendle YT v6/market v7 `^0.8.17`; Net vendor snapshot reported 2026-08-28. These are not verified installed compiler/runtime versions or immutable dependency pins. No shell, build, tests, fork, deployment or transaction was run in this round.

External primary references consulted by researchers after Context7 lookup, accessed 2026-09-25:

- Astra: https://docs.pendle.finance/pendle-v2-dev/Contracts/Oracle/PYLpOracle — distinguishes observation readiness concerns; not the selected NET/DETF oracle.
- Grok: https://eips.ethereum.org/EIPS/eip-4626 — interface obligations; no certification gate reinstated.
- Grok: https://docs.pendle.finance/pendle-academy/yield-trading-deep-dives/chapter-7-providing-liquidity-while-trading-yield — Keep-YT background, not deployed Robinhood equivalence.

Moderator did not independently re-fetch these URLs; final readiness conclusions rest on current local specifications, not an upstream deployment claim. Researcher reports contain some imprecise line citations (notably references to P:715 as singleton proof text); controlling singleton references are P:173 and M:96. Original model findings remain evidence to verify, not canonical law.

## 6. Preserved artifacts and sessions

All filenames below are under `docs/research/`; prefix is `netnet-pendle-readiness-2026-09-25-`.

| Researcher | Original | Cross-review | Preserved session | Observed task model |
| --- | --- | --- | --- | --- |
| Astra | [Original](netnet-pendle-readiness-2026-09-25-astra-original.md) | [Cross-review](netnet-pendle-readiness-2026-09-25-astra-cross-review.md) | `ses_f25fade8cffeMRUhowWuAOImOG` | `openai/gpt-6-astra` |
| Grok | [Original](netnet-pendle-readiness-2026-09-25-grok-original.md) | [Cross-review](netnet-pendle-readiness-2026-09-25-grok-cross-review.md) | `ses_f25f63f70ffe9CGLHPAkwydF3V` | `xai/grok-4.6` |
| MiniMax M3 | [Original](netnet-pendle-readiness-2026-09-25-minimax-original.md) | [Cross-review](netnet-pendle-readiness-2026-09-25-minimax-cross-review.md) | `ses_f25f3b310ffeMer1lyRloa9O4M` | `minimax/MiniMax-M3` |
| Kimi K3 | [Original](netnet-pendle-readiness-2026-09-25-kimi-original.md) | [Cross-review](netnet-pendle-readiness-2026-09-25-kimi-cross-review.md) | `ses_f25ef8556ffejQT9yEGeMtcgdV` | `kimi-code-plan-global/k3` |

Task routing matched the requested models; no participant failure or failed continuation was reported. Kimi reports high variant; task metadata does not independently attest that variant or provider identity. MiniMax reported using its available `write` tool instead of requested `apply_patch`, within its assigned Markdown path. Astra reported a discovery glob exposed historical peer filenames without reading their contents. No earlier peer reviews were intentionally supplied during independent passes; embedded PRD history was available to all.

## 7. Human checkpoint and separate implementation handoff

Recommended next authorization is **documentation closure and gated planning only**:

1. Reconcile companions and classify the open register without changing settled economics.
2. Prepare the scoped authority map and evidence-backed TWAP/availability proposal for owner decisions.
3. Front-load the engineering gates above; map R01–R55 and A01–A45 to deliverables, dependencies and measurable pass conditions.
4. Return concrete incompatibilities for human resolution before freezing an executable plan.

No implementation, tests, instruction/config edits, deployment or transactions are authorized by this report. The next implementer must receive a separately approved plan and resolved authority gates. Stop here for the human decision.
