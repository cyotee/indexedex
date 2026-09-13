---
last_reviewed: 2026-09-08
scope: skills
method: measured-catalog-and-link-validation
---
# Skill catalog

Codex discovers **45 entries**: 19 core workflow skills and 26 family routers. All **200 existing topics** remain available through the core entries or the routers' direct links. Detailed files, scripts, examples and references stay at their existing source paths.

## Source and scope rules

- Maintain shared Crane guidance under `lib/crane/.claude/skills/`; IndexedEx skills and its family routers under `.claude/skills/`.
- `scripts/codex-skill-catalog.json` records each discoverable source and every retained topic. `.agents/skills/` contains relative discovery links, not editable copies.
- Eleven topics currently exist only under `.opencode/skills/`: seven IndexedEx discovery/user-flow topics and four Playwright topics. Their explicit manifest paths preserve those sources without replacing them with stale or missing copies.
- Read canonical Crane guidance before older mirrors. Use `crane-*` and `indexedex-*` deployment/testing/adversarial rules ahead of generic examples. Approved task PRDs and the root `CLAUDE.md` govern product scope.
- Router links point to existing topic SKILL.md files. Read only the relevant topic and resolve its references from its own directory. A topic name in older instructions can be found in the manifest even if it is no longer a standalone discovery entry.
- React performance and Web Interface Guidelines are discovered once, through `.agents/skills/`. The identical legacy `.codex/skills/` copies are retired.
- Selected `ethskills-*` topics remain installed under `.claude/skills/`, sourced by the existing `scripts/sync-ethskills.sh` workflow, and are reached through `ethereum-reference`.
- Full Bankr/Base-agent catalogs remain in the parent workspace via `scripts/sync-bankr-skills.sh`; do not install them here. Godot/game-engine skills remain outside this repository's scope.
- Protocol availability does not expand a release's scope. This catalog change does not enable Rocket Pool or alter the approved Balancer DETF exclusion or Slipstream deferral.

## Budget and maintenance

The manifest enforces repository limits of **50 entries**, **160 characters per description**, and **14,000 characters** for the rendered catalog. Descriptions should usually be 80–140 characters, with the domain and task first. Preserve existing license, version and policy metadata.

The rendered measurement is one line per entry: `- name: description (file: absolute-discovery-path)`. It includes names, descriptions and paths; it excludes skill bodies and on-demand references. It is a character measurement and a repository policy, not a claim about the client's exact token limit. Global/plugin catalogs add overhead separately.

| Measurement at this checkout | Before | After |
| --- | ---: | ---: |
| Discoverable repository entries | 202, including 2 duplicates | 45 |
| Distinct retained topics | 200 | 200 |
| Description characters | 47,317 | 4,831 |
| Rendered catalog characters | 74,999 | 10,629 |

The rendered catalog is **85.8% smaller**. Existing conversation context still contains the catalog already injected into it; a fresh session can use the compact discovery tree.

When installing a topic, add it to a family in the manifest and link it from that family's SKILL.md. Add a direct entry only for an independently useful workflow that fits the aggregate budget. The sync tool rejects installed but unclassified `.claude/skills/` topics; accidental ` copy` folders remain excluded.

```bash
python3 scripts/sync-codex-skills.py --stats
python3 scripts/sync-codex-skills.py
python3 scripts/sync-codex-skills.py --check
python3 -B -m unittest discover -s scripts -p test_sync_codex_skills.py -v
```

`--stats` reports the planned catalog without changing files. `--check` also validates the actual links and absence of legacy duplicates without writing. Synchronization creates or updates recognized symlinks and retires links for grouped topics; it never deletes the topic sources. Unknown entries, real directories and links outside recognized source locations block synchronization before changes are made.

`sync-crane-skills.sh` still calls the discovery sync after its existing mirror refresh. It does not decide which topics are independently discoverable. Edit maintained sources; do not run a mirror refresh over unrelated unmerged work just to update discovery.

## Direct workflow skills


