# Astra — Hook-specific FullSpread packages, independent original

**Date/access date:** 2026-09-27. Research only. Read no peer artifacts for this round. No shell, tests, implementation, configuration edits, deployment or delegation. This document does not adopt or complete another round's proposed plan.

## Recommendation

**Yes: split admission into two explicit package products, but do not duplicate the whole vault implementation.** Start with a hookless FullSpread package and a package for one **identified Pons V2 hook deployment/revision and PoolManager**. Reuse the same core accounting/execution facets wherever their compiled code, constructor immutables, storage schema and quote model are compatible. Add future packages for separately reviewed integrations, not an unrestricted “anything claiming the Pons ABI” package.

This removes the obligation to quote arbitrary hook code from these two products. It does **not** automatically establish correct Pons quotes, static execution costs, immutable external behavior, correct factory identity or safe accounting. Those become finite, testable integration requirements.

The latest human proposal can supersede old PRD D14's open-admission/deployer-assurance policy for these new products. I do not reject it for that conflict. Record the scope change explicitly if adopted. Keep all unrelated owner law: combined exact-output-plus-rebalance remains disabled, 25/50/10/1 bp protections and maintenance progress policy stay, full local booking/pretransfer rules stay, and no old-tree edits or migration are authorized.

### Source shorthand

