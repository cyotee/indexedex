# Migration DETF ownership and package contract

Date: 2026-11-10. **Source-backed preflight, not implementation acceptance.**
Scope: plan MIG-P11/P12, sections 2, 4, 6/6.1, task 3, and the ownership/composition boundaries of task 7.

All source paths below resolve under `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03/`; `lib/crane/` is the shared, read-only dependency. For compact source references:

- `D/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- `C/` = `contracts/vaults/detf/common/`
- `K/` = `lib/crane/contracts/`
- `R/` = `contracts/registries/vault/`
- `T/` = `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- Proposed `M/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`

## 1. Decision and evidence boundary

The smallest implementation is a **distinct registered Migration parent package** with compatible base arguments, explicit proxy owner and buffer arguments, the existing Crane Ownable facet, and immutable references to the Migration-aware child composition. Reuse compatible facets and narrowly extract ordinary initialization, rather than subclassing/copying the concrete ordinary package or changing ordinary ownership policy.

This is an engineering proposal derived from the complete main-checkout `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, not a new owner-policy decision. The r20 PRD's MIG-R41 and MIG-AC46/47 supply the ownership requirement; MIG-P12 overrides its obsolete “price setting” wording. Ordinary unowned-DETF law remains unchanged outside Migration.

Phase-one `migration/evidence/phase01-verification.md`, section 6, permits independent ownership/bootstrap work but does not establish fungible authenticated attribution or TokenStaking atomic handoff. Phase-two `migration/pricing/evidence/verification/report.md`, sections 1-3, confirms only a bounded pricing fixture, not actual-recovery E3. Neither report is an implementation or issuance approval. This report specifies no fungible attribution tuple, verifier, loader schema or substitute eligibility policy.

## 2. Observed Ownable contract: buffer is not an acceptance delay

| Source observation | Exact evidence | Migration consequence |
| --- | --- | --- |
| One canonical proxy-storage namespace contains owner, pending owner, confirmation flag, configured buffer and buffer end. | `K/access/ERC8023/MultiStepOwnableRepo.sol:30-45` | No parallel `migrationOwner`, cached administrator or facet/package owner authority. |
| `_initialize` merely writes owner and buffer; it checks neither zero owner nor prior initialization. | `K/access/ERC8023/MultiStepOwnableRepo.sol:83-98` | Migration package must reject zero and enforce once-only account initialization itself. |
| Authorization compares `msg.sender` to current stored owner. | `K/access/ERC8023/MultiStepOwnableRepo.sol:111-125` | Every retained harvest and removable administration operation uses this check, not creator, fee recipient, pending owner or transaction origin. |
| Initiation requires current owner, records pending owner, and computes `now + configuredBuffer`. It does not clear an existing confirmation flag. | `K/access/ERC8023/MultiStepOwnableRepo.sol:158-177` | Preserve current Crane behavior; do not infer authority from `preConfirmedOwner`. Replacing a pending transfer needs a characterization test. |
| Confirmation requires current owner, elapsed buffer and matching pending address. Cancellation clears all pending state. | `K/access/ERC8023/MultiStepOwnableRepo.sol:189-242` | Buffer applies to confirmation. Test both sides of its exact boundary. |
| Acceptance checks only that caller equals pending owner, then replaces owner and clears pending state. No confirmation or time check occurs. | `K/access/ERC8023/MultiStepOwnableRepo.sol:253-274`; target forwards directly at `K/access/ERC8023/MultiStepOwnableTarget.sol:54-56` | A pending owner can accept immediately after initiation and then becomes current owner. It has no administration authority **before acceptance**, even if the buffer has elapsed or confirmation exists. |
| `preConfirmedOwner` is conditional on the flag; buffer getter returns the stored duration. | `K/access/ERC8023/MultiStepOwnableRepo.sol:334-379` | These are observations, not substitutes for `owner()`. |
| Existing facet exposes exactly eight ownership/query/transfer selectors and no initializer/cut. | `K/access/ERC8023/MultiStepOwnableFacet.sol:43-68` | Install the real facet and `IMultiStepOwnable` declaration; do not implement a new transfer protocol. |

**Proposed initialization:** interface-owned Migration `PkgArgs` contains `IUniswapV4Detf.PkgArgs baseArgs`, `address owner`, and `uint256 ownershipBufferPeriod`. The duration is explicit deployment data; no hardcoded operational delay, nonzero-buffer requirement or new minimum is inferred. Decode canonically; reject zero owner in argument processing and again in account initialization. Keep all base fields unchanged.

Run canonical base initialization, including its once-only core initializer, and initialize `MultiStepOwnableRepo._initialize(owner, ownershipBufferPeriod)` in that same proxy delegatecall. `D/UniswapV4DetfRepo.sol:98-110` rejects an already populated hook before rewriting core state. Preserve that guard on **every** Migration initializer path, with no reset/alternate initializer. Any repeated invocation must revert the entire transaction, including metadata/policy/owner writes; do not rely on Ownable's initializer as the guard. Do not install package/factory initializer selectors on the proxy. This adds no separate owner variable and needs no global Crane repair.

Contract owners are accepted: the observed guard is address equality, not an EOA/code-size/signature test. A contract must actually call the proxy to administer or accept; merely naming a contract owner does not grant its external caller authority.

## 3. Arguments, salts and distinct registration

**Observed base contract.** `D/interfaces/IUniswapV4Detf.sol:32-55` defines metadata, hook/liquidity policy, creation/opening rates, thresholds/expansion, creator, child metadata and four route tables; it has no administrative owner. Package `PkgInit` at `:185-198` supplies facets, fee oracle, registry and children. `D/UniswapV4DetfDFPkg.sol:53-98` stores these as immutable package dependencies; `:197-217` rejects noncanonical encodings and checks registry caller, hook shape and liquidity policy. Hook self-leg and hook ownership are checked during initialization (`:223-232`).

The hook's owner is the **DETF proxy**, not Migration's administrative owner: `D/UniswapV4DetfProcessArgsLib.sol:50-62`. Preserve this distinction and `ownerOnlyLiquidity`; transferring Migration administration must not transfer hook ownership to the new human/contract administrator.

**Proposed salt contract:**

```text
decode canonical Migration PkgArgs
set only baseArgs.hook = address(0) in the salt copy
packageSalt = keccak256(abi.encode(the complete modified Migration PkgArgs))
```

Thus owner, buffer, creator, metadata, policies and all route tables remain in salt material. Preserve deliberate hook exclusion, not exclusion of ownership or child metadata. `D/UniswapV4DetfDFPkg.sol:197-207` is the ordinary precedent. Factory CREATE2 then hashes `(packageAddress, packageSalt)` (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-230,327-329`), separating ordinary/Migration packages as well as two owners.

