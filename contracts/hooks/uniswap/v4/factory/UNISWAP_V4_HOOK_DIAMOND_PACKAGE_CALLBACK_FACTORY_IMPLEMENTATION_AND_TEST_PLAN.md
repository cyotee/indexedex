# Uniswap V4 Hook Diamond Package Callback Factory — Implementation & Test Plan

**Package name (frozen):** `UniswapV4HookDiamondPackageCallBackFactory`  
**Date:** 2026-08-04  
**Status:** **Ready to implement** against PRD **v1.1**  
**Package path:** `contracts/hooks/uniswap/v4/factory/`  
**Authority:**

| Layer | Role |
|-------|------|
| **[PRD v1.1](./UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md)** | Product law (do not re-litigate) |
| **This plan** | Source of truth for implementors: file layout, APIs, salt helpers, registry surface, phases, tests |
| Consumer (Single SE Buffer CP Hook) | Blocks on factory DoD; separate package |

**Skills (mandatory before coding):**

- Crane: `crane-deployment`, `crane-architecture`, `crane-testing`, `crane-code-style`
- IndexedEx: `indexedex-testing` (registry path, TestBase ladder, no mock SUT)
- Peer reference: `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` (copy structure; **change salt + mine + package interface**)

---

## 0. Plan-owned locks (finalize PRD soft spots)

These choices were left to the plan in PRD v1.1 and are **LOCKED** here.

| ID | Lock |
|----|------|
| **P1** | Salt composition (already PRD): `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` with `packageSalt = pkg.calcSalt(processedArgs)` and **no** `address(pkg)`. |
| **P2** | Flag mask / loop: `FLAG_MASK = Hooks.ALL_HOOK_MASK`; `MAX_LOOP = 160_444` (peer `HookMiner`). Expose as `public constant` on factory interface. |
| **P3** | Package adaptor: use Crane `DiamondFactoryPackageAdaptor` (`_calcSalt`, `_processArgs`, `_initAccount`) for the same delegatecall semantics as the vault factory. |
| **P4** | Immutability mechanism: **mirror vault factory** — base cuts = ERC165 + Loupe + ERC8109 + **PostDeploy only** (no diamondCut facet in base cuts). Initial cuts applied via `ERC2535Repo._processFacetCuts` inside factory `initAccount` (proxy context). `postDeploy` **removes** PostDeploy hook. Additionally, factory `postDeployFacetCuts()` **removes** `IDiamond.diamondCut.selector` if present (belt-and-suspenders if a package incorrectly added cut). Packages **must not** include diamondCut in `diamondConfig`. |
| **P5** | Instance `requiredHookFlags()` view: factory installs shared **`UniswapV4HookFlagsFacet`** as a base cut on every proxy; factory writes flags into `UniswapV4HookFlagsRepo` during `initAccount` from package pure flags. Packages do not re-declare the selector unless they need a superseding product surface. |
| **P6** | Thin `isExpectedInstance` (stub + guidance): `proxy.code.length > 0 && (uint160(proxy) & FLAG_MASK) == (requiredHookFlags() & FLAG_MASK)`. Factory does **not** deep-compare facets. |
| **P7** | Production deploy path: prefer **`deployWithMineNonce`**. Keep **`deploy`** (auto-mine) with NatSpec gas warning. Optional view `findMineNonce(pkg, pkgArgs)` **not** required for v1 DoD (off-chain mine in tests/scripts). |
| **P8** | Factory singleton deploy: CREATE3 via `UniswapV4HookDiamondPackageCallBackFactory_FactoryService` + `create3Factory`; salt = `keccak256("UniswapV4HookDiamondPackageCallBackFactory")` (or typed hash helper consistent with peer FactoryServices). |
| **P9** | Manager wiring for registry: new **`UniswapV4HookDiamondPackageFactoryAwareRepo`** on IndexedexManager (slot under IndexedEx namespace) holding `IUniswapV4HookDiamondPackageCallBackFactory`. Init via manager bootstrap / test setup (peer `DiamondPackageFactoryAwareRepo`). |
| **P10** | Vault Registry deployment extension (**PRD F40 in DoD**): add to `IVaultRegistryDeployment` + target + facet selectors: |
| | `deployHookVault(IStandardVaultPkg pkg, bytes calldata pkgArgs, uint256 mineNonce) external returns (address vault)` |
| | Behavior: auth = same as `deployVault` (`_onlyOwnerOrOperatorOrPkg`); pkg must be registered + not disabled; cast pkg to `IUniswapV4HookDiamondPackage`; call `hookFactory.deployWithMineNonce(...)`; `VaultRegistryVaultRepo._registerVault(vault, pkg, IStandardVault(vault).vaultConfig())`; return vault. |
| **P11** | Optional convenience (same ACL): `deployHookVaultAutoMine(IStandardVaultPkg pkg, bytes calldata pkgArgs)` → `hookFactory.deploy(...)` then register. Include for hermetic parity with factory auto-mine; production callers use mineNonce form. |
| **P12** | Stub package implements: `IUniswapV4HookDiamondPackage` + minimal `IStandardVault` / `IStandardVaultPkg` surfaces required for registry smoke (`vaultDeclaration`, `vaultConfig`, thin `isExpectedInstance`, pure flags, PRODUCT_ID in `calcSalt`). |
| **P13** | Events: factory emits `HookDiamondDeployed(address indexed proxy, address indexed pkg, bytes32 packageSalt, uint256 mineNonce, uint160 flags)` **only** on first CREATE2 success (not on idempotent return). Registry may emit existing vault-register events via `_registerVault`. |
| **P14** | Errors (factory): `HookMineExhausted()`, `HookDeployCollision(address proxy)`, `InvalidHookFlags(address predicted, uint160 got, uint160 want)`, `ZeroAddress()`, reuse peer `DeploymentAddressMismatch` if CREATE2 mismatches. |
| **P15** | `calcAddress` / views: pure CREATE2 prediction using **same** salt law; must match deploy. Provide `previewFinalSalt(bytes32 packageSalt, uint256 mineNonce)` as public pure/view helper. |
| **P16** | ProcessArgs for off-chain: stub `processArgs` is pure identity (or passthrough); NatSpec on factory: off-chain miners must apply the same `processArgs` rules as on-chain before `calcSalt`. |
| **P17** | Fork RPCs: use existing IndexedEx fork TestBase patterns under `test/foundry/fork/{ethereum_main,base_main,robinhood_4663}/`. Smoke only: deploy factory + stub package + one premine deploy. |
| **P18** | No Crane promotion in v1; do not modify `DiamondPackageCallBackFactory` salt law. |

