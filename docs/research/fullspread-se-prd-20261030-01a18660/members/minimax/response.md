# MiniMax — council member response: full-spread Standard Exchange vault PRD fragment

## 1. Identity and route

- **Assigned route label:** `minimax/MiniMax-M3` (assigned by the coordinator in `docs/research/fullspread-se-prd-20261030-01a18660/brief.md`, §"Requested roster"). This label is a **request, not a runtime attestation** of model, provider, or reasoning depth.
- **Role:** independent council member, initial pass. No peer originals, drafts, feedback, or resolutions were read. No peer file was written.
- **Deliverable:** this file only — `docs/research/fullspread-se-prd-20261030-01a18660/members/minimax/response.md`. No project code, config, PRD, plan, or test was created or edited. No Forge, build, install, Git, or deploy was run. No sub-agent was launched.
- **Product under specification:** `UniswapV4FullSpreadStandardExchangeVault` — one registry-deployed Crane diamond owning **one** Uniswap V4 pool position, full-range, with **one** public ERC-20 share supply. It is the Standard Exchange version of the shape the owner clarified in the brief: **not** Weir's one-contract-many-virtual-vaults model.
- **Contribution type:** a merge-ready PRD fragment with stable requirement IDs, not a narrative memo. Every requirement below carries a source, an ID, and an acceptance check.
- **Reading note:** where this fragment and the current source disagree, the source wins. Three places where the brief's summary was checked against source and corrected are called out explicitly in §9.

---

## 2. Family boundary and deltas from PairToken and Wings

### FS-BND-01 — Identity and placement (new)

`UniswapV4FullSpreadStandardExchangeVault` is a **new family** with a **new type identity**. It is a sibling family, not a rename, fork, or restoration.

- Production directory: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` (already exists, empty, per brief §"Artifact root and delivery").
- Type prefix: `UniswapV4FullSpreadStandardExchangeVault` (files, types, FactoryService, TestBase, spec files use the full product name, per `.agents/skills/indexedex-uniswap-v4-hook-packages/SKILL.md` §"Naming (mandatory)").
- **Not** a restoration of the deleted V4 FullSpread families: `CLAUDE.md` records "Both V4 FullSpread families (hookless and Pons) are deleted (owner ruling 2026-10-23, APEX-2026-011). Do not restore them." `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` §2 repeats it: "The retired V4 legacy SE and FullSpread families are not templates to restore."
- **Not** a rename of PairToken: `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` §2 requires "Stage one is a new family with a new type identity."

### FS-BND-02 — The one-diamond / one-pool / one-supply shape (inherits S1-D02, S1-D04, S1-D05, S1-ARCH-01, S1-ARCH-02)

The fullSpread family is exactly the PairToken stage-one ownership shape, restated as this family's boundary:

- One diamond. The diamond **is** the ERC-20 share token. One `PoolKey`. One full-range position with salt `bytes32(0)`, identity `(diamond, tickLower, tickUpper, bytes32(0))`. One public share supply. No singleton manager, no second internal share ledger, no shares-of-shares, no outer wrapper (inherits S1-D05, S1-ARCH-02; brief §"Locked owner decisions" 1).
- Full usable tick range from `TickMath.minUsableTick/maxUsableTick(tickSpacing)`; the diamond's own liquidity is never conflated with pool active liquidity (inherits S1-ARCH-02).
- No operational owner, no strategy setter, no rescue of backing, no `diamondCut`, no upgrade surface (inherits S1-ARCH-02, S1-A68).

### FS-BND-03 — What fullSpread is **not** (new)

| Not this | Why | Source |
|---|---|---|
| Not a Weir copy | Weir is one contract holding many virtual vaults with a per-PoolId internal share ledger, a 5% performance fee, and a permanently locked `MIN_SHARES = 1,000` sink | `docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md` §"Profiles" (Weir); brief §"Locked owner decisions" 7 |
| Not a Weir "add ERC-20 and stop" port | A single global ERC-20 over Weir's per-pool ledgers would merge distinct baskets | `docs/research/v4-vault-adaptation-20261029-01a18660/REPORT.md` §"Why adding ERC-20 is not enough" 1 |
| Not an Upper/Lower Wings copy | Wings owns three position slots (`state.positions[0..2]`), a target-token sleeve, and a rebalance engine; fullSpread owns one position and no sleeve | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol` (`Repo.Position[] positions`, `state.target0`); `.../UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` (`_localTarget`, `_place`, `_fund`) |
| Not an ERC-4626-only wrapper | There is no single underlying token for a two-currency basket; `IERC4626` must not be claimed | `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` S1-API-04 |
| Not a second pool, multi-pool router, or independent price source | Single `PoolKey`; no Chainlink, no second pool, no TWAP construction | brief §"Locked owner decisions" 9; S1-API-04 |
| Not a restored legacy V4 family | Owner ruling 2026-10-23 (APEX-2026-011) deleted the V4 FullSpread families | `CLAUDE.md` |

### FS-BND-04 — Deliberate delta vs. PairToken stage one (new, and small)

PairToken stage one is the packaging and economics exemplar. fullSpread inherits its confirmed decisions **by ID** and changes exactly four things:

| Delta | PairToken stage one | fullSpread | Source |
|---|---|---|---|
| **Already-unlocked entry** | Any family route starting while the manager is unlocked reverts `ManagerAlreadyUnlocked()`; there is no local-sleeve mode | The exact-input Standard Exchange route (`exchangeIn`) detects an already-unlocked manager and executes its manager actions **inline** (no nested `unlock`) | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol:323` and `:548` (`if (TransientStateLibrary.isUnlocked(...)) revert IVault.ManagerAlreadyUnlocked();`); S1-OP-05, S1-SEC-01; brief §"What must be specified" 5 |
| **Executable one-share rate** | `IRateProvider.getRate()` is explicitly *not* installed; only SY `exchangeRate()` (a spot accounting value) exists | fullSpread exposes an **executable normalized one-share withdrawal-and-sale rate**, distinct from SY accounting | `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` S1-API-04, S1-QUOTE-02; brief §"Locked owner decisions" 8 |
| **Hook-leg provider need** | Not applicable (PairToken is not bound into a buffer hook) | A fullSpread leg bound into a V4 buffer hook is a **buffered leg** and therefore **must** carry a rate provider (D60) | `docs/agent/INDEXEDEX_AGENT_LAW.md` §"Uniswap V4 SE buffer hooks: held-reserve valuation (APEX D60)"; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol` (`error RateProviderRequired()`) |
| **Exact-output route** | Both `IStandardExchangeOut` methods revert `ExchangeOutNotAvailable()` | Same (unchanged) — but the consequence for the hook's exact-out unwrap path is now an explicit requirement (FS-HOOK-06) | S1-P03; `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` |

Everything else — the issuance equation, the non-dilution credit equation, the proportional withdrawal equation, the fee checkpoints, the compound sequence, the maintenance fallback, the native custody rules, the quote budgets, the gas envelope, the SY surface, the registry/disable rules, and the full acceptance matrix — is inherited unchanged from PairToken stage one by ID. Section 8 lists the inherited IDs verbatim.

### FS-BND-05 — Deliberate delta vs. Upper/Lower Wings (new)

Wings' already-unlocked behavior is **not** inherited. Wings' model is "local sleeve": when `state.manager.isUnlocked()` is true it skips harvesting and placement entirely and settles only from local inventory (`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:96,102,167,254,262,275`; `.../UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol:43` reverts `ManagerAlreadyUnlocked()` inside `execute`). fullSpread has **no sleeve**: its backing is a live pool position, so an already-unlocked operation must still perform real manager actions, just without opening a second unlock. PairToken stage one already rejected Wings' local-sleeve mode (S1-OP-05: "stage one does not inherit Wings' local-sleeve execution mode"), and fullSpread keeps that rejection while adding the inline mode required for hook integration.

---

## 3. Standard and family facet inventory

### FS-FACET-01 — Shared standard facets (5) — reused unchanged

Verified in source: `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol` (`PkgInit.erc20Facet … PkgInit.standardVaultFacet`) and confirmed by the DFPkg's own selector table (`contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`, `_expectedSelectors(0..4)`).

| # | Facet | Source path | Declared interface(s) | Selectors installed | Why included | Owner |
|---|---|---|---|---|---|---|
| 0 | `ERC20Facet` | `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | `IERC20`, `IERC20Metadata` | 9: `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom` | The share supply **is** the diamond | **Shared** |
| 1 | `ERC2612Facet` | `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `IERC20Permit` | 3: `permit`, `nonces`, `DOMAIN_SEPARATOR` | Canonical permit on the share | **Shared** |
| 2 | `ERC5267Facet` | `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `IERC5267` | 1: `eip712Domain` | EIP-712 domain on the diamond | **Shared** |
| 3 | `MultiAssetBasicVaultFacet` | `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `IBasicVault` | 3: `vaultTokens`, `reserveOfToken`, `reserves` | Two ERC-20 currency faces; booked local custody | **Shared** |
| 4 | `MultiAssetStandardVaultFacet` | `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `IStandardVault` | 4: `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` | Zero stage-one fee types; registry identity | **Shared** |

These 5 contribute **20 distinct package-owned selectors**. `ERC20PermitFacet` must **not** also be installed — its combined ERC-20/permit/domain selectors overlap these three (S1-ARCH-04). The empty `StandardVaultTarget` must not be installed; the functional shared implementation is `MultiAssetStandardVaultTarget` via its facet (S1-API-01).

### FS-FACET-02 — Family facets (7) — inherited from the PairToken exemplar

Verified in source: `PkgInit.moneyFacet … PkgInit.callbackFacet` and the DFPkg's `_expectedSelectors(5..11)`.

| # | Facet | Source path (PairToken exemplar) | Declared interface(s) | Selectors | Why included | Owner |
|---|---|---|---|---|---|---|
| 5 | `MoneyFacet` | `.../pairToken/UniswapV4PairTokenStandardExchangeVaultMoneyFacet.sol` | `IVault`, `IStandardExchangeIn` | 5: `exchangeIn`, `depositPair`, `redeemPair`, `donate`, `compound` | All state-changing money routes | **Family** |
| 6 | `QuoteFacet` | `.../pairToken/UniswapV4PairTokenStandardExchangeVaultQuoteFacet.sol` | `IVault`, `IStandardExchangeIn` | 5: `previewExchangeIn`, `previewDepositPair`, `previewRedeemPair`, `previewWithdrawalMode`, `previewZapCredit` | Execution-equivalent previews | **Family** |
| 7 | `OutFacet` | `.../pairToken/UniswapV4PairTokenStandardExchangeVaultOutFacet.sol` | `IStandardExchangeOut` | 2: `previewExchangeOut`, `exchangeOut` | Installed and reverting per S1-P03 | **Family** |
| 8 | `QueryFacet` | `.../pairToken/UniswapV4PairTokenStandardExchangeVaultQueryFacet.sol` | `IVault` | 11: `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, `maxZapTickMove` | Static and economic discovery | **Family** |
| 9 | `SYMoneyFacet` | `.../pairToken/UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet.sol` | `IStandardizedYield` | 4: `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards` | Native-capable SY execution | **Family** |
| 10 | `SYQueryFacet` | `.../pairToken/UniswapV4PairTokenStandardExchangeVaultSYQueryFacet.sol` | `IStandardizedYield` | 12: `previewDeposit`, `previewRedeem`, `getTokensIn`, `getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`, `isValidTokenIn`, `isValidTokenOut`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored` | SY accounting surface | **Family** |
| 11 | `CallbackFacet` | `.../pairToken/UniswapV4PairTokenStandardExchangeVaultCallbackFacet.sol` | `IUnlockCallback` | 1: `unlockCallback` | The vault's own authenticated manager callback | **Family** |

### FS-FACET-03 — Family facet to add for fullSpread (1) — **new, justified**

fullSpread needs exactly one selector the shared facets do not provide and the seven inherited family facets do not carry: the **executable one-share rate** required by brief §"Locked owner decisions" 8 and by D60's provider requirement for a buffered leg.

| # | Facet | Proposed source path | Declared interface(s) | Selectors | Why | Owner |
|---|---|---|---|---|---|---|
| 12 | `RateFacet` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRateFacet.sol` (+ `…RateTarget.sol`) | `IRateProvider` (`@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol`) | 1: `getRate()` | Exposes the executable normalized one-share withdrawal-and-sale rate (FS-RATE-05) so a V4 buffer hook can bind a rate provider for a fullSpread leg without inventing a second rate authority | **Family** |

