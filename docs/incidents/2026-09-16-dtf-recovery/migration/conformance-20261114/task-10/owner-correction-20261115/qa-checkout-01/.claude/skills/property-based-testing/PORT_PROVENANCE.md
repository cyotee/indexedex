# Port provenance: property-based-testing

Staged 2026-10-19 for IndexedEx / OmO Native; not installed.

## Source evidence

- Archive: `/Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json`.
- Source asset: `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0`; tree SHA-256: `aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0`.
- Preferred occurrence: `plugin-cache/trailofbits/property-based-testing/1.2.2/skills/property-based-testing`.
- Object bytes read from `objects/<sha256>` and checked against every listed source hash.

| Source asset | Source file | Staged file | Source SHA-256 | Staged SHA-256 | Equality/change | Source mode |
|---|---|---|---|---|---|---|
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `README.md` | `README.md` | `ffbe30eec09cc64fb1eae836b07ca1d82939bda3f1e6f0dceadcdd78793a3112` | `75081f9b25b1a971a26b9fc3f391749f3e4614871c88cdbef875e8f456aad1b1` | adapted | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `SKILL.md` | `SKILL.md` | `9448cacb65c6237a7c22dc59602667177ecae405524079ae9ff92240590b995a` | `183cd4c0d794a59a9384ed9277a7af11952617f2f209fe5cc08eb6975dca9101` | adapted | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `agents/openai.yaml` | `references/upstream-openai.yaml` | `51d635deefa254d8cdf6dc56450851b6ec9545cd37f88a4eb4035cf3f2262fff` | `51d635deefa254d8cdf6dc56450851b6ec9545cd37f88a4eb4035cf3f2262fff` | relocated-identical | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `assets/trail-of-bits-mark.svg` | `assets/trail-of-bits-mark.svg` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | unchanged | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `references/generating.md` | `references/generating.md` | `c0e72dfc89babe3c32de718b81b94044362c85e776d7475e950dfeaab78bb58e` | `c0e72dfc89babe3c32de718b81b94044362c85e776d7475e950dfeaab78bb58e` | unchanged | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `references/interpreting-failures.md` | `references/interpreting-failures.md` | `dbae7db8773712ba03268a3d56ea5aa6720af0650a5189580bfd88aa2edc3f9a` | `dbae7db8773712ba03268a3d56ea5aa6720af0650a5189580bfd88aa2edc3f9a` | unchanged | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `references/libraries.md` | `references/libraries.md` | `f7218acf8e668130ef3048983472579d04e12030c5401926f666363e5f69c686` | `083e9af648cc695ae3e6909d80ddd1a7433a65a89852a9c871e83a66c561cf8a` | adapted | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `references/refactoring.md` | `references/refactoring.md` | `6eb5c206f575704791f089608bb06e41d6eed91b9d3c7fb27912f969aed07a18` | `e3c8f4060532b173318921d70c8e54cf3bfd55f3456619b498b8980169bd3c31` | adapted | 420 |
| `skill-aefa724c7f0e553370e06e18176c29c0434a4abfd5c426661a94ca1c74aa87f0` | `references/reviewing.md` | `references/reviewing.md` | `110b08118a1e7b1a2566def6e9d2a0bf43fc2deefce857d2ce3b4382b07bc774` | `110b08118a1e7b1a2566def6e9d2a0bf43fc2deefce857d2ce3b4382b07bc774` | unchanged | 420 |

## Exact adaptations

- `references/upstream-openai.yaml`: Relocated agents/openai.yaml byte-for-byte outside agent discovery; display metadata only, no registration.
- `SKILL.md`: Shorten selection description to IndexedEx 160-character catalog budget, retaining full body coverage.
  - Replaced: "description: \"Writes, reviews, and debugs property-based tests — Hypothesis, fast-check, proptest, jqwik, rapid, and Echidna or Medusa for Solidity invariants. Use whenever tests should cover a whole input domain instead of a hand-picked list of examples: encode/decode and serialize/deserialize pairs, parsers, canonicalizers and normalizers, validators, numeric and Decimal types, comparators and sort order, data structures, and smart-contract state invariants. Also use when adding cases to an existing @given, fast-check, or proptest suite, when judging whether existing property tests assert anything real, and when a generator has shrunk a counterexample and you need to tell a wrong property from a genuine bug. Not for coverage-guided binary fuzzing (libFuzzer, AFL), mutation-testing campaigns, static analysis, benchmarking, or end-to-end UI tests.\""
  - With: "description: \"Write, review, and debug property-based tests and Solidity invariants; identify vacuity, tautologies, and shrunk counterexamples.\""