---

## 1. Goals / non-goals

### 1.1 Goals

1. Ship production **Hook Diamond Package Callback Factory** per PRD F1–F44 / DoD §11.  
2. CREATE2 `MinimalDiamondCallBackProxy` with package-**out**-of-salt + V4 flag mining.  
3. Premine-first + auto-mine; pure `requiredHookFlags`; thin package `isExpectedInstance`; first-deployer-wins.  
4. Install-then-remove immutability (P4).  
5. FactoryService CREATE3 singleton + TestBase.  
6. Vault Registry deployment interface extension + register smoke (H15).  
7. Hermetic H1–H15 + fork smokes FK1–FK3.  
8. Unblock Single SE Buffer CP Hook (consumer) coding against this factory.

### 1.2 Non-goals (v1)

- Changing vault factory salt law.  
- Migrating existing monomorph V4 hooks.  
- Full vanity mining beyond flag bits.  
- Deep facet-set equality on idempotent path.  
- Full Vault Registry UI / product redesign.  
- Single SE CP hook product implementation (consumer plan).  
- On-chain `findMineNonce` as DoD.  

---

## 2. Target package layout

```text
contracts/hooks/uniswap/v4/factory/
  UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md
  UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4HookDiamondPackage.sol
    IUniswapV4HookDiamondPackageCallBackFactory.sol
    IUniswapV4HookFlags.sol                    # optional thin instance surface

  libs/  # or common/
    UniswapV4HookDiamondCreate2Lib.sol         # create2 predict + flag check pure helpers

  UniswapV4HookFlagsRepo.sol                   # diamond storage for flags on instances
  facets/
    UniswapV4HookFlagsFacet.sol                # requiredHookFlags() view on proxies
  targets/
    UniswapV4HookFlagsTarget.sol               # if Crane facet/target split used

  UniswapV4HookDiamondPackageCallBackFactory.sol
  UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol

  stubs/
    IUniswapV4HookDiamondFactoryStubPackage.sol
    UniswapV4HookDiamondFactoryStubPackage.sol

  TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol

# Registry / manager touchpoints (existing trees)
contracts/interfaces/
  IVaultRegistryDeployment.sol                 # extend
  IUniswapV4HookDiamondPackageFactoryAware.sol # optional manager surface

contracts/registries/vault/
  VaultRegistryDeploymentTarget.sol            # deployHookVault*
  VaultRegistryDeploymentFacet.sol             # selectors

contracts/manager/  # or existing aware wiring path
  # wire UniswapV4HookDiamondPackageFactoryAwareRepo init where diamondPackageFactory is set

# Optional aware repo colocated with factory or under registries/manager
contracts/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondPackageFactoryAwareRepo.sol

test/foundry/spec/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Deploy.t.sol
  UniswapV4HookDiamondFactory_Salt.t.sol
  UniswapV4HookDiamondFactory_Flags.t.sol
  UniswapV4HookDiamondFactory_Idempotent.t.sol
  UniswapV4HookDiamondFactory_Premine.t.sol
  UniswapV4HookDiamondFactory_Immutable.t.sol
  UniswapV4HookDiamondFactory_Registry.t.sol

test/foundry/fork/ethereum_main/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Ethereum.t.sol
test/foundry/fork/base_main/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Base.t.sol
test/foundry/fork/robinhood_4663/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Robinhood.t.sol
```

