> **Status:** Superseded for **decisions** by [`PROTOCOL_NAMING_RENAME_PRD.md`](./PROTOCOL_NAMING_RENAME_PRD.md). Kept as blast-radius evidence.

# Protocol DETF naming inventory report

**Status:** Research complete. **Rename decisions locked** in [`PROTOCOL_NAMING_RENAME_PRD.md`](./PROTOCOL_NAMING_RENAME_PRD.md) (2026-07-28). This file remains the blast-radius evidence base; the PRD wins on naming choices.  
**Date:** 2026-07-28  
**Scope root:** `contracts/vaults/detf/**`  
**Goal:** Catalog every surviving use of the deprecated **Protocol DETF** product name (and closely related “Protocol*” identifiers) so a rename PRD can be written without surprise blast radius.

---

## 1. Executive summary

The **Protocol DETF product package is gone** from production sources:

- There is **no** `ProtocolDETF*.sol` under `contracts/` today.
- `contracts/vaults/protocol/` now holds only **shared** packages that outlived the product:
  - `DETFNFTVault*` (bond NFT vault)
  - `RebasingClaimToken*`
- The **typed product surface** still named after the old product remains and is **actively used by multiple live DETF families**:
  - `contracts/interfaces/IProtocolDETF.sol`
  - `contracts/interfaces/IProtocolDETFErrors.sol`
  - `contracts/interfaces/proxies/IProtocolDETFProxy.sol`

Under `contracts/vaults/detf` itself:

| Category | Count / finding |
|----------|-----------------|
| Files with `Protocol` in **filename** | **1** — `inventory/IDetfProtocolNftInventoryPolicy.sol` |
| Solidity files with Protocol-related **identifiers** | **~47** `.sol` files |
| Matching hits (rough) | **~228** symbol matches across those files |
| DETF families polluted | Single SE, Single Vault (composed/single), Multi-vault weighted, Mixed-buffer multi-vault stable, Composed stable common (+ local rebasing claim) |
| Clean subtrees | `detf/dual/**` (no Protocol matches); reusable only imports `contracts/vaults/protocol/` path |

**Key insight for the PRD:** most surviving code is **common DETF machinery** (errors, bond NFT sell/reallocate, seigniorage mint split, protocol-owned NFT id, claim-token back-pointer). It is **not** a dead Protocol-DETF-only island. Renaming must treat this as a **cross-family surface rename**, not a local package cleanup.

**Second key insight:** the word “protocol” appears in **three semantic layers**. A good PRD must not rename them all the same way:

1. **Product-brand pollution** (must rename): `IProtocolDETF`, `NotProtocolDETF`, `setProtocolDETF`, docs saying “Protocol DETF”, directory `vaults/protocol` for shared bond/claim packages.
2. **Domain “protocol-owned inventory”** (may keep or soften): `protocolNftId`, `sellPositionToProtocol`, `reallocateProtocolRewards`, mint-split `protocolDetf` — these mean “owned by the DETF/protocol reserve,” not “Protocol DETF product.”
3. **Unrelated “protocol”** (out of rename scope): DEX/lending “protocol ports,” “external protocols,” script names like `DeployBaseProtocols`, docs about Uniswap/Aerodrome as protocols.

---

## 2. Methodology

1. Filename scan: `find contracts/vaults/detf -iname '*protocol*'`.
2. Identifier scan under `contracts/vaults/detf` for Protocol DETF product symbols and inventory APIs (`IProtocolDETF*`, `sellPositionToProtocol`, `protocolDETF`, `protocolNftId`, etc.).
3. Import/usage graph expanded to:
   - `contracts/interfaces/**`
   - `contracts/vaults/protocol/**` (shared survivors)
   - `test/foundry/**` consumers
   - `scripts/foundry/**` residual deploy scripts
   - light frontend / docs touchpoints
4. Confirmed absence of concrete `ProtocolDETF` / `ProtocolNFTVault` implementation files under `contracts/`.

---

## 3. Taxonomy of “Protocol” under DETF

### 3.1 Product-brand / type-system pollution (primary rename targets)

These still encode the **deprecated product name** as if it were the canonical DETF interface.

| Symbol / artifact | Kind | Location | Role today |
|-------------------|------|----------|------------|
| `IProtocolDETF` | interface | `contracts/interfaces/IProtocolDETF.sol` | Shared typed surface for mint/bond/threshold/claimLiquidity used by F5 and others; NatSpec still says “Protocol DETF” |
| `IProtocolDETFErrors` | interface | `contracts/interfaces/IProtocolDETFErrors.sol` | Shared error set; `DETFCommon` inherits it |
| `IProtocolDETFProxy` | interface | `contracts/interfaces/proxies/IProtocolDETFProxy.sol` | Diamond proxy composite for the old product surface |
| `NotProtocolDETF(address)` | error | `IProtocolDETFErrors` | Access check wording tied to product name |
| `ISingleVaultDetf is IProtocolDETF` | inheritance | `contracts/interfaces/ISingleVaultDetf.sol` | Explicit “extends Protocol DETF interface for DETFNFTVault compatibility” |
| `IDetfProtocolNftInventoryPolicy` | interface | `contracts/vaults/detf/inventory/IDetfProtocolNftInventoryPolicy.sol` | **Only detf filename hit**; empty extension of fee-recipient inventory policy |
| Threshold-modes docs “F6 — IProtocolDETF” | docs | `DETF_Threshold_Modes_*.md` | Program already shipped F6 NatSpec against this name |

