# **Balancer V3 Router Integration with Strategy Vaults - Project Requirements Document**

## 📋 **Project Overview**

**Project Name:** Balancer V3 Router Integration with Strategy Vaults  
**Version:** 1.0  
**Date:** December 2024  
**Status:** Implementation Phase  

### **Objective**

Complete the implementation of two specialized routers for the IndexedEx platform to integrate with Balancer V3, enabling seamless token swaps and liquidity operations involving strategy vaults. The Standard Router provides gas-optimized single-step operations, while the Batch Router handles complex multi-step operations. Users choose between them based on operation complexity.

---

## 🎯 **Business Requirements**

### **Primary Goals**

1. **Complete Standard Router**: Finalize `BalancerV3StandardExchangeRouterDFPkg.sol` for gas-optimized single-step operations
2. **Complete Batch Router**: Finalize `BalancerV3StandardExchangeBatchRouterFacet.sol` for complex multi-step operations
3. **Strategy Vault Integration**: Enable seamless conversion to/from strategy vaults in swap operations
4. **ETH/WETH Support**: Handle native ETH wrapping/unwrapping in all operations
5. **Gas Optimization**: Provide single-step operations as gas-efficient alternative to batch operations

### **Secondary Goals**

1. **Complementary Design**: Provide gas-optimized single-step operations as alternative to batch operations
2. **Error Handling**: Robust error handling for failed operations
3. **Testing Coverage**: Comprehensive test suite for all functionality
4. **Documentation**: Clear implementation patterns for future development

---

## 🛠️ **Technical Requirements**

### **Architectural Constraints**

- **MANDATORY**: Follow Diamond Proxy pattern using Package-based deployment
- **MANDATORY**: Use CREATE3 deployment for deterministic addressing
- **MANDATORY**: Inherit from existing base classes (`BetterRouterCommon`, `BetterBatchRouterCommon`)
- **MANDATORY**: Integrate with existing strategy vault system (`IStandardExchange`)
- **MANDATORY**: Support Permit2 for gasless approvals

### **Core Components to Complete**

#### **1. Standard Router (`BalancerV3StandardExchangeRouterDFPkg.sol`)**

**Required Functions:**

```solidity
function swapSingleTokenExactIn(
    address pool,
    IERC20 tokenIn,
    IStandardExchange tokenInVault,
    IERC20 tokenOut,
    IStandardExchange tokenOutVault,
    uint256 exactAmountIn,
    uint256 minAmountOut,
    uint256 deadline,
    bool wethIsEth,
    bytes calldata userData
) external payable returns (uint256);

function swapSingleTokenExactOut(
    address pool,
    IERC20 tokenIn,
    IStandardExchange tokenInVault,
    IERC20 tokenOut,
    IStandardExchange tokenOutVault,
    uint256 exactAmountOut,
    uint256 maxAmountIn,
    uint256 deadline,
    bool wethIsEth,
    bytes calldata userData
) external payable returns (uint256);

function swapSingleTokenHook(
    StandardExchangeSwapSingleTokenHookParams calldata params
) external returns (uint256);
```

**Strategy Vault Integration Patterns:**

1. **Direct Strategy Vault Operations** (Pool = Strategy Vault):

   ```solidity
   // Deposit: USDC → Strategy Vault Shares
   swapSingleTokenExactIn(
       pool: strategyVault,
       tokenIn: USDC,
       tokenInVault: strategyVault,  // Same as pool
       tokenOut: strategyVault,      // Same as pool
       tokenOutVault: address(0),
       exactAmountIn: 1000e6,
       minAmountOut: 950e18
   );
   
   // Withdrawal: Strategy Vault Shares → USDC
   swapSingleTokenExactIn(
       pool: strategyVault,
       tokenIn: strategyVault,
       tokenInVault: address(0),
       tokenOut: USDC,
       tokenOutVault: strategyVault,  // Same as pool
       exactAmountIn: 1000e18,
       minAmountOut: 950e6
   );
   ```