**Naming:** production types use frozen prefix `UniswapV4HookDiamond*` / `UniswapV4HookFlags*`.

---

## 3. Architecture

### 3.1 Factory core (peer-diff from vault factory)

| Concern | Vault `DiamondPackageCallBackFactory` | This factory |
|---------|----------------------------------------|--------------|
| Proxy | `MinimalDiamondCallBackProxy` | **Same** |
| Init callback | `IFactoryCallBack.initAccount` | **Same pattern** |
| Outer salt | `keccak256(abi.encode(pkg, packageSalt))` | **`keccak256(abi.encode(packageSalt, mineNonce))`** |
| Flags | N/A | Mine / validate against pure `requiredHookFlags` |
| Idempotent | `isContract()` → return | `isContract()` → **`isExpectedInstance`** → return or collide |
| Package type | `IDiamondFactoryPackage` | **`IUniswapV4HookDiamondPackage`** |
| Base cuts | ERC165, Loupe, ERC8109, PostDeploy | **Same + HookFlags facet** |
| postDeploy | Remove PostDeploy | Remove PostDeploy **+ strip diamondCut selector if any** |

### 3.2 Deploy flow (normative)

```text
deployWithMineNonce(pkg, pkgArgs, mineNonce):
  require(address(pkg) != 0)
  packageSalt = pkg._calcSalt(pkgArgs)          // adaptor; may process internally per package
  // Prefer: processArgs first then calcSalt on processed — match vault adaptor order carefully.
  // Vault factory: _calcSalt(pkgArgs) first for prediction, then _processArgs before CREATE2.
  // This factory MUST use ONE consistent order for salt + prediction + deploy:
  //   LOCKED order (P19 below): processArgs → calcSalt(processed) for ALL salt math.
  requiredFlags = pkg.requiredHookFlags() & FLAG_MASK
  finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
  predicted = create2(this, PROXY_INIT_HASH, finalSalt)
  if (uint160(predicted) & FLAG_MASK) != requiredFlags:
    revert InvalidHookFlags(predicted, uint160(predicted) & FLAG_MASK, requiredFlags)
  if predicted.code.length > 0:
    if !pkg.isExpectedInstance(predicted, processedArgs): revert HookDeployCollision(predicted)
    return predicted
  // store transient pkgOfAccount / pkgArgsOfAccount / mineNonce if needed
  pkg.updatePkg(predicted, processedArgs)       // if package implements updatePkg like peers
  proxy = new MinimalDiamondCallBackProxy{salt: finalSalt}()
  require(proxy == predicted)
  pkg.postDeploy(proxy)
  IPostDeployAccountHook(proxy).postDeploy()    // removes temp hooks / cut
  emit HookDiamondDeployed(proxy, pkg, packageSalt, mineNonce, requiredFlags)
  return proxy

deploy(pkg, pkgArgs):
  for mineNonce in 0 .. MAX_LOOP-1:
    try path of deployWithMineNonce core for this nonce without requiring pre-known flags match
    // only attempt CREATE2 when flags match; on match share _deployAtSalt core
  revert HookMineExhausted()
```

### 3.3 Plan lock P19 — processArgs / calcSalt order

**LOCKED:** For this factory, salt is always computed as:

```text
processedArgs = pkg._processArgs(pkgArgs)   // adaptor delegatecall
packageSalt   = pkg.calcSalt(processedArgs) // view on package (or adaptor if needed)
```