### 3.2 Domain language: protocol-owned inventory (shared concept, name inherited from Protocol DETF era)

These describe **protocol-owned bond NFT / seigniorage inventory**, a concept every DETF family still needs. Names often say “Protocol” because Protocol DETF coined the API.

| Symbol | Kind | Meaning (domain) | Main defs |
|--------|------|------------------|-----------|
| `sellPositionToProtocol` | external fn | Sell user bond NFT principal into protocol-owned NFT | `IDetfBondInventoryPolicy`, `IDETFNFTVault`, family bonding targets, `ComposedStableCommonDetfBondNFTVaultTarget`, `DETFNFTVaultTarget` |
| `reallocateProtocolRewards` | external fn | Move protocol-accrued rewards to recipient | same inventory surfaces |
| `ProtocolRewardsReallocated` | event | Reward reallocation log | `IDETFNFTVault` |
| `protocolDETF()` / `setProtocolDETF` | external fn | Back-pointer from NFT vault / claim token → DETF diamond | `IDETFNFTVault`, `IRebasingClaimToken`, composed-stable bond vault, rebasing claim targets |
| `protocolNftId` / `_tryInitProtocolNft` | storage / helper | Token id of protocol-owned NFT after `initializeDETFNFT` | Family DFPkgs + repos |
| `protocolDetf` / `protocolDetfOut` / `protocolAmount_` | mint-split fields | Seigniorage share of mint that accrues to protocol inventory | Family `*Common.sol`, `DETFMintSplitLib` |
| `_accrueMintProtocolInventory` | internal | Mint protocol share + join reserve to protocol NFT | Composed stable common |
| `_sellPositionToProtocol`, `_collectProtocolRewards`, `_addReservePoolBptToProtocolNft` | lib helpers | Lifecycle wrappers | `DETFBondLifecycleLib` |
| `protocolDETF_` param in `_validateRedeemCaller` | arg name | Caller must be the DETF diamond | `DETFBondNFTMathLib` |

### 3.3 Path / layout pollution (outside `detf/` but blocking a clean story)

| Path | Contents today | Notes |
|------|----------------|-------|
| `contracts/vaults/protocol/` | `DETFNFTVault*`, `RebasingClaimToken*` only | Directory name still says Protocol product; types were already partially generalized |
| `test/foundry/spec/protocol/vaults/protocol/` | Deploy tests for those packages | Path mirrors layout |
| `test/foundry/spec/vaults/protocol/` | `DETFNFTVault.t.sol`, claim tests | Same |
| `scripts/foundry/**/Script_16_DeployProtocolDETF.s.sol` etc. | Residual deploy scripts | Import `IProtocolDETF`; may be dead vs live families |
| Frontend `protocolDetfs()`, `protocolNftVault`, portfolio kind `'protocol'` | UI/list taxonomy | Product-list naming, not Solidity under detf |

### 3.4 False positives / out of rename scope

Do **not** treat as Protocol-DETF pollution without explicit PRD decision:

- `contracts/protocols/**` (DEX/lending integrations)
- Script `Script_03_DeployBaseProtocols`, `Demo_02_External_Protocols`
- Docs mentioning “protocol SE vaults,” “production protocol ports,” “protocol-owned reserve” as English prose where “protocol” = the system generally
- `DETFNFTRestricted` (already role-named; product word not present)
- `initializeDETFNFT` / `addToDETFNFT` / `detfNFTId` (already partially migrated away from `ProtocolNFT`)

---

## 4. Filename inventory under `contracts/vaults/detf`

### 4.1 Files with `Protocol` in the name

| Path | Type | Content summary |
|------|------|-----------------|
| `contracts/vaults/detf/inventory/IDetfProtocolNftInventoryPolicy.sol` | interface | `interface IDetfProtocolNftInventoryPolicy is IDetfFeeRecipientInventoryPolicy {}` — marker only |

Sibling inventory interfaces (for rename clustering context):

| Path | Notes |
|------|-------|
| `inventory/IDetfBondInventoryPolicy.sol` | Declares `sellPositionToProtocol`, `reallocateProtocolRewards` |
| `inventory/IDetfSelfNftInventoryPolicy.sol` | Empty extend of bond policy |
| `inventory/IDetfFeeRecipientInventoryPolicy.sol` | Fee-recipient NFT ids (no Protocol in name) |

### 4.2 Directories

No directory under `contracts/vaults/detf` is named `protocol`.  
Shared survivors live at **`contracts/vaults/protocol/`** (sibling of `detf/`).

---

## 5. External interfaces the detf tree depends on (must be in any rename PRD)

These files are **outside** `contracts/vaults/detf` but are the **root of the pollution graph**.

### 5.1 `IProtocolDETF`

