# Implementation & Test Plan: Uni V4 SE DETF `deployVault` mineNonce

**PRD (product law SoT):** [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](./UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md) (**Accepted v0.2**)  
**This plan (implementor SoT):** file map, phases, exact edits, test commands, DoD. **No product choices.**  
**Date:** 2026-08-16  
**Status:** Ready to implement.

| Layer | Role |
|-------|------|
| **PRD v0.2** | Product law. Wins on any conflict. Patch this plan if the PRD changes. |
| **This plan** | Phases, file map, commit order, `forge test --match-path` set, grep DoD |
| **CLAUDE.md / INDEXEDEX_AGENT_LAW** | Crane first; never `new` DFPkgs; DETF role names; no `via_ir`; production-first tests; forge patience |
| **Skills** | `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing` |

**Process:** If this plan and the PRD disagree, **PRD wins** and this plan must be patched before coding continues. Do not invent a third layout.

**Role names only:** `rateAsset`, `pairToken`, `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`. No product brands.

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.2 | Locked, co-located |
| Four `I*DETDFPkg` | `deployVault(PkgArgs)` one-arg; `PkgArgs.hookMineNonce` present |
| Four `*DETDFPkg.sol` | `calcSalt` decodes `PkgArgs` and zeros `hookMineNonce`; `_deployReserveHook` auto-mines when nonce is 0 |
| Four gold TestBases | `hookMineNonce: 0`; `indexedexManager.deployVault(pkg, abi.encode(args))` |
| `scripts/.../HookPremineLib.sol` | Exists; rejects nonce `0`; stuffs nonce into `PkgArgs` |
| Shared premine lib | **Does not exist** |
| Shared mine-nonce test | **Does not exist** |

---

## 1. Goals / non-goals

### Goals

1. Remove `hookMineNonce` from all four Uni V4 SE DETF `PkgArgs`.  
2. Typed surface: `I*DETDFPkg.deployVault(PkgArgs args, uint256 mineNonce)` only.  
3. Registry bytes: `abi.encode(args, mineNonce)`. `calcSalt` hashes `PkgArgs` only.  
4. DETF packages never auto-mine. `_deployReserveHook` always `HOOK_PKG.deployVault(hArgs, cfg.hookMineNonce)`.  
5. One shared `UniswapV4DetfHookPremineLib`; all TestBases and listed scripts use it.  
6. Hermetic family suites green. Grep DoD green.

### Non-goals (do not do)

Copied from PRD §8. Do not: change hook factory / hook DFPkg auto-mine; put nonce back in `calcSalt`; keep one-arg DETF `deployVault`; `uint8` nonce; `via_ir`; `new` facets/DFPkgs; rename `DeployConfig.hookMineNonce`; add `POOL_MANAGER()` / `FEE_ORACLE()` getters; keep `scripts/.../HookPremineLib.sol`; change mint/bond/threshold/expansion product behavior; live 46630 broadcast.

---

## 2. Read order for implementors

1. PRD §0–§2 (N1–N22)  
2. PRD §4–§4.2 (normative premine + helper signatures + complete hook field tables)  
3. PRD §5–§9 (tests, scripts, docs, DoD)  
4. **This plan** §3–§8  
5. Current `calcSalt` / `processArgs` / `initAccount` / `_deployReserveHook` on one package (CP is the template; clone the same four-line pattern to the other three)

---

## 3. File map (complete)

### 3.1 Create

| Path | What |
|------|------|
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol` | Library per PRD §4.2. SPDX `BSL-1.1`, `pragma solidity ^0.8.0;`. Four `internal view` functions. No `console2`. |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfDeployMineNonce.t.sol` | Four contracts, units A/B/C each. |

### 3.2 Delete

| Path | Why |
|------|-----|
| `scripts/foundry/anvil_robinhood_testnet/HookPremineLib.sol` | Replaced by the shared lib. Do not leave a wrapper. |

### 3.3 Edit — packages (same four-function pattern on each)

