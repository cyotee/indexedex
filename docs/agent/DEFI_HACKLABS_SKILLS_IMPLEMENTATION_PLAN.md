# DeFiHackLabs → agent skills — implementation plan

**Status:** IMPLEMENTED (Waves 0–3)  
**Date:** 2026-08-10 (executed 2026-08-10)  
**Inputs:**

- Submodule: [`lib/DeFiHackLabs`](../../lib/DeFiHackLabs) (SunWeb3Sec/DeFiHackLabs, ~852 incidents, Foundry fork POCs)
- Canonical adversarial method: `lib/crane/.claude/skills/crane-adversarial-testing/`
- IndexedEx product adversarial: `.claude/skills/indexedex-adversarial-testing/`
- Skill authoring: `skill-authoring` (progressive disclosure, SoT + mirrors)
- Install law: [`Claude.md`](../../Claude.md), [`docs/agent/SKILL_CATALOG.md`](./SKILL_CATALOG.md)
- Prior vault program: [`docs/testing/ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md`](../testing/ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md)

**Goal:** Turn real historical DeFi incident patterns into **agent skills and catalog extensions** that improve:

1. Secure smart-contract development (checklist + anti-patterns grounded in loss events)
2. Production-first **adversarial** Foundry tests (catalog coverage, ship gates)
3. Discoverability for Claude and Grok agents in this monorepo

**Non-goal:** Teaching agents to run profitable fork exploits as a product DoD. HackLabs POCs prove *attacks worked historically*; IndexedEx/Crane skills prove *attacks fail* (or bounded intentional risk) on **production SUT**.

---

## 1. Success definition

### 1.1 Program done

| Criterion | Evidence |
|-----------|----------|
| New skill installed for Claude + Grok + OpenCode | `.claude/skills/defi-incident-patterns/` SoT; mirrors under `.grok/skills/` and `.opencode/skills/` |
| Crane attack catalog extended (L/M/N/O or approved IDs) | SoT under `lib/crane/.claude/skills/crane-adversarial-testing/`; `./scripts/sync-crane-skills.sh` run |
| IndexedEx adversarial skill maps new IDs to SE/DETF | Updated `indexedex-adversarial-testing` + checklist reference |
| Discovery routing | Rows in `Claude.md` skill table + `SKILL_CATALOG.md`; optional `SKILL_GAP_BACKLOG.md` entry closed |
| Curated incident index | `references/curated-incidents.md` with ≥25 high-signal paths under `lib/DeFiHackLabs/src/test/...` |
| Ship-gate updated | Crane `references/implementation-test-dod.md` mentions new P0 IDs where applicable |
| Agents load skill on trigger prompts | Manual smoke: 3 representative prompts load the new skill (see §8) |

### 1.2 Explicit non-goals

| Out of scope | Why |
|--------------|-----|
| Porting all 844 `*_exp.sol` into IndexedEx `forge test` | Separate Foundry project; archive RPC; wrong pass criteria |
| Green tests that assert attacker profit | Violates adversarial ship gate |
| Expanding MultiVault/SE adversarial **code** suites in this plan | Optional Wave 4 only; skills first |
| Vendoring HackLabs as a compile dependency of IndexedEx | Submodule is **reference-only** |
| Committing Crane changes upstream without a Crane PR | If Crane is a submodule, catalog edits land in Crane SoT then sync |

### 1.3 Non-negotiables (carry into every skill body)

1. **Production-first SUT** — CREATE3 / DFPkg / registry; no mock vault/manager/registry.
2. **Credit only observed deltas** — never absolute `balanceOf` + caller-claimed `amountIn` alone (catalog **I**).
3. **Pass criteria:** exploit blocked **or** intentional economic risk with hard safety invariants.
4. **DETF role names only** on IndexedEx surfaces (`rateAsset`, `pairToken`, …).
5. **HackLabs paths** are citations for root-cause study; hermetic tests remain the bar.
6. **Do not** instruct agents to use HackLabs POCs against live systems or to write offensive tooling for unowned targets.

