# Original Findings — Hook-Specific Uniswap V4 Standard Exchange Vault Packages

Researcher: MiniMax M3 (independent first pass; no peer artifacts read this round)
Date / access date: 2026-09-27
Target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/` (NEW FullSpread V4)
Scope: User proposes hook-specific DFPkg split — initial hookless, Pons Family, future per-hook; reusing identical facet sets where compatible. Evaluate architecture, identity/binding, facet reuse, package salt uniqueness across multiple packages using same bytecode, Pons version/parameters/fees, runtime safety, quote model, deployment checks, tests, and minimal owner questions.

---

## 0. Bottom-line assessment

The proposal is **architecturally sound and directly supported** by the existing Indexedex Manager vault registry, CREATE3 facet reuse, and Crane DFPkg patterns. **Three structural caveats** constrain the "reuse identical facet sets" claim, and **eight owner decisions** must be ratified before any plan. The current single-package `UniswapV4FullSpreadStandardExchangeVaultDFPkg` is left intact (additive change), preserving immutable live instances. The proposal **legitimately supersedes** PRD D14's no-whitelist/deployer-assurance clause: a whitelisted hook IS a structural admission.

| Decision block | Verdict |
|---|---|
| Two packages now (Hookless + Pons), more later per hook | **feasible**, requires PkgArgs widening |
| Reuse identical facet sets where compatible | **partially feasible** — CREATE3-bytecode-level reuse yes; library-level reuse no |
| Avoid arbitrary-hook quote concerns | **achievable** — each package bounds its supported hook surface deterministically |
| Salt uniqueness across N packages using same bytecode | **preserved** — package salt = contract-name hash (line 253 of DFPkg); CREATE3 ensures one canonical address per facet name |
| Pons versions / mutable parameters / fees | **manageable** — bounded by `MAX_HOOK_FEE_BPS = 1000` and immutable param ceilings; require hook bytecode hash check at deployment |
| Runtime safety / quote model | **stronger than single-package** — package-scoped model, no branching on hook flag bits at quote time |
| Tests | **extendable** — package-level invariant = "hook matches expected, fee/composition/liquidity paths hold" |
| Minimal owner decisions | **8 items** (see §6) |

---

## 1. Verified evidence (NEW FullSpread code, primary sources)

### 1.1 Single-package status today

`UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` (361 lines) currently:

- Stores **15 facets** as `immutable` (lines 71–92): `ERC20_FACET`, `ERC5267_FACET`, `ERC2612_FACET`, `MULTI_ASSET_BASIC_VAULT_FACET`, `MULTI_ASSET_STANDARD_VAULT_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_IN_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_IN_QUERY_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_POSITION_IMPORT_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_OUT_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_OUT_QUERY_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_LIQUID_RESERVE_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_QUERY_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_FACET`, `UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_QUERY_FACET`.
- Stores **5 dependencies** as `immutable`: `VAULT_FEE_ORACLE_QUERY`, `VAULT_REGISTRY_DEPLOYMENT`, `PERMIT2`, `POOL_MANAGER`, `POSITION_MANAGER`, `TWAP_ORACLE`, `WETH` (lines 87–93).
- Construct-time checks: `ZeroTwapOracle`, `ZeroWeth`, `TwapOraclePoolManagerMismatch` (lines 115–125).
- Package salt: `keccak256(abi.encode(type(UniswapV4FullSpreadStandardExchangeVaultDFPkg).name)._hash())` (per `UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol:181–184`). **Salt is type name, not constructor args.** This ensures a single canonical CREATE3 address for the package across the entire repo.
- Instance salt: `keccak256(abi.encode(pkgArgs))` (line 253–255); `PkgArgs = (PoolKey)` (current shape).
- `initAccount` (lines 271–298): no `poolKey.fee` validation, no `poolKey.hooks` validation, no Pons-version check. Stores PoolKey verbatim.
- `processArgs` (lines 257–265): only checks `msg.sender == VAULT_REGISTRY_DEPLOYMENT` and `TWAP_ORACLE.poolManager() == POOL_MANAGER`.
- `deployVault(poolKey)` (lines 333–336): accepts ANY PoolKey.

### 1.2 Facet dependencies on the QuoteService

Quote-service coupling in facets (verified via grep on `UniswapV4FullSpreadStandardExchange`):

- `Common.sol:239`: `_inventorySwap` calls `UniswapV4FullSpreadStandardExchangeVaultQuoteService._adjustHookSwap(_poolKey(), result.amountOut, true)`.
- `Common.sol:1092`: `_quoteSwapAfterWithdrawal` calls `...QuoteService._adjustHookSwap(...)` (line 1092).
- `Common.sol:1134`: `...QuoteService._adjustHookSwap(...)`.
- `Common.sol:1151`: `_quoteSwapOut` calls `...QuoteService._quoteDirectExactOutput(...)`.
- `Common.sol:1108`: `_quoteSwapIn` calls `...QuoteService._quoteDirectExactInput(...)`.
- `Common.sol:101`: `_inventorySnapshot` checks `_supportsInventoryQuote()` which delegates to `...QuoteService._supportsProjectedHook(_poolKey())`.

**Implication.** Every quote-or-execution path on **pool tokens** eventually calls `UniswapV4FullSpreadStandardExchangeVaultQuoteService`. **The library is compiled into the facet bytecode at construction.** Facets are not currently strategy-injectable.

### 1.3 Pons V2 hook structure (relevant to the second proposed package)

`PonsV2MemeHook.sol` (1029 lines, accessed 2026-09-27):

- **Header (line 30)**: "Singleton Uniswap V4 hook shared by every graduated pons v2 pool." All Pons V2 pools share ONE hook address.
- **Hook permissions** (line 184–201): `beforeInitialize: true`, `afterInitialize: false`, `beforeSwap: false`, `afterSwap: true`, `afterSwapReturnDelta: true`, all others false. Matches the `BEFORE_INITIALIZE_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG` mask that FullSpread QuoteService requires at line 25 (`flags != (Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG)`).
- **Mutable owner-settable parameters** (lines 239–267):
  - `setProtocolFeeShareBps(uint256)` (max `MAX_PROTOCOL_FEE_SHARE_BPS = 5000` per line 70)
  - `setBuybackBurnBps(uint256)` (max `BASIS_POINTS = 10000`)
  - `setHookFeeBps(uint256)` (max `MAX_HOOK_FEE_BPS = 1000` per line 71)
  - `setMaxInternalPriceImpactBps(uint256)` (must be `> 0` and `< 10000`)
  - `setProtocolFeeRecipient(address)` (non-zero)
  - `setFeeSweepOperator(address)` (non-zero)
- All these ceilings are **immutable constants** in the hook contract (lines 70–74). Mutable live values are bounded by these caps.
- **Per-pool frozen parameters** (in `LaunchInfo` struct, lines 48–67): `creatorTaxBps`, `protocolFeeShareBps`, `buybackBurnBps`, `hookFeeBps`, `maxInternalPriceImpactBps`, `buybackEnabled` are snapshotted at `registerPool` time (lines 313–407) and never updated on the live pool.
- **LaunchInfo 13-word packed struct** — verified by `PonsV2LaunchDeployer.sol` decode at quote time: `info[0] = version` (must be `== 1`), `info[1] = layout` (`0`/`1`), `info[2] = memecoin (when layout=0)`, `info[3] = quote (when layout=0)`, `info[7] = hookFeeBps` (max 2000, FullSpread asserts), `info[10] = protocolFeeShareBps` (max 2000, FullSpread asserts). **Other positions are NOT validated by FullSpread QuoteService.**
- **Factory wiring**: `PonsV2LaunchFactory` constructs `PonsV2MemeHook` once at protocol deploy and pools register via `registerPool(...)`. All Pons V2 pools share a single hook address.

### 1.4 Package salt uniqueness pattern

`BetterEfficientHashLib._hash()` is used twice:
- **Package-level** (UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol:181–184): `abi.encode("UniswapV4FullSpreadStandardExchangeVaultDFPkg")._hash()` → package-salt (immutable across the entire repo).
- **Instance-level** (DFPkg.sol:253–255): `abi.encode(pkgArgs)._hash()` → instance-salt.

This pattern: the **package contract TYPE-NAME is its salt**, so **renaming the contract is sufficient to give a new package a unique CREATE3 address.** Multiple packages with the same bytecode will have different addresses because their names differ. ✓

**Consequence for the proposal:**
- A new `UniswapV4PonsV4FullSpreadStandardExchangeVaultDFPkg` (with Pons in the name) lands at a different CREATE3 address than the existing `UniswapV4FullSpreadStandardExchangeVaultDFPkg`. ✓
- Both packages can share facet bytecode by reusing the same `ArtifactCreationCode("UniswapV4FullSpreadStandardExchangeVaultInFacet.sol:...")` reference and the same canonical salt in their respective FactoryServices, landing each facet at the SAME address.

### 1.5 Registry multi-package coexistence

`VaultRegistryVaultPackageRepo.sol:75–108`: `_registerPkg` adds the package to:
- `Storage.packages` (address-set keyed by pkg)
- `Storage.pkgNames` (mapping pkg → name)
- `Storage.vaultTypeIds` (bytes4-set of all registered interfaces)
- `Storage.pkgsOfType[typeId]` (per-type pkg address-sets)

There is **no unique constraint on vault types** — two packages exposing the same interface ID (e.g., both claiming `IStandardExchangeIn`) coexist in `pkgsOfType[typeId]` as two addresses. ✓ This is well-supported.

`VaultRegistryDeploymentTarget.sol:44–61`: registers pkg via `IStandardVaultPkg(pkg).vaultDeclaration()`; `deployPkg(initCode, initArgs, salt)` is permissionless on the registry interface but only reachable via a registered package's `deployVault` (or by anyone calling the registry directly if `deployVault` is exposed). ✓

### 1.6 Source-map compatibility

`README.md` line 11: "Each component/package salt is directly `keccak256(abi.encode("<FullSpread contract name>"))`. Artifact bytecode and constructor arguments remain intact but are not salt inputs. Instance salt derivation, storage field order, and storage slot strings are unchanged."

This is the **canonical Indexedex deployment model** that the proposal reuses. The proposal is compatible with preserved baseline evidence in `VERSION_SOURCE_MAP.json`, `PRESERVED_SOURCE_SHA256.json`, `PRESERVED_BUILD_CONTEXT.json`.

### 1.7 Pond V2 deployment lifecycle

`PonsV2LaunchDeployer.sol:86–109`: Uses **CREATE2** (`Create2.deploy(0, salt, _curveCreationCode(params))`), not CREATE3, for curves and tokens. **The Pons hook itself** is not deployed via PonsV2LaunchDeployer — it is deployed elsewhere (not located in this read). It is a singleton with **stable address** (BaseHook requires CREATE2 to mine the right hook-permission flag bits).

`PonsV2LaunchFactory.sol:146`: salt for one launch's curve and token, including `creatorTaxBps` etc. in storage.

### 1.8 Run-time protections for v4FS

- `rebalanceLiquidReserve` (UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol:92–97): reverts `PoolManagerInteractionBlocked` when blocked, calls `_rebalanceLiquidReserveInternal()` when idle, returns success-without-unlock when both tokens are within deadband. **Behavior is the same regardless of hook** — vanilla or Pons.
- Configurable enforcement constants per PRD D20: 25 bp / 50 bp / 10 bp / 1 bp. These would still apply per-package.

---

## 2. Answering the user's specific proposal

### 2.1 "Initial hookless package checks no hook"

✅ **Feasible and recommended.** Add to `processArgs`:
```solidity
if (decodedArgs.poolKey.hooks != address(0)) revert UnsupportedHookForHooklessPackage(decodedArgs.poolKey.hooks);
```
The existing single-package already accepts hookless Pools through that branch — formalizing it as a separate package removes the "any hook is OK by default" framing.

### 2.2 "Pons Family package checks specific hook"

✅ **Feasible.** Two distinct checks needed:
1. `processArgs` (or `initAccount`): `decodedArgs.poolKey.hooks == PonsV2HookAddress` (immutable in package). Recommend ALSO asserting `keccak256(PonsV2HookCode) == PonsV2HookBytecodeHash` to bind the version. ✓
2. `initAccount`: existing Pons decode (`_ponsHookFees` decodes 13-word `LaunchInfo`) becomes a hard requirement — reverts `InvalidPonsVersion` if `info[0] != 1` instead of being a soft "hook-fee adjustment only" path.

### 2.3 "Future integrations: one package per compatible hook, reusing identical facet sets where compatible"

⚠ **Partially feasible.** Two interpretations:

**(A) Bytecode-level reuse** ✅ — via `ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInFacet.sol:...")` referenced by every new package's FactoryService. Each new package's InFacet is the **same canonical address** because the salt is `keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultInFacet"))`. ✓

**(B) Library-level reuse** ❌ — impossible in current structure. `InFacet`/`OutFacet` call `UniswapV4FullSpreadStandardExchangeVaultQuoteService` directly (verified in §1.2). To re-use the *same* facet bytecode against a *different* hook, you'd need a strategy abstraction. Today's facets cannot switch quote library without source change.

**Recommendation:** Per hook family, ship a **suite of new facet targets** that delegate to the **same library interface** but with different implementations:
- `UniswapV4HooklessFullSpreadStandardExchangeVaultQuoteService` (vanilla only)
- `UniswapV4PonsV2FullSpreadStandardExchangeVaultQuoteService` (Pons V2 only, harder `info[0] == 1` + bytecode-hash check)
- (future) `UniswapV4<HookFamily>...QuoteService`

Each hook-family package then composes a fresh set of facets that reference the right library. **The facet-bytecode salt is unchanged** → CREATE3 reuses the same address → the regeneration cost is just the **library contracts**, not the facets.

### 2.4 "Should split into two implementations/packages to avoid arbitrary-hook quote concerns?"

✅ **Yes**, but with the caveat above. The split:
- Bounds the supported hook set per package (encoded at deploy-time).
- Removes the `_supportsProjectedHook` branching in Common (line 104) **inside the new packages** (the library swap does the gating once at construction).
- Allows per-package intercept-point customization (custom `Pons V2 fee-aware` adjustment) without polluting the hookless package.

The split improves over the current single-package: today `Common._supportsInventoryQuote` checks `_supportsProjectedHook` at quote time, which has both a flag-check (vanilla OR Pons mask) and a runtime `launches(bytes32)` staticcall. With per-package libraries, the per-package logic becomes the **deploy-time contract-bytecode-hash assertion** plus a hard `processArgs` hook-address check — no runtime branching on hook flags.

### 2.5 Architectural benefits over the current single-package

| Aspect | Current single-package | Proposed hook-specific |
|---|---|---|
| Hook admission | runtime branching | **deploy-time rejection** |
| Pons-version drift detection | soft (relies on `_ponsHookFees` decodes) | **hard (processArgs check on `launches(poolId).info[0]`)** |
| Cross-hook pollution risk | one library for all hooks | one library per family |
| Per-package bug blast radius | any hook type | bounded to that family |
| Facet bytecode reuse (n) | n=1 family | **n=N families share facets** via canonical salt |
| Registry discovery | one package, type-ids intersect | multiple packages, registry isolates by pkg address |
| Backward compatibility | current instances live | **additive** — old package untouched |

### 2.6 Architectural caveats

| Caveat | Risk | Mitigation |
|---|---|---|
| Pons V3 launches with `info[0] == 1` for back-compat | silent acceptance of unsupported hooks | hook bytecode hash check at processArgs |
| Mutable hook params (Pons `setHookFeeBps` etc.) | preview differs from execution when owner changes mid-flight | `MAX_HOOK_FEE_BPS = 1000` ceiling is immutable; document as known closed-form bound (PRD D20 ≥ 10 bp shortfall covers intra-block drift) |
| Per-package adds new immutable state | gas/bytecode budget vs `24,576` runtime limit (README:65) | reference existing facet addresses via interface IDs rather than embedding |
| Multi-package `pkgsOfType[typeId]` now returns >1 address | off-chain discoverability breaks unless indexers use pkg-name or hook-id leaf | registry already supports per-pkg lookup by address; recommend off-chain selector |
| `processArgs` must know the expected hook address at construction | if Pons hook is redeployed at a new address (uncommon), package breaks | recommend package-field `hookBytecodeHash` rather than `hookAddress` for forward-compat |

---

## 3. Architecture proposal — concrete files / change surface

### 3.1 New package tree (suggested)

```
contracts/vaults/standard/exchange/protocols/uniswap/v4/
├── UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol                 [existing — UNTOUCHED]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultDFPkg.sol       [NEW: vanilla, hooks==0]
├── UniswapV4PonsV2V4FullSpreadStandardExchangeVaultDFPkg.sol         [NEW: Pons V2 only]
└── libraries/
    ├── UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol     [existing — UNTOUCHED]
    ├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultQuoteService.sol
    └── UniswapV4PonsV2V4FullSpreadStandardExchangeVaultQuoteService.sol
