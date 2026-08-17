# PRD: Uni V4 SE DETF `deployVault` mineNonce (out of PkgArgs)

**Status:** Accepted v0.2 — product law locked. Implementor and plan agents make **no** product or layout choices.  
**Date:** 2026-08-16  
**Scope:** All four Uni V4 Standard Exchange DETF families (CP Single, Orbital, Weighted, Curve Quad).  
**Follow-on:** Implementation / test plan is co-located (file map, phases, DoD only). This PRD is product law.

| Doc | Role |
|-----|------|
| **This file** | Product law for DETF deploy encoding, salt, premine, and caller updates |
| Co-located family `*_PRD.md` (four families) | Still SoT for family PkgArgs **except** `hookMineNonce` / auto-mine — **this file supersedes those clauses** |
| [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](../../../../../../../../docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) D38 | **Superseded** on `hookMineNonce = 0` (auto-mine). All other D38 fields unchanged |
| [`docs/ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../../../../../../docs/ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md) | **Superseded** on `hookMineNonce = 0` / auto-mine sentences |
| Hook factory PRD | Unchanged. Hook DFPkgs keep `deployVault(hookArgs, uint256)` **and** `deployVaultAutoMine` |
| Implementation plan | [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_IMPLEMENTATION_AND_TEST_PLAN.md) — phases, file map, `forge test --match-path` set, commit slices |

**Authority:** If this PRD and a family PRD / 46630 demo PRD / fee-DETF launch plan disagree on mine nonce or DETF `deployVault` arity, **this PRD wins**. The plan agent must patch those docs to match. Do not leave the old `0 → auto-mine` text in place.

---

## 0. One-line goal

Remove `hookMineNonce` from all four Uni V4 SE DETF `PkgArgs`. Typed deploy is `deployVault(PkgArgs args, uint256 mineNonce)` on each `I*DETDFPkg`. Registry bytes are `abi.encode(args, mineNonce)`. `calcSalt` hashes **only** `PkgArgs`. DETF packages **never** auto-mine. Callers (TestBases, tests, Foundry scripts) **premine** the hook nonce off-chain via `UniswapV4DetfHookPremineLib`, then pass it in.

---

## 1. Why

`PkgArgs.hookMineNonce == 0` meant “auto-mine the reserve hook on-chain” (up to `MAX_LOOP = 160_444` CREATE2 hashes inside `deployVault`). That is not feasible in a broadcast / `eth_estimateGas` on a fork. It also made `0` both a valid CREATE2 nonce and a sentinel.

`calcSalt` that includes the nonce made the DETF CREATE2 address depend on the nonce, so you could not predict the DETF, premine the hook (salt includes `rawToken = DETF`), and then write the nonce back.

The nonce is deploy mechanics, not instance identity. It does not belong in `PkgArgs`.

---

## 2. Locked decisions

| # | Decision | Status |
|---|----------|--------|
| N1 | **Four families only:** CP Single, Orbital, Weighted, Curve Quad Uni V4 SE DETF packages + their `I*DETDFPkg` interfaces + gold TestBases + every in-repo caller. | **Locked** |
| N2 | **Delete** `uint256 hookMineNonce` from all four `PkgArgs` structs. Do not replace it with another field. | **Locked** |
| N3 | Typed surface on each of the four **`I*DETDFPkg`** interfaces (same four files as today; PkgArgs stay on `I*DETDFPkg`): `function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);`. **Do not** add `deployVault` to the instance `I*DETF` interfaces. | **Locked** |
| N4 | **`uint256 mineNonce`**, not `uint8`. Same width as hook factory / hook DFPkg `deployVault`. | **Locked** |
| N5 | **Delete** the one-arg `deployVault(PkgArgs)` on those four `I*DETDFPkg` interfaces and implementations. No overload. No leftover auto-mine helper on the DETF package (`deployVaultAutoMine` must **not** exist on DETF packages). | **Locked** |
| N6 | Implementation of DETF `deployVault`: `return VAULT_REGISTRY_DEPLOYMENT.deployVault(IStandardVaultPkg(address(this)), abi.encode(args, mineNonce));` — encode **exactly** `(PkgArgs, uint256)` in that order. | **Locked** |
| N7 | `IVaultRegistryDeployment.deployVault(pkg, bytes)` and the vault diamond factory are **unchanged**. The `bytes` payload for these four packages **must** be `abi.encode(PkgArgs, uint256)`. | **Locked** |
| N8 | `calcSalt(bytes memory pkgArgs)` on all four DETF packages: `abi.decode(pkgArgs, (PkgArgs, uint256))`, then `return keccak256(abi.encode(argsOnly));` — **never** hash `mineNonce`. Do **not** zero a nonce field (the field is gone). Crane `diamondPackageFactory.calcAddress` calls `pkg.calcSalt(pkgArgs)` only — it does **not** call `processArgs`. Dummy `uint256(0)` in the blob is therefore legal for prediction. | **Locked** |
| N9 | `processArgs`: keep `msg.sender == VAULT_REGISTRY_DEPLOYMENT` (`NotCalledByRegistry`); `abi.decode(pkgArgs, (PkgArgs, uint256))` (discard the decoded values); **return the original `pkgArgs` bytes**. Do **not** re-encode. Do **not** validate PkgArgs fields here (that stays in `initAccount`). Do **not** validate the nonce. A payload that is only `abi.encode(PkgArgs)` **reverts** on decode with the compiler’s ABI-decode revert. **Do not** add a custom decode error. | **Locked** |
| N10 | `initAccount`: `abi.decode(initArgs, (PkgArgs, uint256))`; existing PkgArgs checks **stay in `initAccount`** and stay unchanged except they no longer read `args.hookMineNonce`; store the decoded extra argument on **`DeployConfig.hookMineNonce`**. **Do not** rename that storage field. It is **not** a PkgArgs field. | **Locked** |
| N11 | `_deployReserveHook`: **only** `HOOK_PKG.deployVault(hArgs, cfg.hookMineNonce)`. **Delete** `if (nonce == 0) HOOK_PKG.deployVaultAutoMine(...)`. Pass `0` through if the caller premined `0` (valid CREATE2 match). Hook factory `deployWithMineNonce` already reverts `InvalidHookFlags` on a bad nonce. | **Locked** |
| N12 | DETF packages **do not** expose `deployVaultAutoMine`. Hook DFPkgs **keep** their own `deployVaultAutoMine` (out of scope). | **Locked** |
| N13 | Predict DETF **before** mining: `diamondPackageFactory.calcAddress(IDiamondFactoryPackage(detfPkg), abi.encode(args, uint256(0)))`. Dummy `0` is not in the salt (N8), so the address equals `calcAddress(..., abi.encode(args, anyNonce))`. | **Locked** |
| N14 | Premine algorithm is **normative** (§4). Tests and scripts **must** use `UniswapV4DetfHookPremineLib` (§4.2). Do **not** call hook `FactoryService.findMineNonce` for this path (it `processArgs`es the hook and reads `decimals()` on the not-yet-deployed DETF). | **Locked** |
| N15 | Gold TestBase `_deployDetfInstance(args)` (all four families) **must** call the matching `UniswapV4DetfHookPremineLib.premine*` then `I*DETDFPkg(detfPkg).deployVault(args, nonce)`, then `require(detf == predictedDetf)`. Still `vm.startPrank(owner)` / `stopPrank` around `deployVault` as today. Stop calling `indexedexManager.deployVault`. | **Locked** |
| N16 | In-repo Foundry scripts that deploy these DETFs **must** compile and use `I*DETDFPkg.deployVault(args, nonce)` after §4 premine (§6). | **Locked** |
| N17 | Family PRDs + 46630 demo PRD D38 + fee-DETF launch plan + 46630 script README **must** be patched in the same change set so they no longer say `hookMineNonce = 0` / auto-mine (§7). | **Locked** |
| N18 | No `via_ir`. No `new` facets/DFPkgs. DETF role names only. Production-first tests: no mocks of SUT. | **Locked** |
| N19 | **Canonical in-repo caller:** `I*DETDFPkg.deployVault(args, nonce)` only. `indexedexManager.deployVault(pkg, abi.encode(args, nonce))` is allowed **only** in the one shared unit that proves the registry bytes path. The same shared unit owns the negative `manager.deployVault(pkg, abi.encode(args))` (no nonce) revert. No other manager.encode call sites for these four packages. | **Locked** |
| N20 | Shared premine library: **one** file at the path in §4.2. **Delete** `scripts/foundry/anvil_robinhood_testnet/HookPremineLib.sol`. Scripts import the shared library. Helper functions are `internal view`, **no** `console2`. Return `(address predictedDetf, uint256 mineNonce)`. **Delete** `takePrepared` / `hookNoncePrepared` / `pendingHookMineNonce` LaunchState machinery. | **Locked** |
| N21 | New calcAddress / bad-nonce / missing-nonce units live in **one** shared test file (§5). Not four copies. Not on the gold TestBases. | **Locked** |
| N22 | Do **not** add `public` getters for DETF `POOL_MANAGER` / `FEE_ORACLE` immutables. The premine helper takes those two addresses as arguments. Callers pass the same values used in that package’s `PkgInit` (`poolManager: pm`, `feeOracle: indexedexManager` on gold TestBases; scripts: `RobinhoodCanonicalLib.poolManager()` and `address(s.indexedexManager)`). | **Locked** |

---

## 3. Packages in scope (complete)

`deployVault` and `PkgArgs` live on the **`I*DETDFPkg`** interface in each file (not on the instance `I*DETF` interface in the same file):

| Family | File (contains both `I*DETF` and `I*DETDFPkg`) | Change `deployVault` on |
|--------|-----------------------------------------------|-------------------------|
| CP Single | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol` | `IUniswapV4SingleStandardExchangeDETDFPkg` |
| Orbital | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol` | `IUniswapV4StandardExchangeOrbitalDETDFPkg` |
| Weighted | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol` | `IUniswapV4StandardExchangeWeightedDETDFPkg` |
| Curve Quad | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol` | `IUniswapV4StandardExchangeCurveQuadStableDETDFPkg` |

Implementations (same directories, `*DETDFPkg.sol`): `deployVault`, `calcSalt`, `processArgs`, `initAccount`, `_deployReserveHook`.

`DeployConfig` on each package **must** keep `uint256 hookMineNonce` for postDeploy. It is filled from the decoded extra argument, **not** from `PkgArgs`. Do not rename it.

**Out of scope (do not change for this PRD):**

- Hook diamond factory
- Hook DFPkgs (`deployVault(hookArgs, uint256)` / `deployVaultAutoMine` stay)
- Vault registry / vault diamond factory signatures
- Non–Uni-V4-SE DETF families
- Dual SE / Balancer Quad DETFs if they exist later
- Product mint/bond/threshold/expansion behavior
- Adding `POOL_MANAGER()` / `FEE_ORACLE()` getters on DETF packages

---

## 4. Normative premine (tests and scripts)

Use this exact sequence. Gas cost in tests is accepted. Production callers **must** invoke it through `UniswapV4DetfHookPremineLib` (§4.2), not by inlining a second algorithm.

```text
1. Build DETF PkgArgs (no nonce field).
2. predictedDetf = diamondPackageFactory.calcAddress(
       IDiamondFactoryPackage(detfPkg),
       abi.encode(args, uint256(0))
   )
