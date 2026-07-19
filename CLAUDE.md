# CLAUDE.md

Read **[AGENTS.md](./Agents.md)** in this repo (same content as `Agents.md` / `AGENTS.md` depending on filesystem case).

## Must internalize for this monorepo

1. **Crane first:** `lib/crane/AGENTS.md` + canonical skills under `lib/crane/.claude/skills/` (`crane-deployment`, `crane-architecture`, `crane-testing`).
2. **IndexedEx deploy:** CREATE3 facets; vault/DETF DFPkgs via **manager vault registry** (never `new` facets/DFPkgs; never mock SUT vaults/manager/registry).
3. **Production-first tests:** real packages + gold TestBases; see `.claude/skills/indexedex-testing/` and AGENTS.md testing sections.
4. **DETF common expectations:** AGENTS.md section **“DETF families — common expectations”** — role names only, immutable unowned instances, inert→live via first bond, synthetic mint/burn gates, vault-share routes, bond NFT + rebasing claim, preview==execution, price-shift under default thresholds, `InvalidRoute` for non-closed-form routes. Do not re-explain or invent alternate product rules; family PRDs under `contracts/vaults/detf/**` override only when explicit.

If `PROGRESS.md` exists, read it for cross-session context before starting work.
