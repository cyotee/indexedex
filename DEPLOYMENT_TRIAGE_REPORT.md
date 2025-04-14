# Deployment Readiness Task Triage Report

**Generated**: 2026-02-11  
**Repository**: IndexedEx (IDXEX)  
**Total Active Tasks**: 19

---

## Executive Summary

This report triages all active tasks in the `tasks/` directory to identify which are **required for deployment**, which are **high priority**, and which can be **deferred post-deployment**.

### Key Findings
- **3 MUST COMPLETE** - Critical for production deployment
- **6 HIGH PRIORITY** - Important for production confidence
- **8 MEDIUM/LOW** - Can be completed post-deployment
- **2 OUT OF SCOPE** - Future features or redundant

---

## 🔴 MUST COMPLETE (Blocking Deployment)

These tasks address critical security, functionality, or correctness issues that would block a safe production deployment:

| ID | Title | Why Critical | Complexity | Status |
|---|---|---|---|---|
| **IDXEX-103** | Balancer V3 Preview 1-Wei Tolerance | Preview/execution parity mismatch causes failed transactions in production. Users will experience revert failures when actual output differs from preview by even 1 wei. | Medium | Ready |
| **IDXEX-104** | StandardExchangeRateProviderDFPkg Tests | Rate provider is fundamental to vault pricing. Without dedicated tests, incorrect rate calculations could lead to economic exploits or user fund loss. | Medium | Ready |
| **IDXEX-106** | IndexedexManager initAccount Verification | Core deployment infrastructure. Missing e2e tests for the main entry point means deployment failures could brick the system. | Medium | Ready |

### Detailed Analysis

#### IDXEX-103: Balancer V3 Preview 1-Wei Tolerance
- **Root Issue**: Preview functions don't account for rounding differences in Balancer V3 batch operations
- **Impact**: Users calling `querySwap()` then `swap()` will have transactions revert
- **Files Affected**: `contracts/protocols/dexes/balancer/v3/routers/`
- **Acceptance Criteria**: 
  - Add 1-wei tolerance to all preview functions
  - Update tests to verify tolerance works
  - Document tolerance behavior

#### IDXEX-104: StandardExchangeRateProviderDFPkg Dedicated Tests
- **Root Issue**: Rate provider package lacks comprehensive test coverage
- **Impact**: Incorrect rates could cause vault mispricing
- **Files Affected**: `contracts/protocols/dexes/*/rateProviders/`
- **Acceptance Criteria**:
  - Test `getRate()` accuracy
  - Test asset conversion math
  - Test deployment state
  - Verify rate consistency across DEXes

#### IDXEX-106: IndexedexManager initAccount Verification
- **Root Issue**: No end-to-end tests for the core orchestrator deployment
- **Impact**: Deployment failures could leave system in broken state
- **Files Affected**: `contracts/manager/IndexedexManagerDFPkg.sol`
- **Acceptance Criteria**:
  - Test manager deployment via CREATE3
  - Verify oracle initialization
  - Test access control setup
  - Validate facet configuration

---

## 🟠 HIGH PRIORITY (Pre-Production)

Important for production confidence and operational safety. Should be completed before mainnet deployment if schedule permits:

| ID | Title | Value | Complexity | Status |
|---|---|---|---|---|
| **IDXEX-085** | Fix RICHIR Preview Compound Simulation | Hardcoded 0.15% discount is incorrect; proper Aerodrome fee compounding needed | Medium | In Progress |
| **IDXEX-092** | Malicious Token Reentrancy Test | Security hardening - reentrancy is a common attack vector in DeFi | Low | Ready |
| **IDXEX-098** | Add Permit2 / Pretransferred Path Tests | Permit2 is core UX pattern; needs thorough testing | Low | In Progress |
| **IDXEX-101** | Handle Pool-Init Preview Path | Uninitialized pools cause user confusion; prevents failed transactions | Low | Ready |
| **IDXEX-102** | Preview Tests for Rate-Provider Tokens | Yield-bearing tokens need accurate preview testing | Medium | Ready |
| **IDXEX-095** | Readback Assertion to Seigniorage Fuzz Test | Fuzz test quality improvement | Very Low | Ready |

### Rationale

These tasks improve:
- **Security posture** (reentrancy testing)
- **User experience** (Permit2, pool-init handling)
- **Pricing accuracy** (RICHIR simulation, rate-provider tests)
- **Test quality** (fuzz assertions)

---

## 🟡 MEDIUM/LOW PRIORITY (Post-Deployment Acceptable)

Test coverage improvements and code cleanup that don't block deployment:

| ID | Title | Notes | Status |
|---|---|---|---|
| **IDXEX-070** | Add Transient Token Vault Deposit Test | Defensive test for edge case; core functionality already tested | Ready |
| **IDXEX-089** | Add Slippage Revert Selector Matching | Quality improvement for error messages; not critical | Ready |
| **IDXEX-090** | Remove Dead PPM Bond Constants | Code cleanup; no functional impact | In Progress |
| **IDXEX-091** | Add B->A Pretransferred Exact No-Refund Tests | Symmetric test coverage; A->B already exists and tested | Ready |
| **IDXEX-105** | FeeCollector Revert Path Tests | Access control testing; already covered by other tests | Ready |
| **IDXEX-107** | SeigniorageDETF Deploy.t.sol | Deployment test; can be added later | Ready |
| **IDXEX-108** | SeigniorageNFTVault Production Tests | Deployment test; can be added later | Ready |

---

## ⚪ OUT OF SCOPE / REDUNDANT / FUTURE

