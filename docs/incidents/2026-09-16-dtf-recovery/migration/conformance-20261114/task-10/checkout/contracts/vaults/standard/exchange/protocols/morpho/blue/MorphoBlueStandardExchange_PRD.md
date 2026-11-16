# PRD: Morpho Blue Standard Exchange Vault

**Date:** 2026-08-22
**Status:** Draft for implementation (product law for this package)
**Package path:** `contracts/vaults/standard/exchange/protocols/morpho/blue/`
**Crane Morpho port:** `lib/crane/contracts/protocols/lending/morpho/`
**Vendored Morpho Blue:** `lib/crane/contracts/external/morpho/blue/` (pin **v1.0.0**)

**Related:**
- Gold lending SE shape: `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md`
- Generic ERC-4626 SE (not sufficient alone): `contracts/vaults/standard/erc4626/`
- Rate provider (v1 smoke consumer): `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`
- Uni V4 Single SE Buffer CP hook (later consumer): `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md` (D4: any `IStandardExchange` with closed-form pairToken ↔ SE)
- Agent law: `docs/agent/INDEXEDEX_AGENT_LAW.md` (token policy, deploy path, role names)
- Network Morpho constants: `lib/crane/contracts/constants/networks/{ROBINHOOD_MAIN,ETHEREUM_MAIN,BASE_MAIN}.sol`
- Implementation plan: [`MorphoBlueStandardExchange_IMPLEMENTATION_AND_TEST_PLAN.md`](./MorphoBlueStandardExchange_IMPLEMENTATION_AND_TEST_PLAN.md)

This file is **internal product law** for the package. Do not treat it as public docs. Implement only from this PRD plus the sibling implementation-and-test plan.

---

## 1. Goal

Deliver a production-first **Standard Exchange (SE) vault** that **lends one ERC-20 on Morpho Blue** (isolated-market singleton):

1. User deposits the market **loan token** (`rateAsset`) into this SE.
2. The vault supplies that token to **one already-existing Morpho Blue market** (`IMorpho.supply`).
3. Morpho supply shares accrue interest on the market. SE share price vs the loan token rises.
4. User withdraws later: burn SE shares, receive loan token **principal plus earned Morpho interest** (net of IndexedEx usage fee if any, and Morpho market fee already in Blue accounting).
5. v1 ships a **Standard Exchange Rate Provider smoke**: deploy the existing rate-provider DFPkg against this SE (`rateTarget = loanToken`) and assert `getRate()` vs `previewExchangeIn` / `convertToAssets`. A later **Uni V4 Single SE Buffer Constant Product hook** can bind this vault as the SE leg (`pairToken` = loan token). Hook e2e is **not** this package.

This is **not** a generic ERC-4626 SE wrap of Morpho Vault V2 / MetaMorpho. Morpho Blue has **no ERC-20** for market supply shares. The IndexedEx diamond **is** the share token.

Robinhood Earn (Steakhouse USDG) is Morpho **Vault V2**. That wrap is a **second package** later, not this tree.

---

## 2. Locked product decisions

### 2.1 Identity

