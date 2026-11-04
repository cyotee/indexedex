# Full-spread Standard Exchange vault — Grok original

This is a PRD fragment for the coordinator to merge. It is not the published PRD, not an implementation, and not an audit. `S1-*` IDs are inherited from `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` and are not redefined here. `FS-*` IDs are new. A cited `S1-*` row applies to this family unless an `FS-*` row names it as not inherited.

Observed PairToken selectors below are citations of the current interface, not values this contribution computed. Implementation must recompute selectors, topics, and interface IDs with the repository NatSpec script. Do not copy hex from this file into source as if it had been computed here.

## 1. Identity and route, labeled as the assigned route, not a runtime attestation

- Assigned route label: `xai/grok-4.7:xhigh`. That label is not a runtime attestation and is not evidence that this process ran on that route.
- Writer: grok, council member, initial pass only.
- Run: `fullspread-se-prd-20261030-01a18660`.
- Question answered: requirements for one registry-deployed Crane diamond, `UniswapV4FullSpreadStandardExchangeVault`, owning one hookless Uniswap V4 pool position, full-range, and one public ERC-20 share supply, with the current Standard Exchange facet set, a Diamond Package, and tests that include other SE vault shares in the existing custom Uniswap V4 buffer hooks.
- Owned path: `docs/research/fullspread-se-prd-20261030-01a18660/members/grok/response.md`.
- Publication path this contribution does not write: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. The publication directory exists and is empty. The coordinator creates that file after advisory resolution.
- This contribution does not authorize implementation, deployment, a hook-package edit, or an amendment of the PairToken stage-one PRD.

## 2. Family boundary and deltas from PairToken and Wings

### FS-BOUND-01 — What this family is

`UniswapV4FullSpreadStandardExchangeVault` is one IndexedEx registry-deployed Crane diamond. That diamond is the ERC-20 and the PoolManager position owner. It has one `PoolKey`, one full-range position, and one public 18-decimal ERC-20 share supply. Public shares are proportional claims on that one basket: owned full-range principal plus booked idle of the two pool currencies. Source: owner decisions 1 and 3; PairToken `S1-ARCH-02`; current `IUniswapV4PairTokenStandardExchangeVault` notice "Full-range position ownership through one public share supply."

