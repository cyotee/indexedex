# IndexedEx project skill deployment - 2026-10-19

## Startup collision correction

The original RPC availability check missed duplicate-resource diagnostics: the
project's two Crane authoring entries shadowed the maintained user-level
`docs-to-skills` and `skill-authoring` packages. The actual terminal reproduced
both collision warnings.

`.omo/settings.json` now excludes only `-skills/docs-to-skills` and
`-skills/skill-authoring` from project discovery. Exact matching uses the
auto-discovery resource root and skill directory. The shared 48-entry catalog,
canonical skill bodies and discovery links remain unchanged for other harnesses.

After correction, the actual terminal reached its prompt without a conflict
banner. RPC verified 46 project entries plus both user-level authoring workflows
from root and `frontend/`, and project isolation still passed. Catalog validation
and all 12 existing tests passed. JSON was parsed and exercised by Native; Biome
was unavailable, so no language-server validation is claimed. Test sessions sent
no model requests and were stopped after observation.

Installed at the owner's request from the preserved `opencode-config` collection.
The complete candidate decisions, source variants, before/after hashes and
verification evidence are in [SKILL_PORTS_2026-10-19.json](SKILL_PORTS_2026-10-19.json).

## Result

- Added **38 complete skill packages** with resources and port provenance.
- Exposed four existing canonical topics: `chainlink-local-testing`,
  `chainlink-vrf-architecture`, `crane-chainlink-local-testing` and
  `crane-chainlink-vrf`; their source bodies were not overwritten.
- Added three compact routers: `evm-development`, `defi-ui-testing`,
  `solidity-security`.
- Extended the existing Balancer V3, Permit2, Foundry and Ethereum routers.
- Preserved all 200 previous topics. The catalog now exposes **242 topics through
  48 discovery entries**, within the unchanged 50-entry/14,000-character limits.
- Maintained new sources under `.claude/skills/`, with complete `.grok/skills/`
  and `.opencode/skills/` mirrors as the repository requires.
- Generated three relative discovery links through the existing synchronizer;
  `.agents/skills/` remains a discovery view, not another editable source tree.

## Selection accounting

Every one of the source catalog's **384 non-retired skill names** has a disposition:

| Disposition | Count |
| --- | ---: |
| Existing canonical target matched the preferred archived tree | 197 |
| Existing canonical variant retained instead of archived replacement | 25 |
| New adapted complete skill package | 38 |
| Existing source newly exposed in the catalog | 2 |
| Explicit target-scope exclusion | 5 |
| Outside this domain-specific deployment | 117 |

The two additional Crane Chainlink companions already existed in this checkout
and were exposed as dependencies, not imported from the archived candidate set.

Bankr/Base-agent catalogs remain in the parent workspace as `CLAUDE.md` requires.
The archived `circom` skill documents deprecated `circom_old`, and its `snarkjs`
companion targets ManaMesh ZK scaffolding; neither belongs to this IndexedEx
deployment. Game engines, unrelated chains, marketing/document tooling, general
agent orchestration and optional runtime integrations were not installed.
Existing shared authoring and frontend guidance remains available.

Protocol reference availability does not approve new release scope. The current
Balancer DETF, Slipstream and legacy Uniswap V4 retirement rules still apply.

## Adaptations and boundaries

New skills honor the current IndexedEx router, product PRDs, registry/CREATE3
deployment, production-first TestBases, artifact-first Foundry execution, token
policy and current frontend layout.

The additions include Foundry transaction checks/scripts, exact token-unit
conversion, ERC20/WETH/Permit2 operations, Balancer operations, DeFi Saver/Fluid
review patterns, Viem, wallet/UI testing knowledge and ten Solidity-oriented
security/review skills. Full supporting reference trees were retained. Separate
security role prose is stored as inert references, not registered agents.

Concrete repairs include stale address handling, missing relative references,
unknown historical skill aliases, floating-point amount conversion and misleading
Viem nonce/fee examples. The large Viem API body is retained on demand behind a
concise entry. Current locked types and deployment artifacts still govern use.

`indexedex-ui-tx-testing/SKILL.md` explicitly says **"No MetaMask automation"**.
MetaMask/Synpress topics are therefore reference-only. Active money-path tests use
the existing real injected-wallet framework; connector stubs do not prove real
contract, signing or wallet-extension behavior. Existing transaction guidance
contains stale `apps/dtf` paths; current `CLAUDE.md` and `frontend/apps/indexedex`
win. The existing policy body was not replaced.

## Discovery repair

The first Native probe found four existing skills missing because their
descriptions contained unquoted YAML mapping separators:

- `indexedex-product-voice`
- `indexedex-testing`
- `indexedex-ui-refactor`
- `indexedex-uniswap-v4-hook-packages`

Their description text and policy bodies were preserved while quoting the YAML.
Legacy mirror continuation text was retained too. Grok aliases share some OpenCode
files, so 12 logical paths correspond to eight physical metadata repairs. One
missing final newline was normalized; no policy content was removed.

The catalog parser now rejects this invalid plain-scalar shape before changing
links. Its new regression test covers both rejected unquoted separators and
accepted quoted values.

## Verification

- Catalog: **48 entries, 242 topics, 5,500 description characters, 10,345 rendered
  characters**. Synchronization is idempotent with zero pending link changes.
- All 516 newly installed package/router files across canonical and mirror roots
  match the reviewed staging contents; existing-router addenda have separate hashes.
- All 232 new operational reference links resolve. All 29 family-router symlinks
  resolve to the correct canonical source, and all 223 grouped-topic links resolve.
- Native RPC discovery found all 48 entries with project scope from both repository
  root and `frontend/`. The three new routers were absent outside IndexedEx.
- Native probes were model-free, offline, and used `--approve` only for that run.
  No persistent/global trust setting was changed.
- All **12 focused catalog tests** passed.
- The source archive validator passed for **603 assets / 1,658 unique blobs**,
  and all **41 source-repository tests** passed.
- `git diff --check` passed.

Basedpyright is not installed, so language-server diagnostics were unavailable.
The focused stdlib tests and actual Native discovery checks were used instead;
no dependency was installed or warning suppressed.

No Solidity build, contract test, live wallet/RPC operation, scanner campaign,
browser/extension launch or dependency installation was run. This is a skill and
discovery change; the catalog's documented validation does not require Forge.
Library examples, scanner templates and historical incident patterns are not
represented as newly executed or newly proven current facts.

## Preservation and maintenance

Original archived objects remain unchanged. Existing canonical variants were
retained; changes to them are limited to additive router links and the documented
metadata repairs. The two pre-existing deleted readiness-cache artifacts were
left alone. No auth, provider, MCP, Foundry, frontend dependency or global skill
configuration was replaced.

Catalog and Trail of Bits plugin-root license notices were not collected in the
source archive. Existing declarations, attribution and resources were retained;
the installation does not invent a new license or redistribution grant.

Edit canonical sources, not discovery symlinks. Resolve a symlink before following
relative links. Register future topics in
[codex-skill-catalog.json](../../scripts/codex-skill-catalog.json), then run the
documented sync/check workflow. New trusted project sessions discover the catalog;
existing sessions need a reload or restart. Grok/OpenCode mirrors contain the same
new package content; only Native discovery was exercised here.
