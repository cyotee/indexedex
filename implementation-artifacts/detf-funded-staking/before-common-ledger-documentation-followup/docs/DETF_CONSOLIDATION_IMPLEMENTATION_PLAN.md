# DETF Consolidation Implementation Plan

## Objective

Consolidate the current DETF families into a layered architecture that reuses shared lifecycle, accounting, and planning modules while preserving real topology differences.

Primary objective:

- enforce the DRY principle across DETF internals to reduce maintenance cost and make new DETF vault types faster to build from proven code

Hard requirements from scope clarification:

- preserve all exposed interfaces
- preserve current deployment and package processes
- consolidate internal logic only
- reuse existing facets and packages where appropriate instead of multiplying family-local copies

Current families in scope:

- Protocol DETF
- Single Vault DETF
- Composed Stable/Common DETF

Out of scope for active migration in this effort:

- Seigniorage vault product line

This plan is intentionally sequenced to reduce refactor risk:

- extract behavior before moving files
- prove abstractions in the simplest family first
- avoid storage migration until shared behavior is stable
- defer factory cleanup until runtime modules stop moving

## Target Architecture

The end state should be organized around four layers:

1. DETF core modules
2. topology adapters
3. inventory policies
4. family assemblies and package manifests

Recommended top-level layout:

```text
contracts/vaults/detf/
  core/
    DETFCoreRepo.sol
    DETFThresholdPolicy.sol
    DETFMintSplitLib.sol
    DETFTokenTransferLib.sol
    DETFPreviewLib.sol
    DETFBondLifecycleLib.sol
    DETFReservePoolStateLib.sol
    DETFRoutePlanTypes.sol
  topology/
    IDetfTopologyAdapter.sol
    SelfCommonTopologyAdapter.sol
    SingleVaultTopologyAdapter.sol
    ComposedStableCommonTopologyAdapter.sol
  inventory/
    IDetfBondInventoryPolicy.sol
    SelfNftInventoryPolicy.sol
    ProtocolNftInventoryPolicy.sol
  factory/
    DETFPackageManifest.sol
    DETFComponentFactoryBase.sol
    DETFFacetFactoryBase.sol
    DETFPkgFactoryBase.sol
  self/
    common/
    ethereum/
  composed/
    single/
    stable/common/
  reusable/
    nft/
    rebasing/
```

Naming direction:

- the current Protocol DETF common component should be renamed and restructured as `SelfCommonDETF`
- the protocol-owned NFT inventory model should be renamed `Self NFT`
- the fee-recipient NFT inventory model should be renamed `Protocol NFT`
- shared NFT and rebasing logic should live under reusable DETF directories to make reuse explicit

## Guiding Constraints

The consolidation should follow these rules:

- Do not build a single universal DETF contract with family branches.
- Do not migrate storage layouts early.
- Do not merge rebasing token logic into direct mint or burn token logic.
- Preserve all exposed interfaces and deployment flows while consolidating internals.
- Do not change `BasicVaultCommon` as part of this effort.
- Standardize reserve-pool state handling toward `WeightedPoolReserveVaultRepo`.
- Shared DETF NFT logic must converge on one reusable NFT package.
- Shared DETF rebasing logic must converge on one reusable rebasing package derived from Stable DETF code.
- Do not start with factory consolidation before runtime behavior is stabilized.

## Crane Reuse-First Policy

The DETF consolidation should prefer composing existing Crane primitives before introducing new DETF-specific helpers.

The review of the in-repo Crane contracts shows there is already meaningful overlap with the proposed DETF core layer.

The practical rule is:

- only create a new DETF core module when the behavior is DETF-specific
- otherwise wrap, compose, or lightly extend the relevant Crane primitive

Primary Crane reuse targets already identified:

- `lib/daosys/lib/crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol`
  - use as the base transfer primitive for all DETF token movement
  - `DETFTokenTransferLib` should be a thin DETF orchestration layer around this, not a replacement for it
- `lib/daosys/lib/crane/contracts/utils/math/BetterMath.sol`
  - use for common arithmetic, mulDiv behavior, bounds, rounding, and small shared math helpers
- `lib/daosys/lib/crane/contracts/utils/math/ConstProdUtils.sol`
  - reuse for constant-product quoting and reserve calculations that already exist
- `lib/daosys/lib/crane/contracts/utils/math/AerodromeUtils.sol`
  - reuse for Aerodrome-specific quote parity instead of rebuilding similar logic inside DETF core
- `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol`
  - reuse for weighted-pool exact-in and exact-out quote math
