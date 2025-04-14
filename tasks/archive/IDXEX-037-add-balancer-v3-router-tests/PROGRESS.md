# Progress Log: IDXEX-037

## Current Checkpoint

**Last checkpoint:** Complete — all 6 test suites written and passing
**Build status:** PASS (forge build successful)
**Test status:** PASS — 33 new tests across 6 files, all passing

---

## Final Summary

### Files Created (6 test files)

1. **BalancerV3StandardExchangeRouter_Deadline.t.sol** — 7 tests
   - SwapDeadline selector matches ISenderGuard
   - Expired deadline reverts for exact-in, exact-out, and vault deposit routes
   - Boundary: deadline == block.timestamp succeeds
   - Future deadline succeeds
   - vm.warp past deadline reverts

2. **BalancerV3StandardExchangeRouter_Permit2.t.sol** — 5 tests
   - Full Permit2 approval chain succeeds
   - Missing router approval on Permit2 reverts
   - Missing ERC20 approval on Permit2 reverts
   - Direct ERC20 approve on router insufficient (proves Permit2-only)
   - Exact-out with full Permit2 approval succeeds

3. **BalancerV3StandardExchangeRouter_TransientState.t.sol** — 6 tests
   - Custom DFPkg with TransientStateHarnessFacet for reading transient storage
   - Initially zero outside swap context
   - Set during harness-simulated context
   - Cleared after vault deposit, vault withdrawal, direct swap, and revert

4. **BalancerV3StandardExchangeRouter_PrepayAuth.t.sol** — 5 tests
   - Custom DFPkg with PrepayAuthHarnessFacet + PrepayAuthAttacker contract
   - Vault unlocked → any caller succeeds
   - Vault locked + wrong caller → reverts with NotCurrentStandardExchangeToken
   - Vault locked + correct caller → no auth revert
   - Vault locked + no token + EOA → blocked
   - Vault locked + no token + contract → allowed

5. **BalancerV3StandardExchangeRouter_BatchRefund.t.sol** — 5 tests
   - Two-step vault withdrawal → pool swap pattern (matching existing codebase)
   - Strategy vault uses less than max → refund forwarded to user
   - Query vs execution consistency
   - Refund settlement verified through balance accounting
   - Router no token retention after batch with vault
   - Slippage protection (maxAmountIn too low → reverts)

6. **BalancerV3StandardExchangeRouter_QueryHookAbuse.t.sol** — 5 tests
   - Direct call from EOA reverts with NotBalancerV3Vault
   - Malicious contract callback (reentrancy vector) reverts
   - ExactOut hook also protected from malicious callbacks
   - Legitimate exact-in query via vault.quote() still works
   - Legitimate exact-out query still works

### Key Technical Decisions

- **Struct name collisions**: `PkgInit` in custom DFPkg contracts conflicted with inherited `IBalancerV3StandardExchangeRouterDFPkg.PkgInit`. Renamed to `PrepayAuthPkgInit` and `TransientStatePkgInit`.
- **Single-step strategy vault paths**: Single-step strategy vault batch paths cause `BalanceNotSettled()` because the Balancer Vault's transient accounting can't balance when both input and output bypass the vault. Rewritten to use two-step paths (vault withdrawal → pool swap) matching the established pattern.
- **Transient storage testing**: Used harness facet pattern (from existing `_Prepay_LockedCaller.t.sol`) to read `currentStandardExchangeToken` within the same call context, since transient storage auto-clears at transaction end.

### Acceptance Criteria Coverage

- [x] US-037.1: SwapDeadline error tests (7 tests)
- [x] US-037.2: Permit2 requirement tests (5 tests)
- [x] US-037.3: Transient storage tests (6 tests)
- [x] US-037.4: Prepay authorization tests (5 tests)
- [x] US-037.5: Batch exact-out refund tests (5 tests)
- [x] US-037.6: Query hook access tests (5 tests + 5 in existing ExactInQueryHookAbuse)

---

## Session Log

### 2026-02-02 - Task Created

- Task designed from REVIEW_REPORT.md coverage gaps
- Depends on IDXEX-033 (query hook fix) and IDXEX-034 (refund fix)
- TASK.md populated with requirements
- Ready for agent assignment via /backlog:launch

### 2026-02-07 - Implementation Complete

- Explored codebase: router architecture, test base, transient storage, Permit2 pattern
- Created 6 test files with 33 total tests
- Fixed struct name collision compilation errors
- Fixed BalanceNotSettled failures by using two-step vault paths
- All 33 tests passing, build clean
