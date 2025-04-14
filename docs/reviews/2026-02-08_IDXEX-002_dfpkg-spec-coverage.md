# IDXEX-002 — DFPkg Spec Coverage Review (Full Checklist)

**Date:** 2026-02-08
**Reviewer:** Agent (Claude Opus 4.6)
**Prior review:** `2026-01-19_IDXEX-002_dfpkg-spec-coverage.md`

## Goal

Verify that every IndexedEx-owned DFPkg has runnable test coverage with meaningful assertions per the checklist in `tasks/IDXEX-002-review-dfpkg-spec-coverage/TASK.md`.

## Scope

12 DFPkg files under `contracts/**/*DFPkg*.sol` mapped to specs under `test/foundry/spec/**`.

---

## 1. Coverage Map

| # | DFPkg | Deploy-Path Coverage | Success Assertions | Revert Assertions | Severity |
|---|-------|---------------------|--------------------|--------------------|----------|
| 1 | IndexedexManagerDFPkg | Indirect (IndexedexTest base) | Downstream only | Downstream only (VaultFeeOracle auth) | Medium |
| 2 | FeeCollectorDFPkg | Indirect (IndexedexTest base) | Routing/selectors only | None dedicated | Medium |
| 3 | AerodromeStandardExchangeDFPkg | Direct (14 test files) | Balance, reserves, shares, preview | RecipientRequired, slippage | OK |
| 4 | UniswapV2StandardExchangeDFPkg | Direct (4 test files) | Balance, reserves, shares, preview | RecipientRequired, slippage | Low |
| 5 | CamelotV2StandardExchangeDFPkg | Direct (3 test files) | Balance, reserves, shares, events | ZeroAmount, InsufficientLiquidity, StablePool | Low |
| 6 | BalancerV3StandardExchangeRouterDFPkg | Direct (16 test files) | Query vs exec, batch, permit2 | Deadline, hook abuse, prepay auth | OK |
| 7 | StandardExchangeRateProviderDFPkg | Indirect only | None dedicated | None dedicated | High |
| 8 | ProtocolDETFDFPkg | Direct (Deploy.t.sol + 10 behavioral) | Code length, reserve init, shares, preview | NotCalledByRegistry, slippage | OK |
| 9 | ProtocolNFTVaultDFPkg | Direct (Deploy.t.sol + 2 behavioral) | Code length, config, lock, NFT mint | NotCalledByRegistry, permissions | OK |
| 10 | RICHIRDFPkg | Direct (Deploy.t.sol + 2 behavioral) | Code length, protocolDETF ref, deterministic salt | NotCalledByRegistry, permissions | OK |
| 11 | SeigniorageDETFDFPkg | Integration only (no Deploy.t.sol) | Underwrite/redeem, preview match, balance changes | Invalid token revert | Medium |
| 12 | SeigniorageNFTVaultDFPkg | Mock-derived only | Lock/mint assertions (via mock) | BaseSharesZero | Medium |

---

## 2. Checklist Verdicts

### System DFPkgs

#### IndexedexManagerDFPkg
- [x] At least one runnable suite (indirect via IndexedexTest base; deployed via `create3Factory.deployIndexedexManagerDFPkg()` in setUp)
- [x] Explicit revert-path coverage: `VaultFeeOracleManagerFacet_Auth.t.sol` tests `NotOwner` and `NotOperator` reverts against the deployed manager proxy
- **Note:** No dedicated `IndexedexManagerDFPkg_Deploy.t.sol` exists. The DFPkg's `initAccount()` state (default fees, bond terms, seigniorage percentages) is not directly asserted post-deployment. Covered implicitly by downstream consumers.

#### FeeCollectorDFPkg
- [x] At least one runnable suite (indirect via IndexedexTest base; deployed via `diamondPackageFactory.deployFeeCollector()`)
- [ ] Explicit revert-path coverage (access control / caller restrictions) **GAP**: No test asserts reverts on unauthorized FeeCollector operations. `FeeCollectorProxy_Selectors.t.sol` tests routing but not auth.

