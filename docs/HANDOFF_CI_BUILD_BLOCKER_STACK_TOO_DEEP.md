# Handoff: CI / default `forge build` blocked by stack-too-deep

**Status:** Open — blocks GitHub Foundry CI hermetic job at **compile** time.  
**Date:** 2026-08-06  
**Repo:** `cyotee/indexedex`  
**Audience:** Next agent fixing green default/CI builds.

Read **AGENTS.md** + Crane skills (`crane-deployment`, `crane-architecture`, `crane-testing`) before changing packages. Prefer production-first fixes; do not mock SUT.

---

## TL;DR

| Item | Detail |
|------|--------|
| **Command that fails** | `forge build` (default profile) and CI job **Build + hermetic tests** → step `forge build` |
| **Hard error** | Solidity **stack too deep** in Uni V4 **SE Orbital Buffer Hook** Target |
| **Not the cause** | Alchemy / secrets / Pages (Pages workflow removed; `ALCHEMY_KEY` works for fork job) |
| **Already fixed (local, may be uncommitted)** | Missing `createPositionWithEffectiveBase` on Composed Stable bond NFT vault (see below) |
| **Goal** | Default `forge build` succeeds so CI can reach **tests**; package suites stay on their dedicated `FOUNDRY_PROFILE`s |

---

## Evidence

### GitHub Actions

- Run: https://github.com/cyotee/indexedex/actions/runs/31115867699  
- Workflow: `.github/workflows/foundry-ci.yml`  
- Hermetic job failed at **`forge build`** (tests skipped).  
- Fork job also failed at compile (same monorepo graph issues / soft-gated).

**First CI failure (now fixed in working tree, verify before push):**

```text
Error (3656): Contract "ComposedStableCommonDetfBondNFTVaultTarget" should be marked as abstract.
Note: Missing implementation:
  IDetfBondInventoryPolicy.createPositionWithEffectiveBase(...)
```

**Current local failure after that fix** (`forge build` / compile of monorepo graph):

```text
Error: Compiler error (... LValue.cpp): Stack too deep.
  Try compiling with `--via-ir` ... or removing local variables.
   --> contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookTarget.sol:740:20:
    |
740 |             _toWad(tokenOut, dOutNative)
    |                    ^^^^^^^^
```

Compiler: Solc **0.8.35**, ~2k files under default profile. Wall time can exceed **15+ minutes** on a full rebuild.

### Profile law (important)

`foundry.toml` **default** profile:

```toml
via_ir = false   # comment: NEVER enable via_ir — use structs to fix stack-too-deep instead
```

Isolated package profiles that **do** allow `via_ir = true` for this product:

| Profile | Path focus |
|---------|------------|
| `se_orbital_buffer_hook` | `contracts/hooks/uniswap/v4/standardExchange/orbital` + matching tests |
| `se_orbital_detf` | Orbital DETF (imports hook → needs via_ir) |

```bash
FOUNDRY_PROFILE=se_orbital_buffer_hook forge test -vv
FOUNDRY_PROFILE=se_orbital_detf forge test -vv
```

Default CI does **not** set those profiles; it runs bare `forge build` then `FOUNDRY_PROFILE=ci forge test`.  
`profile.ci` currently has `inherits = "default"` which **CI Foundry may warn as unknown** — treat as soft; `ci_fork` is an explicit fork of `fork` settings.

---

## What already landed / is in progress

### CI infrastructure (on `main`)

- Workflow: `.github/workflows/foundry-ci.yml` (hermetic + fork).  
- Docs: `docs/ci.md`.  
- Repo secret: `ALCHEMY_KEY` (raw key).  
- GitHub Pages deploy workflow **removed**.  
- Vercel project **indexedex** linked to GitHub with root `frontend/`.

### Composed Stable bond NFT interface gap (fix in working tree)

**Problem:** Shared inventory policy gained `createPositionWithEffectiveBase` for Orbital (principal LP vs reward-weight base). Shared `DETFNFTVaultTarget` implements it; forked **Composed Stable** bond package did not → monorepo compile failed.

**Fix applied locally (uncommitted as of handoff):**

- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol`  
  - `createPosition` → `_createPositionInternal(shares, shares, …)`  
  - `createPositionWithEffectiveBase` → `_createPositionInternal(original, effectiveBase, …)`  
- `…/ComposedStableCommonDetfBondNFTVaultFacet.sol`  
  - `facetFuncs` includes `IDETFNFTVault.createPositionWithEffectiveBase.selector`

**Do not “fix” that by removing the method from `IDetfBondInventoryPolicy`.** Keep shared inventory law; complete implementors.

**Function meaning (for context only):**

- `originalShares` = principal locked (LP/BPT).  
- `effectiveBase` = pre-bonus reward weight (Orbital: rateAsset mid WAD).  
- `createPosition(s)` ≡ `createPositionWithEffectiveBase(s, s, …)`.

Commit this fix with the stack-too-deep work if still uncommitted.

---

## Current blocker (your job)

### Symptom

Default-profile compilation of:

```text
contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookTarget.sol
```

hits **stack too deep** around the exact-out quote path (~line 740), e.g. `Math.sphereExactOutInNetWad(...)` with many locals / nested `_toWad` / SE+RP mapping.

### Why default profile sees this file

Default `src = 'contracts'` compiles the whole tree (or large import graph).  
Orbital SE buffer hook was designed to live under **`FOUNDRY_PROFILE=se_orbital_buffer_hook`** with **`via_ir = true`**.  
It was never meant to be clean under default `via_ir = false`, but CI/`forge build` still try to compile it.

Same class of isolation already used for:

- coordinator / universal router (`via_ir` + narrow `src`/`test`)  
- other large hooks (`se_weighted_buffer_hook`, etc.)

### Constraints (project rules)

1. **Do not** flip default `via_ir = true` globally (“NEVER enable via_ir” on default — fix with structs / smaller functions / isolation).  
2. **Do not** invent mocks of diamond/vault SUT.  
3. Production deploy path remains CREATE3 + registry for vault packages; hook packages follow IndexedEx Uni V4 hook package skill when relevant.  
4. Prefer **behavioral** parity with peers; fresh codepaths should not subclass other family concrete contracts for DETFs (hooks are separate packages).

---

## Acceptable fix strategies (pick smallest that greens default build)

Order is preference, not mandate — choose based on blast radius.

### Strategy A — Isolate from default compile graph (often best for CI)

Keep large orbital SE hook **out of** default `forge build` / hermetic test graph:

- Use Foundry `skip` / path exclusions on **default** (and `ci`) so default does not compile  
  `contracts/hooks/uniswap/v4/standardExchange/orbital/**`  
  (and DETF under `…/vaults/detf/.../orbital/**` if it pulls the hook under default).  
- Keep full suite on `FOUNDRY_PROFILE=se_orbital_buffer_hook` / `se_orbital_detf`.  
- Optionally add CI matrix jobs later for those profiles (not required for first green hermetic).

**Risk:** accidental “green CI” while orbital package is red under its own profile — document that package CI is separate.

### Strategy B — Reduce stack on Target without default via_ir

Refactor `UniswapV4StandardExchangeOrbitalBufferHookTarget` (and helpers) so default codegen succeeds:

- Bundle locals into memory/calldata **structs**.  
- Split exact-out / exact-in / SE invert paths into internal functions with fewer simultaneous stack slots.  
- Avoid deep nested expression trees (`_toWad` args computed into named temps only where needed).  
- Match patterns used elsewhere in Crane/IndexedEx for stack pressure.

**Risk:** large Target edits; must re-run `FOUNDRY_PROFILE=se_orbital_buffer_hook forge test`.

### Strategy C — Hybrid

- Struct/refactor the worst function so isolation is thinner, **or**  
- Isolate only the worst files while keeping smaller orbital pieces under default if needed.

### Rejected / last resort

| Approach | Why avoid |
|----------|-----------|
| Default `via_ir = true` | Explicit project ban; multi-hour / OOM CI risk monorepo-wide |
| Delete orbital package to green CI | Product code; wrong |
| `vm.mockCall` / mock vault to skip compile | Does not fix compile of production sources |
| Moving `createPositionWithEffectiveBase` off shared inventory | Wrong fix for prior error; do not reopen |

---

## Suggested investigation steps

1. Confirm Composed Stable fix is present and committed.  
2. Reproduce:

   ```bash
   forge build -vv
   # or after clean:
   forge clean && forge build
   ```

3. Confirm package profile still works (baseline):

   ```bash
   FOUNDRY_PROFILE=se_orbital_buffer_hook forge build
   FOUNDRY_PROFILE=se_orbital_buffer_hook forge test -vv
   ```

4. Map **who imports** the Orbital SE hook under default test tree:

   ```bash
   rg -n 'UniswapV4StandardExchangeOrbitalBufferHook|standardExchange/orbital' \
     test/foundry/spec contracts --glob '*.sol' | head -80
   ```

5. Choose A vs B from import graph:
   - If only package-local tests need it → **Strategy A**.  
   - If default hermetic tests must import it → **Strategy B** (or move those tests under the package profile + A).

6. After fix:

   ```bash
   forge build
   FOUNDRY_PROFILE=ci forge test -vv   # or at least start; suite is large
   FOUNDRY_PROFILE=se_orbital_buffer_hook forge test -vv
   ```

7. Push and confirm GitHub **Foundry CI** hermetic job passes **Forge build** step.

---

## Key file map

| Path | Role |
|------|------|
| `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookTarget.sol` | Stack-too-deep site (~740) |
| `foundry.toml` | `profile.default` `via_ir=false`; `profile.se_orbital_buffer_hook` / `se_orbital_detf` `via_ir=true` |
| `.github/workflows/foundry-ci.yml` | CI: `forge build` then `FOUNDRY_PROFILE=ci forge test` |
| `docs/ci.md` | CI / secret / profile notes |
| `contracts/vaults/detf/common/inventory/IDetfBondInventoryPolicy.sol` | Shared `createPositionWithEffectiveBase` |
| `contracts/vaults/detf/common/bondNft/DETFNFTVaultTarget.sol` | Shared impl (already correct) |
| `…/stable/common/ComposedStableCommonDetfBondNFTVault{Target,Facet}.sol` | Forked vault — needs effective-base impl (local fix) |

Related skills:

- `.grok/skills/indexedex-uniswap-v4-hook-packages/` (hook DFPkg / factory path)  
- `.grok/skills/crane-testing/`, `indexedex-testing`  
- AGENTS.md DETF + testing sections  

---

## Success criteria

1. **`forge build`** (default profile, no FOUNDRY_PROFILE) exits **0**.  
2. GitHub **Foundry CI** hermetic job gets past **Forge build**; tests may still fail for other reasons — note any new failures separately.  
3. **`FOUNDRY_PROFILE=se_orbital_buffer_hook forge test`** still meaningful (not hollowed out).  
4. Default profile remains **`via_ir = false`**.  
5. Composed Stable `createPositionWithEffectiveBase` implemented and facet selector registered.  
6. No mocks of manager/registry/vault SUT introduced to “pass” CI.  
7. Short note in PR / this file “Resolution” section when done.

---

## Out of scope for this handoff

- Making fork job required / fixing all fork flakes.  
- Full hermetic suite green if failures are test logic (only compile gate is in scope here).  
- Migrating Composed Stable bond package onto shared `DETFNFTVault` (optional later).  
- Vercel / frontend.  
- Re-enabling GitHub Pages.

---

## Resolution (fill when fixed)

- **Date:** 2026-08-06
- **Strategy used (A/B/C):** **B** — structs + helper frames (no `via_ir` anywhere)
- **PR / commit:** product stack packs in `95cc676`; UR/coordinator no-IR follow-up in working tree
- **Commands verified:**
  - `FOUNDRY_PROFILE=se_orbital_buffer_hook|se_orbital_detf|se_weighted_buffer_hook forge build` with `via_ir = false` → **success**
  - `FOUNDRY_PROFILE=universal_router forge build` (`via_ir = false`) → **success** after ChainedActions / V2 / V3 stack frames
  - `FOUNDRY_PROFILE=coordinator forge build` (`via_ir = false`) → **success** after hostile-token test stored reenter calldata as `bytes` (no nested `RouteStep[]` storage copy)
  - All `foundry.toml` profiles set **`via_ir = false`** (project law)
- **Notes / residual risks:**
  - Product stack pressure fixed earlier in Orbital SE hook/DETF + Weighted buffer Targets.
  - Universal Router Crane port diverges from upstream only for stack-safe call frames (see UR `VENDOR.md`).
  - Package profiles remain for **narrow `src`/`test` iteration**, not for viaIR.
  - Full default monorepo `forge build --force` is slow (~2k files); use package builds as fast proof, force-default as CI gate.