The selector is `IRateProvider.getRate.selector` = `0x9576a02f` (canonical selector; the value must be re-derived with `cast sig "getRate()"` in the canonical verification workflow, not hand-copied). It is a **new** selector not present in the shared 20 nor in the 28 inherited family selectors, so no selector overlap is introduced.

**Design note.** `RateFacet` is deliberately *not* folded into `QueryFacet`. `QueryFacet` is the static/economic discovery cut; the rate is a distinct authority with distinct failure modes (a rate that cannot be executed must fail closed), and a separate cut keeps the rate's revert surface off the discovery surface. It is also the only place that will answer "what is one share worth if I sell it", which must never be confused with SY accounting (FS-RATE-01).

### FS-FACET-04 — Factory-owned facets that must **not** appear in `PkgInit` (new, restated with source)

These are supplied by the diamond factory, are **never** package inputs, and must not appear in `facetAddresses()`, `facetCuts()`, or the package's interface aggregation:

| Factory-owned component | Source | Rule |
|---|---|---|
| ERC-165 introspection | `lib/crane/contracts/introspection/ERC165/` | Excluded from `PkgInit`; remains callable on the final proxy |
| Diamond loupe (ERC-2535) | `lib/crane/contracts/introspection/ERC2535/` | Excluded |
| ERC-8109 introspection | `lib/crane/contracts/introspection/` | Excluded |
| Temporary post-deploy hook | Diamond package callback factory lifecycle (`lib/crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol`) | The factory owns its lifecycle; never redeployed, recut, or independently initialized here |

Source for the rule: `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` S1-ARCH-04 ("Exclude all factory-provided facets from the package facet inputs, component deployment list, `facetAddresses()`, `facetCuts()`, and package-owned interface aggregation") and S1-A56/S1-A57; `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol` (`@dev Factory-owned introspection and temporary-hook facets are never package inputs.`). The PairToken DFPkg's constructor confirms the package installs only the 12 declared facets (`_appendComponent(init_.erc20Facet, 0) … _appendComponent(init_.callbackFacet, 11)`) and nothing else.

### FS-FACET-05 — Selector/interface accounting (new)

- Package-owned selectors: **20 shared + 28 inherited family + 1 new rate = 49**.
- The final proxy's persistent selector set is the **disjoint union** of package-owned and factory-owned selectors. It must never be asserted equal to the package cut alone (S1-A06, S1-A57).
- `PkgInit` order is the package's binding order and therefore part of `bindingHash`; `RateFacet` is appended at index 12 so the first twelve indices keep the PairToken ordering.

---

## 4. Proposed file and package contract

### FS-ARCH-01 — Proposed file layout (new)

Root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Mirrors the current PairToken split (`contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`) exactly — facet, target, repo, types, math, projection, planner, execution, callback — with one added facet/target pair and one added interface.

```text
contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/
├── interfaces/
│   ├── IUniswapV4FullSpreadStandardExchangeVault.sol
│   └── IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
├── UniswapV4FullSpreadStandardExchangeVaultTypes.sol
├── UniswapV4FullSpreadStandardExchangeVaultRepo.sol
├── UniswapV4FullSpreadStandardExchangeVaultMath.sol
├── UniswapV4FullSpreadStandardExchangeVaultProjection.sol
├── UniswapV4FullSpreadStandardExchangeVaultPlanner.sol
├── UniswapV4FullSpreadStandardExchangeVaultExecution.sol
├── UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol
├── UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol
├── UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
├── UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol      + …MoneyTarget.sol
├── UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol      + …QuoteTarget.sol
├── UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol        + …OutTarget.sol
├── UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol      + …QueryTarget.sol
├── UniswapV4FullSpreadStandardExchangeVaultSYMoneyFacet.sol    + …SYMoneyTarget.sol
├── UniswapV4FullSpreadStandardExchangeVaultSYQueryFacet.sol    + …SYQueryTarget.sol
├── UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol   + …CallbackTarget.sol
├── UniswapV4FullSpreadStandardExchangeVaultRateFacet.sol       + …RateTarget.sol
└── test/
    ├── bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol
    └── behaviors/Behavior_UniswapV4FullSpreadStandardExchangeVaultPackage.sol
```

Mirror of the exemplar's mapping (verified against the current PairToken tree):