2. **Strategy Vault Intermediation** (Pool ≠ Strategy Vault):

   ```solidity
   // USDC → Strategy Vault → Balancer Pool → DAI
   swapSingleTokenExactIn(
       pool: balancerPool,
       tokenIn: USDC,
       tokenInVault: strategyVault,  // Pre-conversion
       tokenOut: DAI,
       tokenOutVault: address(0),    // No post-conversion
       exactAmountIn: 1000e6,
       minAmountOut: 950e18
   );
   ```

#### **2. Batch Router (`BalancerV3StandardExchangeBatchRouterFacet.sol`)**

**Required Functions:**

```solidity
function swapExactIn(
    SESwapPathExactAmountIn[] memory paths,
    uint256 deadline,
    bool wethIsEth,
    bytes calldata userData
) external payable returns (
    uint256[] memory pathAmountsOut,
    address[] memory tokensOut,
    uint256[] memory amountsOut
);

function swapExactOut(
    SESwapPathExactAmountOut[] memory paths,
    uint256 deadline,
    bool wethIsEth,
    bytes calldata userData
) external payable returns (
    uint256[] memory pathAmountsIn,
    address[] memory tokensIn,
    uint256[] memory amountsIn
);

function querySwapExactIn(
    SESwapPathExactAmountIn[] memory paths,
    address sender,
    bytes calldata userData
) external returns (
    uint256[] memory pathAmountsOut,
    address[] memory tokensOut,
    uint256[] memory amountsOut
);

function querySwapExactOut(
    SESwapPathExactAmountOut[] memory paths,
    address sender,
    bytes calldata userData
) external returns (
    uint256[] memory pathAmountsIn,
    address[] memory tokensIn,
    uint256[] memory amountsIn
);
```

**Strategy Vault Integration in Paths:**

```solidity
struct SESwapPathStep {
    address pool;           // Balancer pool OR strategy vault
    IERC20 tokenOut;
    bool isBuffer;          // ERC4626 wrapper
    bool isStrategyVault;   // Strategy vault flag
}

// Complex path example:
// USDC → Strategy Vault → Balancer Pool → Strategy Vault → ETH
SESwapPathStep[] memory steps = [
    SESwapPathStep({
        pool: strategyVault1,
        tokenOut: vaultShares1,
        isBuffer: false,
        isStrategyVault: true
    }),
    SESwapPathStep({
        pool: balancerPool,
        tokenOut: vaultShares2,
        isBuffer: false,
        isStrategyVault: false
    }),
    SESwapPathStep({
        pool: strategyVault2,
        tokenOut: WETH,
        isBuffer: false,
        isStrategyVault: true
    })
];
```

---

## 🔧 **Implementation Requirements**

### **Standard Router Implementation**

#### **1. Strategy Vault Detection Logic**

```solidity
function _handleDirectStrategyVaultOperation(
    StandardExchangeSwapSingleTokenHookParams calldata params
) internal returns (uint256) {
    // Check if pool IS the strategy vault
    if (params.pool == address(params.tokenInVault) && 
        params.pool == address(params.tokenOutVault)) {
        
        // Direct deposit/withdrawal operation
        return _executeDirectStrategyVaultOperation(params);
    }
    
    // Strategy vault intermediation
    return _executeStrategyVaultIntermediation(params);
}
```

#### **2. Pre-Swap Strategy Vault Conversion**

```solidity
function _handlePreSwapStrategyVaultConversion(
    StandardExchangeSwapSingleTokenHookParams calldata params,
    uint256 amountGiven
) internal returns (IERC20 tokenIn, uint256 amountIn) {
    if (address(params.tokenInVault) != address(0)) {
        // Convert to strategy vault shares
        tokenIn.approve(address(params.tokenInVault), amountGiven);
        amountGiven = params.tokenInVault.exchangeIn(
            tokenIn, amountGiven, params.tokenInVault, 0, address(this), false
        );
        tokenIn = IERC20(address(params.tokenInVault));
    }
    return (tokenIn, amountGiven);
}
```

