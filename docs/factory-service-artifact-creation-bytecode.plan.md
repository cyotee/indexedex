# Implementation plan: FactoryService artifact creation bytecode

- **PRD:** `docs/factory-service-artifact-creation-bytecode.md`
- **Created:** 2026-09-02
- **Status:** ready for `/goal`

This file is the execute artifact. `/goal` should be given **this path**. Implementors follow this plan and the PRD; they do not invent requirements.

## Objective

IndexedEx FactoryService libraries load creation bytecode from Foundry `out/` via `ArtifactCreationCode.creationCode("File.sol:ContractName")` instead of importing implementations for `type(C).creationCode` / `type(C).name`. Crane implementations those services deploy are compiled by `CraneFactoryArtifactSeed.sol` under `src`. CREATE3 salts, labels, helper names, and deploy routing stay. TestBases that already `using` a FactoryService stay on that path.

## In scope

- New `contracts/utils/foundry/ArtifactCreationCode.sol`
- New `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`
- Rewrite the 55 IndexedEx `*FactoryService*.sol` files that currently embed `type().creationCode`
- Agent-law note in `docs/agent/INDEXEDEX_AGENT_LAW.md` **Build & Test Commands**
- Grep / import / artifact-file confirmation (no new product tests, no compile-cache timing experiment)

## Out of scope

- Do not rewrite leftover `type().creationCode` in TestBases, scripts, or helpers
- Do not rewrite Crane `lib/crane/contracts/**/*FactoryService.sol` (`AccessFacetFactoryService`, `IntrospectionFacetFactoryService` stay on `IndexedexTest`)
- Do not rewrite wrapper FactoryServices with no `type().creationCode` (list under Do not)
- Do not rewrite empty stub `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterFactoryService.sol`
- Do not move interfaces into new files
- Do not change CREATE3 factories, vault-registry `deployPkg`, hook-factory routing, salts, labels, or deploy helper signatures
- Do not parse ABI JSON; do not use `vm.getDeployedCode`
- Do not put `vm.getCode` on an on-chain production path
- Do not delete or clean `out/` / `cache_forge/`
- Do not enable `via_ir`
- Do not add a CI compile-time size or benchmark gate
- Do not import `CraneFactoryArtifactSeed.sol` from FactoryServices, TestBases, or scripts
- Do not compile all of `lib/crane` or add Crane paths to `src`
- Do not edit `Claude.md`
- Do not add new TestBases or product tests

## Decisions (locked)

| ID | Decision |
|----|----------|
| D1 | Scope is IndexedEx `contracts/**/*FactoryService*.sol` that today use `type().creationCode` (55 files). Crane FactoryServices are out. |
| D2 | Load creation bytecode with `vm.getCode("File.sol:ContractName")` behind `ArtifactCreationCode`. Do not hand-parse `out/*.json` with `stdJson`. |
| D3 | Salts and labels become string literals equal to current `type(C).name`. |
| D4 | TestBases are confirmation-only. Do not migrate leftover TestBase `type().creationCode`. |
| D5 | Wrapper Component / Pkg-init FactoryServices with no `type().creationCode` are not rewritten. |
| D6 | Empty stub `BalancerV3StandardExchangeRouterFactoryService.sol` is skipped. |
| D7 | Do not relocate interfaces. Co-located `IFoo` imports from `Foo.sol` may remain. |
| D8 | Helper path is `contracts/utils/foundry/ArtifactCreationCode.sol`. |
| D9 | Agent law lives in `docs/agent/INDEXEDEX_AGENT_LAW.md`. Missing artifact reverts via `vm.getCode`. |
| D10 | Keep `type(C).creationCode` only for unlinked artifacts (`__$`). Not a general fallback. |
| D11 | Done means grep + hub import check. No compile-cache smoke. |
| D12 | API is `ArtifactCreationCode.creationCode(string memory artifactId_)`. No `using` for `string`. `__$` reverts with a string that includes the artifact id. |
| D13 | Salt rewrite replaces only `type(C).name`. Extra `abi.encode` components (including `pkgInitArgs`) stay. Uni V3/V4 `bytes.concat(..., abi.encode(executionDelegate))` stays. Existing `create3` / `deployFacet` / `deployPackageWithArgs` / `deployPkg` stay. |
| D14 | Crane-sourced deploy targets compile via `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` (nine imports). FactoryServices load those bytes with `ArtifactCreationCode.creationCode`. |

