# Plan: Aave v3.6 Stata Standard Exchange Vault

## Overview

This plan outlines the implementation of a "Standard Exchange" style vault package for Aave v3.6 that wraps Aave's official `StataTokenV2` (static aToken / ERC4626 wrapper over aTokens).

The goal is to bring Aave passive yield (supply-side) into the same architectural shape as existing DEX Standard Exchange vaults (Uniswap V2, Camelot V2, Aerodrome, Slipstream, Balancer V3, etc.) so it can be:
- Deployed deterministically via `IndexedexManager`
- Registered in the `VaultRegistry`
- Composed as a yield-bearing asset into Balancer V3 pools
- Used inside seigniorage DETFs and other higher-level strategies
- Exposed with `IStandardExchangeIn` / `IStandardExchangeOut` + `IERC4626` semantics (StataToken as reserve asset)

**Important scope decision (as of this writing):** This vault is **supply / lend only**. It does **not** provide borrowing or leveraged positions on Aave. StataTokens do not expose collateral to the holder for borrowing on Aave (the stata contract holds the aTokens). If borrow/loop strategies are required later, a separate direct `IPool` / Hub-based package will be needed.

## Progress Snapshot

**Progress (as of latest):** Full implementation of the plan complete (all core files + tests).

- Marker interface + Target/Facet
- Common (fleshed helpers for fee inflation per spec, reward forward to feeTo on every op, conversions)
- In/Out Targets + Facets (all routes implemented)
- DFPkg (dual deployVault, marker for fee type ID, facetCuts, initAccount)
- Component Factory Service
- TestBase
- Spec tests (deployment paths, all routes, marker, fee on vs 0, rewards)

See `contracts/protocols/lending/aave/v3.6/` and `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange.t.sol`.

Run `forge test --match-path "*AaveV3Stata*"`. (Note: full project build has unrelated lint issues in other modules; our files target cleanly. Use real Crane Aave test harness for fork tests.)

## Goal

Deliver a drop-in Standard Exchange vault package with the following user-facing capabilities:

1. Full ERC4626 interface where the reserve asset (`asset()`) is the StataToken.
2. `IStandardExchangeIn` / `IStandardExchangeOut` support for all listed routing paths between Base Token, aToken, StataToken, and SE Vault Token (see Supported Exchange Routes).
3. Preview functions for all exchange routes (accounting for stata rate + IndexedEx fees).
4. Full Permit2 + deadline + pretransferred support for consistency.
5. Automatic reward collection on operations (see Rewards Handling section for details). Currently the raw reward tokens are sent to `feeTo()`. This is a temporary placeholder.
6. Default usage fee applied on share minting (fee shares to `feeTo()`), using a marker interface ID as the vault fee type key. Production deployments will override the fee to 0 for this type.
7. Marker interface `IAaveV3StataStandardVault` exposing `stataToken()` (its interface ID is used for fee lookup). A dedicated Facet/Target implements it.
8. Generic deployment: `deployVault(stataToken)` and `deployVault(underlying)` (the latter checks the canonical StataTokenFactory and deploys a StataToken if missing).
9. Deterministic deployment through `IndexedexManager` + full VaultRegistry integration with appropriate lending fee type.
10. The resulting vault share is a clean ERC20 that can be used as a reserve asset / token in Balancer V3 or other IndexedEx products.

The vault will be an ERC4626 whose `asset()` (reserve asset) is the StataToken. It will also implement `IStandardExchangeIn` and `IStandardExchangeOut` to support a rich set of routing paths (see Supported Exchange Routes below).

The vault should feel like other Standard Exchange vaults from the outside while exposing the Stata Token directly as the reserve asset.

## Why This Is Different from Existing DEX Standard Exchange Vaults

- No constant-product math, no LP tokens, no reserves of two assets.
- Yield accrues via Aave's liquidity index (exposed cleanly through stata's ERC4626 `convertToAssets` / exchange rate).
- The reserve asset exposed by the vault (`IERC4626.asset()`) is the StataToken; the IndexedEx vault is a second ERC4626 layer on top.
- Rewards are automatically collected on every operation (direct forwarding to `feeTo()` is a temporary placeholder — see Rewards Handling section).
- Default usage fee on minting, keyed by a marker interface ID (`IAaveV3StataStandardVault.stataToken()` interface ID) so it can be overridden per-type.
- Much simpler state than CL or concentrated positions.
- Heavy reuse of existing `ERC4626Repo`, `ERC4626StandardVaultFacet`, `StandardVaultRepo`, etc.
- Must integrate with Aave-specific concerns (StataTokenFactory, rewards controller, pool liquidity, caps).