### Aerodrome V1 StandardExchange DFPkg
- [x] At least one runnable suite with successful path assertions (14 spec files covering swap, zap, vault deposit/withdraw, deploy, fuzz)
- [x] Explicit revert-path coverage: `RecipientRequiredForDeposit` revert, slippage reverts (`vm.expectRevert()` when minAmountOut too high), reentrancy guard tested

### Uniswap V2 Package
- [x] At least one runnable suite with successful path assertions (4 spec files covering deploy, vault deposit, slippage, IStandardExchangeIn interface)
- [x] Explicit revert-path coverage: `RecipientRequiredForDeposit` revert, slippage reverts
- **Note:** Fewer test files than Aerodrome. Missing: dedicated ZapIn/ZapOut tests, FeeCompound tests, reentrancy guard test.

### Camelot V2 Package
- [x] At least one runnable suite with successful path assertions (3 spec files covering deploy, slippage, reentrancy)
- [x] Explicit revert-path coverage: `ZeroAmountForNonZeroRecipient`, `InsufficientLiquidity`, `PoolMustNotBeStable`, slippage reverts
- **Note:** Least comprehensive DEX test suite (only 3 files). Missing: ZapIn/ZapOut, VaultDeposit/VaultWithdraw, FeeCompound tests.

### Balancer V3 StandardExchange Router DFPkg
- [x] At least one runnable suite with successful path assertions (16 spec files covering batch exact in/out, refund, deadline, direct swap, hook abuse, permit2, prepay, transient state, vault deposit/withdrawal/passthrough)
- [x] Explicit revert-path coverage: deadline reverts, query hook abuse detection, prepay auth reverts, locked caller reverts, slippage reverts

### StandardExchangeRateProviderDFPkg
- [ ] Has direct (unit-ish) specs beyond integration tests **GAP**: No dedicated test files. Only deployed indirectly via `_deployStandardExchangeRateProviderPkg()` in seigniorage integration bases. No unit tests for rate calculation, getRate(), or vault asset conversion.

### Vault DFPkgs (Protocol)

#### ProtocolDETFDFPkg
- [x] At least one runnable suite: `ProtocolDETFDFPkg_Deploy.t.sol` + 10 behavioral specs (minting, bonding, exchange out, seigniorage, sell NFT, routes, donation)
- [x] Explicit revert-path coverage: `NotCalledByRegistry` on processArgs, slippage protection, peg gate tests (minting threshold), exchange out rounding (rounds up = vault-favorable)

#### ProtocolNFTVaultDFPkg
- [x] At least one runnable suite: `ProtocolNFTVaultDFPkg_Deploy.t.sol` + `ProtocolNFTVault.t.sol`, `ProtocolNFTVaultPermissions_Negative.t.sol`
- [x] Explicit revert-path coverage: `NotCalledByRegistry` on processArgs, permission restrictions for lock operations

#### RICHIRDFPkg
- [x] At least one runnable suite: `RICHIRDFPkg_Deploy.t.sol` + `RICHIRRedemption.t.sol`, `RICHIRPermissions_Negative.t.sol`
- [x] Explicit revert-path coverage: `NotCalledByRegistry`, deterministic salt collision handling, permission restrictions

### Vault DFPkgs (Seigniorage)

#### SeigniorageDETFDFPkg
- [x] At least one runnable suite: `SeigniorageDETFIntegration.t.sol` (deploys production DFPkg via factory service + registry)
- [x] Explicit revert-path coverage: `test_integration_underwrite_invalidToken_reverts()` tests non-approved token rejection
- **Note:** No dedicated `SeigniorageDETFDFPkg_Deploy.t.sol` with explicit post-deployment state verification. The integration test exercises deploy path but doesn't verify all initAccount() outputs.

#### SeigniorageNFTVaultDFPkg
- [x] At least one runnable suite: `SeigniorageNFTVault.t.sol` (lock, mint, position recording)
- [x] Explicit revert-path coverage: `BaseSharesZero` on zero-amount lock
- **Note:** Tests use `MockSeigniorageNFTVaultDFPkg` (derived from production). Production DFPkg is not deployed directly in any spec. If production has meaningful overrides, this is a coverage gap.

