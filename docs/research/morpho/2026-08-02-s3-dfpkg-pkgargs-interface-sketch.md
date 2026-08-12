# S3 DFPkg Interface Sketch: `PkgInit` / `PkgArgs` / Deploy Validation

**Date:** 2026-08-02  
**Status:** Design sketch (pre-PRD) — package surface only; not implementation  
**Strategy:** S3 Morpho Blue borrow → Uni V4 Standard Exchange LP  
**Package kind:** IndexedEx **vault DFPkg** via manager vault registry (`IStandardVaultPkg` + `IDiamondFactoryPackage`)

**Peers (copy patterns, do not invent):**

| Peer | Path | Steal |
|------|------|--------|
| ERC-4626 SE | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol` | Minimal `PkgArgs`; `deployVault` early check; registry path |
| Uni V4 SE | `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` | Protocol singleton in `PkgInit` (`poolManager`); instance bind in `PkgArgs` |
| Aave cross-version loop | `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol` | **Validate user args against package-held protocol** before `deployVault` |

**Related:**

- Design surfaces: [`2026-08-02-s3-borrow-to-lp-design-surfaces.md`](./2026-08-02-s3-borrow-to-lp-design-surfaces.md)  
- Process research T1: [`2026-08-02-lending-cl-mm-protocol-process-research.md`](./2026-08-02-lending-cl-mm-protocol-process-research.md)  

**Crane rules:** `PkgInit` / `PkgArgs` on the **interface**, not the contract body only. Never `new` facets/DFPkg. Vault instance via `VAULT_REGISTRY_DEPLOYMENT.deployVault(SELF, abi.encode(args))`.

---

## 1. Deployment model (package vs instance)

```text
┌─────────────────────────────────────────────────────────────────┐
│  PkgInit (constructor — once per chain / env package deploy)    │
│  • Facets (CREATE3 already deployed)                            │
│  • vaultRegistryDeployment, vaultFeeOracleQuery, permit2        │
│  • IMorpho morpho  (chain Morpho Blue singleton)                │
│  • (optional) IPoolManager only if strategy talks to PM directly│
│    — v1 recommended: NO; strategy talks to Uni V4 SE only       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │  user / integrator
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  deployVault(PkgArgs-derived args)                              │
│  1. Validate PkgArgs against Morpho + SE on-chain state         │
│  2. registry.deployVault(SELF, abi.encode(PkgArgs))             │
│  3. processArgs (registry-only)                                 │
│  4. initAccount: wire Morpho market + SE + policy into repos    │
└─────────────────────────────────────────────────────────────────┘
```

**Users choose markets and SE instances.** The package only defines:

1. What fields belong in `PkgInit` vs `PkgArgs`  
2. When a configuration is **accepted** (validation)  
3. How accepted args are **stored** (`initAccount`)

No hard-coded coll/loan symbols. Robinhood vs Base vs ETH = different `PkgInit.morpho` (and facets/registry) + different user `PkgArgs`.

---

## 2. Proposed interface (normative sketch)

Names are provisional (`MorphoUniswapV4LeveredLp` TBD). Structs and validation law are the design product of this note.

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IMorpho, MarketParams, Id} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
// MarketParams: loanToken, collateralToken, oracle, irm, lltv

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardExchange} from "/* peer SE surface — vaultTokens / exchangeIn-Out */";

/**
 * @title IMorphoUniswapV4LeveredLpDFPkg
 * @notice Vault DFPkg: Morpho Blue coll+borrow + Uni V4 SE LP inventory (S3).
 * @dev PkgInit / PkgArgs LIVE ON THIS INTERFACE (Crane rule).
 */
interface IMorphoUniswapV4LeveredLpDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    // ─── Errors (deploy / processArgs / initAccount) ───────────────────────

    error NotCalledByRegistry(address caller);

    error ZeroMorpho();
    error ZeroUniV4Se();
    error ZeroAddress();
    error ZeroLltv();
    error InvalidMarketParams();
    error CollEqualsLoan();
    error MarketNotCreated(Id id);
    error IrmNotEnabled(address irm);
    error LltvNotEnabled(uint256 lltv);
    error OracleZero();

    error SeNotContract(address se);
    error SeMissingVaultTokens();
    /// @dev v1 capital-path family: both Morpho coll and loan must appear in SE.vaultTokens().
    error MarketNotCompatibleWithSe(address coll, address loan, address se);
    error LoanNotInSeVaultTokens(address loan, address se);
    error CollNotInSeVaultTokens(address coll, address se);

    error MaxLtvNotBelowLltv(uint256 maxLtvWad, uint256 lltv);
    error TargetLtvAboveMax(uint256 targetLtvWad, uint256 maxLtvWad);
    error InvalidHfBounds(uint256 minStrategyHfWad, uint256 liquidationStrategyHfWad);
    error InvalidPolicy();

    // ─── PkgInit: package constructor (chain / env wiring) ──────────────────

    /**
     * @notice Immutable package wiring. Deployed once per chain (or env) with local Morpho + registry.
     * @dev Facet addresses are CREATE3-deployed before package deploy (peer SE / Aave loop).
     *      Morpho is the Blue singleton for this chain — NOT a per-vault choice.
     *      Uni V4 PoolManager is NOT required in v1 Init if the strategy only calls the SE.
     */
    struct PkgInit {
        // Facets (illustrative set — finalize with facet inventory later)
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet strategyFacet;           // S3 open/close/delever/liquidate surface
        IFacet strategyQueryFacet;      // NAV / HF / previews
        IFacet markerFacet;             // optional package marker interface

        // IndexedEx infra (peers)
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;

        // Protocol singleton for this package deployment
        IMorpho morpho;
    }

    // ─── PkgArgs: per vault instance (user-chosen market + SE + policy) ─────

    /**
     * @notice Per-instance configuration. User selects any Morpho market + Uni V4 SE that pass validation.
     * @dev LTV / HF fields in WAD (1e18 = 100%). Morpho LLTV is also WAD-scale on Blue.
     */
    struct PkgArgs {
        /// @dev Full Blue market key. Tokens/oracle/irm/lltv come from here — package does not pick them.
        MarketParams market;
        /// @dev Existing Uni V4 Standard Exchange vault (diamond). Not the PoolManager; not PoolKey alone.
        address uniV4Se;
        /// @dev Target Morpho LTV after open (debt / coll value), WAD. Must be < maxLtvWad.
        uint256 targetLtvWad;
        /// @dev Hard cap for Morpho LTV on open / leverageUp. Must be < market.lltv.
        uint256 maxLtvWad;
        /// @dev Min strategy equity health (product plane). Below this, withdraw/open restricted.
        uint256 minStrategyHfWad;
        /// @dev Strategy liquidate threshold (equity plane). Typically ≤ minStrategyHfWad.
        uint256 liquidationStrategyHfWad;
    }

    /**
     * @notice Deploy a strategy vault instance for a user-chosen Morpho market + Uni V4 SE.
     * @dev Validates, then registry.deployVault(SELF, abi.encode(PkgArgs)).
     */
    function deployVault(PkgArgs calldata args) external returns (address vault);
}
```