| # | Topic | Decision |
|---|--------|----------|
| D1 | Protocol | **Morpho Blue v1.0.0** isolated markets (`IMorpho`). Not Morpho V1 optimizer. Not MetaMorpho V1.1. Not Morpho Vault V2. Not Morpho Midnight. |
| D2 | Product name | **`MorphoBlueStandardExchange`** (full type/file names; no `MBSE` / `MorphoSE` types) |
| D3 | Package location | `contracts/vaults/standard/exchange/protocols/morpho/blue/` |
| D4 | Instance identity | **One Morpho market per vault.** Bound at deploy to `(morpho, MarketParams)`. No post-deploy rebind. |
| D5 | `MarketParams` | `(loanToken, collateralToken, oracle, irm, lltv)` is the Morpho market id. Lenders still supply **only** `loanToken`. `collateralToken` is market identity, not vault inventory. |
| D6 | Mode | **Supply / lend only.** No borrow, no `supplyCollateral`, no repay, no liquidate, no flash loan, no Morpho `setAuthorization` for third parties. |
| D7 | SE surface | **`IStandardExchangeIn` + `IStandardExchangeOut` only** (exact-in and exact-out). Plus `IERC20` / permit / `IERC4626` / `IBasicVault` / `IStandardVault`. |
| D8 | Share token | Diamond **is** the ERC-20 / ERC-4626 share (`address(this)`). |
| D9 | `IERC4626.asset()` | **`loanToken`** (Morpho market loan asset). This is the DETF/hook **`rateAsset`**. |
| D10 | Crane ops | `MorphoBlueService` + `MorphoBlueAwareRepo` + `MorphoBalancesLib`. Do not reimplement Blue math. Do not `new Morpho` except inside Crane hermetic TestBase. |
| D11 | Deploy | CREATE3 facets + **vault registry** DFPkg (`indexedexManager` / `IVaultRegistryDeployment.deployPkg`). Never `new` facets or the vault DFPkg. `PkgInit` / `PkgArgs` on the **interface**. |
| D12 | Crane vs IndexedEx | All new product code lives in IndexedEx under D3. Crane Morpho port is a dependency. No Crane edits required for v1 if Service/Aware/TestBase already cover supply/withdraw. |

### 2.2 Accounting