- **Path:** `contracts/interfaces/IProtocolDETF.sol`
- **Role:** Canonical typed surface for:
  - role getters (`detfToken`, `pairToken`, `rateAsset`, `underlyingVault`, `reservePool`, `detfNFTVault`, `detfNFTId`, …)
  - threshold mode / synthetic gates
  - `mintWithRateAsset`, `bond`, `sellNFT`, `captureSeigniorage`, `donate`
  - `previewClaimLiquidity` / `claimLiquidity`
  - bridge helpers
- **NatSpec title:** still “Interface for Protocol DETF…”
- **Already partially role-named** in comments (rateAsset / pairToken), but **type name** is brand pollution.

**Import sites (Solidity, production + tests):**

| Consumer area | Files (representative) |
|---------------|------------------------|
| Interfaces | `ISingleVaultDetf`, `IDETFNFTVault`, `IProtocolDETFProxy` |
| detf composed/single | Info/ExchangeIn/Bonding facets & targets, DFPkg, Query facet |
| detf multi-vault-weighted | `MultiVaultWeightedDetfDFPkg` (casts DETF to `IProtocolDETF` for claim deploy) |
| detf mixedBuffer | `MixedBufferMultiVaultStableDetfDFPkg` (same pattern) |
| detf standardExchange/single | `SingleStandardExchangeDETDFPkg` |
| detf composed/stable/common | Bond NFT vault DFPkg/Repo/Target, FactoryService, ExchangeOutQueryFacet, RebasingDETFTokenTarget, TestBase |
| vaults/protocol | DETFNFTVault*, RebasingClaimToken* |
| tests | SingleVault*, ComposedStable*, MultiVault bonding, deploy tests under `spec/protocol/vaults/protocol` |
| scripts | `Script_16_DeployProtocolDETF*`, supersim ProtocolDetf scripts, scenario overlay |

### 5.2 `IProtocolDETFErrors`

- **Path:** `contracts/interfaces/IProtocolDETFErrors.sol`
- **Inherited by:** `DETFCommon` → effectively **all DETF family commons** that extend `DETFCommon`
- **Also:** `ComposedStableCommonDetfBondNFTVaultCommon`, `RebasingDETFTokenTarget`, `DETFNFTVaultCommon`, seigniorage NFT target, tests for threshold/mint reverts
- **Product-named error:** `NotProtocolDETF(address caller)` (others are domain-generic: `MintingNotAllowed`, `BondTokenNotSupported`, …)

### 5.3 `IProtocolDETFProxy`

- **Path:** `contracts/interfaces/proxies/IProtocolDETFProxy.sol`
- **Composes:** `IProtocolDETF` + diamond plumbing
- **Usage:** lighter than `IProtocolDETF` itself; still a public type name for clients/tests

### 5.4 `IDETFNFTVault` / `IRebasingClaimToken` (partial rename already done)

| API still saying Protocol | File |
|---------------------------|------|
| `protocolDETF() → IProtocolDETF` | `IDETFNFTVault` |
| NatSpec “Protocol NFT Vault”, “Protocol DETF contract” | `IDETFNFTVault` |
| `sellPositionToProtocol`, `reallocateProtocolRewards`, `ProtocolRewardsReallocated` | `IDETFNFTVault` (+ inventory policy) |
| `protocolDETF()` / `setProtocolDETF` | `IRebasingClaimToken` |

### 5.5 `ISingleVaultDetf`

```solidity
interface ISingleVaultDetf is IProtocolDETF { ... }
```

Comment explicitly: extends Protocol DETF interface for DETFNFTVault compatibility.

### 5.6 `IComposedStableCommonDetfBondNFTVault`

```solidity
interface IComposedStableCommonDetfBondNFTVault is IDETFNFTVault, IDetfProtocolNftInventoryPolicy
```

Only production consumer of `IDetfProtocolNftInventoryPolicy`.

### 5.7 Existing cleaner partial surface: `IDETF`

- **Path:** `contracts/interfaces/IDETF.sol`
- Narrow pricing/rebasing helpers (`bondNftVault`, `detfNFTId`, previews) — **not** a full replacement for `IProtocolDETF`.
- PRD should decide whether rename merges into `IDETF` expansion vs new name (e.g. `IDetf`, `IDetfCore`, `IStandardDetf`).

---

## 6. Inventory under `contracts/vaults/detf` by layer

### 6.1 Shared core / root

| File | Protocol-related surface | Imported / used by |
|------|--------------------------|--------------------|
| `DETFCommon.sol` | `is IProtocolDETFErrors` | Family commons/targets that inherit DETFCommon |
| `core/DETFBondLifecycleLib.sol` | `_sellPositionToProtocol`, `_collectProtocolRewards`, `_addReservePoolBptToProtocolNft` | Single SE, multi-vault, mixedBuffer, single vault bonding |
| `core/DETFBondNFTMathLib.sol` | `_validateRedeemCaller(..., protocolDETF_, ...)` | Composed stable bond NFT service |
| `core/DETFMintSplitLib.sol` | return name `protocolAmount_` | Mint split callers (stable common path) |
| `inventory/IDetfBondInventoryPolicy.sol` | `sellPositionToProtocol`, `reallocateProtocolRewards` | Self-NFT policy → NFT vaults |
| `inventory/IDetfProtocolNftInventoryPolicy.sol` | type name only | `IComposedStableCommonDetfBondNFTVault` |