| File | Edits (exact) |
|------|----------------|
| `…/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol` | On **`IUniswapV4SingleStandardExchangeDETDFPkg` only**: delete `PkgArgs.hookMineNonce`; change `deployVault` to `function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);`. Do not touch `IUniswapV4SingleStandardExchangeDETF`. |
| `…/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol` | Same on `IUniswapV4StandardExchangeOrbitalDETDFPkg`. |
| `…/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol` | Same on `IUniswapV4StandardExchangeWeightedDETDFPkg`. |
| `…/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol` | Same on `IUniswapV4StandardExchangeCurveQuadStableDETDFPkg`. |
| `…/constantProduct/single/UniswapV4SingleStandardExchangeDETDFPkg.sol` | §3.4 |
| `…/orbital/UniswapV4StandardExchangeOrbitalDETDFPkg.sol` | §3.4 |
| `…/weighted/UniswapV4StandardExchangeWeightedDETDFPkg.sol` | §3.4 |
| `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol` | §3.4 |

Do **not** edit facet/target/repo/FactoryService files for this change. `PkgArgs` is only on the package interface.

### 3.4 Package function bodies (copy this; four packages)

**`deployVault`**

```solidity
function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault) {
    return VAULT_REGISTRY_DEPLOYMENT.deployVault(
        IStandardVaultPkg(address(this)), abi.encode(args, mineNonce)
    );
}
```

**`calcSalt`** — replace the current “decode PkgArgs, zero hookMineNonce, hash” body:

```solidity
function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
    (PkgArgs memory argsOnly,) = abi.decode(pkgArgs, (PkgArgs, uint256));
    return keccak256(abi.encode(argsOnly));
}
```

**`processArgs`** — keep the `NotCalledByRegistry` check; add decode; return the original bytes:

```solidity
function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs_) {
    if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
        revert NotCalledByRegistry(msg.sender);
    }
    abi.decode(pkgArgs, (PkgArgs, uint256));
    return pkgArgs;
}
```

**`initAccount`** — change only the decode and the nonce store:

```solidity
(PkgArgs memory args, uint256 mineNonce) = abi.decode(initArgs, (PkgArgs, uint256));
// existing PkgArgs checks unchanged (they no longer read args.hookMineNonce)
cfg.hookMineNonce = mineNonce;
```

**`_deployReserveHook`** — delete the `if (cfg.hookMineNonce == 0) deployVaultAutoMine` branch. Keep hook `PkgArgs` construction exactly as it is today. End with only:

```solidity
hook_ = HOOK_PKG.deployVault(hArgs, cfg.hookMineNonce);
```

**`DeployConfig.hookMineNonce`** — do not rename, do not move, do not delete.

### 3.5 Shared premine library (create — signatures are law)

Path and signatures: PRD §4.2. Implement §4 steps 2–5 only.

Private helpers allowed (and required — do not add others):

| Helper | Role |
|--------|------|
| `_orbitalPairIdx(uint8 detfIdx) private pure returns (uint8 p0, uint8 p1)` | PRD §4.1 Orbital remaining-index loop |
| `_sort(address[] memory a) private pure` | PRD §4.1 insertion sort |
| `_mine(hookFactory, hookPkg, bytes memory hookArgs) private view returns (uint256)` | `hookPkg.calcSalt(hookArgs)` then `UniswapV4HookDiamondCreate2Lib.findMineNonce(address(hookFactory), hookFactory.PROXY_INIT_HASH(), packageSalt, hookPkg.requiredHookFlags(), UniswapV4HookDiamondCreate2Lib.MAX_LOOP)`. Pass `0` through. Do not remine. Do not catch `HookMineExhausted`. |

Each `premine*`:

1. `predictedDetf = diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0)))`  
2. Build hook `PkgArgs` from PRD §4.1 using `poolManager` / `feeOracle` arguments (not package getters).  
3. `mineNonce = _mine(hookFactory, hookPkg, abi.encode(hArgs))`  
4. `return (predictedDetf, mineNonce)`

`premineQuad`: `baseAmp = args.baseAmp` as given. Do not substitute `100` / `FixtureEconomics.BASE_AMP`.

Imports (only these):

- `@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol`
- `@crane/contracts/interfaces/IDiamondFactoryPackage.sol`
- `contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol`
- `contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol` (if needed for `_mine`)
- `contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol`
- Four `I*DETDFPkg` interface files
- Four hook package interface files listed in PRD §4.1

### 3.6 Gold TestBases

| File |
|------|
| `…/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol` |
| `…/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol` |
| `…/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol` |
| `…/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol` |

In each:

1. Import `UniswapV4DetfHookPremineLib`.  
2. Drop `hookMineNonce` from every `PkgArgs({...})` literal (`_defaultDetfArgs` and any second literal; Weighted has two).  
3. Replace `_deployDetfInstance` body with the PRD §4.2 snippet for that family (`premineCp` / `premineOrbital` / `premineWeighted` / `premineQuad`). Keep `vm.startPrank(owner)` / `stopPrank` around `deployVault` only (premine is `view`; may sit inside or outside the prank).  
4. `require(detf_ == predicted_, "detf != predicted");` then `vm.label`.  
5. Stop calling `indexedexManager.deployVault`.

TestBase argument tuple (all four):

```text
diamondPackageFactory, hookFactory, detfPkg, hookPkg, args, address(pm), address(indexedexManager)
```

### 3.7 Existing tests that construct `PkgArgs` with `hookMineNonce`

Remove the field. Deploy only via `_deployDetfInstance`. Do not inline premine.

| File | Lines today |
|------|-------------|
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Adversarial.t.sol` | `hookMineNonce: 0` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Core.t.sol` | two literals |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Adversarial.t.sol` | one literal |

After those edits, `rg hookMineNonce --glob '*.sol'` must not hit these files.

### 3.8 New shared test (create)

**Path:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfDeployMineNonce.t.sol`

Four contracts, one file:

| Contract | Inherits |
|----------|----------|
| `UniswapV4SeDetfDeployMineNonce_Cp` | `TestBase_UniswapV4SingleStandardExchangeDETF` |
| `UniswapV4SeDetfDeployMineNonce_Orbital` | `TestBase_UniswapV4StandardExchangeOrbitalDETF` |
| `UniswapV4SeDetfDeployMineNonce_Weighted` | `TestBase_UniswapV4StandardExchangeWeightedDETF` |
| `UniswapV4SeDetfDeployMineNonce_Quad` | `TestBase_UniswapV4StandardExchangeCurveQuadStableDETF` |

Each contract implements these three tests (same names on all four):

**`test_saltIgnoresNonce` (Unit A)**

```solidity
PkgArgs memory args = _defaultDetfArgs();
address a0 = diamondPackageFactory.calcAddress(
    IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
);
address a1 = diamondPackageFactory.calcAddress(
    IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(1))
);
assertEq(a0, a1);
address deployed = _deployDetfInstance(args);
assertEq(deployed, a0);
```

**`test_badNonceReverts` (Unit B)**

1. `args = _defaultDetfArgs()`.  
2. `(, uint256 good) = UniswapV4DetfHookPremineLib.premine*(..., args, address(pm), address(indexedexManager));`  
3. Rebuild that family’s hook `PkgArgs` from PRD §4.1 (`predictedDetf` from `calcAddress(..., abi.encode(args, uint256(0)))`).  
4. `packageSalt = hookPkg.calcSalt(abi.encode(hArgs))`.  
5. `uint256 bad = good + 1`; `while (UniswapV4HookDiamondCreate2Lib.flagsMatch(UniswapV4HookDiamondCreate2Lib.predictAddress(address(hookFactory), hookFactory.PROXY_INIT_HASH(), packageSalt, bad), hookPkg.requiredHookFlags())) { unchecked { ++bad; } }`  
6. `vm.prank(owner); vm.expectRevert(); detfPkg.deployVault(args, bad);`

Do not require a specific revert selector.

**`test_missingNonceReverts` (Unit C)** — **only** allowed `indexedexManager.deployVault` call site:

```solidity
vm.prank(owner);
vm.expectRevert();
indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(_defaultDetfArgs()));
```

No SUT mocks. No extra tests in this file.

### 3.9 Scripts — 46630 testnet