#### **3. Post-Swap Strategy Vault Conversion**

```solidity
function _handlePostSwapStrategyVaultConversion(
    StandardExchangeSwapSingleTokenHookParams calldata params,
    IERC20 tokenOut,
    uint256 amountOut
) internal returns (IERC20 finalTokenOut, uint256 finalAmountOut) {
    if (address(params.tokenOutVault) != address(0)) {
        // Convert from strategy vault shares
        _balV3Vault().sendTo(tokenOut, address(this), amountOut);
        tokenOut.approve(address(params.tokenOutVault), amountOut);
        amountOut = params.tokenOutVault.exchangeIn(
            tokenOut, amountOut, params.tokenOutVault, 0, address(this), false
        );
        tokenOut = params.tokenOut;
    }
    return (tokenOut, amountOut);
}
```

### **Batch Router Implementation**

#### **1. Strategy Vault Step Processing**

```solidity
function _processStrategyVaultStep(
    SESwapPathStep memory step,
    IERC20 tokenIn,
    uint256 amountIn,
    uint256 minAmountOut,
    address recipient
) internal returns (uint256 amountOut) {
    if (step.isStrategyVault) {
        // Handle strategy vault conversion
        amountOut = IStandardExchangeIn(step.pool).exchangeIn(
            tokenIn, amountIn, step.tokenOut, minAmountOut, recipient, false
        );
        emit StrategyVaultExchangeIn(
            step.pool, tokenIn, step.tokenOut, amountIn, amountOut
        );
    }
    return amountOut;
}
```

#### **2. Transient Storage Management**

```solidity
function _updateTransientStorage(
    address token,
    uint256 amount,
    bool isInput
) internal {
    if (isInput) {
        _currentSwapTokensIn().add(token);
        _currentSwapTokenInAmounts().tAdd(token, amount);
    } else {
        _currentSwapTokensOut().add(token);
        _currentSwapTokenOutAmounts().tAdd(token, amount);
    }
}
```

---

## 📊 **Current Test Coverage Status**

### **✅ Batch Router Tests (EXCELLENT COVERAGE)**

**Multiple comprehensive test files found:**

- **`IStandardExchangeBatchRouter_StratVault_ERC20Swaps.t.sol`** (269 lines) - Strategy vault integration in ERC20 swaps
- **`IStandardExchangeBatchRouter_StratVault_Wrapping.t.sol`** (653 lines) - Extensive strategy vault wrapping/unwrapping
- **`IStandardExchangeBatchRouter_ETH_Wrapping.t.sol`** (138 lines) - ETH/WETH wrapping functionality
- **`IStandardExchangeBatchRouter_LiquidityBuffers.t.sol`** (182 lines) - Liquidity buffer operations
- **`IStandardExchangeBatchRouter_BufferVaultPrimitive.t.sol`** (917 lines) - Comprehensive buffer vault testing
- **`IStandardExchangeBatchRouter_ERC20Swaps.t.sol`** (331 lines) - Basic ERC20 swap functionality
- **`IStandardExchangeBatchRouter_BatchRouter.t.sol`** (96 lines) - Batch router core functionality

### **❌ Standard Router Tests (CRITICAL GAP)**

**ZERO functional tests found starting with `IStandardExchangeRouter_`**

**Only infrastructure tests exist:**

- `BalancerV3StandardExchangeRouterDFPkg_IDiamondLoupe.t.sol` - Diamond pattern tests
- `BalancerV3StandardExchangeRouterDFPkg_IWETHAware.t.sol` - WETH integration tests
- `BalancerV3StandardExchangeRouterDFPkg_IFacet.t.sol` - Facet interface tests
- `BalancerV3StandardExchangeRouterDFPkg_ICreate2Aware.t.sol` - Create2 deployment tests

### **🚨 Missing Standard Router Test Files**

#### **1. `IStandardExchangeRouter_StrategyVault_Tests.sol`**

