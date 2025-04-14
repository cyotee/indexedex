# **ERC4626 Strategy Vault Pool Implementation - Project Requirements Document**

## 📋 **Project Overview**

**Project Name:** ERC4626 Strategy Vault Pool Implementation  
**Version:** 1.0  
**Date:** December 2024  
**Status:** Requirements Definition Phase  

### **Objective**
Implement a new Balancer V3 pool type that enables efficient liquidity provision and trading using ERC4626 wrapped strategy vaults as pool tokens, leveraging our existing Diamond Proxy pattern and infrastructure.

---

## 🎯 **Business Requirements**

### **Primary Goals**
1. **Create a Balancer V3 pool** that holds ERC4626 wrapper tokens as liquidity
2. **Enable seamless swaps** between various tokens through strategy vault intermediation
3. **Leverage existing infrastructure** including VaultRegistry, VaultFeeOracle, and strategy vaults
4. **Maintain gas efficiency** through optimized pool math and minimal external calls
5. **Ensure composability** with existing Balancer V3 ecosystem and our vault system

### **Secondary Goals**
1. **Establish reusable patterns** for future pool implementations
2. **Demonstrate advanced Diamond Proxy** usage with pool-specific facets
3. **Create comprehensive testing suite** following our architectural standards
4. **Document implementation patterns** for team knowledge sharing

---

## 🛠️ **Technical Requirements**

### **Architectural Constraints**
- **MANDATORY**: All deployments MUST use `factory().create3()` - NEVER `new`
- **MANDATORY**: Follow Diamond Proxy pattern using Package-based deployment
- **MANDATORY**: Inherit from existing base classes and leverage common facets
- **MANDATORY**: Use Balancer V3 interfaces and comply with vault requirements
- **MANDATORY**: Maintain CREATE3 deployment consistency across all components

### **Core Components to Implement**

#### **1. Pool-Specific Facet** 
**File**: `contracts/pools/balancer/v3/erc4626/ERC4626StrategyVaultPoolFacet.sol`

```solidity
interface IERC4626StrategyVaultPool is IBasePool {
    function getUnderlyingTokens() external view returns (IERC20[] memory);
    function getVaultWrappers() external view returns (IERC4626[] memory);
    function getStrategyVaults() external view returns (address[] memory);
    function swapViaVault(
        uint256 indexIn,
        uint256 indexOut, 
        uint256 amountIn,
        address recipient
    ) external returns (uint256 amountOut);
}
```

**Key Features**:
- **Pool Math**: Implement constant product formula for wrapped vault tokens
- **Vault Integration**: Interface with our existing strategy vault system
- **Wrapper Logic**: Handle ERC4626 deposit/withdraw operations seamlessly
- **Fee Handling**: Integrate with VaultFeeOracle for dynamic fee calculation

#### **2. Package Implementation**
**File**: `contracts/pools/balancer/v3/erc4626/ERC4626StrategyVaultPoolPackage.sol`

**Required Facets**:
- ✅ `StandardVaultFacet` (existing)
- ✅ `BalancerV3VaultAwareFacet` (existing) 
- ✅ `BetterBalancerV3PoolTokenFacet` (existing)
- ✅ `DefaultPoolInfoFacet` (existing)
- ✅ `StandardSwapFeePercentageBoundsFacet` (existing)
- ✅ `BalancedLiquidityInvariantRatioBoundsFacet` (existing)
- ✅ `BalancerV3AuthenticationFacet` (existing)
- 🆕 `ERC4626StrategyVaultPoolFacet` (to implement)

#### **3. Script Implementation**
**File**: `contracts/scripts/Script_ERC4626StrategyVaultPool.sol`

**Must Follow Pattern**:
```solidity
contract Script_ERC4626StrategyVaultPool is Script_Crane {
    // ✅ REQUIRED: CREATE3 deployment for facet
    function erc4626StrategyVaultPoolFacet() public returns(ERC4626StrategyVaultPoolFacet) {
        // Must use factory().create3() - NEVER new
    }
    
    // ✅ REQUIRED: CREATE3 deployment for package
    function erc4626StrategyVaultPoolPackage() public returns(ERC4626StrategyVaultPoolPackage) {
        // Must use factory().create3() - NEVER new
    }
}
```

---

## 🧱 **Existing Components We Can Leverage**

### **✅ Core Vault Infrastructure**
From `Script_Indexedex.sol`, we already have:

- **VaultFeeOracle system** (query, manager, dfpkg)
- **VaultRegistry system** (deployment, query, dfpkg) 
- **StandardVaultFacet** - Core vault functionality
- **ConstantProductStrategyVaultFacet** - Strategy vault logic

### **✅ ERC4626 Wrapper Infrastructure**
We already have comprehensive ERC4626 wrapper support:

- **`ERC4626Wrapper.sol`** - Complete ERC4626 wrapper implementation
- **Integration patterns** with our vault system
- **Fee handling** through existing oracle infrastructure

### **✅ Balancer V3 Foundation**
From `Script_BalancerV3.sol` and related components:

- **Core deployment infrastructure** for Balancer V3 pools
- **Common facet implementations** (pool token, vault aware, authentication)
- **Fee and invariant bounds facets** ready for use
- **Testing infrastructure** via `BetterBalancerV3BasePoolTest`

### **✅ Strategy Vault Implementations**
We have proven patterns for:

- **UniswapV2StandardStrategyVault** - Production-ready implementation
- **CamelotV2StandardStrategyVault** - Alternative DEX integration
- **Package-based deployment** with proper CREATE3 factory usage

---

## 🎯 **Implementation Strategy**

### **Phase 1: Core Pool Facet Implementation**
**Duration**: 2-3 days

1. **Create `ERC4626StrategyVaultPoolFacet`**:
   - Implement `IBasePool` interface with pool math optimized for wrapped vault tokens
   - Handle swap calculations accounting for vault conversion rates
   - Integrate with existing `VaultFeeOracle` for dynamic fee management
   - Support efficient batch operations for multiple vault interactions

2. **Implement Pool Math**:
   - **Invariant**: Modified constant product accounting for vault exchange rates
   - **Swap calculations**: Handle underlying token ↔ vault token conversions
   - **Liquidity operations**: Support proportional and single-token operations

### **Phase 2: Package and Script Development**
**Duration**: 1-2 days

1. **Create `ERC4626StrategyVaultPoolPackage`**:
   - Combine all required facets into cohesive diamond configuration
   - Initialize with proper Balancer V3 registration
   - Handle pool-specific argument passing and validation

2. **Develop `Script_ERC4626StrategyVaultPool`**:
   - Follow established `Script_Crane` patterns exactly
   - Deploy all components using CREATE3 factory (NEVER `new`)
   - Register components properly with chain ID mapping

### **Phase 3: Comprehensive Testing Suite**
**Duration**: 2-3 days

1. **IFacet Compliance Tests**:
   ```solidity
   contract ERC4626StrategyVaultPoolFacet_IFacet_Test is TestBase_IFacet, TestBase_Indexedex {
       // ✅ Test facet interface compliance
       // ✅ Validate function selectors
       // ✅ Verify deployment via CREATE3
   }
   ```

2. **Pool Functionality Tests**:
   ```solidity
   contract ERC4626StrategyVaultPoolTest is BetterBalancerV3BasePoolTest, Script_ERC4626StrategyVaultPool {
       // ✅ Test pool math through proxy
       // ✅ Test router integration
       // ✅ Test liquidity operations
       // ✅ Test fee handling
   }
   ```

3. **Integration Tests**:
   - Router swap integration through proxy addresses
   - Multi-vault liquidity provision scenarios
   - Fee collection and distribution validation
   - Edge case handling (zero liquidity, large swaps, etc.)

---

## 🔧 **Technical Implementation Details**

### **Pool Math Specifications**

#### **Modified Constant Product Formula**
```solidity
// Account for vault exchange rates in invariant calculation
function computeInvariant(uint256[] memory balancesScaled18, Rounding rounding) 
    external pure returns (uint256 invariant) {
    
    // Get underlying token amounts from vault wrappers
    uint256[] memory underlyingBalances = _getUnderlyingBalances(balancesScaled18);
    
    // Apply constant product: invariant = sqrt(x * y * z...)
    return _computeConstantProductInvariant(underlyingBalances);
}
```

#### **Swap Calculation with Vault Integration**
```solidity
function onSwap(PoolSwapParams calldata params) 
    external view returns (uint256 amountCalculatedScaled18) {
    
    // Convert vault tokens to underlying for calculation
    uint256 underlyingAmountIn = _convertToUnderlying(
        params.indexIn, 
        params.amountGivenScaled18
    );
    
    // Apply constant product swap math
    uint256 underlyingAmountOut = _calcConstantProductSwap(
        underlyingBalances[params.indexIn],
        underlyingBalances[params.indexOut], 
        underlyingAmountIn
    );
    
    // Convert back to vault token amount
    return _convertFromUnderlying(params.indexOut, underlyingAmountOut);
}
```

