# Port provenance: token-integration-analyzer

Staged 2026-10-19 for IndexedEx / OmO Native; not installed.

## Source evidence

- Archive: `/Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json`.
- Source asset: `skill-f5b17dd1ea87356e3fcb74a4043a2aa498c8de691b141a571cd3f6158b1adc56`; tree SHA-256: `f5b17dd1ea87356e3fcb74a4043a2aa498c8de691b141a571cd3f6158b1adc56`.
- Preferred occurrence: `plugin-cache/trailofbits/building-secure-contracts/1.2.2/skills/token-integration-analyzer`.
- Object bytes read from `objects/<sha256>` and checked against every listed source hash.

| Source asset | Source file | Staged file | Source SHA-256 | Staged SHA-256 | Equality/change | Source mode |
|---|---|---|---|---|---|---|
| `skill-f5b17dd1ea87356e3fcb74a4043a2aa498c8de691b141a571cd3f6158b1adc56` | `SKILL.md` | `SKILL.md` | `4b7f5cb3c52f9b45e2216963a49458e1f23f5a279a0296e702fd9d8df268b301` | `fdb5c5bd73a92a699959573d45257151d654ec25dc5eeeb9ff564d3b747de035` | adapted | 420 |
| `skill-f5b17dd1ea87356e3fcb74a4043a2aa498c8de691b141a571cd3f6158b1adc56` | `agents/openai.yaml` | `references/upstream-openai.yaml` | `08d464486ef3598d69d683ec669277da6c839f4804606a2f46c6f31896f5a3a3` | `08d464486ef3598d69d683ec669277da6c839f4804606a2f46c6f31896f5a3a3` | relocated-identical | 420 |
| `skill-f5b17dd1ea87356e3fcb74a4043a2aa498c8de691b141a571cd3f6158b1adc56` | `assets/trail-of-bits-mark.svg` | `assets/trail-of-bits-mark.svg` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | `4bf74c789b38dcf6ad762c136b6832363d27ae19fbaa9a18ec18d66ecce6ca05` | unchanged | 420 |
| `skill-f5b17dd1ea87356e3fcb74a4043a2aa498c8de691b141a571cd3f6158b1adc56` | `resources/ASSESSMENT_CATEGORIES.md` | `resources/ASSESSMENT_CATEGORIES.md` | `bf1313e59c960688cc73bda5b7a98579336a277c521b9b37937aa1cda3a122a7` | `5b01de887dc5cae57fec73e5d686827ec5e9cf69a554c5346580d5a9176ea4c7` | adapted | 420 |
| `skill-f5b17dd1ea87356e3fcb74a4043a2aa498c8de691b141a571cd3f6158b1adc56` | `resources/REPORT_TEMPLATES.md` | `resources/REPORT_TEMPLATES.md` | `77dc2195901cbca8f0a04687e6ac51347520b6320cfe2ca7c39d9725ffae1177` | `081183f2bf35189aab291e06d1bf255266ac8950bce8bf91bc5ee4165d65a834` | adapted | 420 |

## Exact adaptations

- `references/upstream-openai.yaml`: Relocated agents/openai.yaml byte-for-byte outside agent discovery; display metadata only, no registration.
- `SKILL.md`: Shorten selection description to IndexedEx 160-character catalog budget, retaining full body coverage.
  - Replaced: "description: Token integration and implementation analyzer based on Trail of Bits' token integration checklist. Analyzes token implementations for ERC20/ERC721 conformity, checks for 20+ weird token patterns, assesses contract composition and owner privileges, performs on-chain scarcity analysis, and evaluates how protocols handle non-standard tokens. Use when integrating or accepting arbitrary ERC20/ERC721 tokens, auditing a token implementation for standards conformity, or assessing risk from weird tokens such as fee-on-transfer, rebasing, missing return values, or blocklists."
  - With: "description: \"Review token implementations and integrations for ERC conformance, weird-token behavior, privileges, and integration risks.\""
- `SKILL.md`: Insert IndexedEx integration section: project precedence, production-first testing/deployment law, analysis-only default, scoped operations, Native tools and inert metadata.
- `SKILL.md`: Clarify upstream examples are not observed evidence.
  - Replaced: "Reports go only to the user-scoped output path."
  - With: "Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness."
- `SKILL.md`: Place current token law next to pattern analysis and generic mitigations.
  - Replaced: "## Purpose"
  - With: "## IndexedEx token policy\n\nFee-on-transfer and rebasing underlyings are forbidden; detecting them is an incompatibility finding, not a request to support them. Pause/blocklist behavior is accepted but liveness and failure paths still need analysis. Non-18 decimals are allowed; normalize only where pricing adapters require it, and keep DETF/sDETF native 9 decimals. `rebasingClaimToken` is a protocol product, not a permitted rebasing underlying. Do not add a `PkgArgs` allowlist. Generic mitigation examples below are not changes to these rules.\n\n## Purpose"