### 6.2 Reusable factories (path pollution only)

| File | Hit |
|------|-----|
| `reusable/DetfComponentFactoryService.sol` | imports from `contracts/vaults/protocol/DETFNFTVaultDFPkg` / RebasingClaim |
| `reusable/DetfPkgFactoryService.sol` | same |
| `reusable/DetfFacetFactoryService.sol` | facets under `vaults/protocol/` |
| `reusable/nft/IDetfSelfNftInventoryDFPkg.sol` | package type import from `vaults/protocol/` |

No `IProtocolDETF` identifier in these files beyond **filesystem path** `vaults/protocol`.

### 6.3 Family: Single Standard Exchange (`standardExchange/single/`)

| File | Symbols / usage |
|------|-----------------|
| `SingleStandardExchangeDETDFPkg.sol` | imports `IProtocolDETF`; `_tryInitProtocolNft`; passes `IProtocolDETF(detf_)` into claim/NFT init; `protocolNftId` into repo |
| `SingleStandardExchangeDETFRepo.sol` | storage/init field `protocolNftId` |
| `SingleStandardExchangeDETFCommon.sol` | mint-split field `protocolDetf` |
| `SingleStandardExchangeDETFBondingTarget.sol` | interface + impl `sellPositionToProtocol`; mints `split_.protocolDetf`; calls lifecycle lib |
| `SingleStandardExchangeDETFExchangeInTarget.sol` | mints `split_.protocolDetf` to bond vault |
| `SingleStandardExchangeDETFExchangeInFacet.sol` | registers `sellPositionToProtocol` selector |

**Tests:** `test/.../standardExchange/single/adversarial/Adversarial_SingleSE_P0.t.sol` (and family suite generally exercises bonding).  
**Docs:** PRD / implementation plan still mention “Protocol DETF” as behavioral reference.

### 6.4 Family: Composed single / Single Vault DETF (`composed/single/`)

**Heaviest direct use of `IProtocolDETF` selectors** (facet registration for F5 / F6).

| File | Symbols / usage |
|------|-----------------|
| `SingleVaultDetfInfoFacet.sol` | `type(IProtocolDETF).interfaceId` + many `IProtocolDETF.*.selector` (detfToken…isBurningAllowed, including `thresholdMode`) |
| `SingleVaultDetfExchangeInFacet.sol` | `IProtocolDETF.mintWithRateAsset.selector` + interfaceId |
| `SingleVaultDetfExchangeInQueryFacet.sol` | IProtocolDETF selectors |
| `SingleVaultDetfBondingFacet.sol` | IProtocolDETF selectors |
| `SingleVaultDetfInfoTarget.sol` / Query/Bonding targets | implement surface typed as Protocol DETF |
| `SingleVaultDetfRepo.sol` | `IProtocolDETFErrors` |
| `SingleVaultDetfDFPkg.sol` | `IProtocolDETF` |
| `SingleVaultDetfBondingTarget.sol` | `_addReservePoolBptToProtocolNft`, `_collectProtocolRewards` wrappers |

**Tests (import `IProtocolDETF`):**  
`SingleVaultDetfInfoFacet_IFacet_Test`, ExchangeIn/Query/Bonding facet tests, `MintWithWeth`, `MintSellRedeem`, `ThresholdMode`, `BridgeTransport`, `DFPkg_Deploy`.

### 6.5 Family: Multi-vault weighted (`composed/multi-vault-weighted/`)

| File | Symbols / usage |
|------|-----------------|
| `MultiVaultWeightedDetfDFPkg.sol` | `_tryInitProtocolNft`, `protocolNftId`, `IProtocolDETF(detf_)` for claim package |
| `MultiVaultWeightedDetfRepo.sol` | `protocolNftId` storage |
| `MultiVaultWeightedDetfCommon.sol` | `protocolDetf` mint split |
| `MultiVaultWeightedDetfBondingTarget.sol` | `sellPositionToProtocol` + lifecycle |
| `MultiVaultWeightedDetfExchangeInTarget.sol` | mint `protocolDetf` |
| `MultiVaultWeightedDetfExchangeInFacet.sol` | selector registration |

**Tests:** `MultiVaultWeightedDetf_Bonding.t.sol` (`test_sellPositionToProtocol`), claim tests.

### 6.6 Family: Mixed-buffer multi-vault stable (`composed/stable/mixedBuffer/`)

Same structural pattern as multi-vault weighted:

| File | Symbols / usage |
|------|-----------------|
| `*DFPkg.sol` | `_tryInitProtocolNft`, `IProtocolDETF` cast, `protocolNftId` |
| `*Repo.sol` | `protocolNftId` |
| `*Common.sol` | `protocolDetf` |
| `*BondingTarget.sol` | `sellPositionToProtocol` |
| `*ExchangeInTarget.sol` / Facet | mint split + selector |

### 6.7 Family: Composed stable common (`composed/stable/common/`)

**Densest local coupling** of `protocolDETF` storage and claim/bond packages.