---

## 2. Architecture of deliverables

```text
lib/DeFiHackLabs/                          # submodule (reference corpus)
    src/test/YYYY-MM/*_exp.sol
    academy/...

lib/crane/.claude/skills/
  crane-adversarial-testing/               # SoT — extend catalog A–K → +L/M/N/O
    SKILL.md
    references/
      attack-catalog-template.md           # extend
      implementation-test-dod.md           # extend
      incident-pattern-bridge.md           # NEW (optional Crane-facing summary)

.claude/skills/                            # IndexedEx SoT for IX-local
  defi-incident-patterns/                  # NEW skill
    SKILL.md
    references/
      curated-incidents.md
      secure-dev-checklist.md
      theme-to-catalog.md
      hermetic-test-templates.md
  indexedex-adversarial-testing/           # PATCH
    SKILL.md
    references/detf-adversarial-checklist.md

.grok/skills/…  .opencode/skills/…         # mirrors of IX-local + synced Crane

Claude.md                                  # skill routing row
docs/agent/SKILL_CATALOG.md
docs/agent/SKILL_GAP_BACKLOG.md            # optional G-xx entry
docs/agent/AGENT_NAVIGATION_INDEX.md       # optional one-liner
```

**Ownership rule**

| Artifact | SoT | Mirror |
|----------|-----|--------|
| Catalog IDs L/M/N/O, generic harness law | Crane `crane-adversarial-testing` | `./scripts/sync-crane-skills.sh` |
| Incident corpus map, HackLabs paths, secure-dev checklist | IndexedEx `defi-incident-patterns` | copy to `.grok` + `.opencode` |
| DETF/SE ID applicability | IndexedEx `indexedex-adversarial-testing` | copy to `.grok` + `.opencode` |

---

## 3. Catalog extension design (Wave 1)

Extend the Crane attack catalog. Keep letter IDs stable; **do not renumber A–K**.

### 3.1 New categories

| Cat | Theme | Source themes in DeFiHackLabs | Typical pass |
|-----|--------|-------------------------------|--------------|
| **L** | AMM reserve / balance desync | skim/sync, FoT surplus, burn-from-pair, pair reserve manip (AIC, RWT, CrowdRing) | Books match balances; no free extract of untracked surplus; FoT does not desync protocol NAV |
| **M** | Middleware / arbitrary call / allowance | Unprotected forwarders, aggregators, trusted swap targets (UnprotectedArbBot, Silo-class, TSAggregator) | No user-supplied `target+calldata` with protocol/user allowances; allowlisted routers only; amountOut measured |
| **N** | Quote–settle TOCTOU | Index Coop ExchangeIssuance, pre-issue hooks, mid-flow unit inflation | Hostile hook/callback between quote and settle cannot inflate credit or drain inventory |
| **O** | Signature / permit failure modes | Lixir permit, ecrecover address(0), replay, broken EIP-712 | Invalid/zero/reused sig reverts; never authorizes address(0) |

### 3.2 Required sub-IDs (minimum ship set)

| ID | Attack | Priority | Notes |
|----|--------|----------|-------|
| **L1** | Untracked balance / public skim-class surplus on protocol-owned or protocol-priced inventory | P0 if product holds AMM LP or prices from pair reserves | |
| **L2** | FoT / deflationary transfer leaves books ≠ balances | **Forbidden** as a product claim (agent law § Token policy). `test_L2_FoT_forbidden` only — never `credits_actualIn` | Aligns with **I4** |
| **L3** | Burn-from-pair or direct pair reserve skew used as mint/burn oracle | P0 when mint/burn uses spot/reserves without TWAP/deadband policy | Overlaps **B**; document boundary in skill |
| **M1** | Public arbitrary `call`/`delegatecall` with held ERC20 allowance | P0 for any router/helper/facet that forwards calldata | |
| **M2** | User-supplied swap target without path/out validation | P0 for issuance/exchange helpers | |
| **M3** | Allowance sweep / transferFrom third party without explicit intent | P0 | |
| **N1** | Mid-tx external valuation/hook changes units between quote and settle | P0 for multi-step issuance/bond paths with callbacks | |
| **N2** | Preview/view path inconsistent with execute path (stale snapshot) | P1 | |
| **O1** | Permit/ecrecover accepts invalid or address(0) signer | P0 if product has permit | |
| **O2** | Signature replay / missing nonce or deadline | P0 if product has permit | |
| **O3** | Permit2 / EIP-712 typed data mismatch (domain, typehash) | P1 | Aligns with **I5** |

