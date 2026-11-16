> **SUPERSEDED** by `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_PRD.md` / `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` (Buffer hook diamond package). Do not implement further under Pricing names.

# Implementation Plan: Move + Rename Single SE Buffer Pricing Hook

**Date:** 2026-08-03  
**Status:** **Ready to execute**  
**Scope:** Mechanical package relocation + product rename + **mandatory** salt/storage identity rewrite. **No behavior changes** to wrap/unwrap/hook permissions.

**Out of scope entirely:** `contracts/hooks/uniswap/v4/standardExchange/dual/**` — do **not** open, edit, move, rename, or “fix” dual. Dual is correctly ordered; leave it alone.

---

## 0. Locked decisions (review 2026-08-03)

| # | Decision | Value |
|---|----------|--------|
| D-L1 | Product / type stem | **`UniswapV4SingleStandardExchangeBufferPricingHook`** (locked) |
| D-L2 | Deploy-test override salt namespace | **`"uv4-single-se-buffer-pricing-hook-test-"`** (replace `"uv4-buffer-pricing-hook-test-"`) |
| D-L3 | PRD / plan history tables | **Anachronistic rewrite + new move row.** In single PRD + single implementation plan: replace old product names/paths/salt/storage strings **everywhere**, including existing changelog / revision rows (do **not** preserve old stems as historical narrative). **Also** append a **new** dated changelog/revision row that records this move/rename (product name, `single/` path, new salt/storage/test-override identity). |
| D-L4 | This move plan | **Lives under `single/`** (this file). Keep after execution as the move/rename record. Target directory `.../standardExchange/single/` **already exists** (holds this plan); executor only adds product files + nested `interfaces/`. |
| D-L5 | Production deploys | **None.** No CREATE3 instances, no address stability requirement. Greenfield identity rewrite is mandatory. |
| D-L6 | Parallel work | **None** when the implementation agent runs. Safe to execute without a worktree hold. |
| D-L7 | Dual package | **Do not touch** `dual/`. Do not update dual PRD/plan cross-refs. Do not run dual-focused greps/tests as acceptance for this task. |
| D-L8 | Dual → single links after move | **Intentionally stale.** Dual PRD currently points at old single package paths/names (e.g. root `UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md`, `UniswapV4BufferAndPricingHookTarget.sol`). After this task those links will 404. **Expected and accepted** until a **separate dual follow-up**. Acceptance does **not** require dual link health. Do **not** “fix” dual to satisfy greps. |
| D-L9 | PRD / plan prose title | Match type stem: human-readable title → **Uniswap V4 Single Standard Exchange Buffer Pricing Hook** (and **Name** header = type `UniswapV4SingleStandardExchangeBufferPricingHook`). Not the shorter “Single SE …” prose form. |
| D-L10 | Path rewrite scope in single docs | **Product package path only.** Rewrite paths that locate **this product’s** PRD, code, tests, FactoryService, or interface to `.../standardExchange/single/...`. Keep bare `.../standardExchange/` when prose means the **family root** that holds both `single/` and `dual/`. Do **not** blind-append `single/` to every occurrence of the parent path. |

### Inventory vs chat

| Item | Fact |
|------|------|
| User-said old name (chat typo) | `UniswapV4BufferAAndPricingHook` |
| **Actual on-disk name** | **`UniswapV4BufferAndPricingHook`** (no extra `A`) |
| Target product name | **`UniswapV4SingleStandardExchangeBufferPricingHook`** |
| Wrong location | `contracts/hooks/uniswap/v4/standardExchange/*` (package root) + `.../interfaces/` |
| Correct location | `contracts/hooks/uniswap/v4/standardExchange/single/` (+ `single/interfaces/`) |
| `single/` today | Contains **this plan only**; product files still at package root |

Target layout (executor does not manage `dual/` contents):

```text
standardExchange/
  dual/          # OUT OF SCOPE — do not touch
  single/        # TARGET for single SE product + this plan
```

---

## 1. Goal

