# Agent copy skills (IndexedEx)

## Global (all Claude + Grok sessions)

Installed under `~/.claude/skills/` and `~/.grok/skills/`:

| Skill | Source |
|-------|--------|
| `copywriting` | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) |
| `copy-editing` | same |
| `product-marketing` | same (builds/uses `.agents/product-marketing.md`) |
| `marketing-psychology` | same |
| `cro` | same |
| `docs-as-marketing` | [jonathimer/devmarketing-skills](https://github.com/jonathimer/devmarketing-skills) |
| `technical-tutorials` | same |
| `developer-audience-context` | same |

Refresh agent sessions after install so skill indexes reload.

## Project (this repo — Claude + Grok + OpenCode)

| Path | Skill |
|------|--------|
| `.claude/skills/indexedex-product-voice/` | Product voice law (names, Open/Policy, ban list) |
| `.grok/skills/indexedex-product-voice/` | same |
| `.opencode/skills/indexedex-product-voice/` | same |
| `.agents/product-marketing.md` | Shared product marketing context for marketing skills |
| `docs/marketing/DETF_NARRATIVE_SPINE.md` | Canonical narrative |

**Rule:** On any customer-facing IndexedEx copy task, load **`indexedex-product-voice`** *after* generic copywriting so domain law wins.

**Hierarchy (v2):** Premier = create your own DETFs (many types). Protocol DETF = share of protocol fees — not premier, not a “separate product.” Define DETF = Decentralized ETF early (D is decentralized).
