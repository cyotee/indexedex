# Flatten `SingleVaultDetfDFPkg.PkgInit.bridgeConfig` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the `ProtocolDETFSuperchainBridgeRepo.BridgeConfig bridgeConfig` field from `ISingleVaultDetfDFPkg.PkgInit` and replace it with five flat fields (`bridgeTokenRegistry`, `standardBridge`, `messenger`, `localRelayer`, `peerRelayer`), so `PkgInit` no longer surfaces a foreign repo's storage-grouping struct.

**Architecture:** Two files change. `SingleVaultDetfDFPkg.sol` flattens the `PkgInit` struct fields and updates the constructor reads. `SingleVaultDetf_Component_FactoryService.sol` updates `buildPkgInit` to project `SingleVaultDetfInfra.bridgeConfig.*` into the flat fields. The `SingleVaultDetfInfra` helper struct keeps its grouped `BridgeConfig` field on purpose — deployment scripts and tests build a single `BridgeConfig` per environment and pass it as one unit; that ergonomic grouping stays in the FactoryService boundary, but it no longer leaks into the package's public `PkgInit` interface. All existing call sites that set `bridgeConfig:` on `SingleVaultDetfInfra` continue to work without modification.

**Out of scope:** `IEthereumProtocolDETFDFPkg.PkgInit` and `IBaseProtocolDETFDFPkg.PkgInit` (in `EthereumProtocolDETF_Component_FactoryService.sol` / `BaseProtocolDETF_Component_FactoryService.sol`) have the same `bridgeConfig` pattern. The user explicitly scoped this refactor to the Single Vault DETF package; if the same change is desired there, file a follow-up plan. Do **not** change them here.

**Tech Stack:** Solidity 0.8.30, Foundry (forge), Crane Diamond Factory Package pattern.

---

## File Structure

**Modified:**
- `contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol` — flatten `PkgInit`; update constructor.
- `contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol` — update `buildPkgInit` to map flat fields.

**Unchanged (verified):**
- `contracts/vaults/detf/composed/single/SingleVaultDetf_Pkg_FactoryService.sol` — only takes `PkgInit memory` and abi-encodes it; no field-level references.
- `contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol` — `BridgeConfig` struct stays as-is; it is still consumed inside `initAccount` to call `_initialize(BridgeConfig)`.
- All deployment scripts (`scripts/foundry/**/Script_16_DeployProtocolDETF.s.sol`) and tests under `test/foundry/spec/vaults/detf/composed/single/` — they construct `SingleVaultDetfInfra` (with its grouped `bridgeConfig`), not `PkgInit` directly. The `buildPkgInit` helper still hides the mapping.

---

## Task 1: Flatten `PkgInit` struct definition

**Files:**
- Modify: `contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol:88-121`

- [ ] **Step 1: Replace the single `bridgeConfig` field with five flat fields**

In the `ISingleVaultDetfDFPkg` interface, locate the `PkgInit` struct (currently lines 88–121) and replace this line:

```solidity
        ProtocolDETFSuperchainBridgeRepo.BridgeConfig bridgeConfig;
```