Placement is a sibling directory, not a PairToken revision:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`

Type prefix: `UniswapV4FullSpreadStandardExchangeVault`. Do not rename PairToken. Do not edit PairToken source, its stage-one PRD, or its tests to make this family pass.

### FS-BOUND-02 — What this family is not

| Not this | Source | Requirement |
| --- | --- | --- |
| Weir singleton / many virtual vaults in one contract | Owner request; owner decision 7; Weir import PRD objective (source-import only, not an SE adaptation) | One diamond, one position, one share supply. No performance fee, no locked `MIN_SHARES`, no internal non-ERC-20 ledger, no "add ERC-20 and stop" plan. |
| Upper/Lower Wings | Owner decision 2; Wings `PkgInit` uses `IFacet[]` plus `IPermit2` | No second range, no rebalance, no harvest sleeve, no local-sleeve execution, no open facet array, no Permit2 package input. |
| ERC-4626 vault | `S1-API-04`; owner decision 7 | Do not implement `asset()`, `deposit(uint256,address)`, or any other `IERC4626` selector. `yieldToken()` is this diamond. |
| Second share ledger or shares-of-shares | Owner decision 1; `S1-D05` | One ERC-20 supply. `ERC20Repo` is that supply. |
| PairToken stage-one amendment | Owner decision 2 | Inherit by ID. Deltas are `FS-*` only. |
| Hook redesign | Brief hook rule | Existing buffer-hook packages stay unchanged. A hook gap is `FS-HOOK-04`, not an edit. |
| Independent price or manipulation proof | Owner decision 9; `S1-P06` | No Chainlink, no second pool, no peg. An underlying-pool TWAP may be named as the available reference. It is not an independent price and not a manipulation proof. This family does not construct a TWAP. |

### FS-X01 — Deliberate delta from PairToken's unlocked reject

PairToken stage one rejects an already-unlocked manager and then calls `unlock`. Observed in `UniswapV4PairTokenStandardExchangeVaultExecution.sol`: `_start` reverts `ManagerAlreadyUnlocked` when `TransientStateLibrary.isUnlocked` is true, and `_action` reverts the same error before `poolManager.unlock`. `S1-SEC-01`, `S1-OP-05`, and `S1-A40` require that reject and forbid a local-sleeve fallback.

This family does not inherit those three sentences. It still forbids a nested `unlock` and still forbids Wings' local sleeve. When the bound manager is already unlocked, money execution runs inline on that unlock and closes this diamond's deltas before return (`FS-UNLOCK-01`). Ordinary user entry, when the manager is locked, still opens its own unlock and still uses `unlockCallback`.

`ManagerAlreadyUnlocked` is not a required family error. The hook path must succeed, not revert that error. A regression that still calls `unlock` while the manager is unlocked fails `FS-AH02`.

### FS-X02 — Single-token consumption, without a second issuance equation

Owner decision 6 is binding. It does not replace `S1-ACC-07`.

- Single-token entry pulls only the selected leg, in the full declared amount, or the call reverts before mint. It does not pull or pay a second token. A short pull reverts. Tokens of the selected leg are either deployed into attributable principal or booked by the inherited zap rule. They are not left unbooked.
- The inherited zap settlement still applies on success: mint against `G_i` only, then book leftover caller inventory `J_i` as an explicit no-extra-shares contribution, emitted in `ZapCredit`. That booked `J_i` is not an unaccounted strand, not a second-token payout, and not a refund. Do not add a dust tolerance or a second issuance formula to force `J_i` to zero.
- Single-token exit inherits `S1-X12` and `S1-OP-04`. The unwanted allocation is sold completely or the call reverts atomically. A successful exit pays only the requested currency. It does not burn shares and donate the unsold allocation to remaining holders.

The stricter reading "revert whenever planned `J_i != 0`" is not adopted. It would replace the exemplar's specified zap success domain. Limits records that choice.

### FS-X03 — Inherited economics that stay

Where `FS-X01` and `FS-X02` do not speak, the basket equations stay the PairToken equations. Do not derive a new issuance, fee, or redemption formula from Weir, Wings, lpTOKEN, or the external rate provider.

Inherited without restatement beyond the operative rules in sections 5 and 6: `S1-D03`, `S1-D04`, `S1-D05`, `S1-P01` through `S1-P07`, `S1-X01` through `S1-X19` except the unlocked sentences named in `FS-X01`, `S1-ACC-01` through `S1-ACC-07`, `S1-OP-01` through `S1-OP-05` except that same unlocked sentence, `S1-EXIT-01`, `S1-NATIVE-01`, `S1-API-01` through `S1-API-05`, `S1-QUOTE-01`, `S1-QUOTE-02`, `S1-GAS-01`, `S1-PKG-01`, `S1-SEC-02`, `S1-OBS-01`.

Operative rules the implementer must not re-derive:

- Genesis: `S == 0` mints `floor(sqrt(a0 * a1))` to the recipient. No dead shares, no 1,000-share sink, no virtual assets.
- Positive supply, both reserves positive: candidate `qQuote = min(floor(a0*S/R0), floor(a1*S/R1))`, then `S1-ACC-07` caps the minted `q`.
- One-sided positive-supply entry consumes only the live leg.
- Positive supply with both reserves zero reverts `InvalidAccountingState`. Geometric-mean issuance is only the zero-supply branch.
- Withdrawal after the selected maintenance checkpoint: `liquidityRemoved = floor(L * s / S)`, idle allocated `floor(B_i * s / S)`. Burn `s` before removal. Reject a burn whose total actual payout is zero.
- Entry credit at frozen post-checkpoint price `P*`: `G_i = N_i(P*, L+dL) - N_i(P*, L)`. Paired `C_i = G_i + J_i`. Zap `C_i = G_i`. `qCredit = min floor(S * C_i / R_i)` over positive `R_i`. Paired `q = min(qQuote, qCredit)`. Zap `q = qCredit`. Predicate `q * R_i <= S * C_i` for each positive `R_i`.
- `DUST = 1000` raw units. `maxZapBps` caps zap size and the compound quarter-cap. `maxZapTickMove` bounds only the caller's entry swap. No silent defaults.
- Position identity: `(diamond, TickMath.minUsableTick(tickSpacing), TickMath.maxUsableTick(tickSpacing), bytes32(0))`.
- Vault fee-type IDs are zero. Pool trading fees still apply. No protocol-fee split and no fee-manager call.
- FoT and rebasing underlyings are forbidden by repository law. No `processArgs` allowlist. Non-18-decimal currencies are allowed. Pause and blacklist are accepted risk.

## 3. Standard and family facet inventory, each row sourced

### FS-FACET-01 — Package inputs, verified from the current PairToken package

Source read for this table: `IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol` `PkgInit`, and `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol` constructor `_appendComponent` indices 0–11 plus `_expectedSelectors`. Wings `IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol` was read only to reject its `IFacet[]` shape. Do not copy that shape.

The five shared inputs are present, in this order, as explicit `IFacet` fields. Do not drop one to shrink the package. Do not substitute `ERC20PermitFacet`; its selectors overlap the three token facets (`S1-ARCH-04`).

| Index | `PkgInit` field | Ownership | Source facet | Interfaces the cut must declare | Selectors the package expects |
| --- | --- | --- | --- | --- | --- |
| 0 | `erc20Facet` | Shared. Not family-owned. | `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | `IERC20`, `IERC20Metadata`, plus the extra interface ID that facet already declares | `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom` (9) |
| 1 | `erc2612Facet` | Shared | `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `IERC20Permit` | `permit`, `nonces`, `DOMAIN_SEPARATOR` (3) |
| 2 | `erc5267Facet` | Shared | `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `IERC5267` | `eip712Domain` (1) |
| 3 | `basicVaultFacet` | Shared | `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `IBasicVault` | `vaultTokens`, `reserveOfToken`, `reserves` (3) |
| 4 | `standardVaultFacet` | Shared | `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `IStandardVault` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` (4) |

Those 20 selectors are installed only by those cuts. Family facets must not redeclare them. SY inherits the token interfaces and does not reinstall their selectors.

Resolve the five through the existing CREATE3 / FactoryService path. Pass the deployed addresses into `PkgInit`. Do not hand-copy their implementations into this family.

### FS-FACET-02 — Family facets

Add a family facet only for selectors the shared facets do not provide. The current PairToken package already splits those selectors into seven family facets. This family uses that split. No eighth family facet. The already-unlocked path is an execution branch inside the existing money and callback targets, not a new selector (`FS-FACET-04`).

| Index | `PkgInit` field | File | Selectors, from the current PairToken `_expectedSelectors` |
| --- | --- | --- | --- |
| 5 | `moneyFacet` | `UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol` | `IStandardExchangeIn.exchangeIn`, `depositPair`, `redeemPair`, `donate`, `compound` |
| 6 | `quoteFacet` | `UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol` | `previewExchangeIn`, `previewDepositPair`, `previewRedeemPair`, `previewWithdrawalMode`, `previewZapCredit` |
| 7 | `outFacet` | `UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol` | `previewExchangeOut`, `exchangeOut` |
| 8 | `queryFacet` | `UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol` | `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, `maxZapTickMove` |
| 9 | `syMoneyFacet` | `UniswapV4FullSpreadStandardExchangeVaultSYMoneyFacet.sol` | `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards` |
| 10 | `syQueryFacet` | `UniswapV4FullSpreadStandardExchangeVaultSYQueryFacet.sol` | `previewDeposit`, `previewRedeem`, `getTokensIn`, `getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`, `isValidTokenIn`, `isValidTokenOut`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored` |
| 11 | `callbackFacet` | `UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol` | `IUnlockCallback.unlockCallback` only |

`exchangeIn` / `previewExchangeIn` come from `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` (`0x05562cc8` / `0x89d61912` observed). `exchangeOut` / `previewExchangeOut` come from `IStandardExchangeOut.sol` (`0x612d4427` / `0xdb149bc5` observed). Both Out methods revert `ExchangeOutNotAvailable` (`S1-P03`). Interface presence is not route availability.

Each family facet index `>= 5` must return `linkedComponents()` equal to the package's `linkedLibraries` array, or construction reverts `InvalidComponent`. That check is copied from the current PairToken `_appendComponent`, not invented here.

### FS-FACET-03 — Factory-owned facets excluded from `PkgInit`

Source: PairToken DFPkg interface comment "Factory-owned introspection and temporary-hook facets are never package inputs"; `S1-ARCH-04`; `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` constructor documentation and immutables `ERC165_FACET`, `DIAMOND_LOUPE_FACET`, `ERC8109_INTROSPECTION_FACET`, and the temporary `PostDeployAccountHookFacet` removed in `postDeploy`.

Never package inputs, never in `facetAddresses()`, `facetCuts()`, or package-owned interface aggregation:

| Factory facet | Interface | Lifecycle |
| --- | --- | --- |
| ERC-165 facet | `IERC165` | Persistent. Factory installs it. |
| Diamond loupe facet | `IDiamondLoupe` | Persistent. Factory installs it. |
| ERC-8109 introspection facet | `IERC8109Introspection` | Persistent. Factory installs `functionFacetPairs`. |
| Post-deploy account hook facet | `IPostDeployAccountHook` | Temporary. Factory adds it for deploy and removes it in `postDeploy`. This package does not manage that cut. |

Exclusion from the package does not remove the three persistent interfaces from the finished proxy. Tests assert they are callable and absent from package cuts (`S1-A57`, `FS-FACET-03`).

### FS-FACET-04 — No new selector for the unlocked entry

Hooks call `IStandardExchangeIn.exchangeIn`. They do not call a special "unlocked" selector. Adding one would be a second entry and an authorization surface. Do not add it. Do not add `IRateProvider`, `IStandardExchangeRateQuote`, Wings economic selectors, `diamondCut`, rescue, ownership, or Permit2.

### FS-FACET-05 — Infrastructure bindings, not facets

Also in `PkgInit`, and in `bindingHash`, matching the current PairToken struct:

- `IPoolManager poolManager`
- `IVaultRegistryDeployment registry`
- `IVaultFeeOracleQuery oracle`
- `IWETH wrappedNative`
- `IDiamondPackageCallBackFactory diamondFactory`
- `address[6] linkedLibraries`, order fixed: Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation

`IVaultFeeOracleQuery` is bound so `StandardVaultRepo` can be initialized. Execution does not charge a vault fee. `vaultFeeTypeIds()` stays `bytes32(0)`.

## 4. Proposed file and package contract

### FS-ARCH-01 — File split

Mirror the current PairToken split under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Do not create these files in this research pass.

| File | Role |
| --- | --- |
| `interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol` | Family ABI, enums, events, errors. `PkgInit` is not defined here. |
| `interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | `PkgInit`, `PkgArgs`, package errors, `bindingHash`, `deployVault`. Structs live on this interface, not on the contract. |
| `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | Immutable package. SELF-dispatch for facet lists when called in a foreign context, as the current PairToken package does. |
| `UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol` | `linkedComponents() returns (address[6])` for the seven family facets. |
| `UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol` | CREATE3 deploy of the six libraries and seven family facets. Package deployment goes through the IndexedEx manager registry, not `new` and not a direct diamond-factory call. |
| `UniswapV4FullSpreadStandardExchangeVaultRepo.sol` | Family storage. ERC-1967 slot `bytes32(uint256(keccak256(abi.encode("indexedex.vault.standard.exchange.uniswap.v4.fullSpread"))) - 1)`. Dual `_layoutStruct`. No state variables. |
| `UniswapV4FullSpreadStandardExchangeVaultTypes.sol` | Config, inventory categories, operation kind, action, snapshot. No second share ledger. |
| `UniswapV4FullSpreadStandardExchangeVaultMath.sol` | Integer issuance, withdrawal allocation, zap size, compound leftover. Same equations as `S1-ACC-*`. |
| `UniswapV4FullSpreadStandardExchangeVaultProjection.sol` | Projection and SwapProjection. Shared by quote and execution. |
| `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` | One planner for execution and previews, including `S1-EXIT-01` mode choice and the three quote budgets. |
| `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` | Execution and ExecutionPreparation. Locked path and already-unlocked path. |
| `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` / `MoneyFacet.sol` | Public money entry. |
| `UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol` / `QuoteFacet.sol` | Previews. |
| `UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol` / `OutFacet.sol` | Reverting exact output. |
| `UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol` / `QueryFacet.sol` | Static and economic queries. |
| `UniswapV4FullSpreadStandardExchangeVaultSYMoneyTarget.sol` / `SYMoneyFacet.sol` | SY deposit, redeem, reward index, claim. |
| `UniswapV4FullSpreadStandardExchangeVaultSYQueryTarget.sol` / `SYQueryFacet.sol` | SY discovery, previews, `exchangeRate`. |
| `UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol` / `CallbackFacet.sol` | `unlockCallback` for the vault-started unlock only. |
| `test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` | Production-first harness. |
| `test/behaviors/Behavior_UniswapV4FullSpreadStandardExchangeVaultPackage.sol` | Package declaration checks. |

Specs, not co-located with production:

- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultHookIntegration.t.sol`