---

## 3. `PkgInit` vs `PkgArgs` decision table

| Field | Layer | Rationale |
|-------|--------|-----------|
| Facets | **Init** | Same for all instances of this package on this chain |
| `vaultRegistryDeployment` | **Init** | IndexedEx vault path (peer) |
| `vaultFeeOracleQuery` | **Init** | Peer SE |
| `permit2` | **Init** | Peer SE |
| `morpho` (IMorpho) | **Init** | One Blue per chain; like Aave loop pinning `V36_POOL` / Uni SE pinning `POOL_MANAGER` |
| `MarketParams` | **Args** | User-chosen market — package stays market-agnostic |
| `uniV4Se` | **Args** | User-chosen SE instance for a pool — like ERC4626 `protocolVault` |
| LTV / HF policy | **Args** | Per-instance risk appetite; must still satisfy market.lltv |
| Uni V4 `PoolKey` | **Not in strategy Args (v1)** | Read from SE if needed; user deploys SE via Uni V4 SE DFPkg first |
| `IPoolManager` | **Not in Init (v1)** | Strategy holds SE shares; SE already bound to PM |

### 3.1 Why Morpho in Init, market in Args

- **Init:** chain identity of Morpho Blue (RH / Base / ETH addresses differ).  
- **Args:** which isolated market on that Morpho (`loan`, `coll`, `oracle`, `irm`, `lltv`).  
- Matches: protocol singleton immutable + instance bind (Uni V4 SE: PM in Init, `poolKey` in Args).