### 3.3 Relationship to existing IDs (avoid double-count)

| Existing | When to use vs new |
|----------|--------------------|
| **A** (donation/inflation) | Assets arrive *without* mint path; empty vault / first depositor |
| **I** (trust-flag) | Caller *claims* transfer via `pretransferred` / permit amount |
| **K** (accounting sync) | Stale `lastTotalAssets` / reserve snapshot; next user free credit |
| **L** | *External AMM* or pair-level balance≠reserve; FoT pair surplus; skim |
| **B** | Economic skew of *priced* path (mint/burn seigniorage) |
| **L3 vs B1** | L3 = books/oracle trust of desynced reserves; B1 = intentional skew trade around gates |
| **C** | Reentrancy; still primary for callback reentry |
| **N** | Logic TOCTOU without necessarily reentering the same lock |

Skill bodies must include this mapping table so agents do not invent parallel catalogs.

### 3.4 Empty-vault / residual inventory (A0 alias)

Document as **A0** (or strengthen **A1/A3**) using Thetanuts / Vault4626 class:

| ID | Attack | Pass |
|----|--------|------|
| **A0** | Residual assets with `totalSupply()==0` (or dead shares missing); first minter drains pre-seeded inventory | First mint cannot claim unaccounted inventory; dead shares / virtual offset / init gate |

Wire A0 into Crane template + IndexedEx checklist as **P0** for any vault/SE/DETF that can hold inventory before live shares.

---

## 4. New skill: `defi-incident-patterns`

### 4.1 Metadata

```yaml
---
name: defi-incident-patterns
description: >-
  Maps real DeFiHackLabs incident patterns to Crane/IndexedEx adversarial catalog
  IDs and secure-development checklists. Use when the user asks about "DeFiHackLabs",
  "historical DeFi hacks", "incident-driven security", "what hacks teach us",
  "secure vault checklist", "oracle manipulation patterns", "skim attack",
  "first deposit inflation", "arbitrary call allowance drain", "TOCTOU issuance",
  or wants to improve adversarial tests from past exploits. Do not use as a guide
  to run profitable mainnet exploits; for writing hermetic abuse tests prefer
  crane-adversarial-testing and indexedex-adversarial-testing.
license: MIT
---
```

### 4.2 SKILL.md body (lean, target &lt;200 lines)

Required sections:

1. Purpose + hard boundary (study → defend; not profit PoC as DoD)
2. When to load this skill vs `crane-adversarial-testing` / `indexedex-adversarial-testing`
3. Corpus location: `lib/DeFiHackLabs` (submodule init command)
4. Theme → catalog map (summary table; full in `references/theme-to-catalog.md`)
5. Workflow for agents:
   - Identify surface (vault / AMM / router / signature / diamond)
   - Map to A–O IDs
   - Write hermetic adversarial tests (link Crane DoD)
   - Optional: read curated HackLabs POC for intuition only
6. Navigation table → references
7. See also

### 4.3 References (Wave 2 content)

| File | Content | Est. lines |
|------|---------|------------|
| `references/theme-to-catalog.md` | Full multi-label map: HackLabs themes → A–O; IndexedEx applicability | 120–180 |
| `references/curated-incidents.md` | ≥25 incidents: path, year, root cause one-liner, catalog IDs, IndexedEx relevance (High/Med/Low) | 150–250 |
| `references/secure-dev-checklist.md` | Agent checklist while writing facets/routers/vaults (CEI, delta credit, no arbitrary call, dead shares, allowlists, permit checks) | 100–150 |
| `references/hermetic-test-templates.md` | NatSpec stubs + test name patterns for L/M/N/O/A0 (copy into adversarial suites) | 80–120 |