```solidity
// Test strategy vault deposit/withdrawal operations
function test_swapSingleTokenExactIn_StrategyVaultDeposit()
function test_swapSingleTokenExactIn_StrategyVaultWithdrawal()
function test_swapSingleTokenExactOut_StrategyVaultDeposit()
function test_swapSingleTokenExactOut_StrategyVaultWithdrawal()
```

#### **2. `IStandardExchangeRouter_Intermediation_Tests.sol`**

```solidity
// Test strategy vault intermediation (pre/post swap)
function test_swapSingleTokenExactIn_StrategyVaultIntermediation()
function test_swapSingleTokenExactOut_StrategyVaultIntermediation()
```

#### **3. `IStandardExchangeRouter_ETH_Tests.sol`**

```solidity
// Test ETH/WETH integration with strategy vaults
function test_swapSingleTokenExactIn_ETH_StrategyVault()
function test_swapSingleTokenExactOut_ETH_StrategyVault()
```

#### **4. `IStandardExchangeRouter_Error_Tests.sol`**

```solidity
// Test error handling
function test_swapSingleTokenExactIn_InvalidStrategyVault()
function test_swapSingleTokenExactIn_InsufficientLiquidity()
function test_swapSingleTokenExactIn_ExpiredDeadline()
```

---

## 🧪 **Testing Requirements**

### **Standard Router Tests (MISSING - NEEDS IMPLEMENTATION)**

#### **1. Direct Strategy Vault Operations**

- **Test**: USDC → Strategy Vault Shares (deposit)
- **Test**: Strategy Vault Shares → USDC (withdrawal)
- **Test**: ETH → Strategy Vault Shares (with WETH wrapping)
- **Test**: Strategy Vault Shares → ETH (with WETH unwrapping)

#### **2. Strategy Vault Intermediation**

- **Test**: USDC → Strategy Vault → Balancer Pool → DAI
- **Test**: ETH → WETH → Strategy Vault → Balancer Pool → DAI
- **Test**: USDC → Balancer Pool → Strategy Vault → DAI

#### **3. Error Handling**

- **Test**: Insufficient input amount
- **Test**: Slippage exceeded
- **Test**: Expired deadline
- **Test**: Invalid strategy vault address

### **Batch Router Tests (EXCELLENT COVERAGE - COMPLETE)**

#### **1. Multi-Path Strategy Vault Operations**

- **Test**: Multiple paths with different strategy vaults
- **Test**: Mixed paths (some with strategy vaults, some without)
- **Test**: Complex paths with multiple strategy vault conversions

#### **2. Query Operations**

- **Test**: `querySwapExactIn` with strategy vault paths
- **Test**: `querySwapExactOut` with strategy vault paths
- **Test**: Static call behavior for strategy vaults

#### **3. Transient Storage**

- **Test**: Token tracking across multiple paths
- **Test**: Amount aggregation for same tokens across paths
- **Test**: Settlement of aggregated amounts

---

## ✅ **Success Criteria**

### **Functional Requirements**

- ✅ **Standard Router**: All single-token swap operations work correctly with gas optimization
- ✅ **Batch Router**: All multi-path operations work correctly for complex scenarios
- ✅ **Strategy Vault Integration**: Both direct and intermediation patterns work
- ✅ **ETH/WETH Support**: Native ETH handling works in all scenarios
- ✅ **Error Handling**: Robust error handling for all failure cases
- ✅ **User Choice**: Users can choose appropriate router based on operation complexity

### **Performance Requirements**

- ✅ **Gas Efficiency**: Standard Router provides gas-optimized single-step operations (no iteration overhead)
- ✅ **Slippage Protection**: Accurate slippage calculation and protection
- ✅ **Deadline Enforcement**: Proper deadline checking and enforcement

### **Integration Requirements**

- ✅ **Balancer V3 Vault**: Proper integration with Balancer V3 vault system
- ✅ **Strategy Vault System**: Correct integration with existing strategy vaults
- ✅ **Permit2**: Gasless approval system works correctly
- ✅ **Diamond Pattern**: Proper facet and package integration