- `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol`
  - use as the canonical Balancer vault dependency storage surface
- `lib/daosys/lib/crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol`
  - reuse for Permit2 dependency storage and wiring instead of adding parallel DETF-only storage
- `lib/daosys/lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol`
  - continue using Crane reentrancy protection around execution entry points
- `lib/daosys/lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol`
  - prefer for accepted token registries or similar address membership state where applicable
- `lib/daosys/lib/crane/contracts/access/AccessFacetFactoryService.sol`
- `lib/daosys/lib/crane/contracts/introspection/IntrospectionFacetFactoryService.sol`
- `lib/daosys/lib/crane/contracts/factories/create3/Create3FactoryService.sol`
  - reuse these deployment and assembly patterns for any DETF factory cleanup work

Implications for the proposed DETF modules:

- `DETFTokenTransferLib` should focus on DETF-specific balance-delta accounting, pretransferred semantics, and route settlement sequencing while delegating raw transfers and approvals to `BetterSafeERC20`
- `DETFPreviewLib` should compose existing Balancer and AMM quote libraries rather than re-encode pool math
- `DETFReservePoolStateLib` should sit on top of `BalancerV3VaultAwareRepo` and existing quote utilities instead of creating a new generic Balancer abstraction from scratch
- any shared repo or manifest layer should align with Crane repo and factory conventions instead of inventing a second pattern family

## Indexedex Reuse-First Policy

The consolidation should also reuse existing Indexedex vault abstractions before introducing new DETF-only layers.

The Indexedex contracts already contain reusable patterns that overlap directly with the proposed DETF consolidation work.

Primary Indexedex reuse targets already identified:

- `contracts/vaults/basic/BasicVaultCommon.sol`
  - this already provides the canonical `_secureTokenTransfer(...)`, pretransferred handling, Permit2 fallback, refund logic, and self-burn behavior for vault flows
  - `DETFTokenTransferLib` should build on this behavior or promote reusable logic into DETF base layers without changing `BasicVaultCommon` itself
- `contracts/vaults/standard/WeightedPoolReserveVaultRepo.sol`
  - this already models reserve pool address, token indices, token weights, and tracked reserve contents
  - `DETFReservePoolStateLib` should reuse or extend this storage model rather than inventing an unrelated reserve-pool schema
- `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol`
  - this already contains normalized reserve-pool loading structs and diluted-price style reserve accounting patterns
  - use as reference material only; Seigniorage is not an active migration target in this consolidation
- `contracts/vaults/protocol/BaseProtocolDETFPreviewHelpers.sol`
  - this already demonstrates the repo pattern of moving plan-like preview calculations into a separate helper unit to control stack depth
  - use this as prior art for shared DETF route-plan helpers instead of introducing a completely different planner shape
- `contracts/vaults/protocol/ProtocolNFTVaultService.sol`
  - this is already a stateless inventory-service style library with parameter structs and stack-depth mitigation
  - use it as the starting point for reusable DETF NFT inventory policy extraction
- `contracts/vaults/seigniorage/SeigniorageNFTVaultCommon.sol`
  - this already holds reusable NFT vault validation behavior tied to bond terms and fee-oracle policy
  - reference only; do not pull Seigniorage migration work into this effort
- `contracts/vaults/VaultComponentFactoryService.sol`
  - this already standardizes vault-related facet and package deployment on top of Crane factory patterns
  - any DETF factory consolidation should compose this service instead of creating an independent deployment stack
- `contracts/vaults/detf/DETFCommon.sol`
- `contracts/vaults/detf/dual/DualDETFCommon.sol`
  - these are currently thin insertion points and should become the shared behavior layering surface before adding new parallel base contracts elsewhere

Implications for the proposed DETF modules:

- `DETFTokenTransferLib` should treat `BasicVaultCommon` as the canonical source for secure transfer and pretransfer semantics
- `DETFReservePoolStateLib` should align with `WeightedPoolReserveVaultRepo` as the target standard storage model
- DETF preview planning should borrow the helper extraction style already used in `BaseProtocolDETFPreviewHelpers`
- DETF inventory policies should start by extracting from `ProtocolNFTVaultService` and converging on shared DETF NFT packages, not by creating wholly new policy logic from scratch
- DETF factory cleanup should layer on `VaultComponentFactoryService` in the same way the repo already layers on Crane factory services

## Reuse Matrix

Use this matrix as the default decision table when implementing the consolidation. A new DETF abstraction should only be created when the listed sources are insufficient or materially DETF-specific behavior remains after composition.

