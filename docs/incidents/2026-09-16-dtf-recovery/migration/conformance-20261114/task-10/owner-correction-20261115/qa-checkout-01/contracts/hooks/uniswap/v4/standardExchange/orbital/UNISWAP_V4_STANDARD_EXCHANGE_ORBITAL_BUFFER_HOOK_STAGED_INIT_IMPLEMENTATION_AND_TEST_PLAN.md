# Implementation & Test Plan: SE Orbital Buffer Hook Staged Init

**PRD:** [`UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_STAGED_INIT_PRD.md)  
**Gold diamond + `deployPair` ABI:** [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) (v0.5)  
**Index:** [`../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md)  
**Date:** 2026-08-17  
**Status:** Draft. **Prerequisite:** Orbital v0.5 ABI amend has landed (`IUniswapV4HookStagedPairInit` exists). One family per worktree.

**Authority:** family PRD wins on product pairs / production cuts / callers. Gold plan wins on diamond algorithms (finalize Remove `SELF`, `postDeploy` `return true`, S58 selectors, S59 event). No `via_ir`. No `new` facets/DFPkg. Default hermetic profile.

---

## 0. Goal

Amend `UniswapV4StandardExchangeOrbitalBufferHookDFPkg` to gold staged shape. Product doors: `deployPair` on `(t0,t1)`, `(t1,t2)`, `(t0,t2)`. Production Adds include deposit / withdraw / SE.

## 1. Locked

Gold I1–I10, I15 with `UniswapV4StandardExchangeOrbitalBufferHook*` names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()` Add order: HOOKS, DEPOSIT, WITHDRAW, SE, ERC20, ERC5267, ERC2612 |
| **F2** | `facetInterfaces()` stay today’s 9 IDs |
| **F3** | Init `facetFuncs()` = gold S58 (6). Thin `IUniswapV4StandardExchangeOrbitalBufferHookInit is IUniswapV4HookStagedPairInit` |
| **F4** | Product pair = any two distinct bound tokens. Same `deployPair` body as gold §4.2 |
| **F5** | Delete `PairPoolLib.ensureThreePairPools`. `postDeploy` `return true` (keep non-pure) |
| **F6** | Do **not** edit `hooks/uniswap/v4/orbital/` |
| **F7** | TestBase helper: three `deployPair` calls + finalize. `_deployBootstrapOnly` for S43 |

## 2. Files

```text
interfaces/IUniswapV4StandardExchangeOrbitalBufferHookInit.sol      # NEW thin alias
UniswapV4StandardExchangeOrbitalBufferHookBeforeInitializeLib.sol  # NEW
UniswapV4StandardExchangeOrbitalBufferHookInitTarget.sol           # NEW
facets/UniswapV4StandardExchangeOrbitalBufferHookInitFacet.sol     # NEW
UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol                # is InitFacet
UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol          # delete ensureThree
UniswapV4StandardExchangeOrbitalBufferHookRepo.sol                 # + flag at end
UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol          # beforeInitialize → lib
TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol
interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol         # UNCHANGED
interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol   # + productionFacetCuts()
test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/
  *_StagedInit.t.sol                                               # NEW
  existing Factory / Adversarial / Reentrancy / product specs      # grep-fix
```

## 3. Phases

**A+B+C one compile** (do not leave a half-cut package): Repo flag, Init files, DFPkg inherit, bootstrap `facetCuts` (3), `productionFacetCuts` (7), finalize body, `postDeploy` no-op, hooks `beforeInitialize` → lib.  
**D:** TestBase helper + grep.  
**E:** StagedInit + Factory F2 rewrite + J-surface.  
**F:** Patch this family’s product PRD/impl plan if they still claim same-tx three inits.

## 4. Tests

Gold §7 names, this path. Package decl: `facetCuts.length == 3`, `productionFacetCuts.length == 7`, `facetFuncs` == S58. S43 bootstrap. `deployPair` emit / skip / reverse-args same door. Finalize 0 and 2 doors revert. After finalize: `deployPair` unmatched; `beforeInitialize` on HOOKS_FACET; deposit on DEPOSIT_FACET. Existing product specs via S42.

## 5. Anti-patterns / DoD

Gold §8–§9. Extra: do not cut SE/deposit onto bootstrap; do not touch raw Orbital.