| File | Required edit |
|------|----------------|
| `scripts/foundry/anvil_robinhood_testnet/HookPremineLib.sol` | **Delete** |
| `scripts/foundry/anvil_robinhood_testnet/LaunchState.sol` | Delete `pendingHookMineNonce` and `hookNoncePrepared` (and their comments). |
| `scripts/foundry/anvil_robinhood_testnet/FixtureEconomics.sol` | Delete `HOOK_MINE_NONCE` and its comment. Do not replace it. |
| `scripts/foundry/anvil_robinhood_testnet/Stage_06_LeafDETFs.sol` | §3.10 |
| `scripts/foundry/anvil_robinhood_testnet/Stage_07_NestDETFs.sol` | Replace `args.hookMineNonce = HookPremineLib.for*(s, args)` + `deployVault(args)` with `premine*` + `deployVault(args, nonce)`. Drop the field from literals. Import the shared lib; delete `HookPremineLib` import. |
| `scripts/foundry/anvil_robinhood_testnet/Stage_08_FeeSink.sol` | Same as Stage_07 (`premineCp`). |
| `scripts/foundry/anvil_robinhood_testnet/Script_06_LeafDETFs.s.sol` | Delete every `Stage_06_LeafDETFs.prepare*(s)` call. Update the file comment: premine happens inside `deploy*` (internal view; not a broadcast tx). |
| `scripts/foundry/anvil_robinhood_testnet/Script_06a_NvdaS.s.sol` | Delete `prepareNvdaS`. |
| `scripts/foundry/anvil_robinhood_testnet/Script_06b_NvdaSmhO.s.sol` | Delete `prepareNvdaSmhO`. |
| `scripts/foundry/anvil_robinhood_testnet/Script_06c_IdxQ.s.sol` | Delete `prepareIdxQ` if present. |
| `scripts/foundry/anvil_robinhood_testnet/Script_06d_M7W.s.sol` | Delete `prepareM7W` if present. |
| `scripts/foundry/anvil_robinhood_testnet/Script_06e_DolQ.s.sol` | Delete `prepareDolQ` if present. |
| `scripts/foundry/anvil_robinhood_testnet/Script_07_NestDETFs.s.sol` | Change only if it names `HookPremineLib` / `hookMineNonce` / `prepare*` / `takePrepared`. Otherwise compile-check. |
| `scripts/foundry/anvil_robinhood_testnet/Script_08_FeeSink.s.sol` | Same rule as Script_07. |
| `scripts/foundry/anvil_robinhood_testnet/README.md` | Replace “premine then stuff `hookMineNonce`” / “do not leave `hookMineNonce = 0`” with: caller premines via `UniswapV4DetfHookPremineLib`; `deployVault(args, mineNonce)`; `0` is a legal nonce. |

**Do not** reintroduce LaunchState nonce stash under a new name. `prepare*` functions are deleted. Premine runs inside `_deploy*` / `deploy*` immediately before `deployVault`. `UniswapV4DetfHookPremineLib` is `internal view`; Foundry does not broadcast it.

### 3.10 Stage_06 deploy body (template)

Delete all `prepare*` functions. Each `_deploy*` becomes:

```solidity
I*DETDFPkg.PkgArgs memory args = _*Args(s);
(address predicted, uint256 nonce) = UniswapV4DetfHookPremineLib.premine*(
    s.diamondPackageFactory,
    s.hookFactory,
    I*DETDFPkg(s.*DetfPkg),
    I*Hook(s.*HookPkg),
    args,
    RobinhoodCanonicalLib.poolManager(),
    address(s.indexedexManager)
);
s.tt* = I*DETDFPkg(s.*DetfPkg).deployVault(args, nonce);
require(s.tt* == predicted, "detf != predicted");
```

Family mapping:

| Deploy | `premine*` | detf pkg field | hook pkg field |
|--------|------------|----------------|----------------|
| `_deployNvdaS` | `premineCp` | `s.cpDetfPkg` | `s.cpHookPkg` |
| `_deployNvdaSmhO` | `premineOrbital` | `s.orbitalDetfPkg` | `s.orbitalHookPkg` |
| `_deployIdxQ` / `_deployDolQ` | `premineQuad` | `s.curveQuadDetfPkg` | `s.curveQuadHookPkg` |
| `_deployM7W` | `premineWeighted` | `s.weightedDetfPkg` | `s.weightedHookPkg` |

`deployNvdaS` etc. keep the current “if already deployed, skip; else `_deploy*`; then enrich” control flow, minus `if (!s.hookNoncePrepared) prepare*`.

Delete `_quadBase`’s `args.hookMineNonce = FixtureEconomics.HOOK_MINE_NONCE` line.

### 3.11 Scripts — main + fee DETF

These today pass `hookMineNonce: 0` and call `indexedexManager.deployVault(pkg, abi.encode(args))`. That is forbidden after this change (PRD N19).

