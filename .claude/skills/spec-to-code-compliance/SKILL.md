---
name: spec-to-code-compliance
description: "Compare authoritative specifications with implementation paths; record requirement verdicts, evidence, refutations, and undocumented behavior."
allowed-tools: task read grep glob apply_patch
---

# Spec-to-Code Compliance

Two artifacts disagree, and the job is to find where. The documentation says what the system does; the code
decides what it actually does. Every gap between them is either a bug or a documentation fix, and which one it
is is the finding.


## IndexedEx integration

Read the target repository's `CLAUDE.md` and `docs/agent/SKILL_CATALOG.md`; current product law and canonical `crane-*` / `indexedex-*` guidance override generic examples here. Tests are production-first, never SUT mocks; use Crane TestBases, CREATE3/FactoryService for facets and the IndexedEx manager registry for vault/DETF DFPkgs, never direct `new`. For testing within the current authorized task: `forge build` before tests, default hermetic or `FOUNDRY_PROFILE=fork`; no `via_ir` or package profiles.

Analysis produces findings and recommendations, not silent production fixes. Commands, installation, scans, network/RPC, tests, deployments, Git writes and broadcasts require scope in the current request; examples grant none. Reading or installing this skill executes none. Current task authorization may already cover routine local analysis and validation; do not demand a second approval for those actions. Assessment-only requests do not authorize production fixes. Use Native's actual `read`, `grep`, `glob`, LSP and `apply_patch` tools as available; `allowed-tools` metadata is not enforcement. No Claude aliases or plugin agent registration is assumed. Report missing tools and unverified results rather than claiming success. Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness. Retained upstream interface metadata is inert in `references/upstream-openai.yaml`. Upstream pointers to `audit-context-building` or `issue-writer` are optional, not installed commands; use scoped code reading and the included report templates when they are absent.

## When to Use

You have both documentation describing intended behavior and the code that should implement it. A whitepaper
against a protocol, a design note against a service, a README's stated guarantees against the functions behind
them.

Most useful when the document is authoritative — something a client wrote, published, or is audited against —
because then a divergence is a defect rather than stale prose.

## When NOT to Use

Not for code with no documentation of intended behavior. There is nothing to check against, and a requirement
inferred from the code is checked against itself. Build the system model first with `audit-context-building`.

Not for finding bugs in general. This finds one class: where the code and the document disagree. A bug both
artifacts are silent about is out of scope, and a bug the document endorses is a finding against the document.

Not for writing or improving documentation, though it produces the list of what needs fixing.

## Per-requirement checking in Native

The archived plugin command and its dispatch script are not supplied or registered here. Preserve the original isolation, independent refutation and structured evidence goals with explicit Native task prompts; do not claim a schema-enforced plugin runtime exists.

1. Scope the code path, authoritative specification(s), output directory and requirement limit with the current request. Read the current IndexedEx router and approved family PRDs before older specs; retired families and superseded product law are not implementation obligations. Inventory unreadable documents and authority conflicts rather than inventing their contents.
2. Split the scoped specification into individually checkable requirements. Give each an ID, verbatim quotation, document/section, normative force (MUST/SHOULD/MAY or descriptive), enforcement target and any ambiguity. Record requirements beyond the scoped limit as `notChecked`, never silently omit them.
3. For each checked requirement, read the complete [checker role](references/spec-compliance-checker.md). Use Native `task` with an available category such as `deep-low`, `run_in_background: true`, and an explicit prompt containing that role, one requirement, document/code paths, read-only production scope, and a unique report path. Do not use a namespaced or bare plugin role as `subagent_type`. Each worker must read enforcement, callees, callers, modifiers and all relevant paths, not infer from names. Use [ANALYSIS_FORMAT.md](resources/ANALYSIS_FORMAT.md) for one file per requirement.
4. Require each worker's compact record to carry `id`, `verdict`, `confidence`, `analysisPath`, `documentProblem`, `read` (file and line ranges), and `searched` (patterns, scope, results). Accept only the six verdicts below; `absent` needs explicit searches, including alternate vocabulary and caller/base enforcement. Parse returned JSON and inspect required fields and cited analysis files yourself: prompt instructions are not schema enforcement. Missing, malformed, truncated or unsupported records are `unverified`, not confirmed.
5. Send every candidate divergence to two fresh, independent workers that did not author it: one re-reads code enforcement/call paths, one re-reads the authoritative specification and its definitions. Explicitly ask each to refute the finding and return `upheld`, `refuted` or `unverified` with evidence. Remove or revise refuted divergences with reasons recorded; confirm only after both uphold it. Failed/missing refutations remain `unverified` and visible to the user. Do not reuse the finding author's self-review as an independent refutation.
6. Check the reverse direction explicitly: inspect behavior in the scoped code and identify obligations or constraints with no corresponding document requirement. This cannot be found by specification-driven workers alone. Record coverage and authority uncertainties.
7. Produce `REPORT.md` and `requirements/<id>.md` only within the user-scoped output directory (for example `spec-compliance/` when requested). The report contains the requirement index, six verdict counts, severity and consequence, evidence links, reverse gaps, `notChecked`, `unverified`, `unreadableDocuments` and `documentProblem` records, refutation outcomes, scope and limitations. Return compact records and a summary to the user. If Native delegation is unavailable, perform isolated sequential checks and explicitly disclose that independent-worker refutation was not achieved; do not label those divergences confirmed.

