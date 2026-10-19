# Port provenance: differential-review

Staged 2026-10-19 for IndexedEx / OmO Native; not installed.

## Source evidence

- Archive: `/Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json`.
- Source asset: `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8`; tree SHA-256: `64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8`.
- Preferred occurrence: `plugin-cache/trailofbits/differential-review/1.1.4/skills/differential-review`.
- Object bytes read from `objects/<sha256>` and checked against every listed source hash.

| Source asset | Source file | Staged file | Source SHA-256 | Staged SHA-256 | Equality/change | Source mode |
|---|---|---|---|---|---|---|
| `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8` | `SKILL.md` | `SKILL.md` | `f9af6a8193fc1a9f8ca3c54bb8d19095a5f20c9472ca6d014488bbde50b67da0` | `3fae1b051d3e6070791d40103b5ea65ba1b0abe42367628ae464cdba7ea01129` | adapted | 420 |
| `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8` | `adversarial.md` | `adversarial.md` | `3cb823f38c6e551cbcf5f72325d2bb219dacdad774072519c31d50d92db19800` | `3cb823f38c6e551cbcf5f72325d2bb219dacdad774072519c31d50d92db19800` | unchanged | 420 |
| `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8` | `agents/openai.yaml` | `references/upstream-openai.yaml` | `0279d56f88dc1a04d4b1941a25fa7672912a3ceb0557b13c38d069908b30ae61` | `0279d56f88dc1a04d4b1941a25fa7672912a3ceb0557b13c38d069908b30ae61` | relocated-identical | 420 |
| `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8` | `assets/trail-of-bits-mark.svg` | `assets/trail-of-bits-mark.svg` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | unchanged | 420 |
| `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8` | `methodology.md` | `methodology.md` | `16b335d24cf2145e3dc4a37f50056550d29db2efa20e6df78fec95ec1e6fb0b4` | `da6b9af7227c0546414ec73bb002b2314b60d2e5c8323039d55aa6509369ac10` | adapted | 420 |
| `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8` | `patterns.md` | `patterns.md` | `52abb18abbc73502a3d3b2f36a7a035adc1db40fd812d1d5424cf065036a06e9` | `52abb18abbc73502a3d3b2f36a7a035adc1db40fd812d1d5424cf065036a06e9` | unchanged | 420 |
| `skill-64a3b47eabaf7fc2f79c6bdada44e70d6a9b43285f6ea539fae0716d658de6d8` | `reporting.md` | `reporting.md` | `0016876dc6f158e926448bff1b6f634796757c7afe09dff177cfe30250724fc4` | `1474fac6872602e0ca09d76a2ec193c140c00bbebf727a55b21620c974e0d0ea` | adapted | 420 |
| `agent-9ef0b3c8a7096aad6cc61422084d66de13feb29bdbf2148c6fa0a66003a21398` | `adversarial-modeler.md` | `references/adversarial-modeler.md` | `f7be8413601990ceae260f2b1e3557f6d33022e7c4279eaedbed0a7d3bc919e6` | `3cbfb47925ef775620a37ae7c7d967d1c8a5443deb262ed2b53bbf758db0bd5a` | relocated-and-adapted | 420 |

## Exact adaptations

- `references/upstream-openai.yaml`: Relocated agents/openai.yaml byte-for-byte outside agent discovery; display metadata only, no registration.
- `SKILL.md`: Shorten selection description to IndexedEx 160-character catalog budget, retaining full body coverage.
  - Replaced: "description: \"Performs security-focused differential review of code changes. Adapts analysis depth to codebase size, uses git blame for context, calculates blast radius by counting callers, checks test coverage of modified code, and generates a markdown report. Use when reviewing a PR, commit, or diff for security vulnerabilities, checking whether a change re-introduces a previously fixed bug, asking what else a change could break, or finding which modified code has no test covering it.\""
  - With: "description: \"Review diffs for security regressions, changed validation, caller impact, test gaps, and concrete attacker paths.\""
- `SKILL.md`: Insert IndexedEx integration section: project precedence, production-first testing/deployment law, analysis-only default, scoped operations, Native tools and inert metadata.
- `SKILL.md`: Clarify upstream examples are not observed evidence.
  - Replaced: "Reports go only to the user-scoped output path."
  - With: "Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness."
- `SKILL.md`: Replace Claude tool aliases; ignored metadata is not permissions.
  - Replaced: "allowed-tools: Read Write Grep Glob Bash"
  - With: "allowed-tools: read apply_patch grep glob bash"
- `SKILL.md`: Replace undefined plugin agent with retained role instructions.
  - Replaced: "Or delegate to: differential-review:adversarial-modeler agent"
  - With: "Or read the role: references/adversarial-modeler.md"
- `SKILL.md`: Preserve dedicated attacker modeling via explicit Native role prompt, not namespaced plugin dispatch.
  - Replaced: "**`differential-review:adversarial-modeler`** — Models attacker perspectives and\nbuilds exploit scenarios for HIGH RISK code changes. Follows the 5-step\nadversarial methodology (attacker model, attack vectors, exploitability rating,\nexploit scenario, baseline cross-reference) and produces structured vulnerability\nreports. Delegate to this agent when Phase 5 analysis is needed on high-risk\nchanges, passing that full namespaced name as `subagent_type` — a bare\n`adversarial-modeler` is unregistered and the dispatch fails at runtime.\n"
  - With: "Read [adversarial-modeler role](references/adversarial-modeler.md) for Phase 5. Apply it directly, or use Native `task` with an available category such as `deep-low`, `run_in_background: true`, and an explicit prompt containing the role instructions, diff scope, read-only constraints, and requested evidence. Do not pass a plugin role name as `subagent_type`; no agent is registered by this package."