3. hookArgs = family hook PkgArgs from §4.1
      with DETF token slots = predictedDetf
      poolManager / feeOracle = the PkgInit values for that DETF package (N22)
4. packageSalt = hookPkg.calcSalt(abi.encode(hookArgs))
      // hook package calcSalt — NOT hook processArgs, NOT FactoryService.findMineNonce
5. mineNonce = UniswapV4HookDiamondCreate2Lib.findMineNonce(
       address(hookFactory),
       hookFactory.PROXY_INIT_HASH(),
       packageSalt,
       hookPkg.requiredHookFlags(),
       UniswapV4HookDiamondCreate2Lib.MAX_LOOP
   )
      // 0 is a legal result; pass it through; do not remine
      // findMineNonce reverts HookMineExhausted if no match — do not catch / fallback
6. detf = I*DETDFPkg(detfPkg).deployVault(args, mineNonce)
7. require(detf == predictedDetf)
```

Hook factory / hook package addresses are the ones already wired on the DETF package (`HOOK_PKG` in `PkgInit`) and the manager (`setHookDiamondPackageFactory`). Gold TestBases already have `hookFactory` / `hookPkg` / `detfPkg` / `diamondPackageFactory` / `pm` / `indexedexManager`.

**Forbidden premine paths:** `HOOK_PKG.deployVaultAutoMine`; hook `FactoryService.findMineNonce` (processArgs + decimals); stuffing a nonce into `PkgArgs`; skipping step 7; rejecting nonce `0` and remine; calling `hookFactory.calcAddress` (that path `processArgs`es the hook).

### 4.1 Hook `PkgArgs` the miner must build (must match `_deployReserveHook`)

These tables are **complete**. Every hook `PkgArgs` field is listed. Copy this layout. If a later package change would diverge, **stop and amend this PRD** — do not invent a third layout.

Shared constants (all families):

| Name | Value |
|------|--------|
| `tickSpacing` (Orbital only) | `60` |
| `sqrtPriceX96` (Orbital only) | `79228162514264337593543950336` (1:1) — **not** in Orbital hook `calcSalt`; still set |
| `poolManager` | caller-supplied; **must** equal that DETF package’s `PkgInit.poolManager` |
| `feeOracle` | caller-supplied; **must** equal that DETF package’s `PkgInit.feeOracle` |

**CP Single** (`IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs`):

| Field | Value |
|-------|--------|
| `poolManager` | PkgInit `poolManager` |
| `feeOracle` | PkgInit `feeOracle` |
| `standardExchange` | `address(args.standardExchangeVault)` |
| `pairToken` | `address(args.pairToken)` |
| `rawToken` | `predictedDetf` |

**Orbital** (`IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs`):

Binding (same as package `_resolvePairBinding`): `detfIdx = args.detfBindingIndex` (0, 1, or 2). Remaining indices in ascending order: first → pair0, second → pair1.

```text
uint8[2] rem; uint256 k;
for (uint8 i; i < 3; ++i) if (i != detfIdx) rem[k++] = i;
p0Idx = rem[0]; p1Idx = rem[1];
tokens[detfIdx] = predictedDetf;
tokens[p0Idx] = address(args.pairToken0);
tokens[p1Idx] = address(args.pairToken1);
ses[p0Idx] = address(args.standardExchange0);
ses[p1Idx] = address(args.standardExchange1);
rps[p0Idx] = args.rateProvider0;
rps[p1Idx] = args.rateProvider1;
// ses[detfIdx] and rps[detfIdx] stay address(0)
```

| Hook field | Value |
|------------|--------|
| `poolManager` | PkgInit `poolManager` |
| `feeOracle` | PkgInit `feeOracle` |
| `token0` | `tokens[0]` |
| `token1` | `tokens[1]` |
| `token2` | `tokens[2]` |
| `se0` | `ses[0]` |
| `se1` | `ses[1]` |
| `se2` | `ses[2]` |
| `rp0` | `rps[0]` |
| `rp1` | `rps[1]` |
| `rp2` | `rps[2]` |
| `tickSpacing` | `60` |
| `sqrtPriceX96` | `79228162514264337593543950336` |

**Weighted** (`IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs`):

`m = args.pairTokens.length`. `n = m + 1`. Build `sorted[0] = predictedDetf`, `sorted[i+1] = address(args.pairTokens[i])`. Insertion-sort `sorted` by address ascending (same loop as package `_resolveBinding`):

```text
for (uint8 i = 1; i < n; ++i) {
    address key = sorted[i];
    uint8 j = i;
    while (j > 0 && sorted[j - 1] > key) {
        sorted[j] = sorted[j - 1];
        unchecked { --j; }
    }
    sorted[j] = key;
}
```

`detfIdx` = index of `predictedDetf` in `sorted`. `pairIdx[i]` = index of `args.pairTokens[i]` in `sorted`. Then:

```text
tokens[detfIdx] = predictedDetf;
weights[detfIdx] = args.detfWeight;
ses[detfIdx] = address(0);
rps[detfIdx] = address(0);
for i in [0, m):
    tokens[pairIdx[i]] = address(args.pairTokens[i]);
    ses[pairIdx[i]] = address(args.standardExchanges[i]);
    rps[pairIdx[i]] = args.rateProviders[i];
    weights[pairIdx[i]] = args.pairWeights[i];
