# pons skill family — coverage

| Metric | Value |
|--------|-------|
| Docs root | https://docs.ponsfamily.com/ |
| Inventory (in-scope pages) | 3 content URLs + 1 sitemap |
| Fetched OK | 3/3 content |
| Failed | 0 |
| Waived | None |
| Skills emitted | 3 (+ family meta) |
| Pages with no skill mapping | 0 |

## Skills

1. **pons-architecture** — v1/v2 system map, network, contracts, fees, risks  
2. **pons-operations** — end-user and creator workflows  
3. **pons-integration** — onchain indexing, reads, trades, launch APIs  

## Family tree (canonical)

```text
lib/crane/.claude/skills/
├── pons-architecture/
│   ├── SKILL.md
│   └── references/
│       ├── v1-contracts.md
│       ├── v2-contracts.md
│       └── risk-and-governance.md
├── pons-operations/
│   ├── SKILL.md
│   └── references/
│       ├── user-trade-flows.md
│       └── creator-and-fees.md
├── pons-integration/
│   ├── SKILL.md
│   └── references/
│       ├── v1-indexing-and-reads.md
│       └── v2-onchain-api.md
└── pons-family/
    ├── SOURCES.md
    └── COVERAGE.md
```

## Known gaps / doc status

| Topic | Note |
|-------|------|
| v2 mainnet addresses | Explicitly unpublished; skills flag unaudited/undeployed |
| v2 audit reports | In progress; not published |
| Optional HTTP APIs | Listed from llms.txt; schema not fully documented in docs body |
| Numeric price math in JS | Docs use Number ratios; production indexers need bigint fixed-point |

## Smoke prompts

| Skill | Prompt |
|-------|--------|
| architecture | "How does pons v2 differ from v1?" |
| operations | "How do I claim creator fees on pons?" |
| integration | "Index TokenLaunched on Robinhood Chain for pons" |

## Install locations

- **Canonical:** `lib/crane/.claude/skills/pons-*/` and `pons-family/`
- **Synced (IndexedEx):** `.claude/skills/`, `.opencode/skills/`, `.grok/skills/`
- **Synced (Crane mirrors):** `lib/crane/.grok/skills/`, `lib/crane/.opencode/skills/` when present