Storage must not reuse the PairToken or Wings slot. The test reads those Repo constants and asserts inequality. This contribution did not read those constants, so it does not claim their values.

No `receive` facet. Empty-calldata ETH hits the proxy receive path (`S1-NATIVE-01`). The active engine attributes expected receipts. Unsolicited ETH stays unbooked.

### FS-PKG-01 — `PkgInit` and `PkgArgs`

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

No optional component. No caller-selectable execution address. No hook address. No rate-provider address. No silent zap default. `maxZapBps == 0` or `maxZapBps > 10_000` or `maxZapTickMove < 0` reverts `InvalidZapLimits`.

### FS-PKG-02 — Identity, deploy, init

- `bindingHash()` returns `keccak256(abi.encode(init_))`, computed in the constructor from the full `PkgInit`. All twelve facets and five infrastructure bindings participate. Linked-library addresses participate.
- `calcSalt(bytes)` returns `keccak256(abi.encode(bindingHash, abi.decode(args, (PkgArgs))))`.
- `processArgs` runs by delegatecall in the factory. It reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound diamond factory. It validates, then returns `abi.encode` of the decoded args. It does not read foreign package storage.
- `deployVault(PkgArgs) returns (address)` calls `registry.deployVault(this, abi.encode(args))`. Tests and production use this path. A direct `diamondPackageFactory.deploy` of a registered vault package is a test failure, not an alternate production path.
- `initAccount` runs by delegatecall on the proxy. It reverts `InvalidInitializationContext` unless the factory's `pkgOfAccount` is this package's `SELF` and the factory's stored args match the calldata. It reverts `AlreadyInitialized` if the family flag is set. It re-validates args.
- Initialization writes family config, `ERC20Repo._initialize(name, symbol, 18)`, `EIP712Repo._initialize(name, "1")`, `MultiAssetBasicVaultRepo._initialize(faces)` in PoolKey face order, and `StandardVaultRepo._initialize(oracle, bytes32(0), facetInterfaces(), keccak256(abi.encode(sortedFaces)))`. Registry contents hash uses the sorted copy. `vaultTokens()` keeps PoolKey face order (`S1-A58`).
- `updatePkg` and `postDeploy` revert `InvalidInitializationContext` unless the caller is the bound factory and the account's package is `SELF`. `postDeploy` does not add cuts.
- Package facet lists use SELF when `address(this) != SELF`, matching the current PairToken package. `calcSalt` / `processArgs` must keep working under factory delegatecall.

Faces: `C0` is `wrappedNative` when `currency0` is `address(0)`, otherwise `currency0`. `C1` is `currency1`. A native leg and that same wrapper as `currency1` collide and revert `InvalidWrappedNative`.

### FS-PKG-03 — Validation errors

Reuse the current PairToken package error set. Observed selectors are citations:

| Error | When | Observed selector |
| --- | --- | --- |
| `InvalidComponent()` | Missing code, empty facet, selector-set mismatch, or family facet `linkedComponents()` mismatch | `0xb03ac0b6` |
| `InvalidPoolKey()` | `currency0 >= currency1`, currency1 has no code, nonzero currency0 has no code, hooks nonzero, `fee > 1_000_000`, tick spacing outside `(0, 32767]`, currency is this package, pool sqrt price is zero | `0xc256622b` |
| `InvalidRateAsset()` | `rateAsset` is not one of the two ERC-20 faces | `0x41ef82fd` |
| `InvalidZapLimits()` | Basis points or tick bound outside the rule above | `0x70965b62` |
| `InvalidWrappedNative()` | Wrapper has no code, decimals not 18, `deposit()` / `withdraw(0)` probe fails, probe changes the package's wrapper balance, or the two faces are equal | `0x5e66e44d` |
| `NotCalledByRegistry()` | `processArgs` outside the registry/factory delegatecall context | `0xd8af869a` |
| `InvalidInitializationContext()` | Proxy init or lifecycle callback does not match the factory's package and args | `0x0bda07c4` |
| `AlreadyInitialized()` | Second `initAccount` | `0x0dc149f0` |