| ID | Title | Disposition | Recommendation |
|---|---|---|---|
| **IDXEX-013** | Implement Uniswap V4 Vault | **Future Feature** | Significant new functionality (Large complexity). Uniswap V4 is not a current protocol requirement. Schedule for v2.0. |
| **IDXEX-081** | Remove Token-Specific Exchange Routes | **Verify Necessity** | Cleanup to remove `richToRichir()` and `wethToRichir()` from public interfaces. **Confirm with protocol team** these aren't needed for Protocol DETF operations before proceeding. |
| **IDXEX-084** | ERC6909 Token ID Vault Interfaces | **Blocked** | Waiting on CRANE-255 (ERC6909 Diamond implementation). Cannot proceed until Crane framework supports this. |

---

## 📊 Deployment Readiness Assessment

### Current Test Coverage State

Based on `docs/TEST_ANALYSIS_REPORT.md` and `docs/NEGATIVE_TEST_COVERAGE_REPORT.md`:

| Component | Coverage | Status |
|---|---|---|
| Uniswap V2 Exchange | 100% | ✅ Complete |
| Camelot V2 Exchange | 95% | ✅ Complete |
| Balancer V3 Router | 85% | ⚠️ Missing Pattern 3-4 |
| Batch Router | 90% | ✅ Complete |
| Fee Collection | 90% | ✅ Complete |
| Infrastructure (IFacet/IERC165) | 60% | ⚠️ Gaps identified |

### Critical Gaps from Analysis

1. **Pattern 3-4 (Vault Pass-Through Swap)**: 0% coverage
   - Route: `pool == tokenInVault == tokenOutVault`
   - Impact: Users cannot perform basic token swaps through vaults
   - **Mitigation**: IDXEX-103, IDXEX-104 address core preview issues

2. **Query Functions**: Minimal coverage
   - Preview vs execution consistency not fully tested
   - **Mitigation**: IDXEX-101, IDXEX-102 add preview tests

3. **Exact Out Tests**: ~50% commented out
   - Per TEST_ANALYSIS_REPORT.md
   - **Mitigation**: These are already in archive - deferred to post-deployment

### Recommended Task Sequence

**Week 1: Critical Path (Blocking)**
1. IDXEX-103 - Balancer V3 1-Wei Tolerance
2. IDXEX-104 - RateProviderDFPkg Tests  
3. IDXEX-106 - IndexedexManager Verification

**Week 2: Security Hardening**
4. IDXEX-092 - Reentrancy Test
5. IDXEX-098 - Permit2 Tests
6. IDXEX-085 - RICHIR Preview Fix

**Week 3-4: Polish**
7. IDXEX-101 - Pool-Init Preview
8. IDXEX-102 - Rate-Provider Tests
9. Remaining medium/low priority tasks

**Post-Deployment**
- IDXEX-013 - Uniswap V4 (v2.0)
- IDXEX-084 - ERC6909 (blocked on CRANE)
- Cleanup tasks (IDXEX-090, etc.)

---

## 🔑 Key Recommendations

### 1. DO NOT Block Deployment On
- **IDXEX-013 (Uniswap V4)**: Major new feature, not deployment readiness
- **IDXEX-084 (ERC6909)**: Blocked on external dependency (CRANE-255)
- **Test coverage improvements** beyond the 3 MUST COMPLETE tasks

### 2. VERIFY Before Proceeding
- **IDXEX-081 (Remove Token Routes)**: Confirm with protocol team whether `richToRichir()` and `wethToRichir()` are actively used

### 3. Prioritize Security Over Coverage
- Reentrancy tests (IDXEX-092) > Additional fuzz tests
- Permit2 validation (IDXEX-098) > Code cleanup

### 4. Document Known Limitations
If deploying before all HIGH PRIORITY tasks complete:
- Document Pattern 3-4 (Vault Pass-Through) as beta
- Add monitoring for preview/execution mismatches
- Set conservative slippage defaults

---

## Appendix: Task Reference Table

| ID | Priority | Status | Blocking | Notes |
|---|---|---|---|---|
| IDXEX-013 | OUT OF SCOPE | Ready | No | Future feature - Uniswap V4 |
| IDXEX-070 | LOW | Ready | No | Transient token test |
| IDXEX-081 | VERIFY | In Progress | No | Check if functions used |
| IDXEX-084 | BLOCKED | Blocked | No | Waiting CRANE-255 |
| IDXEX-085 | HIGH | In Progress | No | RICHIR preview fix |
| IDXEX-089 | LOW | Ready | No | Slippage selectors |
| IDXEX-090 | LOW | In Progress | No | Dead code removal |
| IDXEX-091 | LOW | Ready | No | B->A test coverage |
| IDXEX-092 | HIGH | Ready | No | Reentrancy security |
| IDXEX-095 | MEDIUM | Ready | No | Fuzz assertion |
| IDXEX-098 | HIGH | In Progress | No | Permit2 tests |
| IDXEX-101 | MEDIUM | Ready | No | Pool-init preview |
| IDXEX-102 | MEDIUM | Ready | No | Rate-provider tests |
| IDXEX-103 | **CRITICAL** | Ready | **YES** | 1-wei tolerance |
| IDXEX-104 | **CRITICAL** | Ready | **YES** | Rate provider tests |
| IDXEX-105 | LOW | Ready | No | FeeCollector reverts |
| IDXEX-106 | **CRITICAL** | Ready | **YES** | Manager verification |
| IDXEX-107 | LOW | Ready | No | Deploy.t.sol |
| IDXEX-108 | LOW | Ready | No | Production DFPkg tests |

---

*Report generated from analysis of tasks/, docs/TEST_ANALYSIS_REPORT.md, docs/NEGATIVE_TEST_COVERAGE_REPORT.md, and docs/CODEBASE_MAP.md*