### 4.4 Curated incident seed set (minimum)

Agents must not dump 852 rows. Seed list (paths relative to `lib/DeFiHackLabs/`):

| Path (approx) | Theme | Catalog |
|---------------|--------|---------|
| `src/test/2026-06/Vault4626_exp.sol` | Wrong assets in totalAssets / redeem | A, K |
| `src/test/2026-04/ThetanutsVaultShareRounding_exp.sol` + `2026-06/Thetanuts_exp.sol` | Empty supply + residual assets | A0 |
| `src/test/2026-07/ExchangeIssuance_exp.sol` | Quote–settle TOCTOU / malicious hook | N1, composition |
| `src/test/2026-08/AIC_exp.sol` | FoT surplus + public skim | L1, L2 |
| `src/test/2026-06/LixirPermitDrain_exp.sol` | Broken permit | O1 |
| `src/test/2026-07/UnprotectedArbBot_exp.sol` | Arbitrary call + allowance | M1, M3 |
| `src/test/2026-06/AmbientCrocSwapDex_exp.sol` | Native surplus accounting | K, L |
| `src/test/2026-07/CrowdRingCircle_exp.sol` / `RWT_exp.sol` | Burn-from-pair / deflationary | L2, L3 |
| `academy/solidity/02_first_deposit/en/readme.md` | Compound first-deposit | A0, A1 |
| `academy/onchain_debug/03_write_your_own_poc/en/` | Oracle manip methodology | B |
| `academy/onchain_debug/06_write_your_own_poc/en/` | Reentrancy classes | C |
| Classic inflation / lending first deposit POCs (grep) | Share inflation | A |
| 2–3 signature/replay classics | Permit/auth | O |
| 2–3 access-control drains | Unprotected admin | F, M |
| Index/issuance + reward self-deal samples | Business logic | N, D, reward |

Expand to ≥25 during Wave 2 with explicit **IndexedEx relevance** column.

---

## 5. Patch existing skills (Wave 1–2)

### 5.1 `crane-adversarial-testing` (Crane SoT)

| Task | Change |
|------|--------|
| Catalog table | Add rows **L, M, N, O** and **A0** |
| Workflow step 2 | “Attack catalog IDs (A–H classic + I + J + K + L/M/N/O)” |
| Directory layout | Optional suite files: `Adversarial_AmmDesync.t.sol`, `Adversarial_Middleware.t.sol`, `Adversarial_Toctou.t.sol`, `Adversarial_Signatures.t.sol` |
| Anti-patterns | Add: “only reading HackLabs without hermetic test”; “fork profit assert as security coverage” |
| See also | Link `defi-incident-patterns` (consumer monorepo skill; note path) |
| `attack-catalog-template.md` | Full ID rows for L/M/N/O/A0 |
| `implementation-test-dod.md` | Ship gate: if surface has AMM pricing / router / permit / multi-step issue → corresponding L/M/N/O P0 |

**Sync:** After Crane SoT edit:

```bash
./scripts/sync-crane-skills.sh
```

If `lib/crane` is a separate git submodule, catalog commits may need a Crane branch/PR before IndexedEx pins the new SHA. Plan assumes Crane skills are editable in-tree; executor documents pin step if not.

### 5.2 `indexedex-adversarial-testing`

| Task | Change |
|------|--------|
| Multi-vault/SE mapping table | Add A0, L*, M* (if any router helpers), N* (bond/issue multi-step), O* (Permit2 paths) |
| P0 extensions section | Parallel to I/J/K: list when L/M/N/O apply to SE vs DETF |
| Porting checklist | Step for incident-pattern pass using `defi-incident-patterns` |
| Deferred NatSpec examples | Include L/M/N/O deferral template |
| `references/detf-adversarial-checklist.md` | New checkboxes |

### 5.3 Router / catalog docs

