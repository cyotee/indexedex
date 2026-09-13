# DETF Consolidation Report

## Goal

This report reviews the current DETF implementations under:

- `contracts/vaults/protocol/`
- `contracts/vaults/detf/composed/single/`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/`

The goal is to identify how to consolidate and reorganize the code so new DETF families can be built by composing shared modules instead of copying and reworking entire vault stacks.

## Executive Summary

The three existing DETF families solve many of the same problems with family-local implementations:

- mint/burn threshold gating
- fee and seigniorage split math
- reserve-pool accounting
- preview versus execution symmetry
- bonding and bond-NFT settlement
- route execution pipelines
- package/factory composition patterns

The biggest issue is not that the families are identical. They are not. The issue is that the reusable parts are currently mixed together with topology-specific logic inside family-local `Common`, `Repo`, `Target`, and package files.

The right direction is not one monolithic `UniversalDETF`. The right direction is a layered DETF architecture:

1. shared DETF core modules for math, fees, previews, reserve accounting, and bond lifecycle
2. topology adapters for each reserve-pool shape and routing model
3. family assemblies that wire those modules together with family-specific topology and token models

That structure preserves the differences between Protocol DETF, Single Vault DETF, and Composed Stable/Common DETF while eliminating most of the repeated implementation work.

## Current Families

### 1. Protocol DETF

Representative files:

- `contracts/vaults/protocol/BaseProtocolDETFCommon.sol`
- `contracts/vaults/protocol/BaseProtocolDETFRepo.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInQueryTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeOutTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- `contracts/vaults/protocol/RICHIRTarget.sol`

Core characteristics:

- two underlying exchange vaults
- 2-token reserve topology with Balancer reserve-pool accounting
- protocol NFT vault as the default incentive sink
- rich route surface and bridge logic
- strong preview/execution mirroring across multiple token routes

### 2. Single Vault DETF

Representative files:

- `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeOutTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol`

Core characteristics:

- one underlying exchange vault
- 2-token reserve topology with a simpler reserve math model
- protocol NFT vault reused from protocol DETF stack
- fewer routes than Protocol DETF but very similar mint/bond/redeem lifecycle
- family-local implementations of logic that already exists in concept in Protocol DETF

### 3. Composed Stable/Common DETF

Representative files:

- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondingFacet.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol`

Core characteristics:

- routed mint/burn through underlying vaults plus stable/common composed pools
- 3-token reserve topology
- separate bond-NFT vault implementation with fee-recipient NFT support
- rebasing DETF token package rather than direct CHIR-like minting
- structurally different topology, but repeated lifecycle and fee logic

## Major Duplication Clusters

### A. Threshold gating and synthetic-price decision logic

Repeated concept in:

- `contracts/vaults/protocol/BaseProtocolDETFCommon.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol`

Repeated behavior:

- compute a synthetic or reserve-derived price
- compare against `mintThreshold`
- compare against `burnThreshold`
- gate exchange and bonding flows

Observation:

The price source differs by family, but the threshold semantics are shared. Threshold policy should be extracted from threshold input calculation.

### B. Mint split and incentive math

Repeated concept in:

- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInQueryTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol`

Repeated behavior:

- compute gross mint amount from a topology-specific quote
- apply seigniorage incentive boost before or around quote construction
- split gross mint output between user and protocol-side sink
- in newer single-vault work, also skim a fee-recipient slice to `feeTo()`

Observation:

The split math is currently family-local even though the conceptual pipeline is the same:

1. get gross output
2. compute fee slices
3. direct each slice to the proper sink

Only the sinks differ.

### C. Preview and execution symmetry

Repeated concept in:

- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInQueryTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeOutTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeOutTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol`

Repeated behavior:

- route detection in preview and execution
- same quote math represented twice
- manual preview buffers and conservative rounding
- family-local result structs and route branches

Observation:

This is one of the highest-value consolidation opportunities. The route tree should not be duplicated between preview and execution. Instead, each family should build a single route-plan/quote pipeline and let preview and execution share that plan.

### D. Reserve-pool accounting

Repeated concept in:

- `contracts/vaults/protocol/BaseProtocolDETFRepo.sol`
- `contracts/vaults/protocol/BaseProtocolDETFCommon.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol`

Repeated behavior:

- store reserve-pool token indices and weights
- validate indices on initialization
- load pool state from Balancer
- compute owned balances or proportional reserve claims
- handle liquidity add/remove flows

Observation:

The topology varies, but there is a reusable reserve-pool state model underneath:

- pool address
- tracked token indices
- tracked weights
- reserve-entry router and reserve-exit helpers

The common part should be extracted, with family-specific topology adapters layered on top.

### E. Bonding lifecycle

Repeated concept in:

- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondingFacet.sol`