```

| Hook field | Value |
|------------|--------|
| `poolManager` | PkgInit `poolManager` |
| `feeOracle` | PkgInit `feeOracle` |
| `n` | `n` (`uint8`) |
| `tokens` | `tokens` (`address[]`, length `n`) |
| `weights` | `weights` (`uint256[]`, length `n`) |
| `standardExchanges` | `ses` (`address[]`, length `n`) |
| `rateProviders` | `rps` (`address[]`, length `n`) |

**Curve Quad** (`IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs`):

`N = 4`, `M = 3`. Build `sorted[0] = predictedDetf`, `sorted[i+1] = address(args.pairTokens[i])` for `i in [0, 3)`. Insertion-sort `sorted` with the **same** loop as Weighted / package `_resolveBinding`. `detfIdx` / `pairIdx[i]` as Weighted. Then:

```text
tokens[detfIdx] = predictedDetf;
ses[detfIdx] = address(0);
rps[detfIdx] = address(0);
for i in [0, 3):
    tokens[pairIdx[i]] = address(args.pairTokens[i]);
    ses[pairIdx[i]] = address(args.standardExchanges[i]);
    rps[pairIdx[i]] = args.rateProviders[i];
```

`baseAmp` = `args.baseAmp` **as given**. Do **not** substitute `FixtureEconomics.BASE_AMP` when `args.baseAmp == 0` (the package already rejects 0 / over max in `initAccount`).

| Hook field | Value |
|------------|--------|
| `poolManager` | PkgInit `poolManager` |
| `feeOracle` | PkgInit `feeOracle` |
| `tokens` | `tokens` (`address[4]`) |
| `standardExchanges` | `ses` (`address[4]`) |
| `rateProviders` | `rps` (`address[4]`) |
| `baseAmp` | `args.baseAmp` |

### 4.2 Shared premine helper (locked)

**Path (create):** `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol`

**Delete:** `scripts/foundry/anvil_robinhood_testnet/HookPremineLib.sol`

**License / pragma:** `SPDX-License-Identifier: BSL-1.1`, `pragma solidity ^0.8.0;` (match sibling DETF files).

**Shape:** `library UniswapV4DetfHookPremineLib` with four `internal view` functions. No `console2`. No LaunchState. No `takePrepared`. Implement §4 steps 2–5 only (callers do 6–7).

Exact signatures (no overloads, no extra helpers except `private` sort / orbital-index functions used by these four):

```solidity
function premineCp(
    IDiamondPackageCallBackFactory diamondPackageFactory,
    IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
    IUniswapV4SingleStandardExchangeDETDFPkg detfPkg,
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage hookPkg,
    IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args,
    address poolManager,
    address feeOracle
) internal view returns (address predictedDetf, uint256 mineNonce);

