# Grok — Cross-review: hook-specific FullSpread packages

**Date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). Peers read: Astra, MiniMax M3, Kimi K3 originals only. Untrusted evidence. No earlier cross-reviews. Originals preserved.

## Corrections

| Claim | Who | Verdict |
|---|---|---|
| Same PoolKey through two packages hits one instance address because salt excludes the package | Kimi §1, citing `IVaultRegistryDeployment.sol:60` | **Wrong path.** That comment is only on `deployHookVault`. SE vaults use `VaultRegistryDeploymentTarget.deployVault` → `DiamondPackageCallBackFactory.deploy`. The implementation, not the comment, sets `salt = keccak256(abi.encode(pkg, pkg.calcSalt(args)))` (`DiamondPackageCallBackFactory.sol` 201–206). Different package addresses yield different proxies for the same args. |
| CREATE3 re-use reverts | Kimi, citing `Bytecode.sol` | **Not the registry path.** `Create3Factory._create3WithArgs` returns existing code and does not rerun the constructor (`Create3Factory.sol` 161–178). Astra is right. Reusing `"UniswapV4FullSpreadStandardExchangeVaultDFPkg"` with new constructor args silently returns the first package. |
| Same facet name salt can host two quote libraries | MiniMax §2.3 and §3.1 | **Contradictory.** A different QuoteService compiled into `InFacet` is different bytecode. The occupied facet salt returns the first bytecode. Per-family quote facets need **new facet type names and salts**, or one shared facet whose source no longer has a vanilla fallback. |
| `info[0]` is a Pons version and must be 2 for V3 | MiniMax §1.3, §6.3 | **False.** `LaunchInfo` field 0 is `bool registered` (`PonsV2MemeHook.sol` 48–49). ABI `true` is 1. `QuoteService.sol` 35 `info[0] != 1` means “not registered,” not “schema version.” Field 7 is `creatorTaxBps`; field 10 is `hookFeeBps`. MiniMax swapped those. |
| `setHookFeeBps` after launch changes the quoted pool fee | MiniMax §2.6, test `midFlightPonsFeeChangeDrift` | **False for registered pools.** The setter writes the global default (`251–254`). `afterSwap` reads `launches[poolId].hookFeeBps` (`490–503`). `AlreadyRegistered` blocks a second snapshot (`357`). |
| All 15 facets are reusable with the current vanilla fallback left in place | Kimi §1, §4 | **Only after the fallback is removed.** `QuoteService.sol` 55 still returns the vanilla amount for an unknown hook. Shared facets are fine once that branch reverts and each package admits only its hook. |
| Grok original: ask the owner for one vault per PoolId | Grok original decision 3 | **Withdrawn.** Package address already namespaces instances. A global uniqueness rule is an extra product constraint the user did not ask for. |

## Consensus

- Split admission into a hookless package and a Pons V2 package. Do not clone accounting.
- Distinct package contract names and name-derived CREATE3 salts. Do not change the salt law to hash constructor args.
- Reuse facets whose bytecode does not embed a conflicting hook model. `InTarget.sol` 32–35 bakes one execution-delegate address. Sharing that facet address shares that delegate. That is acceptable because the delegate is hook-agnostic.
- Pin this hook, not the family name: `PonsV2MemeHook`, permissions `beforeInitialize + afterSwap + afterSwapReturnDelta` (`184–200`), same `poolManager()` as the package (`DFPkg.sol` 113–120; hook constructor `160–165`).
- Swapper-visible Pons bps are frozen per pool. Creator recipient and `buybackEnabled` remain mutable (`415–437`) and do not change the bps.
- D17–D19, D20, and D21 stay. No admin list of extra hooks. No old-tree migration.
- D14 may be superseded for these packages: unsupported hooks are rejected at init, not accepted on deployer assurance.

## Minimum architecture

1. Add two named packages, for example `UniswapV4HooklessFullSpreadStandardExchangeVaultDFPkg` and `UniswapV4PonsV2FullSpreadStandardExchangeVaultDFPkg`. Each gets `abi.encode("<that contract name>")._hash()` as its `deployPkg` salt. Leave the existing FullSpread package salt untouched so the first deployment is not silently reused.
2. Cut the same existing facet and delegate addresses into both, after one quote-library change: unknown hooks revert. Do not compile a second InFacet under the same facet-name salt.
3. Package immutables hold the expected hook (`address(0)` or the pinned Pons address) and the reviewed runtime codehash. `processArgs` / `initAccount` require `poolKey.hooks == expectedHook`, codehash match, and `hook.poolManager() == POOL_MANAGER`. Those functions run by delegatecall; read package immutables from the package code, and write only diamond storage (`DiamondFactoryPackageAdaptor.sol` 11–28).
4. Pons package also requires a registered `launches(poolId)` whose words 7 and 10 are the tax and hook fee, sum `<= 2000`. Do not treat word 0 as a version. Also require `poolKey.fee == 0`, because this factory reverts otherwise (`PonsV2LaunchFactory.sol` 1497). That is a check against this revision, not a new fee policy.
5. Do not add a registry-wide one-vault-per-pool rule. Document that each package may deploy its own proxy for the same PoolKey.
6. Keep measured fills, 25/50/10/1, D21 progress, and `InvalidRoute` for combined exact-output on both packages.

## Unresolved dissent

- Astra and Kimi want a separate owner choice of the production hook address tuple. No address was supplied in this round. The check is specified; the chain address is a deploy input, not a new economic rule. Do not block the architecture on it.
- Astra wants initialized-pool proof at first pricing, not necessarily at package admission. Agree. Do not add it as an owner question.
- MiniMax’s eight owner questions (deprecate old package, Pons V3 layout, new interface ids, fee-drift UX) are not required. Adoption of the two named packages answers them: old salt stays frozen, a new hook revision is a new package, shared interface ids are already allowed, and registered Pons trade bps do not drift.

**Saved:** `docs/research/uniswap-v4-hook-specific-packages-2026-09-27/grok-cross-review.md`