**Do not** salt on raw `pkgArgs` if `processArgs` mutates encoding.  
Stub: `processArgs` returns input unchanged; `calcSalt` hashes `PRODUCT_ID || abi.encode(decoded binding fields)`.

> Note: vault factory currently salts via `_calcSalt(pkgArgs)` before `_processArgs`. This factory **intentionally** uses process-then-salt so off-chain preminers and on-chain deploys share one recipe (PRD F25). Document the difference in NatSpec.

### 3.4 Flag storage (instance)

**`UniswapV4HookFlagsRepo`** (ERC-1967-style Crane slot under IndexedEx/hooks namespace):

```text
struct Storage {
  uint160 requiredHookFlags;
}
```

- Written once in factory `initAccount` after base cuts: `UniswapV4HookFlagsRepo._set(pkg.requiredHookFlags() & FLAG_MASK)`.  
- Read via `UniswapV4HookFlagsFacet.requiredHookFlags()`.  
- Facet is a base cut (P5).

### 3.5 Transient factory context (peer)

Mirror vault factory mappings (or equivalent):

```text
mapping(address account => IUniswapV4HookDiamondPackage pkg) pkgOfAccount;
mapping(address account => bytes args) pkgArgsOfAccount;
```

Set **before** CREATE2; read in `initAccount` via `msg.sender` (proxy). Optional: clear after postDeploy (vault leaves them; either is fine — prefer **peer leave** for debuggability).

### 3.6 Immutability (P4 detail)

| Phase | Cuts |
|-------|------|
| Base (init) | Add: ERC165, Loupe, ERC8109, PostDeploy, **HookFlags** |
| Package (init) | Package `diamondConfig().facetCuts` + interfaces (no diamondCut) |
| postDeploy (proxy) | Remove: PostDeploy selectors; Remove: `diamondCut` selector if present |

**Test H10:** after deploy, `diamondCut` call reverts (no facet) / loupe shows no cut selector.

### 3.7 Registry path (P9–P11)

```text
IndexedexManager (aware)
  diamondPackageFactory      → vault factory (unchanged)
  hookDiamondPackageFactory  → this factory (new)

VaultRegistryDeploymentTarget.deployHookVault(pkg, pkgArgs, mineNonce):
  _onlyOwnerOrOperatorOrPkg()
  require registered + !disabled
  vault = hookFactory.deployWithMineNonce(
            IUniswapV4HookDiamondPackage(address(pkg)), pkgArgs, mineNonce)
  VaultRegistryVaultRepo._registerVault(vault, address(pkg), IStandardVault(vault).vaultConfig())
  return vault
```

**Stub package** must implement enough of `IStandardVault` / `IStandardVaultPkg` for register (minimal config: name, vault types array with a dedicated test type id, empty or sentinel fee type ids as peers do for test pkgs).

If existing test vault packages define a pattern for “minimal vault config”, copy it. Suggested stub vault type id:

```text
bytes4 constant STUB_HOOK_VAULT_TYPE = bytes4(keccak256("UniswapV4HookDiamondFactoryStub"));
```

---

## 4. Interfaces and types

### 4.1 `IUniswapV4HookDiamondPackage`

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IDiamondFactoryPackage} from "@crane/contracts/factories/diamondPkg/IDiamondFactoryPackage.sol";

interface IUniswapV4HookDiamondPackage is IDiamondFactoryPackage {
    /// @dev Package-constant. Factory masks to Hooks.ALL_HOOK_MASK.
    function requiredHookFlags() external pure returns (uint160 flags);

    /// @dev Thin first-deployer-wins acceptance. See PRD §4.5.
    function isExpectedInstance(address proxy, bytes calldata processedArgs)
        external
        view
        returns (bool);
}
```

### 4.2 `IUniswapV4HookDiamondPackageCallBackFactory`

Normative surface:

```solidity
interface IUniswapV4HookDiamondPackageCallBackFactory {
    error HookMineExhausted();
    error HookDeployCollision(address proxy);
    error InvalidHookFlags(address predicted, uint160 got, uint160 want);
    error ZeroAddress();
    error DeploymentAddressMismatch(address expected, address actual);

    event HookDiamondDeployed(
        address indexed proxy,
        address indexed pkg,
        bytes32 packageSalt,
        uint256 mineNonce,
        uint160 flags
    );

    function PROXY_INIT_HASH() external view returns (bytes32);
    function FLAG_MASK() external pure returns (uint160);
    function MAX_LOOP() external pure returns (uint256);

