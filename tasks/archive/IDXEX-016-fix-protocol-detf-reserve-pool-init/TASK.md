# Task IDXEX-016: Fix Protocol DETF Reserve Pool Initialization

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-27
**Dependencies:** None
**Worktree:** `feature/fix-protocol-detf-reserve-pool-init`

---

## Description

The `ProtocolDETFDFPkg._deployReservePoolAndFinalize()` function creates the 80/20 Balancer V3 reserve pool but never seeds it with initial liquidity. The vault shares (CHIR/WETH and RICH/CHIR vault tokens) are minted during `_fundProxyAndDeployExchangeVaults()` but remain unused in the CHIR contract. This causes all bonding operations (`bondWithWeth`, `bondWithRich`) to fail with "Exceeds max in ratio" because Balancer V3 pools require proportional initialization before accepting single-sided deposits.

Additionally, the frontend Staking page has incorrect ABIs that need to be fixed as part of this task.

## Root Cause Analysis

### Contract Issue

**File:** `contracts/vaults/protocol/ProtocolDETFDFPkg.sol`

**Function:** `_deployReservePoolAndFinalize()` (lines 501-594)

Current behavior:
1. Creates the 80/20 Balancer pool via `WEIGHTED_POOL_8020_FACTORY.create()` (line 547)
2. Initializes ERC4626Repo with the pool address (line 555)
3. Deploys NFT vault and RICHIR (lines 558-576)
4. Stores pool indices in storage (line 583)

**Missing step:** Never calls Balancer's pool initialization to seed it with the vault shares that were created in `_fundProxyAndDeployExchangeVaults()`.

**Evidence:**
- Reserve pool total supply: 0
- CHIR/WETH vault shares held by CHIR contract: ~3.3e18
- RICH/CHIR vault shares held by CHIR contract: ~100ke18
- Balancer error on bond: "Exceeds max in ratio"

### Frontend Issues

**File:** `frontend/app/staking/StakingPageClient.tsx`

1. `mintWithWeth` function doesn't exist on contract - should use `exchangeIn` with WETH→CHIR
2. `bondWithWeth` and `bondWithRich` ABIs have wrong 4th parameter (`bool pretransferred` instead of `uint256 deadline`)

## User Stories

### US-IDXEX-016.1: Seed Reserve Pool on Deployment

As a Protocol DETF deployer, I want the 80/20 reserve pool to be seeded with initial liquidity during deployment so that bonding operations work immediately after deployment.

**Acceptance Criteria:**
- [ ] After `WEIGHTED_POOL_8020_FACTORY.create()`, call Balancer V3's pool initialization
- [ ] Deposit ALL initial vault shares into the reserve pool (80% CHIR/WETH, 20% RICH/CHIR by weight)
- [ ] CHIR contract receives initial BPT tokens
- [ ] Reserve pool `totalSupply()` > 0 after deployment
- [ ] No vault shares remain unused in CHIR contract after initialization

### US-IDXEX-016.2: Fix Frontend Staking Page ABIs

As a user, I want the Staking page to correctly call the Protocol DETF contract so that minting and bonding operations succeed.

**Acceptance Criteria:**
- [ ] Replace `mintWithWeth` with `exchangeIn(address,uint256,address,uint256,address,bool,uint256)`
- [ ] Fix `bondWithWeth` ABI: 4th param is `uint256 deadline` not `bool pretransferred`
- [ ] Fix `bondWithRich` ABI: 4th param is `uint256 deadline` not `bool pretransferred`
- [ ] Update function call arguments to pass deadline timestamp
- [ ] All bonding operations succeed on local Anvil fork

### US-IDXEX-016.3: Add Unit Tests for Reserve Pool Initialization

As a developer, I want unit tests that verify the reserve pool is correctly initialized so that regressions are caught.

**Acceptance Criteria:**
- [ ] Test that reserve pool has non-zero total supply after Protocol DETF deployment
- [ ] Test that CHIR contract holds BPT tokens after deployment
- [ ] Test that vault shares are transferred to Balancer vault during initialization

### US-IDXEX-016.4: Add Fork Test for Bonding Flow

As a developer, I want a fork test that verifies the complete bonding flow so that integration is validated.

**Acceptance Criteria:**
- [ ] Fork test deploys Protocol DETF on Base mainnet fork
- [ ] Test `bondWithWeth` succeeds and returns NFT token ID
- [ ] Test `bondWithRich` succeeds and returns NFT token ID
- [ ] Test that BPT balance increases after bonding

## Technical Details

### Contract Fix

In `_deployReservePoolAndFinalize()`, after creating the reserve pool and before `ERC4626Repo._initialize()`:

1. Get vault share balances:
   ```solidity
   uint256 chirWethShares = IERC20(address(detfStorage.chirWethVault)).balanceOf(address(this));
   uint256 richChirShares = IERC20(address(detfStorage.richChirVault)).balanceOf(address(this));
   ```

2. Approve vault tokens to Balancer vault:
   ```solidity
   IERC20(address(detfStorage.chirWethVault)).approve(address(BALANCER_V3_VAULT), chirWethShares);
   IERC20(address(detfStorage.richChirVault)).approve(address(BALANCER_V3_VAULT), richChirShares);
   ```

3. Call Balancer V3 router to initialize pool with proportional amounts:
   ```solidity
   // Use router.initialize() or addLiquidityProportional()
   // Amounts should respect 80/20 weighting
   ```

4. Receive BPT tokens to CHIR contract

### Frontend Fix

Already partially implemented in this session. Verify:
- `protocolDetfAbi` uses correct `exchangeIn` signature
- `bondWithWeth` and `bondWithRich` use `deadline: uint256` as 4th param
- Function calls pass `BigInt(Math.floor(Date.now() / 1000) + 5 * 60)` for deadline

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolDETFDFPkg.sol` - Add reserve pool seeding in `_deployReservePoolAndFinalize()`
- `frontend/app/staking/StakingPageClient.tsx` - Fix ABIs and function calls (partially done)

**New Files:**
- `test/foundry/spec/protocol/detf/ProtocolDETF_ReservePoolInit.t.sol` - Unit tests for initialization
- `test/foundry/fork/protocol/detf/ProtocolDETF_Bonding.fork.t.sol` - Fork tests for bonding flow

## Inventory Check

Before starting, verify:
- [ ] Balancer V3 router interface for pool initialization (`IRouter.initialize` or similar)
- [ ] Weighted pool initialization requirements (proportional vs unbalanced)
- [ ] Current vault share balances available for seeding

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Unit tests pass
- [ ] Fork tests pass
- [ ] Build succeeds (`forge build`)
- [ ] Frontend compiles without errors (`npm run build` in frontend/)
- [ ] Manual test: Deploy to local Anvil, bond with RICH successfully

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
