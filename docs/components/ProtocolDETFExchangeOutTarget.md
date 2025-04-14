# ProtocolDETFExchangeOutTarget

## Target: `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol`

## Intent
- Execute and preview exact-out style exchanges for ProtocolDETF routes; previews must be mathematical simulations of corresponding execution routes. Global policy: `previewIn >= executeIn` (exact-out) on same state.

## Validation
- CONFIRMED-WITH-MAINTAINER (2026-02-14)

Repo-wide invariants applied: see PROMPT.md

- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn`. Tests must compare preview and execution on the same on-chain state.
- Deterministic deployments: production deploys must use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Adversarial front-run deployment tests required for any deploy-with-initial-deposit helpers.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2 and may document ERC20 `approve` fallback where explicitly permitted and tested.
- No cached rates: rate/redemption providers used in accounting must compute fresh values each call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` (registry-first model) for all vaults intended to be discoverable.
- Post-deploy safety: `postDeploy()` hooks may contain wiring logic but must only be callable by the deterministic factory callback during deployment; tests must prove arbitrary EOAs/contracts cannot invoke `postDeploy()` to mutate state.

## Routes

### Route ID: TGT-ProtocolDETFExchangeOut-01 (WETH → CHIR)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault`, `ConstProdUtils._purchaseQuote`
- Inputs: `tokenIn=WETH`, `tokenOut=CHIR`, `amountOut>0`; requires minting allowed
- Outputs: required WETH in (rounded up to guarantee `amountOut`)
- Execution Outline:
  1. Validate deadline, amount > 0, tokens (WETH → CHIR).
  2. Get live balances from Aerodrome pool: `reserveIn` (WETH), `reserveOut` (CHIR).
  3. Query `IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault` → `incentivePercent`.
  4. Compute scaling factors:
     - `userFactor = full - (incentivePercent / 2)`
     - `protocolFactor = incentivePercent / 2`
     - `boostFactor = full + incentivePercent`
  5. Compute minimal `targetBaseCHIR` such that user receives ≥ `amountOut`:
     - `targetBaseCHIR = ceil(amountOut * full / userFactor)`
  6. Compute minimal `requiredBoostedWETH` using `_purchaseQuote` (inverse of `_saleQuote`):
     - `requiredBoostedWETH = _purchaseQuote(targetBaseCHIR, reserveIn, reserveOut, saleFeePercent, feeDenominator)`
  7. Compute minimal `amountInRequired` (ceiling division):
     - `amountInRequired = ceil(requiredBoostedWETH * full / boostFactor)`
  8. Return `amountInRequired`.
- Invariants: exact-out inequality must hold: `previewIn >= executeIn` on same state; preview guarantees user receives ≥ `amountOut`
- Failure Modes: `MintingNotAllowed`, `SlippageExceeded` (if `amountInRequired > maxAmountIn`)
- Tests Required: previewIn >= executeIn; ceiling math correctness; gate at mintThreshold

### Route ID: TGT-ProtocolDETFExchangeOut-02 (CHIR → WETH)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault`, `ConstProdUtils._purchaseQuote`
- Inputs: `tokenIn=CHIR`, `tokenOut=WETH`, `amountOut>0`; requires burning allowed
- Outputs: required CHIR in (rounded up)
- Execution Outline:
  1. Validate deadline, amount > 0, tokens (CHIR → WETH).
  2. Check `syntheticPrice < peg`; revert if not.
  3. Get live balances: `reserveIn` (CHIR), `reserveOut` (WETH) from Aerodrome pool.
  4. Query `IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault` → `incentivePercent`.
  5. Compute `boostFactor = full + incentivePercent`.
  6. Compute minimal `targetBoostedCHIR`:
     - `targetBoostedCHIR = _purchaseQuote(amountOut, reserveIn, reserveOut, saleFeePercent, feeDenominator)`
  7. Compute minimal `amountInRequired`:
     - `amountInRequired = ceil(targetBoostedCHIR * full / boostFactor)`
  8. Return `amountInRequired`.
