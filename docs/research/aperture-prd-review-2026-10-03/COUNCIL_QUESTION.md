# Council review: clarifications and improvements to the Aperture PRD

Date: 2026-10-03. Human question: “Does the council have any questions to clarify the requirements or any suggestions to improve the PRD?”

## Review target

Read directly: `docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md`, current `CLAUDE.md`, referenced current family/task PRDs and canonical skills as needed. The owner has selected Aperture-inspired sizing for the existing Hookless SE and explicitly requires math-library implementation/tests first, then vault refactoring only after successful validation. Mandatory scalar entry/exit, proportional whole-book ownership, sleeve, current protections, Pons separation and current blocked-state policy are not open questionnaires absent an identified contradiction.

This is a requirements-review round, not another algorithm search or implementation task. Do not modify the target PRD or earlier artifacts. The moderator will consolidate suggested changes for human decision.

## Same goals for all four researchers

1. Identify true ambiguities, contradictions, missing product acceptance and risky implementation interpretations. Cite target PRD section and line numbers plus source/other current law as relevant.
2. Classify every finding: **owner decision**, **engineering detail for later plan**, **editorial clarification**, **already settled/do not reopen**. Ask only questions that actually affect scope/economics/acceptance; do not offload coefficient widths, exact filenames or routine test engineering to the human. Give a recommended default and concrete consequence for each owner question.
3. Review Stage 1 isolation and Gate M: can all required math/traversal/exact settlement/placement/whole-book tests be built without prematurely integrating the vault? Does Gate M accidentally require Stage 2 consumer proof or unrealistic exhaustive coverage? Define clean proof-vs-integration boundaries and failure/re-entry semantics. Stage 1 must establish useful integer domains, not universal rejection or only continuous algebra.
4. Review intended bounded monotone traversal versus one-segment milestone, one candidate/rounding correction/stencil, analytical completeness vs practically useful liveness, parity vs economic equivalence, baseline old solver status and missed-solution policy. Clarify what prior search cannot be the oracle for.
5. Review work/gas acceptance: counters for word reads/core steps/certification, current 64-step envelope, maintenance and outer Orbital searches preserved, nested caps and baseline failures. Is the PRD measurable without inventing a gas win or making all upstream/consumer failures part of this refactor? Identify scope traps and crisp later measurement requirements.
6. Review scope preservation: D1–D31, existing full range, no wings/NAV/idle-CP change, exact-output limits, collection/credit/placement ownership, already-unlocked cover, V4 callback/delta/state projection, Pons generic dependency changes, registry/artifact/source-copy/license gate. Do not import third-party policy simply because upstream uses it.
7. Suggest concise replacement/additional clauses, prioritized P0/P1/P2, with acceptance rationale. Distinguish required corrections from optional enhancements. Seek the smallest sufficient changes, not an expanded research wish list.
8. End with a short list (prefer <=3) of genuine blocking owner questions, if any; explicit “none” is valid. Include recommended PRD readiness status and what the later implementation plan must settle. No consensus claim or passing tests/security/gas claim.

## Protocol

Retained sessions: Astra ses_efedceddcffePvMhXHALsysYwr; Grok REPLACEMENT ses_efe9c85c1ffexasWfYk2bT5JP0; MiniMax ses_efd10d9aeffeZrzk3843SZFPTL; Kimi ses_efd0301b6ffeRJ1euc9LP87byl. No restart/substitution.

Each first pass reads this identical question and target PRD but **no peer original/review/synthesis artifacts**, old or new. Retained session history exists. Write only assigned original in this directory: astra-original.md, grok-replacement-original.md, minimax-original.md, kimi-original.md. Prefer <=2000 words with a findings table and exact proposed wording. Originals remain immutable. Later each session gets all three other complete originals together, never earlier cross-reviews, and writes its assigned review.

Research and assigned document authoring only; no delegation, shell/tests/execution/deployment/config/instruction/contracts changes. Context7 first if making fresh library/API claims, then public primary sources; no private source/secrets externally. Ordinary missing paths: record and do not retry the exact path. Guard attribution/identity/history/compaction/evidence or genuine SDK unavailable: stop/report without retry. Do not bypass denied writes. Moderator owns final review report and stops for human decisions; target PRD amendments are not silently applied.