| Planned DETF module or layer | Existing source to reuse first | Repo | Recommended action | Notes |
| --- | --- | --- | --- | --- |
| `DETFTokenTransferLib` | `contracts/vaults/basic/BasicVaultCommon.sol` | Indexedex | Extract or wrap | Canonical source for `_secureTokenTransfer`, Permit2 fallback, refunds, and self-burn semantics. |
| `DETFTokenTransferLib` | `lib/daosys/lib/crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol` | Crane | Compose | Keep raw transfer and approval behavior delegated here. |
| `DETFTokenTransferLib` | `lib/daosys/lib/crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol` | Crane | Compose | Reuse dependency storage and Permit2 wiring rather than adding DETF-only storage. |
| `DETFThresholdPolicy` | Existing `_isMintingAllowed` and `_isBurningAllowed` helpers in family commons | Indexedex | Extract | Semantics are shared even though price-signal computation stays family-local. |
| `DETFMintSplitLib` | Existing mint split helpers in `SingleVaultDetfCommon`, `BaseProtocolDETF*`, and `ComposedStableCommonDetfCommon` | Indexedex | Extract and normalize | Consolidate slice math, keep sink routing outside the lib. |
| `DETFMintSplitLib` | `lib/daosys/lib/crane/contracts/utils/math/BetterMath.sol` | Crane | Compose | Use existing arithmetic, mulDiv, min or max, and rounding helpers. |
| `DETFPreviewLib` | `contracts/vaults/protocol/BaseProtocolDETFPreviewHelpers.sol` | Indexedex | Extend pattern | Use the existing helper-unit extraction pattern to reduce stack depth. |
| `DETFPreviewLib` | `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol` | Crane | Compose | Reuse weighted-pool exact-in and exact-out quote math. |
| `DETFPreviewLib` | `lib/daosys/lib/crane/contracts/utils/math/ConstProdUtils.sol` | Crane | Compose | Reuse constant-product quote math for underlying AMM legs. |
| `DETFPreviewLib` | `lib/daosys/lib/crane/contracts/utils/math/AerodromeUtils.sol` | Crane | Compose | Reuse Aerodrome-specific quote parity helpers. |
| `DETFReservePoolStateLib` | `contracts/vaults/standard/WeightedPoolReserveVaultRepo.sol` | Indexedex | Reuse or extend | This is the current reserve-pool storage model for pool, indices, weights, and tracked contents. |
| `DETFReservePoolStateLib` | `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol` | Indexedex | Reference only | Useful prior art, but Seigniorage is out of scope for active migration in this effort. |
| `DETFReservePoolStateLib` | `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol` | Crane | Compose | Canonical Balancer vault dependency surface. |
| Shared DETF base layer | `contracts/vaults/detf/DETFCommon.sol` | Indexedex | Grow in place | Prefer turning this into the shared DETF behavior insertion point. |
| Shared DETF base layer | `contracts/vaults/detf/dual/DualDETFCommon.sol` | Indexedex | Grow in place | Natural intermediate layer for shared dual-reserve family behavior. |
| Shared fee and vault metadata access | `contracts/vaults/standard/StandardVaultRepo.sol` | Indexedex | Reuse | Keep fee oracle, vault fee type ids, vault type ids, and contents metadata aligned with standard vault storage instead of creating DETF-only copies. |
| Bond lifecycle helper | `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol` | Indexedex | Extract | One of the primary sources for lifecycle ordering and settlement behavior. |
| Bond lifecycle helper | `contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol` | Indexedex | Extract | Use as the simpler pilot source where lifecycle is close to protocol DETF. |
| Bond lifecycle helper | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondingFacet.sol` | Indexedex | Extract last | Hardest topology, should consume a proven lifecycle abstraction instead of defining it. |
| Inventory policy layer | `contracts/vaults/protocol/ProtocolNFTVaultService.sol` | Indexedex | Extract or wrap | Best current starting point for stateless DETF NFT inventory operations. |
| Inventory policy layer | `contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol` | Indexedex | Reuse via shared role alias | Keep the existing concrete package and adapt DETF consumers toward shared Self NFT and Protocol NFT policy variants without changing external deployment flow. |
| Inventory policy layer | `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` | Indexedex | Extract Self NFT semantics | Source for protocol-owned inventory behavior, to be renamed under Self NFT semantics. |
| Inventory policy layer | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol` | Indexedex | Extract Protocol NFT deltas | Source for fee-recipient NFT behavior, to be reorganized as Protocol NFT semantics. |
| Shared rebasing package | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol` | Indexedex | Reuse directly as base package | Canonical rebasing package source for cross-DETF reuse. |
| Topology adapter: self common | `contracts/vaults/protocol/BaseProtocolDETFCommon.sol` | Indexedex | Extract adapter and rename | Rename and restructure this line as `SelfCommonDETF`, keeping bridge and token-model extras outside the adapter interface. |
| Topology adapter: single vault | `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol` | Indexedex | Extract adapter first | Preferred pilot source for shared route-plan abstraction. |
| Topology adapter: composed stable/common | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol` | Indexedex | Extract adapter last | Reuse planner and lifecycle once proven elsewhere. |
| Route-plan and planner structs | `contracts/vaults/protocol/BaseProtocolDETFPreviewHelpers.sol` | Indexedex | Extend pattern | Keep heavy plan calculations in helper units when needed for compilation hygiene. |
| Factory consolidation | `contracts/vaults/VaultComponentFactoryService.sol` | Indexedex | Compose | Use as the Indexedex-specific factory layer over Crane. |
| Factory consolidation | `lib/daosys/lib/crane/contracts/access/AccessFacetFactoryService.sol` | Crane | Compose | Reuse standard access facet deployment. |
| Factory consolidation | `lib/daosys/lib/crane/contracts/introspection/IntrospectionFacetFactoryService.sol` | Crane | Compose | Reuse standard introspection facet deployment and package wiring. |
| Factory consolidation | `lib/daosys/lib/crane/contracts/factories/create3/Create3FactoryService.sol` | Crane | Compose | Preserve CREATE3 deployment conventions and service flow. |
| Reentrancy protection on execution surfaces | `lib/daosys/lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol` | Crane | Reuse directly | Do not create a DETF-specific reentrancy pattern. |
| Accepted token registry or tracked address membership | `lib/daosys/lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol` | Crane | Reuse directly | Prefer this for bond-token allowlists and similar membership state. |