### **Integration Points**

#### **Strategy Vault Integration**
```solidity
interface IStrategyVaultIntegration {
    function getUnderlyingToken() external view returns (IERC20);
    function getVaultWrapper() external view returns (IERC4626);
    function convertToUnderlying(uint256 vaultTokenAmount) external view returns (uint256);
    function convertFromUnderlying(uint256 underlyingAmount) external view returns (uint256);
}
```

#### **Fee Oracle Integration**
```solidity
// Leverage existing VaultFeeOracle for dynamic fee calculation
uint256 swapFee = vaultFeeOracle.getSwapFee(
    address(this),           // pool address
    address(tokenIn),        // input token
    address(tokenOut),       // output token
    amountIn                 // swap amount for dynamic fees
);
```

---

## 🧪 **Testing Requirements**

### **Mandatory Testing Patterns**

#### **1. IFacet Compliance (REQUIRED)**
```solidity
contract ERC4626StrategyVaultPoolFacet_IFacet_Test is TestBase_IFacet, TestBase_Indexedex {
    ERC4626StrategyVaultPoolFacet public poolFacetInstance;
    
    function setUp() public override(Test_Crane, TestBase_Indexedex) {
        super.setUp();
        // ✅ Deploy via CREATE3 - NEVER new
        poolFacetInstance = erc4626StrategyVaultPoolFacet();
    }
    
    function facetTestInstance() public view override returns (IFacet) {
        return IFacet(address(poolFacetInstance));
    }
    
    function controlFacetInterfaces() public pure override returns (bytes4[] memory) {
        bytes4[] memory interfaces = new bytes4[](1);
        interfaces[0] = type(IBasePool).interfaceId;
        return interfaces;
    }
    
    function controlFacetFuncs() public pure override returns (bytes4[] memory) {
        bytes4[] memory funcs = new bytes4[](3);
        funcs[0] = IBasePool.onSwap.selector;
        funcs[1] = IBasePool.computeInvariant.selector;
        funcs[2] = IBasePool.computeBalance.selector;
        return funcs;
    }
}
```

#### **2. Pool Integration Testing (REQUIRED)**
```solidity
contract ERC4626StrategyVaultPoolTest is BetterBalancerV3BasePoolTest, Script_ERC4626StrategyVaultPool {
    
    function setUp() public override {
        super.setUp();
        // Deploy via script to get proper CREATE3 deployment
        run();
    }
    
    function createPoolFactory() internal override returns (address) {
        return address(erc4626StrategyVaultPoolPackage());
    }
    
    function createPool() internal override returns (address newPool, bytes memory poolArgs) {
        // ✅ Deploy via vault registry (proxy pattern)
        newPool = vaultRegistryDeploymentFacet().deployVault(
            IStandardVaultPkg(address(erc4626StrategyVaultPoolPackage())),
            abi.encode(packageArgs)
        );
    }
}
```

### **Test Coverage Requirements**
- **✅ Pool Math Accuracy**: All swap and liquidity calculations
- **✅ Vault Integration**: Proper ERC4626 wrapper interactions
- **✅ Fee Handling**: Integration with VaultFeeOracle
- **✅ Router Integration**: Full swap workflow through Balancer router
- **✅ Edge Cases**: Zero liquidity, large amounts, rounding errors
- **✅ Gas Optimization**: Benchmark against standard pools

---

## 📊 **Success Criteria**

### **Functional Requirements**
- [ ] **Pool deploys successfully** via Diamond Proxy pattern
- [ ] **All Balancer V3 interfaces** implemented and working
- [ ] **Swap operations execute** with correct math and fee handling
- [ ] **Liquidity operations** (add/remove) function properly
- [ ] **Router integration** works seamlessly
- [ ] **Fee collection** integrates with existing VaultFeeOracle

### **Performance Requirements**
- [ ] **Gas efficiency**: Comparable to standard Balancer V3 pools
- [ ] **Swap accuracy**: <0.01% deviation from expected mathematical results
- [ ] **Rate calculations**: Proper handling of vault exchange rate fluctuations

### **Quality Requirements**
- [ ] **100% test coverage** on pool math functions
- [ ] **IFacet compliance** tests pass for all facets
- [ ] **Integration tests** pass for router and vault interactions
- [ ] **Code follows** established patterns and architectural requirements
- [ ] **No usage of `new`** anywhere in codebase - all CREATE3 deployments

