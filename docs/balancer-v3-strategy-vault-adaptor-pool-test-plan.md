# BalancerV3StrategyVaultAdaptorPool Test Implementation Plan

**Generated:** 2024-12-19  
**Target:** BalancerV3StrategyVaultAdaptorPoolAndHooksFacetDFPkg.sol  
**Architecture:** Diamond Proxy with Strategy Vault tokens only  
**Status:** Planning Phase

## 🎯 Test Objectives

### Core Concept

The pool **ONLY holds Strategy Vault tokens**, not the underlying LP tokens. This creates a simplified routing where:

- **Pool Tokens**: Strategy Vault tokens (e.g., UniswapV2StrategyVault tokens)
- **No ERC4626 Wrapper**: Direct Strategy Vault integration
- **Simplified Swaps**: Strategy Vault token ↔ Strategy Vault token exchanges
- **Combined Hooks + Pool**: Single facet handles both pool logic and hooks

### Primary Test Goals

1. **Strategy Vault Creation** - Deploy UniswapV2 Strategy Vault using TestBase_UniswapV2
2. **Pool Deployment** - Diamond proxy creation with BalancerV3StrategyVaultAdaptorPool facet
3. **Token Configuration** - Pool configured with Strategy Vault tokens only
4. **Initialization** - Pool initialization with Strategy Vault tokens (no underlying tokens)
5. **Swap Operations** - Exchange between different Strategy Vault tokens
6. **Liquidity Operations** - Add/remove liquidity using Strategy Vault tokens only
7. **Hook Integration** - Verify combined hooks+pool functionality

## 🏗️ Test Architecture

### Base Classes Inheritance

```solidity
contract BalancerV3StrategyVaultAdaptorPoolTest is 
    BetterBalancerV3BasePoolTest,
    TestBase_Indexedex,
    TestBase_UniswapV2
{
    // Test implementation
}
```

### Required Components

#### 1. **Strategy Vault Setup** (via TestBase_UniswapV2)

- **UniswapV2 Pair**: DAI/USDC pair for underlying LP
- **Strategy Vault**: UniswapV2StandardStrategyVault wrapping the LP pair
- **Strategy Vault Tokens**: ERC20 tokens representing vault shares

#### 2. **Pool Configuration**

- **Pool Tokens**: Strategy Vault tokens ONLY (not DAI, USDC, or LP tokens)
- **Token Count**: 1 token type (the Strategy Vault token itself)
- **No Rate Providers**: Direct Strategy Vault token handling
- **Combined Facet**: BalancerV3StrategyVaultAdaptorPoolAndHooksFacet

#### 3. **Test Infrastructure**

- **Base**: BetterBalancerV3BasePoolTest for standard pool functionality
- **Indexedex**: TestBase_Indexedex for our deployment patterns
- **UniswapV2**: TestBase_UniswapV2 for Strategy Vault creation

## 📋 Detailed Test Implementation Plan

### Phase 1: Component Setup

#### 1.1 Strategy Vault Deployment

```solidity
function setUp() public override {
    // Initialize all base test classes
    super.setUp();
    
    // Deploy UniswapV2 infrastructure via TestBase_UniswapV2
    // This creates DAI/USDC pair and Strategy Vault
    
    // Strategy Vault becomes our pool token
    strategyVaultToken = uniswapV2StandardStrategyVault();
    
    // Configure pool to hold Strategy Vault tokens only
    poolTokens = [address(strategyVaultToken)].toMemoryArray().asIERC20();
    tokenAmounts = [STRATEGY_VAULT_TOKEN_AMOUNT].toMemoryArray();
}
```

#### 1.2 Pool Package Deployment

```solidity
function createPoolFactory() internal override returns (address) {
    // Deploy BalancerV3StrategyVaultAdaptorPoolAndHooksFacetDFPkg
    // via TestBase_Indexedex deployment patterns
    return address(balancerV3StrategyVaultAdaptorPoolPackage());
}
```

#### 1.3 Pool Creation

