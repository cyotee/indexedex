# FullSpread Standard Exchange Vault — independent PRD contribution

## 1. Identity and route, labeled as the assigned route, not a runtime attestation

**Member:** Kimi, independent council member.  
**Assigned route label:** `kimi-coding/k3.1-pro:high`. This is the assigned label, not a runtime attestation.  
**Contribution:** Original research/PRD fragment for `UniswapV4FullSpreadStandardExchangeVault`; no implementation is authorized or supplied.

“Shall” is normative. `V` is the FullSpread diamond and its sole 18-decimal ERC-20 share, `P` is its hookless backing pool, `M` is the shared PoolManager, and `Q/H` is a distinct consuming pool and its existing Standard Exchange buffer hook. `C0/C1` are the ERC-20 faces of the two actual pool currencies in PoolKey order; native currency0 has `C0 = wrappedNative`. Amounts are raw native-token units unless WAD normalization is stated explicitly.

Each new requirement has an `FS-` ID, a source, and at least one acceptance row. Inherited PairToken requirements retain their `S1-` IDs and acceptance rows except for the enumerated deltas. Source aliases are resolved in section 9.

## 2. Family boundary and deltas from PairToken and Wings

| ID | Requirement | Source | Acceptance |
| --- | --- | --- | --- |
| FS-BOUND-01 | Deploy one registry-registered Crane diamond per instance. The diamond shall own exactly one position in one initialized, hookless `PoolKey`, at `(tickLower = TickMath.minUsableTick(tickSpacing), tickUpper = TickMath.maxUsableTick(tickSpacing), salt = bytes32(0))`, and exactly one public 18-decimal ERC-20 share supply. The diamond, not a router, hook, NFT manager, or user, is the position owner. There shall be no singleton manager, second share ledger, shares-of-shares wrapper, second pool, or range-management position. | Brief locked decisions 1/2; PT-PRD S1-ARCH-02; PT-Exec `_managerAction` | FS-A01, FS-A26; inherited S1-A47/A68 |
| FS-BOUND-02 | Place a new sibling family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, using the `UniswapV4FullSpreadStandardExchangeVault` prefix. PairToken shall not be renamed, amended, subclassed, or used as a concrete implementation base. PairToken stage one is the economics and packaging exemplar only. | Brief locked decisions 2/3; PT-PRD S1-ARCH-01 | FS-A01/FS-A02; inherited S1-A47 |
| FS-BOUND-03 | FullSpread shall make only three functional additions to PairToken stage one: (a) exact-input SE/SY execution while `M` is already unlocked, (b) an executable normalized one-share `IRateProvider.getRate`, and (c) production-first cross-vault integration through existing custom V4 SE buffer hooks. All other economics remain inherited, including strict single-token completion, fee attribution, native ETH, conditional withdrawal maintenance, and unsupported exact output. | Brief locked decisions 6/8/10/11 and “Money surface”/“Hook integration”; Adaptation “Required adaptations” | FS-A19–FS-A38 |
| FS-BOUND-04 | Do not copy Upper/Lower Wings’ open `IFacet[] facets` package input, `IPermit2` binding, `targetToken` argument, target-token sleeves, upper/lower ranges, rebalancing, or local-sleeve fallback. Wings is a negative packaging reference only. | Wings-DFPkg `PkgInit`/`PkgArgs`; PT-PRD S1-ARCH-04/S1-OP-05 | FS-A01/FS-A02/FS-A28 |
| FS-BOUND-05 | Non-goals: no Weir source copy, performance fee, locked `MIN_SHARES`, internal non-ERC-20 ledger, or “add ERC-20 and stop”; no ERC-4626-only wrapper; no second pool or off-pool conversion venue; no Wings range management; no registry migration of existing vaults; no deployment; no queued withdrawal; and no claim that this PRD is an audit or manipulation proof. | Brief locked decisions 1/7/8/9/12 and non-goals; Survey comparison conclusions; Weir WI-07 | FS-A40 and final implementation non-goal review |

### Deliberate PairToken deltas

| PairToken ID | FullSpread disposition | Acceptance |
| --- | --- | --- |
| S1-ARCH-01 | Replace the family path and type prefix with FS-BOUND-02; retain Facet → Target → Repo, canonical shared components, and no alternate share/reserve framework. | FS-A01/FS-A02 |
| S1-ARCH-04 | Retain the same five shared facets and twelve explicit `PkgInit` facet fields. `queryFacet` gains `getRate`, so package-owned selectors total 61 rather than 60. No factory facet enters `PkgInit`. | FS-A02 |
| S1-OP-05 | Replace blanket rejection of an already-unlocked manager only for supported scalar exact-input SE/SY calls. Paired operations, donation, and standalone compound retain `ManagerAlreadyUnlocked()`. | FS-A22–FS-A24/FS-A28 |
| S1-API-04 | `IRateProvider` is now in scope because the admitted buffer-hook consumer explicitly requires a provider on a buffered leg. Transition-quote, unlock-context quote, exact-output quantity quote, and ERC-4626 interfaces remain optional and are not installed by this family. Hook fallback uses ordinary SE previews when those interfaces are absent. | FS-A19–FS-A21/FS-A29–FS-A36; ContextQuote `supported`, `deposit`, `redeem` |
| S1-API-05 | Add `getRate()` to the family query ABI and interface declarations; retain every listed PairToken family method unchanged. | FS-A02/FS-A19 |
| S1-SEC-01 | Ordinary entry retains one-use callback commitments and zero-delta closure. The new already-unlocked path instead uses per-address/per-currency delta baselines and must not demand global zero deltas belonging to the outer operation. | FS-A14/FS-A22–FS-A27 |
| S1-A40 | Superseded by FS-A22–FS-A28: supported exact-input calls no longer reject solely because `M` is unlocked; nested `unlock` remains forbidden and non-scalar operations still reject. | FS-A22–FS-A28 |
| S1-A68 | `IRateProvider.getRate` is required, not an excluded integration selector. Operational ownership, diamondCut, rescue, ERC-4626, transition-quote, and unlock-context quote selectors remain absent. | FS-A02/FS-A19/FS-A40 |
| S1-A70 | Retain the vault operation/preview ceilings and add whole composed-hook-swap measurements under FS-GAS-01. | FS-A38 |
| S1-TEST-01 | Extend the real-manager fixture with real PairToken/other SE instances and real registry-deployed buffer-hook packages; no mock or etch of vault, manager, hook, or PoolManager. | FS-A29–FS-A37 |

## 3. Standard and family facet inventory, each row sourced

The source of truth is PT-DFPkg `PkgInit`, `_appendComponent`, and `_expectedSelectors`; the five shared facets also match PT-PRD S1-ARCH-04. The proposed query row deliberately adds only `getRate` under FS-RATE-04.