| File | Symbols / usage |
|------|-----------------|
| `ComposedStableCommonDetfBondNFTVaultRepo.sol` | storage `IProtocolDETF protocolDETF`; `_protocolDETF()`; init args |
| `ComposedStableCommonDetfBondNFTVaultTarget.sol` | `protocolDETF()`, `sellPositionToProtocol`, `reallocateProtocolRewards`; auth vs `layoutStruct.protocolDETF` |
| `ComposedStableCommonDetfBondNFTVaultDFPkg.sol` | `PkgArgs.protocolDETF` |
| `ComposedStableCommonDetfBondNFTVaultFacet.sol` | `IDETFNFTVault.protocolDETF.selector` |
| `ComposedStableCommonDetfBondNFTVaultCommon.sol` | `IProtocolDETFErrors` |
| `ComposedStableCommonDetfBondNFTVaultService.sol` | redeem params `protocolDETF` |
| `ComposedStableCommonDetf_Component_FactoryService.sol` | config field `protocolDETF` |
| `ComposedStableCommonDetfExchangeIn.sol` | `_accrueMintProtocolInventory`, `protocolDetfOut` |
| `ComposedStableCommonDetfCommon.sol` | `protocolDetfOut` in mint split |
| `ComposedStableCommonDetfBondingFacet.sol` | calls `sellPositionToProtocol` on bond vault |
| `ComposedStableCommonDetfExchangeOutQueryFacet.sol` | registers `IProtocolDETF.previewClaimLiquidity` / `claimLiquidity` |
| `RebasingDETFTokenTarget.sol` | `protocolDETF()`, `setProtocolDETF`, casts to `IProtocolDETF` for claim liquidity |
| `RebasingDETFTokenFacet.sol` | registers `protocolDETF` / `setProtocolDETF` selectors |
| `TestBase_ComposedStableCommonDetf.sol` | `IProtocolDETF internal protocolDETF` mock addr |
| `TestBase_ComposedStableCommonDetf_Components.sol` | `mockProtocolReserveBpt` |

**Tests:** Integrated deploy, bond NFT vault deploy, bonding facet, exchange in/out, threshold mode, rebasing facet IFacet tests.

---

## 7. Cross-reference matrix (symbol → define → use)

### 7.1 Type renames (breaking for every implementer)

| Symbol | Defined | Used under detf | Used outside detf |
|--------|---------|-----------------|-------------------|
| `IProtocolDETF` | `interfaces/IProtocolDETF.sol` | All families above (§6) | `IDETFNFTVault`, `ISingleVaultDetf`, proxy, vaults/protocol, tests, scripts |
| `IProtocolDETFErrors` | `interfaces/IProtocolDETFErrors.sol` | `DETFCommon`, single vault repo, stable bond common, rebasing claim target | `DETFNFTVaultCommon`, seigniorage NFT, tests |
| `IProtocolDETFProxy` | `interfaces/proxies/...` | (indirect / docs) | clients/tests/historical |
| `IDetfProtocolNftInventoryPolicy` | `detf/inventory/...` | via composed-stable bond interface | `IComposedStableCommonDetfBondNFTVault` |
| `NotProtocolDETF` | errors interface | any check emitting it | NFT/claim auth paths |

### 7.2 External function renames (ABI / selector breaks)

| Function | Declared on | Implementations (non-exhaustive) | Call sites |
|----------|-------------|-----------------------------------|------------|
| `sellPositionToProtocol` | `IDetfBondInventoryPolicy`, `IDETFNFTVault`, family bonding interfaces | `DETFNFTVaultTarget`, `ComposedStableCommonDetfBondNFTVaultTarget`, family DETF bonding targets (user-facing sell may wrap claim mint) | `DETFBondLifecycleLib`, bonding facets, tests |
| `reallocateProtocolRewards` | inventory + `IDETFNFTVault` | NFT vault targets | lifecycle `_collectProtocolRewards`, capture seigniorage paths |
| `protocolDETF()` | `IDETFNFTVault`, `IRebasingClaimToken` | both NFT vaults + claim tokens | DFPkg wiring, redeem auth, frontend reads |
| `setProtocolDETF(address)` | `IRebasingClaimToken` | `RebasingClaimTokenTarget`, `RebasingDETFTokenTarget` | postDeploy / tests |
| `IProtocolDETF.*` getters/ops | `IProtocolDETF` | Single vault facets primarily; others partial | facet metadata, off-chain ABIs |

**ABI risk:** any rename of external functions changes selectors. Diamonds already deployed (if any Protocol DETF instances remain on networks) would **not** pick up renames without redeploy. Shared packages deployed under new names need versioning strategy in the PRD.

### 7.3 Storage / internal renames (layout / readability)

| Field / helper | Layout impact | Families |
|----------------|---------------|----------|
| `protocolNftId` in repo `Storage` / init structs | **storage layout** if slot order preserved poorly | Single SE, multi-vault, mixedBuffer |
| `IProtocolDETF protocolDETF` in bond NFT vault repo | **storage type rename** (same address slot if careful) | Composed stable bond NFT vault; shared `DETFNFTVaultRepo` |
| mint-split `protocolDetf` / `protocolDetfOut` | memory only | all minting families |
| `_tryInitProtocolNft` | private helpers | DFPkgs |

### 7.4 Events

| Event | File | Rename impact |
|-------|------|---------------|
| `ProtocolRewardsReallocated` | `IDETFNFTVault` | Indexers / frontend event filters |