    function ERC165_FACET() external view returns (IFacet);
    function DIAMOND_LOUPE_FACET() external view returns (IFacet);
    function ERC8109_INTROSPECTION_FACET() external view returns (IFacet);
    function POST_DEPLOY_HOOK_FACET() external view returns (IFacet);
    function HOOK_FLAGS_FACET() external view returns (IFacet);

    /// @notice Gas-risky auto-mine from nonce 0. Prefer deployWithMineNonce in production.
    function deploy(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs)
        external
        returns (address proxy);

    function deployWithMineNonce(
        IUniswapV4HookDiamondPackage pkg,
        bytes calldata pkgArgs,
        uint256 mineNonce
    ) external returns (address proxy);

    function calcAddress(
        IUniswapV4HookDiamondPackage pkg,
        bytes calldata pkgArgs,
        uint256 mineNonce
    ) external view returns (address predicted);

    function previewFinalSalt(bytes32 packageSalt, uint256 mineNonce)
        external
        pure
        returns (bytes32 finalSalt);

    // IFactoryCallBack surface used by proxy:
    // initAccount(), pkgConfig(), postDeploy(address) — implement as peer factory
}
```

Also implement `IFactoryCallBack` (Crane) for proxy constructor callback.

### 4.3 Factory `InitArgs` (constructor)

Peer vault factory pattern:

```solidity
struct InitArgs {
    IFacet erc165Facet;
    IFacet diamondLoupeFacet;
    IFacet erc8109IntrospectionFacet;
    IFacet postDeployHookFacet;
    IFacet hookFlagsFacet;   // NEW vs vault factory
}
```

Stored as immutables. FactoryService deploys/reuses facets via CREATE3 where possible (reuse existing ERC165/Loupe/ERC8109/PostDeploy facets from Crane/IndexedEx TestBase stack; deploy HookFlags facet once).

### 4.4 Registry interface delta

```solidity
// on IVaultRegistryDeployment
function deployHookVault(
    IStandardVaultPkg pkg,
    bytes calldata pkgArgs,
    uint256 mineNonce
) external returns (address vault);

function deployHookVaultAutoMine(
    IStandardVaultPkg pkg,
    bytes calldata pkgArgs
) external returns (address vault);
```

Update `VaultRegistryDeploymentFacet.facetFuncs()` / selectors array accordingly. Ensure manager diamond cut / package that installs deployment facet includes new selectors (follow how existing manager package wires `VaultRegistryDeploymentFacet` — extend that DFPkg or manager init cuts in the same place tests already cut facets).

---

## 5. FactoryService

`UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol`:

```text
library UniswapV4HookDiamondPackageCallBackFactory_FactoryService {
  // deploy factory singleton:
  // create3Factory.deploy... with type(Factory).creationCode + abi.encode(initArgs)
  // salt: keccak256(abi.encodePacked(type(Factory).name)) or project-standard hash

  function deployUniswapV4HookDiamondPackageCallBackFactory(
    ICreate3Factory create3Factory,
    IUniswapV4HookDiamondPackageCallBackFactory.InitArgs memory initArgs
  ) internal returns (IUniswapV4HookDiamondPackageCallBackFactory);

  // typed helpers:
  function deployHook(
    IUniswapV4HookDiamondPackageCallBackFactory factory,
    IUniswapV4HookDiamondPackage pkg,
    bytes memory pkgArgs,
    uint256 mineNonce
  ) internal returns (address);

  // optional off-chain mine helper documented in NatSpec (pure Solidity loop in tests)
}
```

**Never** `new Factory()` in production or tests outside CREATE3 service path.

---

## 6. Stub package (hermetic)

`UniswapV4HookDiamondFactoryStubPackage`:

| Method | Behavior |
|--------|----------|
| `PRODUCT_ID` | `bytes32 public constant` unique stub id |
| `requiredHookFlags()` | pure; default a **sparse** flag set easy to mine (e.g. only `BEFORE_SWAP_FLAG` or peer constant used in existing hooks tests). Expose setter **only if** package is test-only via constructor immutable flags (prefer constructor-set immutable flags so pure returns constant). |
| `calcSalt(args)` | `keccak256(abi.encode(PRODUCT_ID, decoded fields))` — **no package address** |
| `processArgs` | identity |
| `diamondConfig` | minimal: optional no-op facet or empty extra cuts + interfaces for IERC165 if needed |
| `initAccount` | write a simple binding in stub repo (e.g. `uint256 value` from args) |
| `isExpectedInstance` | thin (P6) |
| `IStandardVaultPkg` | declaration with stub vault type |
| `IStandardVault.vaultConfig` | minimal struct for registry |

**Constructor args for stub:** `uint160 flags` immutable for pure `requiredHookFlags`.

**H7 exhaustion:** deploy a second stub (or same stub with flags = full mask unlikely) using flags that are hard to hit, **or** unit-test the mine loop with a test harness that overrides `MAX_LOOP` — prefer a dedicated `UniswapV4HookDiamondFactoryStubPackageImpossibleFlags` with `requiredHookFlags = type(uint160).max & FLAG_MASK` only if still statistically hittable; simplest H7: internal/unit test of loop bound via **forge test that expects revert after MAX_LOOP** with mock package returning flags that force full scan — if full 160k is too slow/gas heavy in CI, use a **test-only factory subclass** with `MAX_LOOP = 8` under `stubs/` **only if** production factory uses constant that tests also cover via constant equality test.  

**H7 practical lock (P20):**

| Approach | Choice |
|----------|--------|
| Production | `MAX_LOOP = 160_444` constant |
| Exhaustion test | Deploy factory **test double** `UniswapV4HookDiamondPackageCallBackFactoryMineCap` inheriting production and overriding `MAX_LOOP()` to `8` **only if** production uses virtual getter — **OR** call internal pure mine helper with injected max. Prefer: **`MAX_LOOP` public constant** + separate pure lib `mineNonce(factory, initHash, packageSalt, flags, maxLoop)` tested with `maxLoop=8`; production `deploy` calls lib with `MAX_LOOP`. H7 asserts lib reverts at 8; production constant asserted `== 160_444`. |

---

## 7. Off-chain mining recipe (NatSpec + tests)

```text
1. factory = hook diamond factory address (CREATE2 deployer)
2. initHash = factory.PROXY_INIT_HASH()
3. processed = processArgs(pkgArgs)   // same as on-chain
4. packageSalt = pkg.calcSalt(processed)
5. flags = pkg.requiredHookFlags() & FLAG_MASK
6. for mineNonce = 0 .. :
     finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
     addr = create2(factory, initHash, finalSalt)
     if (uint160(addr) & FLAG_MASK) == flags: return mineNonce
