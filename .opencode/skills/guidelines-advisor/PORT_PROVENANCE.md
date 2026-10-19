# Port provenance: guidelines-advisor

Staged 2026-10-19 for IndexedEx / OmO Native; not installed.

## Source evidence

- Archive: `/Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json`.
- Source asset: `skill-fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df`; tree SHA-256: `fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df`.
- Preferred occurrence: `plugin-cache/trailofbits/building-secure-contracts/1.2.2/skills/guidelines-advisor`.
- Object bytes read from `objects/<sha256>` and checked against every listed source hash.

| Source asset | Source file | Staged file | Source SHA-256 | Staged SHA-256 | Equality/change | Source mode |
|---|---|---|---|---|---|---|
| `skill-fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df` | `SKILL.md` | `SKILL.md` | `5bb8ba34d363c419e1769a59d0fcc7444a04dc6d9e59032cb93019befdc2e464` | `449b0bf45116e191a68ffe7aa9d8ad9910bbad7139befe9362d7173593a01cde` | adapted | 420 |
| `skill-fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df` | `agents/openai.yaml` | `references/upstream-openai.yaml` | `efb688da205e309c49a91e969bfd5c6c63c23ad3f90bd429367d5539eea7e6ec` | `efb688da205e309c49a91e969bfd5c6c63c23ad3f90bd429367d5539eea7e6ec` | relocated-identical | 420 |
| `skill-fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df` | `assets/trail-of-bits-mark.svg` | `assets/trail-of-bits-mark.svg` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | unchanged | 420 |
| `skill-fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df` | `resources/ASSESSMENT_AREAS.md` | `resources/ASSESSMENT_AREAS.md` | `951352a5e7c3afa717ed62770ae1b7c152c4792480e3beebefc68f9c96d2a46c` | `951352a5e7c3afa717ed62770ae1b7c152c4792480e3beebefc68f9c96d2a46c` | unchanged | 420 |
| `skill-fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df` | `resources/DELIVERABLES.md` | `resources/DELIVERABLES.md` | `5a9a6e14acb0be5dd8e15440227d5cf659931ec79cca346661f9ef22bc5f21c2` | `5a9a6e14acb0be5dd8e15440227d5cf659931ec79cca346661f9ef22bc5f21c2` | unchanged | 420 |
| `skill-fc96a9fc95576feddca6d6fb981325c9e46c81cf555a71c284223f0160bf42df` | `resources/EXAMPLE_REPORT.md` | `resources/EXAMPLE_REPORT.md` | `4c31c1718afaece6c7ba2c3519373167ca5d81f937fb4356c8d9b45d280833f0` | `4c31c1718afaece6c7ba2c3519373167ca5d81f937fb4356c8d9b45d280833f0` | unchanged | 420 |

## Exact adaptations

- `references/upstream-openai.yaml`: Relocated agents/openai.yaml byte-for-byte outside agent discovery; display metadata only, no registration.
- `SKILL.md`: Shorten selection description to IndexedEx 160-character catalog budget, retaining full body coverage.
  - Replaced: "description: Smart contract development advisor based on Trail of Bits' best practices. Analyzes codebase to generate documentation/specifications, review architecture, check upgradeability patterns, assess implementation quality, identify pitfalls, review dependencies, and evaluate testing. Use when asking whether a smart contract project follows development best practices, reviewing on-chain/off-chain split, upgradeability, or delegatecall proxy patterns against guidelines, or seeking recommendations on contract design, inheritance, events, documentation, dependencies, or test strategy."
  - With: "description: \"Review smart contract architecture, proxy safety, dependencies, documentation, and testing against Trail of Bits development guidance.\""
- `SKILL.md`: Insert IndexedEx integration section: project precedence, production-first testing/deployment law, analysis-only default, scoped operations, Native tools and inert metadata.
- `SKILL.md`: Clarify upstream examples are not observed evidence.
  - Replaced: "Reports go only to the user-scoped output path."
  - With: "Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness."

The inserted IndexedEx integration section is in `SKILL.md`. Other than the listed adaptations, complete source coverage, notices, assets and templates are retained. The upstream interface YAML is preserved byte-for-byte as inert reference data, not agent configuration; icon paths retain upstream package-root semantics. Source modes are recorded, not an installation/mode-restoration claim.

## Missing tooling and dependencies

- Slither and upgradeability tools: availability not probed; no scanners run.
- External vulnerability databases and language documentation remain optional source references; no network lookups made.

## License evidence

Manifest owner `building-secure-contracts@trailofbits`: `not-found-at-root-review-redistribution`; recorded license assets: []. No license found at the archived plugin root. Actual attribution/notices and source frontmatter are retained; no MIT terms or other license grant is inferred or added. Redistribution rights remain unresolved. No external license fetch was performed.

## Validation boundary

Read/parse and hash/link checks only. No scripts, hooks, scanners, network, tests or contract operations were executed; no MCP/plugin manifests or agent registrations are staged. Reports and role prose do not authorize production edits or broadcasts.

## Deployment review adjustment

Removed staging-only wording and clarified that existing task authorization covers
routine local analysis/validation. Optional upstream skill pointers are not assumed
installed commands. Final installed hashes are recorded in the deployment ledger.