```solidity
function createPool() internal override returns (address newPool, bytes memory poolArgs) {
    // Configure TokenConfig for Strategy Vault token only
    TokenConfig[] memory tokenConfigs = new TokenConfig[](1);
    tokenConfigs[0] = TokenConfig({
        token: IERC20(address(strategyVaultToken)),
        tokenType: TokenType.STANDARD,
        rateProvider: IRateProvider(address(0)), // No rate provider needed
        paysYieldFees: false
    });

    // Package arguments for Strategy Vault pool
    IBalancerV3StrategyVaultAdaptorPoolPackage.PoolPackageArgs memory packageArgs = 
        IBalancerV3StrategyVaultAdaptorPoolPackage.PoolPackageArgs({
            tokenConfigs: tokenConfigs,
            hooksContract: address(0) // Combined in facet
        });

    // Deploy via vault registry (proxy pattern)
    newPool = vaultRegistryDeploymentFacet().deployVault(
        IStandardVaultPkg(address(balancerV3StrategyVaultAdaptorPoolPackage())),
        abi.encode(packageArgs)
    );
    
    poolArgs = abi.encode(packageArgs);
}
```

### Phase 2: Core Functionality Tests

#### 2.1 Pool Initialization Tests

```solidity
function test_pool_initialization_strategy_vault_only() public {
    // Verify pool holds Strategy Vault tokens only
    IERC20[] memory tokens = IPoolInfo(pool).getTokens();
    assertEq(tokens.length, 1, "Pool should have exactly 1 token type");
    assertEq(address(tokens[0]), address(strategyVaultToken), "Pool token should be Strategy Vault");
    
    // Verify no underlying tokens in pool
    uint256[] memory balances = IPoolInfo(pool).getCurrentLiveBalances();
    assertEq(balances.length, 1, "Pool should have 1 balance");
    assertGt(balances[0], 0, "Strategy Vault token balance should be positive");
}

function test_pool_initialization_liquidity() public {
    // Verify initial liquidity is Strategy Vault tokens
    uint256 totalSupply = IERC20(pool).totalSupply();
    assertGt(totalSupply, 0, "Pool should have BPT supply");
    
    // Verify LP owns initial BPT
    uint256 lpBptBalance = IERC20(pool).balanceOf(lp);
    assertGt(lpBptBalance, 0, "LP should own BPT tokens");
}
```

#### 2.2 Strategy Vault Token Swap Tests

```solidity
function test_swap_strategy_vault_tokens() public {
    // Since pool only holds Strategy Vault tokens, swaps would be:
    // Strategy Vault Token → Strategy Vault Token (same token, different amounts)
    // This tests the pool's ability to handle Strategy Vault token exchanges
    
    vm.startPrank(alice);
    
    uint256 amountIn = 10e18; // Strategy Vault tokens
    uint256 initialBalance = strategyVaultToken.balanceOf(alice);
    
    // Setup approvals for Permit2
    strategyVaultToken.approve(address(permit2), amountIn);
    permit2.approve(
        address(strategyVaultToken), 
        address(router), 
        type(uint160).max, 
        type(uint48).max
    );
    
    // Execute swap via router (pool proxy address)
    // Note: This is a conceptual test - actual swap logic depends on
    // how the pool handles single-token swaps
    router.swapSingleTokenExactIn(
        pool,
        strategyVaultToken,
        strategyVaultToken, // Same token for single-token pool
        amountIn,
        0, // minAmountOut
        type(uint256).max, // deadline
        false, // ethIsWeth
        bytes("")
    );
    
    vm.stopPrank();
}
```

#### 2.3 Liquidity Operations Tests

