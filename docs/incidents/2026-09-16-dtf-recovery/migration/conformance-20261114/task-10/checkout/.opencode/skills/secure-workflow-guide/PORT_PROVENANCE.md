# Port provenance: secure-workflow-guide

Staged 2026-10-19 for IndexedEx / OmO Native; not installed.

## Source evidence

- Archive: `/Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json`.
- Source asset: `skill-c00024de643ad49c4478bbdd599ed5ae49480661f8fb7b44df0707b5d06591db`; tree SHA-256: `c00024de643ad49c4478bbdd599ed5ae49480661f8fb7b44df0707b5d06591db`.
- Preferred occurrence: `plugin-cache/trailofbits/building-secure-contracts/1.2.2/skills/secure-workflow-guide`.
- Object bytes read from `objects/<sha256>` and checked against every listed source hash.

| Source asset | Source file | Staged file | Source SHA-256 | Staged SHA-256 | Equality/change | Source mode |
|---|---|---|---|---|---|---|
| `skill-c00024de643ad49c4478bbdd599ed5ae49480661f8fb7b44df0707b5d06591db` | `SKILL.md` | `SKILL.md` | `7c0e7fb45f97c073ec9599cbe0b2acf44f31bbece38636bc5c3fcc9bc7703015` | `c2e5aee8f179fa21c63f3a7a10c281bae2dcd40f9fb5248bcb8cea7299aa2d1d` | adapted | 420 |
| `skill-c00024de643ad49c4478bbdd599ed5ae49480661f8fb7b44df0707b5d06591db` | `agents/openai.yaml` | `references/upstream-openai.yaml` | `bc87102affc83dfb8e2676efc91cf792512ddfcbe37af2fa1446d389d591b545` | `bc87102affc83dfb8e2676efc91cf792512ddfcbe37af2fa1446d389d591b545` | relocated-identical | 420 |
| `skill-c00024de643ad49c4478bbdd599ed5ae49480661f8fb7b44df0707b5d06591db` | `assets/trail-of-bits-mark.svg` | `assets/trail-of-bits-mark.svg` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | unchanged | 420 |
| `skill-c00024de643ad49c4478bbdd599ed5ae49480661f8fb7b44df0707b5d06591db` | `resources/EXAMPLE_REPORT.md` | `resources/EXAMPLE_REPORT.md` | `c55fb9e549a38c9bebc9b23f5f16fb498bd20a8f867868232623a4bd721df340` | `c55fb9e549a38c9bebc9b23f5f16fb498bd20a8f867868232623a4bd721df340` | unchanged | 420 |
| `skill-c00024de643ad49c4478bbdd599ed5ae49480661f8fb7b44df0707b5d06591db` | `resources/WORKFLOW_STEPS.md` | `resources/WORKFLOW_STEPS.md` | `8b048011407a9a123a01ba4548b62a944f8cd5f271e4e0cdfe58b09583bd9291` | `ee42879c24e12ec6245d12a03e46e01a39934fc7e50246a48fbab27d85b1953d` | adapted | 420 |

## Exact adaptations

- `references/upstream-openai.yaml`: Relocated agents/openai.yaml byte-for-byte outside agent discovery; display metadata only, no registration.
- `SKILL.md`: Shorten selection description to IndexedEx 160-character catalog budget, retaining full body coverage.
  - Replaced: "description: Guides through Trail of Bits' 5-step secure development workflow. Runs Slither scans, checks special features (upgradeability/ERC conformance/token integration), generates visual security diagrams, helps document security properties for fuzzing/verification, and reviews manual security areas. Use when securing a smart contract end to end rather than hunting one bug, checking a project on every check-in or before deployment, triaging a Slither report, or asking where to start on smart contract security."
  - With: "description: \"Apply the five-step secure contract workflow: known issues, special features, diagrams, security properties, and manual review.\""