### Decision Rule

When implementing any row in the matrix:

1. try direct reuse first
2. if direct reuse is too coupled, add a thin wrapper or extraction around the existing source
3. only create a new DETF-specific implementation when the remaining behavior is genuinely DETF-specific after steps 1 and 2

## Existing Code Anchors

The plan is anchored to these current seams:

- `contracts/vaults/detf/DETFCommon.sol` is effectively empty and can become the shared DETF behavior entry surface.
- `contracts/vaults/detf/dual/DualDETFCommon.sol` is also effectively empty and is a natural intermediate layer for dual-reserve DETF behavior if needed.
- `contracts/vaults/protocol/BaseProtocolDETFCommon.sol` is the current source that should be renamed and restructured as `SelfCommonDETF`.
- `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol` contains a narrower version of the same family of concerns.
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol` contains route selection and stable/common reserve logic that should stay topology-aware but consume shared planning and lifecycle helpers.
- `contracts/vaults/basic/BasicVaultCommon.sol` already contains the strongest existing shared token intake pattern and should be treated as a direct consolidation input.
- `contracts/vaults/protocol/ProtocolNFTVaultService.sol` already represents the strongest in-scope inventory-service pattern relevant to bond policy extraction.
- `contracts/vaults/VaultComponentFactoryService.sol` already provides a vault-specific factory layer on top of Crane.

## Completed Helper Extractions

The current refactor pass has already completed a focused subset of the Phase 1 and Phase 4 extraction work inside the bond and preview paths.

Completed shared helpers under `contracts/vaults/detf/common/core/`:

- `DETFPreviewLib.sol`
  - shared preview discount and markup helpers now back the duplicated conservative preview buffer math in protocol bonding and exact-out paths
- `DETFBondNFTMathLib.sol`
  - shared quadratic bonus multiplier math
  - shared lock-duration status evaluation
  - shared effective-share calculation
  - shared reward accrual calculation
  - shared redeem-caller validation
  - shared deadline and unlock predicates
  - shared bond-terms lookup wrapper for the converged bond-NFT families
  - shared `IProtocolNFTVault.Position` assembly helper
- `DETFSafeTransferLib.sol`
  - shared low-level ERC20 transfer helper used by bond-NFT reward-transfer flows
- `DETFBondLifecycleLib.sol`
  - shared bond-position finalization helper for recipient normalization plus `createPosition(...)`
  - shared Bond NFT sale-to-protocol settlement helper for `sellPositionToProtocol(...)` plus `mintFromNFTSale(...)`
  - shared protocol-reward collection helper for `reallocateProtocolRewards(...)` plus zero-reward guard
  - shared reserve-pool BPT top-up helper for `forceApprove(...)` plus `addToProtocolNFT(...)` before family-local sale minting

Families already rewired to these helpers:

- `contracts/vaults/protocol/ProtocolNFTVault*`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVault*`
- `contracts/vaults/seigniorage/nft/SeigniorageBondNFT*`
- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFBridgeTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFBridgeTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol`

Important scope note:

- Seigniorage remains out of scope for the broader DETF family migration, but narrowly shared bond-NFT math and transfer helpers were reused there where the behavior matched exactly.
- Unsupported `ExchangeOut` routes remain outside this helper pass; we are not extracting or extending exact-out lifecycle branches that intentionally have no gas-efficient, behavior-preserving route implementation.

What this means for the remaining plan:

- the bond-NFT helper extraction work is no longer hypothetical and should be treated as an in-progress implementation of the reusable lifecycle and inventory groundwork described in Phase 4
- remaining work in this area should prioritize larger lifecycle and policy seams over more trivial wrapper deduplication

## Phased Plan

### Phase 0: Baseline and Refactor Guardrails

Goal:

- lock current behavior before shared extraction starts

Scope:

- identify and run the narrow DETF-focused Forge suites for all three families
- group baseline coverage by threshold gating, preview and execution symmetry, reserve accounting, exchange in and out, and bonding flows
- capture any current known quirks that must remain stable during refactor
- document the external interfaces and deployment flows that must remain unchanged

Primary outputs:

- baseline command list for DETF validation
- refactor checklist for regressions
- explicit list of tests that define current behavior

Exit criteria:

- the team agrees on what behavior is canonical versus accidental
- focused validation commands are documented and runnable

### Phase 1: Extract Low-Risk Shared Core Libraries

Goal:

- remove the most obvious duplication without touching storage shapes or route topology

New modules:

- `contracts/vaults/detf/common/core/DETFMintSplitLib.sol`
- `contracts/vaults/detf/common/core/DETFTokenTransferLib.sol`
- `contracts/vaults/detf/common/core/DETFThresholdPolicy.sol`
- `contracts/vaults/detf/common/core/DETFPreviewLib.sol`

Primary work:

- centralize mint split math so preview and execution consume the same slice model
- centralize secure transfer-in and pretransferred accounting by promoting common DETF-facing helpers from existing semantics in `BasicVaultCommon` without modifying `BasicVaultCommon` itself
- centralize mint and burn threshold semantics while leaving price-signal calculation family-local
- centralize conservative preview rounding and buffer helpers while composing existing Balancer and AMM quote utilities

Likely call sites:

- Self Common DETF exchange in and query surfaces
- Single Vault DETF common, exchange in, and query surfaces
- Composed Stable/Common mint and preview surfaces

Exit criteria:

- all three families call shared libs for split math and transfer handling
- no storage migration has occurred
- focused family tests still pass

### Phase 2: Normalize Reserve-Pool State Access

Goal:

- consolidate reserve-pool loading and index validation while standardizing toward `WeightedPoolReserveVaultRepo`

New modules:

- `contracts/vaults/detf/common/core/DETFReservePoolStateLib.sol`
- optional `contracts/vaults/detf/common/core/DETFCoreRepo.sol` for new shared fields only if needed without breaking existing external behavior

Primary work:

- centralize Balancer reserve-pool state loading on top of Crane `BalancerV3VaultAwareRepo`
- centralize tracked index validation and normalized balance access
- centralize owned reserve-claim calculations where the math is actually shared
- standardize to `WeightedPoolReserveVaultRepo` for tracked token index and weight storage rather than introducing duplicate per-family maps
- keep these repos separate for now:
  - `contracts/vaults/protocol/BaseProtocolDETFRepo.sol`
  - `contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol`
  - `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol`

Exit criteria:

- family repos are thinner and mostly topology-specific
- behavior remains unchanged with current storage layout

### Phase 3: Pilot Shared Route Planning in Single Vault DETF

Goal:

- prove a single planning pipeline that serves both preview and execution

Why Single Vault first:

- simpler topology than Protocol DETF
- closer in lifecycle to Protocol DETF than Composed Stable/Common
- lower branching complexity, so abstraction mistakes are cheaper here

New modules:

- `contracts/vaults/detf/common/core/DETFRoutePlanTypes.sol`
- shared mint plan builder and execution helpers, likely under `core/` plus a single-vault topology adapter
- `contracts/vaults/detf/topology/IDetfTopologyAdapter.sol`
- `contracts/vaults/detf/topology/SingleVaultTopologyAdapter.sol`

Primary work:

- replace duplicated route and quote branching in:
  - `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInTarget.sol`
  - `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryTarget.sol`
- introduce a shared `buildMintPlan(...)` flow
- make preview return the plan quote and execution consume the same plan logic
- keep helper extraction style consistent with `BaseProtocolDETFPreviewHelpers` so large plan calculations can move to dedicated helper units without changing repo conventions

Exit criteria:

- preview and execution share the same route-plan builder in Single Vault DETF
- the team is satisfied with the plan data model before porting it to other families

### Phase 4: Extract Shared Bond Lifecycle and Inventory Policy

Goal:

- stop cloning bonding and NFT inventory behavior per family

New modules:

- `contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol`
- `contracts/vaults/detf/common/inventory/IDetfBondInventoryPolicy.sol`
- `contracts/vaults/detf/common/factory/nft/SelfNFT*`
- `contracts/vaults/detf/common/factory/nft/ProtocolNFT*`

Primary work:

- normalize bond input collection
- normalize bond settlement sequencing
- separate topology-specific reserve conversion from shared lifecycle steps
- represent inventory sink differences as policy hooks rather than contract forks
- define one shared DETF NFT inventory policy interface used by all DETF families
- implement `Self NFT` as the protocol-owned NFT model
- implement `Protocol NFT` as the fee-recipient NFT model
- converge on one reusable NFT package rather than maintaining family-local NFT packages
- extract from existing in-scope inventory code before introducing new policy behavior, especially `ProtocolNFTVaultService`, `ProtocolNFTVaultTarget`, and `ComposedStableCommonDetfBondNFTVaultTarget`

Current surfaces to reconcile:

- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondingFacet.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol`