function premineOrbital(
    IDiamondPackageCallBackFactory diamondPackageFactory,
    IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
    IUniswapV4StandardExchangeOrbitalDETDFPkg detfPkg,
    IUniswapV4StandardExchangeOrbitalBufferHookPackage hookPkg,
    IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args,
    address poolManager,
    address feeOracle
) internal view returns (address predictedDetf, uint256 mineNonce);

function premineWeighted(
    IDiamondPackageCallBackFactory diamondPackageFactory,
    IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
    IUniswapV4StandardExchangeWeightedDETDFPkg detfPkg,
    IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg,
    IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args,
    address poolManager,
    address feeOracle
) internal view returns (address predictedDetf, uint256 mineNonce);

function premineQuad(
    IDiamondPackageCallBackFactory diamondPackageFactory,
    IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg detfPkg,
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage hookPkg,
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args,
    address poolManager,
    address feeOracle
) internal view returns (address predictedDetf, uint256 mineNonce);
```

Imports: Crane `IDiamondPackageCallBackFactory`; hook factory interface; the four `I*DETDFPkg` files; the four hook package interfaces; `UniswapV4HookDiamondCreate2Lib`.

Private helpers allowed: `_orbitalPairIdx(uint8 detfIdx) returns (uint8 p0, uint8 p1)` and `_sort(address[] memory a)` as in the deleted script lib; plus a private `_mine(hookFactory, hookPkg, hookArgs)` that runs steps 4–5.

Gold TestBase call (CP; other families swap the `premine*` name and types):

```solidity
(address predicted_, uint256 nonce_) = UniswapV4DetfHookPremineLib.premineCp(
    diamondPackageFactory,
    hookFactory,
    detfPkg,
    hookPkg,
    args,
    address(pm),
    address(indexedexManager)
);
detf_ = detfPkg.deployVault(args, nonce_);
require(detf_ == predicted_, "detf != predicted");
```

Launch scripts: same call with `s.diamondPackageFactory`, `s.hookFactory`, the family `s.*DetfPkg` / `s.*HookPkg`, `RobinhoodCanonicalLib.poolManager()`, `address(s.indexedexManager)`. Then `I*DETDFPkg(pkg).deployVault(args, nonce)` — **not** `args.hookMineNonce = nonce`.

---

## 5. Tests (locked)

| Item | Law |
|------|-----|
| Gold TestBases (four `TestBase_UniswapV4*DETF.sol` co-located with packages) | `_defaultDetfArgs` / struct literals: **drop** `hookMineNonce`. `_deployDetfInstance` uses §4.2 + typed `deployVault(args, nonce)` + `require(detf == predicted)`. |
| Tests that construct `PkgArgs({..., hookMineNonce: 0})` | Remove that field; deploy only via `_deployDetfInstance`. Do not inline a second premine. |
| `indexedexManager.deployVault` | Forbidden for these four packages except the one shared unit in the file below. |
| New units (all four families) | **One file:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfDeployMineNonce.t.sol`. Four contracts in that file, each inheriting the matching gold TestBase. Each contract implements the three units below. |
| Unit A — salt ignores nonce | Same `PkgArgs`. `calcAddress(..., abi.encode(args, uint256(0)))` equals `calcAddress(..., abi.encode(args, uint256(1)))`. `_deployDetfInstance(args)` address equals `calcAddress(..., abi.encode(args, uint256(0)))`. |
| Unit B — bad nonce reverts | Premine to get a good nonce. `deliberatelyBadNonce = goodNonce + 1`; while `UniswapV4HookDiamondCreate2Lib.flagsMatch(predictAddress(hookFactory, PROXY_INIT_HASH, packageSalt, deliberatelyBadNonce), hookPkg.requiredHookFlags())`, increment by 1. Then `vm.prank(owner); vm.expectRevert(); detfPkg.deployVault(args, deliberatelyBadNonce);`. Do not auto-mine as fallback. Do not require a specific revert selector (factory `InvalidHookFlags` vs decode vs hook-pkg revert are all failures). |
| Unit C — missing nonce reverts | `vm.prank(owner); vm.expectRevert(); indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));` (no nonce). This is the **only** allowed `indexedexManager.deployVault` call site for these packages. |
| Hook `deployVaultAutoMine` tests | Unchanged; those are hook-package tests. |
| Adversarial / core / price-movement suites | Must still compile and pass hermetic. No SUT mocks. Deploy through `_deployDetfInstance` only. |