7. deployWithMineNonce(pkg, pkgArgs, mineNonce)
```

Test H13: Foundry pure computation equals `factory.calcAddress`.

---

## 8. TestBase

`TestBase_UniswapV4HookDiamondPackageCallBackFactory`:

```text
inherits: CraneTest → IndexedexTest (preferred; provides create3Factory, manager, owner)

setUp:
  1. super.setUp()
  2. Resolve/reuse base facets (ERC165, Loupe, ERC8109, PostDeploy) from Crane/IndexedEx existing deploy helpers if available; else CREATE3 deploy once
  3. CREATE3 deploy UniswapV4HookFlagsFacet
  4. FactoryService.deploy factory with InitArgs
  5. Wire hook factory into UniswapV4HookDiamondPackageFactoryAwareRepo on manager (owner prank)
  6. Ensure VaultRegistryDeploymentFacet selectors include deployHookVault* (if manager needs diamondCut to add selectors — follow IndexedexTest patterns for facet upgrades in tests)
  7. Deploy stub package via CREATE3 (not vault registry deployPkg unless testing registry path)
  8. Off-chain mine helper stores good mineNonce for stub flags
```

**Gold rule:** factory SUT is real; stub package is real DFPkg-shaped code; no `vm.mockCall` on factory.

---

## 9. Test matrix (map PRD H*/FK* → files)

### 9.1 Hermetic

| ID | File | Assert |
|----|------|--------|
| H1 | Deploy.t | Factory code at CREATE3 predicted address; immutables set |
| H2 | Deploy.t | `PROXY_INIT_HASH == keccak256(type(MinimalDiamondCallBackProxy).creationCode)` |
| H3 | Flags.t / Premine.t | Deployed address flags == package pure flags |
| H4 | Idempotent.t | Second `deploy` same args returns same address; no second `HookDiamondDeployed` (or allow 0 new events) |
| H5 | Premine.t | `deployWithMineNonce` happy path |
| H6 | Premine.t | Wrong nonce → `InvalidHookFlags` |
| H7 | Salt.t or Mine.t | Lib exhaustion with maxLoop=8; production MAX_LOOP constant == 160_444 |
| H8 | Idempotent.t / Salt.t | Two stub package **addresses** same PRODUCT_ID + args → same predicted; second returns existing |
| H9 | Deploy.t | Loupe has ERC165, Loupe, ERC8109, HookFlags |
| H10 | Immutable.t | No diamondCut after postDeploy; PostDeploy selectors gone |
| H11 | Deploy.t | Stub binding storage readable |
| H12 | Flags.t | Instance `requiredHookFlags()` == package pure |
| H13 | Salt.t | Off-chain create2 == `calcAddress` |
| H14 | Deploy.t | Event on first deploy only |
| H15 | Registry.t | `deployHookVault` registers vault; query registry returns vault/pkg |

### 9.2 Forks

| ID | File | Assert |
|----|------|--------|
| FK1 | Ethereum.t | Factory + stub + one premine deploy succeeds on fork |
| FK2 | Base.t | Same |
| FK3 | Robinhood.t | Same |

### 9.3 Suggested forge commands

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/factory/*' -vv
forge test --match-path 'test/foundry/fork/*/hooks/uniswap/v4/factory/*' -vv
```