---

## 8. Path graph: `detf` → `vaults/protocol` shared packages

`detf/reusable/*` and family DFPkgs deploy bond NFT + claim packages from:

```text
contracts/vaults/protocol/
  DETFNFTVault{Common,Repo,Service,Target,Facet,DFPkg}.sol
  RebasingClaimToken{Repo,Target,Facet,DFPkg}.sol
```

Those packages:

- Still import and store `IProtocolDETF`
- Still expose `protocolDETF()`, `sellPositionToProtocol`, `reallocateProtocolRewards`
- Live under a **directory named `protocol`** even though types were renamed from `ProtocolNFTVault*` / product DETF

**PRD implication:** renaming only identifiers inside `detf/` without moving/renaming `contracts/vaults/protocol/` leaves structural pollution. Prefer a single program that:

1. Renames shared interfaces (`IProtocolDETF*` → role-neutral DETF interface name).
2. Renames inventory APIs if product brand is inseparable from them **or** documents intentional keep of “protocol-owned” wording.
3. Moves `vaults/protocol/{DETFNFTVault,RebasingClaimToken}` → e.g. `vaults/detf/` or `vaults/detf/protocolOwned/` / `contracts/vaults/bond/` (decision for PRD).
4. Updates reusable factory imports + tests under `test/foundry/spec/protocol/vaults/protocol/`.

---

## 9. Tests inventory (consumers of Protocol-named symbols)

### 9.1 Under `test/foundry/spec/vaults/detf/` (23 files matched broader Protocol DETF symbols)

| Area | Example files |
|------|----------------|
| composed/single | Facet IFacet tests, MintSellRedeem, ThresholdMode, BridgeTransport, DFPkg_Deploy, MintWithWeth |
| composed/stable/common | IntegratedDeploy, BondNFTVaultDFPkg_Deploy, BondingFacet, ExchangeIn/Out, ThresholdMode, Rebasing facet tests |
| multi-vault-weighted | Bonding (`test_sellPositionToProtocol`), Claim |
| standardExchange/single | adversarial P0 |

### 9.2 Shared package tests still under Protocol paths

| Path | Role |
|------|------|
| `test/foundry/spec/protocol/vaults/protocol/DETFNFTVaultDFPkg_Deploy.t.sol` | imports `IProtocolDETF` |
| `test/foundry/spec/protocol/vaults/protocol/RebasingClaimTokenDFPkg_Deploy.t.sol` | same |
| `test/foundry/spec/vaults/protocol/DETFNFTVault.t.sol` | package behavior |
| `test/foundry/spec/vaults/protocol/RebasingClaimTokenRedemption.t.sol` | claim redeem |
| `test/foundry/debug/ProtocolDETF_SyntheticPrice_Debug.t.sol` | **legacy product name** in filename |
| `test/foundry/fork/sepolia/protocol/EthereumProtocolDETFSyntheticPrice_SuperSimFork.t.sol` | largely commented imports; residual path |

### 9.3 Deploy scripts (residual product name)

| Script pattern | Notes |
|----------------|-------|
| `scripts/foundry/**/Script_16_DeployProtocolDETF.s.sol` | anvil_base_main, anvil_sepolia, public_sepolia base/ethereum |
| `scripts/foundry/supersim/*ProtocolDetf*` | bridge configure/test, minimal deploy |
| `scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol` | imports `IProtocolDETF` |

PRD should mark scripts as: delete / rewrite for modern families / archive only.

---

## 10. Documentation under `contracts/vaults/detf` that still speaks “Protocol DETF”

| Doc | Why it matters |
|-----|----------------|
| `DETF_Threshold_Modes_PRD.md` | F6 still titled **IProtocolDETF surface**; normative for threshold work |
| `DETF_Threshold_Modes_PROGRESS.md` / P6 exec prompts | Ship notes for F6 |
| `standardExchange/single/*_PRD.md` / implementation plan | Behavioral reference to Protocol DETF |
| `composed/stable/common/ComposedStableCommonDetf_PRD.md` | Heavy “Protocol DETF-style split,” “Protocol NFT” narrative |
| Family threshold mode implementation plans | Cross-links to F6 |

These should be updated **after** code rename PRD freezes names (or in the same PRD’s doc wave), not ad hoc.

---

## 11. Frontend / list / config (out of Solidity detf tree, in blast radius)

| Location | Symbol | Note |
|----------|--------|------|
| `frontend/e2e/helpers/chainArtifacts.ts` | `protocolDetfs()` | list-driven artifact type |
| e2e specs | import `protocolDetfs` | earn/swap tests |
| `frontend/app/portfolio/page.tsx` | `protocolDetfAbi`, `protocolNftVaultAbi`, kind `'protocol'` | portfolio NFT reading |
| `tokenlists.config.ts` | `includeTypeDirs: ['vaults/protocolDetf']` | token list taxonomy |
| `PROMPT.md` | generated registry field `protocolDetf` | codegen schema |

Not required for a contracts-only rename, but any PRD aiming at “no Protocol product pollution” should include a frontend/list wave.

---

## 12. What is **common** (survived deprecation) vs **product-local**