| `PkgInit` field | Concrete facet and interface(s) | Selectors and ownership rationale | Source / acceptance |
| --- | --- | --- | --- |
| `erc20Facet` | `ERC20Facet`; `IERC20`, `IERC20Metadata`, plus its canonical declared XOR ID | Shared; 9 selectors: metadata, supply, balances, allowances, approve/transfer. Sole public share implementation. | PT-DFPkg index 0; PT-PRD S1-ARCH-04; FS-A02 |
| `erc2612Facet` | `ERC2612Facet`; `IERC20Permit` | Shared; `permit`, `nonces`, `DOMAIN_SEPARATOR` (3). Do not add the overlapping combined permit facet. | PT-DFPkg index 1; FS-A02/FS-A03 |
| `erc5267Facet` | `ERC5267Facet`; `IERC5267` | Shared; `eip712Domain` (1), initialized for the diamond. | PT-DFPkg index 2; FS-A02/FS-A03 |
| `basicVaultFacet` | `MultiAssetBasicVaultFacet`; `IBasicVault` | Shared; `vaultTokens`, `reserveOfToken`, `reserves` (3), publishing booked idle rather than unbooked balances or position NAV. | PT-DFPkg index 3; PT-PRD S1-ARCH-05; FS-A03 |
| `standardVaultFacet` | `MultiAssetStandardVaultFacet`; `IStandardVault` | Shared; `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` (4), with zero fee-type IDs and truthful registry discovery. | PT-DFPkg index 4; IStandardVaultPkg; FS-A01/FS-A03 |
| `moneyFacet` | `UniswapV4FullSpreadStandardExchangeVaultMoneyFacet`; `IStandardExchangeIn` + family execution | Family; `exchangeIn`, `depositPair`, `redeemPair`, `donate`, `compound` (5). It selects ordinary versus already-unlocked exact-input execution. | PT-DFPkg index 5; PT-MoneyTarget; FS-A04–FS-A09/FS-A22–FS-A28 |
| `quoteFacet` | `UniswapV4FullSpreadStandardExchangeVaultQuoteFacet`; `IStandardExchangeIn` + family previews | Family; `previewExchangeIn`, `previewDepositPair`, `previewRedeemPair`, `previewWithdrawalMode`, `previewZapCredit` (5). Same planner and maintenance choice in both lock contexts. | PT-DFPkg index 6; PT-PRD S1-QUOTE-01; FS-A10 |
| `outFacet` | `UniswapV4FullSpreadStandardExchangeVaultOutFacet`; `IStandardExchangeOut` | Family; both canonical selectors installed, always reverting `ExchangeOutNotAvailable()` before funds or state changes. | PT-DFPkg index 7; SE-Out; FS-A11/FS-A37 |
| `queryFacet` | `UniswapV4FullSpreadStandardExchangeVaultQueryFacet`; family queries + `IRateProvider` | Family; the 11 PairToken queries (`poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, ticks, position liquidity, local reserves, basket, zap limits) **plus `getRate`** (12). | PT-DFPkg index 8; RateProvider; FS-A02/FS-A19–FS-A21 |
| `syMoneyFacet` | `UniswapV4FullSpreadStandardExchangeVaultSYMoneyFacet`; native `IStandardizedYield` money/reward methods | Family; `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards` (4), using the same share and exact-input engine. | PT-DFPkg index 9; PT-SYMoneyTarget; FS-A12/FS-A22/FS-A23 |
| `syQueryFacet` | `UniswapV4FullSpreadStandardExchangeVaultSYQueryFacet`; native `IStandardizedYield` discovery/previews | Family; 12 selectors: previews, token lists, yield token, asset info, `exchangeRate`, validity, and empty reward views. SY accounting remains distinct from `getRate`. | PT-DFPkg index 10; PT-SYQueryTarget; FS-A10/FS-A19–FS-A21 |
| `callbackFacet` | `UniswapV4FullSpreadStandardExchangeVaultCallbackFacet`; `IUnlockCallback` | Family; only `unlockCallback` (1). Ordinary manager actions use it; the already-unlocked path never treats it as a public money route. | PT-DFPkg index 11; PT-CallbackTarget/PT-Exec; FS-A14/FS-A27 |

**FS-FACET-01 — Package-owned surface.** The package shall install exactly 61 distinct selectors: 20 shared and 41 family-owned. Interface declarations shall include concrete `IStandardExchangeIn`, `IStandardExchangeOut`, native SY, family, and `IRateProvider` IDs, not an empty inheritance-only aggregate ID. Every selector shall be derived from Target/product interfaces and exercised on the deployed proxy. Source: PT-DFPkg `_expectedSelectors`; Crane architecture LR-7. Acceptance: FS-A02.

**FS-FACET-02 — Factory-owned exclusions.** ERC-165, diamond loupe, ERC-8109 introspection, and the temporary post-deployment hook are factory-owned. They shall not appear in `PkgInit`, component deployment lists, `facetAddresses`, `facetCuts`, or package-owned interface aggregation. No operational owner or `diamondCut` facet is added. Source: PT-DFPkg interface comment; PT-PRD S1-ARCH-04/S1-API-01. Acceptance: FS-A02/FS-A40.

**FS-FACET-03 — Optional quote interfaces remain absent.** `IStandardExchangeTransitionQuote`, `IStandardExchangeUnlockContextQuote`, and `IStandardExchangeExactOutputQuantityQuote` shall not be advertised as a substitute for execution. ContextQuote checks ERC-165 and falls back to standard exact-input previews when unsupported; exact-output quantity paths remain unavailable. Source: ContextQuote `supported`, `snapshot`, `deposit`, `redeem`, `_requireQuantity`; PT-PRD S1-API-04. Acceptance: FS-A29/FS-A37.

## 4. Proposed file and package contract

### FS-FILE-01 — Family and target split

Mirror PairToken’s current file split under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`; do not create these files during this research task. Source: PT-ComponentBindings and current PairToken tree. Acceptance: FS-A01/FS-A02 and inherited S1-A48.

```text
interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol
interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol
UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol
UniswapV4FullSpreadStandardExchangeVaultTypes.sol
UniswapV4FullSpreadStandardExchangeVaultRepo.sol
UniswapV4FullSpreadStandardExchangeVaultMath.sol
UniswapV4FullSpreadStandardExchangeVaultProjection.sol
UniswapV4FullSpreadStandardExchangeVaultPlanner.sol
UniswapV4FullSpreadStandardExchangeVaultExecution.sol
UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol
UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol
UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol
UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol
UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultSYMoneyFacet.sol
UniswapV4FullSpreadStandardExchangeVaultSYMoneyTarget.sol
UniswapV4FullSpreadStandardExchangeVaultSYQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultSYQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol
UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol
```

`Projection.sol` shall contain both `...Projection` and `...SwapProjection`; `Execution.sol` shall contain both `...Execution` and `...ExecutionPreparation`. `Types.Config`, `Inventory`, operation/snapshot/plan models, and the canonical PoolManager-owned position/supply observations remain the PairToken models. Add only execution-memory fields for `alreadyUnlocked` and the two starting manager deltas; no second authoritative ledger or persistent hook list is needed. `Repo.Storage` keeps `config`, categorized `inventory`, `initialized`, `operation`, and `callbackHash`, using namespace `indexedex.vaults.standard.exchange.uniswap.v4.fullSpread`. The six fixed compiler links, in order, are `Math`, `Projection`, `SwapProjection`, `Planner`, `Execution`, `ExecutionPreparation`.

### FS-PKG-01 — Interface-owned package inputs and instance arguments

`IUniswapV4FullSpreadStandardExchangeVaultDFPkg` shall inherit `IDiamondFactoryPackage` and `IStandardVaultPkg`, and define both structs on the interface. There is no open facet array and no caller-selectable execution address. Source: PT-DFPkg interface; Crane architecture DFPkg rule. Acceptance: FS-A01/FS-A02.

```solidity
struct PkgInit {
    IFacet erc20Facet;
    IFacet erc2612Facet;
    IFacet erc5267Facet;
    IFacet basicVaultFacet;
    IFacet standardVaultFacet;
    IFacet moneyFacet;
    IFacet quoteFacet;
    IFacet outFacet;
    IFacet queryFacet;
    IFacet syMoneyFacet;
    IFacet syQueryFacet;
    IFacet callbackFacet;
    IPoolManager poolManager;
    IVaultRegistryDeployment registry;
    IVaultFeeOracleQuery oracle;
    IWETH wrappedNative;
    IDiamondPackageCallBackFactory diamondFactory;
    address[6] linkedLibraries;
}

struct PkgArgs {
    PoolKey poolKey;
    address rateAsset;
    string name;
    string symbol;
    uint16 maxZapBps;
    int24 maxZapTickMove;
}
```

No silent zap default, hook allowlist, consuming-pool argument, fee switch, performance fee, or rescue address is added. Hook compatibility is a public exact-input execution capability constrained by FS-EXEC-02, not a per-instance privileged role.

### FS-PKG-02 — Binding, registry entry, and deployment

- `bindingHash = keccak256(abi.encode(init_))`; all 12 facets, five infrastructure bindings, and six links participate. `calcSalt(args) = keccak256(abi.encode(bindingHash, abi.decode(args, (PkgArgs))))`.
- `deployVault(args)` shall call only `registry.deployVault(this, abi.encode(args))`. The DFPkg itself shall be registered through `indexedexManager.deployPkg` or typed `deployUniswapV4FullSpreadStandardExchangeVaultDFPkg` in `...Component_FactoryService.sol`; facets and linked libraries use CREATE3/FactoryServices. Production and tests shall not use `new` or bypass the registry with the diamond factory.
- `name`/`packageName` return `UniswapV4FullSpreadStandardExchangeVaultDFPkg`; `vaultFeeTypeIds()` and declaration fee IDs are zero. `vaultTypes()`/`facetInterfaces()` include `IRateProvider`, and registry discovery succeeds by both declared currency faces and all declared types.
- `processArgs` runs only with `msg.sender == registry` and `address(this) == diamondFactory`, validates canonical args, and returns canonical encoding. `initAccount` runs only on the proxy whose factory package is this `SELF` and whose recorded args hash matches; it rejects repeat/direct/malformed initialization.

Source: PT-DFPkg `bindingHash`, `calcSalt`, `processArgs`, `deployVault`, `initAccount`; IndexedEx law “Deployment in IndexedEx”. Acceptance: FS-A01–FS-A03.

### FS-PKG-03 — Validation and errors

Retain `InvalidComponent()`, `InvalidPoolKey()`, `InvalidRateAsset()`, `InvalidZapLimits()`, `InvalidWrappedNative()`, `NotCalledByRegistry()`, `InvalidInitializationContext()`, and `AlreadyInitialized()` on the package interface. Source: PT-DFPkg interface and `_validate`; acceptance FS-A01.

- `InvalidComponent`: missing code, wrong/duplicate/missing selector set, wrong linked-component vector, or missing registry/manager/oracle/diamond-factory code. The query facet control now contains exactly 12 selectors including `getRate`.
- `InvalidPoolKey`: unordered/duplicate/self currencies, missing nonzero token code, nonzero hooks, dynamic or excessive fee, nonpositive/excessive tick spacing, or zero initialized sqrt price. Static zero fee is valid.
- `InvalidRateAsset`: not exactly one declared ERC-20 face. Cache its decimals for `assetInfo` and `getRate`; do not impose an 18-decimal allowlist.
- `InvalidZapLimits`: zero or over-10,000 `maxZapBps`, or negative `maxZapTickMove`.
- `InvalidWrappedNative`: missing/non-18-decimal/non-one-to-one wrapper behavior, or identical declared ERC-20 faces, including a native/same-wrapper collision.
- `NotCalledByRegistry` and `InvalidInitializationContext`: wrong caller, package, proxy, factory, args encoding/hash, or lifecycle context. `AlreadyInitialized`: second initialization.

### FS-PKG-04 — Proxy initialization

`initAccount` shall initialize family config and ticks, `ERC20Repo(name, symbol, 18)`, `EIP712Repo(name, "1")`, `MultiAssetBasicVaultRepo([C0,C1])`, and `StandardVaultRepo(oracle, bytes32(0), deduplicatedInterfaces, keccak256(abi.encode(sortedFaces)))`. Stored token/reserve views retain PoolKey face order; only the contents hash uses a sorted copy. No supply is minted and no position is created at deployment. Source: PT-DFPkg `initAccount`; PT-PRD S1-ARCH-05. Acceptance: FS-A03/FS-A04.

### FS-PKG-05 — Factory service and linked components

`...Component_FactoryService.sol` shall deploy the six linked libraries and seven family facets through CREATE3, resolve the five shared facets through existing canonical infrastructure, register the DFPkg through the manager, and expose typed package/instance helpers. `I...ComponentBindings.linkedComponents()` returns the fixed six-address vector but is never installed on a vault. Source: PT-ComponentBindings and PT-DFPkg `_appendComponent`; acceptance FS-A01/FS-A02.

## 5. Money, callback, and already-unlocked hook entry

### Inherited money surface

**FS-MONEY-01 — Preserve PairToken economics.** The following operations, equations, errors, previews, events, and acceptance rows are inherited without an economic rewrite. Source: PT-PRD sections 5–10 and PT-Vault ABI; acceptance is the listed inherited row plus the FullSpread composition rows.

| Operation | Required behavior | Source / acceptance |
| --- | --- | --- |
| Paired deposit | `depositPair` and `previewDepositPair`: full preflight, incumbent compound/checkpoint, accepted maxima, caller-only addition, genesis geometric mean with no dead shares, and positive-supply `min(qQuote,qCredit)` under S1-ACC-07. Native unused maximum is refunded; ERC-20 unused maximum is never pulled. | S1-OP-01/S1-ACC-02/07; S1-A08–A15/A49; FS-A04 |
| Single-token zap in | SE/SY exact input: positive existing supply and both reserves, size/tick limits, half-swap from caller inventory, post-swap incumbent checkpoint, caller-only addition, `qCredit` only from removable-principal growth, and residual booked without extra shares. | S1-OP-02/S1-ACC-07; S1-A13–A15/A64; FS-A05 |
| Paired redemption | `redeemPair` and preview: conditional maintenance, burn caller shares, proportional owned liquidity and booked idle, no retention, both actual currencies, terminal reset/rebootstrap. | S1-OP-03/S1-ACC-03/05; S1-A16/A17/A20/A54; FS-A06 |
| Single-token zap out | SE/SY share exact input: allocate only the exiter’s proportional withdrawal, sell the complete unwanted allocation through remaining pool liquidity, pay only the selected token, and revert the entire call on partial consumption, zero payout, or unmet minimum. Never silently pay a pair. | S1-OP-04 and S1-X12; S1-A18/A19/A21; FS-A07 |
| Compound | Permissionless collection, bounded ratio swap/reinvestment, final nonrecursive checkpoint, all LP fees to shareholders, no supply change or external fee-manager call; empty compound is a no-op. | S1-OP-05/S1-P01; S1-A22–A24/A66; FS-A08 |
| Donation | Pull and book only this call’s positive supported receipt without minting; disabled vault rejects it; unsolicited balances remain unbooked. Native/wrapped forms credit once. | S1-ACC-04/S1-SEC-02; S1-A38/A55/A65; FS-A09 |
| Quotes | Every SE/SY/paired preview uses the same complete bounded planner, including maintenance, fee growth, swaps, crossings, integer settlement, and withdrawal fallback. No NAV or off-chain quoter substitution. | S1-QUOTE-01/S1-GAS-01; S1-A27/A28/A67/A70; FS-A10 |
| Exact output | Install both Out methods and revert `ExchangeOutNotAvailable()` before transfer, burn, mint, manager mutation, or state change. | S1-P03; SE-Out; S1-A26; FS-A11/FS-A37 |
| Native ETH | Preserve actual native PoolKey and payable paired/SY paths; wrapped-native is only the nonpayable SE/SY face. Reset native sync before native debt and never issue ERC-20 calls to address zero. | S1-P02/S1-NATIVE-01; S1-A49–A55/A58/A60; FS-A12 |

Trust flags, recipient/deadline checks, issuance disable, terminal behavior, and custody partition remain governed by S1-ACC-04/06, S1-SEC-01/02, and S1-A34–A43/A52–A65. Acceptance: FS-A13–FS-A18 in addition to those inherited rows.

### Already-unlocked execution contract

**FS-EXEC-01 — Lock-context selection at the existing entrypoint.** After route validation and the family idle guard, `Execution.exchangeIn` shall read `TransientStateLibrary.isUnlocked(M)`. When false, it uses PairToken’s ordinary authenticated-unlock engine. When true, supported scalar exact-input SE and native SY deposit/redeem calls use `exchangeInAlreadyUnlocked`, an internal execution branch in `Execution.sol`, with no new public selector and no nested `M.unlock`. The same request, plan, events, and output semantics apply. Paired deposit/redemption, donation, and standalone compound do not branch and retain `ManagerAlreadyUnlocked()`. Source: Brief “already-unlocked entry”; Adaptation “Hook integration: two pools, one outer unlock”; PT-MoneyTarget/PT-SYMoneyTarget. Acceptance: FS-A22/FS-A23/FS-A28.

**FS-EXEC-02 — Operation authorization, not flag authorization.** The unlocked flag selects mechanics only. In the already-unlocked branch, require `recipient == msg.sender` for SE and `receiver == msg.sender` for SY; this matches current hooks’ `address(this)` recipient and prevents a caller from directing an outer-context payout to a third party. Require the ordinary supported route, positive amount, deadline/minimum, recipient checks, exact observed ERC-20/native credit, and caller-owned or canonically validated vault-held share authority. `pretransferred=true` retains the contract-only guard and unbooked-credit checks. No hook role, Q-specific allowlist, or claim that global `isUnlocked` identifies a locker is introduced. Source: SingleHookCommon `_seExchangeIn`; DualCommon `_buffer`/`_unwrap`; Adaptation “Bind source shares/tokens…” and “unlocked flag is not authorization”. Acceptance: FS-A13/FS-A24/FS-A27.

**FS-EXEC-03 — One planner and one guard.** Both branches shall prepare the identical amount-specific plan before a false-flag pull, burn, or manager mutation. Already-unlocked execution shall not weaken S1-EXIT-01 into unconditional collection-only maintenance, relax work/tick/bitmap limits, or ignore `EconomicStateChanged`. The cross-facet operation guard remains held through funding, direct manager actions, payouts/refunds, reserve publication, and cleanup. Economic reads reject while busy; static configuration and canonical token views retain S1-SEC-01 behavior. Source: PT-PRD S1-QUOTE-01/S1-SEC-01; Adaptation required adaptations 2/6. Acceptance: FS-A10/FS-A22/FS-A23/FS-A27.

**FS-EXEC-04 — Direct manager actions and position custody.** For every planned action in the already-unlocked branch, call `M.modifyLiquidity` or `M.swap` directly from the diamond, using the same hookless `P`, salt-zero full-range parameters, expected actual delta, fee attribution, and after-state witnesses as the ordinary callback. Do not set or consume `callbackHash`, call the vault’s `unlockCallback`, or route through `Q/H`. `V` remains the manager caller and position owner. Require `M` still to be unlocked before each direct action; loss of the expected context is `EconomicStateChanged()`. Source: PT-Exec `_managerAction`; Adaptation “Preserve V as the caller…”. Acceptance: FS-A22/FS-A23/FS-A26/FS-A27.

**FS-EXEC-05 — Per-address delta baselines.** At already-unlocked operation start, record `d0Start = M.currencyDelta(V, P.currency0)` and `d1Start = M.currencyDelta(V, P.currency1)`. For each direct action, snapshot the current two deltas, apply only that action’s actual returned delta, settle/take exactly the vault’s obligation/credit using the canonical sync/transfer/settle/take or native branch, and restore those two pre-action values after accounting. At successful return require both deltas to equal `d0Start/d1Start`, all operation reservations to be zero, and no change to another address’s deltas. Do **not** call `_zeroDeltas` and do **not** require `getNonzeroDeltaCount() == 0` in this branch; the outer router/hook owns global closure before its unlock returns. Pre-existing credits/debts belonging to `V` may be carried only as the explicit baseline, never as unclassified input or as another actor’s funds. Source: Adaptation “M’s deltas are per address and currency”; PT-Exec `_settle`/`_zeroDeltas`. Acceptance: FS-A25–FS-A27.

**FS-EXEC-06 — Ordinary callback remains closed.** Ordinary execution shall preserve `msg.sender == M`, active non-None operation, one-use `keccak256(abi.encode(operation,payload))`, expected action/deltas/fees, state witnesses, native settlement, and global zero-delta closure before returning from each unlock. An arbitrary caller, replay, wrong action, stale payload, direct already-unlocked call, or unsolicited callback is `InvalidCallback()`. `isUnlocked` alone never authenticates this callback. Source: PT-Exec `unlockCallback`; PT-PRD S1-SEC-01. Acceptance: FS-A14/FS-A27.

**FS-EXEC-07 — Atomic rollback.** Any wrong value/credit, allowance or share failure, partial unwanted-token sale, delta mismatch, unexpected fee/state change, failed transfer/wrapper/payout, callback violation, reentrancy, limit, or outer-hook revert shall roll back the complete vault subtree. If the outer hook does not catch it, the complete outer swap rolls back. No burned-share donation, residual second-token payout, pending withdrawal, or saved transient-slot restoration is permitted. Source: PT-PRD S1-OP-04/S1-SEC-01/02; Adaptation “Complete backing/fee ownership”. Acceptance: FS-A07/FS-A25/FS-A27/FS-A37.

### Existing hook integration contract

**FS-HOOK-01 — No hook-package change is required by the admitted source.** Existing hooks call opaque `IStandardExchangeIn`/`Out` addresses, use `address(this)` as recipient, and support `pretransferred=false`; their package args accept generic SE/token/provider addresses. FullSpread shall satisfy that existing exact-input ABI rather than require a new hook method. If implementation later identifies a concrete source-backed rejection, it shall be logged as a separate `FS-HOOK-CHANGE-*` requirement with the rejecting file and test; no hook edit is authorized by this PRD. Source: SingleHookCommon; DualCommon; all seven Hook-Pkg interfaces. Acceptance: FS-A29–FS-A37.

**FS-HOOK-02 — Covered current families.** Integration inventory and tests shall name:

1. `standardExchange/single/` — Single SE Buffer Hook (no held reserve).
2. `standardExchange/constantProduct/single/` — Single SE Buffer Constant-Product Hook.
3. `standardExchange/dual/` — Dual SE Buffer Constant-Product Hook.
4. `standardExchange/weighted/` — SE Weighted Buffer Hook.
5. `standardExchange/orbital/` — SE Orbital Buffer Hook.
6. `standardExchange/stable/quad/balancer/` — SE Balancer Quad Stable Buffer Hook.
7. `standardExchange/stable/quad/curve/` — SE Curve Quad Stable Buffer Hook.

Source: respective Hook-Pkg interfaces. Acceptance: FS-A29–FS-A35.

**FS-HOOK-03 — Identity and buffered legs.** An identity leg (`token == standardExchange == V`) holds V shares and needs no provider. A buffered leg (`token != standardExchange`, with `standardExchange == V`) converts its pair token to/from V and shall configure a nonzero provider; it may use `V` itself because FS-RATE-04 implements `getRate`. Actual conversions always use amount-specific `previewExchangeIn`/`exchangeIn`, never `heldShares * getRate` as a payout promise. Other SE legs use the existing real rate-provider fixture/provider, not a mock SUT. Source: IndexedEx law “held-reserve valuation”; SingleCP/Dual/Weighted/Orbital/Quad package args; Adaptation Rate Provider section. Acceptance: FS-A31–FS-A36.

**FS-HOOK-04 — Exact-input composition only.** Existing exact-input wrap/buffer/unwrap routes shall work in both directions. Any route that invokes `IStandardExchangeOut` on V shall revert `ExchangeOutNotAvailable()` atomically; this is intentional unsupported behavior, not a reason to enable exact output or redesign a hook. Source: S1-P03; SingleHookCommon `_seExchangeOut`; DualCommon `_unwrapExactOut`. Acceptance: FS-A11/FS-A37.

**FS-HOOK-05 — Pool and lock topology.** `P` remains initialized and hookless; `Q` is a distinct pool whose hook is H. The tests shall use one shared real `M`, so H calls V while `M` is unlocked. V performs its backing-pool operations directly without nested unlock or assuming immediate-caller hook suppression prevents recursion. H/router closes outer deltas; V closes only its own baseline. Source: Adaptation “two pools, one outer unlock”; PT-PRD S1-ARCH-03. Acceptance: FS-A22–FS-A26/FS-A29–FS-A35.

## 6. Rate, quote, and issuance separation

| ID | Requirement | Source | Acceptance |
| --- | --- | --- | --- |
| FS-RATE-01 | **Issuance:** `depositPair`, currency→V `exchangeIn`, and SY `deposit` use only S1-ACC-02/S1-ACC-07 attributable reserve growth and caller-only inventory. Neither SY `exchangeRate` nor `getRate` is an issuance input, NAV buy-in, or target-value guarantee. | PT-PRD S1-P06/S1-ACC-07/S1-QUOTE-02; Adaptation “Ownership/issuance” | FS-A04/FS-A05/FS-A20 |
| FS-RATE-02 | **SY accounting:** `IStandardizedYield.exchangeRate()` remains the spot-marked, fee-inclusive basket accounting value in raw `rateAsset` units per `1e18` raw shares: `floor(Vraw * 1e18 / S)`, with exact-rational currency conversion and zero at zero supply. It is not an execution quote and is not rescaled by target decimals. | PT-PRD S1-QUOTE-02; PT-SYQueryTarget | FS-A19/FS-A20; inherited S1-A32/A33 |
| FS-RATE-03 | **Amount-specific executable quotes:** `previewExchangeIn`, SY `previewRedeem`, and paired previews use the complete S1-QUOTE-01 planner. `E(q)` is the actual supported withdrawal-and-sale result for q shares, including conditional maintenance, proportional fee/idle attribution, post-removal liquidity, swap fees/price impact, full unwanted-input consumption, work limits, and integer rounding. | PT-PRD S1-QUOTE-01; Adaptation “Executable quote E(q)” | FS-A07/FS-A10/FS-A19 |
| FS-RATE-04 | **Normalized one-share exit rate:** `queryFacet` shall expose canonical `IRateProvider.getRate()`. Let `oneShare = 1e18`, `E = previewExchangeIn(V, oneShare, rateAsset)` under FS-RATE-03, and `d = cached rateAssetDecimals`. Return `floor(E * 1e18 / 10**d)` using full-precision arithmetic. For example, `E = 2,400,000` raw units at six decimals returns `2.4e18`. Do not alias SY accounting or a whole-book quote divided by supply. | RateProvider; Adaptation `exitRateWAD` formula; Brief locked decision 8 | FS-A19/FS-A20 |
| FS-RATE-05 | **Unavailable/rate-read boundaries:** if total supply is below `1e18`, return zero rather than extrapolating a smaller exit or inventing a 1:1 bootstrap rate. A genuine planner failure, arithmetic overflow, or busy family operation propagates (`ReentrantOperation()` when busy); zero/unavailable rates fail closed in existing hooks. After V commits and becomes idle, a valid rate read is allowed even if M remains unlocked. | Adaptation “Bootstrap…” and “coherent read boundaries”; IndexedEx hook law fail-closed reads | FS-A21/FS-A36 |
| FS-RATE-06 | **Reference, not protection:** `getRate` is a current, endogenous, one-whole-share exit reference, generally nonlinear in share amount and not a manipulation-resistant oracle. No Chainlink, peg, second pool, second deep market, or independent price is required. A same-P TWAP may be considered only as a separately authorized observation design; V4 core does not provide one automatically and this PRD does not add a hook to P. | Brief locked decision 9; Adaptation “A scalar rate is a reference…” | FS-A19–FS-A21/FS-A36/FS-A40 |

The three numeric surfaces shall be documented adjacently in NatSpec so integrators cannot confuse them: SY `exchangeRate` = raw-unit spot accounting; `getRate` = WAD-normalized executable one-share exit; `previewExchangeIn` = amount-specific executable quote. `assetInfo` continues to report the configured ERC-20 face and cached decimals.

## 7. Test and acceptance requirements, including cross-vault hook integration

### Fixture and file requirements

**FS-TEST-01 — Production-first bases.** Add `test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` and `test/behaviors/Behavior_UniswapV4FullSpreadStandardExchangeVaultPackage.sol` beside the proposed family. Follow `CraneTest → IndexedexTest → TestBase_VaultComponents → family TestBase`, deploying the real PoolManager, facets, DFPkg, manager, registry, fee oracle, native wrapper, tokens, and hooks through production paths. Extend shared bases, not concrete PairToken or Wings vaults. No SUT mock, subclass, etch, `vm.mockCall`, storage injection, scripted manager delta, or privileged synthetic issuance. Source: indexedex-testing; PT-PRD S1-TEST-01. Acceptance: every row below and inherited S1-A01–A70 as mapped in section 8.

**FS-TEST-02 — Required specs.** Create these future test files under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`:

```text
UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol
UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol
UniswapV4FullSpreadStandardExchangeVaultNative.t.sol
UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol
UniswapV4FullSpreadStandardExchangeVaultCallbacksAndSecurity.t.sol
UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol
UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol
UniswapV4FullSpreadStandardExchangeVaultInvariant.t.sol
```

Use exact balances, supply, position liquidity, manager deltas, events, and errors; independent wide-integer arithmetic; real prior swaps/donations for fees; and snapshot/restore only for whole-state branch comparison, with pre/post assertions. No timing-luck or fixed-sleep test. Source: PT-PRD S1-TEST-01 and repository test law. Acceptance: FS-A01–FS-A40.

**FS-TEST-03 — Proxy surface and trust negatives.** The package suite shall derive controls from Target/product interfaces, assert exactly 61 package selectors plus the disjoint factory surface, smoke every selector on the proxy, and verify permit/domain/shared Repo initialization. Retain EOA/constructor pretransfer rejection, short-delivery `TransferDeltaInsufficient`, exact declared-input processing with no excess refund, booked-inventory non-spend, false-flag exact-input pull behavior, exact-output no-funds rejection, and callback/reentrancy cross-facet attacks. Source: indexedex-testing mandatory negatives; PT-PRD S1-A06/A34–A39/A56–A59. Acceptance: FS-A02/FS-A13/FS-A14.

**FS-TEST-04 — Real cross-vault/hook fixtures.** Deploy V and a real PairToken SE (or another current real SE where a fixture is more economical) through their registries. Deploy each hook through its package → registry `deployHookVault` → hook factory with a premined nonce, then initialize Q and seed actual liquidity through public routes. For two-SE tests configure V on a buffered leg with its real provider and the other SE on an identity leg (`token == se`), so the other SE need not have its own already-unlocked conversion path; both shares must participate in the hook’s rated reserve/conversion path. Separately configure identity V/other-share legs for direct cross-vault share swaps. No hook, vault, or provider is replaced by a mock. Source: hook-package skill; Hook-Pkg interfaces; IndexedEx held-reserve law. Acceptance: FS-A29–FS-A36.

### Acceptance matrix

Inherited S1 rows remain independent obligations. The following rows are additive or replace an explicitly listed delta.

| ID | Acceptance evidence | Requirements / source |
| --- | --- | --- |
| FS-A01 | A valid registry-deployed package/instance has deterministic identity; every facet, infrastructure, link, and PkgArgs change affects it as intended. Each invalid component, pool key, rate asset, zap bound, wrapper, caller, args encoding, and reinitialization case reverts with its specified error. No Wings open array/Permit2/targetToken input exists. | FS-BOUND-01/02/04; FS-PKG-01–05 |
| FS-A02 | Interface/Target-derived controls equal all cuts: 20 shared + 41 family = 61 distinct package selectors, including 12 query selectors. Every selector is callable on the proxy as intended; ERC-165/loupe/ERC-8109 remain factory-installed and temporary-hook lifecycle is unchanged; no duplicate or factory facet appears in PkgInit/cuts. | FS-FACET-01/02; FS-FILE-01 |
| FS-A03 | Metadata, 18-decimal shares, permit, EIP-712 instance isolation, zero fee IDs, both-face registry discovery, `IRateProvider` type discovery, ordered token/reserve views, sorted-only contents hash, and booked-idle publication are correct for ERC-20 and native pools. | FS-PKG-02/04; S1-A05/A07/A56–A58 |
| FS-A04 | Paired genesis and subsequent deposits match independent equations, with no dead shares, complete recipient mint, accepted maxima/refunds, caller-only addition, and non-dilution `q*R_i <= S*C_i`. | FS-MONEY-01; FS-RATE-01 |
| FS-A05 | Both zap-in directions consume only the selected input or revert; no second token is pulled/paid, incumbent inventory is excluded from credit, residual is disclosed/booked without extra shares, and size/tick boundaries match previews. | FS-MONEY-01; Brief locked decision 6 |
| FS-A06 | Paired partial and terminal redemptions pay exact proportional principal/idle without retention, including collection-only maintenance and rebootstrap; no unbooked balance is captured. | FS-MONEY-01 |
| FS-A07 | Both zap-out directions pay only the selected leg and consume the entire unwanted allocation; partial fill, zero payout, or minimum failure restores shares, position, fees, deltas, and balances. No automatic paired fallback occurs. | FS-MONEY-01; FS-EXEC-07 |
| FS-A08 | Compound boundary/dust/tie/zero-liquidity/quarter-cap cases retain all fees once, never change supply, and emit exact actual costs/liquidity. | FS-MONEY-01 |
| FS-A09 | Donation adds exactly the observed same-call receipt with no shares; unrelated/unsolicited transfers stay unbooked through all operations and restart; disabled vault rejects donation. | FS-MONEY-01 |
| FS-A10 | Every SE/SY/paired preview equals execution from identical state in locked and already-unlocked contexts, including fees, crossings, maintenance fallback, terminal branches, and exact work-limit errors. | FS-MONEY-01; FS-EXEC-01/03 |
| FS-A11 | Both exact-output methods are installed and revert before funds/state/manager changes for every supported-looking and invalid route. | FS-MONEY-01; FS-HOOK-04 |
| FS-A12 | Native paired/SY and wrapped SE/SY routes have equal economics from equal states, exact msg.value/refunds, correct sync/settle/take, no address-zero ERC-20 call, and rollback on rejecting/reentrant receivers. | FS-MONEY-01; FS-EXEC-05/07 |
| FS-A13 | All trust-flag negatives pass in both lock contexts: code-less/construction callers reject, booked inventory cannot satisfy claimed input, short delivery reverts, exact declared credit is processed, excess is unbooked/refunded only as canonical rules require, and no third-party shares burn. | FS-TEST-03; FS-EXEC-02 |
| FS-A14 | Authentic ordinary callback succeeds; wrong manager, unsolicited/replayed/nested payload, wrong operation/action, stale witness, and cross-facet reentry reject with complete rollback. | FS-EXEC-06; FS-TEST-03 |
| FS-A15 | Entry-swap fees remain incumbent-owned, exit-sale fees remain with remaining liquidity, compound fees are counted once, and whole-position fee receipts never become a partial exiter’s principal in either lock context. | FS-MONEY-01; FS-EXEC-04/05 |
| FS-A16 | Registry disable rejects paired/SE/SY issuance and donation, allows compound, and preserves paired and executable single-token exits with the same maintenance and already-unlocked rules. | FS-MONEY-01; FS-EXEC-01 |
| FS-A17 | Terminal paired exit empties supply/liquidity/booked balances; terminal single-token exit requires remaining external liquidity; rebootstrap excludes old unbooked assets. | FS-MONEY-01 |
| FS-A18 | Mixed 6/8/18-decimal currencies retain raw units and exact accounting; forbidden FoT/rebase behavior is not advertised as supported; no token allowlist is introduced. | FS-PKG-03; FS-RATE-04 |
| FS-A19 | For 6/8/18-decimal rate assets, independently compute `E(1e18)` and assert `getRate == floor(E*1e18/10**d)`, including the 2.4e18 example scale. Compare an actual one-share exit from the same state; include fees, idle, price movement, and post-removal depth. | FS-RATE-03/04/06 |
| FS-A20 | Construct states where SY spot accounting, `getRate`, amount-specific larger exits, and issuance credit differ numerically; assert each from its own formula and prove neither rate enters issuance. No whole-book/supply substitution occurs. | FS-RATE-01–04 |
| FS-A21 | Supply below one whole share returns zero without scaling a smaller exit; busy reads revert `ReentrantOperation`; planner/arithmetic failures propagate; after commit, reads succeed while M remains unlocked. Existing hooks fail closed on zero/revert/short return. | FS-RATE-05; FS-HOOK-03 |
| FS-A22 | Under a real outer unlock, exact-input currency0→V and currency1→V deposits complete without nested unlock and match locked-context outputs/events from identical state. Paired genesis is established first; both pretransfer modes allowed by the canonical contract are covered. | FS-EXEC-01–05; FS-HOOK-05 |
| FS-A23 | Under a real outer unlock, V→currency0 and V→currency1 withdrawals complete both directions, fully consume the unwanted allocation, and match locked-context economics. SY native/wrapped variants use the same branch where supported. | FS-EXEC-01–05; FS-MONEY-01 |
| FS-A24 | Already-unlocked SE/SY calls with third-party recipient/receiver reject before funds or mutation; recipient==caller succeeds with ordinary authority. Global isUnlocked does not authenticate a callback or override route/share/input checks. | FS-EXEC-02/06 |
| FS-A25 | Seed unrelated outer-operation deltas and, separately, nonzero V starting baselines. V restores exactly its own starting currency deltas, leaves other addresses’ deltas untouched, and the outer unlock closes globally only after H/router settlement. No global-zero assertion fires inside V. | FS-EXEC-05/07 |
| FS-A26 | Before/after every direct action and composed hook swap, the salt-zero full-range position key remains owned by V; no H, router, user, or PositionManager becomes owner. | FS-BOUND-01; FS-EXEC-04 |
| FS-A27 | Wrong delta/fee/witness, manager-context loss, reentrancy, partial sale, payout failure, and outer-hook revert each produce atomic rollback with zero operation reservations and no stale callbackHash. | FS-EXEC-03–07 |
| FS-A28 | `depositPair`, `redeemPair`, `donate`, and `compound` called while M is unlocked revert `ManagerAlreadyUnlocked()` before action; ordinary scalar locked entry still uses authenticated callbacks. | FS-EXEC-01; FS-BOUND-03 |
| FS-A29 | Single non-reserve Buffer Hook: exact-input underlying→V wrap and V→underlying unwrap execute during Q’s swap, use ordinary SE preview fallback without transition interfaces, close deltas, and preserve ownership. | FS-HOOK-01/02/05; FS-FACET-03 |
| FS-A30 | Single SE Buffer CP Hook: exact-input buffered wrap/unwrap works in both directions with V’s provider; identity-leg configuration works without one; actual conversions use amount-specific SE calls. | FS-HOOK-01–03 |
| FS-A31 | Dual SE Buffer CP Hook: configure V on a buffered leg and another real SE on an identity leg. One exact-input Q swap mints/uses V shares and the other SE’s shares in its rated conversion path; the reverse exercises V withdrawal without requiring the other SE to convert while unlocked. Assert both directions, actual balances/rated reserves, providers, and deltas. Add an identity V/other-share swap proving direct cross-vault share acceptance. | FS-HOOK-01–05; FS-TEST-04 |
| FS-A32 | Weighted Buffer Hook: a multi-leg pool containing buffered V and an identity-leg other real SE completes exact-input cross-vault conversion both directions with correct rated reserves and no nested unlock. | FS-HOOK-01–05; FS-TEST-04 |
| FS-A33 | Orbital Buffer Hook: a three-leg pool containing buffered V, an identity-leg other real SE, and a supported third leg completes the corresponding exact-input conversions and preserves all three legs’ accounting. | FS-HOOK-01–05; FS-TEST-04 |
| FS-A34 | Balancer Quad Stable Buffer Hook: a supported 2–5-token configuration containing buffered V and an identity-leg other real SE completes exact-input conversions with correct provider use and deltas. | FS-HOOK-01–05; FS-TEST-04 |
| FS-A35 | Curve Quad Stable Buffer Hook: an exact-four-token configuration containing buffered V and an identity-leg other real SE completes exact-input conversions with correct provider use and deltas. | FS-HOOK-01–05; FS-TEST-04 |
| FS-A36 | Package/init tests prove buffered legs require providers and identity legs do not; V can be its own provider. Zero/reverting/unavailable V rates fail closed; conversions never settle by linear `shares*getRate`. | FS-HOOK-03; FS-RATE-05/06 |
| FS-A37 | Each hook exact-output route that calls V Out reverts `ExchangeOutNotAvailable()` and rolls back the outer operation; no funds, shares, deltas, or reserve changes survive. | FS-HOOK-04; FS-EXEC-07 |
| FS-A38 | Measure worst supported locked/already-unlocked calls and composed swaps for every integrated hook family, including maintenance plus conversion, native/wrapped forms, and fallback. V retains S1’s 12M transaction/5M preview ceilings; each complete composed hook swap meets FS-GAS-01 rather than merely measuring the inner call. | FS-GAS-01; S1-A70 delta |
| FS-A39 | Two V instances and V plus another SE sharing facets/hooks cannot alter each other’s config, supply, approvals, inventory, position key, provider denomination, or initialization. | FS-BOUND-01/02; FS-PKG-04 |
| FS-A40 | Final review evidences all non-goals: no owner/diamondCut/rescue, second pool/share ledger, Weir fee/locked shares, ERC-4626/transition/unlock-context interfaces, queued withdrawal, exact-output support, deployment/migration, audit claim, or manipulation-safety claim. | FS-BOUND-05; FS-RATE-06; FS-FACET-02/03 |

**FS-GAS-01 — Composed execution envelope.** In addition to S1-GAS-01’s per-vault limits, each supported complete Q/H swap that includes V conversion shall fit the same 12,000,000-gas engineering transaction ceiling (11.9M measured call body plus 100k overhead) and its hook preview the applicable 5,000,000-gas local ceiling. Deterministic planner rejection shall occur before V mutation; no chain-limit or third-party RPC guarantee is claimed. Source: Adaptation “whole outer swap…” and PT-PRD S1-GAS-01. Acceptance: FS-A38.

## 8. Inherited IDs, new `FS-` IDs, and owner decisions still open

### Complete inherited-ID register

Unless delta-mapped in section 2, FullSpread inherits the following PairToken stage-one requirements and their tests by ID, substituting only the family/type/path names:

- **Confirmed decisions:** S1-D01–S1-D05; S1-P01–S1-P07.
- **Deviation/economics register:** S1-X01–S1-X19.
- **Architecture/shared initialization:** S1-ARCH-01–S1-ARCH-05, subject to the family name and query-selector deltas.
- **Accounting:** S1-ACC-01–S1-ACC-07.
- **Operations/native:** S1-OP-01–S1-OP-05, S1-EXIT-01, S1-NATIVE-01, subject only to the scalar already-unlocked branch.
- **Interfaces:** S1-API-01–S1-API-05, with `getRate` added and the other optional interfaces still excluded.
- **Quotes/gas:** S1-QUOTE-01, S1-QUOTE-02, S1-GAS-01.
- **Package/security/events:** S1-PKG-01, S1-SEC-01, S1-SEC-02, S1-OBS-01, with the two settlement-context rules split as specified.
- **Acceptance:** S1-A01–S1-A70, with S1-A40 replaced by FS-A22–FS-A28, S1-A68 adjusted for required `getRate`, S1-A70 extended by FS-A38, and selector counts in S1-A06/A56/A68 changed from 60 to 61 solely for `getRate`.
- **Fixture discipline:** S1-TEST-01, extended by FS-TEST-01–04.

In particular, S1-D03’s removal of dead shares, redemption retention and protocol-fee routing; S1-P03’s unsupported exact output; S1-P05’s conditional withdrawal fallback; S1-P06’s separate SY accounting; S1-P07’s bounded execution; and S1-ACC-07’s non-dilution equation are not reopened.

### New requirement register

| IDs | Subject |
| --- | --- |
| FS-BOUND-01–05 | Family identity, PairToken/Wings deltas, and non-goals |
| FS-FACET-01–03 | Sixty-one-selector package surface, factory exclusions, optional quote absence |
| FS-FILE-01 | Full family/facet/target/repo/library file split |
| FS-PKG-01–05 | PkgInit/PkgArgs, binding/registry/deploy, validation/errors, initialization, factory service |
| FS-MONEY-01 | Inherited paired/zap/compound/donation/quote/native/exact-output surface |
| FS-EXEC-01–07 | Lock selection, operation authority, planner/guard, direct actions, delta baselines, callback closure, rollback |
| FS-HOOK-01–05 | No hook edit, seven-family inventory, leg/provider rules, exact-input scope, two-pool topology |
| FS-RATE-01–06 | Issuance/SY/executable quote separation, normalized getRate, unavailable reads, manipulation limits |
| FS-TEST-01–04 | Production bases, named specs, surface/trust matrix, real cross-vault fixtures |
| FS-A01–FS-A40 | Additive acceptance matrix and explicit S1-A40 replacement |
| FS-GAS-01 | Whole composed-hook-swap execution/preview envelope |

### Owner decisions still open

**None block implementation under this contribution.** The family shape, economics inheritance, strict single-token behavior, native support, unsupported exact output, same-manager execution goal, executable `getRate`, and use of existing hooks are settled by the brief. The existing hooks’ held-reserve valuation law supplies the downstream provider-consumption rule, so no new pricing invariant or oracle choice is introduced here.

The following are deliberately **not** implicit approvals and would require a separate owner/product decision: Q-specific hook allowlists or a new authorization ABI; an accounting-NAV or TWAP provider replacing executable `getRate`; an oracle hook on P; exact-output support; transition/unlock-context quote interfaces; queued withdrawals; changes to existing hook packages; deployment or registry migration. No such open item may be silently resolved by an implementer.

## 9. Limits and sources

This is a static research/PRD contribution, not code, an audit, a gas result, a deployment, or proof of economic/manipulation safety. No Forge, tests, builds, installs, Git, deploys, wallets, or sub-agents were used. No peer response, feedback, coordinator draft, or resolution was read. Proposed selector/interface IDs shall be computed through the repository’s canonical verification workflow during implementation; no hexadecimal constants are invented here.

### Source registry

- **Brief:** `docs/research/fullspread-se-prd-20261030-01a18660/brief.md`.
- **PT-PRD:** `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, sections 1–12, especially S1-ARCH, S1-ACC, S1-OP, S1-API, S1-QUOTE, S1-PKG, S1-SEC, S1-A01–A70, and S1-TEST-01.
- **PT-DFPkg:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol` and `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`.
- **PT-Vault:** `.../pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`.
- **PT-Exec:** `.../pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol`.
- **PT-Types/PT-Repo:** `.../pairToken/UniswapV4PairTokenStandardExchangeVaultTypes.sol` and `...Repo.sol`.
- **PT-ComponentBindings:** `.../pairToken/UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol`.
- **PT-MoneyTarget/PT-SYMoneyTarget/PT-SYQueryTarget/PT-CallbackTarget:** corresponding current files under `.../pairToken/`.
- **Wings-DFPkg:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol`, used only to reject its open facet-array shape.
- **SE-In/SE-Out:** `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` and `IStandardExchangeOut.sol`.
- **IStandardVaultPkg:** `contracts/interfaces/IStandardVaultPkg.sol`.
- **RateProvider:** `lib/crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol`, re-exporting the canonical common `IRateProvider.getRate()`.
- **Hook-Pkg interfaces:** one current `interfaces/I*Package.sol` read for each of `single`, `constantProduct/single`, `dual`, `weighted`, `orbital`, `stable/quad/balancer`, and `stable/quad/curve` under `contracts/hooks/uniswap/v4/standardExchange/`.
- **SingleHookCommon/SingleHookTarget:** `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol` and `...Target.sol`, including exact-input preview/execute and `address(this)` recipient.
- **DualCommon:** `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`, `_buffer`/`_unwrap` and exact-output counterpart.
- **ContextQuote:** `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol`, ERC-165-gated optional projections with standard-preview fallback.
- **Repository law/skills:** `CLAUDE.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md`; `.github/ASSISTANT_CODING.md`; `.github/ASSISTANT_TESTS.md`; `.agents/skills/crane-architecture/SKILL.md`; `.agents/skills/indexedex-testing/SKILL.md`; `.agents/skills/indexedex-uniswap-v4-hook-packages/SKILL.md`; `.agents/skills/indexedex-user-flows/SKILL.md` and its Standard Exchange topic.
- **Adaptation:** `docs/research/v4-vault-adaptation-20261029-01a18660/REPORT.md`, optional context supporting same-unlock direct custody, delta baselines, strict conversion, and normalized executable one-share `getRate`.
- **Survey:** `docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md`, optional comparison context only, not economics authority.
- **Weir:** `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`, optional negative/fidelity context only; no Weir economics imported.