| File | Change |
|------|--------|
| `Claude.md` | Skill routing row: incident-driven security / HackLabs → `defi-incident-patterns`; adversarial row mention A–O |
| `docs/agent/SKILL_CATALOG.md` | New IndexedEx-local skill entry |
| `docs/agent/SKILL_GAP_BACKLOG.md` | Add G-22 (or next ID) “DeFiHackLabs incident patterns skill” → Done after Wave 3 |
| `docs/agent/AGENT_NAVIGATION_INDEX.md` | One row under testing/security |
| Optional: `docs/agent/INDEXEDEX_AGENT_LAW.md` | One sentence: incident corpus at `lib/DeFiHackLabs`; skills map to catalog (only if law file is the right place — prefer thin cross-link) |

---

## 6. Waves and task breakdown

### Wave 0 — Hygiene & submodule (0.25–0.5 d)

| ID | Task | Output | Done when |
|----|------|--------|-----------|
| W0-1 | Confirm submodule present and documented | `lib/DeFiHackLabs` + `.gitmodules` | Path exists; `git submodule status` shows commit |
| W0-2 | Document init in skill (not necessarily README root) | Submodule command in new skill | Agents can fetch corpus |
| W0-3 | Policy note: reference-only, not forge path | Skill non-goals | No remapping into `foundry.toml` |

**Note:** Committing the submodule to the IndexedEx branch is a **repo ops** step; skill content can land even if submodule commit is already staged.

### Wave 1 — Catalog + Crane skill patch (1–1.5 d)

| ID | Task | Output | Done when |
|----|------|--------|-----------|
| W1-1 | Finalize A0 + L/M/N/O ID definitions in this plan (no renumber fights) | §3 accepted or amended | IDs frozen |
| W1-2 | Update Crane `SKILL.md` catalog + workflow + anti-patterns | Crane SoT | Reviewable diff |
| W1-3 | Update `attack-catalog-template.md` | Full new rows | Agents can copy IDs into plans |
| W1-4 | Update `implementation-test-dod.md` | Ship-gate bullets | DoD mentions L/M/N/O/A0 applicability |
| W1-5 | Optional Crane `references/incident-pattern-bridge.md` | Thin bridge to monorepo skill | Only if Crane skill should not depend on IX paths |
| W1-6 | Run `./scripts/sync-crane-skills.sh` | Mirrors in IX `.claude`/`.grok`/`.opencode` | File trees match SoT |

### Wave 2 — New skill + IndexedEx patch (1.5–2 d)

| ID | Task | Output | Done when |
|----|------|--------|-----------|
| W2-1 | Author `defi-incident-patterns/SKILL.md` | SoT under `.claude/skills/` | Frontmatter triggers pass checklist |
| W2-2 | Author `theme-to-catalog.md` | Reference | All §3 themes mapped |
| W2-3 | Author `curated-incidents.md` (≥25) | Reference | Paths verified on disk |
| W2-4 | Author `secure-dev-checklist.md` | Reference | Checklist actionable for facet/vault/router |
| W2-5 | Author `hermetic-test-templates.md` | Reference | Templates use production-first law |
| W2-6 | Patch `indexedex-adversarial-testing` + DETF checklist | SoT + mirrors | SE/DETF applicability clear |
| W2-7 | Mirror IX-local skill to `.grok/skills` and `.opencode/skills` | `cp -R` or project convention | Trees identical |
| W2-8 | Update `Claude.md`, `SKILL_CATALOG.md`, nav/backlog | Docs | Discovery path complete |

### Wave 3 — Verification & smoke (0.5 d)

| ID | Task | Output | Done when |
|----|------|--------|-----------|
| W3-1 | Description trigger smoke (see §8) | Notes in plan status or PR | 3/3 prompts would load skill |
| W3-2 | Link integrity | All reference paths exist | No broken relative links |
| W3-3 | Conflict check vs existing A–K | Mapping table reviewed | No contradictory pass criteria |
| W3-4 | Mark this plan **IMPLEMENTED (Waves 0–3)** | Status header | Skills live for agents |

