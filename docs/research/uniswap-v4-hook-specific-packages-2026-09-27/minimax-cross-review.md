# Cross-review — Hook-Specific Uniswap V4 Standard Exchange Vault Packages

Reviewer: MiniMax M3 (independent cross-review; peer cross-review artifacts not read this round)
Date / access date: 2026-09-27
User direction: package-specific identity + reuse; minimize disruption; correct errors explicitly.

**Saved path:** `docs/research/uniswap-v4-hook-specific-packages-2026-09-27/minimax-cross-review.md` (this file)
**Preserved unchanged:** `docs/research/uniswap-v4-hook-specific-packages-2026-09-27/minimax-original.md`

---

## 1. Final recommendations (concise)

| # | Recommendation |
|---|---|
| **R1** | **Adopt the family-package split.** Keep the existing `UniswapV4FullSpreadStandardExchangeVaultDFPkg` untouched (legacy free-for-all, additively deprecated as policy). Add two new separately-named concrete DFPkgs via CREATE3 (`name._hash()` salts). One initial package per approved hook family. |
| **R2** | **Pin Pons V2 by `(address == EXPECTED_PONS_HOOK) AND (codehash == <reviewed hash>) AND (hook.poolManager() == POOL_MANAGER)`** at `initAccount` and again at `processArgs`. Address alone misses replaced implementation; codehash alone accepts storage-changed forks. Both with manager binding are minimally required. |
| **R3** | **Per-family QuoteService libraries.** Two new libraries that hard-fail (no vanilla fallback) for non-matching hook signature. Hookless reverts unless `hooks == address(0)`; Pons reverts unless the pin above passes **and** `info[0] == 1`. The current `_adjustHookSwap` "return amount" fallback for `!supported` is removed (Astra §6 R5). |
| **R4** | **Don't enforce a global one-vault-per-pool-id.** Per DFPkg, identical PoolKey deploys an idempotent instance via `DiamondPackageCallBackFactory:215`. Across packages, the **pkg address is part of the proxy salt** (line 206: `salt = keccak256(abi.encode(pkg, salt))`), so the same PoolKey through two packages yields two distinct instances. Family-admission determinism is the rule; global dedup is not enforced or needed. |
| **R5** | **Static-fee structural validation inherited (R1 from last round).** Hookless package rejects `isDynamicFee(fee)`; Pons package pins `fee == 0` (Pons V2 fixture constant). The previous dynamic-fee reject need not be repeated per family; one package-wide rule suffices. |
| **R6** | **Keep D20/D21/D17–D19 verbatim in both packages.** No discretionary admin function that appends hook addresses. No new family without a new package deployment via manager registry. |
| **R7** | **Tests follow Kimi §5 + Astra §5 + Grok §"Tests".** Both packages: registry-deployed proxy tests, family-mismatch matrix, same-key idempotency, hook-bytecode pin, fee-bps freeze under owner mutation, D17–D19 `InvalidRoute` regression. |

Total owner decisions required: **0 explicit beyond "adopt".** The above assumes the latest owner direction supersedes PRD D14.

---

## 2. Behavior matrix (corrected against direct evidence)