---

## 🚀 **Implementation Timeline**

### **Phase 1: Standard Router Tests (HIGH PRIORITY - 1-2 days)**

#### **Step 1: Create Test Base Class**
1. **Create `TestBase_IndexedexBalancerV3_StandardExchangeRouter.sol`**: Provide shared setup and utilities for all Standard Router tests
   - Deploy or get standard router instance
   - Setup strategy vaults and pools for testing
   - Provide common test utilities

#### **Step 2: Create Core Test Files**
2. **Create `IStandardExchangeRouter_StrategyVault_Tests.sol`**: Test direct strategy vault operations
   - `test_swapSingleTokenExactIn_StrategyVaultDeposit()`: USDC → Strategy Vault Shares
   - `test_swapSingleTokenExactIn_StrategyVaultWithdrawal()`: Strategy Vault Shares → USDC
   - `test_swapSingleTokenExactOut_StrategyVaultDeposit()`: Exact out deposit
   - `test_swapSingleTokenExactOut_StrategyVaultWithdrawal()`: Exact out withdrawal

3. **Create `IStandardExchangeRouter_Intermediation_Tests.sol`**: Test strategy vault intermediation
   - `test_swapSingleTokenExactIn_StrategyVaultIntermediation()`: USDC → Strategy Vault → Balancer Pool → DAI
   - `test_swapSingleTokenExactIn_PostSwapStrategyVault()`: USDC → Balancer Pool → Strategy Vault → DAI
   - `test_swapSingleTokenExactOut_StrategyVaultIntermediation()`: Exact out intermediation
   - `test_swapSingleTokenExactOut_PostSwapStrategyVault()`: Exact out post-swap

4. **Create `IStandardExchangeRouter_ETH_Tests.sol`**: Test ETH/WETH integration
   - `test_swapSingleTokenExactIn_ETH_StrategyVault()`: ETH → Strategy Vault (with WETH wrapping)
   - `test_swapSingleTokenExactIn_StrategyVault_ETH()`: Strategy Vault → ETH (with WETH unwrapping)
   - `test_swapSingleTokenExactIn_ETH_StrategyVault_BalancerPool()`: ETH intermediation

5. **Create `IStandardExchangeRouter_Error_Tests.sol`**: Test error handling
   - `test_swapSingleTokenExactIn_InvalidStrategyVault()`: Invalid strategy vault address
   - `test_swapSingleTokenExactIn_InsufficientLiquidity()`: Insufficient liquidity scenarios
   - `test_swapSingleTokenExactIn_ExpiredDeadline()`: Expired deadline handling
   - `test_swapSingleTokenExactIn_SlippageExceeded()`: Slippage protection

### **Phase 2: Standard Router Implementation Fixes** (1-2 days)

#### **Implementation Strategy**
1. **Start with Basic Tests**: Create test base class and simple strategy vault deposit test
2. **Run Tests to Identify Issues**: Execute tests to find implementation gaps
3. **Fix Implementation**: Address issues found by failing tests
4. **Expand Test Coverage**: Add more tests as implementation improves

#### **Expected Implementation Issues**
1. **Strategy Vault Detection**: Implement logic to detect when pool = strategy vault
2. **Pre/Post Conversion**: Complete strategy vault deposit/withdrawal logic
3. **Error Handling**: Add robust error handling for all failure scenarios
4. **ETH/WETH Integration**: Ensure proper ETH wrapping/unwrapping with strategy vaults

### **Phase 3: Batch Router Completion** (1-2 days)

### **Phase 4: Batch Router Completion** (1-2 days)

1. **Fix Strategy Vault Step Processing**: Handle strategy vaults in paths
2. **Complete Transient Storage**: Proper token and amount tracking
3. **Add Query Functions**: Implement quote operations
4. **Write Tests**: Comprehensive test suite for batch router (already mostly complete)

### **Phase 5: Integration Testing** (1-2 days)