### 3.2 Why SE address in Args, not PoolKey

- S3 inventory is **SE shares**, not a raw V4 position owned by the strategy.  
- User deploys (or reuses) Uni V4 SE via existing `UniswapV4StandardExchangeDFPkg.deployVault(poolKey, widthMultiplier)`.  
- Strategy DFPkg only accepts a compatible SE — composition of two packages, not one mega-package.  
- Alternative (later): helper that deploys SE then strategy in one script; still two DFPkg calls under the hood.

---

## 4. Acceptance law (when we accept the configuration)

All checks run in **`deployVault`** (and re-checked in `initAccount` if needed). Pattern: **AaveCrossVersionLoopDFPkg.deployVault** + **`_validatePairUsable`**.

### 4.1 Structural (`PkgArgs` only)

| ID | Predicate | Error |
|----|-----------|--------|
| V1 | `uniV4Se != 0` | `ZeroUniV4Se` |
| V2 | `market.loanToken`, `collateralToken`, `oracle`, `irm` all non-zero | `InvalidMarketParams` / `ZeroAddress` / `OracleZero` |
| V3 | `market.collateralToken != market.loanToken` | `CollEqualsLoan` |
| V4 | `market.lltv != 0` | `ZeroLltv` |
| V5 | `maxLtvWad > 0 && maxLtvWad < market.lltv` | `MaxLtvNotBelowLltv` |
| V6 | `targetLtvWad > 0 && targetLtvWad <= maxLtvWad` | `TargetLtvAboveMax` |
| V7 | `liquidationStrategyHfWad > 0 && minStrategyHfWad >= liquidationStrategyHfWad` | `InvalidHfBounds` |
| V8 | HF / LTV scales consistent (document: all WAD) | `InvalidPolicy` |

### 4.2 Morpho (Init.morpho + Args.market)

| ID | Predicate | Error |
|----|-----------|--------|
| M1 | `address(MORPHO) != 0` (constructor) | `ZeroMorpho` |
| M2 | `MORPHO.isIrmEnabled(market.irm)` | `IrmNotEnabled` |
| M3 | `MORPHO.isLltvEnabled(market.lltv)` | `LltvNotEnabled` |
| M4 | Market created: `MORPHO.market(id).lastUpdate != 0` (or peer Morpho existence check) | `MarketNotCreated` |
| M5 | Optional: oracle contract has code | `OracleZero` / custom |

**Do not** require a specific coll/loan symbol. Any enabled market on this Morpho that passes SE compatibility is fine.

**Note:** Exact “market exists” check should match Crane `MorphoBlueService` / IMorpho views used elsewhere in the monorepo (use the same helper as Morpho tests).

### 4.3 Uni V4 SE (Args.uniV4Se)

| ID | Predicate | Error |
|----|-----------|--------|
| S1 | `uniV4Se.code.length > 0` | `SeNotContract` |
| S2 | SE exposes vault token list (e.g. `vaultTokens()` / multi-asset surface) non-empty | `SeMissingVaultTokens` |
| S3 | **v1 capital-path family (see §5)** | `MarketNotCompatibleWithSe` / token-specific errors |