1. Move single-SE hook Solidity + package docs from `standardExchange/` root into `standardExchange/single/`.
2. Rename all product identifiers from `UniswapV4BufferAndPricingHook*` → `UniswapV4SingleStandardExchangeBufferPricingHook*`.
3. Move tests under `test/.../standardExchange/single/` and update imports/names.
4. Update **non-dual** external doc links that point at the old path/name (orbital PRD + morpho research notes).
5. **Mandatory:** rewrite CREATE3 salt namespace + Repo storage id to single-SE-specific strings (§3). Not optional; no legacy-preserve branch.
6. **Mandatory in tests:** override salt string → `"uv4-single-se-buffer-pricing-hook-test-"`.
7. **Mandatory in single PRD + single implementation plan:** rewrite history/changelog so old type names, paths, and salt/storage strings do not remain.
8. Keep this move plan under `single/`.

**Non-goals:** rewrite hook math, change permissions, change SE integration, add missing tests from the old plan (`Interest`, `InitGuards`, fork suites), any work under `dual/`.

---

## 2. Target package tree (after)

```text
contracts/hooks/uniswap/v4/standardExchange/
  dual/                                          # OUT OF SCOPE — leave as-is
  single/
    interfaces/
      IUniswapV4SingleStandardExchangeBufferPricingHook.sol
    UniswapV4SingleStandardExchangeBufferPricingHook.sol
    UniswapV4SingleStandardExchangeBufferPricingHookCommon.sol
    UniswapV4SingleStandardExchangeBufferPricingHookRepo.sol
    UniswapV4SingleStandardExchangeBufferPricingHookTarget.sol
    UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService.sol
    UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md
    UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md
    UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_MOVE_AND_RENAME_PLAN.md  # this file

test/foundry/spec/hooks/uniswap/v4/standardExchange/
  single/
    UniswapV4SingleStandardExchangeBufferPricingHook_Deploy.t.sol
    UniswapV4SingleStandardExchangeBufferPricingHook_Routes.t.sol
```

After move, package root under `standardExchange/` should contain **only** `dual/` and `single/` (no loose single-hook `.sol` or root `interfaces/`). Executor does not inspect or modify `dual/` beyond not deleting the directory.

---

## 3. Rename map (types / files)

| Old (current) | New |
|---------------|-----|
| `IUniswapV4BufferAndPricingHook` | `IUniswapV4SingleStandardExchangeBufferPricingHook` |
| `UniswapV4BufferAndPricingHook` | `UniswapV4SingleStandardExchangeBufferPricingHook` |
| `UniswapV4BufferAndPricingHookCommon` | `UniswapV4SingleStandardExchangeBufferPricingHookCommon` |
| `UniswapV4BufferAndPricingHookRepo` | `UniswapV4SingleStandardExchangeBufferPricingHookRepo` |
| `UniswapV4BufferAndPricingHookTarget` | `UniswapV4SingleStandardExchangeBufferPricingHookTarget` |
| `UniswapV4BufferAndPricingHook_FactoryService` | `UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService` |
| `UniswapV4BufferAndPricingHook_Deploy_Test` | `UniswapV4SingleStandardExchangeBufferPricingHook_Deploy_Test` |
| `UniswapV4BufferAndPricingHook_Routes_Test` | `UniswapV4SingleStandardExchangeBufferPricingHook_Routes_Test` |

### Docs filenames