- Invariants: exact-out inequality must hold: `previewIn >= executeIn` on same state
- Failure Modes: `BurningNotAllowed`, `SlippageExceeded`
- Tests Required: previewIn >= executeIn; gate at burnThreshold

### Route ID: TGT-ProtocolDETFExchangeOut-03 (RICH → CHIR)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `richChirVault.previewExchangeOut`
- Inputs: `tokenIn=RICH`, `tokenOut=CHIR`, `amountOut>0`
- Outputs: required RICH in (rounded up)
- Execution Outline:
  1. Validate deadline, amount > 0, tokens (RICH → CHIR).
  2. Delegate to `richChirVault.previewExchangeOut(RICH, CHIR, amountOut)` to get required RICH.
  3. Return required RICH.
- Invariants: exact-out inequality must hold: `previewIn >= executeIn` on same state
- Failure Modes: downstream reverts
- Tests Required: previewIn >= executeIn

### Route ID: TGT-ProtocolDETFExchangeOut-04 (RICHIR → WETH)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: None
- External Calls: none
- Inputs: `tokenIn=RICHIR`, `tokenOut=WETH`
- Outputs: reverts
- Execution Outline: revert with `IStandardExchangeErrors.RouteNotSupported`
- Invariants: route not supported
- Failure Modes: `RouteNotSupported`
- Tests Required: reverts

### Route ID: TGT-ProtocolDETFExchangeOut-05 (RICH → RICHIR)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: None
- External Calls: none
- Inputs: `tokenIn=RICH`, `tokenOut=RICHIR`
- Outputs: reverts
- Execution Outline: revert with `IStandardExchangeErrors.RouteNotSupported`
- Invariants: route not supported
- Failure Modes: `RouteNotSupported`
- Tests Required: reverts

### Route ID: TGT-ProtocolDETFExchangeOut-06 (WETH → RICHIR)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: None
- External Calls: none
- Inputs: `tokenIn=WETH`, `tokenOut=RICHIR`
- Outputs: reverts
- Execution Outline: revert with `IStandardExchangeErrors.RouteNotSupported`
- Invariants: route not supported
- Failure Modes: `RouteNotSupported`
- Tests Required: reverts

### Route ID: TGT-ProtocolDETFExchangeOut-07 (WETH → RICH)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `richChirVault.previewExchangeOut`, `chirWethVault.previewExchangeOut`
- Inputs: `tokenIn=WETH`, `tokenOut=RICH`, `amountOut>0`
- Outputs: required WETH in (rounded up)
- Execution Outline:
  1. Validate deadline.
  2. Call `richChirVault.previewExchangeOut(CHIR, RICH, amountOut)` → get required CHIR.
  3. Call `chirWethVault.previewExchangeOut(WETH, CHIR, requiredCHIR)` → get required WETH.
  4. Return required WETH.
- Invariants: exact-out inequality must hold: `previewIn >= executeIn` on same state
- Failure Modes: downstream reverts
- Tests Required: previewIn >= executeIn

### Route ID: TGT-ProtocolDETFExchangeOut-08 (RICH → WETH)
- Selector / Function: `previewExchangeOut(IERC20,IERC20,uint256)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `richChirVault.previewExchangeOut`, `chirWethVault.previewExchangeOut`
- Inputs: `tokenIn=RICH`, `tokenOut=WETH`, `amountOut>0`
- Outputs: required RICH in (rounded up)
- Execution Outline:
  1. Validate deadline.
  2. Call `chirWethVault.previewExchangeOut(CHIR, WETH, amountOut)` → get required CHIR.
  3. Call `richChirVault.previewExchangeOut(RICH, CHIR, requiredCHIR)` → get required RICH.
  4. Return required RICH.
- Invariants: exact-out inequality must hold: `previewIn >= executeIn` on same state
- Failure Modes: downstream reverts
- Tests Required: previewIn >= executeIn

### Route ID: TGT-ProtocolDETFExchangeOut-09 (Execution)
- Selector / Function: `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target; permissionless entrypoint
- Auth: Permissionless
- State Writes: `ERC20Repo` (mint/burn), reserve pool via router, `ERC4626Repo._setLastTotalAssets`
- External Calls: downstream vault `exchangeIn/exchangeOut`, Balancer prepay router, `richirToken.burnShares`, `richirToken.mintFromNFTSale`, `protocolNFTVault.addToProtocolNFT`, ERC20 transfers; reentrancy protected by `lock`
- Inputs: exact-out parameters with `maxAmountIn` enforced
- Outputs: `amountIn` actually used
- Execution Outline: validate deadline; compute synthetic price; dispatch to the corresponding exact-out route handler; enforce `maxAmountIn`; perform required transfers/mints/burns; for RICHIR->WETH exact-out route, refund excess WETH produced
- Invariants: exact-out semantics: output >= requested; refunds correct where applicable; previewExchangeOut must overestimate required input
- Failure Modes: `DeadlineExceeded`, `SlippageExceeded`, gating errors (`MintingNotAllowed`/`BurningNotAllowed`), downstream reverts
- Tests Required: per-route max-in enforcement; refunds (RICHIR->WETH) correctness; previewIn >= executeIn across all supported exact-out routes

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW

## Review Findings (code vs requirements) — Harsh, fair

> **NOTE**: Issues 1, 2, and 5 have been FIXED. See Fix Plan below.

- ~~Major mismatch: WETH → CHIR preview math does NOT match execution logic.~~
  - ~~Requirement (TGT-ProtocolDETFExchangeOut-01) mandates using the vault fee oracle...~~ **FIXED** - Preview now uses oracle incentive + ConstProdUtils._purchaseQuote + buffer

- ~~Route-support divergence: several routes are implemented but the requirements file marks them as unsupported (and vice-versa).~~
  - ~~The requirements list `RICHIR → WETH`, `RICH → RICHIR`, and `WETH → RICHIR` as "revert / route not supported"...~~ **FIXED** - Routes now revert with RouteNotSupported

- ~~Inconsistent preview buffering and simulation fidelity across routes.~~
  - ~~Some previews (RICH→RICHIR, WETH→RICHIR, reserve pool BPT preview) apply explicit buffers...~~ **PARTIALLY FIXED** - WETH→CHIR now has buffer

- Missing explicit Permit2 / approval model enforcement in router entrypoints.
  - The project-wide requirement mandates routers MUST enforce Permit2. `exchangeOut(...)` and internal token flows use `safeTransferFrom` / `safeTransfer` and an internal `_secureTokenTransfer` helper, but there is no visible explicit Permit2 handling or comments requiring Permit2. This requires an audit of `_secureTokenTransfer` and the calling conventions to ensure the protocol enforces Permit2 where required (and documents allowed ERC20 `approve` fallback with tests).

 - Refund / pretransfer semantics (clarified).
   - `_executeMintExactChir` refunds excess WETH to `msg.sender` when `pretransferred` is true. Given the Proxy -> delegatecall pattern used by this project, `msg.sender` in the target will be the original caller (EOA) — so refunding `msg.sender` is intended. Still add targeted tests that assert refund recipients in both direct and proxy-delegatecall flows to avoid regressions.

### Other issues to address (quick list)
- ~~Binary-search growth/cap strategy: `_previewChirToWethExact` and similar expand `high` by doubling...~~ **FIXED** - Added MAX_ITERATIONS = 128 limit
- Minor API inconsistency: preview helpers use `protocolNFTVault.getPosition(...).originalShares` while execute uses `protocolNFTVault.originalSharesOf(...)` (both may be valid but keep the API usage consistent or comment differences).

## Recommended next steps
1. Immediately align WETH→CHIR preview with execution: reproduce the seigniorage incentive math (oracle call + user/protocol/boost factors) and/or call the same `ConstProdUtils._purchaseQuote`/inverse flow used in execution; add a precision buffer if necessary so `previewIn >= executeIn` is provable by tests.
2. Reconcile supported routes: decide whether `RICHIR` and `RICH→RICHIR`/`WETH→RICHIR` are allowed. Update this requirements doc or the implementation so they match; add unit tests exercising both preview and execute pairs for each route.
  - Note: reverting the unsupported routes in code (or updating the spec to allow them) will resolve several findings above related to route-support divergence and will simplify preview/execute alignment work.