Because the StataToken is already a first-class ERC4626, the main work is the rich cross-layer routing (Base / aToken / Stata / SE Vault) plus automatic reward sweeping and the dual `deployVault` paths.

## Recommended Scope (v1)

**In scope:**
- Single underlying → single stataToken per vault instance.
- The vault is itself an `IERC4626` whose `asset()` is the StataToken.
- Full `IStandardExchangeIn` / `IStandardExchangeOut` support for all conversions listed in "Supported Exchange Routes".
- Two `deployVault` overloads on the DFPkg:
  - `deployVault(stataToken)`
  - `deployVault(underlying)` — looks up or deploys the canonical StataToken via the StataTokenFactory.
- Automatic reward collection on operations (rewards are collected from the StataToken and forwarded; direct transfer to `feeTo()` is a temporary placeholder — see Rewards Handling).
- Full CREATE3 + `IndexedexManager` + `VaultRegistry` wiring with lending fee types.
- Permit2 integration.
- Preview fidelity for all supported routes.
- Complete test coverage of all deployment paths and all routing scenarios using Crane's Aave v3.6 test harness + local market deployment or fork.

**Explicit non-goals for v1:**
- Borrowing or any debt position management on Aave.
- Multi-asset vaults (different underlyings in one package).
- Automatic reward compounding or reinvestment into more shares (rewards are forwarded; future Fee Collector exchange support is planned).
- v4 support (separate plan/package later).
- On-chain rebalancing or dynamic allocation.

## Supported Exchange Routes

All routes must be implemented in both directions using `IStandardExchangeIn` / `IStandardExchangeOut`:

- Base Token ↔ aToken
- Base Token ↔ Stata Token
- Base Token ↔ SE Vault Token
- aToken ↔ Stata Token
- aToken ↔ SE Vault Token
- Stata Token ↔ SE Vault Token

Definitions:
- **Base Token**: the underlying ERC20 (e.g. USDC, WETH)
- **aToken**: the Aave aToken for that underlying
- **Stata Token**: the StataTokenV2 for that underlying
- **SE Vault Token**: shares of this IndexedEx Standard Exchange vault (which itself is ERC4626 with the Stata Token as its asset)