```solidity
function test_add_liquidity_strategy_vault_tokens() public {
    vm.startPrank(alice);
    
    uint256 strategyVaultAmountIn = 100e18;
    uint256[] memory amountsIn = [strategyVaultAmountIn].toMemoryArray();
    
    // Approve Strategy Vault tokens for router
    strategyVaultToken.approve(address(permit2), strategyVaultAmountIn);
    permit2.approve(
        address(strategyVaultToken),
        address(router),
        type(uint160).max,
        type(uint48).max
    );
    
    // Add liquidity with Strategy Vault tokens only
    uint256 bptAmountOut = router.addLiquidityProportional(
        pool,
        amountsIn,
        0, // minBptAmountOut
        false, // ethIsWeth
        bytes("")
    );
    
    assertGt(bptAmountOut, 0, "Should receive BPT tokens");
    assertGt(IERC20(pool).balanceOf(alice), 0, "Alice should have BPT balance");
    
    vm.stopPrank();
}

function test_remove_liquidity_strategy_vault_tokens() public {
    // First add liquidity
    test_add_liquidity_strategy_vault_tokens();
    
    vm.startPrank(alice);
    
    uint256 bptAmountIn = IERC20(pool).balanceOf(alice) / 2; // Remove half
    uint256 initialStrategyVaultBalance = strategyVaultToken.balanceOf(alice);
    
    // Remove liquidity proportionally
    uint256[] memory amountsOut = router.removeLiquidityProportional(
        pool,
        bptAmountIn,
        [uint256(0)].toMemoryArray(), // minAmountsOut
        false, // ethIsWeth
        bytes("")
    );
    
    assertEq(amountsOut.length, 1, "Should return 1 token amount");
    assertGt(amountsOut[0], 0, "Should receive Strategy Vault tokens");
    assertGt(
        strategyVaultToken.balanceOf(alice),
        initialStrategyVaultBalance,
        "Alice should receive Strategy Vault tokens"
    );
    
    vm.stopPrank();
}
```

### Phase 3: Hook Integration Tests

#### 3.1 Combined Hook+Pool Functionality

```solidity
function test_hooks_integration() public {
    // Test that hooks are properly integrated with pool operations
    // Since hooks and pool are combined in one facet
    
    // Test hook calls during swap
    // Test hook calls during liquidity operations
    // Verify hook state changes
}

function test_hook_access_controls() public {
    // Test that hooks have proper access controls
    // Verify only authorized operations can proceed
}
```

### Phase 4: Strategy Vault Integration Tests

#### 4.1 Strategy Vault Interaction Tests

```solidity
function test_strategy_vault_exchange_integration() public {
    // Test that the pool can interact with Strategy Vault's exchange functions
    // Verify previewExchangeIn/Out functions work correctly
    
    uint256 strategyVaultTokenAmount = 50e18;
    
    // Test exchange preview functions
    uint256 previewOut = IStandardExchange(address(strategyVaultToken))
        .previewExchangeIn(
            IERC20(address(strategyVaultToken)),
            strategyVaultTokenAmount,
            dai // Exchange to underlying token
        );
    
    assertGt(previewOut, 0, "Should preview positive exchange amount");
}

function test_strategy_vault_underlying_access() public {
    // Verify pool can access Strategy Vault's underlying tokens when needed
    // Test that Strategy Vault properly manages underlying LP tokens
    
    IERC20[] memory underlyingTokens = IStandardVault(address(strategyVaultToken)).tokens();
    assertEq(underlyingTokens.length, 2, "Strategy Vault should have 2 underlying tokens");
    assertEq(address(underlyingTokens[0]), address(dai), "First token should be DAI");
    assertEq(address(underlyingTokens[1]), address(usdc), "Second token should be USDC");
}
```

### Phase 5: Error Handling and Edge Cases

#### 5.1 Invalid Operation Tests

```solidity
function test_revert_invalid_token_operations() public {
    // Test that operations with non-Strategy Vault tokens revert
    
    vm.expectRevert("Invalid token");
    router.swapSingleTokenExactIn(
        pool,
        dai, // Wrong token - should be Strategy Vault token
        usdc,
        100e18,
        0,
        type(uint256).max,
        false,
        bytes("")
    );
}

function test_revert_insufficient_liquidity() public {
    // Test operations with insufficient liquidity
    
    vm.startPrank(alice);
    
    uint256 excessiveAmount = strategyVaultToken.totalSupply() + 1;
    
    vm.expectRevert("Insufficient balance");
    router.swapSingleTokenExactIn(
        pool,
        strategyVaultToken,
        strategyVaultToken,
        excessiveAmount,
        0,
        type(uint256).max,
        false,
        bytes("")
    );
    
    vm.stopPrank();
}
```

## 🧪 Test Constants and Configuration

### Test Parameters