| Old | New |
|-----|-----|
| `UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md` | `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md` |
| `UNISWAP_V4_BUFFER_AND_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` | `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |
| *(this plan already under `single/`)* | `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_MOVE_AND_RENAME_PLAN.md` |

### Identity strings — **MANDATORY** (not optional)

These are **not** Solidity type names but **must** be updated with the rename (CREATE3 salt + ERC-7201-style storage id + test override). **Do not leave the old strings under `single/` or in single package docs (except this move plan’s “Old” columns).**

| Constant / use site | Current (must remove from product + single docs) | **Required new value** |
|---------------------|--------------------------------------------------|------------------------|
| `DEFAULT_SALT_NAMESPACE` (FactoryService) | `"uv4-buffer-pricing-hook-"` | `"uv4-single-se-buffer-pricing-hook-"` |
| Repo storage id string | `"indexedex.hooks.uv4.buffer.pricing.storage"` | `"indexedex.hooks.uv4.single.se.buffer.pricing.storage"` |
| Deploy test override namespace (`test_HD3_differentNamespace_secondInstance`) | `"uv4-buffer-pricing-hook-test-"` | `"uv4-single-se-buffer-pricing-hook-test-"` |

**Decision lock for executor (mandatory):**

1. **Always** change default salt + storage id in FactoryService + Repo as part of this move/rename.
2. **Always** change the Deploy test override salt to `"uv4-single-se-buffer-pricing-hook-test-"`.
3. Reflect the new values in the single PRD (D1/D2/D21/D32, naming lock, layout tree, salt samples) and single implementation plan tables.
4. **Rewrite history** in single PRD + single implementation plan: changelog / revision rows use the **new** product name, paths, and identity strings — do not leave old names “for history.”
5. Do **not** keep old values “for address stability” — **no deployments exist**; greenfield single-SE identity.
6. **Do not edit `dual/`** for salt/storage or anything else.

---

## 4. Path map (imports)

| Old import / path prefix | New |
|--------------------------|-----|
| `contracts/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook*.sol` | `.../standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook*.sol` |
| `contracts/hooks/uniswap/v4/standardExchange/interfaces/IUniswapV4BufferAndPricingHook.sol` | `.../standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferPricingHook.sol` |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook_*.t.sol` | `.../standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_*.t.sol` |

---

## 5. Full file inventory

**Authoritative list for Phase A:** this section (not the abbreviated shell snippets).

### 5.1 Production Solidity — MOVE + RENAME

| # | Current path | Target path |
|---|--------------|-------------|
| 1 | `contracts/hooks/uniswap/v4/standardExchange/interfaces/IUniswapV4BufferAndPricingHook.sol` | `.../single/interfaces/IUniswapV4SingleStandardExchangeBufferPricingHook.sol` |
| 2 | `.../UniswapV4BufferAndPricingHook.sol` | `.../single/UniswapV4SingleStandardExchangeBufferPricingHook.sol` |
| 3 | `.../UniswapV4BufferAndPricingHookCommon.sol` | `.../single/UniswapV4SingleStandardExchangeBufferPricingHookCommon.sol` |
| 4 | `.../UniswapV4BufferAndPricingHookRepo.sol` | `.../single/UniswapV4SingleStandardExchangeBufferPricingHookRepo.sol` |
| 5 | `.../UniswapV4BufferAndPricingHookTarget.sol` | `.../single/UniswapV4SingleStandardExchangeBufferPricingHookTarget.sol` |
| 6 | `.../UniswapV4BufferAndPricingHook_FactoryService.sol` | `.../single/UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService.sol` |

### 5.2 Package docs — MOVE + RENAME

| # | Current path | Target path |
|---|--------------|-------------|
| 7 | `.../UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md` | `.../single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md` |
| 8 | `.../UNISWAP_V4_BUFFER_AND_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` | `.../single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` |
| 9 | `.../single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_MOVE_AND_RENAME_PLAN.md` | **Already under `single/` — keep; no move required** |

### 5.3 Tests — MOVE + RENAME

| # | Current path | Target path |
|---|--------------|-------------|
| 10 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook_Deploy.t.sol` | `.../standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_Deploy.t.sol` |
| 11 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook_Routes.t.sol` | `.../standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_Routes.t.sol` |

### 5.4 Dual package — OUT OF SCOPE (stale links OK)

| # | Path | Action |
|---|------|--------|
| — | `contracts/hooks/uniswap/v4/standardExchange/dual/**` | **Do not touch.** No moves, renames, greps-as-acceptance, or cross-ref patches. |

**Known dual debt (do not fix here — D-L8):** dual PRD currently references single at the **old** package root, e.g.:

- `contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md`
- `.../UniswapV4BufferAndPricingHookTarget.sol` + Common
- narrative name `UniswapV4BufferAndPricingHook` as the single peer

Those will be wrong after Phase A. **Leave them.** Separate dual follow-up owns retargeting.

### 5.5 External docs — PATH/NAME FIX ONLY (non-dual)

