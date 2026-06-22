# PLAN: Fix Incorrect DFPkg and Package Deployments in Tests and Related Code

**Date**: 2026-07-02 (approx)
**Context**: Multiple agents have implemented tests and some supporting code that violate the project's deployment standards for Crane/IndexedEx DFPkgs (Diamond Factory Packages).

**Core Standards** (from AGENTS.md, Crane skills, and code patterns):
- **NEVER use `new` to deploy facets, DFPkgs, or Diamond proxies** that participate in the CREATE3 system. All must go through the factory for deterministic addresses and correct initialization flow.
- Use `create3Factory` (from `CraneTest` / `InitDevService`) for:
  - Facets: `create3Factory.deployFacet(...)` or via `*FactoryService` / `Component_FactoryService`.
  - Generic / non-registry DFPkgs: `create3Factory.deployPackageWithArgs( type(X).creationCode, abi.encode(IX.PkgInit({...})), salt )`.
- For **vault / StandardExchange / DETF-style packages** that must be registered: use `indexedexManager.deploy*DFPkg(...)` (or `IVaultRegistryDeployment.deployPkg(...)` via Component_FactoryService on the manager). This handles CREATE3 + registration in `VaultRegistryVaultPackageRepo`.
- Instance creation for vaults: `myPkg.deployVault(...)` (the pkg forwards to the registry, which uses `diamondPackageFactory` internally + registers the vault).
- `PkgInit` / `PkgArgs` structs **must** be defined in the `I*DFPkg` **interface**, not inside the contract (see previous fix and `crane-architecture` skill).
- Tests should inherit from appropriate bases (`CraneTest` → `IndexedexTest` → `TestBase_VaultComponents` → protocol TestBase) so facets and (where applicable) the DFPkg are set up via the standard path.
- Even for "unit" tests of DFPkg logic (validation, reverts in `deployVault`, etc.), prefer deploying the DFPkg via the factory (with mocks for facets/registry if needed) so that constructor + package deployment path is exercised the same as production.
- Auxiliary pkgs (e.g. ERC20PermitDFPkg used only for test tokens) should consistently use `create3Factory.deployPackageWithArgs` (or dedicated service) rather than `diamondPackageFactory.deploy(IDiamondFactoryPackage(addr), ...)` or `new`.
- Harness DFPkgs (for injecting test-only facets like in Balancer router tests) should still be deployed via `create3Factory.deployPackageWithArgs` using the harness pkg's creationCode, not raw `new`. This at least validates the PkgInit path.

**Goal of this plan**: Systematically identify, categorize, and fix all violations so that:
- Tests actually validate the real deployment mechanism (CREATE3 determinism, proper initAccount via callback, registry registration for vault pkgs, correct wiring).
- Code is consistent and maintainable.
- Future agents won't repeat the mistakes (documentation already updated).

## Review Findings (as of this plan)

I reviewed via searches for deployment patterns (`new *DFPkg`, `deployPackageWithArgs`, `diamondPackageFactory.deploy`, direct PkgInit construction, DFPkg tests, etc.) across `test/foundry/spec`, `test/foundry/fork`, and supporting contract test bases.

### Category 1: Direct `new XxxDFPkg(...)` (worst violations - completely bypasses CREATE3)
These call the constructor directly. No factory, no CREATE3 address, no proper salt, init not via the package callback flow in many cases.
- `test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.t.sol`
  - `dfpkg = new AaveCrossVersionLoopDFPkg( IAaveCrossVersionLoopDFPkg.PkgInit({ many zeros, mock registry... }) );`
  - Uses `_MockRegistry`.
  - Facets mostly `address(0)`.
  - Inherits `TestBase_AaveCrossVersionLoopV3Market` (which sets up markets) but manually news the pkg.
  - Problem: Does not test real deployment/registration/init path. Can't validate "deployed correctly".
- Balancer router harness tests (to test specific prepay/transient/auth behaviors by injecting harness facets):
  - `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_PrepayAuth.t.sol`: `new PrepayAuthDFPkg(p)`
  - `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Prepay_LockedCaller.t.sol`: `new BalancerV3StandardExchangeRouterDFPkg_WithHarness(...)`
  - `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_TransientState.t.sol`: `new TransientStateDFPkg(p)`
  - `test/foundry/fork/base_main/balancer/v3/BalancerV3Fork_Prepay_LockedCaller.t.sol`: similar `new ...WithHarness`
  - These define inner contract `XxxDFPkg is I...DFPkg { ... }` and `new` it with custom PkgInit (including harness facet).
  - Problem: Bypasses factory. The harness DFPkgs are test-only but still should follow deployment mechanics.