Exit criteria:

- at least two families share the same bond lifecycle helper
- inventory sink differences are driven through policy abstractions
- all DETF families target the same reusable NFT package model

### Phase 5: Rename and Port Protocol DETF as SelfCommonDETF

Goal:

- rename and restructure the current Protocol DETF line as `SelfCommonDETF` while moving it onto the shared lifecycle model

New modules:

- `contracts/vaults/detf/topology/SelfCommonTopologyAdapter.sol`

Primary work:

- migrate current Protocol DETF mint planning to the shared route-plan model
- migrate shared threshold, split, transfer, and preview behavior to core libs if not already done
- leave bridge-specific and token-model-specific behavior outside the shared core
- rename and restructure internal code to `SelfCommonDETF` naming while preserving exposed interfaces and deployment processes

Current surfaces in scope:

- `contracts/vaults/protocol/BaseProtocolDETFCommon.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInQueryTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeOutTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`

Exit criteria:

- Self Common DETF shares the same planning model used by Single Vault where the lifecycle is actually common
- bridge and RICHIR-specific behavior remain isolated
- all external interfaces still match prior deployment expectations

### Phase 6: Port Composed Stable/Common onto the Shared Core

Goal:

- bring the most topology-complex family onto proven shared primitives

New modules:

- `contracts/vaults/detf/topology/ComposedStableCommonTopologyAdapter.sol`