Known current `hookMineNonce` Solidity call sites that **must** change (grep-verify; if grep finds more, change those too — **all** in-repo Solidity that names the PkgArgs field must change):

- Four gold TestBases under `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/**`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Adversarial.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Core.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Adversarial.t.sol`
- Four DETF `*DETDFPkg.sol` (`PkgArgs` gone; `DeployConfig.hookMineNonce` **stays**)
- Four `I*DETDFPkg` interface files
- Scripts listed in §6
- Any other `rg hookMineNonce --glob '*.sol'` hit in this repo except hook-factory / hook-DFPkg files

After the change, `rg hookMineNonce --glob '*.sol'` hits **only** `DeployConfig.hookMineNonce` (and comments on it) inside the four DETF packages.

---

## 6. Scripts (locked)

Must compile and use `I*DETDFPkg.deployVault(args, mineNonce)` after `UniswapV4DetfHookPremineLib.premine*`.

| Tree | Files | Required edit |
|------|--------|----------------|
| `scripts/foundry/anvil_robinhood_testnet/` | `HookPremineLib.sol` | **Delete** the file. Fix every import. |
| same | `Stage_06_LeafDETFs.sol`, `Stage_07_NestDETFs.sol`, `Stage_08_FeeSink.sol` | Replace `args.hookMineNonce = HookPremineLib.*` / `takePrepared` with `premine*` + `deployVault(args, nonce)`. Drop `hookMineNonce` from every `PkgArgs` literal. |
| same | `FixtureEconomics.sol` | **Delete** `HOOK_MINE_NONCE`. Do not replace it. |
| same | `LaunchState.sol` | **Delete** `hookNoncePrepared`, `pendingHookMineNonce`, and any `prepare*` helpers that only existed to stash a PkgArgs nonce. |
| same | `Script_06*.s.sol`, `Script_07_NestDETFs.s.sol`, `Script_08_FeeSink.s.sol` | Change **only** if they name `hookMineNonce`, import `HookPremineLib`, or call `takePrepared` / `prepare*`. Otherwise compile-check only. |
| same | `README.md` | Replace “premine then stuff `hookMineNonce`” / “do not leave `hookMineNonce = 0`” with “premine via `UniswapV4DetfHookPremineLib`; `deployVault(args, mineNonce)`; `0` is a legal nonce.” |
| `scripts/foundry/anvil_robinhood_main/` | `Script_13_DeployInertDemos.s.sol`, `Script_18_DeployChirInstance.s.sol` | Drop `hookMineNonce` from literals; premine + typed `deployVault(args, nonce)`. Today they pass `0` (auto-mine) — that path is gone. |
| `scripts/foundry/anvil_robinhood_fee_detf/` | `Script_09_DeployChirInstance.s.sol` | Same as main scripts. |

Remove the script hack that rejects nonce `0` and remine. `0` is a legal premined nonce.

46630 demo PRD D38: replace “`hookMineNonce = 0` (auto-mine)” with “caller premines via `UniswapV4DetfHookPremineLib`; `deployVault(args, mineNonce)`; nonce not in PkgArgs.” Implementation plan for 46630 must be patched the same way.

---

## 7. Docs the plan agent must patch (same change set)

- This PRD stays SoT.
- Four family `*_PRD.md` next to the packages: delete PkgArgs `hookMineNonce` / auto-mine rows; document `deployVault(args, mineNonce)` on `I*DETDFPkg`.
- Four family `*_IMPLEMENTATION_AND_TEST_PLAN.md` next to the packages: any sentence that says DETF auto-mines when nonce is 0.
- `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md` D38 and §2.8 shared-args line.
- `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md` `HOOK_MINE_NONCE = 0` / auto-mine notes.
- `docs/ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md` `hookMineNonce: 0 → auto-mine` and the “Hook mine / flag failure” row.
- `scripts/foundry/anvil_robinhood_testnet/README.md` (see §6).

Do not rewrite hook-factory or hook-package PRDs.

---

## 8. Explicit non-goals

- Changing hook factory mining, `MAX_LOOP`, or hook `deployVaultAutoMine`
- Putting mineNonce back into DETF `calcSalt`
- Package-level pending-nonce mapping / transient stash (N6 encoding is the only path)
- Keeping a one-arg DETF `deployVault` “for convenience”
- `uint8` nonce
- `via_ir`
- Changing DETF mint/bond/threshold/expansion product behavior
- Public broadcast / 46630 live deploy
- Renaming `DeployConfig.hookMineNonce`
- Adding DETF `POOL_MANAGER` / `FEE_ORACLE` public getters
- Keeping `scripts/.../HookPremineLib.sol` as a wrapper
- A second premine algorithm in tests or scripts

---

## 9. Definition of done (requirements)

- Four `I*DETDFPkg` interfaces: `PkgArgs` has no `hookMineNonce`; `deployVault(PkgArgs, uint256)` only. Instance `I*DETF` interfaces have no `deployVault`.
- Four packages: N6–N11; no `deployVaultAutoMine`; `_deployReserveHook` never auto-mines; `DeployConfig.hookMineNonce` remains the storage field.
- `calcAddress` independent of the nonce integer in the encoded blob.
- `rg hookMineNonce --glob '*.sol'` in this repo: hits only `DeployConfig.hookMineNonce` (and comments) inside the four DETF packages. No `PkgArgs` field.
- `rg deployVaultAutoMine` on those four DETF packages: clean.
- `scripts/foundry/anvil_robinhood_testnet/HookPremineLib.sol` does not exist.
- Gold TestBases + listed tests + listed scripts compile and use `UniswapV4DetfHookPremineLib` + two-arg `deployVault`.
- Shared test file §5 exists and covers units A/B/C on all four families.
- Hermetic tests for the four families green (plan names the exact `forge test --match-path` set).
- Family PRDs + 46630 D38 + fee-DETF launch plan + 46630 script README patched.
- `git diff` does not change hook factory / hook DFPkg auto-mine surfaces except call-site updates if a test was wrongly using DETF auto-mine.

---

## 10. Open questions

None. Review v0.2 locked: keep `DeployConfig.hookMineNonce`; delete script `HookPremineLib`; helper returns `(predictedDetf, mineNonce)`; typed `deployVault` only except the one registry unit; one shared test file; `processArgs` returns the original blob; extra docs in §7.

---

## 11. Revision log

| Date | Rev | Change |
|------|-----|--------|
| 2026-08-16 | **v0.1** | First draft from agreed design: nonce out of PkgArgs; `deployVault(args, uint256)`; no DETF auto-mine; `abi.encode(args, nonce)`; calcSalt hashes PkgArgs only. |
| 2026-08-16 | **v0.2** | Review lock: `I*DETDFPkg` only; `processArgs` returns original blob; `DeployConfig.hookMineNonce` kept; delete script premine lib; helper signatures + complete hook field tables; typed callers only except one registry unit; one shared test file; extra docs (fee-DETF plan + script README); no remaining `or` / `optionally` / `may`. |

**Next:** implement from [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_IMPLEMENTATION_AND_TEST_PLAN.md) (no new product choices).
