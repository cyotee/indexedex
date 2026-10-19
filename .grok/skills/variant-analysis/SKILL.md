---
name: variant-analysis
description: "Find variants of a known bug by extracting its root cause, calibrating patterns, expanding searches, and triaging candidates."
---

# Variant Analysis

Find the other instances of a bug you have already found. One root cause usually has several
manifestations, and they are rarely in the module where you found the first one.


## IndexedEx integration

Read the target repository's `CLAUDE.md` and `docs/agent/SKILL_CATALOG.md`; current product law and canonical `crane-*` / `indexedex-*` guidance override generic examples here. Tests are production-first, never SUT mocks; use Crane TestBases, CREATE3/FactoryService for facets and the IndexedEx manager registry for vault/DETF DFPkgs, never direct `new`. For testing within the current authorized task: `forge build` before tests, default hermetic or `FOUNDRY_PROFILE=fork`; no `via_ir` or package profiles.

Analysis produces findings and recommendations, not silent production fixes. Commands, installation, scans, network/RPC, tests, deployments, Git writes and broadcasts require scope in the current request; examples grant none. Reading or installing this skill executes none. Current task authorization may already cover routine local analysis and validation; do not demand a second approval for those actions. Assessment-only requests do not authorize production fixes. Use Native's actual `read`, `grep`, `glob`, LSP and `apply_patch` tools as available; `allowed-tools` metadata is not enforcement. No Claude aliases or plugin agent registration is assumed. Report missing tools and unverified results rather than claiming success. Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness. Retained upstream interface metadata is inert in `references/upstream-openai.yaml`. Upstream pointers to `audit-context-building` or `issue-writer` are optional, not installed commands; use scoped code reading and the included report templates when they are absent.

## When to Use

- A vulnerability has been found and you need to search for similar instances
- Building or refining CodeQL/Semgrep queries for security patterns
- Performing systematic code audits after an initial issue discovery
- Analyzing how a single root cause manifests in different code paths

## When NOT to Use

- Initial vulnerability discovery — use audit-context-building or a domain-specific audit
- General code review with no known pattern to search for
- Writing fix recommendations — use issue-writer
- Understanding unfamiliar code — use audit-context-building first

## The Five Steps

Read the reference for a step when you reach it.

**1. Understand the original issue.** Extract the root cause — why the code is wrong, not
what it does — and enumerate the directions a variant could hide in: related identifiers,
other manifestations of the same mistake, data-type edge cases.
→ [references/root-cause.md](references/root-cause.md)

**2. Create an exact match.** Write a pattern matching ONLY the known instance and confirm
it hits. A pattern that matches nothing means you have misunderstood the bug, and every
search built on it is calibrated against the wrong code.

**3–4. Generalize one element at a time.** Climb from the exact match toward the pattern
family, running and reading all matches after each single change. Stop when more than half
the matches are noise.
→ [references/searching.md](references/searching.md) — abstraction ladder, tool selection,
false-positive filters

**5. Triage.** Decide which candidates are real, and say so with a severity attached.
→ [references/triage.md](references/triage.md)

**Then write it up**, including the patterns that failed and a CI rule to prevent regression.
→ [references/reporting.md](references/reporting.md)

## Coordinating a larger hunt in Native

The upstream plugin slash workflow is not archived or registered here. For narrow searches, apply the five steps directly. For a larger hunt, use Native `task` with an available category such as `deep-low`, `run_in_background: true`, and explicit instructions; do not dispatch undefined plugin agents.

First extract one grounded root-cause statement and calibrate an exact match. Partition independent, non-overlapping expansion axes using [root-cause.md](references/root-cause.md). Give each worker the known instance, its assigned axis, authorized search root, read-only constraints, and the complete relevant searching/triage instructions. Require the pattern history, every match location, evidence, false-positive counts and reasons, severity, confidence and coverage limits. Workers generalize one element at a time and read every new match, stopping that axis when new justified abstractions yield no new candidates or noise exceeds the threshold. No automatic installs, scanners, CI writes, production fixes or broadcasts.

Collect and deduplicate candidates by location and root cause, then re-check callers, guards and reachability before confirming. Take a new sweep only when new evidence or a different grounded axis warrants it; record exhaustion and unsearched areas rather than claiming whole-codebase coverage. Fill the retained [report template](resources/variant-report-template.md), including failed patterns and a proposed regression rule, without installing it into CI. Tool/rule execution is a separately scoped operation; source search and evidence review remain usable when Semgrep/CodeQL are unavailable.

## What Makes Hunts Fail

1. **Narrow scope** — searching only the module the original bug was in
2. **Pattern too specific** — searching one attribute and missing the family around it
3. **One vulnerability class** — chasing a single manifestation of the root cause
4. **Happy-path testing** — never trying the null, empty, and boundary cases
5. **Generalizing too fast** — abstracting several elements at once, so noise cannot be
   attributed to any one of them

The first three are covered in root-cause.md and searching.md, the fourth in triage.md.

## Resources

**CodeQL** (`resources/codeql/`): `python.ql`, `javascript.ql`, `java.ql`, `go.ql`, `cpp.ql`

**Semgrep** (`resources/semgrep/`): `python.yaml`, `javascript.yaml`, `java.yaml`, `go.yaml`, `cpp.yaml`

**Report**: `resources/variant-report-template.md`