Optional later: interface-id / marker that address is Uni V4 SE (not arbitrary multi-asset vault). v1 may use behavioral checks only (vaultTokens + exchange routes).

### 4.4 Registry / processArgs

| ID | Predicate | Error |
|----|-----------|--------|
| R1 | `processArgs`: `msg.sender == VAULT_REGISTRY_DEPLOYMENT` | `NotCalledByRegistry` (Uni V4 SE peer) |

---

## 5. Capital-path family (v1 compatibility)

This is package law, still **not** token picks: which **relationship** between `market` and `SE.vaultTokens()` is allowed.

### 5.1 Family A (recommended v1 — strict)

```text
Let T = set(SE.vaultTokens())  // for Uni V4 SE: pool currency0, currency1

ACCEPT iff
  market.collateralToken ∈ T  AND  market.loanToken ∈ T
```

**Meaning:** Morpho coll and borrow asset are exactly the two (or among the) SE pool legs. Open path:

```text
post coll on Morpho → borrow loan → SE zap/mint using coll residual + loan
```

(Exact zap routes still designed in strategy Target; deploy only guarantees tokens are on the SE.)

### 5.2 Families deferred (not v1 accept)

| Family | Idea | Why defer |
|--------|------|-----------|
| B | Coll ∉ pool; only loan ∈ pool | Needs external coll mark + swap path design |
| C | Loan ∉ pool | Borrow asset cannot enter SE without extra venue |
| D | SE wraps something else | Out of S3 |

**First PRD lock:** Family A only. Expanding families is a PRD revision + new validation branches.

### 5.3 Pseudocode

```solidity
function _validateMarketCompatibleWithSe(MarketParams memory m, address se) internal view {
    address[] memory tokens = IStandardVault(se).vaultTokens(); // peer surface name TBD
    if (tokens.length == 0) revert SeMissingVaultTokens();

    bool collOk;
    bool loanOk;
    for (uint256 i; i < tokens.length; ++i) {
        if (tokens[i] == m.collateralToken) collOk = true;
        if (tokens[i] == m.loanToken) loanOk = true;
    }
    if (!collOk) revert CollNotInSeVaultTokens(m.collateralToken, se);
    if (!loanOk) revert LoanNotInSeVaultTokens(m.loanToken, se);
}
```

---

## 6. `deployVault` flow (package contract)

```solidity
function deployVault(PkgArgs calldata args) external returns (address vault) {
    _validateArgs(args); // §4 + §5
    vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
        IMorphoUniswapV4LeveredLpDFPkg(address(this)),
        abi.encode(args)
    );
}

function _validateArgs(PkgArgs calldata args) internal view {
    // V1–V8 structural
    // M2–M5 Morpho (use immutable MORPHO from Init)
    // S1–S3 SE + Family A
}

function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
    if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
        revert NotCalledByRegistry(msg.sender);
    }
    // Optional: re-validate (defense in depth) then return pkgArgs or normalized encoding
    return pkgArgs;
}

function calcSalt(bytes memory pkgArgs) public pure returns (bytes32) {
    // Peer: hash of encoded args so same market+SE+policy → same salt
    return keccak256(pkgArgs); // or BetterEfficientHashLib style used by Uni V4 SE
}

function initAccount(bytes memory initArgs) public {
    PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
    // Optional: _validateArgs(args) again

    // Wire repos (names TBD):
    // MorphoAwareRepo / MarketParamsRepo ← MORPHO + args.market
    // UniV4SeAwareRepo ← args.uniV4Se
    // LeveredLpPolicyRepo ← target/max LTV, HF bounds
    // ERC20 share token name/symbol from coll/loan symbols
    // MultiAssetBasicVaultRepo vaultTokens: at least [coll, loan, uniV4Se] or product-defined set
    // StandardVaultRepo + fee oracle + permit2 (peer SE)
    // Approvals: coll/loan → Morpho; coll/loan → SE as required by routes
}
```

### 6.1 Typed FactoryService helper (later implement)