Prediction precedes hook construction because the hook embeds the predicted DETF as self-leg and owner; the concrete fixture does exactly this at `D/TestBase_UniswapV4Detf.sol:289-331`. Changing owner requires a newly predicted proxy and its own correctly wired hook. Do not attempt to reuse a hook whose self-leg/owner belongs to the first proxy.

Use a new package name, Migration product interface/type declaration and artifact release salt keyed to `UniswapV4DetfMigrationDFPkg`, not the ordinary package's release key. Preserve compatible standard interfaces and usage-fee classification; do not falsely advertise an ordinary-only product interface after replacing its callable semantics. The ordinary declaration/cuts are at `D/UniswapV4DetfDFPkg.sol:104-195`.

The new package factory must mirror `D/UniswapV4Detf_Pkg_FactoryService.sol:16-31`: load concrete artifact bytecode, encode interface-owned `PkgInit`, and call the manager's `IVaultRegistryDeployment.deployPkg`. Component facets use CREATE3 artifact helpers like `D/UniswapV4Detf_Facet_FactoryService.sol:19-84`. No new manager facet is required merely to add a typed internal FactoryService.

**Actual authority chain:**

1. Registry `deployPkg` requires registry owner/operator, creates via CREATE3, and registers declaration (`R/VaultRegistryDeploymentTarget.sol:44-52`).
2. Parent package `deployVault` calls its immutable registry (`D/UniswapV4DetfDFPkg.sol:100-102`).
3. Registry allows owner/operator/**any registered package**, requires requested package registered/enabled, deploys through callback factory and records `vaultConfig` (`R/VaultRegistryDeploymentTarget.sol:64-76,141-158`). It does not require caller package to equal requested package.
4. Registry records package names/types by package address and vaults in address sets, not a unique owner/content slot (`R/VaultRegistryVaultPackageRepo.sol:74-114`; `R/VaultRegistryVaultRepo.sol:92-149`).

Consequently permissionless use of the registered package helper does not make its caller the Migration owner. `owner` must come from explicit validated deployment arguments, not `msg.sender` as observed inside registry/factory/delegatecall. No extra owner-signature deployment policy is added.

## 4. Init, child wiring and restoration boundaries

**Observed call context.** Factory `deploy` delegatecalls package `processArgs`, so its `msg.sender` remains the registry; it records `(pkg,args)` before constructor deployment (`K/factories/diamondPkg/utils/DiamondFactoryPackageAdaptor.sol:17-33`; factory `:217-230`). Proxy constructor delegatecalls factory initialization (`K/proxies/MinimalDiamondCallBackProxy.sol:29-36`; `K/factories/diamondPkg/utils/FactoryCallBackAdaptor.sol:16-20`). Factory obtains context from its own `pkgConfig` and applies base/package cuts before delegatecalling package init (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:347-399`). The context mappings persist (`:159-167,410-413`); they are **not** a one-use replay guard.

Factory base cuts install ERC165, loupe, only ERC8109 `functionFacetPairs`, and a temporary post-deploy hook; not generic diamondCut, update or delegatecall selectors (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:263-312`). ERC8109 introspection reads routing only (`K/introspection/ERC8109/ERC8109IntrospectionTarget.sol:13-20`).

The temporary hook is consequential: it delegatecalls its **caller** as a package (`K/factories/diamondPkg/PostDeployAccountHookFacet.sol:20-23`). Parent post-deploy first uses it for child wiring, then factory removes it (`D/UniswapV4DetfDFPkg.sol:306-319`; factory `:230-231,427-453`). Preserve the full completion sequence and do not introduce user-selected execution/callback targets during it. Returning with this hook still routed is unacceptable.

**Child binding contract:**

| Child | Actual ordinary construction and role binding | Migration proposal |
| --- | --- | --- |
| Bond NFT | `D/UniswapV4DetfTarget.sol:810-830` uses stored package, parent `address(this)`, hook as LP token, oracle fee recipient and configured creator. Shared package registry-deploys and initializes parent/LP (`C/bondNft/DETFNFTVaultDFPkg.sol:47-52,123-132`); repo rejects rebinding (`C/bondNft/DETFFundedBondRepo.sol:33-39`). | Immutable Migration bond package/facets/metadata; parent-only `createMigrationPosition` extension from plan section 4.1. No arbitrary child address in per-instance args or setter. |
| Staking receipt | `D/UniswapV4DetfTarget.sol:833-848` binds parent, completed bond child and same oracle through stored package. Ordinary package is a generic Crane package, not a registered vault package (`C/claimToken/RebasingClaimTokenDFPkg.sol:45-57,137-152`); staking repo initializes once (`C/claimToken/DETFFundedStakingRepo.sol:52-68`). | Bind the Migration-aware staking composition required by the payout lane; retain parent/NFT/oracle identity and native 9 decimals. Do not “register” this child by silently changing its existing generic deployment category. |
| Raw and staking SY | Parent post-deploy calls `C/sy/DETFSYDeploymentLib.sol:15-27`, deploying separate registered wrappers with `isStaking=false/true`, same parent/staking and directional route tokens. Registry caller and backing identity checked at `C/sy/DETFSYDFPkg.sol:100-108`. | Preserve two distinct wrappers; reuse ordinary facets only after child-lane payout/route audit proves compatibility. |

Bond completion rejects missing hook and already-wired child; receipt completion rejects missing NFT and already-wired receipt (`D/UniswapV4DetfTarget.sol:810-837`). Their public wrappers expose no package-selection parameters (`D/UniswapV4DetfClaimTarget.sol:9-15`). Keep this immutable once-only behavior; external repeat calls must not replace children or recreate reserved rights.

Reserved IDs 0/1/2 are protocol/fee/creator, with users beginning at 3 (`C/core/DETFBondNftIds.sol:4-8`). `C/bondNft/DETFFundedBondTarget.sol:82-91` permits only parent initialization, rejects repeats/zero fee recipient, mints protocol role to NFT child, fee role to fee recipient, creator role to creator or fee-recipient fallback. Those roles are not Migration ownership or user principal. Current funded staking distributes actual role receipts (`C/claimToken/DETFFundedStakingRepo.sol:185-201`): ordinary children cannot be assumed safe for Stage 1 merely because parent ownership is correct.

**Future activation contract:** retain Ownable and owner-only harvesting, but remove the whole administration facet surface, including activation, with no public generic cut/init/delegatecall route. Local removal must resolve each selector's actual current owning facet: zero facet cuts are skipped (`K/introspection/ERC2535/ERC2535Repo.sol:155-170`), mismatched ownership reverts (`:245-274`), and arbitrary initializer calldata would delegatecall (`:104-116`). Use a fixed locally assembled Remove set with no initializer, current-owner check and shared lock, atomically with activation as the plan requires.

After return, selector resolution is only the proxy's local mapping (`K/proxies/MinimalDiamondCallBackProxyResolution.sol:24-26`); an unmapped selector reverts `NoTargetFor` (`K/proxies/Proxy.sol:19-32`). Calling a package or factory directly executes against that address's storage, not an existing proxy; factory redeploy of an existing deterministic address returns early before init/post-deploy (`factory :214-216`). Therefore preserve the absent routing edge, rather than assuming package/factory methods are themselves access-controlled or unusable. Registry disable/re-enable and ownership transfers must never re-add it. Registry disable authority is the manager's own owner (`R/VaultRegistryDisableManagerTarget.sol:17-34`), independent of Migration ownership.

## 5. Minimal proposed edit paths and sequencing

All following paths are **proposed**, not created by this preflight:

1. `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol`: owner/buffer/base `PkgArgs`; complete nonzero immutable `PkgInit` dependency set, including Ownable facet and Migration child package bindings. `M/interfaces/IUniswapV4DetfMigration.sol` and `M/UniswapV4DetfMigrationRepo.sol`: lifecycle/read surface and only required lifecycle state here; no separate owner or premature attribution layout.
2. New `D/UniswapV4DetfInitializationLib.sol`, with a narrow edit to `D/UniswapV4DetfDFPkg.sol`: extract `initAccount`'s compatible initialization and private `_storeTables` body (`:223-304`) into an internal library accepting explicit dependency values. Both parent packages use it; preserve ordinary guard, metadata, registry classification, routes and child binding exactly. Do not subclass the concrete package, make its unrelated methods virtual, or duplicate the entire stack.
3. `M/UniswapV4DetfMigrationDFPkg.sol`: distinct declarations/cuts, canonical decoding, registry path, owner-aware salt, once-only initialization and complete post-deploy composition. `M/UniswapV4DetfMigration_{Component,Pkg}_FactoryService.sol`: concrete artifact deployment/labels, distinct release keys. Reuse Crane Ownable unchanged; no shared dependency edit.
4. `M/TestBase_UniswapV4DetfMigration.sol` and later adversarial base: compose real manager/reserve/components, using ordinary TestBase deployment helpers as patterns, not inheriting an already-deployed ordinary SUT. New specs under `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`: `MigrationDeploy.t.sol`, then `MigrationActivation.t.sol`/`MigrationSurface.t.sol` when lifecycle facets exist.
5. Cross-lane dependency, not an independently chosen child design: `M/bondNft/UniswapV4DetfMigrationBondNFTVault{Target,Facet,DFPkg}.sol` and interface; Migration-aware staking/other policy composition and narrowly factored shared extension points must be fixed by the children report before final `PkgInit`/cuts/artifacts are wired. Allocation and retained target/facet paths remain those in plan section 4.

Ownership/salt/declaration and compatible-init extraction can proceed without E2. A complete deployable Migration package additionally needs agreed real child artifacts, bootstrap/new-money gates and payout composition; do not wire ordinary children temporarily and call that complete. Loading/issuance/surrender selectors dependent on missing source/attribution/pricing mechanisms are not part of this independent increment.

## 6. Real-proxy test oracles (specified, not executed)

Existing source tests are precedents, **not** proof of Migration behavior:

- `D/TestBase_UniswapV4Detf.sol:185-245,289-331` is the real package/registry/hook deployment pattern.
- `T/UniswapV4Detf_Deploy.t.sol:13-38` covers invalid hook, canonical encoding and inert/wired deployment, not a Migration administrator.
- `T/UniswapV4Detf_OwnerOnlyLiquidityBase.sol:14-34` checks **hook owner equals DETF**, not parent administrative ownership.
- `T/UniswapV4Detf_BondNftPackaging.t.sol:13-63` checks actual child loupe/guarded transfer routing.
- `T/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol:73-141` supplies reserved-role and creator/fallback/rotation oracles. Its immediate receipt-payout expectations remain ordinary regressions, not Stage 1 expectations.
- `test/foundry/spec/registries/vault/VaultRegistryDeployment_Auth.t.sol:44-173` actually deploys through the real registry and proves direct authorization, permissionless package helper, package disable/re-enable and distinct deployments.
- Crane's `lib/crane/test/foundry/spec/access/ERC8023/MultiStepOwnableFacet.t.sol:18-23` deploys a stub, not a registry-deployed Migration proxy. Its handler uses try/catch and updates its ghost after any successful acceptance (`K/access/ERC8023/TestBase_IMultiStepOwnable.sol:130-143`); its “full transfer” invariant (`:279-283`) does not establish a confirmation delay.

Required new tests all use the real Migration package helper -> manager registry -> production callback factory and assert exact state/events/routing:

| Case | Observable oracle |
| --- | --- |
| Nonzero owner and complete initialization | Explicit owner/buffer survive deployment; pending/preconfirmed zero; exact metadata/9 decimals, registry package/type/token discovery, all expected facet addresses nonzero; zero owner reverts without registration/partial children. Different deployer, creator and fee recipient do not become owner. |
| Two isolated owners | Same base salt inputs except owner produce different predictions; construct separate hooks for those predictions. Each real proxy has the requested owner and separate children; owner A cannot administer B. Shared package/facet state is not consulted. Vary buffer independently to prove salt inclusion. |
| Canonical encoding and hook prediction | Trailing/obsolete payload rejected. Zero-hook prediction equals final-hook deployment; changed owner changes prediction. Wrong hook self-leg/owner/liquidity policy fails. Same valid args return existing instance without rerunning initialization. |
| Reinitialization/restoration negatives | Proxy calls to both factory init signatures, package `initAccount(bytes)`, post-deploy signatures, diamondCut and ERC8109 update/delegatecall selectors remain absent and revert `NoTargetFor`; direct calls to package/factory and redeploy attempts cannot change proxy owner/buffer/lifecycle/routes/children. Repeat child completion and reserved-ID initialization fail without mutation. |
| Transfer and actual buffer | Initiate to B: A still administers; B cannot. Confirmation before buffer end reverts; at exact end succeeds but A remains owner until acceptance. Independently, B accepts **immediately without confirmation**, becomes authorized and A loses authority; pending/preconfirmed state clears. Wrong caller cannot accept; cancel clears; superseded pending owner cannot accept. Characterize initiate-after-confirm without inventing flag reset. |
| Contract owner | Deploy with a real forwarding owner contract and execute its call; transfer to a second contract, which accepts by an actual call. Its EOA caller has no direct authority. Do not test this solely by impersonating a contract address. |
| Role and registry separation | Owner transfer leaves creator, reserved NFT owners, fee oracle, registry owner and child parent addresses unchanged. Distinct fee/creator/registry/deployer cannot load/activate/harvest unless also current Migration owner. Migration owner cannot toggle manager disable policy without independent manager authority. Stage 1 role receipt non-payout is a child-lane obligation. |
| Child wiring and ordinary regression | NFT parent/LP, staking parent/NFT/oracle, both SY backing/mode, reserved IDs and no user principal at deployment agree. Repeat wiring cannot overwrite. Ordinary package has no new ownership/issuance selectors; metadata, init behavior and immediate ordinary role receipts remain unchanged. |
| Future activation/removal | Target/interface-derived selector census, Behavior facet/package declarations, real loupe before/after and callable smoke tests. All administration selectors disappear atomically, persistent routes remain. Failed removal rolls back activation/routing; owner transfer afterward moves harvesting only. Factory/package callbacks, same-args redeploy, registry disable/re-enable and child callbacks cannot restore loaders or expose partial activation. Exercise actual retained routes, not just absence of a method named diamondCut. |

Do not fabricate a temporary setter or fake attribution ABI just to test ownership. Loading/activation/harvest authorization tests attach when their genuine production selectors and prerequisites exist; until then mark those cases pending. Use deterministically chosen timestamps for time behavior, not sleeps. Interface-derived selector controls must not simply copy the facet's potentially incomplete list.

Later verification needs warm `out/` and `cache_forge/`, artifact-first Solar build/test through `scripts/forge-artifacts.py`, focused Migration specs plus ordinary V4/common regressions for the extracted initializer, and executed-test counts as well as exit 0. No executable check is requested or claimed here.

## 7. Limits, prerequisites and cleanup

The report cross-checks the proposed owner/argument/salt/registration/init/callback/removal contracts against the source cited above and original plan requirements. LSP document symbols and child-wiring definition/reference queries succeeded; read inspected implementations and tests. No new diagnostics, compilation, runtime/proxy observation or transaction was performed. Existing source behavior is distinguished from required future tests throughout.

No owner-policy question is created or answered. A concrete buffer duration remains deployment input, not a promised delay. Child-lane payout composition and bootstrap-lane gates are required before final package wiring; actual-recovery E3, fungible authenticated attribution, TokenStaking atomic handoff and restricted legacy harvest routes remain external prerequisites for the dependent behavior. This ownership contract does not close task 3, E1-E5 or any original-plan checkbox.

**Cleanup: none created** for processes, listeners, temporary runtime directories, caches, test artifacts or auxiliary files. Only this named report was created with `apply_patch`; source, tests, scripts, configuration, the main plan, sibling reports/worktrees and shared Crane were not edited. No builds/tests/Git/install/broadcast/delegation occurred.
