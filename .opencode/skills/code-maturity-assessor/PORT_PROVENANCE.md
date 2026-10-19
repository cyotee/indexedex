# Port provenance: code-maturity-assessor

Staged 2026-10-19 for IndexedEx / OmO Native; not installed.

## Source evidence

- Archive: `/Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json`.
- Source asset: `skill-389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766`; tree SHA-256: `389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766`.
- Preferred occurrence: `plugin-cache/trailofbits/building-secure-contracts/1.2.2/skills/code-maturity-assessor`.
- Object bytes read from `objects/<sha256>` and checked against every listed source hash.

| Source asset | Source file | Staged file | Source SHA-256 | Staged SHA-256 | Equality/change | Source mode |
|---|---|---|---|---|---|---|
| `skill-389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766` | `SKILL.md` | `SKILL.md` | `a5e1427ae04cb0ed32b003c332becc0c8adb8e382d8d1d489edc997148b57ab1` | `e7e01b39cb40cbd2dedaec53cbfa996681f5cb4f434000a8ee129c55f684e984` | adapted | 420 |
| `skill-389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766` | `agents/openai.yaml` | `references/upstream-openai.yaml` | `b3b5badfebd66eedfaae9b5ad1c867ce6a6a82215f92be5224f62f6351955fc3` | `b3b5badfebd66eedfaae9b5ad1c867ce6a6a82215f92be5224f62f6351955fc3` | relocated-identical | 420 |
| `skill-389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766` | `assets/trail-of-bits-mark.svg` | `assets/trail-of-bits-mark.svg` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | unchanged | 420 |
| `skill-389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766` | `resources/ASSESSMENT_CRITERIA.md` | `resources/ASSESSMENT_CRITERIA.md` | `0ffe131842b209de7910cc2ac77fc1e2cdea1e16455bfba79505c8ba8179009f` | `0ffe131842b209de7910cc2ac77fc1e2cdea1e16455bfba79505c8ba8179009f` | unchanged | 420 |
| `skill-389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766` | `resources/EXAMPLE_REPORT.md` | `resources/EXAMPLE_REPORT.md` | `47f37a7460cf281cb4ca2aeb3abced762ce4b7dd4db21e7b12772b2202e4fc42` | `47f37a7460cf281cb4ca2aeb3abced762ce4b7dd4db21e7b12772b2202e4fc42` | unchanged | 420 |
| `skill-389a2ab5d99a58e520fde96216bd5d697dfc880f9bf21b738bc0d76baa833766` | `resources/REPORT_FORMAT.md` | `resources/REPORT_FORMAT.md` | `28474cce17be996e839353978fc06a830ac3fbd1219efbacc914de567fcdd7dc` | `28474cce17be996e839353978fc06a830ac3fbd1219efbacc914de567fcdd7dc` | unchanged | 420 |

## Exact adaptations

- `references/upstream-openai.yaml`: Relocated agents/openai.yaml byte-for-byte outside agent discovery; display metadata only, no registration.
- `SKILL.md`: Shorten selection description to IndexedEx 160-character catalog budget, retaining full body coverage.
  - Replaced: "description: Systematic code maturity assessment using Trail of Bits' 9-category framework. Analyzes codebase for arithmetic safety, auditing practices, access controls, complexity, decentralization, documentation, MEV risks, low-level code, and testing, then produces a scorecard with evidence-based ratings and a priority-ordered roadmap. Use when assessing or scoring the maturity of a smart contract or blockchain codebase, producing a maturity scorecard or evaluation, or judging how mature, well-tested, or well-documented such a project is against a rubric."
  - With: "description: \"Assess smart contract maturity across nine Trail of Bits categories; produce evidence-backed ratings and a prioritized roadmap.\""
- `SKILL.md`: Insert IndexedEx integration section: project precedence, production-first testing/deployment law, analysis-only default, scoped operations, Native tools and inert metadata.
- `SKILL.md`: Clarify upstream examples are not observed evidence.
  - Replaced: "Reports go only to the user-scoped output path."
  - With: "Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness."

The inserted IndexedEx integration section is in `SKILL.md`. Other than the listed adaptations, complete source coverage, notices, assets and templates are retained. The upstream interface YAML is preserved byte-for-byte as inert reference data, not agent configuration; icon paths retain upstream package-root semantics. Source modes are recorded, not an installation/mode-restoration claim.

## Missing tooling and dependencies

- Coverage, monitoring, incident-response and team-process evidence must be supplied or inspected in a later scoped assessment; no assessment of IndexedEx was performed.

## License evidence

Manifest owner `building-secure-contracts@trailofbits`: `not-found-at-root-review-redistribution`; recorded license assets: []. No license found at the archived plugin root. Actual attribution/notices and source frontmatter are retained; no MIT terms or other license grant is inferred or added. Redistribution rights remain unresolved. No external license fetch was performed.

## Validation boundary

Read/parse and hash/link checks only. No scripts, hooks, scanners, network, tests or contract operations were executed; no MCP/plugin manifests or agent registrations are staged. Reports and role prose do not authorize production edits or broadcasts.

## Deployment review adjustment

Removed staging-only wording and clarified that existing task authorization covers
routine local analysis/validation. Optional upstream skill pointers are not assumed
installed commands. Final installed hashes are recorded in the deployment ledger.