Wrapper probe must not retain inventory. Zero pool fee is valid. Dynamic-fee flag is not. Rate-asset decimals are cached for `assetInfo` and are not used to scale `exchangeRate`. No token allowlist.

`PoolKey.hooks` must be `address(0)`. The vault's pool is not a buffer-hook pool. Hook integration uses a different pool on the same or another manager (`FS-HOOK-01`).

### FS-PKG-04 — Family ABI that init does not install twice

Family interface keeps the current PairToken function set so hook callers and SE routers do not need a new selector. Amount pairs use actual PoolKey currency order, including native `currency0`.

Enums: `WithdrawalMode { FullCompound, CollectOnly }`, `MaintenanceReason { None, MaintenanceWorkLimit, MaintenancePriceLimit, MaintenanceLiquidityLimit, MaintenanceDeltaLimit }`.

Required functions, same signatures as `IUniswapV4PairTokenStandardExchangeVault`: `depositPair`, `previewDepositPair`, `redeemPair`, `previewRedeemPair`, `donate`, `compound`, `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, `maxZapTickMove`, `previewWithdrawalMode`, `previewZapCredit`.

`previewWithdrawalMode(shares, paired, tokenOut)`: paired queries pass `tokenOut == address(0)` as a sentinel. Otherwise `address(0)` means raw ETH output. The boolean is what separates those cases.

Events to keep, with payloads that distinguish input, deployed amounts, shares, allocations, sale proceeds, and actual payout: `PairDeposited`, `PairRedeemed`, `WithdrawalSale`, `Donated`, `Compounded`, `ZapCredit`, `WithdrawalMaintenanceSelected`. Topics are recomputed. Do not invent a protocol-fee event.

Family errors to keep: `ReentrantOperation`, `EconomicStateChanged`, `InvalidAccountingState`, `ZeroPayout`, `QuoteWorkExceeded(uint256,uint256)`, `QuoteTickCrossingsExceeded(uint256,uint256)`, `QuoteBitmapWordsExceeded(uint256,uint256)`, `IssuanceDisabled`. Do not require `ManagerAlreadyUnlocked`.

Add one error, signature only:

```solidity
error DeltaNotClosed();
```

Selector is assigned by the NatSpec script, not here. It is the unlocked-path failure when this diamond's manager deltas are not zero before return (`FS-UNLOCK-04`).

Quote budgets stay `S1-QUOTE-01`: 64 swap steps, 12 initialized crossings, 16 distinct bitmap words, shared across one candidate, fresh counters per withdrawal candidate, at most two withdrawal candidates. Errors carry `(actual, limit)` with the rejecting value (65/64, 13/12, 17/16).

## 5. Money, callback, and already-unlocked hook entry

### FS-MONEY-01 — Surface

| Call | Meaning | Empty supply |
| --- | --- | --- |
| `depositPair` | Payable paired entry of accepted portions of two maxima. Native pools require `msg.value == amount0Max` and refund only unused ETH. Two-ERC-20 pools require zero value. | Genesis path. Both accepted amounts must be positive. |
| `redeemPair` | Burn caller shares. Pay both actual pool currencies, raw ETH included. No pretransfer flag and no third-party allowance burn. | No redemption. |
| `exchangeIn` C0 or C1 to share | Exact-input zap. Nonpayable. Raw `address(0)` is not an SE route. | Revert `ExchangeInNotAvailable`. Paired bootstrap is required. |
| `exchangeIn` share to C0 or C1 | Proportional withdrawal, then sale of only the unwanted allocation. | No redemption. |
| SY `deposit` / `redeem` | Same engine, with native-versus-wrapped settlement from `S1-API-03`. | Same empty-supply rules. |
| `donate` | Payable book of this call's positive receipt. No mint. Does not adopt older balances. | Revert. Positive supply required. |
| `compound` | Permissionless incumbent maintenance. No supply change. No vault fee. | No-op when `S = L = B0 = B1 = 0`. Does not adopt unbooked balances. |
| `exchangeOut` / `previewExchangeOut` | Installed. Both revert `ExchangeOutNotAvailable` before any transfer, burn, mint, or manager call. | Same revert. |

Route rejects use `InvalidRoute`. Unmet SE minima use `MinAmountNotMet`. Expiry is `deadline < block.timestamp`; equality is allowed. Zero amount, zero recipient, and self recipient revert. Disabled registry blocks new paired, SE, and SY issuance and explicit donation. Standalone compound stays open. Exits stay open, including the maintenance they need (`S1-SEC-02`).

Pretransfer follows `IStandardExchangeIn`: `pretransferred == true` is contract-only (`EOAPretransferNotAllowed` for a codeless caller). Booked backing is never pretransfer credit. Declared input is processed only from unbooked surplus. Excess is not refunded. False-flag pulls require an exact observed delta and do not fill a shortfall from booked inventory. Hooks call with `pretransferred == false` after `forceApprove`. The vault must pull with `transferFrom` on that path. Do not require the hook to pretransfer.

`vaultTokens()` reports booked local custody of the two ERC-20 faces, not liquidation value. Family `basket()` is clamped removable principal plus booked idle, excluding uncollected fees. `positionLiquidity()` is this position's liquidity, not pool active liquidity.

### FS-UNLOCK-01 — Two entries, one engine

Every manager-touching money operation uses one planner and one settlement engine.

1. Validate route, amounts, recipient, deadline, share authority, and `msg.value` first. Do not read `isUnlocked` to skip a check.
2. Take the family guard. `ReentrantOperation` if the family is busy. `InvalidAccountingState` if uninitialized, a callback hash is outstanding, or reservations are nonzero.
3. Isolate pending credit and preflight the complete plan before an ERC-20 pull or a manager mutation. Native `msg.value` is reserved before compound.
4. Branch on `TransientStateLibrary.isUnlocked(config.poolManager)`:
   - Locked: `FS-UNLOCK-03` vault-started unlock.
   - Unlocked: `FS-UNLOCK-04` inline execution. Do not revert because the manager is unlocked.
5. Publish booked reserves and release the guard only after payout and refund. Reservations are zero on success.

Standalone `compound` and `donate` use the same branch. If they need no manager call, they still must not revert solely because the manager is unlocked, and they must not call `unlock`. A deposit's mandatory compound runs inside the deposit, on whichever branch the deposit took. Deposits and standalone compound do not receive the withdrawal-only `CollectOnly` fallback (`S1-EXIT-01`).

Previews and `exchangeRate` do not take the guard and do not mutate. An idle vault's preview while the manager is unlocked equals the same preview while it is locked. A preview during a family operation reverts `ReentrantOperation`. Static config, token, and domain reads stay available during an operation. `IBasicVault` reserve reads return the last committed snapshot (`S1-SEC-01` read table, inherited).

### FS-UNLOCK-02 — The unlocked flag is not authorization

`isUnlocked == true` does not identify the caller, does not waive allowance, does not waive the pretransfer rules, does not waive minima or deadlines, and does not authorize `unlockCallback`. The money caller remains `msg.sender`. The PoolManager being unlocked does not make the PoolManager the depositor. A hook is an ordinary contract caller: it is paid only what the route pays any recipient, and it can be reentered into only to the extent a token or ETH transfer reenters. That reentry hits the family guard and reverts `ReentrantOperation`.

No hook allowlist. No "only while unlocked" role. A user who calls the vault during some other unlock is subject to the same authority checks and must still close this diamond's deltas before return.

### FS-UNLOCK-03 — Ordinary locked entry

When the bound manager is locked:

1. Build the action payload.
2. Store `callbackHash = keccak256(abi.encode(operation, payload))` before `unlock`.
3. Call `poolManager.unlock(payload)` once.
4. `unlockCallback` accepts the call only from the bound manager, only while the guard is held, only when the hash matches, and only once. Then clear the hash.
5. Reject a wrong manager, an unsolicited payload, a replay, or a nested callback.
6. After `unlock` returns, the hash is clear and `isUnlocked` is false. Otherwise revert. Do not leave the manager unlocked.
7. Settle inside the callback with the canonical sequence. ERC-20: sync, transfer, settle, take. Native debt: `sync(Currency.wrap(address(0)))`, then `settle{value: exactDebt}()`, then `take` for credits. Never call ERC-20 methods on `address(0)`.

This is the user entry. It is not used when step 4 of `FS-UNLOCK-01` already observed an unlock.

### FS-UNLOCK-04 — Already-unlocked hook entry

When the bound manager is already unlocked, do not call `unlock`. Do not set `callbackHash`. Do not treat an incoming `unlockCallback` as this operation's callback. Run the planned actions by calling the manager directly from this diamond:

- `modifyLiquidity` and `swap` only on this diamond's hookless `PoolKey`.
- `sync`, `settle`, and `take` only for deltas this call created.
- Position owner remains `address(this)`. The only position written is `(address(this), tickLower, tickUpper, bytes32(0))`.
- Before the money call returns, this diamond's currency deltas on that manager are zero. If not, revert `DeltaNotClosed` and roll back the whole operation, including mint, burn, and token pulls.
- Do not clear another address's deltas. The outer locker, usually the swap router, keeps its own deltas. The hook keeps its own deltas. This diamond settles only what it caused.
- A code path that calls `unlock` while `isUnlocked` is true is a defect. The test must fail if that call is reached. Do not catch the manager's already-unlocked revert and continue.

The hook's pool and this vault's pool are different pool keys. The vault key has `hooks == address(0)`. The hook key has the hook address. During `beforeSwap` the vault may modify its own pool. It must not swap or modify liquidity on the hook's pool key.

Native settlement on this path uses the same sync / value-settle / take sequence. The diamond accepts ETH from the wrapper and the manager during the operation. A receive is not a new deposit. Payouts use a checked value transfer with no 2,300-gas stipend. A rejecting or reentrant receiver rolls the operation back.

### FS-UNLOCK-05 — Callback is not a public money route

`unlockCallback` stays installed and stays unusable as a deposit or withdraw entry. Authentication is the bound manager plus the committed hash plus the active operation. An external unlock does not satisfy that check. If `unlockCallback` is invoked with no committed hash, revert the existing invalid-callback failure and do not mint, burn, or settle.

### FS-MONEY-02 — Single-token and paired settlement details that hooks will hit

Hook exact-in calls observed in source, both from inside `beforeSwap` while the manager is unlocked:

- Dual: `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol` `_buffer` and `_unwrap` call `previewExchangeIn` then `exchangeIn(..., pretransferred=false, deadline=block.timestamp)`.
- Single pricing: `UniswapV4SingleStandardExchangeBufferHookTarget.sol` `_wrapExactIn` and `_unwrapExactIn` do the same, after `take` and `forceApprove`.

Those calls are the already-unlocked deposit and withdrawal. `exchangeIn` must complete and return. The hook then `settle`s its own currency. If this vault left a delta, the outer unlock cannot finish.

Hook exact-out calls `exchangeOut` from the same unlocked context. Observed sites include dual `_unwrapExactOut`, single-pricing `_wrapExactOut` / `_unwrapExactOut`, and the CP, orbital, Balancer-quad, Curve-quad, and weighted claim or target files that call `IStandardExchangeOut.exchangeOut`. Those calls must revert `ExchangeOutNotAvailable` without taking funds (`FS-HOOK-03`). Do not implement exact output to make those paths pass.

Paired methods remain the only two-currency entry and exit. Do not alias them onto `IStandardExchangeInMulti` or `IStandardExchangeOutMulti` (`S1-OP-03`).

## 6. Rate, quote, and issuance separation

### FS-RATE-01 — Three different numbers

| Function | What it is | What it is not |
| --- | --- | --- |
| Issuance, `S1-ACC-02` and `S1-ACC-07` | Share mint from attributable reserve growth at the frozen checkpoint price. Zap input is not valued through `exchangeRate`. | Not `exchangeRate`. Not `getRate`. Not a one-share exit quote. |
| `exchangeRate()` | SY accounting value. Raw rate-asset units per `1e18` raw share units. `A_i = N_i(P,L) + B_i + F_i`. Convert at the live sqrt price with one floor after the full conversion, then `floor(Vraw * 1e18 / S)`. Zero supply returns zero. | Not an execution guarantee. Not a manipulation-resistant oracle. Not an issuance input. Not the one-share exit quote. |
| Executable one-share exit quote | `previewExchangeIn(share, 1e18, currencyFace)` and the matching `previewRedeem` / SY preview. One whole share, because shares have 18 decimals. Raw currency units out. Same planner as execution, including maintenance choice and full unwanted-leg consumption. | Not `exchangeRate`. Not a spot NAV. Not a full-book liquidation divided by supply. |

Do not collapse these. A UI or hook that wants a rate must name which one it calls. This diamond does not install a function that returns more than one of them.

### FS-RATE-02 — No `getRate` on this diamond

`S1-API-04` does not install `IRateProvider`. Wings does, in `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.getRate`, as a full-book liquidation quote scaled by supply. Do not copy that facet or that formula.

Owner decision 8 is satisfied by not exposing a false rate. Where a rate is exposed, it must be the executable normalized one-share exit quote. This package exposes that quote only as the preview functions in `FS-RATE-01`, in raw units. It does not expose `getRate`. It does not normalize that preview into WAD inside the vault.

Buffered hooks do not read a rate from the SE. Agent law (APEX D60) says a hook values a buffered reserve as `held * IRateProvider.getRate()`, and package init reverts `RateProviderRequired` when `token != standardExchange` and the provider address is zero. The provider is a `PkgArgs` field on the hook, not a facet of this vault. Deployments that need a provider use the existing external `StandardExchangeRateProvider` through `contracts/test/libs/RateProviderFixtureLib.sol` in tests, and the same production package in product wiring. This PRD does not deploy that provider and does not change it.

That external provider's `getRate` is a full-book `previewExchangeIn` normalization, with a zero-supply unit-deposit invert. That formula is not this family's issuance rule, not `exchangeRate`, and not the one-share exit quote. Do not change this vault so the provider's full-book figure matches one-share redemption. A zero-supply zap on this vault still reverts `ExchangeInNotAvailable`. If the provider then returns zero, that is the provider's failure-closed behavior, not a vault defect to patch.

### FS-RATE-03 — Quote parity

`S1-QUOTE-01` and `S1-GAS-01` apply on both unlock branches. Preview and execution return the same integers from the same idle state, whether or not the manager is unlocked, provided the vault guard is idle. The unlocked branch does not get a different fee, fallback, or work budget. The 12,000,000 gas engineering ceiling and the 5,000,000 local preview ceiling stay. Hook-combined transactions are reported. They are not a new ceiling and not a waiver.

`rateAsset` only denominates `exchangeRate` and `assetInfo`. It is not the zap input token and not a Chainlink feed.

## 7. Test and acceptance requirements, including cross-vault hook integration

### FS-TEST-01 — Harness

`TestBase_UniswapV4FullSpreadStandardExchangeVault` follows the current PairToken harness pattern: real PoolManager port, CREATE3 facets, package registered through `indexedexManager`, instances from `deployVault`. Inheritance is `CraneTest` then `IndexedexTest` then this TestBase. Do not extend a concrete Wings vault or a concrete PairToken vault. Do not `new` the package or the facets. Do not `vm.etch`, `vm.mockCall`, or `vm.store` the vault, the package, the manager, the registry, the fee oracle, or the PoolManager.

Shared ERC-20 and vault facets come from the existing vault-component factory path. Family facets come from this family's FactoryService. After production edits, the repository artifact workflow applies: build creation bytecode before tests. This research pass does not run Forge.

`viaIR` stays off. Do not lower fuzz or invariant depth. Do not add a Foundry profile.

Comparison ledger columns: preserved, intentional deviation, unsupported scope, new capability. `FS-X01` is an intentional deviation from PairToken `S1-A40`. `FS-X02`'s refusal to add a second equation is a preserved rule. Hook rows are new capability. Do not edit PairToken tests to match this family.

Behavior library checks package cuts, interface IDs, and the 20 shared selectors. Sequence tests call public routes only. No synthetic mint of the share supply.

Proxy surface matrix, required on the live registered proxy:

- Every package selector is callable.
- Package cuts equal the twelve facets and no others.
- Factory ERC-165, loupe, and ERC-8109 are callable and are not in package cuts.
- Temporary post-deploy hook is absent after `deployVault` returns.
- Absent: `diamondCut`, rescue, operational ownership, `IERC4626`, `IRateProvider.getRate`, Wings rebalance and transition selectors.

Trust-flag negatives, on both locked and already-unlocked entry:

- Codeless `pretransferred == true` reverts the canonical pretransfer error.
- Contract true-flag without unbooked credit cannot spend booked backing.
- Excess pretransfer is not refunded and is not minted.
- False-flag short pull does not fill from reserves.
- Unlocked state changes none of those results.

FoT proof uses a real fee-on-transfer token as a configured pool currency and expects the operation not to produce a supported share or payout. Do not add an allowlist. Do not ship a test that treats actual-in credit as FoT support.

### FS-A-S1 — Inherited acceptance rows

Every `S1-A01` through `S1-A70` row except `S1-A40` is an acceptance row of this family, executed against this package and this type prefix. Retain the `S1-A` IDs in the ledger. `S1-A40` is not inherited. Its replacement is `FS-AH02`.

Those rows already cover paired genesis, zap credit, proportional redemption, full unwanted-leg consumption, donation, compound, fee attribution, both exact-output selectors reverting, preview parity, quote budgets, all 16 SY methods, pretransfer negatives, native ETH, callback authentication, disable, rollback, decimal mixes, and the factory-facet exclusion. Do not replace a row with a smoke test.

### FS-AH01 — Two shares, one hook swap, exact-in

File: `UniswapV4FullSpreadStandardExchangeVaultHookIntegration.t.sol`.

Deploy two real registered vaults on one real PoolManager, different hookless pools: this family, and a second SE vault that is either a second instance of this family or a current PairToken instance. Deploy a current dual buffer-hook package through `registry.deployHookVault`, not a direct hook-factory call and not a vault-factory call.

Hook arguments that current code accepts without a package edit:

- `standardExchange0` = this diamond. `token0` = one address in `IBasicVault(this).vaultTokens()`. `token0 != standardExchange0`. `rateProvider0` = a real `StandardExchangeRateProvider` for that pair, from the existing fixture helper. Identity `token0 == standardExchange0` is not this test.
- `standardExchange1` = the other SE diamond. `token1` = one address in that vault's `vaultTokens()`, distinct from `token0`. `rateProvider1` set the same way.
- Hook `poolManager` equals both vaults' `poolManager`.

Execute one exact-in swap through that hook's pool. The hook's `beforeSwap` calls `exchangeIn` on both vaults while the manager is unlocked. Observed call shape is `_buffer` / `_unwrap` in `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`, reached from `UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget.beforeSwap`.

Assert:

- The swap returns.
- This diamond's share supply and the other vault's share supply both changed, or a zero-amount leg is not used to fake the row. Use amounts that mint or burn a positive share amount on both legs.
- `positionLiquidity` owner for this diamond's position key is this diamond, read from the manager, not from a local counter alone.
- The other vault's position owner is that other diamond.
- After `exchangeIn` returns, and again after the outer unlock returns, this diamond has no open manager delta (`FS-AH04`).
- Neither vault called `unlock`. A nested `unlock` reverts the swap; that revert fails this row.
- No hook source file is modified. The test deploys the current dual package bytecode.

### FS-AH02 — Deposit and withdrawal while already unlocked

Same file. A harness may `unlock` the real PoolManager and, inside that callback, call this vault. That is the controlled form of the hook entry. The dual-hook swap in `FS-AH01` is the product form. Both are required.

Inside an already-open unlock, with this vault idle:

- `exchangeIn` of a currency face to shares mints, pulls only that face, and returns a positive share amount when the pool is bootstrapped and the plan fits the budgets.
- `exchangeIn` of shares to a currency face burns those shares, pays only that face, and sells the other allocation completely.
- `depositPair` and `redeemPair` succeed under the same inherited predicates, paying or pulling actual pool currencies, including raw ETH when the pool is native.
- SY native deposit and redeem succeed on a native pool with `msg.value` reserved before compound.
- None of these revert `ManagerAlreadyUnlocked`.
- The same calls, when the manager is locked, still take the vault-started unlock and still reject a forged `unlockCallback`.

`FS-AH02` replaces `S1-A40` for this family only. PairToken's reject stays correct for PairToken.

### FS-AH03 — No nested unlock, flag is not authority

- A money call while unlocked does not call `poolManager.unlock`.
- `unlockCallback` from the manager during an external unlock, with no hash committed by this vault, reverts and does not mint.
- A second money call reentering from a payout receiver reverts `ReentrantOperation` and rolls back the outer money call.
- An EOA cannot set `pretransferred` and use the unlocked state to skip the pull.
- A caller who is not the share owner cannot burn shares because the manager is unlocked.

### FS-AH04 — Deltas close before return

Inside the harness unlock, after each vault call returns, this diamond's manager deltas on both pool currencies are zero. The harness can then settle its own unrelated deltas and finish `unlock`. If the vault left a delta, the harness must observe `DeltaNotClosed` from the vault rather than a later `CurrencyNotSettled` from the manager. The hook swap in `FS-AH01` is the integrated form of the same obligation: the outer unlock completes.

### FS-AH05 — Share is a pool asset on the current single pricing hook

Deploy the current `UniswapV4SingleStandardExchangeBufferHook` package. `standardExchange` is this diamond. `pairToken` is one `vaultTokens()` face and is not the diamond (`SameToken` is the current package's reject for that equality). Pool currencies are `sort(pairToken, diamond)`, so the share is a pool currency. Source: that package's `initAccount` and `_requirePairInVaultTokens`.

One exact-in swap calls `_wrapExactIn` or `_unwrapExactIn` in `UniswapV4SingleStandardExchangeBufferHookTarget.sol` while unlocked. Assert the share balance and the pair-token balance move, the position owner is this diamond, and deltas are closed. No package edit.

### FS-AH06 — Exact-out hook paths fail closed

On the dual hook and the single pricing hook, an exact-out swap that reaches `exchangeOut` on this diamond reverts `ExchangeOutNotAvailable`. Share supply, position liquidity, booked reserves, and the caller's token balances are unchanged. The other SE vault in the dual fixture is unchanged. This is required behavior, not a hook bug to fix in this PRD.

### FS-AH07 — Current hook rejection that this PRD does not remove

`UniswapV4SeBufferHookLegLib.isWrapperShareInventory` returns true only when `pair == se` and `staticcall` of selector `0x38d52e0f` (`IERC4626.asset`) returns a different nonzero address. This diamond must not implement that selector.

Dual package `_requireTokenInVaultTokens` therefore does not treat this share as identity inventory. Binding `token == this diamond` and `standardExchange == this diamond` reverts `TokenNotInVaultTokens` unless `asset()` succeeds, which it must not. Source: `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol` `_validateArgs` / `_requireTokenInVaultTokens`, and the lib function above.

`FS-HOOK-04`: a later change to those hook packages would be required to accept this non-ERC-4626 share as an identity leg (`token == se`) on a reserve-holding hook. That change is not part of this family and is not authorized by this PRD. Do not add `asset()` to slip past the check. Cross-vault tests use buffered legs and `FS-AH05`, which current packages already accept.

### FS-AH08 — Fee, native, and rollback rows on the unlocked path

Repeat, while the manager is already unlocked, the obligations already in `S1-A24`, `S1-A26`, `S1-A43`, `S1-A49`, and `S1-A51`:

- Entry-swap fees stay with incumbents. Exit-sale fees stay with remaining liquidity. No double count.
- Exact output still reverts with no manager mutation.
- A reverting payout receiver rolls back mint, burn, and manager actions.
- Native paired entry reserves `msg.value` before compound and refunds only the unused part.
- Native debt syncs currency zero before value settle. No ERC-20 call targets `address(0)`.

### FS-HOOK-01 — Hook families this share must be tested against

Current families under `contracts/hooks/uniswap/v4/standardExchange/`. One package interface was read for each. Tests in `FS-AH01` and `FS-AH05` cover the two shapes that place another SE share beside this one, or place this share in the pool. The other families must accept this diamond as `standardExchange` when their token is in `vaultTokens()` and, where the package requires it, a rate provider is set. That is a deployment-argument fact, not a hook edit.

| Family | Package interface read | Share acceptance without a hook edit |
| --- | --- | --- |
| Single constant-product | `constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol` | Buffered leg: `pairToken` in `vaultTokens()`, provider required when `pairToken != standardExchange`. |
| Dual constant-product | `dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol` | Two legs. This is the `FS-AH01` witness. |
| Orbital | `orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol` | A leg whose token is in this vault's `vaultTokens()` can name this diamond as that leg's SE. At least one SE is required by that package. |
| Single pricing, no reserve | `single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol` | `FS-AH05` witness. Share is a pool currency. Outside the D60 reserve-valuation rule. |
| Balancer quad stable | `stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol` | Same buffered-leg rule. Dynamic token array. Provider required for a buffered leg. |
| Curve quad stable | `stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol` | Same, fixed four tokens, at least one SE. |
| Weighted | `weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol` | Same, `n` in the package's accepted range, at least one SE. |

Do not claim a family rejects this share unless the test hits a cited revert. The only cited init rejection is `FS-AH07`.

### FS-HOOK-03 — Exact output is not a hook-package task

Because `FS-AH06` is inherited vault behavior, no hook package needs an edit for this family to be deployable. Exact-out swaps against this vault fail closed. A future hook that must unwrap this share with exact output needs a separate product decision to change `S1-P03`. That decision is not open in this PRD.

## 8. Inherited IDs, new `FS-` IDs, and owner decisions still open

### Inherited, not rewritten

`S1-D03`, `S1-D04`, `S1-D05`, `S1-P01`, `S1-P02`, `S1-P03`, `S1-P04`, `S1-P05`, `S1-P06`, `S1-P07`, `S1-X01` through `S1-X19` except the unlocked-reject sentences, `S1-ARCH-02`, `S1-ARCH-03`, `S1-ARCH-04`, `S1-ARCH-05`, `S1-ACC-01` through `S1-ACC-07`, `S1-OP-01` through `S1-OP-04`, `S1-OP-05` except the unlocked-reject sentence, `S1-EXIT-01`, `S1-NATIVE-01`, `S1-API-01` through `S1-API-05`, `S1-QUOTE-01`, `S1-QUOTE-02`, `S1-GAS-01`, `S1-PKG-01`, `S1-SEC-01` except the `ManagerAlreadyUnlocked` sentence, `S1-SEC-02`, `S1-OBS-01`, `S1-A01` through `S1-A39`, `S1-A41` through `S1-A70`, `S1-TEST-01`.

`S1-D01` and `S1-D02` are historical PairToken decisions. This family's placement is `FS-BOUND-01`, not `S1-ARCH-01`. The full-range strategy of `S1-D02` is inherited. The PairToken directory is not.

### Not inherited

| PairToken ID | Replacement |
| --- | --- |
| `S1-A40` | `FS-AH02` |
| `S1-SEC-01` sentence that reverts `ManagerAlreadyUnlocked` before a new unlock | `FS-UNLOCK-01`, `FS-UNLOCK-04` |
| `S1-OP-05` sentence that fails calls while the manager is already unlocked | `FS-UNLOCK-01` |
| `S1-ARCH-01` directory and type prefix | `FS-BOUND-01`, `FS-ARCH-01` |

The "no local-sleeve fallback" sentence in `S1-OP-05` is inherited. Inline manager execution is not a sleeve.

### New IDs

| ID | Requirement | Acceptance |
| --- | --- | --- |
| `FS-BOUND-01` | Sibling full-spread family, one diamond, one pool, one position, one share supply | `S1-A01` against this type and directory |
| `FS-BOUND-02` | Not Weir, not Wings, not ERC-4626, not a PairToken rename | Proxy matrix has none of those selectors |
| `FS-X01` | Unlocked inline path replaces the PairToken reject | `FS-AH02` |
| `FS-X02` | Single-token full pull and single-currency payout; zap `J_i` stays the inherited booked donation; exit cannot burn-and-donate | `S1-A13`, `S1-A18`, `S1-A19`, plus no second-token payout assertion |
| `FS-X03` | No second equation set | `S1-A15` predicate, independent arithmetic |
| `FS-FACET-01` | Five shared facets, explicit fields | `S1-A56` |
| `FS-FACET-02` | Seven family facets, PairToken selector split | `S1-A06` |
| `FS-FACET-03` | Factory facets excluded | `S1-A57` |
| `FS-FACET-04` | No unlocked-only selector | Proxy matrix |
| `FS-FACET-05` | Five infrastructure bindings plus six libraries | `S1-A02` |
| `FS-ARCH-01` | File split and distinct storage slot | Slot inequality test |
| `FS-PKG-01` | `PkgInit` / `PkgArgs` on the package interface | Package behavior test |
| `FS-PKG-02` | `bindingHash`, salt, registry `deployVault`, init | `S1-A01`, `S1-A02`, `S1-A04` |
| `FS-PKG-03` | Validation errors | `S1-A03` |
| `FS-PKG-04` | Family ABI matches the current function set, plus `DeltaNotClosed` | Selector manifest recomputed by script |
| `FS-MONEY-01` | Money surface | `S1-A08` through `S1-A26`, `S1-A29` |
| `FS-MONEY-02` | Hook call shape is ordinary `exchangeIn` | `FS-AH01` |
| `FS-UNLOCK-01` | One engine, two branches | `FS-AH02` |
| `FS-UNLOCK-02` | Flag is not authorization | `FS-AH03` |
| `FS-UNLOCK-03` | Locked path keeps `unlockCallback` | `S1-A39` |
| `FS-UNLOCK-04` | Inline actions, position owner, delta close | `FS-AH02`, `FS-AH04` |
| `FS-UNLOCK-05` | Callback is not a money entry | `FS-AH03` |
| `FS-RATE-01` | Issuance, `exchangeRate`, and one-share exit quote stay separate | `S1-A32`, `S1-A33`, preview-versus-`exchangeRate` inequality where they differ |
| `FS-RATE-02` | No vault `getRate`; external provider is not family accounting | Proxy matrix; provider formula not used as mint input |
| `FS-RATE-03` | Quote parity and gas ceilings on both branches | `S1-A27`, `S1-A70` |
| `FS-TEST-01` | Production-first TestBase, proxy matrix, trust-flag negatives | Harness review plus the rows above |
| `FS-A-S1` | Inherit `S1-A*` except `S1-A40` | Those rows |
| `FS-AH01` | Two SE shares moved by one dual-hook exact-in swap | That test |
| `FS-AH02` | Deposit and withdrawal while unlocked | That test |
| `FS-AH03` | No nested unlock; flag grants nothing | That test |
| `FS-AH04` | Deltas closed before return | That test |
| `FS-AH05` | Share is a pool currency on the current single pricing hook | That test |
| `FS-AH06` | Exact-out hook calls fail closed | That test |
| `FS-AH07` | Identity-leg bind reverts on the current dual package | That negative test |
| `FS-AH08` | Fee, native, and rollback obligations hold while unlocked | Those assertions |
| `FS-HOOK-01` | Seven current hook families named; no package edit for buffered legs | `FS-AH01`, `FS-AH05` |
| `FS-HOOK-03` | Exact output is not solved by editing hooks | `FS-AH06` |
| `FS-HOOK-04` | Identity-leg support would be a separate hook-package change | `FS-AH07`; no hook diff in the change set |
| `FS-NG-01` | Non-goals | Absence in the package and the publication note |

### FS-NG-01 — Non-goals

- No Weir copy and no Weir fee or share-ledger import.
- No ERC-4626-only wrapper and no `asset()` compatibility shim.
- No second pool, no multi-pool router, no wings range management.
- No registry migration and no replacement of existing vaults.
- No deployment in this PRD.
- No claim that the PRD or a later implementation was audited.
- No hook-package edit.
- No exact-output implementation.
- No TWAP construction, no Chainlink, no peg, no manipulation-proof claim.
- No Balancer rate-provider facet on this diamond.
- No `viaIR`, no mock SUT, no etched PoolManager.

### Owner decisions still open

None that block facet, package, or test implementation.

Checked and closed from the sources, not left for a later requirements pass:

- Unlocked entry is a branch of the existing money methods, not a new selector.
- `getRate` is not installed. The executable one-share exit quote is the existing preview of `1e18` shares. The external hook rate provider stays external.
- Exact output stays a reverting installed surface.
- Identity-leg hook support is out of scope, not an open vault design choice.
- Zap `J_i` stays the inherited booked donation. A revert-if-`J_i`-nonzero rule is not adopted.

No owner question is posed here.

## 9. Limits and sources

### Limits

- This contribution did not run Forge, compute selectors, or deploy. Hex values are observations from current source comments, not a fresh computation.
- PairToken and Wings storage-slot constants were not read. `FS-ARCH-01` requires an inequality test rather than claiming those values.
- Hook init rejection was verified on the dual package and the shared `isWrapperShareInventory` helper, and on the single pricing package's `SameToken` / `vaultTokens` check. The other five families were read at their package interfaces. `FS-HOOK-01` does not claim they reject this share.
- `StandardExchangeRateProvider` full-book normalization was read far enough to keep it out of issuance. Its rounding tail was not copied into a vault formula on purpose.
- Optional reports were used only as boundary context: the adaptation report's recommendation is local full-range economics, not a Weir fork; the comparison report is not an economics authority. Weir's import PRD is a source copy, not this product.
- Skill entry files and the cited agent-law sections were read. Linked skill references beyond those entries were not reread in full. Nothing in this fragment depends on an unread reference for a numeric parameter.
- No peer response, feedback, draft, or resolution was read.
- The assigned route label is not a runtime attestation.
- A stricter "revert if zap `J_i != 0`" reading of owner decision 6 was considered and not adopted, because it would replace `S1-ACC-07`'s specified zap settlement. If the coordinator treats booked `J_i` as a stranded residual, that is a PRD conflict to resolve in advisory, not a silent second equation in implementation.
- This fragment does not authorize implementation.

### Sources

- Brief: `docs/research/fullspread-se-prd-20261030-01a18660/brief.md`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol` (unlocked reject and `unlock` call)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol` (library order)
- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, sections 1–12 as required for inherited IDs
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` (`getRate` not to copy)
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`
- `contracts/interfaces/IStandardVaultPkg.sol`
- `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol`
- Hook package interfaces named in `FS-HOOK-01`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol`
- `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol`
- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol`
- `contracts/test/libs/RateProviderFixtureLib.sol`
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`
- `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md` token policy and APEX D60, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md`
- `.agents/skills/crane-architecture/SKILL.md`, `.agents/skills/indexedex-testing/SKILL.md`, `.agents/skills/indexedex-uniswap-v4-hook-packages/SKILL.md`, `.agents/skills/indexedex-user-flows/SKILL.md`
- Optional boundary only: `docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md`, `docs/research/v4-vault-adaptation-20261029-01a18660/REPORT.md`, `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`
