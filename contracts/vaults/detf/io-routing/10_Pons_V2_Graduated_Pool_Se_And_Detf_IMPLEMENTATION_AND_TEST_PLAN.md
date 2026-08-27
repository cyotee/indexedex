# Stage 10 — pons v2 graduated V4 pool as Uni V4 SE + DETF bound leg (R20)

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **10** |
| **This file is the sole implementation scope** | New TestBase + specs only. Do not change pons v2 domain. Do not change Uni V4 SE production unless a real incompatibility is proven and the PRD is revised |
| **Depends on** | **07** (unified DETF vs CP). SE-only specs may compile against shipped `UniswapV4StandardExchangeDFPkg` even if 07 is still moving; DETF row waits for 07 |
| **Blocks** | Program complete for R20 |
| **Product law** | PRD **R20**, **§16.11** |
| **Crane fixture** | `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/test/bases/TestBase_PonsFamilyV2.sol` |

**Conforms to product law; no re-litigation.** Production-first: real pons v2 stack + real Uni V4 SE DFPkg. No mock launchpad. No mock SE.

---

## Launch (paste into `/goal`)

```text
/goal Execute contracts/vaults/detf/io-routing/10_Pons_V2_Graduated_Pool_Se_And_Detf_IMPLEMENTATION_AND_TEST_PLAN.md only.

Read that file and PRD §16.11 / R20. Hermetic: TestBase_PonsFamilyV2, launch+graduate a WETH-quoted pons v2 token, wrap the graduated PoolKey with UniswapV4StandardExchangeDFPkg, then bind that SE on the unified CP DETF. Not native ETH quote in v1 of this fixture.

LAW: Claude.md, INDEXEDEX_AGENT_LAW, crane-testing, indexedex-testing.
Seed cache_forge/out if new worktree. Never kill forge. via_ir forbidden. No new DFPkgs. No SUT mocks.

forge test --match-path 'test/foundry/spec/protocols/dexes/uniswap/v4/pons/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**' -vv
```

---

## 1. Goals / non-goals

### Goals

1. Prove Uni V4 SE `exchangeIn` / `exchangeOut` against a **pons v2 graduated** pool (`PonsV2MemeHook`, `fee == 0`).
2. Prove the unified DETF can use that SE as a bound standard exchange (first bond, live mint/burn).
3. Document the two-pool split (pons pool vs DETF buffer hook). Do not conflate hooks.

### Non-goals

- Changing `PonsV2MemeHook` or pons factory.
- Native ETH quote as the bound pool (follow-on if SE native tests exist).
- Fork 4663 (no published v2 addresses).
- TWAP `update` on foreign pons pools (separate oracle PRD).

---

## 2. Files to touch

| File | Action |
|------|--------|
| `contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol` | **Create.** `IndexedexTest` + `TestBase_PonsFamilyV2`. Approve WETH pair. Launch, graduate, `deployVault(PoolKey)`. Shared PoolManager: pons TestBase deploys its own `PoolManager`; IndexedEx Uni V4 SE `PkgInit` is bound to the **IndexedEx** manager’s PoolManager. **If they differ, the SE cannot wrap the pons pool.** Lock: this TestBase must use **one** `PoolManager` for pons graduation and SE `PkgInit`. Prefer: deploy IndexedEx stack, then construct pons v2 against `that` PoolManager/PositionManager/Permit2 (fork helpers from `TestBase_PonsFamilyV2.setUp` rather than inheriting a second manager). |
| `test/foundry/spec/protocols/dexes/uniswap/v4/pons/UniswapV4StandardExchange_PonsV2Pool.t.sol` | SE-only: exchangeIn/Out, preview==execute, meme-hook fees don’t break settlement |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se.t.sol` | DETF: bind that SE on CP hook; first bond; mint launch token or share; burn; R19 dust 0 |

Do not edit files under `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/` except if a **Crane** TestBase helper for “graduate with WETH quote on an injected PoolManager” is missing. Prefer IndexedEx TestBase to inject manager addresses. If Crane `TestBase_PonsFamilyV2` always `new PoolManager`, copy the wiring from it with injected manager (do not vendor a second pons stack).

**PoolManager identity is a ship gate.** Tests that graduate on PoolManager A and deploy SE with PoolManager B are invalid.

---

## 3. Fixture steps (normative)

1. IndexedEx `setUp` (manager, fee oracle, Uni V4 SE DFPkg with **this** `POOL_MANAGER`).
2. Deploy pons v2 stack against the **same** `POOL_MANAGER`, PositionManager, Permit2, WETH.
3. `addLaunchConfig` with hermetic-sized supply/threshold so `readyToGraduate` is reachable.
4. `approvePairToken(WETH)` + `launchToken(..., WETH)`.
5. Buy on the curve until `readyToGraduate`; `createGraduatedPool` if phase is Swept.
6. Assert phase `PoolCreated`. Read `PoolKey` from factory/record (fee 0, hooks = meme hook).
7. `univ4SePkg.deployVault(poolKey)` via manager.
8. Fund testers with WETH + launch token; `exchangeIn` WETH → vault share; `exchangeOut` reverse.
9. DETF: CP buffer hook `standardExchanges` = this vault for the launch-token (or WETH) pair; `PkgArgs.hook` that hook; first bond; mint/burn.

---

## 4. Tests

| # | Test | Expect |
|---|------|--------|
| T10.1 | Same PoolManager for pons and SE | `se.poolManager() == pons factory.poolManager()` |
| T10.2 | Graduated `PoolKey.hooks == memeHook`, `fee == 0` | |
| T10.3 | SE deploy on that key succeeds (registry path) | |
| T10.4 | `previewExchangeIn` == `exchangeIn` (WETH → share) | |
| T10.5 | `previewExchangeOut` == `exchangeOut` | |
| T10.6 | Swap/zap on SE does not revert solely because meme hook takes fee | |
| T10.7 | Locker still holds graduation NFT; SE has its own position id | |
| T10.8 | DETF first bond with this SE live | |
| T10.9 | DETF live mint launch token or share; Gross path still §16.2 | |
| T10.10 | After mint, diamond joinable balances 0 (R19) | |

```bash
forge test --match-path 'test/foundry/spec/protocols/dexes/uniswap/v4/pons/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**' -vv
```

---

## 5. Acceptance

- [x] T10.1–T10.7 green (SE wrap).
- [x] T10.8–T10.10 green (unified `UniswapV4DetfDFPkg` bound to pons Uni V4 SE; Open threshold so mint is reachable).
- [x] No second PoolManager. IndexedEx `poolManager` is injected into the pons v2 stack; `TestBase_PonsFamilyV2.setUp` is not inherited.
- [x] No edits to pons v2 production contracts. Wiring copied from Crane TestBase with injected manager.