### Wave 4 — Optional: test suite follow-through (separate PR stream)

**Not required** for skill program done. Only after Waves 0–3.

| ID | Task | Output | Est. |
|----|------|--------|------|
| W4-1 | Gap matrix: MultiVault / SE / BasicVault vs A0, L, N, O | `docs/testing/...` short report | 0.5 d |
| W4-2 | Add missing P0 hermetic tests for A0 / L2 / O* on gold SE or MultiVault | `adversarial/*.t.sol` | 1–3 d |
| W4-3 | Any production fix if tests expose free-mint / permit bugs | Code PR first | TBD |
| W4-4 | Update `ADVERSARIAL_VAULT_COVERAGE_*` status if suites grow | Docs | 0.25 d |

Wave 4 reuses existing gold harnesses; still **no** mock SUT; still no HackLabs fork as pass criteria.

---

## 7. Secure-development checklist (content outline for Wave 2)

Minimum checklist sections for `secure-dev-checklist.md`:

1. **Accounting** — credit measured delta; update reserve snapshots; empty-supply dead shares / init gates  
2. **Pricing** — no raw spot for high-value mint without policy; deadband / TWAP; do not include foreign tokens in `totalAssets`  
3. **AMM interaction** — understand skim/sync; FoT underlyings; never treat pair balance as free inventory  
4. **External calls** — CEI; reentrancy locks on all value paths; no user `target+data` with allowances  
5. **Allowances** — minimal Permit2 / ERC20 allowance; no open-ended helper approvals  
6. **Signatures** — ecrecover ≠ 0; malleability; nonce; deadline; domain separator  
7. **Diamond surface** — Target ↔ facetFuncs ↔ cuts ↔ proxy (catalog **J**)  
8. **Multi-step flows** — quote/settle atomicity; hostile hooks (catalog **N**)  
9. **Access** — unowned DETF post-deploy; no leftover `initialize`  
10. **Tests** — happy path ≠ adversarial; I1–I3 / A0 / L/M/N/O as applicable  

Each item: **bad pattern → correct pattern → catalog ID → suggested test name**.

---

## 8. Smoke tests (agent discovery)

Without requiring a live multi-agent harness, executor validates:

| # | Prompt (representative) | Expected skill load |
|---|-------------------------|---------------------|
| 1 | “Use DeFiHackLabs patterns to improve our vault adversarial suite” | `defi-incident-patterns` + `crane-adversarial-testing` / `indexedex-adversarial-testing` |
| 2 | “Checklist for secure ERC-4626-like vault development from past hacks” | `defi-incident-patterns` (secure-dev checklist) |
| 3 | “Write a test that donation + empty totalSupply cannot drain residual assets” | `crane-adversarial-testing` A0 + `indexedex-adversarial-testing` if DETF |

Also verify description does **not** steal pure “write reentrancy test” from Crane skill alone (primary remains `crane-adversarial-testing`).

---

## 9. Install commands (executor copy-paste)

### 9.1 Submodule (if missing)

```bash
git submodule add https://github.com/SunWeb3Sec/DeFiHackLabs.git lib/DeFiHackLabs
# or after clone:
git submodule update --init lib/DeFiHackLabs
```

### 9.2 Crane skill sync (after Wave 1)

```bash
./scripts/sync-crane-skills.sh
```

### 9.3 IndexedEx-local skill mirror (after Wave 2)

```bash
ROOT="$(git rev-parse --show-toplevel)"
SKILL=defi-incident-patterns
for dest in .grok/skills .opencode/skills; do
  mkdir -p "$ROOT/$dest"
  rm -rf "$ROOT/$dest/$SKILL"
  cp -R "$ROOT/.claude/skills/$SKILL" "$ROOT/$dest/$SKILL"
done
# Also re-mirror patched indexedex-adversarial-testing
SKILL=indexedex-adversarial-testing
for dest in .grok/skills .opencode/skills; do
  rm -rf "$ROOT/$dest/$SKILL"
  cp -R "$ROOT/.claude/skills/$SKILL" "$ROOT/$dest/$SKILL"
done
```