- `SKILL.md`: An address alone does not authorize RPC queries.
  - Replaced: "If you provide a contract address, I'll query:"
  - With: "Only when the current request explicitly includes read-only network/contract queries, and an address plus endpoint are supplied, assess:"
- `SKILL.md`: Do not turn FoT risk into unsupported compatibility work.
  - Replaced: "**Fix:** Calculate shares from `balanceAfter - balanceBefore`"
  - With: "**IndexedEx recommendation:** Flag the fee-on-transfer underlying as forbidden; do not add support. For other protocols whose policy explicitly supports transfer fees, the generic mitigation is to account from `balanceAfter - balanceBefore`."
- `resources/ASSESSMENT_CATEGORIES.md`: Replace generic allowlist recommendation with IndexedEx policy and retain comparative coverage.
  - Replaced: "**Allowlist Pattern**:\n```solidity\n// Contract-level allowlist\n// Known good tokens\n// UI-level filtering\n```"
  - With: "**Token policy boundary**:\n```solidity\n// IndexedEx: no PkgArgs allowlist; do not introduce one.\n// Fee-on-transfer and rebasing underlyings are forbidden.\n// Pause/blocklist accepted; non-18 decimals allowed under adapter rules.\n// Other protocols may separately use contract/UI allowlists.\n```"
- `resources/ASSESSMENT_CATEGORIES.md`: Gate scarcity analysis.
  - Replaced: "**Note**: I'll only perform on-chain analysis if you provide a contract address. Won't hallucinate if not applicable."
  - With: "**Note**: An address is input, not execution authorization. Only perform on-chain analysis when requested, with a specified address/endpoint and read-only scope; otherwise mark it unverified."
- `resources/ASSESSMENT_CATEGORIES.md`: Gate detailed RPC setup examples.
  - Replaced: "**Note**: I'll only perform on-chain queries if you provide an address and RPC endpoint. Won't hallucinate if not applicable."
  - With: "**Note**: Query only in a task explicitly authorizing read-only network/contract operations with an address and RPC endpoint. This staging review performs none."
- `resources/REPORT_TEMPLATES.md`: Align defensive-pattern report template with repo law.
  - Replaced: "- Fee-on-transfer handling\n- Zero value handling\n- Allowlist implementation"
  - With: "- Forbidden FoT/rebasing underlying findings (do not add support)\n- Zero value handling\n- No PkgArgs allowlist; document actual policy boundaries"
- `resources/REPORT_TEMPLATES.md`: Keep weird-token coverage without requiring banned support.
  - Replaced: "- Fee-on-transfer protected\n- Rebase-safe accounting\n- Blocklist-aware design"
  - With: "- Fee-on-transfer and rebasing underlyings excluded by policy\n- Non-18 decimals handled where pricing adapters require normalization\n- Pause/blocklist accepted, with failure and liveness risks documented"
- `resources/REPORT_TEMPLATES.md`: No generic allowlist roadmap item.
  - Replaced: "- Allowlist implementation\n- Better defensive patterns"
  - With: "- Token-policy documentation without a PkgArgs allowlist\n- Better defensive patterns"

The inserted IndexedEx integration section is in `SKILL.md`. Other than the listed adaptations, complete source coverage, notices, assets and templates are retained. The upstream interface YAML is preserved byte-for-byte as inert reference data, not agent configuration; icon paths retain upstream package-root semantics. Source modes are recorded, not an installation/mode-restoration claim.

## Missing tooling and dependencies

- Slither ERC/printer/property utilities and RPC/indexer clients: availability not probed; no network or contract queries run.
- Historical token names and behaviors are source examples, not verified current chain facts.

## License evidence

Manifest owner `building-secure-contracts@trailofbits`: `not-found-at-root-review-redistribution`; recorded license assets: []. No license found at the archived plugin root. Actual attribution/notices and source frontmatter are retained; no MIT terms or other license grant is inferred or added. Redistribution rights remain unresolved. No external license fetch was performed.

## Validation boundary

Read/parse and hash/link checks only. No scripts, hooks, scanners, network, tests or contract operations were executed; no MCP/plugin manifests or agent registrations are staged. Reports and role prose do not authorize production edits or broadcasts.

## Deployment review adjustment

Removed staging-only wording and clarified that existing task authorization covers
routine local analysis/validation. Optional upstream skill pointers are not assumed
installed commands. Final installed hashes are recorded in the deployment ledger.