---

## 10. Phased implementation

### Phase 0 — Spike (½–1 day)

- [x] Pure lib: `previewFinalSalt`, create2 address, flag match  
- [x] Confirm `MinimalDiamondCallBackProxy` creationCode hash stable under project solc  
- [x] Mine a known nonce for a sample flag set against a dummy factory address  

**Exit:** unit tests for lib only green (may live under factory test path).

### Phase 1 — Interfaces + flags storage/facet

- [x] `IUniswapV4HookDiamondPackage`  
- [x] `IUniswapV4HookDiamondPackageCallBackFactory`  
- [x] `UniswapV4HookFlagsRepo` + Facet/Target  
- [x] Compile-only smoke  

### Phase 2 — Factory core

- [x] Contract skeleton + InitArgs immutables  
- [x] `calcAddress` / `previewFinalSalt`  
- [x] Shared `_deployAtMineNonce`  
- [x] `deployWithMineNonce`  
- [x] `deploy` auto-mine loop  
- [x] `initAccount` base + package cuts + flags write  
- [x] `postDeploy` remove PostDeploy + strip diamondCut  
- [x] Events / errors  
- [x] NatSpec: premine-first, salt law, first-deployer-wins  

**Exit:** H2–H6, H9–H14 with stub (Phase 4 can land in parallel after interface stable).

### Phase 3 — FactoryService + CREATE3 singleton

- [x] FactoryService library  
- [x] TestBase deploys factory via service  
- [x] H1 green  

### Phase 4 — Stub package

- [x] Stub interfaces + package  
- [x] PRODUCT_ID salt  
- [x] Thin `isExpectedInstance`  
- [x] Minimal vault surfaces for registry  
- [x] H3–H8, H11–H12  

### Phase 5 — Manager aware + Vault Registry extension

- [x] `UniswapV4HookDiamondPackageFactoryAwareRepo`  
- [x] Wire init in IndexedexTest / manager bootstrap path used by TestBase  
- [x] Extend `IVaultRegistryDeployment` + Target + Facet selectors  
- [x] Ensure manager diamond exposes new selectors in test bootstrap  
- [x] H15 green  

### Phase 6 — Hermetic suite polish

- [x] All H1–H15 green  
- [x] Gas snapshot optional for auto-mine vs premine (document)  

### Phase 7 — Forks

- [x] Ethereum / Base / Robinhood 4663 smoke tests  
- [x] FK1–FK3 green (RPC-dependent; skip if no RPC in CI with clear `vm.env` pattern peers use)  

### Phase 8 — Handoff

- [x] Short handoff note in this file §12  
- [x] PRD DoD checklist ticked  
- [x] Unblock Single SE Buffer CP Hook plan to require this factory  

---

## 11. Definition of Done (implementation)

Matches PRD §11; checklist for implementor:

1. [x] Factory + interfaces + FactoryService under `contracts/hooks/uniswap/v4/factory/`  
2. [x] CREATE2 proxy + callback init  
3. [x] Salt without package address; processArgs → calcSalt → mineNonce composition  
4. [x] Premine-first + auto-mine + MAX_LOOP  
5. [x] Public PROXY_INIT_HASH  
6. [x] Pure requiredHookFlags enforced  
7. [x] Thin isExpectedInstance first-deployer-wins  
8. [x] Flags on instance via HookFlags facet  
9. [x] Install-then-remove immutability  
10. [x] HookDiamondDeployed event  
11. [x] Stub + hermetic H1–H15  
12. [x] Fork smokes FK1–FK3  
13. [x] Registry `deployHookVault*` implemented + tested  
14. [x] NatSpec complete  
15. [x] No changes to vault factory salt law  