Optional: add a small `scripts/sync-indexedex-skills.sh` listing IX-local skills (future hygiene; not required if one-off mirror is documented).

---

## 10. PR / commit strategy

| PR | Scope | Notes |
|----|-------|-------|
| **PR-A** | Submodule + this plan (if not already) | Docs + `lib/DeFiHackLabs` only |
| **PR-B** | Crane catalog L/M/N/O/A0 + sync | May be Crane submodule PR + IX pin |
| **PR-C** | `defi-incident-patterns` + IX adversarial patch + Claude/catalog routing | Skills + docs; no production contract changes |
| **PR-D** (optional) | Wave 4 hermetic tests / fixes | Production-first tests only |

Commit messages: complete sentences; no secret material; do not force-push.

---

## 11. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Catalog bloat / agent confusion | Freeze IDs in §3; mapping table vs A–K; progressive disclosure |
| Skills encourage offensive fork tooling | Explicit non-goals; pass criteria = blocked exploit |
| Broken paths when submodule not init | Skill documents `git submodule update --init`; curated paths fail soft with “init submodule” |
| Crane SoT not writable / wrong pin | Document: edit Crane → commit → pin → sync |
| Overlap with generic Crane `security` skill (if present under crane mirrors) | Cross-link; this program owns **incident→catalog→test** bridge; leave generic Solidity checklist to security skill if distinct |
| Maintaining 852 incidents | Curated ≥25 only; no auto-scrape obligation |

---

## 12. Acceptance checklist (executor)

- [x] W0: Submodule path documented; reference-only policy in skill
- [x] W1: Crane catalog A0 + L/M/N/O in SoT + template + DoD; sync run
- [x] W2: `defi-incident-patterns` SoT + 4 references; mirrors for Claude/Grok/OpenCode
- [x] W2: `indexedex-adversarial-testing` updated for new IDs
- [x] W2: `Claude.md` + `SKILL_CATALOG.md` (+ backlog/nav as needed)
- [x] W3: Link integrity + smoke prompts + plan status → **IMPLEMENTED (Waves 0–3)**
- [ ] W4: Explicitly deferred or opened as separate plan/PR

---

## 13. Effort estimate

| Wave | Effort | Cumulative |
|------|--------|------------|
| 0 Hygiene | 0.25–0.5 d | 0.5 d |
| 1 Crane catalog | 1–1.5 d | 2 d |
| 2 New skill + IX patch | 1.5–2 d | 4 d |
| 3 Verify | 0.5 d | **~4.5 d** skills program |
| 4 Optional tests | 1.5–4 d | separate |

---

## 14. Executor start command

> Execute `docs/agent/DEFI_HACKLABS_SKILLS_IMPLEMENTATION_PLAN.md` Waves 0–3: extend Crane adversarial catalog (A0, L/M/N/O), author and mirror `defi-incident-patterns`, patch `indexedex-adversarial-testing`, wire `Claude.md` + `SKILL_CATALOG.md`. Do not implement Wave 4 tests unless asked. Production-first law applies to all test templates. DeFiHackLabs is reference-only.

**Parallelization hints:**

- W1 (Crane) and draft of W2 references can run in parallel after IDs frozen (W1-1).
- W2-7 mirror only after SoT files final.
- W3 last.

---

## 15. Related docs

| Doc | Role |
|-----|------|
| [`docs/testing/ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md`](../testing/ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md) | Prior suite program; Wave 4 may extend |
| [`docs/agent/SKILL_GAP_BACKLOG.md`](./SKILL_GAP_BACKLOG.md) | Close G-xx after skills land |
| [`docs/agent/SKILL_CATALOG.md`](./SKILL_CATALOG.md) | Registry of skills |
| Crane skill `implementation-test-dod.md` | Ship gate for “adversarially tested” |

---

*Plan only — no skill or catalog files are modified by authoring this document alone.*