### 12.1 Common to many DETF implementations (rename carefully; do not delete)

| Capability | Shared location | Families using it |
|------------|-----------------|-------------------|
| Error set | `IProtocolDETFErrors` via `DETFCommon` | essentially all |
| Bond sell into protocol-owned NFT | `sellPositionToProtocol` + lifecycle lib | Single SE, multi, mixedBuffer, single vault, composed stable |
| Protocol reward reallocation | `reallocateProtocolRewards` | seigniorage capture paths |
| Protocol-owned NFT id | `protocolNftId` / `detfNFTId` | DFPkg init + synthetic price accounting |
| Mint seigniorage split “protocol leg” | `protocolDetf` / `DETFMintSplitLib.protocolAmount_` | all seigniorage mint families |
| Claim token ↔ DETF pointer | `protocolDETF` / `setProtocolDETF` | claim packages + composed-stable local rebasing |
| Typed claimLiquidity surface | `IProtocolDETF.claimLiquidity` | bond NFT vaults calling DETF |
| Threshold mode surface (F6) | `IProtocolDETF.thresholdMode` etc. | Single vault gold path; PRD law for all families |

### 12.2 Product-local / residual (safe to archive or drop from live path)

| Artifact | Status observation |
|----------|-------------------|
| Concrete `ProtocolDETF*.sol` under contracts | **Absent** |
| `ProtocolNFTVault*.sol` under contracts | **Absent** (replaced by `DETFNFTVault*`) |
| `Script_16_DeployProtocolDETF*` / supersim ProtocolDetf scripts | Residual; may not deploy modern families |
| Debug/fork tests named `ProtocolDETF_*` | Legacy harnesses |
| Historical PLANs / tasks under repo root mentioning ProtocolDETF facet splits | Documentation only |

---

## 13. Suggested rename clusters for the future PRD

These are **options for PRD debate**, not decisions.

### Cluster A — Canonical DETF product interface (highest leverage)

| Current | Candidate directions |
|---------|----------------------|
| `IProtocolDETF` | `IDetf`, `IDetfCore`, `IStandardDetf`, expand `IDETF` |
| `IProtocolDETFErrors` | `IDetfErrors` |
| `IProtocolDETFProxy` | `IDetfProxy` |
| `NotProtocolDETF` | `NotDetf`, `OnlyDetf` |
| `ISingleVaultDetf is IProtocolDETF` | `is IDetf` (or composition) |

### Cluster B — Inventory / protocol-owned NFT (domain language)

| Current | Candidate directions |
|---------|----------------------|
| `sellPositionToProtocol` | `sellPositionToDetfNft`, `sellPositionToProtocolOwnedNft`, `sellBondToReserve` |
| `reallocateProtocolRewards` | `reallocateDetfNftRewards`, `reallocateProtocolOwnedRewards` |
| `ProtocolRewardsReallocated` | match function rename |
| `IDetfProtocolNftInventoryPolicy` | `IDetfProtocolOwnedNftInventoryPolicy` or fold into bond policy |
| `protocolNftId` | `detfNftId` (align with existing `detfNFTId()` getters) |
| `_tryInitProtocolNft` | `_tryInitDetfNft` |

### Cluster C — Mint split “protocol leg”

| Current | Candidate directions |
|---------|----------------------|
| `protocolDetf` / `protocolDetfOut` | `protocolOwnedDetf`, `seigniorageDetf`, `inventoryDetf` |
| `_accrueMintProtocolInventory` | `_accrueMintInventory` |
| `protocolAmount_` | `inventoryAmount_` / `protocolOwnedAmount_` |

### Cluster D — Claim / NFT back-pointer

| Current | Candidate directions |
|---------|----------------------|
| `protocolDETF()` | `detf()`, `detfDiamond()`, `parentDetf()` |
| `setProtocolDETF` | `setDetf` |
| storage `IProtocolDETF protocolDETF` | `IDetf detf` |

### Cluster E — Layout / packages

| Current | Candidate directions |
|---------|----------------------|
| `contracts/vaults/protocol/` | `contracts/vaults/detf/bond/`, `.../claim/`, or keep packages under `detf/reusable` |
| test paths `spec/protocol/vaults/protocol` | mirror new layout |
| scripts `*ProtocolDETF*` | delete or rewrite to family deploys |

### Cluster F — Explicit non-goals (recommend PRD lock)

- Do not rename `contracts/protocols/**`.
- Do not rename English “protocol-owned reserve” prose into awkward synonyms unless it collides with product brand.
- Do not require storage-slot reshuffles for already-deployed diamonds without a migration story (prefer pure renames that preserve layout when possible).

---

## 14. Risk and sequencing notes for the PRD