## Rewrite recipe (every rewrite-set file)

Apply this transform. Do not invent a second pattern.

1. Add `import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";`
2. For each `type(C).creationCode`:
   - Artifact id is `File.sol:C` where `File.sol` is the **source filename** of the current implementation import (last path segment) and `C` is the Solidity contract identifier (`type(C).name` today).
   - Example: `import {FeeCollectorManagerFacet} from "contracts/fee/collector/FeeCollectorManagerFacet.sol"` → `"FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet"`.
   - Example: `BalancerV3PoolTokenFacet` is imported from `BetterBalancerV3PoolTokenFacet.sol` → `"BetterBalancerV3PoolTokenFacet.sol:BalancerV3PoolTokenFacet"`.
   - Never a bare contract name. Never a filesystem `out/` prefix.
   - Replace `type(C).creationCode` with `ArtifactCreationCode.creationCode("File.sol:C")`.
3. Constructor-arg concat stays: `bytes.concat(type(C).creationCode, abi.encode(executionDelegate))` becomes `bytes.concat(ArtifactCreationCode.creationCode("File.sol:C"), abi.encode(executionDelegate))`. This exists on Uni V3/V4 In/Out facets.
4. Deploy callee stays: `create3` (execution delegates), `deployFacet`, `deployPackageWithArgs`, or `vaultRegistry.deployPkg`.
5. Salts: keep today’s `abi.encode(...)` argument list. Only `type(C).name` becomes the string literal `"C"`.
   - `abi.encode(type(C).name)._hash()` → `abi.encode("C")._hash()`
   - `abi.encode(type(FeeCollectorDFPkg).name, pkgInitArgs)._hash()` → `abi.encode("FeeCollectorDFPkg", pkgInitArgs)._hash()`
6. `vm.label` / `HEVM.label` second argument: same string literal `"C"` (or the existing non-`type()` string if already a literal, e.g. `"FeeCollectorProxy"`).
7. Drop implementation imports used only for `type()`. Keep interface imports (`IFacet`, `ICreate3FactoryProxy`, `I*DFPkg`, `PkgInit` / `PkgArgs` on the interface).
8. Co-located interface (D7): `import {IFoo, Foo} from "Foo.sol"` becomes `import {IFoo} from "Foo.sol"`. Do not create a new interface file. Hub examples: `IFeeCollectorDFPkg` from `FeeCollectorDFPkg.sol`, `IIndexedexManagerDFPkg` from `IndexedexManagerDFPkg.sol`, `IERC4626PermitDFPkg` from `ERC4626PermitDFPkg.sol`.
9. Public helper names and `using X for ICreate3FactoryProxy` / `IIndexedexManagerProxy` / `IVaultRegistryDeployment` stay. Do not change TestBases or call sites.
10. **Unlinked exception (D10):** after `forge build`, if `out/File.sol/C.json` creation bytecode (`.bytecode.object`) contains `__$`, restore `type(C).creationCode` and the implementation import for **that deploy helper only**. Add the comment `// unlinked artifact; type().creationCode required` on that helper. Do not use `type()` as a general fallback.

## Work order

### Step 1: ArtifactCreationCode helper

- **Files:** create `contracts/utils/foundry/ArtifactCreationCode.sol` (directory `contracts/utils/foundry/` is new)
- **Do:** IndexedEx Foundry-only library, SPDX `BSL-1.1`, `pragma solidity ^0.8.0`.
  - Import `{Vm}` from `forge-std/Vm.sol` and `{VM_ADDRESS}` from `@crane/contracts/constants/FoundryConstants.sol`.
  - `Vm internal constant VM = Vm(VM_ADDRESS);`
  - Exact API: `function creationCode(string memory artifactId_) internal returns (bytes memory)`.
  - Body: `bytes memory bytecode_ = VM.getCode(artifactId_);` then scan for the three-byte sequence `0x5f, 0x24, 0x5f` (`_`, `$`, `_`). If found, `revert(string.concat("ArtifactCreationCode: unlinked bytecode ", artifactId_));`. Otherwise return `bytecode_`.
  - Do not name the function `getCode`. Do not add `using` for `string`. Do not call `vm.getDeployedCode`. Do not parse JSON. Do not hard-code an `out/` prefix. Missing artifact is `vm.getCode`’s own revert.