| Claim | Verification (file:line) | Verdict |
|---|---|---|
| Package salt = `keccak256(abi.encode(type(...DFPkg).name)._hash())` | `UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol:181–184` | VERIFIED — all originals agree |
| Factory returns existing code at occupied salt without rerunning constructor | `lib/crane/contracts/factories/create3/Create3Factory.sol:151–178` (`if (predictedTarget.isContract()) return predictedTarget;`) | VERIFIED — Astra §3 correct; second deployment with same salt returns first deployment's address even with different constructor args |
| Instance salt = `keccak256(abi.encode(pkg, pkg.calcSalt(pkgArgs)))` via CREATE2 | `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218` | VERIFIED — pkg address IS part of instance salt |
| PoolId = `keccak256(poolKey, 0xa0)` (5-field; no manager/chain) | `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol:14–21` | VERIFIED — all originals agree |
| Facets deployed once via CREATE3 are idempotent by name-hash salt | `ArtifactCreationCode` pattern + `Create3Factory._create3` idempotency check (Create3Factory.sol:151–157) | VERIFIED |
| Same PoolKey through two packages targets the **same** instance address (Kimi §1) | DiamondPackageCallBackFactory.sol:206 (pkg in salt) | **REFUTED** — pkg address is in salt; same PoolKey through two packages yields two distinct proxy addresses |
| Same PoolKey through two packages targets **different** instance addresses (Grok §"What can be shared") | DiamondPackageCallBackFactory.sol:206 (pkg in salt) | **VERIFIED** — Grok correct |
| `info[0] == 1` is a version sentinel (MiniMax M3 Round-2 cross-review) | QuoteService.sol:35 `if (info[0] != 1 ...)`; PonsV2MemeHook.sol:48-67 (`bool registered` is field 0; ABI-encode of `true` yields `1`) | PARTIALLY CORRECT — semantically it's the `registered` bool check; coincidentally also a back-version guard for any re-layout that places a different 1-valued field first. Kimi's `info[0]=registered` is the strict naming. |
| Per-pool Pons fee terms frozen at `registerPool` (`AlreadyRegistered` reversibly-set guard) | PonsV2MemeHook.sol:48–67 (struct), 357, 389–403, 415–437 | VERIFIED — Kimi §2 / Grok §"Pons fees are per pool" agree |
| Mutable per-pool state: `setCreatorFeeRecipient` (onlyFactory), `setBuybackEnabled` (onlyFactory) | PonsV2MemeHook.sol:415–437 | VERIFIED — both originals cite this; affects fee distribution, not swapper quote |
| `_ponsHookFees` decodes 13-word `launches(bytes32)` ABI; verifies `info[0]==1 && info[1]<=1 && info[10]+info[7]<=2000` | `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:21–58` | VERIFIED |
| Existing FullSpread lacks `poolKey.fee` and `poolKey.hooks` checks in `initAccount` | `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:271–298` | VERIFIED |
| Existing FullSpread does NOT rely on per-package QuoteService injection; library is hardcoded in In/Out facet bytecode | Common.sol:239, 1092, 1108, 1134 | VERIFIED |
| Pons V2 is a singleton hook across all graduated pools | PonsV2MemeHook.sol:30 | VERIFIED |
| Pons V2 hook construction binds `poolManager()` immutably | PonsV2MemeHook.sol:160–178 | VERIFIED |
| `MAX_HOOK_FEE_BPS = 1000`; `MAX_PROTOCOL_FEE_SHARE_BPS = 5000`; `MAX_TOTAL_TRADE_FEE_BPS = 2000` are immutable | PonsV2MemeHook.sol:70–74 | VERIFIED |
| Per-launch mutable = swap distribution routing (`setCreatorFeeRecipient`, `setBuybackEnabled`); mutable globally = future launches only (`setHookFeeBps` etc.) | PonsV2MemeHook.sol:239–285 | VERIFIED — Grok §"Pons fees" / Kimi §2 agree |
| Vault registry maps multiple packages per vault type interface | VaultRegistryVaultPackageRepo.sol:101–107 (`pkgsOfType[typeId]._add(pkg)`) | VERIFIED |
| `processArgs` returns existing instance for same `(pkg, pkgArgs)` | DiamondPackageCallBackFactory.sol:215–217 (`if (expectedProxy.isContract()) return expectedProxy;`) | VERIFIED |
| Vault instance deployment via `DiamondPackageFactory.deploy` not CREATE3 for proxy | DiamondPackageFactoryAwareRepo + line 74-75 of VaultRegistryDeploymentTarget.sol | VERIFIED — proxy is CREATE2 (not CREATE3) |
| Old single-package PkgInit has no `requiredHook` field | IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:22–45 | VERIFIED |

---

## 3. Explicit corrections

### 3.1 Kimi: instance address across packages

> "the **same** `PoolKey` deployed through two packages targets the **same** instance address"

**WRONG.** Direct verification of `DiamondPackageCallBackFactory.sol:201–218`:

```
salt = keccak256(abi.encode(pkg, salt));
```

The **pkg address is part of the salt**. Same PoolKey (same `calcSalt(pkgArgs)`) through two different packages (different pkg addresses) → two different `salt` → two different `expectedProxy` (line 207–214) → two different CREATE2 addresses. **No collision possible.**

Kimi's mitigation "exact-equality-only is the mitigation" was right on the merits (family admission determinism is what makes collision impossible), but for the wrong reason. The actual protective mechanism is the pkg address itself.

### 3.2 Kimi: identity convention

> "single DFPkg artifact + `requiredHook` in `PkgInit` + discriminated salt strings (recommended)"