For one requirement, use the same checker role directly or in an explicit Native task prompt. Full-document work needs a separate context per requirement because each verdict depends on an entire enforcement chain. Do not replace that coverage with plausible summaries. This port does not carry forward upstream plugin evaluation measurements as evidence of Native dispatch behavior.

## What comes back, and how to read it

Every requirement gets one of six verdicts: `implemented`, `partial`, `contradicted`, `stronger-than-spec`,
`absent`, or `undecidable`. The interesting ones are the middle four.

- **`partial`** is usually the most serious thing in the report. The requirement holds on the paths anyone would
  test and fails on one nobody did, which is how it survived long enough to be found.
- **`absent`** rests entirely on its `searched` record. Read it. Enforcement often lives somewhere the search
  did not go — a modifier, a base class, a caller that checks first.
- **`undecidable`**, and any `documentProblem`, are findings about the documentation. A requirement too vague to
  check is one the client cannot hold anyone to.
- **`stronger-than-spec`** is an undocumented constraint. It works today, and nothing tells the next person
  changing that code that anything depended on it.

The report also carries the reverse direction — behavior the code has that no document mentions — which the
per-requirement pass cannot find by construction, since it is driven by the documents.

Read `notChecked`, `unverified`, and `unreadableDocuments` before treating the report as complete. Requirements
below the fan-out cut were never checked, and a divergence whose refutation agents both failed is unverified
rather than confirmed.

## Judgment the analysis does not make for you

Severity is consequence, not distance from the text: [DIVERGENCE_RUBRIC.md](resources/DIVERGENCE_RUBRIC.md). A
rounding step that bleeds a pool outranks a MUST satisfied by different means than the document describes, and
documentation drift with no behavioral consequence is a docs ticket.

The verdict is not the finding. `absent` on a mandatory requirement is a finding; `absent` on a sentence
describing a roadmap item is not. Deciding which is which is what this skill is for, and the workflow hands you
the evidence to decide it with.

## The target does not have to be a contract

The question is the same everywhere — what does this requirement demand, where would it be enforced, is it
enforced on every path — but what counts as a specification and where enforcement hides both change.
[DOMAIN_NOTES.md](resources/DOMAIN_NOTES.md) maps that across contracts, C and C++, services, and decompiled
firmware, and covers the case where the specification is an RFC or a standard rather than a project document.
Read it when the target is not a contract, and when scoping a check against a large standard.

## Reference

- [ANALYSIS_FORMAT.md](resources/ANALYSIS_FORMAT.md) — the on-disk format for a per-requirement analysis. Read
  when producing analysis or judging whether a record is trustworthy.
- [WORKED_EXAMPLE.md](resources/WORKED_EXAMPLE.md) — three requirements chased to a verdict, one per verdict
  that is easy to get wrong: arithmetic that satisfies a requirement it does not resemble, an absence whose
  searches are the finding, and enforcement present on every path but the one nobody tested.
- [DOMAIN_NOTES.md](resources/DOMAIN_NOTES.md) — per-domain mapping of specifications and enforcement.
- [DIVERGENCE_RUBRIC.md](resources/DIVERGENCE_RUBRIC.md) — severity, and the two directions of a gap.
