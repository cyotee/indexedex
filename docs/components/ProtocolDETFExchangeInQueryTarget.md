# ProtocolDETFExchangeInQueryTarget

## Target: `contracts/vaults/protocol/ProtocolDETFExchangeInQueryTarget.sol`

## Intent
- Conservative previews for ProtocolDETF exchange-in routes; must be mathematical simulation of corresponding execution routes. Global policy: `previewOut <= executeOut` (exact-in) on same state.

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

### Route ID: TGT-ProtocolDETFExchangeInQuery-01 (CHIR → WETH)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `chirWethVault.previewExchangeIn`, `richChirVault.previewExchangeIn`
- Inputs: `tokenIn=CHIR`, `tokenOut=WETH`; requires reserve pool initialized and burning allowed
- Outputs: pessimistic WETH out
- Execution Outline: compute synthetic price; enforce burning allowed; compute proportional BPT-in; compute proportional vault shares out; preview unwind vault shares to WETH via downstream vault preview calls
- Invariants: exact-in inequality must hold: `previewOut <= executeOut` on same state
- Failure Modes: `ReservePoolNotInitialized`, `BurningNotAllowed`, `ZeroAmount`, downstream reverts
- Tests Required: preview <= execute across fuzzed amounts; boundary at burnThreshold; 0-handling

### Route ID: TGT-ProtocolDETFExchangeInQuery-02 (WETH → CHIR)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: none beyond internal math
- Inputs: `tokenIn=WETH`, `tokenOut=CHIR`; requires minting allowed
- Outputs: CHIR out including discount margin
- Execution Outline: compute synthetic price; enforce minting allowed; compute base mint amount; compute seigniorage/discount; return base+discount
- Invariants: preview must not exceed execute for same state and same input
- Failure Modes: `ReservePoolNotInitialized`, `MintingNotAllowed`
- Tests Required: preview <= execute; discount margin included; gate at mintThreshold

### Route ID: TGT-ProtocolDETFExchangeInQuery-03 (RICH → CHIR)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `richChirVault.previewExchangeIn`, `chirWethVault.previewExchangeIn`
- Inputs: `tokenIn=RICH`, `tokenOut=CHIR`; requires minting allowed
- Outputs: CHIR out from wrapper route (multi-hop then mint)
- Execution Outline: preview RICH->CHIR via richChir vault; preview CHIR->WETH via chirWeth vault; compute mint output from WETH and add discount
- Invariants: preview must be conservative across multi-hop
- Failure Modes: `MintingNotAllowed`, downstream reverts
- Tests Required: preview <= execute; gate at mintThreshold

### Route ID: TGT-ProtocolDETFExchangeInQuery-04 (RICHIR → WETH)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `richirToken.redemptionRate()`
- Inputs: `tokenIn=RICHIR`, `tokenOut=WETH`
- Outputs: WETH out as linear `amountIn * redemptionRate / 1e18`
- Execution Outline: read redemption rate; compute linear redemption
- Invariants: preview <= execute (execution includes unwind mechanics; rate must be non-optimistic)
- Failure Modes: none (returns value; may be 0)
- Tests Required: preview <= execute for a range of redemption states; rate scaling correctness

### Route ID: TGT-ProtocolDETFExchangeInQuery-05 (RICH → RICHIR)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: Balancer vault `getPoolTokenInfo`, downstream vault preview calls, preview helper math
- Inputs: `tokenIn=RICH`, `tokenOut=RICHIR`
- Outputs: conservative RICHIR out (buffered)
- Execution Outline: conservative preview of Aerodrome vault shares after fee compound; compute BPT-out given single-in using liveScaled18 balances and weights; apply BPT buffer; simulate post-mint state in helper to compute RICHIR out; apply RICHIR buffer
- Invariants: preview must be <= execute; buffers must be justified and fuzz-tested
- Failure Modes: `ReservePoolNotInitialized`, downstream reverts
- Tests Required: preview <= execute; fuzz buffers; assert buffer constants remain adequate under rounding extremes

### Route ID: TGT-ProtocolDETFExchangeInQuery-06 (WETH → RICHIR)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: same as Route 05
- Inputs: `tokenIn=WETH`, `tokenOut=RICHIR`
- Outputs: conservative RICHIR out (buffered)
- Execution Outline: same as Route 05 but uses `chirWethVault` index
- Invariants: preview <= execute
- Failure Modes: `ReservePoolNotInitialized`
- Tests Required: preview <= execute; fuzz buffers

### Route ID: TGT-ProtocolDETFExchangeInQuery-07 (BPT → WETH)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: downstream vault preview calls
- Inputs: `tokenIn=BPT(reserve pool)`, `tokenOut=WETH`
- Outputs: WETH out from proportional exit + unwind previews
- Execution Outline: compute proportional vault shares out from BPT-in; preview unwind to WETH
- Invariants: preview <= execute; handles both checks `tokenIn==reserveAsset` and `tokenIn==reservePool()` paths
- Failure Modes: none (may return 0 for zero)
- Tests Required: preview <= execute for BPT->WETH route; zero handling