### Preview Functions
- [x] Where required, preview output matches actual exactly (0 tolerance) for Aerodrome, Uniswap V2, Camelot V2, and Protocol DETF tests
- [ ] Preview rounding follows ERC4626-style conservative direction **MIXED**: Aerodrome/Uniswap/Camelot use `assertEq(actual, preview)` (exact). Balancer V3 batch/vault tests use `assertApproxEqAbs(..., 1)` (1 wei tolerance). Balancer V3 direct swap tests use exact `assertEq()`. Per TASK.md rules, 1 wei tolerance is **High** severity.
- **Finding (verified 2026-02-09):** 10 instances across 6 files use 1-wei tolerance: `BatchExactIn.t.sol:114,248`, `BatchExactOut.t.sol:122,165`, `BatchRefund.t.sol:125,169,212`, `VaultDeposit.t.sol:148`, `VaultPassThrough.t.sol:149`, `VaultWithdrawal.t.sol:152`. Direct swap tests (`DirectSwap.t.sol`, `Permit2.t.sol`) use exact matching (18+ assertions).

### Deployment Patterns
- [x] IndexedEx-owned deployables use factory/CREATE3 helpers (no `new`)
- [x] Exceptions documented: External mocks (ERC20PermitMintableStub) use `new` in test setUp() - this is acceptable for external reference implementations.
- **Finding:** `CamelotV2StandardExchangeIn_SlippageProtection.t.sol:32-33` uses `new ERC20PermitMintableStub(...)` for test tokens - this is acceptable (external mock, not an IndexedEx deployable).

---

## 3. Findings Summary

### Blockers (0)

None.

### High Severity (2)

| ID | Finding | Component | Recommendation |
|----|---------|-----------|----------------|
| H-1 | Balancer V3 batch/vault preview tests use 1 wei tolerance (10 instances in 6 files); direct swap tests use exact match | BalancerV3 Router specs | Investigate root cause of query/exec mismatch in batch router and vault code paths. Direct swaps are unaffected. If inherent to Balancer's batch/vault hooks, document the exception. Otherwise, fix. |
| H-2 | StandardExchangeRateProviderDFPkg has no dedicated test specs | RateProvider | Create `StandardExchangeRateProviderDFPkg_Deploy.t.sol` with unit tests for: rate calculation, getRate() output, vault asset conversion, initialization state. |

### Medium Severity (4)

| ID | Finding | Component | Recommendation |
|----|---------|-----------|----------------|
| M-1 | FeeCollectorDFPkg has no revert-path tests for access control | FeeCollector | Add auth tests for FeeCollectorManager operations (setFeeRecipient, addToken, etc.) when called by non-owner. |
| M-2 | IndexedexManagerDFPkg initAccount() state not directly verified | IndexedexManager | Add tests asserting default fee values, bond terms, and seigniorage percentages after DFPkg deployment. |
| M-3 | SeigniorageDETFDFPkg has no dedicated Deploy.t.sol | SeigniorageDETF | Create `SeigniorageDETFDFPkg_Deploy.t.sol` verifying: reserve pool creation in postDeploy(), token ordering, package registration, predicted address match. |
| M-4 | SeigniorageNFTVaultDFPkg tested only via mock derivative | SeigniorageNFTVault | Add a spec that deploys the production DFPkg (not MockSeigniorageNFTVaultDFPkg) and exercises deployVault(). |

### Low Severity (3)