| # | Topic | Decision |
|---|--------|----------|
| D13 | NAV | `totalAssets` = **idle `loanToken` on the diamond** + **`MorphoBalancesLib.expectedSupplyAssets(morpho, marketParams, address(this))`**. Idle in v1 is **rounding dust and donations only** (D25). |
| D14 | Views | `totalAssets`, `convertToAssets` / `convertToShares`, and SE **previews** use **live** D13 NAV (accrued). Do not quote stale `ERC4626Repo._lastTotalAssets` as the rate. |
| D15 | Writes | Every money path that changes Morpho position or idle inventory **accrues via Morpho** (`supply` / `withdraw` already accrue) then **syncs** `ERC4626Repo._lastTotalAssets` to D13. |
| D16 | ERC4626 facet | **Do not cut stock `ERC4626Facet`.** Cut **`MorphoBlueERC4626Facet`** that extends `ERC4626Target` and **overrides** `totalAssets()` (and `maxWithdraw` / `maxRedeem` per D18). Same `IERC4626` selectors, Morpho-aware NAV. |
| D17 | Interest delivery | **Share-price rise only.** No user reward claim. Morpho market fee (if enabled on the market) is already in Blue share math. |
| D18 | Caps | `maxWithdraw` / `maxRedeem` are **conservative**: idle + Morpho **free liquidity** (`expectedTotalSupplyAssets - expectedTotalBorrowAssets`, capped by this vault's expected supply). Previews of **rate** still use full NAV (D14). |
| D19 | Full exit | Redeem-all / withdraw-all of the Morpho leg uses **shares mode** (`assets = 0`, `shares > 0`) so the position can close cleanly. Exact-out uses **assets mode**. |
| D20 | Decimal offset | **`0`**, matching generic ERC-4626 SE. First-depositor inflation is an **A0** test, not virtual-share policy in v1. |
| D21 | Share decimals | **18**. Scale non-18 `loanToken` amounts in 4626 math the same way Crane `ERC4626Repo` already does (`reserveAssetDecimals`). |
| D22 | Donation | Idle `loanToken` transfer-in and Morpho `supply` **onBehalf of this vault** increase NAV for **existing** shareholders (K1). They **must not** mint free shares to the next depositor (I1 / A0). Credit inbound with **reserve-delta**, never absolute `balanceOf`. |

### 2.3 Liquidity (no sleeve in v1)

| # | Topic | Decision |
|---|--------|----------|
| D23 | Morpho utilization | Withdraw from Blue **reverts** when market cash is insufficient. Same class as Aave supply. Not async (unlike Lido). |
| D24 | Pay path | **Idle `loanToken` first** (dust / donations), then `Morpho.withdraw`. If still short: revert `InsufficientLiquidity(requested, available)` (one named error; do not invent a second). |
| D25 | Liquid sleeve | **Out of v1.** No `liquidReservePercentage` policy, no target idle band, no `rebalance()`. Adding a sleeve is a **PRD revision**, not a silent v1 flag. |
| D26 | Inflow supply | After mint, **supply the full measured inbound** (minus Blue/share rounding) to Morpho. If `Morpho.supply` reverts, **the whole deposit reverts**. Do not leave user deposits idle "to be helpful." |
| D27 | Preview vs liquidity | Rate / `convertToAssets` / `previewExchangeIn(SE → loanToken)` use **full NAV**. Execute may still revert on D24. `maxWithdraw` is the honest UX / hook cap (D18). |
| D28 | Market existence | **Bind existing markets only.** If `morpho.market(id).lastUpdate == 0`, `initAccount` **reverts**. The vault never `createMarket`. Hermetic TestBase creates the market **before** `deployVault`. |

### 2.4 Fees, rewards, tokens

| # | Topic | Decision |
|---|--------|----------|
| D29 | Usage fee | Marker interface id is the **LENDING** vault fee type key (`VaultFeeType.LENDING` + `type(IMorphoBlueStandardExchange).interfaceId`). Fee shares minted to `feeTo()` on SE-share **mint** (Stata inflation pattern). |
| D30 | Usage fee default | **0** for this type in production / TestBase unless a spec explicitly sets non-zero. Tests must cover both 0 and non-zero. |
| D31 | External rewards | **Out of scope.** No Morpho URD / Merkl / MORPHO harvest in v1. Extra ERC-20s sitting on the diamond are **not** in `totalAssets`. |
| D32 | Token policy | **LOCKED** agent law: FoT forbidden; rebasing **underlying** forbidden; non-18 decimals allowed; pause/blacklist accepted; no `PkgArgs` allowlist. `test_L2_FoT_forbidden` with a real FoT as the **configured loan token**. |
| D33 | Native ETH | **Forbidden** on the SE surface. WETH is a normal ERC-20 if it is the market `loanToken`. |

### 2.5 Composition (consumers of this vault)

| # | Topic | Decision |
|---|--------|----------|
| D34 | Rate provider | **In v1 DoD.** Deploy existing **`StandardExchangeRateProvider`** against a live instance: `reserveVault = this SE`, `rateSubject = address(this)`, `rateTarget = loanToken`. Assert `getRate()` vs `previewExchangeIn` / `convertToAssets` (empty supply → `0`, as the provider already does). Do **not** fork rate-provider code. |
| D35 | Uni V4 SE buffer hook | **Out of Morpho package v1 DoD** (rate-provider smoke still closes this package). Later consumer: unified DETF × hook matrix binds this vault as a hook pair leg (`pairToken` **must** be `loanToken` and ∈ `vaultTokens()`). Instant unwrap inherits D23 (utilization revert) until a sleeve revision. Closed-form **pairToken ↔ SE** is D7 + D27. Test PRD: [`UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md`](../../../../../detf/UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md). |
| D36 | DETF opacity | Production DETF/hook code talks only to `IStandardExchange*` / share ERC-20. Do **not** import Morpho types into DETF/hook sources. |
| D37 | Vault V2 wrap | **Follow-on package** under `…/morpho/vault-v2/` (or generic ERC-4626 SE). Not this PRD. |

### 2.6 Clarifications locked 2026-08-22 (design Q&A)

| Topic | Choice |
|-------|--------|
| Blue vs Vault V2 | **Blue now.** Vault V2 / Steakhouse wrap is a second package. |
| v1 done | Standalone lend/withdraw **plus rate-provider smoke**. No Uni V4 hook e2e. |
| Liquid sleeve | **None in v1.** Full supply on deposit. Sleeve needs a later PRD change. |
| Missing market | **Revert.** Never `createMarket` from this vault. |
| Utilized unwrap quotes | **Full-NAV preview**, **conservative `maxWithdraw`**. |
| Fork targets | **Robinhood Chain 4663 and Ethereum and Base.** |

---

## 3. Why a dedicated package

| Approach | Why not for this product |
|----------|--------------------------|
| Generic `ERC4626StandardExchange` | Wraps an **IERC4626 protocol vault**. Morpho Blue supply shares are **not** an ERC-20. |
| Wrap Morpho **Vault V2** / MetaMorpho | Valid **other** product (Steakhouse USDG on Robinhood is Vault V2). Wrong tree. D37. |
| Aave Stata SE copy | Stata **is** an ERC-4626 the vault can hold. Morpho Blue is not. NAV must read Blue share accounting (`expectedSupplyAssets`). |
| Borrow / loop vault | Separate package. Blue borrow needs collateral, health, liquidation. Out of D6. |
| Staking SE sleeve (Rocket / Lido) | Those protocols need a cash buffer for exit. v1 Morpho Blue **always supplies** (D25–D26). |

---

## 4. Token roles and reserve model

Use DETF/SE **role names**, never product brands.

| Role | Token | Notes |
|------|--------|------|
| `rateAsset` / `IERC4626.asset()` / Morpho `loanToken` | Bound market loan ERC-20 | User deposit and withdraw unit |
| Morpho `collateralToken` | Market identity only | Not held, not in `vaultTokens()` |
| SE share | `address(this)` | Exchange routes; 18 decimals |
| Idle `loanToken` | Rounding dust / donations | Not a policy sleeve (D25) |
| Locked yield | Morpho supply shares of this vault on the bound `Id` | Not an ERC-20 |

**`IBasicVault.vaultTokens()` (v1):**

```text
[0] loanToken
```

Do not list Morpho, IRM, oracle, or collateral. `IStandardVault.vaultConfig.tokens` matches.

---

## 5. Route matrix (normative)

Every listed pair is supported on **both** `IStandardExchangeIn` (exact-in) and `IStandardExchangeOut` (exact-out). Unsupported pairs revert `UnsupportedRoute` / `InvalidRoute` (match peer selector).

| tokenIn | tokenOut | Behavior |
|---------|----------|----------|
| `loanToken` | SE share | Pull loan token (delta / Permit2 / pretransfer); mint shares on D13 NAV; apply D29; **then D26 supply (whole tx reverts if supply fails)** |
| SE share | `loanToken` | Burn shares; pay loan token via D24; sync D15 |
| `loanToken` | `loanToken` | **Forbidden** (not a DEX) |
| SE share | SE share | **Forbidden** |
| Anything else | Anything else | Unsupported |

Permit2, deadline, and `pretransferred` match peer SEs (`BasicVaultCommon` reserve-delta). `pretransferred=true` without a measured inbound delta **must not** mint (I1).

ERC-4626 `deposit` / `mint` / `withdraw` / `redeem` are the same economic paths as loanToken ↔ SE (exact-in deposit / exact-out withdraw). They must hit the same Common helpers so preview/execute cannot diverge by entrypoint.

---

## 6. Morpho Blue constraints (normative)

1. **Singleton:** `IMorpho` at deploy-time `PkgArgs.morpho`.
   - Robinhood: `ROBINHOOD_MAIN.MORPHO` = `0x9D53d5E3bd5E8d4Cbfa6DB1ca238AEA02E651010`
   - Ethereum / Base: `ETHEREUM_MAIN.MORPHO` / `BASE_MAIN.MORPHO` = `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`
2. **Market must already exist:** `initAccount` reverts unless `morpho.market(id).lastUpdate != 0` (D28). IRM and LLTV were enabled when someone else created the market; this vault does not enable them.
3. **Assets XOR shares:** Blue requires exactly one of `assets`/`shares` non-zero. Follow D19.
4. **`onBehalf`:** Always `address(this)`. Never supply/withdraw onBehalf of the user.
5. **Callbacks:** Pass `data = ""`. Do not implement Morpho supply callbacks.
6. **Authorization:** Do not `setAuthorization`. The vault is the only operator of its position.
7. **Fee recipient warning:** `expectedSupplyAssets` is wrong for Morpho `feeRecipient`. This vault **must not** be the market fee recipient.
8. **Oracle / IRM:** Bound in `MarketParams`. Vault does not set prices. Pause / blacklist of `loanToken` is accepted risk (token policy).
9. **Interest:** `accrueInterest` runs inside Blue supply/withdraw. Views use `MorphoBalancesLib` so rate providers see accrual between vault txs.

---

## 7. Architecture

### 7.1 Layers

| Piece | Role |
|-------|------|
| `IMorphoBlueStandardExchange` | Marker: `morpho()`, `marketParams()`, `marketId()`, `loanToken()`. Interface id = fee type key (D29). **No** `rebalance()`. |
| `IMorphoBlueStandardExchangeDFPkg` | `PkgInit` / `PkgArgs` **on the interface**. `deployVault(PkgArgs)` → registry. |
| `MorphoBlueStandardExchangeRepo` | Bound `MarketParams` + `Id`. Slot: `indexedex.vaults.standard.exchange.protocols.morpho.blue`. |
| Crane `MorphoBlueAwareRepo` | Morpho singleton. |
| `MorphoBlueStandardExchangeCommon` | NAV (D13), share mint/burn vs NAV, fee inflation, idle-first withdraw, **hard** supply of inbound (D26). |
| `MorphoBlueERC4626Target` / `Facet` | IERC4626 with Morpho `totalAssets` override (D16). |
| In / Out Target + Facet | Full `IStandardExchangeIn` / `Out`. |
| Marker Target + Facet | Marker getters only. |
| `MorphoBlue_Component_FactoryService` | CREATE3 facets + `deployPkg` via registry. |

Reuse: ERC20 + EIP-712 + permit facets, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet`, `VaultFeeOracleQueryAwareRepo`, `Permit2AwareRepo`, `ReentrancyLockModifiers`. **Do not** cut `ERC4626StandardVaultFacet` if `MultiAssetStandardVaultFacet` already owns `IStandardVault` (generic ERC-4626 SE pattern).

### 7.2 `PkgInit` (sketch)

Core facets (ERC20, ERC5267, ERC2612, MorphoBlue ERC4626, MultiAsset Basic + Standard, In, Out, Marker) + `vaultFeeOracleQuery` + `vaultRegistryDeployment` + `permit2`.

Morpho address is **per instance** (`PkgArgs`), not an immutable on the package, so one DFPkg can deploy vaults on hermetic Morpho and on Robinhood / Ethereum / Base Morpho.

### 7.3 `PkgArgs` (sketch)

```solidity
struct PkgArgs {
    IMorpho morpho;
    MarketParams marketParams; // loanToken, collateralToken, oracle, irm, lltv
    string name;               // empty → derive "IndexedEx SE Morpho {loanSymbol}"
    string symbol;             // empty → derive "ixm{loanSymbol}"
}
```

`processArgs` / `calcSalt` hash `morpho` + encoded `MarketParams` (not package/facet addresses). Reject zero `morpho`, zero `loanToken`, zero `oracle`, zero `irm`. `collateralToken` may be non-zero (normal Blue market); it is still not held.

### 7.4 `initAccount`

1. Decode `PkgArgs`. Bind `MorphoBlueAwareRepo` + market repo.
2. `ERC20Repo._initialize(name, symbol, 18)`; `EIP712Repo._initialize(name, "1")`.
3. `ERC4626Repo._initialize(loanToken, loanDecimals, 0)`; `lastTotalAssets = 0`.
4. `MultiAssetBasicVaultRepo._initialize([loanToken])`.
5. StandardVault + fee oracle + Permit2.
6. **Require existing market** (D28). Do not `createMarket`.
7. Do **not** seed shares. First deposit is user-driven (A0 tests).

Instances are **unowned / no diamondCut** after `postDeploy`, matching other SE diamonds.

---

## 8. User flows

### 8.1 Deposit

```text
user --loanToken--> SE
SE mints shares = convertToShares(measuredIn)   // D13 NAV before credit, then sync
SE mints fee shares to feeTo if usageFee > 0     // D29
SE supplies measured inbound to Morpho            // D26; whole tx reverts on supply fail
```

### 8.2 Withdraw

```text
user burns SE shares
assetsOut = convertToAssets(shares)              // D13 full NAV
pay from idle dust, then Morpho.withdraw         // D24
revert if still short                            // InsufficientLiquidity
sync lastTotalAssets
```

Callers that must not revert under utilization should read **`maxWithdraw`** first (D18). Rate still uses full NAV.

Round-trip after time (borrowers paying interest): `assetsOut > assetsIn` for the same shares, within Morpho share rounding.

### 8.3 Rate provider (v1 smoke)

1. Deploy this SE on a funded Morpho market (hermetic: TestBase creates market, then `deployVault`).
2. Deposit so `totalSupply > 0`.
3. Deploy `StandardExchangeRateProvider` with `rateTarget = loanToken`.
4. Assert `getRate()` matches `previewExchangeIn(quoteShares, loanToken)` scaled the same way the provider already scales (1e18 share quote when supply allows).
5. Warp + accrue borrower interest; `getRate()` rises with `convertToAssets`.

Empty vault: `getRate() == 0` (existing provider).

---

## 9. Testing (ship gate)

Production-first. Inherit `IndexedexTest` → `TestBase_VaultComponents` → **`TestBase_MorphoBlueStandardExchange`**. Morpho SUT is Crane **`TestBase_MorphoBlue`** (hermetic `new Morpho` + AdaptiveCurveIRM) or fork bind. **Never** mock Morpho, this vault, manager, registry, fee oracle, or the rate-provider SUT.

### 9.1 Gold TestBase

- Facets via `MorphoBlue_Component_FactoryService` + CREATE3.
- DFPkg: `vm.prank(owner); indexedexManager.deployPkg` / FactoryService helper (same pattern as `deployAaveV3StataStandardExchangeDFPkg`).
- **Create the Blue market first**, then `pkg.deployVault(args)` (D28).
- Negative: `deployVault` with a never-created `MarketParams` reverts.
- Fund suppliers/borrowers with mintable ERC-20s (non-SUT). Optionally borrow against collateral so utilization and interest are real.

### 9.2 Hermetic specs (required)

| Area | Assert |
|------|--------|
| Deploy | Registry path; `asset() == loanToken`; `marketParams` round-trip; `vaultTokens == [loanToken]`; missing market reverts |
| Deposit / withdraw | Measured in; shares; Morpho `expectedSupplyAssets` rises; idle ~ rounding; withdraw returns principal |
| Interest | Warp + borrower interest → redeem `> deposit` (exact delta vs Blue expected, not "balance increased") |
| Preview / execute | Parity on In/Out and ERC-4626 entrypoints |
| Rate provider smoke | D34: `getRate()` vs preview / `convertToAssets`; rises after interest |
| Utilization | Borrow to cap cash; `maxWithdraw` shrinks; unwrap reverts `InsufficientLiquidity`; **deposit still works** (Morpho still accepts supply) |
| Supply fail | If Morpho supply cannot complete, deposit/exchangeIn **reverts** (D26); no leftover user credit as idle |
| Fee 0 / fee > 0 | D29 / D30 |
| J1–J3 | Target API ⊆ `facetFuncs` ⊆ cuts ⊆ proxy loupe; smoke on **proxy** |
| I1–I3 | `pretransferred` free-mint negatives |
| A0 / K1 | Donate loanToken or Morpho-supply-onBehalf before first mint; first depositor does not steal |
| E1 / E5 / E6 | Round-trip; ZeroAmount / deadline; no fat-max refund of booked idle |
| L2 | FoT as configured `loanToken` forbidden |
| CROPS | After `setVaultAddressDisabled(true)`, `exchangeOut` / redeem still work |
| O* | Permit2 / permit paths if exposed |
| Fuzz | Conservation: idle + Morpho expected = NAV; shares * price ≈ NAV |

### 9.3 Fork (required for ship, profile `fork`)

Three binds. Each: `code.length > 0` on Morpho, `deployVault` against a **live existing** market with free cash at the pin, supply / withdraw, no Vault V2 wrap.

| Chain | Morpho constant |
|-------|-----------------|
| Robinhood 4663 | `ROBINHOOD_MAIN.MORPHO` |
| Ethereum | `ETHEREUM_MAIN.MORPHO` |
| Base | `BASE_MAIN.MORPHO` |

Pick markets with free liquidity at the fork pin. Document the `MarketParams` / `Id` in the fork TestBase.

### 9.4 Out of this package's DoD

- Uni V4 hook buffer e2e (D35).
- Liquid sleeve / `rebalance()` / fee-oracle idle target (D25).
- Morpho Vault V2 / MetaMorpho / Midnight (D37).
- Changing `StandardExchangeRateProvider` source (smoke-only consumer).

---

## 10. File map (implementation)

```text
contracts/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_PRD.md                 # this file
  IMorphoBlueStandardExchange.sol
  IMorphoBlueStandardExchangeDFPkg.sol
  MorphoBlueStandardExchangeRepo.sol
  MorphoBlueStandardExchangeCommon.sol
  MorphoBlueERC4626Target.sol
  MorphoBlueERC4626Facet.sol
  MorphoBlueStandardExchangeInTarget.sol
  MorphoBlueStandardExchangeInFacet.sol
  MorphoBlueStandardExchangeOutTarget.sol
  MorphoBlueStandardExchangeOutFacet.sol
  MorphoBlueStandardExchangeMarkerTarget.sol
  MorphoBlueStandardExchangeMarkerFacet.sol
  MorphoBlueStandardExchangeDFPkg.sol
  MorphoBlue_Component_FactoryService.sol
  test/bases/TestBase_MorphoBlueStandardExchange.sol

test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_Deploy.t.sol
  MorphoBlueStandardExchange_Routes.t.sol
  MorphoBlueStandardExchange_Interest.t.sol
  MorphoBlueStandardExchange_Liquidity.t.sol
  MorphoBlueStandardExchange_RateProvider.t.sol
  adversarial/...

test/foundry/fork/robinhood_main/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_RobinhoodFork.t.sol
test/foundry/fork/ethereum_main/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_EthereumFork.t.sol
test/foundry/fork/base_main/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_BaseFork.t.sol
```

---

## 11. Non-goals (v1)

- Borrowing, collateral, liquidation, Morpho public allocator, Bundler3 UX inside the diamond.
- Wrapping Morpho Vault V2 / MetaMorpho (D37).
- Harvesting MORPHO / Merkl / URD rewards.
- Multi-market allocation in one vault.
- Liquid sleeve, `rebalance()`, or `liquidReservePercentage` wiring.
- `createMarket` from this vault.
- Native ETH routes.
- Uni V4 hook package work.
- Editing `StandardExchangeRateProvider` (smoke deploy only).
- `via_ir`.
- Package-specific Foundry profiles (hermetic = default; fork = `FOUNDRY_PROFILE=fork`). Crane `morpho_port` only if compiling Morpho domain in isolation.

---

## 12. Follow-on (not this PRD's implementation)

1. **Sleeve revision** if Uni V4 buffer unwraps need cash under high Morpho utilization.
2. **Hook composition:** this SE + rate provider + Uni V4 Single SE Buffer CP hook with `pairToken = loanToken`.
3. **Vault V2 / Steakhouse wrap** as a separate package under `…/morpho/vault-v2/` (or generic ERC-4626 SE).
4. Coding stages live in [`MorphoBlueStandardExchange_IMPLEMENTATION_AND_TEST_PLAN.md`](./MorphoBlueStandardExchange_IMPLEMENTATION_AND_TEST_PLAN.md).