### **Documentation Requirements**
- [ ] **Implementation guide** updated with new pool type
- [ ] **API documentation** for new interfaces
- [ ] **Usage examples** for pool creation and interaction
- [ ] **Gas optimization notes** and best practices

---

## 🚨 **Critical Architecture Requirements**

### **MANDATORY DEPLOYMENT PATTERNS**
1. **NEVER use `new`** - All deployments MUST use `factory().create3()`
2. **Script inheritance** - Follow `Script_Crane` pattern exactly
3. **Diamond Proxy** - Use Package-based deployment only
4. **Proxy interaction** - Never call facets directly, always through proxy
5. **CREATE3 consistency** - Apply to ALL components including tests

### **FORBIDDEN PATTERNS**
```solidity
// ❌ NEVER DO THESE - Will break architecture
StandardVaultFacet facet = new StandardVaultFacet();
ERC4626StrategyVaultPoolFacet pool = new ERC4626StrategyVaultPoolFacet();
YourPoolPackage package = new YourPoolPackage(initData);

// ✅ ALWAYS DO THIS - Use factory CREATE3 deployment
StandardVaultFacet facet = StandardVaultFacet(
    factory().create3(
        STANDARD_VAULT_FACET_INITCODE,
        abi.encode(initArgs),
        keccak256(abi.encode(type(StandardVaultFacet).name))
    )
);
```

---

## 📅 **Implementation Timeline**

### **Week 1: Foundation (Days 1-3)**
- **Day 1**: Implement `ERC4626StrategyVaultPoolFacet` with core pool math
- **Day 2**: Create pool math unit tests and validate calculations
- **Day 3**: Implement vault integration and wrapper handling

### **Week 2: Integration (Days 4-6)**
- **Day 4**: Create `ERC4626StrategyVaultPoolPackage` and deployment script
- **Day 5**: Implement comprehensive IFacet compliance tests
- **Day 6**: Create pool integration tests with router and vault interactions

### **Week 3: Validation (Days 7-9)**
- **Day 7**: Performance testing and gas optimization
- **Day 8**: Edge case testing and error handling validation
- **Day 9**: Documentation updates and final integration testing

---

## 🔍 **Risk Assessment**

### **Technical Risks**
- **Pool Math Complexity**: ERC4626 rate calculations may introduce precision errors
  - *Mitigation*: Extensive testing with various vault exchange rates
- **Gas Efficiency**: Multiple vault calls could increase transaction costs
  - *Mitigation*: Optimize call patterns and cache exchange rates where possible
- **Integration Complexity**: Coordinating multiple existing systems
  - *Mitigation*: Leverage proven patterns from existing strategy vault implementations

### **Architectural Risks**
- **CREATE3 Deployment Failures**: Incorrect factory usage could break deployment
  - *Mitigation*: Follow established Script_Crane patterns exactly
- **Diamond Proxy Conflicts**: Function selector collisions between facets
  - *Mitigation*: Careful interface design and comprehensive testing
- **Test Coverage Gaps**: Missing edge cases could cause production issues
  - *Mitigation*: Mandatory IFacet tests and comprehensive integration testing

---

## 📚 **Dependencies**

### **External Dependencies**
- **Balancer V3 Core**: Latest stable release with IBasePool interface
- **OpenZeppelin**: ERC4626 interfaces and utilities
- **Existing Crane Framework**: Factory, Diamond, and testing infrastructure

### **Internal Dependencies**
- **VaultFeeOracle**: For dynamic fee calculation and management
- **VaultRegistry**: For pool registration and deployment
- **Strategy Vault System**: For underlying token exposure and operations
- **Existing Facets**: Common Balancer V3 functionality (pool token, authentication, etc.)

---

## 🎯 **Post-Implementation Goals**

### **Knowledge Transfer**
- **Document patterns** for future pool implementations
- **Create developer guide** for ERC4626 pool usage
- **Establish testing standards** for new pool types

### **Future Enhancements**
- **Multi-strategy support**: Pools with different strategy types
- **Dynamic rebalancing**: Automated optimization across strategies
- **Advanced fee models**: Performance-based fee structures
- **Cross-chain compatibility**: Deploy across multiple networks

---

**Document Status**: ✅ **APPROVED FOR IMPLEMENTATION**  
**Next Action**: Begin Phase 1 - Core Pool Facet Implementation  
**Responsibility**: Development Team  
**Review Date**: After each phase completion 