### Category 2: Direct `diamondPackageFactory.deploy(IDiamondFactoryPackage(address(pkg)), args)` for pkgs (bypasses registry for vault pkgs; inconsistent for generics)
Common in DETF / seigniorage / protocol vault deploy tests, often for the `ERC20PermitDFPkg` used to create test tokens inside the test.
- Multiple files use this for token pkgs (instead of consistent `create3Factory.deployPackageWithArgs`):
  - `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_AuctionBondWithPosition.t.sol`
  - `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_ProductionBase.t.sol`
  - `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_BridgeTransport.t.sol`
  - `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfDFPkg_Deploy.t.sol`
  - `test/foundry/spec/protocol/vaults/protocol/RICHIRDFPkg_Deploy.t.sol`
  - `test/foundry/spec/protocol/vaults/protocol/ProtocolNFTVaultDFPkg_Deploy.t.sol`
  - `test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol`
- While ERC20PermitDFPkg is "generic" (not always a registered vault pkg), using `diamond...deploy` directly after sometimes using create3 for other things is inconsistent. Some places already use proper `create3Factory.deployPackageWithArgs`.
- Some main pkgs use correct manager path (`indexedexManager.deploy...` or service), which is good.

### Category 3: Other DFPkg deployment tests that are mostly compliant but need review/consistency
These often use `create3Factory.deployPackageWithArgs` (good for generic) or proper manager for vault ones, but some may have issues with initialization, salt, or mixing.
- `test/foundry/spec/protocol/vaults/protocol/RICHIRDFPkg_Deploy.t.sol` and `ProtocolNFTVaultDFPkg_Deploy.t.sol`: Use create3 for RICHIR / token pkgs (with note that RICHIR is not via registry). Good for their case, but the token pkg uses diamond in some sibling tests.
- `test/foundry/fork/base_main/seigniorage/TestBase_SeigniorageDETF_Fork.sol` and `SeigniorageDETFIntegration.t.sol`: Mix of direct create3 for token/rate pkgs + proper `Seigniorage_Component_FactoryService` (which uses registry) for main DETF. Acceptable if auxiliary pkgs.
- `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol`: Uses create3 for buffer pool related.
- Various `*StandardExchange_DeployWithPool.t.sol` and E2E: Correctly use the pkg from the TestBase (deployed via manager).
- `test/foundry/spec/vaults/detf/...` many: Use `create3Factory.deployRICHIRDFPkg` (extension) + manager for detf pkgs. Good.
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg_Deploy.t.sol` etc.: Good usage from base.
- Smoke / debug tests: Some manually avoid full DFPkg.

### Category 4: Related issues in test infrastructure / bases
- Some bases (e.g. `TestBase_AaveCrossVersionLoopV3Market`) legitimately use `new` for external protocol test infra (Aave market orchestration is noted as `new`-based for portability). This is acceptable per comments, but DFPkg on top must not.
- Harness DFPkgs duplicate a lot of code across 3-4 balancer test files.
- Some tests construct PkgInit with many `address(0)` or incomplete facets, reducing the value of the test (as in the Aave example).
- Not all DFPkg-specific deploy tests exercise the full factory + registry + vault deploy path.

### Category 5: Broader / potential issues
- Inconsistent use of FactoryService extensions vs raw create3 calls even for things that have services.
- Some fork tests may rely on pre-deployed or different paths.
- No central "test DFPkg deploy helper" for cases that need mocks (leading to ad-hoc `new` or partial inits).
- Need to ensure that when fixing, the PkgInit always comes from `IInterface.PkgInit` (already mostly done after previous fixes).

No direct `new *DFPkg` found in production `contracts/` (good).

## Proposed Fixes (by category)

**General approach**:
- Replace `new` with `create3Factory.deployPackageWithArgs( type(TheDFPkg).creationCode, abi.encode(thePkgInit), salt )` + cast + label.
- For vault pkgs: Prefer the manager path if the test can inherit the full base (or call `indexedexManager.deployXXXDFPkg`).
- Extract common harness pkg patterns if possible, or keep per-test but deploy via factory.
- For pure-logic DFPkg tests: Still deploy via factory (even with zero/mocked facets + mock registry) so the package construction and any internal init logic is closer to real.
- Use `TestBase_*` where possible; add helpers to bases if many tests need custom pkg inits.
- Update any manual `diamondPackageFactory.deploy(IDiamond...` for consistency to `create3...` where the pkg is generic.
- Add comments: "Deployed via factory per standards (see crane-deployment skill)".
- After fixes, the tests should still pass (or more assertions on deployment correctness, e.g. code size, registry state if applicable).
- Leverage existing Component/FactoryServices (e.g. `create3Factory.deployRICHIRDFPkg(...)`).

**Specific files and actions** (prioritized):

**High priority (direct new on "real" DFPkg logic):**
1. `test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.t.sol`
   - Change `_deployDFPkg()` to use `create3Factory.deployPackageWithArgs( type(AaveCrossVersionLoopDFPkg).creationCode, abi.encode(pkgInit), salt )`.
   - Provide better (non-zero) facets if possible from the Aave base setup, or keep minimal mocks but document.
   - Keep the mock registry for isolation if the goal is just logic/revert testing.
   - Consider moving pkg init construction to use a helper.
   - Add assertion that the pkg was deployed via factory (e.g. has code, address predictable if salt used).

**Medium priority (harness DFPkgs for router testing):**
2. Balancer router test files (4 files):
   - For each custom `XxxDFPkg` (PrepayAuthDFPkg, TransientStateDFPkg, WithHarness), change the deployment from `new ... (p)` to `create3Factory.deployPackageWithArgs( type(XxxDFPkg).creationCode, abi.encode(p), salt )`.
   - Since these are inside the test contract inheriting a base that has `create3Factory`, it should be available.
   - This validates at least the PkgInit passing and package deployment.
   - If harness facets require special post-deploy, handle in the custom pkg or test.
   - Dedup the harness pkg definitions if feasible (they are similar).

**Consistency pass (auxiliary pkgs and mixed deployments):**
3. All the DETF / protocol vault deploy tests that use `diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), ...)` for test tokens:
   - Standardize on `create3Factory.deployPackageWithArgs( type(ERC20PermitDFPkg).creationCode, abi.encode(pkgInit), salt )`.
   - Update the helper methods (`_deployTestTokenPkg`) consistently across:
     - SingleVaultDetf* tests
     - RICHIRDFPkg_Deploy
     - ProtocolNFTVaultDFPkg_Deploy
     - Any others.
   - Same for rate provider or other generics where mixed.
4. Seigniorage fork/integration tests:
   - Review the direct create3 calls for token/rate pkgs; make sure they use salts consistently and/or extract to services.
   - The main DETF via service is good.
5. Other DFPkg tests (UniswapV4, Aerodrome, Camelot, buffer pool, etc.):
   - Audit that they rely on the TestBase-provided pkg (via manager) or explicit service. Fix any direct/raw ones.
   - `StandardExchangeBufferPoolPkg_Smoke.t.sol` etc. - ensure no direct construction.

**Infrastructure / bases:**
6. Review and enhance bases that provide DFPkgs (e.g. protocol TestBases like Camelot/Aave/Aerodrome, TestBase_VaultComponents, Seigniorage ones):
   - Ensure they always use the documented path (manager for vault, create3 for others).
   - Add a protected helper for "deploy test-only pkg with mocks" if needed for isolated DFPkg tests.
7. Balancer specific test bases / harness setup:
   - If the router DFPkg deployment can go through a service, introduce/update one.
8. `TestBase_AaveCrossVersionLoopV3Market.sol` (and V4):
   - Keep `new` for Aave market setup (documented as exception).
   - Ensure any DFPkg usage on top goes through factory.

**Additional / cross-cutting:**
- Search for and fix any remaining `new` on non-stub DFPkgs/facets in tests (re-run the grep patterns after initial fixes).
- For all fixed tests: Add or improve assertions that validate "deployment correctness" (e.g. `address(pkg).code.length > 0`, registry saw the pkg if applicable, predictable address via `calcAddress` if using factory).
- Update any comments that say "deployed with new for test" to reference the factory.
- If a pure unit test truly can't use factory (rare), wrap in a comment + exception with link to this plan.
- After all test fixes, review if any contract code (e.g. in services or test helpers inside contracts/) needs similar (unlikely).
- Run full `forge test --match "DFPkg|Deploy"` or targeted to verify.
- Consider adding a linter / test helper that detects raw `new` on *DFPkg in CI (future).

## Implementation Steps

1. **Preparation**
   - Read/refresh AGENTS.md (root + Crane) and `crane-deployment` / `crane-architecture` skills for reference.
   - Branch from current (feat/aave-cross-version-carry-loop-vault or main).
   - Run `forge build` and relevant tests to establish baseline.

2. **Fix by priority (small PRs or one big)**
   - Start with the Aave DFPkg test (specific example given).
   - Then Balancer harness files (they are clustered).
   - Then the consistency cleanups for ERC20Permit etc. (many files share similar helpers).
   - Update bases last.

3. **For each fix**:
   - Replace the bad construction.
   - Ensure `using` for any Component/FactoryService if not already.
   - Provide the PkgInit using values from the base (facets, oracles, etc.) where possible.
   - Use a salt like `abi.encode(type(X).name)._hash()` or test-specific.
   - `vm.label` the result.
   - Update the test to assert more about deployment (if it was only testing logic, keep logic tests but add deployment smoke).
   - For harnesses: Keep the inner contract definition but change instantiation.

4. **Verification**
   - `forge test` on changed files + full relevant suites (e.g. `forge test --match "AaveCrossVersion|BalancerV3StandardExchangeRouter|Detf|Seigniorage|DFPkg_Deploy"`).
   - Check that addresses are now deterministic where expected.
   - Run `forge fmt`.
   - Spot check that no new `new *DFPkg` introduced.
   - If a test relied on the old `new` behavior (unlikely), adjust expectations.

5. **Documentation / Prevention**
   - (Already done in prior step) Ensure AGENTS and skills call out "no new for DFPkgs".
   - Add to the Aave test or a common place an example of "correct isolated DFPkg test deployment".
   - Consider a `TestDFPkgHelper` library in `contracts/test/` for common patterns.

6. **Scope boundaries**
   - Do **not** change production contract deployment code (scripts use correct paths).
   - Legitimate `new` for external test doubles (Aave market orch, WETH in tests, pure mocks) stay.
   - Focus on `test/foundry/` primarily.

## Files Likely Needing Changes (initial list from review; re-grep before starting)

**Direct new DFPkg:**
- test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.t.sol
- test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_PrepayAuth.t.sol
- test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Prepay_LockedCaller.t.sol
- test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_TransientState.t.sol
- test/foundry/fork/base_main/balancer/v3/BalancerV3Fork_Prepay_LockedCaller.t.sol

**Inconsistent diamondPackageFactory for aux pkgs (standardize):**
- test/foundry/spec/vaults/detf/composed/single/* (4 files)
- test/foundry/spec/protocol/vaults/protocol/RICHIRDFPkg_Deploy.t.sol
- test/foundry/spec/protocol/vaults/protocol/ProtocolNFTVaultDFPkg_Deploy.t.sol
- test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol

**Review / minor fixes:**
- test/foundry/fork/base_main/seigniorage/*
- test/foundry/spec/protocol/vaults/seigniorage/*
- test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/*
- Any smoke/debug tests that manually construct.

**Supporting:**
- contracts/test/bases/* (enhance if needed)
- Possibly add to `contracts/test/` a helper.

## Success Criteria
- Zero instances of `new *DFPkg(...)` for Crane/IndexedEx DFPkgs in test code (except pure non-Crane stubs if any).
- All DFPkg deployments in tests use `create3Factory...` or manager path + FactoryService where available.
- The fixed Aave test (and others) now exercises a factory-deployed package.
- Tests still pass and provide better coverage of deployment correctness.
- Plan file kept updated if more files found during execution.
- No regression in test coverage or intent.

## Risks / Notes
- Some tests may have been written to avoid full inheritance for speed/isolation; fixing may make them slightly heavier but more correct.
- Harness DFPkgs may require the custom pkg to implement extra interface methods for the test (they already do in the examples).
- If a DFPkg constructor has side effects or requires specific deploy context, the factory path will surface it (which is good).
- For very complex harnesses, document the exception in the test file with link to this plan.

Execute fixes in small batches, update this plan with status (e.g. [DONE] per file).

This plan should be the single source of truth for the remediation effort.