| Skill | Source |
| --- | --- |
| `crane-adversarial-testing` | [SKILL.md](../../lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md) |
| `crane-architecture` | [SKILL.md](../../lib/crane/.claude/skills/crane-architecture/SKILL.md) |
| `crane-code-style` | [SKILL.md](../../lib/crane/.claude/skills/crane-code-style/SKILL.md) |
| `crane-deployment` | [SKILL.md](../../lib/crane/.claude/skills/crane-deployment/SKILL.md) |
| `crane-natspec` | [SKILL.md](../../lib/crane/.claude/skills/crane-natspec/SKILL.md) |
| `crane-testing` | [SKILL.md](../../lib/crane/.claude/skills/crane-testing/SKILL.md) |
| `defi-incident-patterns` | [SKILL.md](../../.claude/skills/defi-incident-patterns/SKILL.md) |
| `docs-to-skills` | [SKILL.md](../../lib/crane/.claude/skills/docs-to-skills/SKILL.md) |
| `indexedex-adversarial-testing` | [SKILL.md](../../.claude/skills/indexedex-adversarial-testing/SKILL.md) |
| `indexedex-launch-scripts` | [SKILL.md](../../.claude/skills/indexedex-launch-scripts/SKILL.md) |
| `indexedex-product-voice` | [SKILL.md](../../.claude/skills/indexedex-product-voice/SKILL.md) |
| `indexedex-script-orchestration` | [SKILL.md](../../.claude/skills/indexedex-script-orchestration/SKILL.md) |
| `indexedex-testing` | [SKILL.md](../../.claude/skills/indexedex-testing/SKILL.md) |
| `indexedex-ui-refactor` | [SKILL.md](../../.claude/skills/indexedex-ui-refactor/SKILL.md) |
| `indexedex-ui-tx-testing` | [SKILL.md](../../.claude/skills/indexedex-ui-tx-testing/SKILL.md) |
| `indexedex-uniswap-v4-hook-packages` | [SKILL.md](../../.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md) |
| `skill-authoring` | [SKILL.md](../../lib/crane/.claude/skills/skill-authoring/SKILL.md) |
| `vercel-react-best-practices` | [SKILL.md](../../lib/crane/.claude/skills/vercel-react-best-practices/SKILL.md) |
| `web-design-guidelines` | [SKILL.md](../../lib/crane/.claude/skills/web-design-guidelines/SKILL.md) |

## Family routers

| Router | Topic count | Guidance |
| --- | ---: | --- |
| `aave-v3` | 7 | [SKILL.md](../../.claude/skills/aave-v3/SKILL.md) |
| `aave-v4` | 7 | [SKILL.md](../../.claude/skills/aave-v4/SKILL.md) |
| `aerodrome` | 9 | [SKILL.md](../../.claude/skills/aerodrome/SKILL.md) |
| `balancer-v3` | 11 | [SKILL.md](../../.claude/skills/balancer-v3/SKILL.md) |
| `battlechain` | 3 | [SKILL.md](../../.claude/skills/battlechain/SKILL.md) |
| `compound-v3` | 8 | [SKILL.md](../../.claude/skills/compound-v3/SKILL.md) |
| `euler` | 8 | [SKILL.md](../../.claude/skills/euler/SKILL.md) |
| `morpho` | 4 | [SKILL.md](../../.claude/skills/morpho/SKILL.md) |
| `olympus` | 3 | [SKILL.md](../../.claude/skills/olympus/SKILL.md) |
| `permit2` | 10 | [SKILL.md](../../.claude/skills/permit2/SKILL.md) |
| `pons` | 3 | [SKILL.md](../../.claude/skills/pons/SKILL.md) |
| `reliquary` | 2 | [SKILL.md](../../.claude/skills/reliquary/SKILL.md) |
| `resupply` | 8 | [SKILL.md](../../.claude/skills/resupply/SKILL.md) |
| `slipstream` | 8 | [SKILL.md](../../.claude/skills/slipstream/SKILL.md) |
| `uniswap-v3` | 8 | [SKILL.md](../../.claude/skills/uniswap-v3/SKILL.md) |
| `uniswap-v4` | 8 | [SKILL.md](../../.claude/skills/uniswap-v4/SKILL.md) |
| `voltaire-effect` | 12 | [SKILL.md](../../.claude/skills/voltaire-effect/SKILL.md) |
| `wagmi` | 12 | [SKILL.md](../../.claude/skills/wagmi/SKILL.md) |
| `tevm` | 7 | [SKILL.md](../../.claude/skills/tevm/SKILL.md) |
| `playwright` | 4 | [SKILL.md](../../.claude/skills/playwright/SKILL.md) |
| `ethereum-reference` | 17 | [SKILL.md](../../.claude/skills/ethereum-reference/SKILL.md) |
| `crane-libraries` | 3 | [SKILL.md](../../.claude/skills/crane-libraries/SKILL.md) |
| `crane-protocol-ports` | 4 | [SKILL.md](../../.claude/skills/crane-protocol-ports/SKILL.md) |
| `foundry-tools` | 8 | [SKILL.md](../../.claude/skills/foundry-tools/SKILL.md) |
| `indexedex-discovery` | 4 | [SKILL.md](../../.claude/skills/indexedex-discovery/SKILL.md) |
| `indexedex-user-flows` | 3 | [SKILL.md](../../.claude/skills/indexedex-user-flows/SKILL.md) |

The [machine-readable topic map](../../scripts/codex-skill-catalog.json) contains all 200 source paths. Additional uninstalled Crane skills remain in `lib/crane/.claude/skills/`; consult the [Crane capability inventory](../../lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md) when the task needs them.

## Validation evidence

- Catalog validation covers all 200 retained topics, every router link, description/aggregate limits, and duplicate names or canonical sources.
- The 11 isolated Python tests cover migration, idempotence, read-only modes, all budgets, missing links, newly installed topics, duplicate discovery, unexpected files, real directories and paths outside the repository.
- This is a skill/discovery change; it does not require or run Solidity builds, fork checks or deployment scripts.
