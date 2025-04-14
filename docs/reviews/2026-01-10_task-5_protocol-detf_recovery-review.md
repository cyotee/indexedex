# Review Header

- **Task/Worktree:** Task 5 — Protocol DETF (CHIR) + Fee Distribution (`feature/protocol-detf`)
- **Reviewer:**
- **Date:** 2026-01-10
- **Scope (files/dirs):**
  - Intended primary: `contracts/vaults/protocol/**`
  - Interfaces/proxies: `contracts/interfaces/IProtocolDETF.sol`, `contracts/interfaces/IProtocolNFTVault.sol`, `contracts/interfaces/IRICHIR.sol`, proxy interfaces
  - Any related factory services + packages
  - Tests: `test/foundry/spec/protocol/vaults/protocol/**` and `contracts/vaults/protocol/TestBase_ProtocolDETF.sol`
- **Tests run (exact commands):**
  - 
- **Environment:** (Base fork? RPC? anvil?)

## Indeterminate/Recovery Inventory (Required)

### Files changed / added

- (Fill in from `git status` / `git diff --name-only` in the Task 5 worktree)

### Build status

- `forge build`:
  - Result: (pass/fail)
  - If fail: first error + file/line

### Test status

- Existing tests discovered:
  - 
- Tests passing:
  - 
- Missing tests (by user story / acceptance criteria):
  - 

## Acceptance Criteria Delta (Task 5)

Mark each as ✅ implemented, ⚠️ partial, ❌ missing, or ❓ unknown.

### Core operations

- Mint CHIR with WETH gate (`synthetic_price > mintThreshold`)
  - Status:
  - Notes:
- Bond with WETH
  - Status:
  - Notes:
- Bond with RICH
  - Status:
  - Notes:
- Seigniorage capture (above peg)
  - Status:
  - Notes:
- Sell NFT to protocol → receive RICHIR
  - Status:
  - Notes:
- RICHIR redemption (burn → WETH) gate (`synthetic_price < burnThreshold`)
  - Status:
  - Notes:
- Fee donation integration (`donate(WETH)` and `donate(CHIR)`)
  - Status:
  - Notes:

### Critical invariants to validate (start table here)

| Invariant | Status | Evidence (test/trace) | Notes |
|----------|--------|------------------------|-------|
| No `new` deployments (CREATE3-only) |  |  |  |
| No storage slot collisions introduced |  |  |  |
| Preview/execution consistency where required |  |  |  |
| CHIR burn occurs on redemption path |  |  |  |
| RICHIR share accounting consistent (shares ↔ balance) |  |  |  |

## Findings Table

| ID | Severity | Area | Summary | Evidence | Recommendation | Fix Now? |
|----|----------|------|---------|----------|----------------|----------|
| 1  |          |      |         |          |                | Yes/No   |

## Deferred Debt

| ID | Category | Description | Rationale for Deferring | Suggested Deadline/Trigger |
|----|----------|-------------|--------------------------|----------------------------|
| D1 | NatSpec  |             | Avoid churn while code evolves | Before audit pass |

## Review Summary

- **Blockers:**
- **High:**
- **Medium:**
- **Low/Nits:**
- **Recommended next action:**