| File | Load these extra addresses | Then |
|------|----------------------------|------|
| `scripts/foundry/anvil_robinhood_main/Script_13_DeployInertDemos.s.sol` | `diamondPackageFactory` from `01_crane_foundation.json`; `hookFactory` already from `03_hook_factory.json`; `cpHookPkg` / `orbitalHookPkg` / `weightedHookPkg` from `10_hook_packages.json` | Drop `hookMineNonce` from every DETF `PkgArgs`. Before each DETF `deployVault`, `premine*` with `RobinhoodCanonicalLib.poolManager()` and `indexedexManager`. Call `I*DETDFPkg(pkg).deployVault(args, nonce)` — **not** `IIndexedexManagerProxy.deployVault`. `require(deployed == predicted)`. Do **not** change the existing hook-package `WgtFS.findMineNonce` / `SingleFS.findMineNonce` calls (those are hook DFPkg deploys, out of scope). |
| `scripts/foundry/anvil_robinhood_main/Script_18_DeployChirInstance.s.sol` | `diamondPackageFactory` from `01_crane_foundation.json`; `hookFactory` from `03_hook_factory.json`; `bufferCpHookPkg` from `17_fee_detf_packages.json` (same key Script_17 writes; if the file only has `bufferCpHookPkg` / `chirDetfPkg`, use those) | CP only: `premineCp` + `IUniswapV4SingleStandardExchangeDETDFPkg(chirDetfPkg).deployVault(args, nonce)`. Drop `hookMineNonce`. Stop `manager.deployVault`. |
| `scripts/foundry/anvil_robinhood_fee_detf/Script_09_DeployChirInstance.s.sol` | `diamondPackageFactory` from `01_crane_foundation.json`; `hookFactory` from `03_hook_factory.json`; `bufferCpHookPkg` from `08_fee_detf_packages.json` | Same as Script_18. |

If a JSON key is missing, **stop** and amend this plan with the real key from that tree’s export — do not invent a third artifact name.

### 3.12 Docs (same change set)

| File | Edit |
|------|------|
| Four family `*_PRD.md` | In Deploy / PkgArgs sections: state `I*DETDFPkg.deployVault(args, mineNonce)`; nonce is **not** a PkgArgs field; caller premines via `UniswapV4DetfHookPremineLib`. Do **not** add `hookMineNonce` to the PkgArgs table. Point at this PRD as SoT for deploy arity. |
| Four family `*_IMPLEMENTATION_AND_TEST_PLAN.md` | If any sentence says DETF auto-mines when nonce is 0, delete it. Add one line: deploy arity is this PRD / this plan. (Today they do not mention `hookMineNonce`; still add the pointer.) |
| `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md` | D38: replace `` `hookMineNonce = 0` (auto-mine) `` with “caller premines via `UniswapV4DetfHookPremineLib`; `deployVault(args, mineNonce)`; nonce not in PkgArgs.” Same for the §2.8 shared-args line that lists `hookMineNonce = 0`. All other D38 fields unchanged. |
| `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md` | Delete `HOOK_MINE_NONCE = 0 // auto-mine` from the FixtureEconomics copy block. Replace with a note: no `HOOK_MINE_NONCE`; premine via shared lib. |
| `docs/ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md` | Replace `hookMineNonce: 0 → auto-mine` and the “Hook mine / flag failure” row (`hookMineNonce=0` auto-mine) with premine + two-arg `deployVault`. |
| `docs/ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md` | Only if it still says DETF auto-mines on nonce 0 — patch that sentence. Do not rewrite the rest. |
| This PRD | Stays SoT. Do not rewrite hook-factory or hook-package PRDs. |

---

## 4. Phases / commit slices

One change set is acceptable. If slicing commits, use this order (later phases will not compile until earlier ones land):

| Phase | Contents | Compile? |
|-------|----------|----------|
| **P0** | Four interfaces + four packages (§3.3–§3.4) | Breaks callers |
| **P1** | Create `UniswapV4DetfHookPremineLib.sol` | Lib alone compiles |
| **P2** | Four TestBases + three existing spec files that name `hookMineNonce` | Family tests compile |
| **P3** | Shared `UniswapV4SeDetfDeployMineNonce.t.sol` | New units compile |
| **P4** | Delete script `HookPremineLib`; LaunchState / FixtureEconomics / Stage_06–08 / Script_06* / main+fee scripts | Scripts compile |
| **P5** | Docs §3.12 | n/a |

Do not merge P4 before P1 (scripts import the new lib). Do not keep the old script lib “until scripts are done.”