```solidity
contract BalancerV3StrategyVaultAdaptorPoolTest is /* base classes */ {
    
    // Strategy Vault token amount for testing
    uint256 constant STRATEGY_VAULT_TOKEN_AMOUNT = 1000e18;
    
    // Pool configuration
    uint256 constant POOL_MIN_SWAP_FEE = 0; // No fees for Strategy Vault pool
    uint256 constant POOL_MAX_SWAP_FEE = 0;
    
    // Test users
    address constant alice = address(0xa11ce);
    address constant bob = address(0xb0b);
    
    // Strategy Vault reference
    IUniswapV2StandardStrategyVault strategyVaultToken;
    
    function setUp() public override {
        expectedAddLiquidityBptAmountOut = STRATEGY_VAULT_TOKEN_AMOUNT;
        super.setUp();
        
        // Set pool fee bounds (no fees for Strategy Vault pool)
        poolMinSwapFeePercentage = POOL_MIN_SWAP_FEE;
        poolMaxSwapFeePercentage = POOL_MAX_SWAP_FEE;
        
        // Deploy Strategy Vault via TestBase_UniswapV2
        strategyVaultToken = uniswapV2StandardStrategyVault();
        
        // Mint Strategy Vault tokens to test users
        _mintStrategyVaultTokensToUsers();
    }
    
    function _mintStrategyVaultTokensToUsers() internal {
        // Implementation to mint Strategy Vault tokens to alice, bob, lp
        // This involves depositing underlying tokens to get Strategy Vault shares
    }
}
```

## 📁 File Structure

### Test File Location

```
test/foundry/pools/balancer/v3/strategy-vault-adaptor/
└── BalancerV3StrategyVaultAdaptorPoolTest.t.sol
```

### Required Imports

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { BetterBalancerV3BasePoolTest } from "@crane/contracts/test/bases/protocols/BetterBalancerV3BasePoolTest.sol";
import { TestBase_Indexedex } from "contracts/test/bases/TestBase_Indexedex.sol";
import { TestBase_UniswapV2 } from "@crane/contracts/test/bases/protocols/TestBase_UniswapV2.sol";
import { IUniswapV2StandardStrategyVault } from "contracts/interfaces/IUniswapV2StandardStrategyVault.sol";
import { IStandardExchange } from "contracts/interfaces/IStandardExchange.sol";
import { IStandardVault } from "contracts/interfaces/IStandardVault.sol";
import { CastingHelpers } from "@crane/contracts/test/utils/CastingHelpers.sol";
import { ArrayHelpers } from "@crane/contracts/test/utils/ArrayHelpers.sol";
```

## 🎯 Success Criteria

### Deployment Success

- [ ] Strategy Vault deploys successfully via TestBase_UniswapV2
- [ ] Pool package deploys via TestBase_Indexedex patterns
- [ ] Pool proxy deploys with Strategy Vault token configuration
- [ ] All facets properly installed in diamond proxy

### Functionality Success

- [ ] Pool initialization with Strategy Vault tokens only
- [ ] Liquidity operations (add/remove) work with Strategy Vault tokens
- [ ] Swap operations handle Strategy Vault token exchanges
- [ ] Hook integration functions correctly
- [ ] Strategy Vault interaction methods work properly

### Architecture Compliance

- [ ] **Zero `new` keywords** - All deployments use factory().create3()
- [ ] Proper inheritance from required test base classes
- [ ] Pool interacts through proxy, not facets directly
- [ ] Strategy Vault integration follows our patterns

### Error Handling

- [ ] Invalid token operations properly revert
- [ ] Insufficient liquidity scenarios handled
- [ ] Access control restrictions enforced
- [ ] Edge cases covered with appropriate error messages

## 🚀 Implementation Priority

1. **Phase 1** - Component Setup (Strategy Vault + Pool deployment)
2. **Phase 2** - Core functionality (initialization, basic operations)
3. **Phase 3** - Hook integration (combined facet testing)
4. **Phase 4** - Strategy Vault integration (exchange functions)
5. **Phase 5** - Error handling and edge cases

This plan ensures comprehensive testing of the BalancerV3StrategyVaultAdaptorPool with Strategy Vault tokens only, following our established architectural patterns and testing infrastructure 🎯⚡ 