Kimi suggests **one contract name** with `requiredHook` as a PkgInit field, vs. **distinct contract names**. The user direction is "package-specific identity and reuse." The minimally-disruptive answer is **separate contracts** because (a) the InFacet/OutFacet hardcode the QuoteService library at compile time, so two families NEED two facet bytecodes — Kimi's path doesn't solve this without also building an indirection layer; (b) CREATE3 salts tied to type-name hashing make a separate contract name give a separate CREATE3 address without any salt-string hack; (c) consistent with the existing Crane DFPkg pattern (PkgInit/PkgArgs on interfaces, salt = name).

**Kimi's path is viable but adds a strategy layer.** Grok's "Prefer two quote facets" combined with separate contracts aligns with the user's intent.

### 3.3 Astra: create3 idempotent return — confirmed but mis-framed

Astra §3 is correct in substance (the CREATE3 factory returns existing addresses without rerunning the constructor), but Astra frames this as a CREATE2-vs-CREATE3 concern. The actual mechanism is CREATE3 itself: `_create3` and `_create3WithArgs` (Create3Factory.sol:151–178) check predicted address and short-circuit. This is **by design** (idempotent factory deploy), not a bug. The risk Astra flags is real but only if the **same salt is used twice** with different construction args. The package-salt law (name-only) prevents this at the `FactoryService` layer; bundling initcode hash into the salt would be a workaround.

### 3.4 Grok: facet bytecode reuse vs compilation coupling

Grok §"What can be shared" is correct on the distinction:

- ERC20/ERC5267/ERC2612/StandardVault/MultiAssetBasic/MultiAssetStandard/LiquidReserve facets are hook-agnostic — shareable verbatim.
- InFacet, InQueryFacet, OutFacet, OutQueryFacet call QuoteService directly — must be re-delivered per family because the library reference is compiled in.
- Out/Out multi-facets indirectly call QuoteService through base — must be re-delivered per family.
- PositionImport facet is hook-agnostic via `PositionImportTarget`.

So **12 facets are reusable by CREATE3 identity (same name → same address) and 3 facets (or thereabouts) must be re-delivered per family**. The In/Out/Query facets have to be `*PonsV2FullSpread…` and `*Hookless…` variants. Grok's "Prefer two quote facets" is correct.

### 3.5 Old single-package preservation

All three originals propose superseding D14 but **do not propose explicit deprecation of the legacy single package**. The minimally-disruptive answer is to leave the legacy DFPkg untouched. Immutable instances already deployed via it continue to function (preserves CLAUDE.md non-negotiable 5: "instances immutable after deploy"). The legacy package continues to register new vaults with any hook — its semantics don't change retroactively. New packages sit alongside as siblings.

### 3.6 Vesting of the legacy package

Astra §3 prefers name-derived salts for new packages (correct). Kimi §"recommendation 2" calls for either "single DFPkg artifact + `requiredHook`" or "distinct contract names." The minimal-disruption path is **distinct contract names** because:

- It uses the existing salt law without change.
- It does not require modifying `IUniswapV4FullSpreadStandardExchangeVaultDFPkg` PkgInit (which would be ABI-breaking — see risk below).
- It does not require adding a strategy layer in the InFacet/OutFacet bytecode.
- Legacy package bytecode is unchanged.

### 3.7 ABI-additivity of `PkgInit` for new family packages

A new family DFPkg has its own interface `IUniswapV4HooklessV4FullSpreadStandardExchangeVaultDFPkg` (or similar) with a wider PkgInit. **This is additive**: it does not modify the existing PkgInit on the legacy package. New v4 family packages may add `IHooks requiredHook`; the existing package's PkgInit does NOT need to grow. ✓

---

## 4. Minimally-disruptive concrete architecture (recommended)

### 4.1 Files to add (NEW; legacy tree untouched)

```
contracts/vaults/standard/exchange/protocols/uniswap/v4/
├── UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol           [existing — UNTOUCHED]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultDFPkg.sol [NEW]
├── UniswapV4PonsV2V4FullSpreadStandardExchangeVaultDFPkg.sol   [NEW]
├── UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol     [existing — UNTOUCHED]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultQuoteService.sol [NEW]
├── UniswapV4PonsV2V4FullSpreadStandardExchangeVaultQuoteService.sol   [NEW]
├── interfaces/
│   ├── IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol [existing]
│   ├── IUniswapV4HooklessV4FullSpreadStandardExchangeVaultLiquidReserve.sol [NEW]
│   └── IUniswapV4PonsV2V4FullSpreadStandardExchangeVaultLiquidReserve.sol   [NEW]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVault_Component_FactoryService.sol [NEW]
├── UniswapV4PonsV2V4FullSpreadStandardExchangeVault_Component_FactoryService.sol   [NEW]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultInFacet.sol        [NEW]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultInQueryFacet.sol  [NEW]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultOutFacet.sol       [NEW]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultOutQueryFacet.sol [NEW]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol [NEW]
├── UniswapV4HooklessV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol [NEW]
└── ... analogous files for PonsV2 family
```

