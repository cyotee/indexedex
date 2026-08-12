---
last_reviewed: 2026-08-09
git_sha: 4494c30
scope: skills
method: cartographer+survey
---

# Skill Gap Backlog

Ranked skill gaps for IndexedEx agent routing. Stop rule (PRD §0.7.7): no open **P0/P1**, or remaining items **Blocked** with reason; §5 skill-related cold-start probes pass.

## Priority key

| P | Meaning |
|---|--------|
| P0 | Broken/missing deploy or test routing for IndexedEx SUT |
| P1 | Crane capability discovery or DETF/SE/hook package routing gaps |
| P2 | Nice-to-have / cleanup |

## Status summary (2026-08-09)

| Priority | Open | Done / Blocked |
|----------|------|----------------|
| P0 | **0** | Deploy/test routing covered by existing skills + navigation |
| P1 | **0** | Crane morpho/olympus/CREATE3 + IX hook/DETF routing present |
| P2 | 2 | Duplicate skill dirs; optional cartographer skill |

## Closed / satisfied (no implement work)

| ID | Title | Priority | Resolution |
|----|-------|----------|------------|
| G-01 | Vault registry / manager DFPkg deploy path | P0 | `indexedex-testing` + `Claude.md` deploy reminder + `AGENT_NAVIGATION_INDEX` → registry path |
| G-02 | CREATE3 / DFPkg / FactoryService | P0 | `crane-deployment` + `crane-architecture` (SoT `lib/crane/.claude/skills/`) |
| G-03 | Production-first TestBase hierarchy | P0 | `crane-testing` + `indexedex-testing` (`CraneTest` → `IndexedexTest` → package TestBase) |
| G-04 | Morpho port discovery | P1 | `crane-morpho`, `morpho-architecture`, `morpho-blue-operations`, `morpho-vaults` + Crane capability inventory |
| G-05 | Olympus port discovery | P1 | `crane-olympus`, `olympus-architecture`, `olympus-operations` + Crane capability inventory |
| G-06 | Uni V4 hook diamond packages | P1 | `indexedex-uniswap-v4-hook-packages` (IX-local SoT + mirrors) |
| G-07 | DETF adversarial / SE abuse | P1 | `indexedex-adversarial-testing` + `crane-adversarial-testing` |
| G-08 | Bankr skills not installed here | P1 | Documented; parent workspace only (`sync-bankr-skills.sh`). **Not** a gap to fill in-repo |
| G-22 | DeFiHackLabs incident patterns → skills | P1 | `defi-incident-patterns` + Crane catalog A0/L/M/N/O + `indexedex-adversarial-testing` map; plan `docs/agent/DEFI_HACKLABS_SKILLS_IMPLEMENTATION_PLAN.md` |

## Open P2 (non-blocking)

| ID | Title | Priority | Notes |
|----|-------|----------|-------|
| G-20 | Remove accidental `* copy` skill directories | P2 | `.claude/skills/anvil-node copy`, `.claude/skills/balancer-v3-vault copy` — prefer non-copy twins; cleanup when convenient |
| G-21 | Optional `indexedex-cartographer` skill | P2 | Installer + map regen already documented in navigation + `scripts/install-cartographer.sh`; skill optional |

## Blocked (allowed reasons only)

_None._ Bankr/Godot remain **out of scope** (not blocked gaps — do not implement into this repo’s skill trees).

## Skill SoT reminder

- Crane skills → `lib/crane/.claude/skills/<name>/` then `./scripts/sync-crane-skills.sh`
- IndexedEx-only → `.claude/skills/<name>/` then mirror to `.grok/skills/` and `.opencode/skills/`