- **Tests:** none (PRD: no new product tests)
- **Done when:** the file exists with that exact function signature and `__$` revert string.

### Step 2: Crane Factory artifact seed

- **Files:** create `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`
- **Do:** SPDX `BSL-1.1`, `pragma solidity ^0.8.0`. Library `CraneFactoryArtifactSeed`. Import exactly these nine implementations and reference each with `type(C).name` in one `internal pure` function (so solc cannot drop the imports). Do **not** call `type(C).creationCode`. Do **not** import this file from FactoryServices, TestBases, or scripts.

  | Identifier | Import path |
  |------------|-------------|
  | `ERC20Facet` | `@crane/contracts/tokens/ERC20/ERC20Facet.sol` |
  | `ERC2612Facet` | `@crane/contracts/tokens/ERC2612/ERC2612Facet.sol` |
  | `ERC4626Facet` | `@crane/contracts/tokens/ERC4626/ERC4626Facet.sol` |
  | `ERC5267Facet` | `@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` |
  | `ERC4626PermitDFPkg` | `@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol` |
  | `BalancerV3VaultAwareFacet` | `@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareFacet.sol` |
  | `BalancerV3PoolTokenFacet` | `@crane/contracts/protocols/dexes/balancer/v3/vault/BetterBalancerV3PoolTokenFacet.sol` |
  | `BalancerV3AuthenticationFacet` | `@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3AuthenticationFacet.sol` |
  | `BalancerV3ConstantProductPoolFacet` | `@crane/contracts/protocols/dexes/balancer/v3/pool-constProd/BalancerV3ConstantProductPoolFacet.sol` |
- **Tests:** none
- **Done when:** the seed imports those nine types only, uses `type(C).name` (not `creationCode`), and is not imported elsewhere.

### Step 3: Rewrite hub FactoryServices

- **Files:**
  - `contracts/fee/collector/FeeCollectorFactoryService.sol`
  - `contracts/manager/IndexedexManagerFactoryService.sol`
- **Do:** Apply the rewrite recipe. Drop facet implementation imports. Keep `IFeeCollectorDFPkg` from `FeeCollectorDFPkg.sol` and `IIndexedexManagerDFPkg` from `IndexedexManagerDFPkg.sol` (D7). FeeCollector DFPkg salt stays `abi.encode("FeeCollectorDFPkg", pkgInitArgs)._hash()`.
- **Tests:** none new. These remain the `IndexedexTest` deploy path.
- **Done when:** neither file contains `type(...).creationCode` or `type(...).name` except an annotated unlinked helper. Neither imports the facet implementations it deploys.

### Step 4: Rewrite Crane-importing FactoryServices

- **Files:**
  - `contracts/vaults/VaultComponentFactoryService.sol`
  - `contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol`
- **Do:** Apply the rewrite recipe. Drop the nine Crane implementation imports (they live in the seed). Keep `IERC4626PermitDFPkg` from `ERC4626PermitDFPkg.sol` if the return type needs it (D7). Artifact id for the pool-token facet is `BetterBalancerV3PoolTokenFacet.sol:BalancerV3PoolTokenFacet`. Keep IndexedEx vault-facet / pkg artifact ids from their `contracts/` source filenames.
- **Tests:** none new
- **Done when:** those two files do not import the Crane facet implementations they deploy. They call `ArtifactCreationCode.creationCode` for those deploys (unless annotated unlinked).

### Step 5: Rewrite remaining FactoryServices

- **Files:** the other 51 rewrite-set files:

```
contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol
contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol
contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_FactoryService.sol
contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHook_FactoryService.sol
contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol
contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol
contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol
contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol
contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService.sol
contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol
contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol
contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol
contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol
contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol
contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol
contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_FactoryService.sol
contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePool_FactoryService.sol
contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_FactoryService.sol
contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPool_FactoryService.sol
contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPool_FactoryService.sol
contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPool_FactoryService.sol
contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol
contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol
contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol
contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol
contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol
contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol
contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol
contracts/protocols/lending/aave/v3.6/AaveV3Stata_Component_FactoryService.sol
contracts/protocols/staking/etherfi/EtherFiWeETH_Component_FactoryService.sol
contracts/protocols/staking/lido/LidoWstETH_Component_FactoryService.sol
contracts/protocols/staking/rocket-pool/RocketPoolRETH_Component_FactoryService.sol
contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol
contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol
contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Facet_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Pkg_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetf_Facet_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetf_Pkg_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVault_Facet_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Pkg_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Facet_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Pkg_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Facet_FactoryService.sol
contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Pkg_FactoryService.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol
contracts/vaults/standard/erc4626/ERC4626StandardExchange_Component_FactoryService.sol
contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol
```

- **Do:** Apply the rewrite recipe to every file. Uni V3 (`UniswapV3_Component_FactoryService.sol`) and Uni V4 (`UniswapV4_Component_FactoryService.sol`) keep `create3` for execution delegates and `bytes.concat(..., abi.encode(executionDelegate))` for In/Out facets.
- **Tests:** none new
- **Done when:** `rg 'type\([^)]+\)\.creationCode' contracts --glob '*FactoryService*.sol'` has no matches except annotated unlinked helpers. The empty stub still has none.

### Step 6: Agent law

- **Files:** root `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`
- **Do:** Treat this as project law for all agents:
  - IndexedEx FactoryServices load creation bytecode from `out/` via `ArtifactCreationCode.creationCode("File.sol:ContractName")` (`vm.getCode`). They do not import Facet/DFPkg implementations solely for `type().creationCode`.
  - After any production contract change, agents run **`forge build` then `forge test`** (same for `forge script`). `forge test` alone can CREATE3-deploy stale `out/` bytecode because the test graph no longer imports the implementation.
  - `forge build` compiles `src = 'contracts'`, including `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`, which is the compile root for Crane implementations those services deploy.
  - A `forge build` is also required when artifacts are missing (empty worktree `out/`, deleted cache, or a command that skips compiling `contracts/`).
  - Missing artifact: `vm.getCode` reverts (no matching artifact). That is expected. Do not deploy empty bytecode.
  - Do not delete `CraneFactoryArtifactSeed.sol`. Do not import it from TestBases or FactoryServices.
  - Worktree seed (`cache_forge/` + `out/` from a warm checkout) stays in force; `out/` is load-bearing for FactoryService deploys.
  - Root `CLAUDE.md` always-on item 10 states the operational command. Full mechanism lives in agent law § FactoryService creation bytecode.
  - In **Critical: CREATE3 Factory Deployment**, keep the `never new` rule. Change the IndexedEx FactoryService illustration so it does not teach `type(MyFacet).creationCode` as the IndexedEx path. Crane FactoryServices (`AccessFacetFactoryService`, `IntrospectionFacetFactoryService`) still use `type().creationCode`.
- **Tests:** none
- **Done when:** `CLAUDE.md` item 10 exists and the agent-law subsection exists.

### Step 7: Unlinked scan and confirmation greps

- **Files:** only rewrite-set helpers that prove unlinked (if any)
- **Do:** After the first `forge build` (see Verification), search creation bytecode for `__$`. For each rewrite-set contract whose artifact is unlinked, restore `type(C).creationCode` on that one helper with the required comment. Then run the Verification commands.
- **Tests:** none new. Do not add a compile-cache timing experiment. Do not run the full hermetic suite as a ship gate.
- **Done when:** Verification commands pass.

## Acceptance criteria