| # | Path | What to update |
|---|------|----------------|
| 12 | `contracts/hooks/uniswap/v4/orbital/UNISWAP_V4_ORBITAL_HOOK_PRD.md` | Single SE **package path** → `.../standardExchange/single/`; PRD filename; FactoryService / product type name |
| 13 | `docs/research/morpho/2026-08-02-morpho-uniswap-strategy-explanations.md` | PRD relative link → `.../standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md` |
| 14 | `docs/research/morpho/2026-08-02-lending-cl-mm-protocol-process-research.md` | Hook PRD path |
| 15 | `docs/research/morpho/2026-08-02-morpho-uniswap-lending-mm-strategies.md` | Hook PRD path |

### 5.6 Not present (do not invent)

- No `TestBase_UniswapV4BufferAndPricingHook` on disk yet (mentioned only in old plans — rewrite those mentions to the new name in single docs only).
- No fork tests under `test/foundry/fork/**` for this hook.
- No frontend / scripts / deploy scripts reference this product (as of inventory grep).
- **No production or staged deployments.**

---

## 6. Per-file internal edits (after move)

For **each** of files 1–6 and 10–11:

1. Update `import {…} from "…"` paths to `.../standardExchange/single/...`.
2. Global replace of type names per §3 rename map (exact symbol replace; longest-first — §9).
3. Update NatSpec `@title` / `@notice` product strings.
4. In FactoryService: `type(UniswapV4SingleStandardExchangeBufferPricingHook).creationCode`.
5. In Repo/FactoryService: **mandatory** identity-string rewrite (§3) — salt namespace + storage id.
6. In Deploy test: override salt → `"uv4-single-se-buffer-pricing-hook-test-"`.
7. In tests: contract names, `@title`, FactoryService library `using` clause, interface casts.

### Intra-package import graph (must remain valid)

```text
IUniswapV4Single…Hook.sol
        ↑
FactoryService ──→ UniswapV4Single…Hook.sol
                          ↓
                    …HookTarget.sol
                          ↓
                    …HookCommon.sol
                          ↓
                    …HookRepo.sol

UniswapV4Single…Hook.sol also imports Repo (ctor sets wrapZeroForOne)
```

### Test import graph

```text
*_Deploy.t.sol / *_Routes.t.sol
  → single/interfaces/IUniswapV4Single…Hook.sol
  → single/UniswapV4Single…Hook_FactoryService.sol
  → existing TestBases (unchanged paths)
```

---

## 7. Doc content checklist (files 7–8, 12–15)

Search/replace across **moved single PRD + single implementation plan + external non-dual docs**:

| Pattern | Replacement |
|---------|-------------|
| `contracts/hooks/uniswap/v4/standardExchange/` as **package path for this product** (PRD path, sol paths, test paths, FactoryService, interface) | `.../standardExchange/single/` (**D-L10** — not when prose means family root `single/`+`dual/`) |
| `UniswapV4BufferAndPricingHook` | `UniswapV4SingleStandardExchangeBufferPricingHook` |
| `IUniswapV4BufferAndPricingHook` | `IUniswapV4SingleStandardExchangeBufferPricingHook` |
| `UniswapV4BufferAndPricingHook_FactoryService` | `UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService` |
| `UNISWAP_V4_BUFFER_AND_PRICING_HOOK_*.md` | new doc filenames |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/UniswapV4Buffer…` | `.../standardExchange/single/UniswapV4Single…` |
| forge match-path examples for single | include `single/` segment (prefer `single/**`) |
| D1 product name / D2 package location | new name + `single/` |
| D21 / D32 salt namespace samples | `"uv4-single-se-buffer-pricing-hook-"` |
| Repo storage id samples | `"indexedex.hooks.uv4.single.se.buffer.pricing.storage"` |
| Layout trees in PRD/plan | match §2 (`single/` + nested `interfaces/`) |
| **Naming lock** / title / **Name** header | type stem + prose title per **D-L9** |
| **Changelog / revision history rows** | **anachronistic rewrite** to new name/paths/identity (**D-L3**) — no leftover old product stem in existing rows |
| **New changelog row** | Append dated row: moved into `single/`, renamed product, new salt/storage/test-override identity (**D-L3**) |

**Also update in single PRD (explicit sections):**

- Title → **Uniswap V4 Single Standard Exchange Buffer Pricing Hook**; **Name** → `UniswapV4SingleStandardExchangeBufferPricingHook` (**D-L9**)
- D1, D2, D20/D21, D32, D73 interface references  
- Architecture diagrams / package tree  
- FactoryService code samples and default-namespace comments  
- Test path trees (`TestBase_*` name → new stem if mentioned)
- Changelog: rewrite historical rows + **append move/rename row** (**D-L3**)

**Do not** open or edit files under `dual/` (**D-L7**, **D-L8**). Dual’s broken single-package links after this move are **expected**.

**This move plan** may retain old names only in “Old / Current” columns of rename maps (required for executors). Product docs under `single/` must not.

---

## 8. Execution steps (ordered)

### Phase A — Move files (git-aware)

§5 is authoritative. From repo root:

```bash
mkdir -p contracts/hooks/uniswap/v4/standardExchange/single/interfaces
mkdir -p test/foundry/spec/hooks/uniswap/v4/standardExchange/single

# Prefer git mv to preserve history — all six Solidity + two package docs + two tests (§5.1–5.3)
# Example (repeat for each row in §5):
git mv contracts/hooks/uniswap/v4/standardExchange/interfaces/IUniswapV4BufferAndPricingHook.sol \
  contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferPricingHook.sol

git mv contracts/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook.sol \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook.sol
# … Common, Repo, Target, FactoryService

git mv contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md \
  contracts/hooks/uniswap/v4/standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md
git mv contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_BUFFER_AND_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md \
  contracts/hooks/uniswap/v4/standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md

git mv test/foundry/spec/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook_Deploy.t.sol \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_Deploy.t.sol
git mv test/foundry/spec/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook_Routes.t.sol \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_Routes.t.sol

# Remove empty root interfaces/ if empty
rmdir contracts/hooks/uniswap/v4/standardExchange/interfaces 2>/dev/null || true
```

If `git mv` rename-in-same-step is awkward: `git mv` into `single/` with **old** basename first, then `git mv` to final basename.

This move plan is already under `single/` — leave it there.

### Phase B — Rewrite identifiers + imports

For each moved Solidity file and test:

1. Fix import paths (`standardExchange/single/...`).
2. Replace type/library/interface names (§3), longest-first (§9).
3. Update NatSpec titles.
4. **Mandatory identity rewrite (§3):**
   - `DEFAULT_SALT_NAMESPACE` → `"uv4-single-se-buffer-pricing-hook-"`
   - Repo storage keccak string → `"indexedex.hooks.uv4.single.se.buffer.pricing.storage"`
   - Deploy test override → `"uv4-single-se-buffer-pricing-hook-test-"`
   - Fail the task if any **old** product salt/storage/test-override string remains under `single/` Solidity or tests.

### Phase C — Docs + cross-refs

1. Rewrite package path / names / salt / storage / **full history tables** inside single PRD + single implementation plan (D-L3).
2. Patch orbital PRD + three morpho research docs (§5.5).
3. **Do not** patch dual docs.
4. Grep again for leftovers (Phase D).

### Phase D — Verification greps (must be clean)

Exclude `lib/`, `dual/`, and this move plan (which documents old names in rename maps):

```bash
# Old product symbols: zero hits outside dual/ and this move plan
rg -n 'UniswapV4BufferAndPricingHook|IUniswapV4BufferAndPricingHook|UNISWAP_V4_BUFFER_AND_PRICING_HOOK' \
  --glob '!lib/**' \
  --glob '!**/standardExchange/dual/**' \
  --glob '!**/*MOVE_AND_RENAME*'

# Old single package root should have no loose product files
rg -n 'standardExchange/UniswapV4Buffer|standardExchange/interfaces/IUniswapV4Buffer' \
  --glob '!lib/**' \
  --glob '!**/standardExchange/dual/**' \
  --glob '!**/*MOVE_AND_RENAME*'

