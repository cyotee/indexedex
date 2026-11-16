# Port provenance: audit-prep-assistant

Staged 2026-10-19 for IndexedEx / OmO Native; not installed.

## Source evidence

- Archive: `/Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json`.
- Source asset: `skill-470063ab97d17986b26c691eb4c308c4bf0333a10f02802b76dccb861641d335`; tree SHA-256: `470063ab97d17986b26c691eb4c308c4bf0333a10f02802b76dccb861641d335`.
- Preferred occurrence: `plugin-cache/trailofbits/building-secure-contracts/1.2.2/skills/audit-prep-assistant`.
- Object bytes read from `objects/<sha256>` and checked against every listed source hash.

| Source asset | Source file | Staged file | Source SHA-256 | Staged SHA-256 | Equality/change | Source mode |
|---|---|---|---|---|---|---|
| `skill-470063ab97d17986b26c691eb4c308c4bf0333a10f02802b76dccb861641d335` | `SKILL.md` | `SKILL.md` | `d639b411a315ea9420e40afabe75bbf4b1bfed6ea5c8601a3e963343ac9924f2` | `c77b46d725ab685a3543597a46d2e56b404dac124d23ce43dbfae2b21b0c1992` | adapted | 420 |
| `skill-470063ab97d17986b26c691eb4c308c4bf0333a10f02802b76dccb861641d335` | `agents/openai.yaml` | `references/upstream-openai.yaml` | `4809b33885e808d1ee243f51d3d6e982d2df0294345aee1094a4a338502ac213` | `4809b33885e808d1ee243f51d3d6e982d2df0294345aee1094a4a338502ac213` | relocated-identical | 420 |
| `skill-470063ab97d17986b26c691eb4c308c4bf0333a10f02802b76dccb861641d335` | `assets/trail-of-bits-mark.svg` | `assets/trail-of-bits-mark.svg` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | unchanged | 420 |

## Exact adaptations

- `references/upstream-openai.yaml`: Relocated agents/openai.yaml byte-for-byte outside agent discovery; display metadata only, no registration.
- `SKILL.md`: Shorten selection description to IndexedEx 160-character catalog budget, retaining full body coverage.
  - Replaced: "description: Prepares codebases for security review using Trail of Bits' checklist. Helps set review goals, runs static analysis tools, increases test coverage, removes dead code, ensures accessibility, and generates documentation (flowcharts, user stories, inline comments). Use when preparing your own codebase to be audited by someone else, getting a repository review-ready before an external security review, deciding what to fix before auditors start, or asking what assessors need from a project. For understanding unfamiliar code you are about to audit, use audit-context-building instead."
  - With: "description: \"Prepare a smart contract codebase for audit: scope, goals, analysis triage, coverage gaps, accessibility, and documentation.\""
- `SKILL.md`: Insert IndexedEx integration section: project precedence, production-first testing/deployment law, analysis-only default, scoped operations, Native tools and inert metadata.
- `SKILL.md`: Clarify upstream examples are not observed evidence.
  - Replaced: "Reports go only to the user-scoped output path."
  - With: "Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness."
- `SKILL.md`: Separate audit preparation from production fixes.
  - Replaced: "Runs static analysis and helps fix low-hanging fruit:"
  - With: "Reviews existing static-analysis evidence and proposes low-hanging fixes. Run fresh analysis only when the current request authorizes it; implementation is a separate requested task:"
- `SKILL.md`: Gate scanner commands.
  - Replaced: "**Run Static Analysis**:"
  - With: "**Static Analysis Plan (commands for separately authorized use)**:"
- `SKILL.md`: Recommend fixes only.
  - Replaced: "- Help fix easy issues"
  - With: "- Recommend specific fixes; do not apply production changes during assessment"
- `SKILL.md`: No automatic contract execution.
  - Replaced: "- Run full test suite"
  - With: "- Review existing test results; record missing evidence and a scoped test plan"
- `SKILL.md`: No automatic Git or lockfile writes.
  - Replaced: "- Create dedicated branch\n- Tag release version\n- Lock dependencies"
  - With: "- Recommend a dedicated review branch and release tag\n- Record dependency versions; do not mutate lockfiles or Git state"
- `SKILL.md`: Align procedure with analysis-only scope.
  - Replaced: "2. **Run static analysis** - Execute appropriate tools for your platform"
  - With: "2. **Review static analysis** - Triage existing evidence; list unavailable tools and propose authorized reruns"
- `SKILL.md`: Gate mandatory rerun.
  - Replaced: "| Execute static analysis tools, generate fresh report |"
  - With: "| If execution is authorized, generate a fresh report; otherwise record the evidence gap |"
- `SKILL.md`: Gate fresh build.
  - Replaced: "| Test build on fresh environment, document every dependency version |"
  - With: "| Document dependency versions and fresh-build procedure; execute only in a separately authorized task |"
- `SKILL.md`: Keep coverage honest.
  - Replaced: "| Run coverage tools, identify specific untested code paths |"
  - With: "| Review coverage evidence and identify untested paths; mark unmeasured coverage explicitly |"
- `SKILL.md`: Keep dead-code review read-only.
  - Replaced: "| Use automated detection tools to find unused functions/variables |"
  - With: "| Inspect references and propose dead-code candidates; run detection tools only when authorized |"
- `SKILL.md`: No branch writes.
  - Replaced: "| Identify and document commit hash now, create dedicated branch |"
  - With: "| Identify and document commit hash now; propose a review branch without creating it |"
- `SKILL.md`: No automatic external sharing.
  - Replaced: "- Send package to auditors"
  - With: "- Deliver the package to the user; external sharing requires explicit authorization"

The inserted IndexedEx integration section is in `SKILL.md`. Other than the listed adaptations, complete source coverage, notices, assets and templates are retained. The upstream interface YAML is preserved byte-for-byte as inert reference data, not agent configuration; icon paths retain upstream package-root semantics. Source modes are recorded, not an installation/mode-restoration claim.

## Missing tooling and dependencies

- Slither, Dylint, golangci-lint, CodeQL, Semgrep and coverage/build tools: availability not probed; commands not run.
- audit-context-building is an optional external skill, not bundled or assumed installed.

## License evidence

Manifest owner `building-secure-contracts@trailofbits`: `not-found-at-root-review-redistribution`; recorded license assets: []. No license found at the archived plugin root. Actual attribution/notices and source frontmatter are retained; no MIT terms or other license grant is inferred or added. Redistribution rights remain unresolved. No external license fetch was performed.

## Validation boundary

Read/parse and hash/link checks only. No scripts, hooks, scanners, network, tests or contract operations were executed; no MCP/plugin manifests or agent registrations are staged. Reports and role prose do not authorize production edits or broadcasts.

## Deployment review adjustment

Removed staging-only wording and clarified that existing task authorization covers
routine local analysis/validation. Optional upstream skill pointers are not assumed
installed commands. Final installed hashes are recorded in the deployment ledger.