with these five lines (field order matches `BridgeConfig`'s declaration in `ProtocolDETFSuperchainBridgeRepo.sol:28-34`):

```solidity
        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        address localRelayer;
        address peerRelayer;
```

After the edit, the full `PkgInit` struct should read:

```solidity
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;

        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;

        IFacet singleVaultDetfExchangeInFacet;
        IFacet singleVaultDetfExchangeInQueryFacet;
        IFacet singleVaultDetfExchangeOutFacet;
        IFacet singleVaultDetfBondingFacet;

        IFacet operableFacet;

        IVaultFeeOracleQuery feeOracle;

        IVaultRegistryDeployment vaultRegistryDeployment;

        IPermit2 permit2;

        IBalancerVault balancerV3Vault;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IWeightedPool8020Factory weightedPool8020Factory;

        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        address localRelayer;
        address peerRelayer;

        IUniswapV4StandardExchangeDFPkg wethRichVaultPkg;
        IProtocolNFTVaultDFPkg protocolNFTVaultPkg;
        IRICHIRDFPkg richirPkg;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
        IDiamondPackageCallBackFactory diamondFactory;
        IERC20 wethToken;
    }
```

Note: `ISuperChainBridgeTokenRegistry`, `IStandardBridge`, and `ICrossDomainMessenger` are already imported in this file (lines 63–65), so no new imports are needed for this task. `ProtocolDETFSuperchainBridgeRepo` is still imported and still needed inside `initAccount` (the constructor below stops using it, but `initAccount` still calls `ProtocolDETFSuperchainBridgeRepo._initialize(...)` with a `BridgeConfig` literal — do **not** remove that import).

- [ ] **Step 2: Build to surface every compiler error this change creates**

Run: `forge build`
Expected: Compilation **fails** with errors in `SingleVaultDetfDFPkg.sol` (the constructor still reads `pkgInit.bridgeConfig.*`) and in `SingleVaultDetf_Component_FactoryService.sol` (the `buildPkgInit` literal still sets `bridgeConfig:`). These are the two sites the next tasks will fix. Record the error list.

Do **not** commit yet. The codebase is mid-refactor.

---

## Task 2: Update the `SingleVaultDetfDFPkg` constructor to read flat fields

**Files:**
- Modify: `contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol:218-222`

- [ ] **Step 1: Replace the five `pkgInit.bridgeConfig.*` reads with flat-field reads**

In the constructor (currently starts at line 201), locate this block:

```solidity
        BRIDGE_TOKEN_REGISTRY = pkgInit.bridgeConfig.bridgeTokenRegistry;
        STANDARD_BRIDGE = pkgInit.bridgeConfig.standardBridge;
        BRIDGE_MESSENGER = pkgInit.bridgeConfig.messenger;
        LOCAL_RELAYER = pkgInit.bridgeConfig.localRelayer;
        PEER_RELAYER = pkgInit.bridgeConfig.peerRelayer;
```

Replace with:

```solidity
        BRIDGE_TOKEN_REGISTRY = pkgInit.bridgeTokenRegistry;
        STANDARD_BRIDGE = pkgInit.standardBridge;
        BRIDGE_MESSENGER = pkgInit.messenger;
        LOCAL_RELAYER = pkgInit.localRelayer;
        PEER_RELAYER = pkgInit.peerRelayer;
```

Leave every other constructor assignment, the immutable storage, and `initAccount` (which constructs `ProtocolDETFSuperchainBridgeRepo.BridgeConfig({...})` inline from the immutables) unchanged.

- [ ] **Step 2: Build to confirm the constructor compiles**

Run: `forge build`
Expected: `SingleVaultDetfDFPkg.sol` now compiles cleanly. The remaining compiler error is in `SingleVaultDetf_Component_FactoryService.sol` only, complaining that `bridgeConfig` is not a member of `ISingleVaultDetfDFPkg.PkgInit`. If `SingleVaultDetfDFPkg.sol` itself still errors, stop and reconcile before proceeding.

Still do not commit — the build is not yet green.

---

## Task 3: Update `buildPkgInit` in `SingleVaultDetf_Component_FactoryService`

**Files:**
- Modify: `contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol:62-86`

- [ ] **Step 1: Replace the single `bridgeConfig:` initializer with five flat ones**

In `buildPkgInit` (currently lines 57–87), inside the `ISingleVaultDetfDFPkg.PkgInit({ ... })` literal, locate this line:

```solidity
            bridgeConfig: infra_.bridgeConfig,
```

Replace it with:

```solidity
            bridgeTokenRegistry: infra_.bridgeConfig.bridgeTokenRegistry,
            standardBridge: infra_.bridgeConfig.standardBridge,
            messenger: infra_.bridgeConfig.messenger,
            localRelayer: infra_.bridgeConfig.localRelayer,
            peerRelayer: infra_.bridgeConfig.peerRelayer,
```

Field order inside a Solidity struct literal must match the struct definition. Insert the five lines in the same slot the old `bridgeConfig:` line occupied (between `weightedPool8020Factory:` and `wethRichVaultPkg:`).

After the edit, the full `buildPkgInit` body should read:

```solidity
    function buildPkgInit(SingleVaultDetfFacets memory facets_, SingleVaultDetfInfra memory infra_)
        internal
        pure
        returns (ISingleVaultDetfDFPkg.PkgInit memory pkgInit_)
    {
        pkgInit_ = ISingleVaultDetfDFPkg.PkgInit({
            erc20Facet: facets_.erc20Facet,
            erc5267Facet: facets_.erc5267Facet,
            erc2612Facet: facets_.erc2612Facet,
            multiAssetBasicVaultFacet: facets_.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: facets_.multiAssetStandardVaultFacet,
            singleVaultDetfExchangeInFacet: facets_.exchangeInFacet,
            singleVaultDetfExchangeInQueryFacet: facets_.exchangeInQueryFacet,
            singleVaultDetfExchangeOutFacet: facets_.exchangeOutFacet,
            singleVaultDetfBondingFacet: facets_.bondingFacet,
            operableFacet: facets_.operableFacet,
            feeOracle: infra_.feeOracle,
            vaultRegistryDeployment: infra_.vaultRegistryDeployment,
            permit2: infra_.permit2,
            balancerV3Vault: infra_.balancerV3Vault,
            balancerV3PrepayRouter: infra_.balancerV3PrepayRouter,
            weightedPool8020Factory: infra_.weightedPool8020Factory,
            bridgeTokenRegistry: infra_.bridgeConfig.bridgeTokenRegistry,
            standardBridge: infra_.bridgeConfig.standardBridge,
            messenger: infra_.bridgeConfig.messenger,
            localRelayer: infra_.bridgeConfig.localRelayer,
            peerRelayer: infra_.bridgeConfig.peerRelayer,
            wethRichVaultPkg: infra_.wethRichVaultPkg,
            protocolNFTVaultPkg: infra_.protocolNFTVaultPkg,
            richirPkg: infra_.richirPkg,
            rateProviderPkg: infra_.rateProviderPkg,
            diamondFactory: infra_.diamondFactory,
            wethToken: infra_.wethToken
        });
    }
```

Important ordering check: in the current `PkgInit` definition (after Task 1), `wethToken` is the **last** field. The current `buildPkgInit` already lists `wethToken: infra_.wethToken` last (after `diamondFactory:`). Keep it last. Do not reorder the existing entries beyond inserting the five new ones in the bridge slot.

Leave the `SingleVaultDetfInfra` struct definition (lines 41–55) untouched. `infra_.bridgeConfig` is still a `ProtocolDETFSuperchainBridgeRepo.BridgeConfig` and that grouping continues to serve deployment scripts and tests.

- [ ] **Step 2: Build the full project**

Run: `forge build`
Expected: Clean build, no errors. The Solidity compiler will emit a warning if any field name or order in the struct literal does not match the struct definition — if you see any such warning or error, re-check that the five bridge field names and positions match Task 1's struct exactly.

- [ ] **Step 3: Run the Single Vault DETF spec tests**

Run: `forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/*.t.sol' -vv`
Expected: All tests pass. These tests exercise four call sites that pass `bridgeConfig:` to `SingleVaultDetfInfra` (verified earlier):
- `SingleVaultDetf_BridgeTransport.t.sol:261`
- `SingleVaultDetf_ProductionBase.t.sol:235`
- `SingleVaultDetf_AuctionBondWithPosition.t.sol:263`
- `SingleVaultDetfDFPkg_Deploy.t.sol:169`

None of them needs editing because they only ever touch the `SingleVaultDetfInfra` grouping, which still has `bridgeConfig`. If any of these tests fails for a non-bridge reason, that's a pre-existing failure unrelated to this refactor — note it but do not fix it here.

If a test fails specifically with a `BridgeConfig` / `bridgeConfig` / "member not found" error, re-check Task 1's field order and Task 3's struct literal ordering.

- [ ] **Step 4: Commit**

```bash
git add contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol \
        contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol
git commit -m "refactor: flatten SingleVaultDetfDFPkg.PkgInit bridge fields

Stop surfacing ProtocolDETFSuperchainBridgeRepo.BridgeConfig in the
public PkgInit struct. Promote its five members (bridgeTokenRegistry,
standardBridge, messenger, localRelayer, peerRelayer) to flat PkgInit
fields so the package interface no longer depends on a sibling repo's
storage-grouping type.

SingleVaultDetfInfra in the Component_FactoryService keeps its grouped
BridgeConfig field — deployment scripts and tests still construct one
bridge config per environment; the FactoryService maps it into the flat
PkgInit at the boundary.

initAccount continues to build a BridgeConfig literal from the cached
immutables when calling ProtocolDETFSuperchainBridgeRepo._initialize."
```

---

## Self-Review Notes

- **Spec coverage:** The user's request — "members of [BridgeConfig] should also be members of PkgInit, to keep a clean separation of concerns" — is implemented by Task 1 (flatten) and Task 3 (mapping). Task 2 keeps the constructor consistent with the new struct shape.
- **Placeholder scan:** No TBDs, no "add appropriate error handling", every code step shows the actual code.
- **Type consistency:** Field names and types in the new `PkgInit` (Task 1) are mirrored exactly in the constructor reads (Task 2) and in the `buildPkgInit` literal (Task 3). The five names — `bridgeTokenRegistry`, `standardBridge`, `messenger`, `localRelayer`, `peerRelayer` — are the same in all three sites, matching the source-of-truth field names in `ProtocolDETFSuperchainBridgeRepo.BridgeConfig`.
- **Caller audit:** The only on-chain construction site of `ISingleVaultDetfDFPkg.PkgInit` is `SingleVaultDetf_Component_FactoryService.buildPkgInit` (verified via grep). Tests and scripts go through `buildPkgInit` and construct `SingleVaultDetfInfra` only. No other file needs edits.