- `SKILL.md`: Insert IndexedEx integration section: project precedence, production-first testing/deployment law, analysis-only default, scoped operations, Native tools and inert metadata.
- `SKILL.md`: Clarify upstream examples are not observed evidence.
  - Replaced: "Reports go only to the user-scoped output path."
  - With: "Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness."
- `SKILL.md`: Gate scan launch.
  - Replaced: "Run Slither with 70+ built-in detectors to find common vulnerabilities:"
  - With: "Review Slither evidence for known vulnerabilities; run a fresh scan only when explicitly within the current task:"
- `SKILL.md`: Separate property documentation from test infrastructure writes.
  - Replaced: "Then set up testing:"
  - With: "Then propose testing, implemented only in a separately requested testing task:"
- `SKILL.md`: No automatic scanner invocation.
  - Replaced: "2. **Run Step 1**: Slither security scan"
  - With: "2. **Review Step 1**: Existing Slither evidence and scan gaps"
- `SKILL.md`: Gate special-feature tools.
  - Replaced: "3. **Detect and run Step 2**: Special feature checks (only what applies)"
  - With: "3. **Assess Step 2**: Applicable special features; execute checks only when authorized"
- `SKILL.md`: Remove mandatory tool installation.
  - Replaced: "| Install and run Slither, or document why it's blocked |"
  - With: "| Document unavailable or unauthorized Slither execution; do not install tools implicitly |"
- `SKILL.md`: Keep diagram coverage without compelled execution.
  - Replaced: "| Execute slither --print commands, generate actual visual outputs |"
  - With: "| Use existing outputs or source-derived diagrams; mark scanner-generated diagrams unverified if execution is not authorized |"
- `SKILL.md`: Prefer repository testing infrastructure.
  - Replaced: "| Document properties now, set up fuzzing infrastructure |"
  - With: "| Document properties now; propose production-first Foundry invariants and separately scope any new fuzzing tooling |"
- `SKILL.md`: No scope expansion from rationalization table.
  - Replaced: "| Execute all 5 steps, generate project-specific findings with file:line references |"
  - With: "| Cover all 5 steps with evidence or explicit execution gaps; generate file:line findings without exceeding task scope |"
- `resources/WORKFLOW_STEPS.md`: Gate detailed workflow scanners, generated code and campaign setup where reference is read directly.
  - Replaced: "## The 5-Step Workflow"
  - With: "## The 5-Step Workflow\n\nFor IndexedEx, these commands are plans/examples, not automatic execution. Read `../SKILL.md` integration rules first. During analysis, review existing output and document gaps. Tool installation, scans, generated properties and campaigns need a separately scoped request. Use existing production-first Foundry invariants before proposing Echidna/Manticore; CREATE3/registry deployment and build-before-test rules still apply."

The inserted IndexedEx integration section is in `SKILL.md`. Other than the listed adaptations, complete source coverage, notices, assets and templates are retained. The upstream interface YAML is preserved byte-for-byte as inert reference data, not agent configuration; icon paths retain upstream package-root semantics. Source modes are recorded, not an installation/mode-restoration claim.

## Missing tooling and dependencies

- Slither detector/printer utilities, Echidna and Manticore: availability not probed; no installs, scans or fuzz campaigns run.

## License evidence

Manifest owner `building-secure-contracts@trailofbits`: `not-found-at-root-review-redistribution`; recorded license assets: []. No license found at the archived plugin root. Actual attribution/notices and source frontmatter are retained; no MIT terms or other license grant is inferred or added. Redistribution rights remain unresolved. No external license fetch was performed.

## Validation boundary

Read/parse and hash/link checks only. No scripts, hooks, scanners, network, tests or contract operations were executed; no MCP/plugin manifests or agent registrations are staged. Reports and role prose do not authorize production edits or broadcasts.

## Deployment review adjustment

Removed staging-only wording and clarified that existing task authorization covers
routine local analysis/validation. Optional upstream skill pointers are not assumed
installed commands. Final installed hashes are recorded in the deployment ledger.