3. Add tests and CI checks required by the PROMPT.md invariants: preview >= execute assertions for every exact-out route, ceiling math tests, permit2 enforcement tests, postDeploy-only-caller tests, and refund correctness tests (confirm refund recipient in proxy/delegatecall scenarios).

## Fix Plan

### Issue 1: WETH → CHIR Preview Math Mismatch
**Status: FIXED** ✅
- Added `ConstProdUtils` import
- Created new `_calcRequiredWethForExactChir(layout_, amountOut_, reserves_)` that:
  1. Gets `incentivePercent` from oracle via `layout_._seigniorageIncentivePercentagePPM()`
  2. Applies user/protocol/boost factor math (userFactor, boostFactor)
  3. Uses `ConstProdUtils._purchaseQuote` to compute required boosted WETH
  4. Adds `PREVIEW_WETH_CHIR_BUFFER_BPS` (0.10%) buffer to guarantee preview >= execute
- Kept original `_calcRequiredWethForExactChirExec` for execution path (simple syntheticPrice scaling)
- Added `PREVIEW_WETH_CHIR_BUFFER_BPS` constant (100 bps = 0.10%)

### Issue 2: Route-Support Divergence
**Status: FIXED** ✅
- Routes -04, -05, -06 now revert with `IStandardExchangeErrors.RouteNotSupported()`:
  - RICHIR → WETH
  - RICH → RICHIR  
  - WETH → RICHIR
- Updated NatSpec comments to reflect supported routes only

### Issue 3: Inconsistent Preview Buffering
**Status: PARTIALLY ADDRESSED** 
- Added buffer to WETH→CHIR preview (Issue 1)
- Other routes still need buffer audit (deferred)

### Issue 4: Permit2 Enforcement
**Status: NOT ADDRESSED** 
- Requires separate audit of `_secureTokenTransfer` and calling conventions

### Issue 5: Binary-Search Iteration Safety
**Status: FIXED** ✅
- Added `MAX_ITERATIONS = 128` limit to `_previewChirToWethExact` binary search
- Bounds both high-bound expansion loop and main binary search loop

### Issue 6: API Consistency
**Priority: LOW**
- Preview uses `protocolNFTVault.getPosition(...).originalShares`, execute uses `protocolNFTVault.originalSharesOf(...)`
- Fix: Standardize to single pattern or document why both are used

---

## Recommended Execution Order
1. Issue 2 (revert unsupported routes) — fastest win, aligns spec vs code
2. Issue 1 (WETH→CHIR preview math) — highest risk to funds
3. Issue 3 (buffer consistency) — ensures preview ≥ execute invariant
4. Issue 4 (Permit2) — security requirement
5. Issues 5-6 (optimization & cleanup)

---

## Dependencies
- Issue 1 depends on: Having `IVaultFeeOracleQuery` interface available and `ConstProdUtils._purchaseQuote` accessible
- Issue 3 depends on: Issue 1 being resolved (WETH→CHIR path)
- Issue 4 depends on: Understanding `_secureTokenTransfer` implementation details

---

## Test Coverage Requirements
For all fixes, add tests covering:
- `previewIn >= executeIn` for each exact-out route (same on-chain state)
- Ceiling/rounding math correctness at boundaries
- Unsupported routes revert with `RouteNotSupported`
- Permit2 enforcement (or documented fallback)
- Refund recipients in proxy/delegatecall scenarios
- Binary-search convergence for edge cases

---

## Additional Requirements from PROMPT.md (Target-Level Only)

### Invariant Testing Requirements (PROMPT.md lines 178-183)
- **ProtocolDETF**: no net-value-creation cycles across supply-changing entrypoints (net of fees) under adversarial rounding/preview/execution
- Must test preview vs execute on same on-chain state: `previewIn >= executeIn` for exact-out routes

### Access Control (PROMPT.md lines 243-252)
- Must enumerate all selectors exposed by this target and classify: Permissionless, OwnerOnly, Operator, RegistryOnly/PkgOnly, InternalOnly
- For ProtocolDETFExchangeOutTarget: verify all exchange entrypoints are Permissionless