- **F/**: `contracts/vaults/standard/exchange/protocols/uniswap/v4/`.
- Within F, `DFPkg`, `Common`, `QuoteService`, `InTarget`, etc. abbreviate `UniswapV4FullSpreadStandardExchangeVault<suffix>.sol`.
- **PonsHook**: `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol`.
- **Z**: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`.

## 1. Verified architecture and safe facet reuse

**Facts:** F/DFPkg:71–92 stores immutable facet addresses and external infrastructure; :94–125 binds them from PkgInit and validates TWAP/PoolManager and nonzero WETH. Its `facetCuts` constructs the proxy's installed facets. The package and each vault are distinct contracts.

F/InTarget:32–35 embeds an immutable execution-delegate address. FactoryService:26–45 deploys the delegate and passes that address into the facet constructor. Thus two packages can safely point to the same facet address only if they deliberately share **that exact delegate binding**. Passing a different delegate through another package does not modify an already deployed facet's immutable.

Most live dependencies are accessed through the diamond's repositories, populated by DFPkg init. They can vary per vault while the facet address remains the same. In contrast, package immutables do **not** automatically become runtime facet configuration. Shared facets need a deliberately initialized, write-once per-vault compatibility profile, or a fixed package-specific quote facet/delegate. No normal-operation setter should exist.

**Selected design:**

1. A shared FullSpread core and package base; two separately named concrete DFPkgs, e.g. `UniswapV4HooklessFullSpreadStandardExchangeVaultDFPkg` and `UniswapV4PonsV2FullSpreadStandardExchangeVaultDFPkg`.
2. Package-fixed profile ID, expected hook (zero for hookless), expected hook runtime fingerprint for Pons, quote-model revision, and the existing infrastructure bindings. Define PkgInit/PkgArgs on interfaces.
3. Initialize the selected model/profile into isolated diamond storage; callers cannot choose an adapter or hook identity inconsistent with the package. Public getters expose package/profile/expected hook and model revision for discovery.
4. Reuse common facets. Initially the same quote implementation can dispatch only between `Hookless` and the pinned `PonsV2` model from that profile. No unknown-hook vanilla fallback. If later behavior requires different quotes or immutables, use different quote facets/delegates while retaining the common ERC20/accounting components.

Do not claim this is a trivial Solidity subclass of the present concrete DFPkg: its `packageName`, `processArgs`, `initAccount` and `calcSalt` are not declared virtual (DFPkg:166,253,257,271). A deliberate shared-base extraction or equivalent factoring is needed in the **new** tree. Avoid two copy-pasted accounting implementations.

Canonical Crane architecture requires Pkg structs on interfaces; Crane/IndexedEx testing requires actual registry-deployed proxy tests. These sources were read directly, as were CLAUDE.md, current family law and the current task PRD.

## 2. Identity must bind behavior, not just a hook flag mask

### Hookless package

Require `address(poolKey.hooks)==address(0)`, not merely zero hook permission bits. Validate currency order/tick spacing/fee encoding and manager binding. A hookless canonical V4 pool cannot use the dynamic-fee sentinel; reject such a key rather than mask its bits.

### Pons package

Require at least:

- `poolKey.hooks == EXPECTED_PONS_HOOK`, nonzero code.
- Exact reviewed hook revision and deployed runtime fingerprint, including its immutable substitutions; record chain, address, source/artifact provenance and proxy/upgradeability status.
- Hook `poolManager()` equals the package's PoolManager; TWAP manager and authorized PositionManager/import infrastructure bind to the same intended manager.
- The expected hook permissions, as a consistency check—not as proof of identity.
- For the configured PoolId, a registered launch with correct memecoin/quote-token orientation, fee bounds and known schema. Read actual per-pool terms rather than global future-launch defaults.
- Initialized pool state before activating or pricing a vault. Requiring this already at vault deployment is a separate lifecycle tightening; package specialization alone need not silently remove deployment-before-initialization if that behavior is retained.

**Evidence:** PonsHook inherits BaseHook (:40); its constructor binds PoolManager (:160–178). `lib/crane/.../v4/base/ImmutableState.sol:12–25` exposes an immutable `poolManager`. `PoolId` hashes PoolKey's five fields, **not PoolManager or chain**. Therefore a PoolId/metadata match alone does not establish the manager binding.

The current F/QuoteService:21–41 only recognizes a hook-address flag pattern plus a 13-word `launches` response. That permits an arbitrary contract to mimic the schema; it is not the new proposal's “specific hook” check. Do not use that heuristic as package admission.

Address equality binds an integration on the selected chain; it does not prove the contract is nonupgradeable or all external dependencies are immutable. A proxy's unchanged codehash does not pin its implementation. Recommend initially pinning the inspected **direct PonsV2MemeHook deployment**, not accepting a proxy/family-name/version-string claim. A different Pons revision or proxy deployment needs its own reviewed package profile.

## 3. CREATE3 identity is a concrete blocker to naive generic-package deployment

There are **three distinct identity layers**:

1. Facet/delegate CREATE3 address.
2. DFPkg contract CREATE3 address.
3. Vault proxy address deployed from that DFPkg and PkgArgs.

**Verified facts:**

- Current F/FactoryService:174–187 always uses `abi.encode("UniswapV4FullSpreadStandardExchangeVaultDFPkg")._hash()`. Different PkgInit, hook address or facet set does **not** alter that salt.
- `lib/crane/contracts/factories/create3/Create3Factory.sol:151–178` returns existing code at an occupied salt without rerunning its constructor. A second differently configured package deployment can silently return the first package unless binding verification rejects it.
- `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:44–52` forwards salt/initcode/args into CREATE3 then registers the returned package.
- Current salt law, `docs/create3-release-salt-input-correction.md:35–36,53–57`, requires name-only production component salts. It forbids constructor/code hashes and caller-supplied package namespaces as a workaround.

**Recommendation:** two named concrete package contracts get their own permitted name-derived salts, while referencing identical facets. For another Pons hook/version binding under the same factory, give the binding a distinct actual package/component identifier with a thin shared-base wrapper. Do not reuse the same package name with different constructor values and expect another instance. Do not silently reintroduce configuration-hashed salts. If the desired future product is arbitrary many same-contract/same-bytecode package configurations under one factory, that needs an explicit salt-policy extension, not a local workaround disguised as facet reuse.

Keep deployed/runtime fingerprints in validation manifests and assert all expected immutable bindings when reusing an occupied address. Fingerprints verify identity; they do not enter the salt.

### Proxy and registry uniqueness

`DiamondPackageCallBackFactory.sol:201–218` computes proxy salt as `keccak256(abi.encode(pkg, pkg.calcSalt(args)))`; F/DFPkg:253–255 hashes PkgArgs. Distinct **package addresses** therefore separate proxy addresses even with identical facets and args. Merely changing facet lists is not an independent proxy namespace if the DFPkg address/args are unchanged.

`VaultRegistryVaultPackageRepo.sol:39–49,75–106` registers packages by address, stores each name/fee types, and indexes **sets** of packages by interface type. Identical interface/facet sets are supported; they do not collapse distinct package addresses. But “first package supporting IStandardExchange” is no longer sufficient discovery. Consumers/UI must select the correct package identity/profile/manager/hook, not rely on interface IDs alone.

Keep the existing V4 usage-fee type and 20% default unless a separate fee policy is intended: F/DFPkg:132–136 ties policy to the liquid-reserve interface ID. A package naming split must not accidentally change sleeve defaults.

Also preserve delegatecall context: package `processArgs` and `initAccount` execute via the factory/proxy adaptor (`DiamondFactoryPackageAdaptor.sol:11–28`). Read package immutable values directly and write diamond storage intentionally; do not assume `address(this)` is the standalone package during validation/init.

## 4. Pons V2 parameters and quote model

The inspected implementation is specifically **PonsV2MemeHook**, Solidity pragma `^0.8.35`, not a promise covering every “Pons Family” revision.

Verified behavior:

- Permissions are beforeInitialize, afterSwap and afterSwapReturnsDelta only (PonsHook:184–200). `_beforeInitialize` permits the bound factory, not arbitrary callers; the SE must consume valid existing launch pools rather than assume it can initialize them.
- Global owner-controlled settings exist (:121–130 and setters beginning :239), but launch fee terms are snapshotted at registration (:355–403). Existing launch `hookFeeBps` and `creatorTaxBps` drive `_afterSwap` (:490–504), not the current global future-launch fee setting.
- Per-pool creator recipient and buyback enablement remain mutable (:415–437); authorized sweeps/buybacks can trade and change pool state. Pinning the hook does not freeze market state or every dependency.
- Hook fee is `floor(unspecifiedAmount*hookFeeBps/10000)` plus separately floored creator tax; the hook takes this amount and returns the matching delta (:480–524). It charges the output leg for exact input and input leg for exact output. Preserve each floor, denomination and call context.
- Own hook-originated internal swaps skip its own callbacks; vault-originated swaps do not (:485–488). Do not price vault calls as if the vault were the hook.

The current model's `hookFeeBps<=2000` test is looser than the inspected hook's `MAX_HOOK_FEE_BPS=1000`; total trade charge is bounded at 2000 (PonsHook:69–74,364–376; F/QuoteService:35–36). A pinned-version model should validate the actual revision's schema/bounds, not silently inherit a broad heuristic.

Both package models still include live directional protocol fees. `lib/crane/.../v4/utils/UniswapV4Quoter.sol:196–225` already combines LP/protocol fees and projects LP-only fee growth. Do not subtract hook charges from a formula that already incorporates them or credit hook/protocol proceeds as the vault's own LP recovery. Protocol fee changes are possible between actions; same-transaction callbacks do not confer universal fee constancy.

**Residual risk/inference:** With exact hook identity and a verified model, arbitrary-hook uncertainty is removed from admission. Quote/execution parity, integer floors, own-position fee recovery and callback settlement still require proof/tests. An immutable package selection cannot turn a wrong fee formula into a correct one. Leave actual-fill, impact, shortfall, reentrancy and local-booking checks intact. Remove the unknown-hook return-unchanged fallback for these new typed packages.

## 5. Deployment/runtime checks and tests

Enforce hook/profile validation centrally through package `processArgs` and before committing init state. Convenience `deployVault` is not the only authorized registry path. Constructor validates infrastructure and expected hook identity; per-vault init validates PoolKey/launch. Invalid profile/model combinations fail before funds or shares move.

NFT imports already compare the imported PoolKey with the vault's configured key (F/PositionImportTarget:48–69). Preserve this and verify the authorized PositionManager belongs to the same manager; matching PoolKey alone does not establish it across managers.

No dynamic-fee approval follows automatically from hook specialization. Hookless necessarily uses static core LP mode. Pin the Pons package to the actual launch fee mode supported by its selected revision/model; a future dynamic integration needs its own model. The previous static-only proposal and any additional 100%-fee admission rule must not silently become new approved law.

Minimum production-path test matrix:

1. Hookless accepts zero hook, rejects any nonzero hook; Pons accepts its exact address, rejects hookless, same-flags impostor, wrong manager, wrong revision/code and unregistered/wrong-token launch.
2. Both packages deploy through manager/registry, reuse the same intended facets, expose complete proxy selectors, and maintain isolated storage/credit.
3. Same factory/name with changed PkgInit returns old CREATE3 deployment; binding verification catches mismatch. Distinct concrete package names produce distinct addresses; identical package/args returns the same proxy, distinct package address gives distinct proxy. Never test only a fresh factory.
4. Changed immutable delegate dependencies cannot masquerade as reused facets; package metadata/profile discovery distinguishes both packages despite shared interfaces.
5. Pons two independently floored charges, zero/boundary fees, both currency directions, native/WETH, own LP recovery, protocol fees, launch-policy changes versus frozen pool terms, recipient/buyback changes and external sweep price movement.
6. Ordinary/transition/SY/Multi/import paths preserve accounting and quote behavior; blocked sleeve routes never nest unlock. Independent reference comparisons, not a model compared against itself.
7. Both packages reject the release-disabled combined exact-output branches consistently in previews/availability/execution, with no “known hook” exception. Approved 25/50/10/1 bp limits, 1 bp maintenance mismatch, sleeve deadband, safe incremental progress and immediate repeated calls remain tested.

## 6. Minimal owner decisions and remaining evidence

1. **Adopt typed-package admission** for the first two products, replacing older open-hook admission specifically there. Recommendation: yes, shared core and reusable facets, not two independent accounting implementations.
2. **Choose the exact Pons integration target:** chain, hook deployment address, reviewed source/runtime revision, PoolManager and required external dependencies. Recommendation: the inspected direct Pons V2 profile first; not generic family-wide acceptance. No exact production tuple was supplied or independently verified here.
3. **Multiple bindings under one factory:** recommendation is distinct thin named package contracts consistent with existing salt law. Only if the owner instead demands arbitrary same-contract configurations should a narrowly scoped name-only salt policy change be requested. No automatic constructor-hash or custom-salt exception is assumed.

Engineering can determine storage schema, model dispatch, discovery getters and factoring; it cannot invent the trusted deployment tuple or silently relax salt policy. No need to reopen enabled economics, combined exact-output closure, pretransfer, full booking or migration scope.

## Evidence and confidence

Context7 `/uniswap/v4-core` consulted first for PoolKey/PoolId/hook identity. Primary source fetched 2026-09-27: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/types/PoolId.sol . It confirms the hash includes key fields but not manager/chain; upstream main is not a deployment pin. Local code is the basis for Crane/registry and Pons findings.

Observed configuration in this retained session: Solidity 0.8.35, optimizer runs 1, via-IR false. Exact deployed hook/package bytecode, chain-specific addresses and dependency commit pins remain unverified. **High confidence** in architecture, immutable-binding and name-salt collision findings; **medium** in complete Pons integration coverage pending explicit target identity and production tests. No tests, security proof or economic-soundness claim is made.