### 4.2 What is unchanged

The legacy single-package code is preserved. Existing instances continue to function. No migration, no ABI-breaking change to legacy PkgInit.

### 4.3 What is reused (CREATE3 idempotency)

Facets that DO NOT call QuoteService hardcode remain at their existing CREATE3 addresses when redeployed through the new package's FactoryService. Concretely:

| Facet | Reusable across families? |
|---|---|
| ERC20_FACET | ✅ (CREATE3 by name → same address) |
| ERC5267_FACET | ✅ |
| ERC2612_FACET | ✅ |
| MULTI_ASSET_BASIC_VAULT_FACET | ✅ |
| MULTI_ASSET_STANDARD_VAULT_FACET | ✅ |
| `*InFacet` | ❌ (references QuoteService) |
| `*InQueryFacet` | ❌ (references QuoteService) |
| `*OutFacet` | ❌ |
| `*OutQueryFacet` | ❌ |
| `*PositionImportFacet` | ✅ (uses PositionImportTarget, no QuoteService) |
| `*LiquidReserveFacet` | ✅ (no QuoteService) |
| `*InMultiFacet` | inherit from InFacet calls, must be re-delivered |
| `*InMultiQueryFacet` | same |
| `*OutMultiFacet` | same |
| `*OutMultiQueryFacet` | same |

So: ~5 facets + multi-facets are family-specific (~9 per family), and 5 are shared.

### 4.4 Salt assignment (canonical, name-derived)

```
UniswapV4FullSpreadStandardExchangeVaultDFPkg         → legacy salt
UniswapV4HooklessV4FullSpreadStandardExchangeVaultDFPkg → new salt via name hash
UniswapV4PonsV2V4FullSpreadStandardExchangeVaultDFPkg   → new salt via name hash
```

Different type names → different CREATE3 addresses automatically. No salt-string hack needed.

### 4.5 Hook binding at instance init (Pons V2 package)

`PonsV2V4InitAccount` (pseudocode):
1. Decode PkgArgs: `(PoolKey poolKey, address expectedHook, bytes32 expectedHookCodehash, address expectedHookPM)`.
2. Verify `poolKey.hooks == expectedHook`. Revert `HookFamilyMismatch(expected, actual)`.
3. Verify `expectedHook.codehash == expectedHookCodehash`. Revert `HookCodehashMismatch`.
4. Verify `IPoolManager(expectedHook.poolManager()) == POOL_MANAGER`. Revert `HookPoolManagerMismatch`.
5. Verify `poolKey.fee == 0` (Pons V2 fixture constant). Revert `WrongStaticFee`.
6. Verify `!LPFeeLibrary.isDynamicFee(poolKey.fee)` (inherited from R1).
7. Verify Pons 13-word decode succeeds + `info[0] == 1` + `info[10] + info[7] <= 2000`. Revert `PonsDecodeMismatch`.
8. Verify `info[2]`/`info[3]` match `key.currency0`/`currency1` per `info[1]` layout. Revert `CurrencyOrientationMismatch`.
9. Existing init continues (token initialization, approvals, ERC20/EIP712 init).

`PonsV2V4ProcessArgs` (pseudocode):
1. Existing checks (registry caller, TWAP-PoolManager match).
2. Add: `poolKey.hooks == expectedHook` check (re-rejected even if registry passes; defense in depth).
3. (Optional) Run `_ponsHookFees` to surface a cleaner error early.

### 4.6 Hook binding at instance init (Hookless package)

`HooklessV4InitAccount`:
1. Decode PkgArgs: `(PoolKey poolKey)`.
2. Verify `address(poolKey.hooks) == address(0)`. Revert `UnsupportedHookForHooklessPackage(poolKey.hooks)`.
3. Verify `!LPFeeLibrary.isDynamicFee(poolKey.fee)` and `LPFeeLibrary.isValid(poolKey.fee)`. Revert `DynamicFeePoolUnsupported` / `LPFeeTooLarge`.
4. Existing init continues.

`HooklessV4ProcessArgs`: same hook/fee checks re-applied for defense in depth.

### 4.7 Legacy single-package preservation