### Route ID: TGT-ProtocolDETFExchangeInQuery-08 (WETH → RICH)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: vault preview calls
- Inputs: `tokenIn=WETH`, `tokenOut=RICH`
- Outputs: RICH out via WETH->CHIR->RICH previews
- Execution Outline: preview WETH->CHIR on chirWeth vault; preview CHIR->RICH on richChir vault
- Invariants: preview <= execute
- Failure Modes: `ReservePoolNotInitialized`, downstream reverts
- Tests Required: preview <= execute for multi-hop route

### Route ID: TGT-ProtocolDETFExchangeInQuery-09 (RICH → WETH)
- Selector / Function: `previewExchangeIn(IERC20,uint256,IERC20)`
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: vault preview calls
- Inputs: `tokenIn=RICH`, `tokenOut=WETH`
- Outputs: WETH out via RICH->CHIR->WETH previews
- Execution Outline: preview RICH->CHIR on richChir vault; preview CHIR->WETH on chirWeth vault
- Invariants: preview <= execute
- Failure Modes: `ReservePoolNotInitialized`, downstream reverts
- Tests Required: preview <= execute for multi-hop route

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW

## Implementation Review Findings (2026-02-14)

I reviewed the implementation at `contracts/vaults/protocol/ProtocolDETFExchangeInQueryTarget.sol` against the requirements in this document. Below are the issues and discrepancies I found (ordered by severity).

- Critical: Preview/execute mismatch for mint routes — The execution target (`ProtocolDETFExchangeInTarget._executeMintWithWeth`) does not currently perform a reserve pool deposit before minting CHIR (see that component's review findings). This means the execution state changes differ from what a proper reserve-backed mint would do. The preview should be updated to match the corrected execution flow once fixed: deposit vault shares to Balancer reserve pool, add BPT to protocol NFT, then mint CHIR. The current preview computes `base + discountMargin` without accounting for the reserve deposit step, which could diverge from corrected execution. Tests must verify `preview ≤ execute` on identical on-chain state after the execution fix.

- High: No buffer applied to mint routes (WETH → CHIR, RICH → CHIR) — Routes 02 and 03 (WETH → CHIR mint and RICH → CHIR wrapper) do not apply any preview buffer, unlike Routes 05-06 (RICHIR routes) which apply `PREVIEW_RICHIR_BUFFER_BPS`. The requirements state "preview must not exceed execute for same state and same input" but without a buffer, rounding or execution path differences could cause `preview > execute`. Add a buffer constant for mint routes (e.g., `PREVIEW_MINT_BUFFER_BPS`) and apply it to ensure pessimistic estimates.

- Medium: BPT → WETH route duplicated — The code at lines 195-198 and lines 220-222 both handle BPT → WETH with identical logic. This is redundant; consolidate into one check.

- Medium: Documentation mismatch — The requirements document (Route 02) says "compute base mint amount; compute seigniorage/discount; return base+discount" but doesn't specify using `_calcMintAmount` (oracle-driven) vs AMM sale quote (`ConstProdUtils._saleQuote`). The implementation uses oracle-driven pricing. This should be explicitly documented in requirements if it's the intended design.

- Low: Missing zero-amount handling in some routes — Routes 02 and 03 don't explicitly check for zero `amountIn` before computing (they rely on downstream calls to revert). Add explicit zero checks for consistency and gas efficiency.

- Low: Virtual inheritance of `_previewChirRedemptionBptIn` — This function is marked `internal view virtual` (line 256) but there's no override in the codebase. If not needed, remove `virtual` to reduce surface area.

- Low: Commented-out code — Lines 290-295 have commented-out `_rateOf` helper. Either remove or move to a utility if needed.

Suggested next steps
1. Add buffer constants for mint routes in `Indexedex_CONSTANTS.sol` (e.g., `PREVIEW_MINT_BUFFER_BPS`) and apply to Routes 02 and 03.
2. Update the preview logic for mint routes to account for the reserve deposit step once the execution target is fixed (deposit vault shares → BPT → add to protocol NFT before mint).
3. Consolidate duplicate BPT → WETH route handlers.
4. Add explicit zero-amount early returns in mint routes for consistency.
5. Remove unused `virtual` modifier and commented code if not needed.
6. Update requirements doc to clarify pricing primitive (oracle vs AMM) for mint calculations.

## Additional Context from PROMPT.md (2026-02-14)

The PROMPT.md provides more detailed requirements that clarify some discrepancies:

- Route 02 (WETH → CHIR) in PROMPT.md (lines 713-729) specifies using `ConstProdUtils._saleQuote` with seigniorage-incentive-adjusted WETH amount, and explicitly describes the seigniorage split as:
  - User receives: `baseCHIR * (1 - seigniorageIncentivePercentageOfVault / 2)`
  - Protocol DETF NFT receives: `baseCHIR * (seigniorageIncentivePercentageOfVault / 2)`
- The current implementation uses `_calcMintAmount` (oracle-driven) and computes seigniorage differently via `_calcSeigniorage` (gross seigniorage from price arithmetic, then split into discountMargin + profitMargin).
- The execution target (once fixed) must perform: WETH → vault shares → deposit to Balancer reserve pool → add BPT to protocol NFT → mint CHIR. The preview must eventually simulate this same flow to guarantee `preview ≤ execute`.