- [ ] `contracts/utils/foundry/ArtifactCreationCode.sol` exists and exposes `function creationCode(string memory artifactId_) internal returns (bytes memory)`.
- [ ] Callers pass `File.sol:ContractName`. The helper does not hard-code an `out/` prefix.
- [ ] The helper returns creation bytecode (`vm.getCode` / `.bytecode.object`), not ABI JSON and not `vm.getDeployedCode`.
- [ ] If bytecode contains `__$`, the helper reverts with a string that includes the artifact id (`ArtifactCreationCode: unlinked bytecode ` + id). Missing artifact is `vm.getCode`’s revert.
- [ ] FactoryServices pass that bytecode into the existing `create3` / `deployFacet` / `deployPackageWithArgs` / `deployPkg` call. Uni V3/V4 constructor concat stays.
- [ ] Every rewrite-set file no longer contains `type(...).creationCode` or `type(...).name`, except annotated unlinked helpers.
- [ ] Those files no longer import Facet / DFPkg / Target implementations used only for `type()`, except annotated unlinked helpers.
- [ ] Interface imports stay. Co-located `IFoo` from `Foo.sol` may remain.
- [ ] CREATE3 salts keep today’s `abi.encode` argument list; only `type(C).name` became the equal string literal.
- [ ] `vm.label` strings stay the same contract identifier.
- [ ] Public helper names and `using` surfaces stay so TestBases and scripts do not need call-site rewrites.
- [ ] Wrapper FactoryServices in the PRD inventory are not rewritten for bytecode loading.
- [ ] `contracts/test/IndexedexTest.sol` still deploys through `FeeCollectorFactoryService` and `IndexedexManagerFactoryService` (and Crane Access / Introspection, unre-written).
- [ ] No new TestBases. Leftover TestBase `type().creationCode` is not migrated.
- [ ] `grep` of `*TestBase*.sol` plus `IndexedexTest.sol` still finds the family FactoryService name for each rewrite-set service that had TestBase or hub usage at PRD time.
- [ ] `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` exists under `src`, imports the nine Crane implementations, references `type(C).name` only, and is not imported by FactoryServices / TestBases / scripts.
- [ ] `VaultComponentFactoryService` and `BalancerV3ConstantProductPool_FactoryService` drop Crane implementation imports and load bytecode with `ArtifactCreationCode.creationCode`.
- [ ] After `forge build`, `out/` contains creation-bytecode artifacts for those nine Crane contracts. Do not rely on `forge test` alone to emit them.
- [ ] Root `CLAUDE.md` item 10 (always-on) and `docs/agent/INDEXEDEX_AGENT_LAW.md` § FactoryService creation bytecode state: after production edits, `forge build` then `forge test` / `forge script`. Artifact / seed / missing-artifact rules are in the law file.
- [ ] `rg 'type\([^)]+\)\.creationCode' contracts --glob '*FactoryService*.sol'` has no matches except annotated unlinked helpers. Empty stub stays empty.
- [ ] `IndexedexManagerFactoryService.sol`, `VaultComponentFactoryService.sol`, and `BalancerV3ConstantProductPool_FactoryService.sol` do not import the facet implementations they deploy. Crane facet imports for those deploy targets live only in the seed.
- [ ] No compile-cache timing experiment. No new product tests.

## Verification

Worktree compile seed: if this checkout’s `out/` or `cache_forge/` is empty, copy them from a warm checkout before the first `forge build` (CLAUDE.md worktree seed rule). Do not delete `out/` or `cache_forge/` as part of this work.

Forge patience: `forge build` / `forge test` cold compiles commonly take 20–40+ minutes with little output. Wait for process exit. Never kill `forge` / `solc`. If a tool requires a timeout, set it to 2–4 hours for a first compile, not 10–20 minutes.