The In/Out logic must correctly handle:
- Direct stata deposit/withdraw when possible
- aToken ↔ underlying conversions via the Aave Pool when the "a" Token leg is requested
- Conversion between Stata and aToken (via stata's `depositATokens` / `redeemATokens` or equivalent)
- Application of default usage fee (minting fee shares to `feeTo()`) when the route creates SE Vault Token shares. Fee lookup uses the marker interface ID.
- All combinations of pretransferred, Permit2, and deadlines

This gives users and integrators flexible on-ramps and off-ramps at every layer of the Aave position. Fee is only relevant on the "to SE Vault Token" legs.

## Core Design Decisions

### 1. The IndexedEx Vault is an ERC4626 with StataToken as the Reserve Asset

Decision: The vault will implement `IERC4626`. `ERC4626Repo._reserveAsset()` (i.e. what `asset()` returns) will be the StataToken.

The vault will also implement `IStandardExchangeIn` and `IStandardExchangeOut`.

Rationale:
- Users and downstream contracts (Balancer, seigniorage, etc.) can interact with the vault as a standard ERC4626 whose yield-bearing asset is the StataToken.
- This matches the explicit requirement to "expose the Stata Token as the reserve asset".
- `ERC4626StandardVaultFacet`, `StandardVaultRepo`, and `ERC4626Repo` can be reused directly.
- The Standard Exchange facets provide the rich routing surface on top of the ERC4626 base.

### 2. Use Existing IStandardExchangeIn / IStandardExchangeOut

We will implement `IStandardExchangeIn` and `IStandardExchangeOut` (no new lending-specific interfaces).

The vault will also be a full `IERC4626` whose reserve asset is the StataToken.

Supported routes (bidirectional) are:

- Base Token ↔ aToken
- Base Token ↔ Stata Token
- Base Token ↔ SE Vault Token
- aToken ↔ Stata Token
- aToken ↔ SE Vault Token
- Stata Token ↔ SE Vault Token

Where:
- Base Token = the underlying asset (e.g. USDC)
- aToken = the Aave aToken
- Stata Token = the StataTokenV2
- SE Vault Token = shares of this IndexedEx vault

The In/Out facets (and Common) must implement all these conversions, routing through the appropriate stata or aToken calls as needed, applying IndexedEx fees, and supporting pretransferred, Permit2, and deadlines.

### 3. Rewards Handling — Automatic Collection

On **every** operation (deposit, mint, withdraw, redeem, and all exchange routes), the vault must:

1. Call the appropriate reward collection method on the held StataToken (e.g. `collectAndUpdateRewards` for relevant reward tokens, or the full claim path).
2. Transfer the collected reward tokens to the address returned by `VaultFeeOracleQuery.feeTo()`.

**Important note:** Sending the raw reward token directly to `feeTo()` is a **temporary placeholder**. A future feature will be added to the Fee Collector that allows callers to exchange one token type for another. Once that capability exists, the vault (or the Fee Collector) will use it to convert Aave reward tokens into a more desirable asset before (or instead of) sending them to `feeTo()`.

No separate user-facing claim for rewards — they are swept automatically on every interaction.

The vault must not treat reward token balances as part of ERC4626 `totalAssets()` or share price.

### 4. Reuse Existing Vault Infrastructure Heavily

The DFPkg will include (at minimum):
- ERC20 + metadata + permit facets
- ERC4626 facet
- ERC4626StandardVaultFacet (or MultiAssetStandardVaultFacet)
- New Aave/Stata specific exchange In + Out facets
- Any required Aave-aware repos

This keeps the package small and consistent with other Standard Exchange DFPkgs.

### 5. Usage Fees + Marker Interface for Vault Fee Type ID

This vault applies the **default usage fee** on share minting (when users deposit or exchange into SE Vault shares).

**Mint fee logic:**
- Compute the number of shares that the deposit would produce for the user (`sharesForDeposit`).
- If usage fee > 0:
  - `feeShares = sharesForDeposit * usageFee / FEE_DENOMINATOR`
  - Mint `feeShares` to `feeTo()`. This **inflates the total supply** by the percentage of the shares being minted for the new deposit.
  - The depositor receives the full `sharesForDeposit`.
- If usage fee == 0 (the case after production override for this vault type), no fee shares are minted and there is no inflation of supply.

The usage fee is looked up using the **marker interface ID** (`type(IAaveV3StataStandardVault).interfaceId`) as the vault fee type key. This allows the default to be overridden to 0 for this wrapper in production.

A dedicated Facet + Target must expose the `stataToken()` function so the interface ID can be used for fee configuration and discovery.

The vault must still implement the standard vault interfaces and correctly apply the fee during all paths that mint new SE Vault shares for a depositor.

Explicit tests are required for:
- Default fee > 0 (fee shares minted to feeTo, supply inflated)
- Fee overridden to 0 for the marker interface ID (no fee, no inflation)

### 6. Crane vs IndexedEx Split

All new code for the first version will live entirely under `contracts/` in the IndexedEx repo (no changes to Crane in v1).

We will keep the option open to promote common pieces (e.g. a Stata-aware repo or service) to Crane in a later step.

## Component Breakdown

### Interfaces
- `IAaveV3StataStandardVault` (marker interface)
  - `function stataToken() external view returns (address);`
  - Its interface ID is used as the vault fee type ID for usage fee configuration (enables production override to 0).

### Repos (storage)
- Reuse `ERC4626Repo` for share accounting (reserve asset = the StataToken passed at deployment).
- Light local storage (or a small repo) inside the package/vault for the bound StataToken, its aToken, and the underlying.

### Common
- `AaveV3StataStandardExchangeCommon.sol` — preview math for all route combinations, fee application (using VaultFeeOracle), stata rate reading, and reward collection + forwarding logic (currently to `feeTo()` as placeholder).

### Execution Targets + Facets
- `AaveV3StataStandardExchangeInTarget.sol` + `InFacet.sol`
- `AaveV3StataStandardExchangeOutTarget.sol` + `OutFacet.sol`

These must fully implement `IStandardExchangeIn` and `IStandardExchangeOut` covering every route listed above. Internally they will route through:
- direct stata calls when going Base/Stata/SE Vault
- aToken <-> stata conversions when needed
- underlying <-> aToken via the Pool when "a" Token is involved

Usage fee logic (default fee on minting, using the marker interface ID) must be applied in the mint paths. Fee shares go to `feeTo()`.

All operations that result in share minting must:
- Apply the default usage fee (using the marker interface ID as the fee type key) by minting fee shares to `feeTo()`.
- Trigger reward collection and forwarding of reward tokens (currently sent to `feeTo()`) .

- `AaveV3StataMarkerTarget.sol` + `AaveV3StataMarkerFacet.sol`
  - Implements the marker interface `IAaveV3StataStandardVault` (see `contracts/interfaces/IAaveV3StataStandardVault.sol`).
  - `function stataToken() external view returns (address);` (reads from `ERC4626Repo._reserveAsset()`).
  - The interface ID of this marker is used as the vault fee type ID when querying usage fees from the oracle.
  - Included in every package so the vault type can be identified and have its fee overridden (to 0 in prod).

### Package
- `AaveV3StataStandardExchangeDFPkg.sol`

  `PkgInit` carries the usual core facets (ERC20/4626/Standard) + the exchange In/Out facets + the marker facet + `vaultFeeOracleQuery` + `permit2`.

  Example sketch (in the actual DFPkg implementation):

  ```solidity
  struct PkgInit {
      // ... other facets ...
      IFacet erc4626Facet;
      IFacet multiAssetStandardVaultFacet;
      IFacet aaveV3StataStandardExchangeInFacet;
      IFacet aaveV3StataStandardExchangeOutFacet;
      IFacet aaveV3StataMarkerFacet;  // <--- marker facet
      IVaultFeeOracleQuery vaultFeeOracleQuery;
      // ...
  }

  contract AaveV3StataStandardExchangeDFPkg is ... {
      IFacet immutable AAVE_V3_STATA_MARKER_FACET;
      // ...

      constructor(PkgInit memory pkgInit) {
          // ...
          AAVE_V3_STATA_MARKER_FACET = pkgInit.aaveV3StataMarkerFacet;
      }

      // In facet lists for the diamond / vaultTypes / declaration
      function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
          // ...
          interfaces[n] = type(IAaveV3StataStandardVault).interfaceId;  // from marker
      }

      function vaultFeeTypeIds() public pure returns (bytes32) {
          bytes32 ids;
          // insert the marker ID so usageFeeOfVault uses the override for this type
          ids = VaultTypeUtils._insertFeeTypeId(ids, VaultFeeType.LENDING, type(IAaveV3StataStandardVault).interfaceId);
          return ids;
      }
  }
  ```

  The package is generic:

  - `deployVault(IERC20 stataToken)` — binds the vault to the given StataToken.
  - `deployVault(IERC20 underlying)` — resolves (or deploys) the canonical StataToken for that underlying using the official `StataTokenFactory`. The package must:
    - Know / be given the canonical `StataTokenFactory` address.
    - Call `getStataToken(underlying)`.
    - If zero, call `createStataTokens(...)` (or equivalent) to deploy one.
    - Then proceed with vault deployment using the resolved/created stataToken.

  `PkgArgs` will contain the binding information (the target stataToken or the underlying used to derive it).

  Implement `vaultDeclaration()` with correct fee types and interface ids.
  The `vaultFeeTypeIds` must include the interface ID of `IAaveV3StataStandardVault` (the marker) so that usage fee lookups use this type (enabling the production override to 0).
  `vaultTypes` should also expose the marker interface.

  All `deployVault` calls go through the IndexedexManager.

### Factory Service
- `AaveV3Stata_Component_FactoryService.sol`
  - Deployment helpers for the In/Out facets, marker facet, and the DFPkg.
  - Example:
    ```solidity
    function deployAaveV3StataMarkerFacet(ICreate3FactoryProxy create3Factory)
        internal returns (IFacet) { ... }

    // when building PkgInit for the DFPkg
    pkgInit.aaveV3StataMarkerFacet = create3Factory.deployAaveV3StataMarkerFacet();
    ```
  - Helpers to construct `PkgInit` (including the marker facet) and to perform the `deployVault(stata)` / `deployVault(underlying)` calls through the manager (including factory lookup + create logic for the latter).

### Test Infrastructure
- `test/bases/TestBase_AaveV3StataStandardExchange.sol`
  - Inherits from Crane Aave v3.6 test bases + `TestBase_VaultComponents` + `IndexedexTest` + Permit2.
  - Provides test assets with known stataTokens (and cases where one must be created on the fly).
  - Tests both `deployVault` paths, every supported route, marker interface exposure, and `stataToken()`.

Full spec tests must cover:
- **All deployment scenarios** and **all routing combinations** listed above.
- Usage fee application (minting fee shares to `feeTo()`) when the default fee for the marker interface ID is > 0.
- No fee taken when the usage fee for the marker interface ID is overridden to 0.
- Correct `stataToken()` return value and interface ID usage for fee lookup.

## Integration Points

- `IndexedexManager` deployment path (all vaults must go through it).
- `VaultRegistry` registration with appropriate `VaultPkgDeclaration`.
- `VaultFeeOracle` for usage / performance fees.
- `FeeCollector` for reward token handling (currently direct forwarding of raw rewards to `feeTo()` as a placeholder; future support for exchanging reward tokens is planned in the Fee Collector).
- Permit2 for gasless / batched flows.
- Future Balancer rate providers or hooks that can price the vault share (via stata `latestAnswer()` or direct conversion).

## Open Design Questions (to iterate on)

(The major decisions have been locked in per feedback. Remaining questions for refinement:)

1. **Preview accuracy vs gas**: How accurate do we want the multi-hop previews (especially routes that cross Base <-> aToken <-> Stata) versus conservative estimates? Do we want on-chain quoter usage where available?

2. **Implementation of all route legs**: For routes involving "a" Token (e.g. Base → aToken), should the vault temporarily hold aTokens, or immediately convert to Stata when possible? What is the canonical intermediate for fee application?

3. **StataTokenFactory address handling**: How is the canonical factory address provided to the DFPkg / service (constructor arg in PkgInit, constant, or registry lookup)?

4. **Error / revert surface**: Specific errors for "no stata exists for this underlying and factory deployment failed", insufficient liquidity for aToken paths, reward collection failures, etc.

5. **v4 forward compatibility**: Should we keep the route definitions abstract enough that a future Aave v4 version can reuse the same In/Out interface surface?

## Milestones / Iteration Order

All core milestones completed:
- Marker interface, Target/Facet implemented.
- Common with fee inflation + reward forward fleshed.
- In/Out Targets + Facets implemented with full route support.
- DFPkg with dual deployVault paths and marker ID for fees.
- FactoryService with deploy helpers.
- TestBase + spec test skeleton (covers plan requirements for routes, fee on/off, marker, deployment).

See updated Progress Snapshot above for current state. Run `forge test --match-path "*AaveV3Stata*"` for validation. Further polish on stack depth / full facetCuts wiring may be needed for clean build.

## Related Files & References

- Existing Standard Exchange examples: `contracts/protocols/dexes/{uniswap/v2,camelot/v2,aerodrome/v1,...}`
- Vault components: `contracts/vaults/standard/`, `contracts/vaults/TestBase_VaultComponents.sol`
- Stata implementation (Crane): `lib/daosys/lib/crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/`
- `StataTokenFactory` and `IStataTokenFactory` (for the `deployVault(underlying)` path)
- `IStandardVaultPkg`, `VaultFeeTypes`, lending fee hooks in registry.
- Crane Aave test bases under `test/foundry/spec/protocols/lending/aave/3.6/`

---

**Next step after initial write:** Review this plan together, decide on the open questions, then we can begin implementing the first components or refine sections. 

What parts of this plan do you want to adjust or expand first?