- `SKILL.md`: Insert IndexedEx integration section: project precedence, production-first testing/deployment law, analysis-only default, scoped operations, Native tools and inert metadata.
- `SKILL.md`: Clarify upstream examples are not observed evidence.
  - Replaced: "Reports go only to the user-scoped output path."
  - With: "Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness."
- `references/libraries.md`: Avoid overriding existing IndexedEx Foundry infrastructure with upstream default.
  - Replaced: "- **Echidna** — property fuzzer, mature, the default choice."
  - With: "- **Echidna** — upstream property-fuzzer option. For IndexedEx, use existing production-first Foundry fuzz/invariant infrastructure by default; adding Echidna requires a separate tooling decision."
- `references/refactoring.md`: Constrain generic mocking example by current production-first testing law.
  - Replaced: "`process_order` keeps example tests with a mocked `db`, which is the right\ntool for a two-line wrapper."
  - With: "This generic example may use a mocked external database outside IndexedEx. In IndexedEx, keep tests production-first and never mock the SUT; exercise real vault, DETF, manager, registry, fee-oracle, facet and DFPkg paths through canonical TestBases."
- `references/refactoring.md`: Prevent generic delivery mocking from expanding to IndexedEx SUT.
  - Replaced: "Construction is testable; delivery is\nmocked."
  - With: "Construction is testable; delivery isolation must respect the project testing law and cannot replace the IndexedEx SUT with mocks."
- `README.md`: Clearly identify unavailable evaluation harness and effort semantics as historical, not runnable dependencies.
  - Replaced: "**Every command below runs from the plugin root** (`plugins/property-based-testing/`)."
  - With: "**Historical upstream evaluation notes only.** Commands below require the original plugin-root eval scripts/fixtures/Makefile, which are not in the archive skill tree or this staged package. They are not installation, validation or runtime instructions for IndexedEx / Native; do not execute them from staging. The upstream `effort: low` field is retained as metadata, not a verified Native setting."

The inserted IndexedEx integration section is in `SKILL.md`. Other than the listed adaptations, complete source coverage, notices, assets and templates are retained. The upstream interface YAML is preserved byte-for-byte as inert reference data, not agent configuration; icon paths retain upstream package-root semantics. Source modes are recorded, not an installation/mode-restoration claim.

## Missing tooling and dependencies

- Hypothesis, fast-check, proptest, jqwik, rapid, Echidna and Medusa: availability not probed; prefer existing Foundry invariants for IndexedEx.
- Upstream README describes unarchived plugin-root evals-extra scripts, fixtures and Makefile. These are historical evaluation evidence, not runtime dependencies or runnable staged checks.
- effort: low is retained upstream metadata; no Native effort override behavior is asserted.

## License evidence

Manifest owner `property-based-testing@trailofbits`: `not-found-at-root-review-redistribution`; recorded license assets: []. No license found at the archived plugin root. Actual attribution/notices and source frontmatter are retained; no MIT terms or other license grant is inferred or added. Redistribution rights remain unresolved. No external license fetch was performed.

## Validation boundary

Read/parse and hash/link checks only. No scripts, hooks, scanners, network, tests or contract operations were executed; no MCP/plugin manifests or agent registrations are staged. Reports and role prose do not authorize production edits or broadcasts.

## Deployment review adjustment

Removed staging-only wording and clarified that existing task authorization covers
routine local analysis/validation. Optional upstream skill pointers are not assumed
installed commands. Final installed hashes are recorded in the deployment ledger.