1. **End-to-End Testing**: Test complete workflows
2. **Documentation**: Update implementation documentation
3. **Final Review**: Code review and final adjustments

---

## 🎯 **Detailed Test Implementation Plan**

### **Test Base Class Structure**
```solidity
contract TestBase_IndexedexBalancerV3_StandardExchangeRouter 
is TestBase_Indexedex_Balancer_V3 {
    
    // IStandardExchangeRouter public standardRouter;
    
    // Strategy vaults for testing
    IStandardExchange public usdcStrategyVault;
    IStandardExchange public daiStrategyVault;
    
    // Balancer pools for testing
    address public usdcDaiPool;
    address public wethUsdcPool;
    
    function setUp() public virtual override {
        super.setUp();
        
        // Deploy or get standard router instance
        // standardRouter = IStandardExchangeRouter(address(balancerV3StandardExchangeRouter()));
        
        // Setup strategy vaults and pools
        _setupStrategyVaults();
        _setupBalancerPools();
    }
}
```

### **Test File Implementation Order**

#### **Priority 1: Strategy Vault Tests**
- **File**: `IStandardExchangeRouter_StrategyVault_Tests.sol`
- **Focus**: Direct strategy vault operations (deposit/withdrawal)
- **Key Tests**: 
  - USDC → Strategy Vault Shares (deposit)
  - Strategy Vault Shares → USDC (withdrawal)
  - Exact out variants

#### **Priority 2: Intermediation Tests**
- **File**: `IStandardExchangeRouter_Intermediation_Tests.sol`
- **Focus**: Strategy vault pre/post swap conversion
- **Key Tests**:
  - USDC → Strategy Vault → Balancer Pool → DAI
  - USDC → Balancer Pool → Strategy Vault → DAI

#### **Priority 3: ETH Integration Tests**
- **File**: `IStandardExchangeRouter_ETH_Tests.sol`
- **Focus**: ETH/WETH integration with strategy vaults
- **Key Tests**:
  - ETH → Strategy Vault (with WETH wrapping)
  - Strategy Vault → ETH (with WETH unwrapping)

#### **Priority 4: Error Handling Tests**
- **File**: `IStandardExchangeRouter_Error_Tests.sol`
- **Focus**: Error scenarios and edge cases
- **Key Tests**:
  - Invalid strategy vault address
  - Insufficient liquidity
  - Expired deadline
  - Slippage exceeded

### **Expected Test Outcomes**
- **Initial Tests Will Fail**: Due to missing implementation details
- **Failures Will Drive Implementation**: Each failing test identifies implementation gaps
- **Iterative Improvement**: Fix implementation, expand test coverage, repeat
- **Final Result**: Comprehensive test coverage for Standard Router

---

## 📦 **Deliverables**

### **Code Deliverables**

- ✅ **Completed `BalancerV3StandardExchangeRouterDFPkg.sol`** (implementation mostly complete)
- ✅ **Completed `BalancerV3StandardExchangeBatchRouterFacet.sol`** (implementation complete)
- ❌ **Missing Standard Router Tests**: Need 4 comprehensive test files
- ✅ **Batch Router Tests**: Excellent coverage with 7 comprehensive test files
- ✅ **Integration tests with existing strategy vault system**

### **Documentation Deliverables**

- ✅ **Updated API documentation**
- ✅ **Implementation patterns guide**
- ✅ **Testing guide and examples**
- ✅ **Deployment instructions**

---

## 🔗 **Related Documents**

- **IndexerDex_BalancerV3_Router_Integration_PRD.md**: Original router integration requirements
- **ERC4626-Strategy-Vault-Pool-PRD.md**: ERC4626 strategy vault pool implementation
- **BALANCER_V3_IMPLEMENTATION_GUIDE.md**: Balancer V3 implementation patterns
- **PLAN.md**: Strategy vault orchestrator pool implementation plan

---

This PRD provides a comprehensive roadmap for completing the Balancer V3 router integration with strategy vaults, ensuring both standard and batch routers work correctly with the existing IndexedEx infrastructure. 