Primary work:

- adapt routed stable/common pool selection to the shared plan model
- keep topology-specific pool routing in the adapter
- reuse shared split, threshold, transfer, preview, reserve-state, and bond lifecycle modules where valid
- preserve rebasing token behavior as a separate token model concern while standardizing on the reusable rebasing package derived from Stable DETF code

Current surfaces in scope:

- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondingFacet.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol`

Exit criteria:

- Composed Stable/Common consumes the shared lifecycle where appropriate without flattening its topology into generic branches
- the reusable rebasing package remains the canonical one for DETF reuse

### Phase 7: Standardize Package and Factory Composition

Goal:

- remove duplicated deploy-time assembly after runtime behavior has stabilized

New modules:

- `contracts/vaults/detf/factory/DETFPackageManifest.sol`
- `contracts/vaults/detf/factory/DETFComponentFactoryBase.sol`
- `contracts/vaults/detf/factory/DETFFacetFactoryBase.sol`
- `contracts/vaults/detf/factory/DETFPkgFactoryBase.sol`

Primary work:

- define common manifests for required facets, topology adapter, inventory policy, token model, and optional extras
- standardize assembly patterns for the family-specific factory services by following Crane `*FactoryService` conventions, CREATE3 service helpers, and existing Indexedex `VaultComponentFactoryService` composition patterns
- preserve CREATE3 and existing deployment conventions

Exit criteria:

- package wiring is manifest-driven instead of family-local boilerplate

### Phase 8: Namespace Cleanup

Goal:

- make the codebase reflect the mental model that Self Common DETF is one DETF family and NFT or rebasing code is explicitly reusable across DETF

Primary work:

- move current protocol DETF internals under `contracts/vaults/detf/self/common/`
- move reusable NFT logic under `contracts/vaults/detf/common/factory/nft/`
- move reusable rebasing logic under `contracts/vaults/detf/common/factory/rebasing/`
- update imports only after runtime consolidation has landed

Exit criteria:

- DETF families sit under one coherent namespace
- there is no unnecessary import churn during earlier phases

## Workstreams

### Workstream A: Shared Runtime Modules

Deliverables:

- threshold policy
- mint split math
- transfer handling
- preview helpers
- reserve state helpers
- bond lifecycle helpers

Reuse rule:

- each deliverable must first map to existing Crane primitives before a new DETF-specific abstraction is introduced
- each deliverable must also first map to existing Indexedex common, repo, service, or factory code before a new DETF-only abstraction is introduced

Primary success signal:

- new DETF behavior changes can be made once in shared code instead of per family

### Workstream B: Planning and Topology Adapters

Deliverables:

- normalized route-plan types
- per-family topology adapters
- shared preview and execution plan pipeline

Primary success signal:

- preview and execution no longer drift because they share the same planner

### Workstream C: Inventory Policy Layer

Deliverables:

- shared DETF NFT inventory policy interface
- Self NFT policy implementation
- Protocol NFT policy implementation
- one reusable NFT package consumed by DETF families
- one reusable rebasing package consumed by DETF families

Primary success signal:

- future DETF families can choose an inventory model without cloning lifecycle code

### Workstream D: Factory and Package Standardization

Deliverables:

- DETF package manifest
- common factory bases

Primary success signal:

- family deployment code differs mainly by manifest, not by assembly boilerplate

## Ticketed Phases

### Phase 0 Tickets

1. `DETF-00` Baseline DETF validation matrix
  - capture the focused existing Forge suites that define current behavior
  - record interface and deployment invariants that must not change

### Phase 1 Tickets

1. `DETF-01` Extract `DETFMintSplitLib`
  - consolidate mint split math from current family commons
2. `DETF-02` Promote DETF transfer helpers without modifying `BasicVaultCommon`
  - add DETF base-layer transfer helpers that mirror existing `BasicVaultCommon` semantics
3. `DETF-03` Extract `DETFThresholdPolicy`
  - normalize mint and burn threshold semantics only
4. `DETF-04` Extract `DETFPreviewLib`
  - centralize preview rounding and small shared quote helpers

### Phase 2 Tickets

1. `DETF-05` Standardize reserve state on `WeightedPoolReserveVaultRepo`
  - define how family repos map to the common reserve-pool storage model
2. `DETF-06` Extract `DETFReservePoolStateLib`
  - centralize Balancer reserve loading, index validation, and proportional reserve access

### Phase 3 Tickets

1. `DETF-07` Add `DETFRoutePlanTypes`
  - define shared mint and burn planning structs
2. `DETF-08` Pilot Single Vault shared mint planner
  - unify preview and execution planning for Single Vault DETF mint paths
3. `DETF-09` Pilot Single Vault burn-planner follow-up if needed
  - unify preview and execution planning for the burn side where required

### Phase 4 Tickets

1. `DETF-10` Extract `DETFBondLifecycleLib`
  - normalize bond sequencing independent of topology
  - status: in progress; current helpers cover bond position creation, protocol reward collection, shared sale-to-protocol settlement, and reserve-pool BPT top-up sequencing, with protocol plus single-vault plus Ethereum protocol bonding flows now routing their reserve-BPT protocol-NFT top-ups through the shared lifecycle helper, protocol plus Ethereum bridge source-compensation and destination rich-to-richir mint flows, and protocol plus Ethereum exchange-in RICHIR mint paths consuming those exact lifecycle fragments
2. `DETF-11` Define shared DETF NFT inventory policy interface
  - codify Self NFT and Protocol NFT policy hooks
  - status: started; `contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol` now names the shared protocol-owned inventory surface, `contracts/vaults/detf/common/inventory/IDetfProtocolNftInventoryPolicy.sol` names the fee-recipient inventory surface, the lower-level hook interfaces remain split under `IDetfBondInventoryPolicy.sol` and `IDetfFeeRecipientInventoryPolicy.sol`, and `DETFBondLifecycleLib` depends on the shared Self NFT inventory interface instead of the concrete protocol NFT vault interface; the remaining work is to migrate more consumers and converge the reusable NFT package around those policy roles
3. `DETF-12` Reorganize reusable NFT package
  - converge current DETF families on one reusable NFT package based on existing in-scope NFT code
  - status: in progress; `contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol` now names the reusable Self NFT package role over the existing `ProtocolNFTVaultDFPkg` surface, the base protocol DETF, Ethereum protocol DETF, and single-vault DETF package wiring now consume that alias at the package-init layer without changing underlying deployment behavior, and the active DETF deploy/integration scaffolding now holds package instances through that alias; remaining concrete `IProtocolNFTVaultDFPkg` usage in the main workspace is now limited to the underlying package implementation plus `PkgInit`/`PkgArgs`/error typing, while the existing concrete package stays in place

### Phase 5 Tickets

1. `DETF-13` Rename internal Protocol DETF common code to `SelfCommonDETF`
  - rename and restructure internals while preserving exposed interfaces and deployment flow
2. `DETF-14` Port Self Common DETF to shared planning and core libs
  - move current Protocol DETF lifecycle logic onto shared modules

### Phase 6 Tickets

1. `DETF-15` Reorganize reusable rebasing package from Stable DETF
  - promote the Stable DETF rebasing package into the reusable DETF package location
2. `DETF-16` Port Composed Stable/Common to shared core and reusable rebasing package
  - consume shared planner, reserve, lifecycle, NFT, and rebasing components

### Phase 7 Tickets

1. `DETF-17` Standardize DETF package manifests and factory bases
  - keep deployment flows externally unchanged while collapsing internal boilerplate

### Phase 8 Tickets

1. `DETF-18` Namespace cleanup and reusable directory finalization
  - move Self Common DETF internals under `contracts/vaults/detf/self/common/`
  - move reusable NFT and rebasing internals under reusable DETF directories

## Validation Gates

Every phase should satisfy the following:

- focused Forge tests for touched DETF family pass
- no behavior change outside the targeted refactor slice
- preview and execution remain consistent for the migrated slice
- no storage layout migration occurs unless explicitly planned and reviewed
- no package or factory reorganization occurs before runtime abstractions are stable
- all exposed interfaces and deployment processes remain unchanged

Additional checks by phase:

- Phase 1: existing focused tests remain green; do not add large new test scope unless required by a regression
- Phase 3 and later: route-plan preview and execution consistency assertions
- Phase 4 and later: bond inventory accounting assertions for both user and protocol sinks

## Risks and Mitigations

### Risk: Shared abstractions become branch-heavy and unreadable

Mitigation:

- keep shared code focused on lifecycle and math
- keep topology in explicit adapters

### Risk: Preview and execution still drift after partial refactor

Mitigation:

- do not treat helper extraction as sufficient
- require migrated families to use one shared plan builder

### Risk: Storage migration gets mixed into behavior extraction

Mitigation:

- prohibit repo merges in early phases
- keep family repos intact until behavior modules are proven across families
- use `WeightedPoolReserveVaultRepo` as the target standard, but stage migration behind internal adapters first

### Risk: Protocol-specific bridge or rebasing token behavior leaks into shared code

Mitigation:

- keep token-model and bridge extras out of core lifecycle libraries
- require shared modules to be token-model agnostic
- standardize on the Stable DETF rebasing package as the reusable rebasing package rather than inventing a new one

### Risk: Renaming Protocol DETF to SelfCommonDETF causes accidental external breakage

Mitigation:

- treat the rename as an internal restructuring only
- preserve all exposed interfaces, deployment arguments, and package-level behavior

### Risk: Factory cleanup starts too early and locks in the wrong abstractions

Mitigation:

- defer manifests and factory base work until runtime module boundaries stop changing

## Definition of Done

The consolidation is complete when:

- all DETF families consume shared core lifecycle modules where behavior is genuinely common
- each family expresses topology through an adapter instead of a family-local clone of common lifecycle code
- inventory sink differences are represented through policy hooks rather than contract forks
- all DETF families share one reusable NFT package model built around Self NFT and Protocol NFT roles
- all DETF families share one reusable rebasing package derived from Stable DETF code where rebasing is needed
- package and factory assembly is manifest-driven
- internal Protocol DETF code lives under the DETF self-common namespace as `SelfCommonDETF`
- adding a new DETF family mainly requires:
  - a topology adapter
  - an inventory policy choice
  - a package manifest
  - any unique token-model or bridge extras

It should no longer require re-implementing:

- threshold gating
- mint split math
- transfer accounting
- preview buffer logic
- bond lifecycle sequencing
- reserve index validation
- family-local package boilerplate