1. **Selector / ABI break:** external renames invalidate existing diamond facets and off-chain ABIs. If no production Protocol DETF remains, blast radius is **code + tests + scripts + frontend**, not live funds — still large.
2. **`IProtocolDETF` is the compatibility hub:** bond NFT vaults and claim tokens type the DETF as `IProtocolDETF` for `claimLiquidity` / `previewClaimLiquidity`. Any rename must update both sides atomically.
3. **Facet metadata tests** (especially Single Vault IFacet tests) hard-code `IProtocolDETF` selectors and interfaceId — first compile failures after rename.
4. **Storage fields** `protocolNftId` / `protocolDETF` in repos: renaming identifiers does not change slots if order unchanged; **reordering** does. PRD should mandate layout-preserving renames.
5. **Threshold Modes F6 already shipped** under the old name; rename PRD should supersede F6 naming without reopening threshold law.
6. **Two “Protocol” meanings:** PRD should include a glossary:
   - *Product (deprecated):* Protocol DETF  
   - *Domain:* protocol-owned NFT / inventory  
   - *External:* DEX protocols  
7. **Empty marker interface** `IDetfProtocolNftInventoryPolicy` is a cheap early rename or deletion (only one consumer).

---

## 15. Completeness checklist for PRD authors

When writing the rename PRD, ensure coverage of:

- [ ] `IProtocolDETF` + Errors + Proxy + `ISingleVaultDetf` inheritance
- [ ] `DETFCommon` error inheritance
- [ ] Inventory policies (`IDetfBond*`, `IDetfProtocolNft*`)
- [ ] `DETFBondLifecycleLib` helpers
- [ ] All five family areas in §6
- [ ] `contracts/vaults/protocol` shared packages + directory move
- [ ] `IDETFNFTVault` / `IRebasingClaimToken` back-pointers and events
- [ ] Factory services under `detf/reusable`
- [ ] Tests in §9
- [ ] Residual deploy scripts in §9.3
- [ ] Frontend/list/tokenlist optional wave
- [ ] Doc wave for Threshold Modes F6 + family PRDs
- [ ] Explicit keep-list for domain “protocol-owned” English where intentional
- [ ] Storage-layout preservation rules
- [ ] ABI / diamond redeploy policy

---

## 16. Appendix A — Solidity files under `detf/` with Protocol-related hits

```
contracts/vaults/detf/DETFCommon.sol
contracts/vaults/detf/core/DETFBondLifecycleLib.sol
contracts/vaults/detf/core/DETFBondNFTMathLib.sol
contracts/vaults/detf/core/DETFMintSplitLib.sol
contracts/vaults/detf/inventory/IDetfBondInventoryPolicy.sol
contracts/vaults/detf/inventory/IDetfProtocolNftInventoryPolicy.sol
contracts/vaults/detf/reusable/DetfComponentFactoryService.sol   # path only
contracts/vaults/detf/reusable/DetfFacetFactoryService.sol       # path only
contracts/vaults/detf/reusable/DetfPkgFactoryService.sol         # path only
contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol # path only
contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETDFPkg.sol
contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol
contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFCommon.sol
contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFExchangeInFacet.sol
contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFExchangeInTarget.sol
contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFRepo.sol
contracts/vaults/detf/composed/single/SingleVaultDetfBondingFacet.sol
contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol
contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol
contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInFacet.sol
contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryFacet.sol
contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryTarget.sol
contracts/vaults/detf/composed/single/SingleVaultDetfInfoFacet.sol
contracts/vaults/detf/composed/single/SingleVaultDetfInfoTarget.sol
contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfExchangeInFacet.sol
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfExchangeInTarget.sol
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol
contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol
contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol
contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol
contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeInFacet.sol
contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeInTarget.sol
contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultCommon.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultDFPkg.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultFacet.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultRepo.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultService.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondingFacet.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfCommon.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfExchangeIn.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol
contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol
contracts/vaults/detf/composed/stable/common/RebasingDETFTokenFacet.sol
contracts/vaults/detf/composed/stable/common/RebasingDETFTokenTarget.sol
contracts/vaults/detf/composed/stable/common/TestBase_ComposedStableCommonDetf.sol
contracts/vaults/detf/composed/stable/common/TestBase_ComposedStableCommonDetf_Components.sol
```

`detf/dual/**`: no matches.

---

## 17. Appendix B — Related production files outside `detf/` (minimum co-rename set)

```
contracts/interfaces/IProtocolDETF.sol
contracts/interfaces/IProtocolDETFErrors.sol
contracts/interfaces/proxies/IProtocolDETFProxy.sol
contracts/interfaces/ISingleVaultDetf.sol
contracts/interfaces/IDETFNFTVault.sol
contracts/interfaces/IRebasingClaimToken.sol
contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol
contracts/vaults/protocol/DETFNFTVault*.sol
contracts/vaults/protocol/RebasingClaimToken*.sol
```

---

## 18. Appendix C — One-line verdict per concern

| Concern | Verdict |
|---------|---------|
| Is Protocol DETF still a deployable package under contracts? | **No** |
| Did common code survive under Protocol names? | **Yes — extensively** |
| Is pollution only filenames under detf? | **No — 1 filename + ~47 sol files + shared interfaces** |
| Can detf be cleaned without touching `interfaces/`? | **No** |
| Can detf be cleaned without touching `vaults/protocol/`? | **No (incomplete)** |
| Is every “protocol” string a bug? | **No — distinguish product vs domain vs external DEX** |
| Safe next step | **Write rename PRD using clusters A–E + glossary + ABI/storage rules** |

---

*End of inventory. No code was modified in this pass.*