### Handoff notes (2026-08-04)

- Run suite: `FOUNDRY_PROFILE=hook_factory forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/factory/*'`
- Salt law: **processArgs → calcSalt(processed) → keccak256(abi.encode(packageSalt, mineNonce))** (no package address)
- Wire manager: `IVaultRegistryDeployment.setHookDiamondPackageFactory(factory)` (owner/operator)
- **Product deploy path (IndexedEx standard):**  
  `HookPackage.deployVault(typedArgs, mineNonce)` → `registry.deployHookVault(pkg, abi.encode(args), mineNonce)` → hook factory → `_registerVault`  
  Gold stub: `IUniswapV4HookDiamondFactoryStubPackage.deployVault` / `deployVaultAutoMine`
- Direct `factory.deploy*` is permissionless and does **not** register vaults (tests / escape hatch only)
- Auto-mine is gas-heavy; prefer premine
- FK1 (Ethereum) opt-in: `RUN_ETH_FORK_SMOKE=true`; FK2/FK3 run with skip-on-RPC-failure
- Consumer hook packages: implement typed `deployVault` calling `deployHookVault` (never vault factory `deployVault`)

---

## 12. Consumer handoff (Single SE Buffer CP Hook)

When factory DoD is green:

1. Hook package implements `IUniswapV4HookDiamondPackage` (pure flags for the product’s V4 permissions).  
2. `calcSalt` includes stable PRODUCT_ID + binding fields (poolManager, SE, tokens, feeOracle, etc.) — **not** package/facet addresses.  
3. Thin `isExpectedInstance` (or product-equivalent that still allows package-address swap).  
4. **Deploy path:** typed `deployVault(PkgArgs, mineNonce)` on the package → `registry.deployHookVault` (package must be registered via `deployPkg`). Do not use vault factory `deployVault`.  
5. Hook product plan should **hard-block** coding of diamond deploy on factory H1–H15 green.  
6. Monomorph CREATE3 remains emergency fallback only if product plan explicitly waives.

---

## 13. Risks & mitigations (implementor)

| Risk | Mitigation |
|------|------------|
| Stack-too-deep in deploy | Internal struct context; viaIR already on in foundry.toml |
| Auto-mine OOG in tests | Prefer premine in all hermetic tests except one auto-mine smoke |
| Manager facet selector not cut | Explicit diamondCut in TestBase setup for new deployment selectors |
| Stub vaultConfig incomplete | Copy minimal vault package test pattern from SE vault TestBases |
| processArgs order confusion | P19 lock + H13/H8 tests |
| Package includes diamondCut | postDeploy strip + H10 |
| Fork RPC flake | Match peer fork skip/env patterns |

---

## 14. Open non-product notes

| Item | Note |
|------|------|
| Exact CREATE3 salt string for factory singleton | Follow peer FactoryService naming hash; document in service NatSpec |
| Whether to clear `pkgOfAccount` after postDeploy | Prefer leave (peer) |
| Manager production bootstrap script | Out of this plan’s hermetic DoD; add to deploy scripts when product ships factory live |
| Global re-export under `contracts/interfaces/` | Package-local interfaces first; re-export only if other packages need global path |

---

## 15. Revision history

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-08-04 | Initial implementation plan against PRD v1.1: process-then-salt order; HookFlags base facet; registry deployHookVault*; thin isExpectedInstance; mine lib for H7; phases 0–8 |

---

## 16. Summary for coding agents

```text
Implement: UniswapV4HookDiamondPackageCallBackFactory
PRD: ./UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md (v1.1)
Peer: Crane DiamondPackageCallBackFactory (structure yes; salt NO package addr)
Salt: processArgs → calcSalt → finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
Prod path: deployWithMineNonce; auto-mine secondary
Package: pure requiredHookFlags + thin isExpectedInstance
Instance: UniswapV4HookFlagsFacet base cut
Immutable: no live diamondCut (postDeploy remove PostDeploy + strip cut)
Registry: deployHookVault(pkg, args, mineNonce) + autoMine variant; aware repo on manager
Tests: stub + H1–H15 + ETH/Base/4663 forks
Never: new Factory(); mock factory SUT; package-in-salt; deep facet equality gate
```