---

## 5. Test execution (normative)

**Forge patience:** first compile in a cold or near-cold tree commonly takes 20–40+ minutes with little output. That is normal. Wait for process exit. Never kill `forge` / `solc`. If a tool requires a timeout, set **2–4 hours**, not 10–20 minutes. If this is a new worktree, seed `cache_forge/` and `out/` from the warm checkout first (CLAUDE.md worktree seed).

Default profile only (`forge test`). No `via_ir`. No package-specific profile. Do not run `FOUNDRY_PROFILE=fork` for this DoD.

Run in this order (stop and fix on first failure):

```bash
# 1. New units (all four family contracts in one file)
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfDeployMineNonce.t.sol' \
  -vv

# 2. CP family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**' \
  -vv

# 3. Orbital family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/**' \
  -vv

# 4. Weighted family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/**' \
  -vv

# 5. Curve Quad family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/**' \
  -vv
```

Script compile check after P4 (does not broadcast):

```bash
forge build --skip test
```

`foundry.toml` already compiles `scripts/`. A green `forge build --skip test` is the script DoD. Do **not** run 46630 live / public broadcast.

---

## 6. Grep DoD (run after P4, before declaring done)

```bash
# PkgArgs field gone. Hits must be DeployConfig.hookMineNonce (and comments) in the four DETF packages only.
rg hookMineNonce --glob '*.sol'

# No DETF-package auto-mine helper
rg deployVaultAutoMine \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange

# Deleted
test ! -e scripts/foundry/anvil_robinhood_testnet/HookPremineLib.sol

# No leftover LaunchState stash / script constant
rg 'pendingHookMineNonce|hookNoncePrepared|HOOK_MINE_NONCE|takePrepared|HookPremineLib' \
  scripts/foundry

# Docs no longer prescribe DETF auto-mine
rg 'hookMineNonce = 0|hookMineNonce: 0|HOOK_MINE_NONCE' docs/ \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange
```

Pass criteria:

- `rg hookMineNonce --glob '*.sol'`: only the four `*DETDFPkg.sol` `DeployConfig` fields (and comments on that field). Zero hits in interfaces, tests, scripts.  
- `rg deployVaultAutoMine` under the four DETF package directories: clean (hook DFPkg trees will still match — those are out of scope).  
- Script `HookPremineLib.sol` gone.  
- `pendingHookMineNonce` / `hookNoncePrepared` / `HOOK_MINE_NONCE` / `takePrepared` / `HookPremineLib` gone from `scripts/foundry`.  
- Docs under `docs/` and the four family trees no longer say `hookMineNonce = 0` / auto-mine for DETF deploy.

If `rg hookMineNonce --glob '*.sol'` finds another PkgArgs / literal site, **change it**. Do not waive.

`git diff` must not change hook factory sources or hook DFPkg `deployVault` / `deployVaultAutoMine` surfaces.

---

## 7. Definition of done

All of PRD §9, plus:

- [ ] Four `I*DETDFPkg`: no `PkgArgs.hookMineNonce`; `deployVault(PkgArgs, uint256)` only. Instance `I*DETF` untouched.  
- [ ] Four packages: N6–N11; `DeployConfig.hookMineNonce` kept; no `deployVaultAutoMine`; no `if (nonce == 0)` auto-mine.  
- [ ] `UniswapV4DetfHookPremineLib.sol` exists with the four locked signatures.  
- [ ] `scripts/foundry/anvil_robinhood_testnet/HookPremineLib.sol` deleted.  
- [ ] Four TestBases use `premine*` + typed `deployVault` + `require(detf == predicted)`.  
- [ ] Shared test file exists with units A/B/C on all four contracts.  
- [ ] Listed scripts compile (`forge build --skip test`) and use typed `deployVault(args, nonce)`.  
- [ ] §5 `forge test --match-path` set all green (default profile).  
- [ ] §6 greps pass.  
- [ ] §3.12 docs patched.  
- [ ] No `via_ir`. No `new` DFPkg/facet. No SUT mocks.

---

## 8. Open questions

None. Product locks are PRD v0.2. This plan names every file, function body, script artifact key, test contract, and `forge` command.

---

## 9. Revision log

| Date | Rev | Change |
|------|-----|--------|
| 2026-08-16 | **v1.0** | First plan from Accepted PRD v0.2. |