- `SKILL.md`: Remove nonexistent skill-as-CLI invocation.
  - Replaced: "- Command: `issue-writer --input DIFFERENTIAL_REVIEW_REPORT.md --format audit-report`"
  - With: "- Optional external skill, not an executable CLI supplied here; use [reporting.md](reporting.md) directly when unavailable."
- `methodology.md`: Remove shared-checkout mutation and fake audit-context-building CLI; retain baseline analysis.
  - Replaced: "If `audit-context-building` skill is available:\n\n```bash\n# Checkout baseline commit\ngit checkout <baseline_commit>\n\n# Invoke audit-context-building skill on baseline codebase\n# Scope = entire relevant project (e.g., packages/contracts/contracts/ for Solidity, src/ for Rust, etc.)\naudit-context-building --scope [entire project or main contract directory] --focus invariants,trust-boundaries,validation-patterns,call-graphs,state-flows\n\n# Examples:\n# For Solidity: audit-context-building --scope packages/contracts/contracts\n# For Rust: audit-context-building --scope src\n# For full repo: audit-context-building --scope .\n```\n\n"
  - With: "Read baseline files without changing the shared checkout, using read-only Git object inspection (`git show <baseline>:<path>`, `git diff <base>..<head>`) when authorized. Build baseline context manually using the checklist below. If an `audit-context-building` skill is actually discoverable, read it as guidance, not a shell command.\n\n"
- `methodology.md`: No Git checkout side effects.
  - Replaced: "After baseline analysis, checkout back to head commit to analyze changes."
  - With: "Keep the working tree unchanged while comparing baseline and head."
- `methodology.md`: Self-contained deep-context path without undefined CLI.
  - Replaced: "**If `audit-context-building` skill is available**, invoke it to help answer all the questions below for each HIGH RISK changed function:\n\n```bash\n# Run audit-context-building on the changed function and its dependencies\naudit-context-building --scope [file containing changed function] --focus flow-analysis,call-graphs,invariants,root-cause\n```\n\n"
  - With: "For each HIGH RISK changed function, read discoverable `audit-context-building` guidance if present; otherwise perform the following code tracing directly. It is not a bundled executable.\n\n"
- `methodology.md`: Use actual Native reader/search tools.
  - Replaced: "using Read, Grep, and code tracing."
  - With: "using Native `read`, `grep`, LSP references and code tracing."
- `reporting.md`: Remove foreign ~/.claude and Desktop output writes.
  - Replaced: "**Priority order for output:**\n1. Current working directory (if project repo)\n2. User's Desktop\n3. `~/.claude/skills/differential-review/output/`\n\n"
  - With: "Write only to the output path scoped by the user. Do not fall back to Desktop, live skill directories, or other unsolicited locations. If writing is outside scope, return the complete report in the response. Use `apply_patch` for an authorized report file.\n\n"
- `reporting.md`: Retain stakeholder-report capability without undefined command.
  - Replaced: "After generating differential review, transform into audit report:\n\n```bash\nissue-writer --input DIFFERENTIAL_REVIEW_REPORT.md --format audit-report\n```\n\nThis creates polished documentation for non-technical stakeholders.\n"
  - With: "The optional `issue-writer` skill is not bundled or assumed installed. The complete templates above can produce a stakeholder report directly; do not execute `issue-writer` as a shell command."
- `reporting.md`: Keep error recovery within output scope.
  - Replaced: "1. Try Desktop location\n2. Try temp directory\n3. As last resort, output full report to chat\n4. Notify user to save manually"
  - With: "1. Report the write failure and intended user-scoped path\n2. Return the complete report to the user\n3. Do not write to an unrelated fallback location"
- `references/adversarial-modeler.md`: Bring complete separately archived role prose into references, retain frontmatter, replace Claude tools with Native tool names and {baseDir}/skills/differential-review/ paths with ../; mark inert and governed by IndexedEx entry scope. Source asset agent-9ef0b3c8a7096aad6cc61422084d66de13feb29bdbf2148c6fa0a66003a21398.

The inserted IndexedEx integration section is in `SKILL.md`. Other than the listed adaptations, complete source coverage, notices, assets and templates are retained. The upstream interface YAML is preserved byte-for-byte as inert reference data, not agent configuration; icon paths retain upstream package-root semantics. Source modes are recorded, not an installation/mode-restoration claim.

## Missing tooling and dependencies

- audit-context-building and issue-writer are not bundled or assumed installed; inline baseline/deep-context and report templates remain usable.
- Git/gh and analysis tools: availability not probed; no history or network operations run.
- Domain-specific bridge/tick-math/merkle pattern databases and not-so-smart-contracts are external optional resources, not bundled.

## License evidence

Manifest owner `differential-review@trailofbits`: `not-found-at-root-review-redistribution`; recorded license assets: []. No license found at the archived plugin root. Actual attribution/notices and source frontmatter are retained; no MIT terms or other license grant is inferred or added. Redistribution rights remain unresolved. No external license fetch was performed.

## Validation boundary

Read/parse and hash/link checks only. No scripts, hooks, scanners, network, tests or contract operations were executed; no MCP/plugin manifests or agent registrations are staged. Reports and role prose do not authorize production edits or broadcasts.

## Deployment review adjustment

Removed staging-only wording and clarified that existing task authorization covers
routine local analysis/validation. Optional upstream skill pointers are not assumed
installed commands. Final installed hashes are recorded in the deployment ledger.