The legacy `UniswapV4FullSpreadStandardExchangeVaultDFPkg` continues to:
- Accept any `PoolKey` (`initAccount` does no hook check).
- Use a single QuoteService library (the existing one) with the `_adjustHookSwap` "return amount" fallback for non-Pons hooks.

This is the ONLY package that retains vanilla-amount fallback. New family packages do NOT have the fallback.

### 4.8 Registry discovery

`_registerPkg` already supports multiple packages per `vaultType` interface ID. New packages register under the same interface IDs (`IStandardExchangeIn`, `IStandardExchangeOut`, etc.). `pkgsOfType[typeId]` returns both old and new packages.

Off-chain indexer must filter by `IStandardVaultPkg(pkgAddress).name()` or `requiredHook()` (new public getter) to route to the correct package for a given PoolKey.

---

## 5. Dissent + open items

### 5.1 Resolved dissent

| Topic | Original disagreement | Resolution |
|---|---|---|
| Same-poolkey-different-packages instance collision | Kimi: same address (wrong) vs Grok: different addresses (right) | **Grok correct**, verified at `DiamondPackageCallBackFactory.sol:206` |
| Salt policy for new packages | Kimi: PkgInit field + salt strings; Astra: name-derived | **Astra correct** (canonical, matches existing law) |
| QuoteService library sharing | Grok: two quote facets per family; Kimi: one contract with dispatch | **Grok correct** (existing InFacet/OutFacet hardcode library; can't share bytecode) |
| Hook version identification | All: bind address + (codehash or family); divergence on registry `info[0]` semantic | **info[0] == 1 is `registered` bool** (Kimi naming correct); add explicit codehash pin (Grok + Astra correct) |

### 5.2 Unresolved (require owner sign-off; listed for completeness, NOT new owner questions)

These were raised in the originals; they're not new from this cross-review, but their resolution is not in scope for this pass:

1. **100%-fee static fee**: reject as a separate product error (Astra) vs. accept and document infeasibility. NOT BLOCKED by this proposal — both packages inherit the policy from the previous round.
2. **Multi-package per vault-type discoverability**: registry already supports it; off-chain indexer change is a documentation task.
3. **Storage schema difference between legacy and new packages**: new packages use a different `MultiAssetBasicVaultRepo` slot string (per Crane convention). Distinct storage namespaces are automatic; no collision.
4. **Pons V3 forward-compat**: per-package-fingerprint deployment, controlled by owner workflow — no code change.

### 5.3 Blocker items

**None.** Recommendation R1–R7 do not require any new owner decision beyond "adopt"; the "minimally-disruptive" path preserves all existing code paths.

---

## 6. Caveats

1. **CREATE3 salt return idempotency**: Create3Factory.sol:151–178 returns existing addresses without re-running constructor. Two deployments with same salt = same address. Implication: a future package must use a distinct type name (and thus distinct CREATE3 salt) — verified that current `FactoryService` derivations use the name hash.
2. **`info[0] == 1` is a `registered` bool, NOT a version sentinel**. A Pons V3 hook that maintains the same LaunchInfo struct layout and bool-encoding would still pass this check. Mitigation: the **codehash pin** (`expectedHookCodehash`) is the actual version check. The `info[0] == 1` check is a sanity assertion that the launch is **registered**.
3. **Mutable Pons parameters at runtime** (Pons's `setHookFeeBps` etc.) only affect **future** launches; per-pool terms remain immutable. The Pons package's quote remains stable across preview/execution for a given pool.
4. **Cross-chain family identity**: each chain's Pons hook and PoolManager must be confirmed before deploying the family package. The package's immutable bindings handle this at construction.
5. **Per-package facet bytecode bytes**: each new facet set adds ~24 KB × 9 family-specific contracts. Within `24,576` runtime byte limit per CLAUDE.md.
6. **The legacy single-package semantics unchanged**. There is no automatic migration or deprecation of vaults deployed via it; new deployments on it remain free-for-all with the existing quote model.
7. **`PoolId` includes the hook address** (PoolId.sol:16–21 hashes all 5 fields including `hooks`). Two pools that differ only by hook are distinct PoolIds, so the registry's instance-salt-excludes-PoolId design (DiamondPackageCallBackFactory.sol:201–206) does not cause cross-package collision within the same pool.

---

## 7. Saved path

`docs/research/uniswap-v4-hook-specific-packages-2026-09-27/minimax-cross-review.md` (this file).
`docs/research/uniswap-v4-hook-specific-packages-2026-09-27/minimax-original.md` preserved unchanged.

No code, shell, test, config, or delegation performed. No peer cross-review artifacts read.