```bash
# 1. Compile src (emits IndexedEx + seed-pulled Crane artifacts). Wait for exit.
forge build

# 2. FactoryServices have no type().creationCode except annotated unlinked helpers.
rg 'type\([^)]+\)\.creationCode' contracts --glob '*FactoryService*.sol'
# Expect: no matches, OR every match line also contains:
#   unlinked artifact; type().creationCode required
# Expect: no matches in
#   contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterFactoryService.sol

# 3. Hub / vault-component / const-prod do not import the facet implementations they deploy.
rg 'import \{[^}]*FeeCollectorManagerFacet' contracts/fee/collector/FeeCollectorFactoryService.sol
rg 'import \{[^}]*VaultFeeOracleQueryFacet|import \{[^}]*VaultRegistryDeploymentFacet|import \{[^}]*IndexedexManagerDFPkg,' contracts/manager/IndexedexManagerFactoryService.sol
rg 'import \{ERC20Facet|import \{ERC2612Facet|import \{ERC4626Facet|import \{ERC5267Facet|import \{IERC4626PermitDFPkg, ERC4626PermitDFPkg|import \{ERC4626PermitDFPkg' contracts/vaults/VaultComponentFactoryService.sol
rg 'import \{[^}]*BalancerV3VaultAwareFacet|import \{[^}]*BalancerV3PoolTokenFacet|import \{[^}]*BalancerV3AuthenticationFacet|import \{[^}]*BalancerV3ConstantProductPoolFacet' contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol
# Expect: no matches. (IERC4626PermitDFPkg-only import from ERC4626PermitDFPkg.sol is allowed.)

# 4. Seed is the Crane compile root; FactoryServices / TestBases / scripts do not import it.
test -f contracts/utils/foundry/ArtifactCreationCode.sol
test -f contracts/utils/foundry/CraneFactoryArtifactSeed.sol
rg 'CraneFactoryArtifactSeed' contracts scripts --glob '*.sol'
# Expect: matches only in contracts/utils/foundry/CraneFactoryArtifactSeed.sol

# 5. Nine Crane artifacts exist after compile.
test -f out/ERC20Facet.sol/ERC20Facet.json
test -f out/ERC2612Facet.sol/ERC2612Facet.json
test -f out/ERC4626Facet.sol/ERC4626Facet.json
test -f out/ERC5267Facet.sol/ERC5267Facet.json
test -f out/ERC4626PermitDFPkg.sol/ERC4626PermitDFPkg.json
test -f out/BalancerV3VaultAwareFacet.sol/BalancerV3VaultAwareFacet.json
test -f out/BetterBalancerV3PoolTokenFacet.sol/BalancerV3PoolTokenFacet.json
test -f out/BalancerV3AuthenticationFacet.sol/BalancerV3AuthenticationFacet.json
test -f out/BalancerV3ConstantProductPoolFacet.sol/BalancerV3ConstantProductPoolFacet.json

# 6. Wrappers were not rewritten for bytecode loading.
rg 'ArtifactCreationCode' \
  contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol \
  contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol \
  contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Component_FactoryService.sol \
  contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetf_Component_FactoryService.sol \
  contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol
# Expect: no matches

# 7. IndexedexTest still uses hub FactoryServices (not migrated off).
rg 'FeeCollectorFactoryService|IndexedexManagerFactoryService' contracts/test/IndexedexTest.sol
# Expect: both names present

# 8. TestBases still mention family FactoryServices (confirmation grep, not a migration).
rg -l 'FactoryService' --glob '*TestBase*.sol' contracts test/foundry | wc -l
# Expect: on the order of the PRD snapshot (97 of 422 at PRD time). Do not fail on small drift from unrelated files.
# Spot-check: each rewrite-set service that the PRD listed as TestBase/hub-used still appears in *TestBase*.sol or IndexedexTest.sol.

# 9. Agent law
rg 'ArtifactCreationCode' docs/agent/INDEXEDEX_AGENT_LAW.md
rg 'CraneFactoryArtifactSeed' docs/agent/INDEXEDEX_AGENT_LAW.md
# Expect: both present under Build & Test Commands. Claude.md is unchanged.
```

Do not add a compile-time benchmark. Do not treat full-suite `forge test` as the done gate. Existing TestBases that already deploy through FactoryService remain the behavioral check if someone runs them later.

## Do not

- Do not change files outside the Files lists without a PRD update
- Do not reopen locked decisions
- Do not add scope from Non-goals
- Do not rewrite `lib/crane/**/*FactoryService.sol`
- Do not rewrite the five wrapper FactoryServices or the empty router stub
- Do not migrate TestBase `type().creationCode`
- Do not import `CraneFactoryArtifactSeed.sol` from FactoryServices, TestBases, or scripts
- Do not kill `forge` / `solc` mid-compile
- Do not enable `via_ir`
- Do not delete `out/` or `cache_forge/`
