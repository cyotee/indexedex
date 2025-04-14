# Task Index: IndexedEx

**Repo:** IDXEX
**Last Updated:** 2026-02-10

## Active Tasks

| ID | Title | Status | Dependencies | Worktree |
|----|-------|--------|--------------|----------|
| IDXEX-013 | Implement Uniswap V4 Standard Exchange Vault | Ready | - | - |
| IDXEX-070 | Add Transient Token Vault Deposit Test | Ready | IDXEX-037 ✓ | - |
| IDXEX-081 | Remove Token-Specific Exchange Routes from Protocol DETF | In Progress | IDXEX-072 ✓ | feature/IDXEX-081-remove-token-specific-exchange-routes |
| IDXEX-084 | Implement ERC6909 Token ID Vault & Exchange Interfaces | Blocked | CRANE-255 | - |
| IDXEX-085 | Replace Hardcoded Preview Discount with Compound State Simulation | In Progress | IDXEX-072 ✓ | - |
| IDXEX-089 | Add MinAmountNotMet Selector Matching in Revert Tests | Ready | IDXEX-049 ✓ | - |
| IDXEX-090 | Remove Dead PPM Bond Constants | In Progress | IDXEX-056 ✓ | feature/IDXEX-090-remove-dead-ppm-bond-constants |
| IDXEX-091 | Add B->A direction for pretransferred exact no-refund tests | Ready | IDXEX-059 | - |
| IDXEX-092 | Add malicious-token reentrancy test (follow-up) | Ready | IDXEX-060 | - |
| IDXEX-095 | Add Readback Assertion to Seigniorage Fuzz Test | Ready | - | - |
| IDXEX-098 | Add Tests for Permit2 / Pretransferred Paths | In Progress | IDXEX-096 | feature/IDXEX-098-add-permit2-pretransferred-tests |
| IDXEX-101 | Handle pool-init path in previewClaimLiquidity + tests | Ready | IDXEX-064 | - |
| IDXEX-102 | Add preview/execution tests for rate-provider tokens | Ready | IDXEX-064 | - |
| IDXEX-103 | Balancer V3 Preview 1-Wei Tolerance | Ready | IDXEX-002 | - |
| IDXEX-104 | StandardExchangeRateProviderDFPkg Dedicated Tests | Ready | IDXEX-002 | - |
| IDXEX-105 | FeeCollector Revert-Path Tests | Ready | IDXEX-002 | - |
| IDXEX-107 | SeigniorageDETF Deploy.t.sol | Ready | IDXEX-002 | - |
| IDXEX-108 | SeigniorageNFTVault Deploy Production DFPkg Tests | Ready | IDXEX-002 | - |
| IDXEX-109 | Review & Verify Ported Balancer V3 for Production Deployment | Ready | - | - |

## Status Legend

- **Ready** - All dependencies met, can be launched with `/backlog:launch`
- **In Progress** - Implementation agent working (has worktree)
- **In Review** - Implementation complete, awaiting code review
- **Changes Requested** - Review found issues, needs fixes
- **Complete** - Review passed, ready to archive with `/backlog:prune`
- **Blocked** - Waiting on dependencies

## Priority Classifications

### CRITICAL Security Fixes (Block Release)

These must be fixed before any mainnet deployment:

| ID | Issue | Risk | Status |
|----|-------|------|--------|

### HIGH Priority Fixes

Important fixes before production:

| ID | Issue | Risk | Status |
|----|-------|------|--------|

### MEDIUM Priority

Documentation and minor fixes:

| ID | Issue | Status |
|----|-------|--------|

### LOW Priority

Defensive hardening (from IDXEX-030 review):

| ID | Issue | Status |
|----|-------|--------|

## Quick Filters

### Ready for Agent (No Dependencies)

### Blocked

- IDXEX-084: Waiting on CRANE-255

## Cross-Repo Dependencies

Tasks in other repos that depend on this repo's tasks:
- (none yet)