| ID | Finding | Component | Recommendation |
|----|---------|-----------|----------------|
| L-1 | CamelotV2 has minimal test coverage (3 files vs Aerodrome's 14) | CamelotV2 | Add ZapIn/ZapOut, VaultDeposit/VaultWithdraw, and FeeCompound test specs. |
| L-2 | UniswapV2 missing reentrancy guard test file | UniswapV2 | Add `UniswapV2StandardExchange_ReentrancyGuard.t.sol` mirroring Aerodrome and Camelot patterns. |
| L-3 | Balancer V3 VaultDeposit uses relative tolerance (0.1%) for multiple deposits | BalancerV3 Router | `assertApproxEqRel(..., 0.1e18, ...)` in consistency tests is looser than expected. Verify this is acceptable for Balancer's internal accounting. |

### Informational (2)

| ID | Finding | Component |
|----|---------|-----------|
| I-1 | Fork tests exist for Aerodrome, Balancer, and Seigniorage under `test/foundry/fork/base_main/` but require RPC setup. These complement spec tests but were not evaluated for runnability. |
| I-2 | BalancerV3 mock test base uses `new` for SenderGuardFacet and pool factory mocks. Acceptable for test infrastructure but noted per "no new for deployables" convention. |

---

## 4. Deployment Pattern Verification

All 12 DFPkgs deploy via CREATE3 factory patterns:

| Pattern | Used By | Method |
|---------|---------|--------|
| `create3Factory.deploy*DFPkg(...)` | System DFPkgs (Manager, FeeCollector) | FactoryService library |
| `indexedexManager.deploy*DFPkg(...)` | DEX DFPkgs (Aerodrome, Uniswap, Camelot) | VaultRegistryDeployment |
| `create3Factory.deployPackageWithArgs(...)` | Balancer Router, RateProvider | Direct CREATE3 |
| `IVaultRegistryDeployment.deployVault(...)` | Vault DFPkgs (Protocol, Seigniorage) | Registry path |
| `DIAMOND_FACTORY.deploy(...)` | RICHIR (non-vault package) | DiamondPackageFactory |

**No IndexedEx-owned contracts use `new` keyword for deployment.** External mocks (ERC20PermitMintableStub) in test setUp() are acceptable exceptions.

---

## 5. Preview Exactness Audit

| Component | Pattern | Tolerance | Verdict |
|-----------|---------|-----------|---------|
| Aerodrome Swap | `assertEq(amountOut, preview)` | 0 | OK |
| Aerodrome ZapIn/Out | `assertEq(sharesOut, preview)` | 0 | OK |
| UniswapV2 Slippage | `assertEq(out, preview)` | 0 | OK |
| CamelotV2 Slippage | `assertEq(out, preview)` | 0 | OK |
| ProtocolDETF ExchangeOut | `assertEq(wethUsed, requiredWeth)` | 0 | OK |
| ProtocolDETF Minting | `assertEq(syntheticPrice, expected)` | 0 | OK |
| SeigniorageDETF Underwrite | `assertEq(info.sharesAwarded, originalShares)` | 0 | OK |
| **Balancer V3 VaultDeposit** | `assertApproxEqAbs(..., 1)` | **1 wei** | **HIGH (H-1)** |
| **Balancer V3 BatchExactIn** | `assertApproxEqAbs(..., 1)` | **1 wei** | **HIGH (H-1)** |
| **Balancer V3 BatchExactOut** | `assertApproxEqAbs(..., 1)` | **1 wei** | **HIGH (H-1)** |
| **Balancer V3 VaultWithdrawal** | `assertApproxEqAbs(..., 1)` | **1 wei** | **HIGH (H-1)** |
| **Balancer V3 VaultPassThrough** | `assertApproxEqAbs(..., 1)` | **1 wei** | **HIGH (H-1)** |

---

## 6. Verification Pass (2026-02-09)

All findings independently verified against source code:

- **H-1 refined**: Narrowed from "all Balancer V3 tests" to 6 specific batch/vault test files (10 instances). Direct swap tests use exact matching.
- **H-2 confirmed**: 9 indirect references found, zero dedicated test files for StandardExchangeRateProviderDFPkg.
- **M-1 confirmed**: `pullFee()` has `onlyOwner` modifier but zero negative tests. Only 2 FeeCollector test files exist, both happy-path only.
- **M-3/M-4 confirmed**: No `*Seigniorage*Deploy*.t.sol` files exist. MockSeigniorageNFTVaultDFPkg overrides only `processArgs()`.
- **Deployment pattern confirmed**: All 237 `= new ` in production code are memory allocations. External Crane facets in test helpers are acceptable.

---

## 7. Completion Status

| Criterion | Status |
|-----------|--------|
| All checklist items verified | Done |
| Findings documented | This file + REVIEW.md |
| Findings verified against source | Done (2026-02-09) |
| Missing test coverage identified and logged | H-2, M-1 through M-4, L-1 through L-2 |
| No Blocker or High severity issues remain unfixed | **2 High issues logged (H-1, H-2)** - require resolution |