```solidity
// MorphoUniswapV4LeveredLp_FactoryService (library on manager / create3 patterns)
// deployPkg(PkgInit) via registry path for vault DFPkg
// deployVault(pkg, PkgArgs) → pkg.deployVault(args)
```

Follow IndexedEx vault package path: **registry for DFPkg**, not bare diamond factory for the registered vault package.

---

## 7. Multi-chain reuse

| What changes per chain | Where |
|------------------------|--------|
| Morpho Blue address | **PkgInit.morpho** when deploying the package on that chain |
| Facets / registry / fee oracle / permit2 | **PkgInit** |
| User’s market (WETH/USDC vs USDG/… whatever exists) | **PkgArgs.market** at instance deploy |
| User’s Uni V4 SE | **PkgArgs.uniV4Se** |
| Instance risk policy | **PkgArgs** LTV/HF fields |

Same package **source**; chain-specific **Init** at package deploy; **no** RH-only coll/loan constants inside the DFPkg.

Robinhood is a **target env** for Init wiring + fork tests, not a fixed market menu.

---

## 8. Explicit non-goals on this surface

| Non-goal | Notes |
|----------|--------|
| Curated market list in package | Users pass any compatible market |
| Deploy Uni V4 SE inside this DFPkg | Separate Uni V4 SE DFPkg; pass SE address |
| Morpho Vault V2 / MetaMorpho as coll market | S3 is **Blue** coll+borrow; V2 wrap is S0 |
| SE shares as Morpho coll | S4 |
| PoolManager / PoolKey in strategy PkgArgs v1 | SE encapsulates pool |
| Picking fee type / facet inventory | Separate design pass after this surface locks |
| NAV formula / open-close bytecode | Strategy Target design; assumes accepted binding |

---

## 9. Open decisions (narrow)

Still to lock before coding the interface file:

| # | Question | Recommendation |
|---|----------|-----------------|
| D1 | Re-validate in `processArgs` / `initAccount`? | Yes, cheap defense in depth (Aave spirit) |
| D2 | Require market `lastUpdate != 0`? | **Yes** — no auto-createMarket in v1 |
| D3 | SE marker interface id required? | v1 behavioral `vaultTokens` only; marker optional |
| D4 | `vaultTokens` on strategy instance | Include coll, loan, SE share address for multi-asset surface |
| D5 | `deployVault` calldata vs memory `PkgArgs` | Calldata on external deploy (gas); memory in init decode |
| D6 | Name of package / marker | Product naming pass |

---

## 10. Acceptance examples (illustrative only)

These are **examples of Family A**, not package defaults:

| Morpho market (user) | Uni V4 SE (user) | Accept? |
|----------------------|------------------|---------|
| coll=WETH, loan=USDC, enabled irm/lltv, market live | SE for WETH/USDC pool | **Yes** if LTV policy &lt; lltv |
| coll=WETH, loan=USDC | SE for WETH/USDT pool | **No** — `LoanNotInSeVaultTokens` |
| coll=wstETH, loan=WETH | SE for wstETH/WETH | **Yes** if market live |
| Uncreated market params | Any SE | **No** — `MarketNotCreated` |
| maxLtvWad ≥ market.lltv | Compatible SE | **No** — `MaxLtvNotBelowLltv` |

---

## 11. Next design steps (after this sketch freezes)

1. Lock D1–D6 + Family A as PRD law.  
2. Facet inventory + `IMorphoUniswapV4LeveredLp` runtime interface (deposit/withdraw/…).  
3. Repo layout for Morpho market + SE + policy.  
4. NAV / dual-HF formulas (design surfaces doc §2.4–2.5).  
5. Open/close state machines.  
6. TestBase: hermetic Morpho + Uni V4 SE → deploy strategy with valid/invalid `PkgArgs`.

---

## 12. Changelog

| Date | Change |
|------|--------|
| 2026-08-02 | Initial DFPkg PkgInit/PkgArgs/validation sketch for S3; Family A capital-path; peer-aligned registry deploy |