| PairToken file | fullSpread file | Notes |
|---|---|---|
| `…VaultTypes.sol` | `…VaultTypes.sol` | `Config`, `Amounts`, `WrappedReservations`, `Inventory`, `OperationKind`, `Phase`, `ActionKind`, `FailureKind`, `Operation`, `PoolState`, `Snapshot`, `TickState`, `BitmapWord`, `ProjectedState`, `Witness`, `Action`, `Failure`, `Plan` |
| `…VaultRepo.sol` | `…VaultRepo.sol` | `Storage { config, inventory, initialized, operation, callbackHash }`; ERC1967-form namespace `bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"))) - 1)`; `_requireIdle()` |
| `…VaultMath.sol` | `…VaultMath.sol` | |
| `…VaultProjection.sol` | `…VaultProjection.sol` | Contains **both** `Projection` and `SwapProjection` (see the exemplar's `ComponentBindings`) |
| `…VaultPlanner.sol` | `…VaultPlanner.sol` | |
| `…VaultExecution.sol` | `…VaultExecution.sol` | Contains **both** `Execution` and `ExecutionPreparation` |
| `…VaultComponentBindings.sol` | `…VaultComponentBindings.sol` | `linkedComponents() -> address[6]` |
| `…VaultComponent_FactoryService.sol` | `…VaultComponent_FactoryService.sol` | Artifact-first CREATE3 deployment + runtime/link verification |
| `…VaultDFPkg.sol` | `…VaultDFPkg.sol` | |

**Naming rules.** Full product name in every type, file, FactoryService, TestBase, and spec file. No `FS`, `FSSE`, or other short alias in production type or file names (`indexedex-uniswap-v4-hook-packages/SKILL.md` §Naming; `CLAUDE.md` §Non-negotiables 4).

### FS-ARCH-02 — Linked components (new)

`address[6] linkedLibraries`, identical role list to the exemplar, deployed by CREATE3 with the same names-and-files mapping:

| Index | Library | File |
|---|---|---|
| 0 | `UniswapV4FullSpreadStandardExchangeVaultMath` | `…VaultMath.sol` |
| 1 | `UniswapV4FullSpreadStandardExchangeVaultProjection` | `…VaultProjection.sol` |
| 2 | `UniswapV4FullSpreadStandardExchangeVaultSwapProjection` | `…VaultProjection.sol` |
| 3 | `UniswapV4FullSpreadStandardExchangeVaultPlanner` | `…VaultPlanner.sol` |
| 4 | `UniswapV4FullSpreadStandardExchangeVaultExecution` | `…VaultExecution.sol` |
| 5 | `UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation` | `…VaultExecution.sol` |

The DFPkg must reject a family facet whose `linkedComponents()` hash differs from the package's `linkedLibraries` — the exemplar's `_appendComponent` already enforces this for indices ≥ 5 (`keccak256(abi.encode(IComponentBindings(address(facet_)).linkedComponents())) != keccak256(abi.encode(linkedLibraries))` → `InvalidComponent()`). **FS-ARCH-02a:** with `RateFacet` appended at index 12, the same equality check must apply to index 12 (the exemplar's condition is `index_ >= 5`, so index 12 is already covered — this requirement records that the new facet must declare the same `linkedComponents()`).

### FS-PKG-01 — `PkgInit` (new; shape inherited from the exemplar, verified in source)

`PkgInit` and `PkgArgs` are defined on the **interface** `IUniswapV4FullSpreadStandardExchangeVaultDFPkg`, never on the contract (`CLAUDE.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md` §"Vault DFPkg Requirements"; `lib/crane/AGENTS.md` §Architecture Overview).

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
    IFacet rateFacet;          // FS-FACET-03, new at index 12
    IPoolManager poolManager;
    IVaultRegistryDeployment registry;
    IVaultFeeOracleQuery oracle;
    IWETH wrappedNative;
    IDiamondPackageCallBackFactory diamondFactory;
    address[6] linkedLibraries;
}
```

Thirteen facet fields, six infrastructure bindings, one linked-library array. The infrastructure set is **identical** to the exemplar — the same `poolManager`, `registry`, `oracle`, `wrappedNative`, `diamondFactory` are sufficient because the inline execution mode uses the same `IPoolManager` and no new infrastructure is introduced (FS-CB-03). No `IPermit2` binding is added (unlike Wings, which has `IPermit2 permit2` in its `PkgInit`) — permit flows use the canonical `ERC2612Facet`.

### FS-PKG-02 — `PkgArgs` (new; identical to the exemplar)

```solidity
struct PkgArgs {
    PoolKey poolKey;
    address rateAsset;
    string name;
    string symbol;
    uint16 maxZapBps;
    int24 maxZapTickMove;
}
```

**No new argument is added.** This is a deliberate decision:

- The already-unlocked mode is selected by the **manager's runtime state**, not by a deployment flag (FS-CB-01). Adding an "unlocked mode enabled" boolean would be a silent default and would not be expressible in a `bindingHash` that the registry can validate.
- The rate is derived from the family's own state and `rateAsset`; no rate-provider address is a `PkgArgs` field, because the rate provider for a hook leg is a **hook-side** binding owned by the hook deployer (`docs/agent/INDEXEDEX_AGENT_LAW.md` §D60: "Any leg may carry a rate provider; the deployer is responsible for the provider matching the bound token").
- There is deliberately **no integrator allowlist**. A vault-bound allowlist would be circular: the hook's `PkgArgs` contains the vault address and the vault's `PkgArgs` would have to contain the hook address. **FS-PKG-02a:** the already-unlocked mode is therefore gated by *route* and by *caller authority*, not by an address allowlist — see FS-CB-01 and FS-CB-04.

### FS-PKG-03 — `bindingHash`, salt, and identity (inherits S1-PKG-01, S1-ARCH-03)

- `bindingHash = keccak256(abi.encode(init_))` — the whole `PkgInit`, all 13 facets, all six infrastructure bindings, and the linked-library array. Constructed once in the package constructor as an immutable.
- `calcSalt(bytes args_) = keccak256(abi.encode(bindingHash, abi.decode(args_, (PkgArgs))))` — identical to the exemplar.
- `processArgs(bytes args_)` is `view`, requires `msg.sender == address(REGISTRY)` **and** `address(this) == address(DIAMOND_FACTORY)`, else `NotCalledByRegistry()`; it decodes `PkgArgs`, runs `_validate`, and returns `abi.encode(decoded_)`.
- All economically relevant immutable arguments participate in instance identity (S1-A02).

### FS-PKG-04 — `deployVault` and registry entry (inherits S1-PKG-01)

- `deployVault(PkgArgs memory args_) external returns (address vault)` → `REGISTRY.deployVault(this, abi.encode(args_))`.
- The package is registered through the IndexedEx manager vault registry path (`indexedexManager.deploy*DFPkg` / `registry.deployPkg`), **never** a direct `diamondPackageFactory.deploy` call for a registered vault package (`CLAUDE.md` §Non-negotiables 2; `indexedex-testing` §"Two deploy paths (critical)").
- The instance is registered by its two ERC-20 currency faces and its declared vault types (S1-A01, S1-A58).

### FS-PKG-05 — Package errors (new; inherited set plus source-verified selectors)

| Error | Signature | Selector (source) | Trigger |
|---|---|---|---|
| `InvalidComponent()` | `InvalidComponent()` | `0xb03ac0b6` | A required component is absent, has no code, or its `linkedComponents()` does not match `linkedLibraries` |
| `InvalidPoolKey()` | `InvalidPoolKey()` | `0xc256622b` | Currency ordering, code presence, hook address, fee, tick spacing, self-reference, or uninitialized pool |
| `InvalidRateAsset()` | `InvalidRateAsset()` | `0x41ef82fd` | `rateAsset` is not one of the two declared ERC-20 currency faces |
| `InvalidZapLimits()` | `InvalidZapLimits()` | `0x70965b62` | `maxZapBps == 0` or `> 10_000`, or `maxZapTickMove < 0` |
| `InvalidWrappedNative()` | `InvalidWrappedNative()` | `0x5e66e44d` | Wrapper is not a canonical 18-decimal one-to-one wrapper, or the two faces collide |
| `NotCalledByRegistry()` | `NotCalledByRegistry()` | `0xd8af869a` | `processArgs` called outside the bound registry/factory context |
| `InvalidInitializationContext()` | `InvalidInitializationContext()` | `0x0bda07c4` | Proxy initialization does not match the bound factory's package and arguments |
| `AlreadyInitialized()` | `AlreadyInitialized()` | `0x0dc149f0` | Re-initialization attempt |

All eight are declared on `IUniswapV4FullSpreadStandardExchangeVaultDFPkg`, with the same `@custom:signature` / `@custom:selector` tags as the exemplar (`contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol`). **FS-PKG-05a:** the interface keeps the exemplar's `@custom:interfaceid 0xc283faa9` **only if** the fullSpread interface's function set is byte-identical to the exemplar's. Because `RateFacet` adds `getRate()` to the package but **not** to the package interface, the DFPkg interface's own function set is unchanged and the interface ID may be reused; the coordinator must recompute it with the canonical verification workflow rather than copying the hex. The **family vault interface** `IUniswapV4FullSpreadStandardExchangeVault` gains no function from `RateFacet` (the rate is reached through `IRateProvider`), so its interface ID likewise must be recomputed, not copied.

### FS-PKG-06 — `initAccount` initialization (inherits S1-ARCH-05)

In the proxy's `initAccount` delegatecall, in this order:

1. Verify `address(this) != SELF`, `DIAMOND_FACTORY.pkgOfAccount(address(this)) == SELF`, `keccak256(DIAMOND_FACTORY.pkgArgsOfAccount(address(this))) == keccak256(args_)`; else `InvalidInitializationContext()`.
2. `Repo._layoutStruct().initialized` must be false; else `AlreadyInitialized()`.
3. `ERC20Repo._initialize(name, symbol, 18)` — zero initial supply; only the deposit logic creates shares.
4. `EIP712Repo._initialize(name, "1")`.
5. `MultiAssetBasicVaultRepo._initialize([C0, C1])` in PoolKey face order.
6. `StandardVaultRepo._initialize(ORACLE, bytes32(0), facetInterfaces(), keccak256(abi.encode(sortedFaces)))` where `sortedFaces` is an **address-sorted** copy of `[C0, C1]`; the stored face order remains PoolKey order.
7. Family `Config`: `poolManager`, `poolKey`, `registry`, `wrappedNative`, `rateAsset`, `tickLower = TickMath.minUsableTick(tickSpacing)`, `tickUpper = TickMath.maxUsableTick(tickSpacing)`, `maxZapBps`, `maxZapTickMove`, `rateAssetDecimals = IERC20Metadata(rateAsset).decimals()` (cached; **never** used to normalize the raw-unit SY rate).

All family state lives in the family namespace; no shared Repo is initialized on a facet address; factory-owned introspection state is untouched.

### FS-PKG-07 — `processArgs` validation (inherits S1-ARCH-03)

`_validate` must reject, with the error named in FS-PKG-05: `token0 >= token1`; missing code on `token1` or on a nonzero `token0`; `poolKey.hooks != address(0)`; `poolKey.fee > 1_000_000`; `tickSpacing <= 0 || tickSpacing > 32767`; `token0 == address(this) || token1 == address(this)`; identical resolved ERC-20 faces; `rateAsset` not one of the two faces; `maxZapBps` out of range; `maxZapTickMove < 0`; and an uninitialized pool (`MANAGER.getSlot0(poolId).sqrtPriceX96 == 0`). The wrapped-native binding is probed at package construction: 18 decimals, `deposit()` and `withdraw(0)` both callable, and the wrapper's balance unchanged by the probe.

No token-decimals allowlist, no FoT/rebase detector, no issuer-blacklist check (token policy, `docs/agent/INDEXEDEX_AGENT_LAW.md` §"Token policy"; S1-ARCH-03).

---

## 5. Money, callback, and already-unlocked hook entry

### FS-MONEY-01 — Money surface (inherits S1-API-05, S1-OP-01..05, S1-NATIVE-01)

The family ABI is the exemplar's ABI, unchanged:

| Function | Behavior | Source ID |
|---|---|---|
| `depositPair(uint256,uint256,uint256,address,uint256) payable → uint256` | Paired deposit of accepted portions of two maxima | S1-OP-01 |
| `previewDepositPair(uint256,uint256) → (uint256,uint256,uint256)` | Execution-equivalent paired preview | S1-OP-01, S1-QUOTE-01 |
| `redeemPair(uint256,uint256,uint256,address,uint256) → (uint256,uint256)` | Proportional paired redemption | S1-OP-03 |
| `previewRedeemPair(uint256) → (uint256,uint256)` | Execution-equivalent paired preview | S1-OP-03, S1-QUOTE-01 |
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256) → uint256` | Exact-input SE route (four supported directions) | S1-API-02 |
| `previewExchangeIn(IERC20,uint256,IERC20) → uint256` | Exact-input preview | S1-QUOTE-01 |
| `previewExchangeOut(IERC20,IERC20,uint256)` / `exchangeOut(...)` | **Both revert `ExchangeOutNotAvailable()`** without transfer, burn, mint, or manager mutation | S1-P03 |
| `donate(address,uint256) payable` | Permissionless donation; credits observed delta, mints no shares | S1-ACC-04 |
| `compound() → (uint256,uint256)` | Permissionless maintenance; reports total fees realized by all checkpoints, once | S1-OP-05 |
| `previewWithdrawalMode(uint256,bool,address) → (WithdrawalMode,MaintenanceReason)` | The preflight-selected maintenance plan | S1-EXIT-01 |
| `previewZapCredit(address,uint256) → (uint256,uint256,uint256,uint256,uint256)` | Share credit and uncredited residual | S1-OP-02 |
| SY: 16 methods | `deposit`, `redeem`, `previewDeposit`, `previewRedeem`, `getTokensIn`, `getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`, `isValidTokenIn`, `isValidTokenOut`, `getRewardTokens`, `accruedRewards`, `rewardIndexesCurrent`, `rewardIndexesStored`, `claimRewards` | S1-API-03 |

Events (family-specific): `PairDeposited`, `PairRedeemed`, `WithdrawalSale`, `Donated`, `Compounded`, `ZapCredit`, `WithdrawalMaintenanceSelected` — same payloads and topic-zero hashes as the exemplar (S1-OBS-01).

Enums on the family interface: `WithdrawalMode { FullCompound, CollectOnly }`, `MaintenanceReason { None, MaintenanceWorkLimit, MaintenancePriceLimit, MaintenanceLiquidityLimit, MaintenanceDeltaLimit }`.

Family errors on the family interface: `ReentrantOperation()`, `ManagerAlreadyUnlocked()`, `EconomicStateChanged()`, `InvalidAccountingState()`, `ZeroPayout()`, `QuoteWorkExceeded(uint256,uint256)`, `QuoteTickCrossingsExceeded(uint256,uint256)`, `QuoteBitmapWordsExceeded(uint256,uint256)`, `IssuanceDisabled()` (S1-OBS-01).

### FS-MONEY-02 — One-token entry/exit consumes the whole leg (inherits S1-OP-02, S1-OP-04, S1-X12, S1-X15)

- A single-token zap **in** swaps a caller-sized portion and mints against the attributable reserve growth at the post-swap incumbent snapshot (S1-ACC-07). It never mints from incumbent idle or incumbent fees.
- A single-token zap **out** removes the proportional position, sells the **complete** unwanted allocation through the remaining pool liquidity, and requires full consumption of that allocation. A partial sale reverts the whole transaction; the caller is never left holding the unwanted leg, and shares are never burned with the residual donated (S1-OP-04; brief §"Locked owner decisions" 6).
- `ZeroPayout()` is raised when a positive-share burn would produce zero total payout in the requested currency.
- The paired route is the fallback when the single-token sale is not plannable; the caller chooses.

### FS-MONEY-03 — Native ETH (inherits S1-NATIVE-01, S1-P02)

Native ETH in `currency0` is supported. The PoolKey is unchanged (`address(0)` stays native). The ERC-20 face mapping is `C0 = wrappedNative` when `currency0` is native, `C1 = currency1`, in PoolKey order. Native reserves are ETH in wei, not a fictional ERC-20 balance at `address(0)`. Standard SE methods remain nonpayable and reject `address(0)` routes; native entry/exit uses the payable family methods. A wrapped-native boundary must never remove native operation.

### FS-CB-01 — The already-unlocked entry: what it is (new)

**FullSpread adds one execution mode that PairToken stage one does not have: an inline execution mode for the exact-input Standard Exchange route when the PoolManager is already unlocked.**

Context and the exact failure it fixes: a V4 buffer hook that holds fullSpread shares is itself a Uniswap V4 hook. When the hook's `beforeSwap`/join/exit callback fires, the outer caller already holds the manager unlocked for the consuming pool. The hook then calls `IStandardExchangeIn(se).exchangeIn(...)` on the fullSpread vault (source: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol`, `buffer(...)` and `unwrap(...)`; the same shape in `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`). The vault must then add liquidity to and swap in **its own backing pool** — and it must do so **without opening a second unlock**, because the manager rejects nested unlocks.

**FS-CB-01a — mode selection.** At the start of an `exchangeIn` operation the family reads `TransientStateLibrary.isUnlocked(config.poolManager)`:

- **false** → the ordinary path: the family opens **its own** unlock, the manager calls back into the family's `unlockCallback`, and the family authenticates and settles there (identical to the exemplar).
- **true** → the **inline path**: the family performs its manager actions directly (`poolManager.modifyLiquidity(...)`, `poolManager.swap(...)`) and settles its own deltas inside the same call. No `poolManager.unlock(...)` is issued by the family.

**FS-CB-01b — the unlocked flag is not authorization.** The unlocked state selects the execution mode; it grants **no** authority that the ordinary path does not already require. In both modes the family must enforce, before any fund movement:

1. the family operation guard (`operation == None`, else `ReentrantOperation()`), and `callbackHash == bytes32(0)`;
2. the deadline (`request.deadline < block.timestamp` → `DeadlineExceeded(deadline, block.timestamp)`);
3. a valid recipient (not `address(0)`, not `address(this)`);
4. the caller's share authority for a redemption (`msg.sender` holds the shares, or the vault-held-share path with `LocalCreditLib.requirePretransferCaller`);
5. the caller's minimum output;
6. registry disable for inbound issuance (`IssuanceDisabled()`);
7. `pretransferred` handling identical to the ordinary path (`EOAPretransferNotAllowed()` for a code-less caller; exact-delivery check; booked inventory never used as credit).

The inline path **must not** relax any of these, and **must not** skip the planner, the witness/state checks, the settlement, or the solvency check.

**FS-CB-01c — the family's callback is never impersonated.** The family's `unlockCallback` must continue to require, jointly: `msg.sender == address(config.poolManager)`, an active operation (`operation != None`), a non-zero committed `callbackHash` equal to `keccak256(abi.encode(operation, payload))`, and `TransientStateLibrary.isUnlocked(poolManager)`. During an inline operation the family's `callbackHash` is zero and no callback is expected, so any callback arriving mid-inline-operation fails on the hash check. A nested `poolManager.unlock(...)` cannot occur while the manager is already unlocked (the manager itself rejects it), so the family's callback cannot be reached by an outer actor.

### FS-CB-02 — Inline execution mechanics (new)

The inline path reuses the exemplar's planner and witness machinery exactly; only the *dispatch* changes.

| Step | Ordinary path | Inline path |
|---|---|---|
| Plan | `Planner.plan(state, operation)` — same | **Same** |
| Manager action | `poolManager.unlock(payload)` → family's `unlockCallback` → `_managerAction(...)` | `poolManager.modifyLiquidity(...)` / `poolManager.swap(...)` called **directly** by the family |
| Action validation | In `unlockCallback`: `actual == action.callerDelta`, `fees == action.feesAccrued`, else `EconomicStateChanged()` | **Same checks, executed inline** immediately after the action returns |
| Witness validation | `_checkState(beforeState, ticks, words, afterState)` before and after settlement | **Same checks, executed inline** |
| Settlement | `_settle(currency, amount)` for currency0 then currency1; `_zeroDeltas(...)`; `getNonzeroDeltaCount(...) != 0` → `SettlementMismatch()` | **Same settlement helpers**, but the delta assertion is **per-address** (FS-CB-03) |
| Position owner | `ModifyLiquidityParams(tickLower, tickUpper, liquidityDelta, bytes32(0))` called by the family, so the family is the owner | **Identical** — the family is still the caller, so the position owner remains this diamond |

**FS-CB-02a — position ownership.** Because the family itself calls `poolManager.modifyLiquidity`, the managed position key stays `(address(this), tickLower, tickUpper, bytes32(0))`. The inline path must not delegate the liquidity mutation to the hook, the outer router, or any other address.

### FS-CB-03 — Per-address delta closure in the inline path (new)

`TransientStateLibrary.getNonzeroDeltaCount(manager)` reads the **global** `NonzeroDeltaCount` transient slot (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol`), which counts **every** address's open deltas. Inside an outer unlock the hook and the outer router legitimately hold open deltas while the family runs. Therefore:

- **FS-CB-03a:** in the inline path the family must **not** assert `getNonzeroDeltaCount(manager) == 0`. It must assert that **its own** per-currency delta is zero after settlement, using `TransientStateLibrary.currencyDelta(manager, address(this), currency) == 0` for currency0 and currency1.
- **FS-CB-03b:** the family's `settle`/`take` calls must use the canonical sync-then-settle discipline and must not depend on another actor's pending sync. Crane's `PoolManager._settle` computes `paid = currency.balanceOfSelf() - CurrencyReserves.getSyncedReserves()` (`lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:299-317`), i.e. it credits the caller with the **increase since the last sync**. The family must therefore call `sync(currency)` immediately before its own transfer and `settle()` immediately after, and must call `sync(Currency.wrap(address(0)))` immediately before every native value settlement (inherits S1-NATIVE-01). The family must never call `settleFor(otherAddress)` and must never reuse a `sync` performed by another actor.
- **FS-CB-03c:** after the family returns, the outer unlock's final global `getNonzeroDeltaCount == 0` check must pass because the family closed its own deltas. The hook and the outer router remain responsible for theirs.

### FS-CB-04 — Which routes may use the inline mode (new)

**Only the exact-input Standard Exchange route (`exchangeIn`) may use the inline mode.** It is the route the buffer hooks use, in both directions (`exchangeIn(pairToken → se)` on inflow, `exchangeIn(se → pairToken)` on outflow — `.../stable/quad/curve/...ClaimLib.sol`, `buffer(...)` and `unwrap(...)`).

All other family routes keep the self-unlock requirement and revert `ManagerAlreadyUnlocked()` when the manager is already unlocked:

| Route | Inline mode allowed? | Reason |
|---|---|---|
| `exchangeIn` (SE exact-input) | **Yes** | The only route a V4 buffer hook invokes on a bound SE |
| `depositPair` | No | Paired bootstrap/entry is a user route; keeping it self-unlock-only prevents a hook from mutating the family's genesis state inside an unrelated unlock |
| `redeemPair` | No | Same |
| `compound()` | No | Maintenance is the family's own scheduled action; forcing it into someone else's unlock adds no product value and widens the surface |
| `donate()` | No | Same |
| SY `deposit` / `redeem` | No | Same |
| `previewExchangeIn` / other previews | N/A | Views; the manager state is not consulted by the planner |

**FS-CB-04a:** the mode is decided **once**, at operation start, before any pull or manager mutation, and is then fixed for the whole operation. A plan is never re-planned mid-operation under a different mode.

### FS-CB-05 — Stale-plan behavior in the inline path (new)

If the outer unlock changes the family's backing pool between the family's plan and its action — for example the outer actor is swapping in the **same** backing pool — the family's witness/state check must fail and the operation must revert `EconomicStateChanged()`. The inline path must never execute a plan computed against a different pool state, and must never silently re-plan.

### FS-CB-06 — Maintenance inside the inline mode (new)

The inline path runs the **same** maintenance engine as the ordinary path, including the S1-EXIT-01 conditional fallback. It must **not** silently substitute an unconditional collection-only execution for a full-compound plan, and it must not weaken the S1-QUOTE-01 budgets. If the maintenance obstacle is one of the four permitted reasons and the collection-only candidate plans cleanly, that candidate is used and `WithdrawalMaintenanceSelected(mode, reason)` is emitted with the same reason as `previewWithdrawalMode` reports.

### FS-CB-07 — Callback and guard invariants (inherits S1-SEC-01)

- One cross-facet operation guard covers all money methods, `compound`, `donate`, and callback execution. The sequence is: validate → guard → input isolation → complete preflight → selected maintenance → execution → reservation settlement → shared reserve publication → guard release.
- Economic reads (basket/position/local-book, credit/mode queries, paired/SE/SY previews, SY `exchangeRate`) revert `ReentrantOperation()` during an operation. Unchanged `IBasicVault` reserve queries return the last committed shared-Repo snapshot. Canonical token/metadata/domain reads retain canonical behavior.
- The family's callback payload commitment is `keccak256(abi.encode(operation, payload))`, committed before each unlock and consumed exactly once at callback entry. All reservations and `callbackHash` are zero at successful external return.

---

## 6. Rate, quote, and issuance separation

### FS-RATE-01 — Three distinct quantities, never collapsed (new)

| Quantity | Function | Meaning | Is it an issuance input? |
|---|---|---|---|
| **Issuance** | `previewDepositPair` / `previewZapCredit` / the actual `depositPair` / `exchangeIn` mint | Shares minted against **attributable reserve growth** under S1-ACC-07 | — (it *is* the issuance) |
| **SY accounting value** | `exchangeRate()` | Spot-marked **raw rate-asset units per 1e18 raw share units**, computed from `A_i = N_i(P,L) + B_i + F_i` | **No.** Never an input to issuance (S1-QUOTE-02, S1-P06) |
| **Executable one-share exit rate** | `getRate()` (new, `IRateProvider`) | The **normalized one-share withdrawal-and-sale quote**: what one whole share can actually be converted into, if executed now | **No.** It is an exit quote, not issuance accounting |

### FS-RATE-02 — Issuance equation (inherits S1-ACC-02, S1-ACC-07)

Paired candidate `qQuote` by the four-branch table of S1-ACC-02 (genesis geometric mean; two-sided limiting ratio; one-sided leg). Final mint is capped by attributable credit:

```text
G_i = N_i(P*, L + dL) - N_i(P*, L)          // removable principal growth at the frozen price
paired: C_i = G_i + J_i   (J_i = caller's idle input after paying actual principal costs)
zap:    C_i = G_i
qCredit = min over i with R_i > 0 of floor(S * C_i / R_i)
paired q = min(qQuote, qCredit);   zap q = qCredit
```

The acceptance predicate `q * R_i <= S * C_i` for every positive `R_i` is the non-dilution invariant (S1-A15). Zero supply with both reserves zero is rejected as an invalid accounting state, not issued against.

### FS-RATE-03 — SY accounting value (inherits S1-QUOTE-02)

`assetInfo()` reports `TOKEN`, the configured `rateAsset`, and its cached initialization-time decimals. `exchangeRate()` reports **raw rate-asset units per 1e18 raw share units**: with `r = P / 2^96`, value in raw token1 units is `A1 + floor(A0 * r^2)` and in raw token0 units `A0 + floor(A1 / r^2)` — one floor after the complete conversion, then one floor at the rate. `exchangeRate = floor(Vraw * 1e18 / S)`; zero supply returns zero. The rate is price-sensitive, is not an execution guarantee, and is not manipulation-resistant.

### FS-RATE-04 — The executable one-share exit rate: `getRate()` (new)

`getRate()` returns the **normalized one-share withdrawal-and-sale quote** in raw `rateAsset` units per one whole share (1e18 raw share units), computed by running the family's **real** exit plan for exactly one whole share:

1. Run the family's normal withdrawal planner for `1e18` shares (or the whole supply when the supply is below 1e18, in which case the rate is per whole share of the actual supply — the coordinator must pick one and the PRD must state it; see FS-OPEN-03).
2. Include the same maintenance choice, fee checkpoints, proportional removal, unwanted-leg sale, rounding, and the same S1-QUOTE-01 budgets as a real exit.
3. Normalize the resulting raw `rateAsset` amount to one whole share using full-precision arithmetic, then convert to `rateAsset` decimals only for presentation of the WAD result.
4. **Fail closed**: if the exit is not plannable within the budgets, the rate is `0` (never a partial, never a NAV substitute, never a spot portfolio value).

**FS-RATE-04a — the rate is not NAV.** `getRate()` is **not** `exchangeRate()` scaled, and not the family's book value per share. It is the *executable* exit value. The two are expected to differ whenever the unwanted leg cannot be sold at the accounting price, and they must differ in the fixtures.

**FS-RATE-04b — the rate is not an issuance input.** `getRate()` is never read by the issuance path. Issuance reads only `R_i`, `G_i`, `J_i`, `S`.

**FS-RATE-04c — units.** The rate is denominated in `rateAsset` raw units per one whole share. Because `rateAsset` is one of the two pool currency faces (S1-ARCH-03), the rate is a price of one share in terms of that face, not a human-normalized "whole token per whole share" figure. The exact scaling constant must be stated on the interface and re-derived by the canonical verification workflow.

**FS-RATE-04d — the rate is not manipulation-resistant.** The backing pool is the only price reference (brief §"Locked owner decisions" 9). The rate is a live, price-sensitive, executable quote. It must not be described as an oracle, a TWAP, or a manipulation defense anywhere in the family interface NatSpec.

### FS-RATE-05 — Why `getRate()` exists on this family (new)

D60 requires a rate provider for a **buffered leg** (`token != se`) and forbids the hook from deriving a rate from the SE's own quotes (`docs/agent/INDEXEDEX_AGENT_LAW.md` §D60; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol`: `error RateProviderRequired()`). A fullSpread leg in a hook is a buffered leg, so it must carry a provider.

The production provider that exists today — `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` — prices the **entire book**: it calls `previewExchangeIn(seShare, totalSupply, rateTarget)` and normalizes by `totalSupply`, with the explicit comment "Price the entire book even when settlement cannot physically exit it. A failed full-book quote must not silently become a smaller trade." For a fullSpread vault whose position dominates its backing pool, the whole-book sale is frequently **not sellable**, so the provider returns `0`, and the hook's `rateAfterExchange` reverts `RateProviderFailed` (`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol`: `if (!ok || data.length != 32) revert RateProviderFailed(); if (rate == 0) revert RateProviderFailed();`).

Therefore:

- **FS-RATE-05a:** the fullSpread family exposes `getRate()` so that a provider can be bound that prices the family **per share** and **fail closed** when the per-share exit is not executable. The family does not install a Balancer rate-provider package; it installs only the `IRateProvider.getRate()` selector (FS-FACET-03).
- **FS-RATE-05b:** a **fullSpread-specific rate provider** that returns the vault's `getRate()` (rather than a whole-book `previewExchangeIn`) is a **separate requirement**, not part of this PRD's implementation scope — see FS-HOOK-05. It is needed before a fullSpread leg can be bound to a reserve-holding buffer hook with a provider that does not fail closed at zero supply.
- **FS-RATE-05c:** the zero-supply case must be handled explicitly. The existing provider's `_initialRate` inverts a unit target deposit (`previewExchangeIn(rateTarget, 10**decimals, se)`) to publish an initial mint rate rather than `0` (`StandardExchangeRateProviderFacet.sol`, `_initialRate`). fullSpread's `getRate()` at zero supply has no exit value to quote; the family must return `0` and the provider must supply the initial rate. This is a deliberate asymmetry, stated here so it is not "fixed" later by accident.

### FS-RATE-06 — The three quantities must not be conflated in code or docs (new)

- `exchangeRate()` (SY) and `getRate()` (rate provider) are separate functions with separate selectors, separate failure modes, and separate NatSpec.
- The `RateFacet` (FS-FACET-03) must not declare or re-export `IStandardizedYield`.
- No preview, quote, or accounting view may return the SY rate as if it were an executable quote, or the executable quote as if it were an accounting value.
- The family must **not** claim `IERC4626` (S1-API-04): there is no single underlying token.

---

## 7. Test and acceptance requirements, including cross-vault hook integration

### FS-TEST-01 — Fixture and discipline (inherits S1-TEST-01)

- New reusable fixture: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol`, extending `IndexedexTest` and `TestBase_Weth9`, mirroring `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`.
- The base deploys: a real `PoolManager` via `create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"), …)`; the 5 shared facets via `create3Factory.deployERC20Facet()` / `deployERC2612Facet()` / `deployERC5267Facet()` / `deployMultiAssetBasicVaultFacet()` / `deployMultiAssetStandardVaultFacet()`; the 8 family facets via the family's `Component_FactoryService`; the package via `Components.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(indexedexManager, pkgInit)` under `vm.prank(owner)`; the instance via `package.deployVault(args)`.
- **No mock, no `vm.mockCall`, no bytecode etch, no storage injection, no subclassing of the vault or the PoolManager.** The vault and the manager are the real production artifacts.
- Non-SUT doubles only: `ERC20PermitMintableStub` for the two pool currencies, and a `PoolActor` harness that acts as an external liquidity provider in the backing pool (the exemplar already has `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/harness/PoolActor.sol`; fullSpread gets its own copy under `…/fullSpread/harness/PoolActor.sol`).
- `forge build` before `forge test`, because the FactoryService reads creation bytecode from `out/` (`CLAUDE.md` item 10; `indexedex-testing` §"`forge build` before `forge test` (LOCKED)").
- No `via_ir`; no lowered fuzz or invariant depth; no fixed sleeps; every assertion on exact balances, supply, liquidity, events, and errors.

### FS-TEST-02 — Proposed spec files (new)

Under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`:

| File | Covers |
|---|---|
| `UniswapV4FullSpreadStandardExchangeVaultDeployment.t.sol` | Package registration, identity, validation errors, re-initialization, wrong-registry, invalid components |
| `UniswapV4FullSpreadStandardExchangeVaultProxySurface.t.sol` | Proxy surface matrix, selector/interface/facet/Repo manifest, factory-owned facets |
| `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` | Paired deposit/redemption, compound, donate, fee attribution, custody reconciliation |
| `UniswapV4FullSpreadStandardExchangeVaultEntry.t.sol` | Zap-in math, size and tick-movement bounds, non-dilution invariant |
| `UniswapV4FullSpreadStandardExchangeVaultExit.t.sol` | Paired and single-token exits, full leg consumption, terminal exit and rebootstrap |
| `UniswapV4FullSpreadStandardExchangeVaultStandardExchange.t.sol` | The four SE routes, unsupported routes, `IStandardExchangeOut` reverts |
| `UniswapV4FullSpreadStandardExchangeVaultStandardizedYield.t.sol` | All 16 SY methods, native/wrapped equivalence |
| `UniswapV4FullSpreadStandardExchangeVaultRate.t.sol` | `getRate()` vs `exchangeRate()` separation, fail-closed, units, non-manipulation wording |
| `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol` | Native custody, refunds, settlement, wrapped-native mapping |
| `UniswapV4FullSpreadStandardExchangeVaultSecurity.t.sol` | Callback authentication, reentrancy, trust-flag negatives, callback rollback |
| `UniswapV4FullSpreadStandardExchangeVaultHookIntegration.t.sol` | **Cross-vault integration through the existing V4 buffer hooks** (FS-TEST-03) |
| `UniswapV4FullSpreadStandardExchangeVaultAccountingInvariant.t.sol` | Supply conservation and per-leg non-dilution invariants |
| `UniswapV4FullSpreadStandardExchangeVaultWorkBudget.t.sol` | The three S1-QUOTE-01 budgets and the gas envelope |

Harness under `…/fullSpread/harness/`: `PoolActor.sol`, `HookBufferActor.sol` (a minimal contract that opens a manager unlock and calls the family's `exchangeIn` inside it, standing in for a hook callback), `Handler_UniswapV4FullSpreadStandardExchangeVault.sol`.

### FS-TEST-03 — Cross-vault hook integration: the hook families and how the share plugs in (new)

**Current hook families under `contracts/hooks/uniswap/v4/standardExchange/`** (all seven verified in source):

| Family | Directory | Package type | Holds a reserve? |
|---|---|---|---|
| Single SE Buffer Hook (pricing / wrap-unwrap) | `single/` | `UniswapV4SingleStandardExchangeBufferHookDFPkg` | No (D60 exemption) |
| Single SE Buffer Constant Product Hook | `constantProduct/single/` | `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg` | Yes |
| Dual SE Buffer Constant Product Hook | `dual/` | `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg` | Yes |
| SE Orbital Buffer Hook | `orbital/` | `UniswapV4StandardExchangeOrbitalBufferHookDFPkg` | Yes |
| SE Weighted Buffer Hook | `weighted/` | `UniswapV4StandardExchangeWeightedBufferHookDFPkg` | Yes |
| SE Balancer Quad Stable Buffer Hook | `stable/quad/balancer/` | `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg` | Yes |
| SE Curve Quad Stable Buffer Hook | `stable/quad/curve/` | `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg` | Yes |

**How the share plugs in (source-verified).** A hook leg is a `(pairToken, se)` binding: `UniswapV4SeBufferHookLegLib.addPairSe(pair, se)` records `standardExchangeOf[pair] = se` and `pairOfStandardExchange[se] = pair`, with the constraint `pair != se` unless the SE is a wrapper share (`PairSeOverlap`). The multi-leg hooks carry parallel arrays `tokens[]` and `standardExchanges[]` (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol`, `Layout`), and `UniswapV4SeBufferHookLegLib.classify` distinguishes `LegKind.Detf / Pair / StandardExchange`. The buffer flow is: the hook approves the leg's pair token to the SE and calls `IStandardExchangeIn(se).exchangeIn(IERC20(pairToken), amount, IERC20(se), min, address(this), false, block.timestamp)` (`.../stable/quad/curve/...ClaimLib.sol`, `buffer(...)`), receiving SE shares; on outflow it calls `IStandardExchangeIn(se).exchangeIn(IERC20(se), seAmount, IERC20(pairToken), min, to, false, block.timestamp)` (`unwrap(...)`).

**Consequences for fullSpread.**

1. Because the SE's share token **is** the vault address, the fullSpread vault satisfies the hook's SE-leg binding with **no hook-package change**: the hook binds `standardExchange = <fullSpread vault>` and the hook holds the vault's own ERC-20 shares as leg inventory. **FS-HOOK-01.**
2. Because a fullSpread leg is a **buffered leg** (`pairToken != se`), the hook's package init reverts `RateProviderRequired()` unless a provider is bound (`.../constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol`). A provider must therefore be bound for the fullSpread leg. **FS-HOOK-02.**
3. The hook's exact-in buffer/unwrap routes use `exchangeIn`, which is exactly the route that fullSpread must support in the already-unlocked inline mode (FS-CB-04). **FS-HOOK-03.**
4. The hook's **exact-out** unwrap route calls `IStandardExchangeOut.exchangeOut(...)` (`.../stable/quad/curve/...ClaimLib.sol`, `unwrapExactTokenOut`; same in the balancer, weighted, and orbital families). fullSpread's `exchangeOut` reverts `ExchangeOutNotAvailable()` (S1-P03), so **the hook's exact-out unwrap path is not available for a fullSpread leg**. This is a citable incompatibility, not a guess: the call site is `IStandardExchangeOut(se).exchangeOut(IERC20(se), seIn, IERC20(pairToken), amountOut, address(this), false, block.timestamp)`. **FS-HOOK-06.**
5. D60 forbids the hook from deriving a rate from the SE's own quotes; the provider is a separate contract. The production provider prices the whole book and can return `0` for a fullSpread leg (FS-RATE-05). **FS-HOOK-05.**

### FS-TEST-04 — Required hook-integration scenarios (new)

| # | Scenario | Assertions |
|---|---|---|
| H1 | **Two vaults' shares in one hook.** Deploy a fullSpread vault and a second, different SE vault (a second registered fullSpread instance over a different `PoolKey`, and — to prove the mechanism is not fullSpread-specific — one non-fullSpread SE where available). Bind them to two legs of one real buffer hook (the `weighted` or `stable/quad/curve` family, which supports per-leg `standardExchanges[]`). | The hook's inventory holds **both** share tokens; a swap touching both legs settles both; each leg's share balance moves by exactly the executed amount; the hook's LP supply and reserves reconcile |
| H2 | **Hook deposit while the PoolManager is already unlocked.** Drive the hook's join/deposit path so that the hook calls `fullSpread.exchangeIn(...)` inside the manager's unlock. | The family takes the **inline** path: no second `unlock` is issued by the family; the family's position liquidity changes by the planned `dL`; the family's share supply increases by the S1-ACC-07 credit; the family's **own** per-currency delta is zero when the family returns; the outer unlock completes with `getNonzeroDeltaCount == 0` |
| H3 | **Hook withdrawal while the PoolManager is already unlocked.** Drive the hook's outflow path. | The family's position liquidity decreases by `floor(L * s / S)`; the sold unwanted allocation is fully consumed; the hook receives exactly the requested currency; the family's own delta is zero on return |
| H4 | **No nested unlock.** Assert on the family's behavior: | The family never calls `poolManager.unlock(...)` while the manager is unlocked; the manager never reverts `AlreadyUnlocked`; the family's own `unlockCallback` is **not** invoked during an inline operation (the family's callback hash stays zero) |
| H5 | **Position ownership remains this diamond.** After H2/H3 and after any ordinary operation | The managed position key is `(vault, tickLower, tickUpper, bytes32(0))`; `positionLiquidity()` equals the manager's `Position.load(vault, tickLower, tickUpper, bytes32(0)).liquidity`; no other address appears as the owner |
| H6 | **Deltas close before return.** | After every inline operation, `TransientStateLibrary.currencyDelta(manager, vault, currency0) == 0` and the same for currency1; `getNonzeroDeltaCount(manager) == 0` at the end of the outer unlock; no unsettled residue is attributed to the hook |
| H7 | **Ordinary user entry keeps its own unlock callback.** Call the family's `exchangeIn` from an EOA with the manager **not** unlocked. | The family opens its own unlock; the family's `unlockCallback` authenticates and settles; the same economic outputs as the inline path from the same state |
| H8 | **The unlocked flag is not authorization.** From inside an unlocked context, attempt: (a) `exchangeIn` with an expired deadline; (b) `exchangeIn` to `address(0)`; (c) a redemption of shares the caller does not hold; (d) `exchangeIn` with `pretransferred = true` from a code-less caller; (e) `exchangeIn` on an unsupported route; (f) `exchangeIn` against a disabled registry entry. | Each reverts with its own canonical error (`DeadlineExceeded`, `ERC20InvalidReceiver`, `TransferDeltaInsufficient`, `EOAPretransferNotAllowed`, `InvalidRoute`, `IssuanceDisabled`) and leaves **no** state change |
| H9 | **Ordinary routes refuse the inline mode.** Inside an unlocked context, call `depositPair`, `redeemPair`, `compound`, `donate`. | Each reverts `ManagerAlreadyUnlocked()` before any manager mutation |
| H10 | **The hook's exact-out unwrap path is unavailable for a fullSpread leg.** | The hook's exact-out unwrap route reverts, and the revert is attributable to the family's `ExchangeOutNotAvailable()`; the exact-in route is unaffected |
| H11 | **A fullSpread leg without a provider is rejected at hook package init.** | The hook package init reverts `RateProviderRequired()` |
| H12 | **A fullSpread leg with a provider that fails closed is rejected at the hook.** | When the provider returns `0` or reverts, the hook reverts `RateProviderFailed()`; it never falls back to a raw-balance valuation for a buffered leg |

### FS-A — Acceptance matrix (new IDs `FS-A01…`)

Each row is an independent obligation. Rows that restate an inherited PairToken row are marked with the inherited ID so the coordinator can decide whether to renumber.

**Package, identity, proxy surface**

| ID | Acceptance evidence |
|---|---|
| FS-A01 | The registered real package deploys a usable diamond; the registry finds it by both declared ERC-20 currency faces and by type, including wrapped-face discovery for a native pool. (inherits S1-A01) |
| FS-A02 | Identical deployment identity predicts the same address; each relevant immutable argument (`poolKey`, `rateAsset`, `name`, `symbol`, `maxZapBps`, `maxZapTickMove`) changes identity as intended. (inherits S1-A02) |
| FS-A03 | Invalid pool keys, uninitialized or hooked pools, invalid rate asset, invalid zap bounds, invalid wrapped-native binding, and duplicate ERC-20 currency faces reject with the named error; valid native/ERC-20 pools deploy. (inherits S1-A03) |
| FS-A04 | Re-initialization, direct package misuse, wrong-registry processing, and invalid facet components reject. (inherits S1-A04) |
| FS-A05 | Metadata, 18-decimal shares, permit, and EIP-712 domain are correct on the live proxy; domains isolate instances. (inherits S1-A05) |
| FS-A06 | Target/interface-derived controls equal the package-owned facet declarations and cuts; every package selector is callable on the live proxy. The final persistent loupe surface equals the **disjoint union** of the 49 package-owned selectors and the factory-owned selectors, not the package cut alone. (extends S1-A06) |
| FS-A07 | Basic and standard vault discovery are initialized, ordered, truthful, and distinguish booked local reserves from deployed principal. (inherits S1-A07) |
| FS-A08 | The 5 shared facets contribute exactly their **20** distinct package-owned selectors and canonical interface declarations; no combined permit facet, no duplicate token/SY selector, and **no factory-provided facet** appears in package inputs, addresses, or cuts. (inherits S1-A56) |
| FS-A09 | Factory-installed ERC-165, loupe, and ERC-8109 remain callable without package cuts; the temporary deployment hook follows the factory lifecycle; shared Repo initialization is correct on each proxy. (inherits S1-A57) |
| FS-A10 | The family facet set is exactly the 12 inherited + `RateFacet`; `RateFacet` declares `IRateProvider` and installs exactly `getRate()`; no other facet redeclares a shared selector. (extends S1-A56) |
| FS-A11 | `linkedComponents()` of every family facet (indices 5–12) hashes equal to the package's `linkedLibraries`; a mismatched facet is rejected with `InvalidComponent()`. (extends S1-A56) |
| FS-A12 | Native pair discovery succeeds when the wrapped-native face sorts after the other currency: the registry hash uses the sorted copy while token/reserve views retain PoolKey face order. (inherits S1-A58) |
| FS-A13 | Two instances sharing facets cannot affect each other's state, balances, approvals, position keys, or initialization. (inherits S1-A47) |
| FS-A14 | The final proxy has no operational ownership, `diamondCut`, rescue, `IERC4626`, or excluded integration selectors. (inherits S1-A68) |

**Money, accounting, fees**

| ID | Acceptance evidence |
|---|---|
| FS-A15 | Fresh paired genesis mints the complete geometric-mean output to the recipient, with zero dead/virtual shares. (inherits S1-A08) |
| FS-A16 | Zero genesis inputs, zero mint, zero fundable liquidity, checked product overflow, and an unmet actual-share minimum reject atomically. (inherits S1-A09) |
| FS-A17 | Paired candidate issuance uses the limiting reserve ratio and ceiling accepted amounts; actual shares apply the S1-ACC-07 credit cap; unused maxima remain with the caller or are refunded in native form. (inherits S1-A10) |
| FS-A18 | One-sided reserve branches consume only the supported leg; positive supply with both reserves zero rejects. (inherits S1-A11) |
| FS-A19 | Deposits compound incumbent fees before the snapshot; caller input is excluded from that compound. (inherits S1-A12) |
| FS-A20 | Both zap directions use the half-swap, post-swap incumbent checkpoint, caller-only addition, actual removable-principal growth, and the final S1-ACC-07 issuance equation. (inherits S1-A13) |
| FS-A21 | Empty supply/basket zap, zero input, the size-cap boundary, and the tick-movement boundary behave exactly as specified. (inherits S1-A14) |
| FS-A22 | For every admitted positive-supply entry and each positive reserve, `q * R_i <= S * C_i` holds under independent wide-integer arithmetic at the same `P*`; incumbent inventory and fees cannot enter `C_i`. (inherits S1-A15) |
| FS-A23 | Paired redemption removes the proportional position and idle allocations without 10-basis-point retention. (inherits S1-A16) |
| FS-A24 | Partial redemption dust remains with holders; no second fee allocation and no donated share supply appears. (inherits S1-A17) |
| FS-A25 | Both single-token exit directions sell only the withdrawing allocation and enforce actual output minima. (inherits S1-A18) |
| FS-A26 | **A single-token exit never leaves a second token with the caller and never burns shares against a stranded residual**: a partial sale reverts the whole transaction; the unwanted allocation is fully consumed or the call reverts. (inherits S1-A19, S1-X12) |
| FS-A27 | Last-share paired exit empties the owned position and booked basket; a later paired genesis works without capturing unbooked balances. (inherits S1-A20) |
| FS-A28 | Last-share single-token exit with external liquidity succeeds; insufficient remaining liquidity reverts without burning shares. (inherits S1-A21) |
| FS-A29 | Compound retains all LP fees, performs no external fee-manager call, and never changes share supply. (inherits S1-A22) |
| FS-A30 | Dust equality, leftover tie direction, zero active liquidity, quarter-cap, and no-swap compound branches are covered. (inherits S1-A23) |
| FS-A31 | Final checkpoints include compound-swap fees in both the positive-add and zero-add branches; entry-swap fees stay incumbent-owned; exit-sale fees stay with the remaining liquidity; a whole-position fee receipt never becomes a partial exiter's principal. (inherits S1-A24) |
| FS-A32 | The four supported exact-input routes execute; unsupported directions and tokens reject with `InvalidRoute`. (inherits S1-A25) |
| FS-A33 | Both exact-output selectors are installed and explicitly reject with `ExchangeOutNotAvailable()` without transfer, burn, mint, or manager mutation. (inherits S1-A26) |
| FS-A34 | Every SE and paired preview matches execution exactly from identical state, including fees, compounding, crossed ticks, and terminal exits. (inherits S1-A27) |
| FS-A35 | The exact step 64/65, crossing 12/13, and distinct-word 16/17 limits, shared across every swap in a candidate, select identical preview/execution failures or fallback; at most two fresh withdrawal candidates; rejected state never leaks; no partial valid quote is returned. (inherits S1-A28) |
| FS-A36 | All 16 SY methods are installed; execution and previews agree with SE; no second receipt token exists. (inherits S1-A29) |
| FS-A37 | SY internal-balance redemption validates caller class and vault-held shares. (inherits S1-A30) |
| FS-A38 | Empty SY reward arrays and events are truthful; LP fees cannot be claimed twice as external rewards. (inherits S1-A31) |
| FS-A39 | SY helpers convert raw shares to raw assets using `floor(Vraw * 1e18 / S)` for 6/8/18-decimal assets, with independent exact-rational currency valuation. (inherits S1-A32) |
| FS-A40 | Zero-supply SY rate is zero; no synthetic 1:1 bootstrap target value is used for issuance. (inherits S1-A33) |
| FS-A41 | False-flag input pulls enforce exact receipt; existing reserves and unrelated transfers never fill a short delivery. (inherits S1-A34) |
| FS-A42 | True-flag input from a code-less or construction-time caller rejects with `EOAPretransferNotAllowed()`. (inherits S1-A35) |
| FS-A43 | Contract true-flag input without unbooked funds cannot mint or spend booked backing; short credit rejects with `TransferDeltaInsufficient`. (inherits S1-A36) |
| FS-A44 | Excess pretransfer processes exactly the declared input, refunds nothing, and leaves the excess unbooked. (inherits S1-A37) |
| FS-A45 | Explicit donation adds backing with no shares; unsolicited balances remain separate through compound, entry, exit, and restart. (inherits S1-A38) |
| FS-A46 | Actual manager liquidity, token custody, booked balances, share supply, and emitted amounts reconcile after every operation. (inherits S1-A41) |
| FS-A47 | A disabled vault rejects issuance and donation, allows public compound, and permits paired and executable single-token/SY exits with the same fallback rules. (inherits S1-A42) |
| FS-A48 | Transfer/payout failure and unmet minima roll back earlier swaps, removals, burns, and transfers. (inherits S1-A43) |
| FS-A49 | Mixed 6/8/18-decimal currencies work. (inherits S1-A44) |
| FS-A50 | Interior, both exact boundaries, and outside-range principal/cost amounts agree with manager receipts; capacity and signed limits select the fallback only for listed withdrawal-maintenance failures. (inherits S1-A45) |
| FS-A51 | Sequence tests assert exact supply conservation, no unbooked adoption, donation without mint, S1-ACC-07 per-leg issuance non-dilution, and each exiter's exact proportional allocation before sale. (inherits S1-A46) |
| FS-A52 | Normal deployed code-size limits pass; no `via_ir`; no lowered fuzz/invariant depth; fresh artifact deployment uses the edited code. (inherits S1-A48) |

**Native**

| ID | Acceptance evidence |
|---|---|
| FS-A53 | Native paired genesis and deposits accept exactly the native maximum, exclude it from the pre-entry compound, and refund only the unused portion; a wrong value and a refund failure roll back. (inherits S1-A49) |
| FS-A54 | Native SY entry/exit and wrapped-native SE/SY routes have equal economic outputs from equal states; only the requested delivery form differs. (inherits S1-A50) |
| FS-A55 | Native manager settlement, wrapper callbacks, ETH receipt, and actual payable proxy selectors work through real registered diamonds; no ERC-20 call targets address zero. (inherits S1-A51) |
| FS-A56 | Unsolicited/forced ETH, pending value, refunds, and temporary wrapped balances never become duplicate backing or free deposit credit. (inherits S1-A52) |
| FS-A57 | Rejecting and reentrant native payout/refund receivers roll back the whole operation. (inherits S1-A53) |
| FS-A58 | Native last-share paired exit empties booked ETH/token reserves and owned liquidity; native rebootstrap excludes old unbooked ETH. (inherits S1-A54) |
| FS-A59 | Native and wrapped donation forms credit the same reserve once; wrong `msg.value`, native calls on ERC-20-only pools, and zero-address standard SE routes reject. (inherits S1-A55) |

**Callback, guard, quote boundary**

| ID | Acceptance evidence |
|---|---|
| FS-A60 | Authentic callback succeeds; wrong manager, unsolicited payload, replay, reentrancy, and cross-facet attacks reject. (inherits S1-A39) |
| FS-A61 | Already-unlocked PoolManager context rejects before any attempted nested unlock on every route **except** the exact-input SE route (which takes the inline mode); no stale local-sleeve fallback is used. (extends S1-A40) |
| FS-A62 | Callback reads enforce the selector policy: new economic reads reject, unchanged basic reserves return the last committed snapshot, and canonical token/domain reads retain behavior. (inherits S1-A59) |
| FS-A63 | Native debt after an outstanding ERC-20 sync explicitly resets sync before settlement; actual manager deltas close to zero; empty-calldata receipts bypass family facets. (inherits S1-A60) |
| FS-A64 | Every maintenance fallback reason has a real-manager reachable case or an independently demonstrated unreachable-domain proof; mode/reason in preview, event, and execution agree; a valid full candidate always wins. (inherits S1-A61) |
| FS-A65 | The fallback never catches actual manager, token, wrapper, custody, fee-collection, state-change, or payout errors; a failed collection-only plan reverts atomically. (inherits S1-A62) |
| FS-A66 | Caller minima or an unavailable final exit sale alone do not select the fallback; paired mode and single-token ETH mode are unambiguous in the mode-query ABI. (inherits S1-A63) |
| FS-A67 | Entry credit controls distinguish `G_i`, paired `J_i`, zap uncredited `J_i`, and incumbent fees; final minimum checks use `q`, not `qQuote`. (inherits S1-A64) |
| FS-A68 | At every stable boundary all local custody categories reconcile and reservations are zero; terminal generated receipts are paid to the last holder. (inherits S1-A65) |
| FS-A69 | Clean empty compound is a no-op; zero-total-output burns reject; one-sided positive paired outputs succeed. (inherits S1-A66) |
| FS-A70 | Nonzero protocol fees, initialized crossings, empty-word progress, and position checkpoint changes are modeled across compound plus entry/exit; token/wrapper-induced plan changes cause `EconomicStateChanged`. (inherits S1-A67) |
| FS-A71 | Zero fee-type IDs work through the real registry; `DUST` remains 1,000 raw units; zap parameters have no silent defaults; metadata uses validated cached decimals. (inherits S1-A69) |
| FS-A72 | Supported worst-case candidate combinations, native/wrapped paths, and collection-only paired exits satisfy the 12M transaction engineering ceiling (11.9M measured call body plus 100k overhead) and the 5M local preview ceiling; former 512-step dense states reject single conversion early and still permit valid paired fallback. (inherits S1-A70) |

**Rate / quote / issuance separation**

| ID | Acceptance evidence |
|---|---|
| FS-A73 | `getRate()` and `exchangeRate()` are distinct selectors with distinct outputs from the same state, and the difference is explained by the executable exit versus the spot accounting value. `getRate()` is **not** `exchangeRate()` rescaled and **not** book value per share. (new) |
| FS-A74 | `getRate()` equals the family's real exit plan for one whole share, recomputed independently in the test from the same planner inputs; the test does not reuse the production helper to compute the expected value. (new) |
| FS-A75 | `getRate()` returns `0` when the one-share exit is not plannable within the S1-QUOTE-01 budgets; it never returns a partial, a NAV substitute, or a spot value. (new) |
| FS-A76 | `getRate()` is never read by the issuance path: mutating nothing, a change in `getRate()`'s inputs does not change minted shares. Assert `shares == expected` under two different `getRate()` values. (new) |
| FS-A77 | `getRate()` is denominated in raw `rateAsset` units per one whole share and the documented scaling constant matches the implementation for 6-, 8-, and 18-decimal rate assets. (new) |
| FS-A78 | `getRate()` at zero supply returns `0`; the family does not publish a synthetic bootstrap price. (new) |
| FS-A79 | The family interface NatSpec distinguishes the issuance quantity, the SY accounting value, and the executable one-share rate, and states that the rate is live, price-sensitive, and not manipulation-resistant. (new; prose is not pinned by a test) |

**Already-unlocked inline mode**

| ID | Acceptance evidence |
|---|---|
| FS-A80 | From an EOA with the manager **not** unlocked, `exchangeIn` opens the family's own unlock and the family's `unlockCallback` authenticates and settles; the economic output equals the inline output from the same state. (new) |
| FS-A81 | From inside an unlocked context, `exchangeIn` takes the inline path: the family issues **no** `poolManager.unlock(...)`, the manager's `AlreadyUnlocked` revert is never observed, and the family's `unlockCallback` is not invoked. (new) |
| FS-A82 | The inline path produces **the same** economic result as the ordinary path from the same state: same shares, same fees, same liquidity delta, same rounding. (new) |
| FS-A83 | The inline path enforces every caller-authority check: deadline, recipient, holder share authority, minimum, route validity, `pretransferred` handling, and registry disable for inbound. Each violation reverts with its canonical error and leaves no state change. (new) |
| FS-A84 | In the inline path the family closes **its own** per-currency deltas (`currencyDelta(manager, vault, currency) == 0` for both currencies) before returning, while the outer actor's deltas may still be open at that moment; the outer unlock's final global `getNonzeroDeltaCount == 0` check passes. (new) |
| FS-A85 | The inline path never uses another actor's `sync`: before every ERC-20 settlement it calls `sync(currency)` and after every native settlement it calls `sync(Currency.wrap(address(0)))`; it never calls `settleFor` for another address. (new) |
| FS-A86 | The family's managed position key is `(vault, tickLower, tickUpper, bytes32(0))` before and after inline operations, and `positionLiquidity()` equals the manager's recorded liquidity for that key. (new) |
| FS-A87 | `depositPair`, `redeemPair`, `compound`, `donate`, and the SY money methods revert `ManagerAlreadyUnlocked()` inside an unlocked context, before any manager mutation. (new) |
| FS-A88 | An inline operation that observes a changed backing-pool state between plan and action reverts `EconomicStateChanged()` rather than executing a stale plan. (new) |
| FS-A89 | An inline operation runs the **same** maintenance engine: the selected mode and reason in `previewWithdrawalMode`, in `WithdrawalMaintenanceSelected`, and in execution agree, and the fallback is never silently widened. (new) |

**Cross-vault hook integration**

| ID | Acceptance evidence |
|---|---|
| FS-A90 | **H1** — One real buffer hook holds this vault's shares and another SE vault's shares simultaneously; a single swap touching both legs settles both; each leg's share balance moves by exactly the executed amount and the hook's LP supply and reserves reconcile. |
| FS-A91 | **H2** — A hook deposit executed while the PoolManager is already unlocked succeeds: the family takes the inline path, no nested unlock occurs, the family's liquidity and supply change by the planned amounts, and the outer unlock completes with zero global nonzero deltas. |
| FS-A92 | **H3** — A hook withdrawal executed while the PoolManager is already unlocked succeeds: the family's liquidity decreases proportionally, the unwanted allocation is fully consumed, and the hook receives exactly the requested currency. |
| FS-A93 | **H4** — The family never issues a nested `unlock`; the manager never reverts `AlreadyUnlocked`; the family's own callback hash stays zero during an inline operation. |
| FS-A94 | **H5** — Position ownership remains this diamond throughout hook-driven and user-driven operations; no other address appears as the position owner. |
| FS-A95 | **H6** — The family's deltas close before it returns; the outer unlock's global check passes; no unsettled residue is attributed to the hook. |
| FS-A96 | **H7** — Ordinary user entry keeps its own unlock callback and produces the same economics as the inline path from the same state. |
| FS-A97 | **H8** — Inside an unlocked context, each of the six authority-violation cases (expired deadline, zero recipient, unheld shares, EOA pretransfer, unsupported route, disabled vault) reverts with its canonical error and leaves no state change. |
| FS-A98 | **H9** — Inside an unlocked context, `depositPair`, `redeemPair`, `compound`, and `donate` revert `ManagerAlreadyUnlocked()`. |
| FS-A99 | **H10** — The hook's exact-out unwrap route against a fullSpread leg reverts, and the revert is attributable to the family's `ExchangeOutNotAvailable()`; the exact-in route is unaffected. |
| FS-A100 | **H11** — A hook package init that binds a fullSpread leg without a rate provider reverts `RateProviderRequired()`. |
| FS-A101 | **H12** — A bound provider that returns `0` or reverts causes the hook to revert `RateProviderFailed()`; the hook never falls back to a raw-balance valuation for a buffered leg. |
| FS-A102 | The hook never derives the fullSpread leg's rate from the vault's own quotes; the provider is a separate contract and the hook's valuation reads the provider only (D60). |

### FS-TEST-05 — Comparison ledger (inherits S1-TEST-01)

The implementation must produce a comparison ledger against the PairToken stage-one exemplar with the four categories **preserved**, **intentional deviation**, **unsupported scope**, and **new capability (no baseline counterpart)**. The three intentional deviations are exactly those in FS-BND-04: the already-unlocked inline mode, the executable one-share `getRate()`, and the hook-leg rate-provider consequence. The baseline PairToken characterization fixture (`test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol`) is reused for comparisons and is not modified. The PairToken stage-one suite is not weakened and expected values are not patched to disguise divergence.

---

## 8. Inherited IDs, new `FS-` IDs, and owner decisions still open

### 8.1 Inherited PairToken stage-one IDs (unchanged, by reference)

The following PairToken stage-one IDs are inherited **verbatim** by fullSpread. This is the complete inheritance list; nothing else is inherited implicitly.

| Group | IDs |
|---|---|
| Owner decisions | S1-D02, S1-D03, S1-D04, S1-D05, S1-P01, S1-P02, S1-P03, S1-P04, S1-P05, S1-P06, S1-P07 |
| Deviations from baseline | S1-X01, S1-X02, S1-X03, S1-X04, S1-X05, S1-X06, S1-X07, S1-X08, S1-X09, S1-X10, S1-X11, S1-X12, S1-X13, S1-X14, S1-X15, S1-X16, S1-X17, S1-X18, S1-X19 |
| Architecture | S1-ARCH-01 (placement/naming), S1-ARCH-02 (share and position identity), S1-ARCH-03 (configuration and validation), S1-ARCH-04 (the five shared facets; factory-owned exclusion), S1-ARCH-05 (shared Repo initialization) |
| Accounting | S1-ACC-01 (state and basket), S1-ACC-02 (paired issuance), S1-ACC-03 (proportional withdrawal), S1-ACC-04 (donations and pending inputs), S1-ACC-05 (terminal withdrawal and restart), S1-ACC-06 (operation ledger and fee ownership), S1-ACC-07 (attributable entry credit and non-dilution) |
| Operations | S1-OP-01 (paired deposit), S1-OP-02 (single-token deposit), S1-OP-03 (paired redemption), S1-OP-04 (single-token redemption), S1-OP-05 (compound) |
| Withdrawal fallback | S1-EXIT-01 (conditional maintenance fallback and its four reasons) |
| Native | S1-NATIVE-01 (native custody and interface adaptation) |
| API | S1-API-01 (required surfaces), S1-API-02 (route table), S1-API-03 (native SY mapping), S1-API-05 (family ABI and execution signals) — **S1-API-04 is NOT inherited in full**: its "no `IRateProvider`" sentence is superseded by FS-RATE-04/FS-FACET-03; its "no transition-quote interfaces" sentence stands |
| Quotes and gas | S1-QUOTE-01 (execution-equivalent previews and the three budgets), S1-QUOTE-02 (SY asset identity and accounting rate), S1-GAS-01 (shared supported execution envelope) |
| Package / security / observability | S1-PKG-01 (package lifecycle), S1-SEC-01 (shared operation guard and settlement), S1-SEC-02 (registry disable and token boundaries), S1-OBS-01 (events and errors) |
| Testing | S1-TEST-01 (fixture and comparison discipline) |
| Acceptance | S1-A01 … S1-A70, as mapped into FS-A01 … FS-A72 in §7 |
| **Not inherited** | S1-D01 (that PRD's own delivery framing), S1-D02's "not upper/lower wings" is inherited as a *strategy* statement only — fullSpread is its own family, not Wings |

### 8.2 New `FS-` IDs created by this contribution

| ID | Subject |
|---|---|
| FS-BND-01…05 | Family boundary, identity, non-goals, deltas vs PairToken and vs Wings |
| FS-FACET-01…05 | Facet inventory: shared 5, family 7, new `RateFacet`, factory-owned exclusions, selector accounting |
| FS-ARCH-01, FS-ARCH-02, FS-ARCH-02a | File layout; linked components |
| FS-PKG-01…07 (+ 02a, 05a) | `PkgInit`, `PkgArgs`, `bindingHash`/salt, `deployVault`/registry, package errors, `initAccount`, `processArgs` validation |
| FS-MONEY-01…03 | Money surface, one-token whole-leg consumption, native ETH |
| FS-CB-01…07 (+ 01a…01c, 02a, 03a…03c, 04a) | Callback model, inline mode, mechanics, delta closure, route scope, stale plans, maintenance, guard invariants |
| FS-RATE-01…06 (+ 04a…04d, 05a…05c) | Issuance vs SY accounting vs executable one-share rate; the provider rationale |
| FS-HOOK-01…06 | Hook families, SE binding, provider requirement, inline route, provider gap, exact-out incompatibility |
| FS-TEST-01…05 | Fixture, spec files, hook scenarios, acceptance matrix, comparison ledger |
| FS-A01…FS-A102 | Acceptance rows |
| FS-OPEN-01…04 | Owner decisions still open |

### 8.3 Owner decisions still open (recommended defaults stated so implementation is not blocked)

| ID | Question | Recommendation | Blocking? |
|---|---|---|---|
| FS-OPEN-01 | Should the already-unlocked inline mode be available to **any** caller that passes the normal authority checks (as specified in FS-CB-01/FS-CB-04), or restricted to a set of pre-declared integrators? | **Any caller with normal authority.** An address allowlist in `PkgArgs` is circular with the hook binding (the hook's args contain the vault address), and the inline path grants no privilege the ordinary path does not. If the owner prefers a closed set, it must be a *separate* authorization mechanism outside `PkgArgs` — that would be a new requirement, not a tweak. | No — the specified default is implementable |
| FS-OPEN-02 | Should `RateFacet` exist at all, given D60 forbids the *hook* from reading the SE's own quotes? | **Yes.** The hook still reads a *provider*; the family exposes `getRate()` so that a provider can exist that prices the family per share and fails closed. The family is not the hook's valuation source. | No |
| FS-OPEN-03 | How is `getRate()` normalized when the total supply is below one whole share (1e18)? | **Normalize by the actual total supply** (`rate = rawExitValue * 1e18 / totalSupply`), documented as "raw `rateAsset` units per 1e18 raw share units", consistent with the SY rate's `floor(Vraw * 1e18 / S)` shape (S1-QUOTE-02). This keeps one scaling rule across both rates. | No |
| FS-OPEN-04 | Should the family implement the optional `IStandardExchangeTransitionQuote` / `IStandardExchangeExternalQuote` / `IStandardExchangeRateQuote` surfaces (used by `UniswapV4SeBufferHookLegLib`)? | **No, not in this family.** PairToken stage one explicitly excludes transition-quote interfaces (S1-API-04). `UniswapV4SeBufferHookLegLib` already degrades gracefully when an SE lacks them (it probes with `staticcall` and falls back to `IRateProvider.getRate()`). Adding them would enlarge the surface beyond the owner's request. | No |

### 8.4 Non-goals (new, restated for this family)

No Weir copy; no ERC-4626-only wrapper; no second pool; no wings range management, target-token sleeve, or rebalance; no registry migration of existing vaults; no deployment, migration, or replacement of any existing vault; no claim that this PRD was audited, reviewed by the council, or implemented; no performance fee, locked `MIN_SHARES`, or internal non-ERC-20 ledger; no shares-of-shares; no transition-quote interfaces; no new fee, fee manager, or protocol-fee routing; no `via_ir`; no Foundry profile; no edit to any hook package in this PRD.

---

## 9. Limits and sources

### 9.1 Limits of this contribution (stated, not hidden)

1. **Research only.** Nothing was implemented, built, deployed, or tested. No Forge, build, install, Git, or deploy command was run. No claim of compilation, gas measurement, or test execution is made.
2. **No selector or interface ID is asserted as final.** All `@custom:selector` / `@custom:interfaceid` values quoted from the exemplar are transcribed from the current source and must be re-derived through the canonical verification workflow (`cast sig` / `type(I).interfaceId`) for the fullSpread types. In particular, the DFPkg interface ID `0xc283faa9` and the family interface ID `0x8be92db3` belong to the **PairToken** types and must not be copied.
3. **No hex constants are invented.** The `getRate()` selector is not stated numerically here; it must be computed.
4. **Three places where the brief's summary was checked against source and the source differs.** (a) The brief says the current `PkgInit` shows "five shared facet inputs"; the current `PkgInit` actually declares **twelve** facets (five shared + seven family), and the DFPkg's constructor installs all twelve — fullSpread therefore starts from twelve, not five (FS-FACET-01/02). (b) The brief says "Do not claim a facet exists because this brief named it"; the `IRateProvider`-carrying `RateFacet` in FS-FACET-03 does **not** exist today and is a **new** family facet this PRD requires, not an existing one — it is marked as new and justified. (c) The brief describes the "already-unlocked entry" as an entry; the source shows the buffer hooks call the **canonical** `IStandardExchangeIn.exchangeIn` selector (`.../stable/quad/curve/...ClaimLib.sol`, `buffer(...)`/`unwrap(...)`), and D60 fixes the permitted SE call set to `previewExchangeIn` / `previewExchangeOut` / `exchangeIn` / `exchangeOut` (`docs/agent/INDEXEDEX_AGENT_LAW.md` §D60). This fragment therefore specifies the already-unlocked behavior as an **execution mode on the canonical `exchangeIn` route**, not as a new SE selector, which is what keeps the hooks usable without a hook-package edit.
5. **Whole-book pricing risk is stated, not resolved.** The production `StandardExchangeRateProvider` prices the entire supply through `previewExchangeIn(seShare, totalSupply, rateTarget)`; for a fullSpread leg whose position dominates its backing pool this is frequently unsellable and yields a zero rate and `RateProviderFailed`. FS-HOOK-05 / FS-RATE-05b mark the dedicated provider as a **separate requirement**, outside this PRD's implementation scope.
6. **The exact-out hook path is unavailable for a fullSpread leg**, cited to `.../stable/quad/curve/...ClaimLib.sol` `unwrapExactTokenOut` and its siblings. Whether the owner wants a hook-side change to support it is FS-OPEN territory and is not decided here.
7. **The `UniswapV4SeBufferHookLegLib` SE↔pair binding is one-to-one** (`pairOfStandardExchange[se] = pair`, with `SeAlreadyBound` on a second pair). A single fullSpread vault serving as the SE of two legs of the same hook is therefore not supported by the current leg library. This PRD does not change it.
8. **The hook families are named from the current tree**, and only the `weighted`, `stable/quad/curve`, `stable/quad/balancer`, `orbital`, `constantProduct/single`, `dual`, and `single` directories under `contracts/hooks/uniswap/v4/standardExchange/` exist. No hook outside that directory is in scope.
9. **Optional context was used only for the non- Weir and hook-integration framing**, not as economics authority, per the brief. No upstream (Weir, lpTOKEN, The Pool, ALPS, USDa, Unoxi, ZapVault) economic policy is adopted.
10. **No peer response, feedback, draft, or resolution was read**, and no peer file was written.
11. **No public search was performed.** Every claim in this fragment is anchored to a repository file read in this session. No external source, and no private source excerpt, was sent to any external service.
12. **This is not an audit.** No security review, gas measurement, or compile check was performed against any of the requirements above.

### 9.2 Sources read in this session (admitted scope)

Repository sources read in full or in the cited sections:

- `docs/research/fullspread-se-prd-20261030-01a18660/brief.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultTypes.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultRepo.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol` (unlock/callback dispatch and settlement sections)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVault{Money,Quote,Out,Query,SYMoney,SYQuery,Callback}Facet.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`
- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` (sections 1–12, in full)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol`, `.../UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`, `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol`, `.../libraries/CurrencyReserves.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` (sync/settle/take/`_accountDelta`)
- `lib/crane/contracts/interfaces/protocols/dexes/balancer/common/IRateProvider.sol`, `lib/crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol`
- `contracts/interfaces/IStandardVaultPkg.sol`, `contracts/interfaces/IVaultRegistryDeployment.sol`, `contracts/interfaces/IVaultRegistryDisableQuery.sol`
- `contracts/interfaces/IStandardExchangeTransitionQuote.sol`, `contracts/interfaces/IStandardExchangeUnlockContextQuote.sol`
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`, `.../StandardExchangeRateProviderRepo.sol`
- `contracts/test/libs/RateProviderFixtureLib.sol`
- `contracts/hooks/uniswap/v4/standardExchange/**` — the seven family directories, their package interfaces, `Repo` layouts, `ClaimLib` buffer/unwrap flows, `HooksTarget`/`SeTarget`/`ExitTarget` exact-out call sites, and `UniswapV4SeBufferHookLegLib`
- `CLAUDE.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md` (token policy, D60 held-reserve valuation, vault DFPkg requirements, project structure)
- `.agents/skills/crane-architecture/SKILL.md` (routing only), `.agents/skills/indexedex-testing/SKILL.md`, `.agents/skills/indexedex-uniswap-v4-hook-packages/SKILL.md`, `.agents/skills/indexedex-user-flows/SKILL.md`
- `lib/crane/AGENTS.md` (Crane conventions surfaced through `lib/crane/contracts/**` reads)

Optional context, read for framing only:

- `docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md`
- `docs/research/v4-vault-adaptation-20261029-01a18660/REPORT.md` (in particular §"Hook integration: two pools, one outer unlock" and §"Why adding ERC-20 is not enough")

Not read (per the brief's admission rules): `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md` (optional context; the Weir facts used here come from the two admitted research reports, which state them with citations); any peer `members/*/response.md` or `feedback.md`; `coordinator/draft.md`; `coordinator/resolution.md`; `RUN.md`.