# New names resolve under single/
rg -n 'UniswapV4SingleStandardExchangeBufferPricingHook' \
  contracts/hooks/uniswap/v4/standardExchange/single \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/single

# Mandatory identity strings under single product (not dual, not this plan):
# old must be gone from .sol / tests / PRD / impl plan
rg -n 'uv4-buffer-pricing-hook-|indexedex\.hooks\.uv4\.buffer\.pricing\.storage' \
  contracts/hooks/uniswap/v4/standardExchange/single \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/single \
  --glob '!**/*MOVE_AND_RENAME*' && exit 1 || true

rg -n 'uv4-single-se-buffer-pricing-hook-' \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService.sol
rg -n 'uv4-single-se-buffer-pricing-hook-test-' \
  test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook_Deploy.t.sol
rg -n 'indexedex\.hooks\.uv4\.single\.se\.buffer\.pricing\.storage' \
  contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHookRepo.sol
```

### Phase E — Build + tests

```bash
forge build

forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/single/**' -vv
```

Expected: Deploy + Routes suites green; no missing-import compile errors for the single package.

Optional (not required for acceptance): broader hooks match-path. **Do not** require dual tests.

### Phase F — Cleanup

- Confirm `contracts/hooks/uniswap/v4/standardExchange/` contains only `dual/` and `single/` as directories (no loose single-hook files at root).
- Confirm no empty `interfaces/` at package root.
- Confirm this move plan remains under `single/`.

---

## 9. Suggested mechanical replace order (reduces half-renamed state)

1. **Move** all files to `single/` (even with temporary old basenames if needed).
2. **Rename files** to final basenames.
3. **Rename symbols longest-first** to avoid partial collisions:
   1. `UniswapV4BufferAndPricingHook_FactoryService`
   2. `UniswapV4BufferAndPricingHookTarget`
   3. `UniswapV4BufferAndPricingHookCommon`
   4. `UniswapV4BufferAndPricingHookRepo`
   5. `IUniswapV4BufferAndPricingHook`
   6. `UniswapV4BufferAndPricingHook` (contract)
   7. test contract names `*_Deploy_Test` / `*_Routes_Test`
4. Identity strings (default salt, storage id, test override).
5. Fix any remaining import path strings.
6. Docs last (including **history rewrite**).

---

## 10. Acceptance criteria

| # | Criterion |
|---|-----------|
| A1 | All single-SE hook `.sol` live under `contracts/hooks/uniswap/v4/standardExchange/single/` |
| A2 | Interface under `single/interfaces/` with new name |
| A3 | Zero remaining `UniswapV4BufferAndPricingHook*` / `IUniswapV4BufferAndPricingHook` / `UNISWAP_V4_BUFFER_AND_PRICING_HOOK` outside `lib/`, `dual/`, and this move plan — **including rewritten single PRD/impl-plan history** |
| A4 | **`dual/` untouched** (no intentional edits under that path); dual→single link staleness is **accepted** (**D-L8**) |
| A5 | Tests under `test/.../standardExchange/single/` with new names; imports resolve |
| A6 | Single PRD/plan package path = `.../single/`; product name = `UniswapV4SingleStandardExchangeBufferPricingHook`; prose title per **D-L9** |
| A7 | Orbital + morpho external docs links not 404 (new `single/` paths). **Dual links not in scope.** |
| A8 | `forge build` + single Deploy/Routes tests pass |
| A9 | **Mandatory:** `DEFAULT_SALT_NAMESPACE == "uv4-single-se-buffer-pricing-hook-"`; Repo storage id uses `"indexedex.hooks.uv4.single.se.buffer.pricing.storage"`; Deploy test uses `"uv4-single-se-buffer-pricing-hook-test-"`; **zero** old salt/storage/test-override strings under single product/docs/tests (excluding this move plan) |
| A10 | Single PRD + implementation plan document new salt namespace, storage id, package path, and product name; history tables **anachronistically rewritten** + **new move/rename changelog row** (**D-L3**) |
| A11 | This move plan remains under `single/` |
| A12 | No production deploy migration work (none exist) |

---

## 11. Risk notes

| Risk | Mitigation |
|------|------------|
| Accidental edit under `dual/` | **Hard rule:** do not open/edit `dual/**`. Scope greps exclude dual for leftover-old-name acceptance. |
| Dual PRD links 404 after move | **Expected (D-L8).** Do not fix dual in this task. |
| Changing salt/storage vs any old deploys | **N/A — no deployments.** Still mandatory greenfield rewrite. |
| `rg` hits only in this move plan | Expected for “Old” columns; Phase D excludes `*MOVE_AND_RENAME*` |
| Foundry cache stale after move | `forge clean` if odd import errors |
| Incomplete history rewrite in PRD | Explicit D-L3 + A3/A10: old rows rewritten + new move row |
| Blind `standardExchange/` → `single/` over-replace | **D-L10:** only product package paths; keep family-root wording |

---

## 12. Estimated work

| Phase | Effort |
|-------|--------|
| Move + rename files | ~15–30 min |
| Symbol/import/identity rewrite (6 sol + 2 tests) | ~30–45 min |
| Docs / history rewrite / external cross-refs | ~25–40 min |
| Build + test verify | ~15–30 min |
| **Total** | **~1.5–2.5 hours** mechanical; no design work |

---

## 13. Executor one-liner brief

> Relocate the single SE Uniswap V4 buffer hook from `contracts/hooks/uniswap/v4/standardExchange/` into `.../standardExchange/single/`, rename every `UniswapV4BufferAndPricingHook*` / `IUniswapV4BufferAndPricingHook` symbol and file to `UniswapV4SingleStandardExchangeBufferPricingHook*`, set salt namespace to `"uv4-single-se-buffer-pricing-hook-"`, Repo storage id to `"indexedex.hooks.uv4.single.se.buffer.pricing.storage"`, Deploy test override to `"uv4-single-se-buffer-pricing-hook-test-"`, move the two Foundry specs under `test/.../standardExchange/single/`, rewrite single PRD + implementation plan (including history) and update orbital/morpho links, keep this move plan under `single/`, then `forge build` + run the single Deploy/Routes suites. **Do not touch `dual/`.** No deploy migration. Do not leave old salt/storage/product stems in single product or single docs (except this plan’s rename-map “Old” columns).

---

## Appendix A — Current internal import list (pre-move)

```text
UniswapV4BufferAndPricingHook.sol
  → …/UniswapV4BufferAndPricingHookRepo.sol
  → …/UniswapV4BufferAndPricingHookTarget.sol

UniswapV4BufferAndPricingHookTarget.sol
  → …/UniswapV4BufferAndPricingHookCommon.sol

UniswapV4BufferAndPricingHookCommon.sol
  → …/UniswapV4BufferAndPricingHookRepo.sol

UniswapV4BufferAndPricingHook_FactoryService.sol
  → …/UniswapV4BufferAndPricingHook.sol
  → …/interfaces/IUniswapV4BufferAndPricingHook.sol

*_Deploy.t.sol / *_Routes.t.sol
  → …/interfaces/IUniswapV4BufferAndPricingHook.sol
  → …/UniswapV4BufferAndPricingHook_FactoryService.sol
```

## Appendix B — Grep command for post-merge CI sanity

```bash
! rg -n 'UniswapV4BufferAndPricingHook|IUniswapV4BufferAndPricingHook|UNISWAP_V4_BUFFER_AND_PRICING_HOOK' \
  --glob '!lib/**' \
  --glob '!**/standardExchange/dual/**' \
  --glob '!**/*MOVE_AND_RENAME*' \
  && ! rg -n 'uv4-buffer-pricing-hook-|indexedex\.hooks\.uv4\.buffer\.pricing\.storage' \
       contracts/hooks/uniswap/v4/standardExchange/single \
       test/foundry/spec/hooks/uniswap/v4/standardExchange/single \
       --glob '!**/*MOVE_AND_RENAME*' \
  && echo OK
```

---

## Status note

**Ready to execute** after clarity lock **D-L8–D-L10** (2026-08-03 review). No parallel-agent hold. No production deploys to migrate. Implementation agent: execute only this plan’s scope; leave `dual/` alone (including intentionally stale dual→single links).