Repeated behavior:

- validate bond token or position input
- collect token input or unwrap ETH
- route into vault/pool layers
- convert into reserve-pool shares
- split between user and fee/protocol sinks where applicable
- create or augment NFT positions
- capture seigniorage into the protocol-owned position

Observation:

This is the second most important consolidation target after preview/execution symmetry. The bonding flow is conceptually the same lifecycle with topology-specific route adapters and incentive policies.

### F. NFT-vault incentive integration

Repeated concept in:

- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondingFacet.sol`

Repeated behavior:

- protocol-owned NFT position as reserve principal sink
- user bond NFT creation and redemption lifecycle
- reward inventory sent to NFT vaults
- seigniorage capture back into protocol inventory

Observation:

The base protocol NFT model is already strong, but the composed stable/common family had to fork it to add fee-recipient NFT semantics. That suggests an extensible NFT-vault policy layer is missing.

### G. Package and factory wiring

Repeated concept in:

- `contracts/vaults/protocol/*_Component_FactoryService.sol`
- `contracts/vaults/protocol/*_Facet_FactoryService.sol`
- `contracts/vaults/protocol/*_Pkg_FactoryService.sol`
- `contracts/vaults/detf/composed/single/*_Component_FactoryService.sol`
- `contracts/vaults/detf/composed/single/*_Facet_FactoryService.sol`
- `contracts/vaults/detf/composed/single/*_Pkg_FactoryService.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/*_Component_FactoryService.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/*_Facet_FactoryService.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/*_Pkg_FactoryService.sol`

Repeated behavior:

- deploy related facets
- assemble package init structs
- assemble package args
- wire oracle, router, NFT-vault, and token dependencies

Observation:

The exact components differ, but the assembly pattern is repeated. This should become a shared package-template layer with family-specific manifests.

## What Should Be Consolidated

## 1. Introduce a DETF core module layer

Create a new folder:

- `contracts/vaults/detf/common/core/`

Recommended modules:

### `DETFThresholdPolicy.sol`

Shared responsibilities:

- `isMintingAllowed(price, mintThreshold)`
- `isBurningAllowed(price, burnThreshold)`
- shared error surfacing for threshold gates

Family-specific responsibilities stay outside:

- synthetic price calculation
- reserve spot price calculation
- topology-specific oracle inputs

### `DETFMintSplitLib.sol`

Shared responsibilities:

- represent `gross`, `user`, `protocol`, `feeTo`, `bondReward` slices
- apply fee and seigniorage policy in one place
- return a normalized split struct that both preview and execution use

Family-specific responsibilities stay outside:

- how to quote gross output
- where each slice is sent

This would directly consolidate the logic currently split across:

- `BaseProtocolDETFExchangeInTarget.sol`
- `BaseProtocolDETFExchangeInQueryTarget.sol`
- `SingleVaultDetfCommon.sol`
- `SingleVaultDetfExchangeInTarget.sol`
- `SingleVaultDetfExchangeInQueryTarget.sol`
- `ComposedStableCommonDetfCommon.sol`

### `DETFTokenTransferLib.sol`

Shared responsibilities:

- secure transfer-in handling
- pretransferred accounting
- balance-delta normalization
- optional support for fee-on-transfer tokens if needed later

This replaces repeated `_secureTokenTransfer(...)` style helpers.

### `DETFPreviewLib.sol`

Shared responsibilities:

- conservative rounding helpers
- preview buffer application
- route plan result structures used by both preview and execution

This should become the home for preview/execution symmetry rules.

### `DETFBondLifecycleLib.sol`

Shared responsibilities:

- normalize bond input collection
- shared bond settlement steps
- apply bond-share splits
- interact with NFT sink abstractions

Family-specific responsibilities stay outside:

- how the input becomes reserve shares
- what the NFT sink model is

### `DETFReservePoolStateLib.sol`

Shared responsibilities:

- reserve-pool initialization validation
- normalized storage helpers for tracked indices/weights
- reserve-pool state loading from Balancer
- owned proportional reserve calculations

Family-specific responsibilities stay outside:

- whether the topology is 2-token or 3-token
- which tokens are tracked

## 2. Separate core state from family topology state

Today, each family repo stores both:

- DETF-generic state
- family topology state

That makes every new family start from a fresh repo instead of composing one.

Recommended split:

### Shared core repo

Create:

- `contracts/vaults/detf/common/core/DETFCoreRepo.sol`

Shared fields should include:

- `feeOracle`
- `mintThreshold`
- `burnThreshold`
- `acceptedBondTokens`
- `protocolNFTVault` or bond-NFT sink reference where applicable
- protocol-owned NFT id if the family uses that model
- reserve-pool initialized flag

### Family extension repos

Keep separate repos for topology-specific state:

- `BaseProtocolDETFRepo.sol`
- `SingleVaultDetfRepo.sol`
- `ComposedStableCommonDetfRepo.sol`

But reduce them to only the fields unique to each topology.

Examples:

- Protocol DETF keeps `chirWethVault`, `richChirVault`, bridging state, local redeem allowlist
- Single Vault keeps `wethRichVault`, pool key hash, rate provider, single reserve topology config
- Composed Stable/Common keeps route table, stable/common pool references, rebasing DETF token, bond vault specifics

## 3. Introduce topology adapters instead of copying `Common.sol`

The current `Common.sol` files each blend:

- generic DETF lifecycle logic
- family-specific topology math
- family-specific route planning

That should be reorganized into adapters.

Recommended adapters:

### `IDETFTopologyAdapter`

Conceptual responsibilities:

- quote gross mint amount from an input route
- quote gross burn amount from an output request
- execute reserve-pool entry
- execute reserve-pool exit
- compute price signal for threshold policy

Concrete implementations:

- `ProtocolTwoVaultTopologyAdapter`
- `SingleVaultTopologyAdapter`
- `ComposedStableCommonTopologyAdapter`

This is the key to supporting additional DETF families later. New families should mainly implement a new topology adapter, not a full new DETF stack.

## 4. Unify preview and execution planning

The current code repeatedly encodes route selection twice:

- once in query/preview code
- once in execution code

That is expensive and risky.

Recommended structure:

### `DETFRoutePlan`

Define a normalized plan/result shape used by both preview and execution:

- selected route id
- underlying vault leg quote
- composed pool leg quote if any
- reserve-pool entry or exit quote
- gross output amount
- split output amounts
- minimum safe buffer where needed

Then provide:

- `buildMintPlan(...)`
- `buildBurnPlan(...)`
- `executeMintPlan(...)`
- `executeBurnPlan(...)`

Preview returns the plan’s quoted user output.
Execution consumes the same plan logic and performs settlement.

This reduces drift between:

- `BaseProtocolDETFExchangeInTarget.sol` and `BaseProtocolDETFExchangeInQueryTarget.sol`
- `SingleVaultDetfExchangeInTarget.sol` and `SingleVaultDetfExchangeInQueryTarget.sol`
- `ComposedStableCommonDetfExchangeIn.sol` and `ComposedStableCommonDetfExchangeOutQueryFacet.sol`

## 5. Turn NFT-vault differences into policy hooks

The codebase has already shown two incentive sink models:

- protocol-owned NFT only
- protocol-owned NFT plus dedicated fee-recipient NFT

Rather than forking the vault model again for each new DETF, introduce explicit policy hooks.

Recommended abstraction:

### `IDETFBondInventoryPolicy`

Responsibilities:

- where reserve principal is credited
- where reward inventory is credited
- whether fee-recipient NFT exists
- how bond-share skims are handled

Suggested implementations:

- `ProtocolNftOnlyPolicy`
- `ProtocolPlusFeeRecipientNftPolicy`

This would let the composed stable/common family reuse more of the protocol NFT infrastructure without forcing a complete clone.

## 6. Standardize package and factory composition

The package/factory files should be reorganized around manifests instead of family-local assembly code.

Recommended structure:

- `contracts/vaults/detf/factory/DETFPackageManifest.sol`
- `contracts/vaults/detf/factory/DETFComponentFactoryBase.sol`
- `contracts/vaults/detf/factory/DETFFacetFactoryBase.sol`
- `contracts/vaults/detf/factory/DETFPkgFactoryBase.sol`

Shared responsibilities:

- build package init from shared dependency groups
- deploy standard reusable DETF components
- enforce consistent naming and package shape

Family-specific manifests describe:

- required facets
- topology adapter
- NFT inventory policy
- token model
- optional extras like bridging or rebasing token package

## Recommended Reorganization

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
    ProtocolTwoVaultTopologyAdapter.sol
    SingleVaultTopologyAdapter.sol
    ComposedStableCommonTopologyAdapter.sol
  inventory/
    IDetfBondInventoryPolicy.sol
    ProtocolNftOnlyPolicy.sol
    ProtocolPlusFeeRecipientNftPolicy.sol
  factory/
    DETFPackageManifest.sol
    DETFComponentFactoryBase.sol
    DETFFacetFactoryBase.sol
    DETFPkgFactoryBase.sol
  protocol/
    base/
    ethereum/
  composed/
    single/
    stable/common/
```

The biggest naming cleanup is moving the protocol family under the DETF tree. Today it lives under `contracts/vaults/protocol/`, while the other DETFs live under `contracts/vaults/detf/`. That split makes the codebase look more different than it really is.

Recommended eventual move:

- `contracts/vaults/protocol/` -> `contracts/vaults/detf/protocol/`

This should be done only after shared modules exist, because the import churn would otherwise create unnecessary refactor risk.

## Migration Plan

## Phase 1: Create shared core modules without moving existing family files

Low-risk first step.

Extract first:

- threshold policy
- token transfer helper
- mint split math
- preview buffer helpers

Why first:

- small surface area
- easy to validate with existing tests
- immediately removes repeat work for future changes

## Phase 2: Normalize reserve-pool state access

Extract shared reserve state helpers and index validation.

Do not merge the repos yet. Keep family repos, but have them call the shared state lib.

Why second:

- large duplication payoff
- low behavior risk if storage shape stays untouched

## Phase 3: Introduce route-plan structs for preview/execution symmetry

Start with one family first.

Recommended pilot:

- `contracts/vaults/detf/composed/single/`

Why:

- simpler than Protocol DETF
- cleaner topology than Composed Stable/Common
- already close to Protocol DETF semantics in mint/bond lifecycle

Deliverable:

- shared plan-building code used by both `SingleVaultDetfExchangeInTarget.sol` and `SingleVaultDetfExchangeInQueryTarget.sol`

## Phase 4: Extract bonding lifecycle and inventory policy

Once route-plan symmetry exists, extract the bond lifecycle into shared settlement helpers and policy hooks.

Use this phase to make the protocol NFT sink model explicit and reusable.

## Phase 5: Standardize package/factory manifests

After runtime behavior is modularized, clean up deploy-time assembly.

This should be done after runtime consolidation so the new manifest layer can target stable shared modules instead of preserving old duplication.

## Where Not To Over-Consolidate

Some differences are real and should stay separate.

### 1. Do not merge topologies into one giant branching contract

The families differ materially in:

- route shapes
- reserve-pool token count
- underlying vault graph
- token models
- reward sink models

Use adapters, not condition-heavy shared contracts.

### 2. Do not force one NFT-vault contract to directly encode every incentive model

The protocol NFT vault and composed stable/common bond vault should share lifecycle concepts, but not necessarily one concrete contract. Use policy layers and reusable services first.

### 3. Do not collapse rebasing token logic into direct DETF mint logic

`RICHIRTarget.sol` and `RebasingDETFTokenTarget.sol` represent different token models. Shared interfaces and accounting helpers are reasonable; one implementation is not.

### 4. Do not move storage until behavior modules are already shared

Storage migration is the riskiest part. Consolidate behavior first, then state shape.

## Concrete Recommendations

### Highest-value refactors

1. Extract `DETFMintSplitLib.sol`

This gives immediate reuse across all three families and sharply reduces preview/execution drift.

2. Extract `DETFTokenTransferLib.sol`

This is low-risk and removes repeated transfer/accounting logic.

3. Introduce route-plan structs and shared plan builders

This is the best medium-term investment because preview/execution mismatch is one of the most expensive failure modes in vault code.

4. Introduce bond inventory policy abstractions

This is the key to supporting more DETF families without cloning NFT-vault logic again.

5. Move Protocol DETF under the DETF namespace after shared modules land

This is mostly organizational, but it matters. It will make future DETF work start from the correct mental model: Protocol DETF is one DETF family, not a separate product line.

## Suggested Foundation for Future DETF Families

If the refactor is done well, a future DETF family should need to implement mainly:

1. a topology adapter
2. an inventory policy choice
3. a package manifest
4. any family-unique token model or bridge extras

It should not need to re-implement:

- threshold gating
- fee split math
- preview buffer logic
- secure transfer handling
- generic bonding lifecycle steps
- reserve-pool index validation
- package/factory assembly patterns

That is the foundation needed to build more DETF vault types efficiently.

## Immediate Next Steps

Recommended first implementation sequence:

1. extract `DETFMintSplitLib.sol`
2. extract `DETFTokenTransferLib.sol`
3. extract `DETFThresholdPolicy.sol`
4. pilot a shared mint plan in `SingleVaultDetf`
5. generalize that mint-plan model to Protocol DETF
6. only then bring Composed Stable/Common onto the same planning pipeline

That sequence yields early reuse while keeping the highest-topology-complexity family for later, when the abstractions are already proven.