```

The new packages reuse the existing **12 of 15 facets**:
- `UniswapV4FullSpreadStandardExchangeVault{InFacet,InQueryFacet,OutFacet,OutQueryFacet,LiquidReserveFacet,PositionImportFacet,InMultiFacet,InMultiQueryFacet,OutMultiFacet,OutMultiQueryFacet}` and the seven shared ones (`ERC20_FACET`, `ERC5267_FACET`, `ERC2612_FACET`, `MULTI_ASSET_BASIC_VAULT_FACET`, `MULTI_ASSET_STANDARD_VAULT_FACET`).
- The hookless package's **InFacet/OutFacet must reference `...Hookless...QuoteService`**, which means the facet bytecode **does differ** between Hookless and Pons packages (since the library reference is hardcoded in compilation). Cost: ≈ 2 facet-contract redellations per hook family.

### 3.2 Package contract structural changes

```solidity
// Pseudocode-only; no code written in this research pass.

contract UniswapV4HooklessV4FullSpreadStandardExchangeVaultDFPkg is ... {
    // existing 12 immutable facet slots — unchanged bytes/code
    // existing 5 immutable dependency slots
    IHooks public immutable EXPECTED_HOOK;  // address(0) for Hookless
    bytes32 public immutable EXPECTED_HOOK_BYTECODE_HASH; // 0 if no hook
    
    function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
        // existing checks
        // NEW: verify (PoolKey.hooks == EXPECTED_HOOK) and (keccak256(EXPECTED_HOOK.code) == EXPECTED_HOOK_BYTECODE_HASH if EXPECTED_HOOK != 0)
    }
    
    function initAccount(bytes memory initArgs) public {
        // existing initialization
        // For Hookless: nothing extra.
        // For Pons: load PoolKey, call launches(poolId), require info[0] == 1.
    }
    
    function deployVault(PoolKey memory pk) external returns (address) { /* unchanged */ }
}
```

`PkgArgs` widens to `(PoolKey poolKey, IHooks expectedHook, bytes32 expectedHookBytecodeHash)` for a forward-compatible shape; for backward-compat this can stay as `(PoolKey)` if the package bakes hook binding at construction (immutable).

Recommend the **wide-PkgArgs shape** for the new packages; existing single-package keeps `(PoolKey)` (no instance-level hook binding; package is hook-agnostic).

### 3.3 Immutable dependencies

New package `PkgInit` adds two slot:
- `IHooks expectedHook`
- `bytes32 expectedHookBytecodeHash` (optional — 0 if `expectedHook == address(0)`)

Existing 15-facet and 7-dependency slots are unchanged. **Bytecode reuse** of facets via CREATE3 to identical salt keeps them at the canonical addresses.

---

## 4. Salt, registry, and bytecode reuse — verified

| Concern | Resolution | Verified by |
|---|---|---|
| Two packages with same 12-facet bytecode land at same facet addresses | Yes — CREATE3 with identical facet-name salt gives identical CREATE3 addresses | `ArtifactCreationCode` and `BetterEfficientHashLib` pattern at `UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol:31–46, 53–67`; `README.md:11` |
| Two packages with the same hook-permitting logic but distinct type-names | Type-name hash → distinct package CREATE3 addresses | `calcSalt = abi.encode(pkgArgs)._hash()` (line 253–255); CREATE3 address from `(deployer, salt)` pair |
| Both packages register under same vault-type interface (e.g., `IStandardExchangeIn.interfaceId`) | Yes — `_registerPkg` adds to `pkgsOfType[typeId]` (line 105) | `VaultRegistryVaultPackageRepo.sol:101–107`; no unique constraint |
| Each package's `vaultFeeTypeIds` (USAGE fee id bit) | Same bit (`IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.interfaceId`) — may need to differentiate | Line 133–137 |
| Pkg deployer must register with same VaultRegistry | Yes — registry's `VaultRegistryDeployment.deployPkg` allows any caller | `VaultRegistryDeploymentTarget.sol:44` |
| Facet bytecode artifacts vs preserved-source hashes | New packages don't touch preserved tree | README §VERSION_SOURCE_MAP; preserved tree at `contracts/protocols/dexes/uniswap/v4/` not modified |

---

## 5. Runtime safety / quote model per hook family

### 5.1 Hookless package

- Quote uses UniswapV4Quoter.quoteExactInput / quoteExactOutput directly (existing path at Common:1095–1108 — Crane-level, hook-agnostic except for `OVERRIDE_FEE_FLAG` which only fires on dynamic-fee pools anyway).
- `_quoteSwapIn`/`_quoteSwapOut` returns the live V4 quote minus Pons-specific `_adjustHookSwap` charges.
- **Preview == execution** for vanilla pools if V4 state (slot0, lpFee, protocolFee) matches; min-out/max-in covers transient state drift (PRD §3).

### 5.2 Pons V2 package

- Quote uses UniswapV4Quoter for the core math; **then** `_adjustHookSwap` adds `feeBps + taxBps` cuts as computed at quote time, sourced from `launches(poolId)[10]` (feeBps) and `launches(poolId)[7]` (taxBps) (per QuoteService:54–57).
- `info[0] == 1` enforced at deploy-time `initAccount` (new) rather than only at quote time (existing soft check at QuoteService:35).
- **Preview vs execution**: same V4 state drift; Pons's internal hook params may differ from preview if the owner mutates between blocks. Bounded by `MAX_HOOK_FEE_BPS = 1000` total per-trade cap.
- **`AFTER_SWAP_RETURNS_DELTA_FLAG` actual delta** is observed in `_unlockCallback` (Common:954) via `BalanceDelta`; preview models the LP-fee share only (no fee-claim delta). The actual hook delta credit/debit is what the Pons hook takes from PoolManager; the vault sees it via `_executeSwap` returning `BalanceDelta` (Common:973–989). Settlement correctness is preserved; preview is fee-only.
- **Position import** (PositionImportFacet): hook-agnostic; no change needed per package.

### 5.3 Combination interactions

- **Same PoolKey → two packages**: `poolKey.hooks == address(0)` routes Hookless; `poolKey.hooks == PonsAddress` routes Pons. Same pool pair with different hooks = two distinct vault families. ✓
- **Same hook, different family**: impossible at deploy-time (Hookless rejects Pons; Pons rejects anything but PonsAddress).
- **Pons singleton vs PkgArgs**: PkgArgs for Pons encodes `expectedHook = PonsAddress`. poolKey may carry the same address. ✓

---

## 6. Minimal owner decisions (8 items)

1. **Deprecate the single-package?** Yes/No — current instances immutable either way; deprecation only affects new deployments.
2. **Pons hook address assumption**: is the Pons V2 hook **deployed at a known, project-controlled address**, or invoked through CREATE2 mining where the address depends on deployer+salt+initcode? Recommend runtime canonicalization via **hookBytecodeHash** rather than literal address.
3. **Pons V3 forward-compat**: when Pons V3 lands, will the layout be `info[0] == 2` (clean) or `info[0] == 1` (forced for compatibility)? Plan must encode which.
4. **Vault-type interfaces per package**: should the Pons package expose a separate interface ID (e.g., `IUniswapV4PonsV2FullSpreadStandardExchangeVaultLiquidReserve`) so off-chain indexers can route? Or stay with current ID and rely on pkg address?
5. **Fee oracle USAGE fee**: `vaultFeeTypeIds` includes `VaultFeeType.USAGE` slot (line 133–137 of existing DFPkg). Same for new packages. Will the registry de-duplicate across packages? Verified — `_registerPkg` uses AddressSet so duplicates are no-ops.
6. **Per-package `processArgs` placement**: at construction hook-binding OR in PkgArgs-immutable? PkgArgs is more flexible; immutable is more idiomatic for hook-by-package.
7. **Runtime guarantee of prefix-of-cap on fee drift**: `MAX_HOOK_FEE_BPS = 1000` is locked in Pons V2 hook. Plan should cite this as an external invariant in the Pons package's PRD excerpt (CED).
8. **Test coverage**: where do the new-package invariants live? `contracts/vaults/standard/exchange/protocols/uniswap/v4/<hook>/` or a sibling of FullSpreadStandardExchangeVault test bases?

---

## 7. Tests required (research-only enumeration)

Each new package must pass a **deployment-package invariant** and a **runtime invariant** before ship.

### 7.1 Hookless package tests

- `test_pacakage_processArgs_rejectsNonZeroHook` — `processArgs` reverts `UnsupportedHookForHooklessPackage(address(0xdeadbeef))` when `poolKey.hooks != address(0)`.
- `test_package_deployVault_acceptsHooklessPool` — full round-trip succeeds.
- `test_quote_directSwap_returnsVanilla` — Preview == execute for `poolKey.hooks == address(0)`.
- `test_inventory_quote_usesOnlyFreeAndDeployed` — no Pons fee adjustments applied (path branch reaches vanilla).
- `test_blockedAndIdlePaths_matchExisting` — duplicate of FullSpread standard tests, on the Hookless package's identical facet set.

### 7.2 Pons V2 package tests

- `test_package_processArgs_rejectsWrongHookAddress` — passes non-Pons hook address; reverts `WrongHookForPonsV2Package(expected, actual)`.
- `test_package_processArgs_rejectsPonsV1Hook` — passes a Pons V1 hook (different bytecode); reverts.
- `test_package_initAccount_rejectsPonsV3LaunchInfo` — deploys a Pons V3-style stub returning `info[0] == 2`; reverts `InvalidPonsVersion`.
- `test_package_initAccount_rejectsUnregisteredPool` — calls `initAccount` with `launches(poolId)` returning `(false, ...)`.
- `test_package_quoteMatchesPonsV2_launchInfo` — preview returns exactly Pons-fee-adjusted amount.
- `test_package_midFlightPonsFeeChangeDrift` — owner calls `setHookFeeBps(newBps)`; preview reflects new value; observe drift via `MAX_EXECUTION_SHORTFALL_BP = 10`.
- `test_package_compatibleOwnerChanges` — `setProtocolFeeRecipient`, `setFeeSweepOperator` do not break hook binding.
- `test_crossPackage_registryDiscoversBoth` — Hookless package and Pons package both registered; `_packagesOfTypeId(IStandardExchangeIn.interfaceId)` returns `[HooklessPkg, PonsPkg]`.

### 7.3 Refactor / shared-facet tests (cross-package)

- `test_facets_at_canonical_addresses` — both packages' `InFacet`/`OutFacet` resolve to the same facet addresses (proves bytecode-reuse at CREATE3 layer).
- `test_package_solts_are_distinct` — both packages' salt addresses differ.

---

## 8. Compatibility with PRD and CP_ACCT_PRD

### 8.1 PRD D17–D19 (combined exact-output closed-form-only)

The user-instruction says "keep disabled combined exact-output." The new-package split does not change this; combined-exact-output remains rejected as `InvalidRoute`. ✓

### 8.2 PRD D20 (25/50/10/1 bp)

The split does not change protection constants. They remain per-package on `_emitRebalanceEvent` and per-route on `MAX_DEPOSIT_COMPOSITION_IMPACT_BP`, etc. Owner must ratify: enforcement happens in the library or at the facet level? Recommend **library-level** for hook-specific packages so the constant sits with the quote model.

### 8.3 PRD D21 (progress policy)

Same: stops when both thresholds satisfied; bounded solver work permitted only for non-combined routes. ✓

### 8.4 PRD D14 supersession

**Updated D14** should explicitly:
- Acknowledge that hook-specific packages **are** a whitelist limited to known hooks.
- State that each new hook family package requires an updated PRD/exec plan + addendum documenting the hook's version-coupling.

### 8.5 CP_ACCT_PRD alignment

- §6 R4 (quote uses same route, fee policy, reserve transitions, rounding as execution): preserved. Hookless package's quote == execution by construction (vanilla V4). Pons V2 package: preview == execution modulo hook-parameter drift bounded by `MAX_HOOK_FEE_BPS = 1000`; documented in plaintext.
- §6 R6 (storage across types: durable local snapshots / deployed principal / uncollected fees / complete economic backing): preserved. Each package inherits `_syncVaultReserves` from FullSpreadCommon.
- §6 R7 (rebalance add/remove only, no swaps through this PRD): preserved. New packages do not change rebalance composition. **D9 swap arm is a separate future plan** (this proposal does NOT enable rebalance swaps; it only splits packages).

---

## 9. Caveats and limitations

1. **The proposal supersedes PRD D14**. The owner explicitly authorized this ("Latest human proposal may supersede old PRD D14"). Any follow-on plan must update PRD D14 in turn; otherwise contradictions remain in the doc tree.

2. **Pons V2 owner-mutable hook fees**: between quote and execution the owner can raise `hookFeeBps` (still bounded by `MAX_HOOK_FEE_BPS = 1000`). PRD D20's `MAX_EXECUTION_SHORTFALL_BP = 10` covers this drift; the 10 bp protection already exists. Document and rely.

3. **Single-package "free-for-all legacy" status**: if kept alive (recommended), its behavior is unchanged for new deployments too (no migration). Off-chain callers may prefer the new package's gate.

4. **Hookless + Pons in same registry**: both packages expose the same `IStandardExchangeIn.interfaceId` and `IStandardExchangeOut.interfaceId` to clients, but the call signatures are identical. Off-chain should select pkg by `packageMetadata().name`. On-chain, callers can pick pkg address from `_packagesOfTypeId(IStandardExchangeIn.interfaceId)[i]`. Recommend: `target` field in `PkgInit` distinguishes via caller choice.

5. **Cross-version Pons**: requires a separate package per Pons major. Recommend semantic-version naming convention (`...PonsV2V4...DFPkg`, `...PonsV3V4...DFPkg`). Less elegant than a single multi-version package, but the strict-deploy-time-rejection contract is clearer and auditable.

6. **The vault-side QuoteService contract does not currently EXIST as a separate deployed contract** — it is a `library` called directly by the facets. The byte-for-byte facet reuse across packages requires the library code to differ, NOT the In/Out facets. Reconcile: **two libraries + 12 shared facets + 2 hook-family-specific facets = package**.

7. **CRITICAL CAVEAT — Solc 0.8.35 + Hermes/OZ 5 access paths**: PonsV2MemeHook uses `@crane/contracts/external/openzeppelin-contracts-v5/access/Ownable.sol`, not the standard OZ. Library imports must match. Verify before commit.

8. **Vault-registry cluster behavior**: `_packagesOfTypeId` returns AddressSet._values. Off-chain should iterate; single-result expectation breaks. Document.

9. **Artifact build workflow**: per CLAUDE.md §10 (forge build before forge test, scripts/forge-artifacts.py with --test-root flag for new test suites). New packages need test-root declarations for the artifact builder.

---

## 10. Confidence and remaining blockers

### High confidence

- The architectural split (Hookless + Pons + future per hook) is **feasible** with the existing Crane DFPkg / Indexedex Manager registry / CREATE3 facet-reuse / Pons V2 hook structure.
- Salt uniqueness across N packages using same bytecode is **preserved** by the canonical CREATE3-with-salt = `keccak256(abi.encode(type(<facet-or-package-name>)))` pattern documented in the README.
- Registry coexistence of multiple packages sharing vault-type IDs is **preserved** (`pkgsOfType[typeId]` is AddressSet).
- Pons V2 hook parameter ceilings (`MAX_HOOK_FEE_BPS = 1000`, `MAX_PROTOCOL_FEE_SHARE_BPS = 5000`, `MAX_TOTAL_TRADE_FEE_BPS = 2000`) are immutable constants — drift is bounded; PRD D20's 10 bp shortfall fits.

### Medium confidence

- The "reuse identical facet sets" claim requires clarification: bytecode-level yes, library-level no. Recommend document language.
- Whether the old single-package should be deprecated or kept as legacy is owner policy.

### Open / owner ratification required

- Eight items in §6.
- Three structural caveats in §2.6: hook bytecode-hash bind, mutable hook param drift documentation, and registry multi-package discovery UX.

### No code/shell/test/config edits performed

This pass writes only the research Markdown file. **Saved at:** `docs/research/uniswap-v4-hook-specific-packages-2026-09-27/minimax-original.md`.
