### Target: contracts/vaults/protocol/ProtocolDETFBondingQueryTarget.sol

## Validation
- CONFIRMED-WITH-MAINTAINER (2026-02-14)

## Intent
- View-only getters and previews for ProtocolDETF bonding; mathematical simulations of execution targets. Global policy: views must be conservative relative to execution.

Routes:

- Route ID: TGT-ProtocolDETFBondingQuery-01
  - Selector / Function: `syntheticPrice()`
  - Entry Context: Proxy -> delegatecall Target; view-only
  - Auth: Permissionless
  - State Writes: None
  - External Calls: none
  - Inputs/Outputs: returns ONE_WAD if uninitialized else computed synthetic price
  - Execution Outline:
    1. If not initialized, return 1e18.
    2. Load pool reserves (CHIR/WETH and RICH/CHIR pools).
    3. Split CHIR supply proportionally.
    4. Calculate synthetic zap-out via `AerodromeUtils._quoteWithdrawSwapWithFee` for both legs.
    5. Combine via Balancer weighted math and return synthetic price.
  - Invariants: should match mint/burn gating logic used by exchange targets
  - Tests Required: initialized/uninitialized behavior; consistency with exchange target computed price

- Route ID: TGT-ProtocolDETFBondingQuery-02
  - Selector / Function: `isMintingAllowed()` / `isBurningAllowed()`
  - Entry Context: Proxy -> delegatecall Target; view-only
  - Auth: Permissionless
  - State Writes: None
  - External Calls: none
  - Inputs/Outputs: returns false if uninitialized; else evaluates gates
  - Execution Outline: compute synthetic price; evaluate `_isMintingAllowed` / `_isBurningAllowed`
  - Invariants: must match execution gates
  - Tests Required: boundary tests around thresholds

- Route ID: TGT-ProtocolDETFBondingQuery-03
  - Selector / Function: protocol getters (`chirWethVault()`, `richChirVault()`, `reservePool()`, `protocolNFTVault()`, `richToken()`, `richirToken()`, `chirToken()`, `protocolNFTId()`, `mintThreshold()`, `burnThreshold()`, `wethToken()`)
  - Entry Context: Proxy -> delegatecall Target; view-only
  - Auth: Permissionless
  - State Writes: None
  - External Calls: none
  - Invariants: returned addresses/ids must match init-time wiring and be immutable
  - Tests Required: getters match values used in execution routes; immutability (no setters)

- Route ID: TGT-ProtocolDETFBondingQuery-04
  - Selector / Function: `previewClaimLiquidity(uint256)`
  - Entry Context: Proxy -> delegatecall Target; view-only
  - Auth: Permissionless
  - State Writes: None
  - External Calls: Balancer state reads, `IERC4626.previewRedeem`, Aerodrome pool `getReserves` and `totalSupply`
  - Inputs: `lpAmount` BPT
  - Outputs: estimated WETH out
  - Execution Outline:
    1. Load reserve pool data (balances, weights).
    2. Calculate CHIR/WETH vault shares out from BPT via `BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn`.
    3. Apply rate provider if available.
    4. Preview redeem LP from vault: `IERC4626.previewRedeem(vaultShares)` → LP tokens.
    5. Calculate WETH from LP: get Aerodrome pool reserves, calculate proportional amount.
    6. Return WETH out.
  - Invariants: preview must be conservative vs `claimLiquidity` execution; rate scaling must be correct
  - Failure Modes: `ReservePoolNotInitialized`
  - Tests Required: preview <= execute; fuzz around lpAmount and rates

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
