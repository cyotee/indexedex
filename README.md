# IndexedEx: Modular DeFi Vault Infrastructure

[![License](https://img.shields.io/badge/license-BUSL--1.1-blue.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-^0.8.0-lightgrey.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/foundry-compatible-green.svg)](https://getfoundry.sh/)

IndexedEx is a sophisticated DeFi infrastructure that provides modular, upgradeable vault strategies with integrated cross-protocol orchestration. Built on a 3-tier deployment architecture using the Diamond Pattern, it enables seamless interaction across multiple DeFi protocols including Uniswap V2, Camelot V2, and Balancer V3.

## 🏗️ Architecture Overview

IndexedEx implements a **3-tier deployment pattern**: **Facets → Packages → Proxies**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     FACETS      │───▶│    PACKAGES     │───▶│     PROXIES     │
│  (Logic Units)  │    │ (Bundled Logic) │    │ (User Interface)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Tier 1: Facets 🔧
Individual logic components deployed via CREATE3 for deterministic addressing:

- **Core Vault Logic**: `StandardVaultFacet`, `ConstantProductStrategyVaultFacet`
- **Fee Management**: `VaultFeeOracleQueryFacet`, `VaultFeeOracleManagerFacet`
- **Registry System**: `VaultRegistryDeploymentFacet`, `VaultRegistryQueryFacet`
- **Protocol Integrations**: UniswapV2, CamelotV2, BalancerV3 specific facets

### Tier 2: Packages 📦
Diamond Factory Packages that bundle related facets:

- **`VaultFeeOracleDFPkg`**: Fee management system
- **`VaultRegistryDFPkg`**: Vault registry and deployment coordination
- **`UniswapV2StandardStrategyVaultPkg`**: UniswapV2 strategy vaults
- **`CamelotV2StandardStrategyVaultPkg`**: CamelotV2 strategy vaults

### Tier 3: Proxies 🎯
Diamond proxies serving as business logic interfaces:

- **`IVaultFeeOracle`**: Fee management interface
- **`IVaultRegistry`**: Central vault registry
- **`IUniswapV2StandardStrategyVault`**: UniswapV2 vault instances
- **`ICamelotV2StandardStrategyVault`**: CamelotV2 vault instances

## 🚀 Deployment Process

### 1. Facet Deployment

```solidity
// Deploy individual logic components
standardVaultFacet_ = StandardVaultFacet(
    factory().create3(
        STANDARD_VAULT_FACET_INITCODE,
        "",
        keccak256(abi.encode(type(StandardVaultFacet).name))
    )
);
```

### 2. Package Assembly

```solidity
// Bundle facets into cohesive packages
vaultFeeOracleDFPkg_ = VaultFeeOracleDFPkg(
    factory().create3(
        VAULT_FEE_ORACLE_DFPKG_INITCODE,
        abi.encode(
            IVaultFeeOracleDFPkg.VaultFeeOraclePkgInit({
                ownableFacet: ownableFacet(),
                feeOracleQueryFacet: vaultFeeOracleQueryFacet(),
                feeOracleManagerFacet: vaultFeeOracleManagerFacet()
            })
        ),
        keccak256(abi.encode(type(VaultFeeOracleDFPkg).name))
    )
);
```

### 3. Proxy Deployment

```solidity
// Deploy business logic interfaces
vaultFeeOracle_ = IVaultFeeOracle(
    diamondFactory().deploy(
        vaultFeeOracleDFPkg(),
        abi.encode(
            IVaultFeeOracleDFPkg.VaultFeeOraclePkgArgs({
                owner: owner_,
                feeTo: feeTo_,
                defaultVaultFee: defaultVaultFee_,
                defaultDexFee: defaultDexFee_,
                defaultLendingFee: defaultLendingFee_
            })
        )
    )
);
```

## 🗺️ Address Mapping Convention

IndexedEx uses a **dual mapping strategy** for component discovery:

### Package Mapping (Implementation)
```solidity
// Use initcode hash for package instances
registerInstance(chainid, VAULT_FEE_ORACLE_DFPKG_INITCODE_HASH, address(package));
```

### Proxy Mapping (Interface)
```solidity
// Use interface name hash for proxy instances
registerInstance(chainid, keccak256(abi.encode(type(IVaultRegistry).name)), address(proxy));
```

This separation ensures:
- **Packages** are discoverable by their implementation bytecode
- **Proxies** are discoverable by their business interface

## 💼 Vault Strategy Deployment Example

Complete flow for deploying a UniswapV2 strategy vault:

```solidity
// 1. Deploy required facets
standardVaultFacet();
constantProductStrategyVaultFacet();
uniswapV2StandardExchangeInFacet();
uniswapV2StandardExchangeOutFacet();

// 2. Deploy strategy package
UniswapV2StandardStrategyVaultPkg pkg = uniswapV2StandardStrategyVaultPkg();

// 3. Deploy specific vault instance
IUniswapV2StandardStrategyVault vault = IUniswapV2StandardStrategyVault(
    pkg.deployVault(uniswapV2Pair)
);
```

## 🔧 Development Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/) for smart contract development
- [Node.js](https://nodejs.org/) for tooling and scripts
- [Git](https://git-scm.com/) with submodules support

### Installation

```bash
# Clone the repository
git clone https://github.com/cyotee/indexedex.git
cd indexedex

# Initialize submodules
git submodule update --init --recursive

# Install dependencies
npm install

# Install Foundry dependencies
forge install
```

### Build

```bash
# Compile contracts
forge build

# Run tests
forge test

# Run with verbosity for detailed output
forge test -vvv
```

## 🧪 Testing

IndexedEx includes comprehensive test suites covering:

- **Unit Tests**: Individual facet functionality
- **Integration Tests**: Package assembly and deployment
- **End-to-End Tests**: Complete vault strategy workflows
- **Cross-Protocol Tests**: Multi-protocol orchestration

### Running Tests

```bash
# All tests
forge test

# Specific test file
forge test --match-path test/integration/StrategyVaultOrchestratorPool.t.sol

# Specific test function
forge test --match-test testComprehensiveSwapOrchestration
```

## 🏗️ Testing Architecture

IndexedEx implements a **sophisticated multi-layered testing architecture** that mirrors our Diamond Proxy deployment pattern and ensures comprehensive validation across all protocol integrations.

### 🚨 CRITICAL: CREATE3 Deployment Requirements

**NEVER USE `new` TO DEPLOY ANYTHING IN OUR CODEBASE**

All component deployments MUST use the Create2CallBackFactory with the create3 function. This is a non-negotiable architectural requirement that ensures:

- **Deterministic addresses** across chains
- **Consistent deployment patterns** throughout the codebase  
- **Factory-managed lifecycles** for all components
- **Proper registration and tracking** of deployed contracts

#### ❌ FORBIDDEN PATTERNS
```solidity
// NEVER DO THIS - Will cause compilation/test failures
StandardVaultFacet facet = new StandardVaultFacet();
YourPoolPackage package = new YourPoolPackage(initData);
AnyContract instance = new AnyContract();
```

#### ✅ REQUIRED PATTERNS
```solidity
// ALWAYS DO THIS - Use factory create3 deployment
StandardVaultFacet facet = StandardVaultFacet(
    factory().create3(
        type(StandardVaultFacet).creationCode,
        abi.encode(ICreate3Aware.CREATE3InitData({
            salt: keccak256(abi.encode(type(StandardVaultFacet).name)),
            initData: ""
        })),
        keccak256(abi.encode(type(StandardVaultFacet).name))
    )
);
```

### 🎯 Testing Layer Architecture

Our testing follows a **4-tier validation hierarchy**:

```
┌─────────────────────────┐  1. IFacet Tests
│    TestBase_IFacet      │     Individual facet interface validation
│  YourFacet_IFacet_Test  │     Function selector & interface compliance
└─────────────────────────┘
           ↓
┌─────────────────────────┐  2. Vault Infrastructure  
│ BetterBalancerV3VaultTest│     CREATE3 factory setup, vault deployment
│   Permit2 Integration   │     Core Balancer V3 infrastructure
└─────────────────────────┘
           ↓
┌─────────────────────────┐  3. Pool Foundation Tests
│BetterBalancerV3BasePool │     Standard pool functionality validation
│        Test             │     Liquidity ops, swaps, fee management
└─────────────────────────┘
           ↓
┌─────────────────────────┐  4. Custom Implementation
│  YourSpecificPoolTest   │     Pool-specific logic & math validation
│   + Script_YourPool     │     Diamond proxy deployment & integration
└─────────────────────────┘
```

### 📂 Test Directory Structure

```
test/foundry/
├── vaults/standard/
│   ├── StandardVaultFacet_IFacet_Test.t.sol           # Core vault facet tests
│   ├── ConstantProductStrategyVaultFacet_IFacet_Test.t.sol
│   └── integrations/
│       └── protocols/
│           ├── uniswap/v2/
│           │   ├── UniswapV2StandardExchangeInFacet_IFacet_Test.t.sol
│           │   └── UniswapV2StandardExchangeOutFacet_IFacet_Test.t.sol
│           ├── camelot/v2/
│           │   └── CamelotV2Integration_Test.t.sol
│           └── balancer/v3/
│               ├── BalancerV3ConstantProductPoolStandardVaultTest.t.sol
│               ├── ConstantProductMultiPoolTest.t.sol
│               └── StrategyVaultOrchestratorPool.t.sol
└── pools/balancer/v3/
    └── strategy-vault-orchestrator/
        └── comprehensive/
            └── BalancerV3ComprehensiveTests.t.sol
```

### 🔥 IFacet Testing Pattern (Tier 1)

**EVERY facet MUST have a dedicated IFacet test** that validates interface compliance:

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { TestBase_IFacet } from "@crane/contracts/test/bases/TestBase_IFacet.sol";
import { Test_Crane } from "@crane/contracts/test/Test_Crane.sol";
import { Script_Crane } from "@crane/contracts/script/Script_Crane.sol";
import { IFacet } from "@crane/contracts/interfaces/IFacet.sol";
import { YourFacet } from "contracts/path/to/YourFacet.sol";
import { IYourInterface } from "contracts/interfaces/IYourInterface.sol";
import { TestBase_Indexedex } from "contracts/test/bases/TestBase_Indexedex.sol";

contract YourFacet_IFacet_Test is TestBase_IFacet, TestBase_Indexedex {
    
    YourFacet public yourFacetInstance;  // ✅ Use descriptive names without "test" prefix
    
    function setUp() public override(Test_Crane, TestBase_Indexedex) {
        super.setUp();
        console.log("Setting up YourFacet IFacet test...");
        
        // ✅ Deploy via CREATE3 factory pattern - NEVER use new!
        yourFacetInstance = yourFacet();
        
        console.log("YourFacet deployed at: %s", address(yourFacetInstance));
    }
    
    function run() public override(Script_Crane, TestBase_Indexedex) {
        // super.run(); // ✅ Comment out for performance - don't deploy unnecessary components
    }
    
    // ✅ REQUIRED: Return the facet instance for testing
    function facetTestInstance() public view override returns (IFacet) {
        return IFacet(address(yourFacetInstance));
    }
    
    // ✅ REQUIRED: Define expected interfaces
    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IYourInterface).interfaceId;
        return controlInterfaces;
    }
    
    // ✅ REQUIRED: Define expected function selectors
    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](3);  // Count must match exactly
        controlFuncs[0] = IYourInterface.function1.selector;
        controlFuncs[1] = IYourInterface.function2.selector;
        controlFuncs[2] = IYourInterface.function3.selector;
        return controlFuncs;
    }
}
```

### 🏗️ BetterBalancerV3BasePoolTest Integration (Tier 3)

**The foundational testing layer** for all Balancer V3 Diamond Proxy pools:

#### **Core Responsibilities:**

1. **Pool Lifecycle Management** - Complete setup from vault to pool deployment
2. **Standard Functionality Tests** - 6 core test patterns every pool must pass:
   - `testPoolAddress()` - CREATE2 deployment address validation
   - `testPoolPausedState()` - Pause window configuration
   - `testInitialize()` - Initial liquidity and BPT minting
   - `testAddLiquidity()` - Proportional liquidity addition
   - `testRemoveLiquidity()` - Proportional liquidity removal
   - `testSwap()` - Basic swap functionality

3. **Fee Management Testing** - Min/max fee bounds enforcement
4. **Diamond Proxy Integration** - All interactions through proxy interface

#### **Your Pool Test Implementation:**

```solidity
contract YourPoolTest is BetterBalancerV3BasePoolTest, Script_YourPool {
    using CastingHelpers for address[];
    using ArrayHelpers for *;

    uint256 constant TOKEN_AMOUNT = 1e3 * 1e18;

    function setUp() public override {
        expectedAddLiquidityBptAmountOut = TOKEN_AMOUNT;
        super.setUp();  // ← Calls BetterBalancerV3BasePoolTest.setUp()
        
        // Set pool-specific fee bounds
        poolMinSwapFeePercentage = 1e12; // 0.0001%
        poolMaxSwapFeePercentage = 0.10e18; // 10%
        
        // Deploy all required facets and package via script
        run();
    }

    function createPoolFactory() internal override returns (address) {
        // Return the package deployed via Script_YourPool.run()
        return address(yourPoolPackage());
    }

    function createPool() internal override returns (address newPool, bytes memory poolArgs) {
        // Use pre-configured test tokens (dai, usdc from BetterBalancerV3VaultTest)
        IERC20[] memory sortedTokens = InputHelpers.sortTokens(
            [address(dai), address(usdc)].toMemoryArray().asIERC20()
        );

        poolTokens = sortedTokens;
        tokenAmounts = [TOKEN_AMOUNT, TOKEN_AMOUNT].toMemoryArray();

        TokenConfig[] memory tokenConfigs = new TokenConfig[](2);
        tokenConfigs[0] = TokenConfig({
            token: sortedTokens[0],
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        tokenConfigs[1] = TokenConfig({
            token: sortedTokens[1],
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        // ✅ CORRECT: Deploy via vault registry deployment facet (proxy pattern)
        IYourPoolPackage.YourPoolPackageArgs memory packageArgs = IYourPoolPackage.YourPoolPackageArgs({
            tokenConfigs: tokenConfigs,
            hooksContract: address(0)
        });

        newPool = vaultRegistryDeploymentFacet().deployVault(
            IStandardVaultPkg(address(yourPoolPackage())),
            abi.encode(packageArgs)
        );
        
        poolArgs = abi.encode(packageArgs);
    }

    function initPool() internal override {
        vm.startPrank(lp);
        bptAmountOut = _initPool(
            pool,
            tokenAmounts,
            expectedAddLiquidityBptAmountOut - DELTA
        );
        vm.stopPrank();
    }
}
```

### 🚀 Script Integration Pattern

All tests MUST inherit from corresponding Script classes for proper CREATE3 deployment:

```solidity
// ✅ REQUIRED SCRIPT STRUCTURE
contract Script_YourComponent is Script_Crane {
    
    // ✅ REQUIRED: CREATE3 deployment function
    function yourComponent() public returns(YourComponent yourComponent_) {
        if(address(yourComponent(block.chainid)) == address(0)) {
            // ✅ ALWAYS use factory().create3() - NEVER new
            yourComponent_ = YourComponent(
                factory().create3(
                    YOUR_COMPONENT_INITCODE,
                    abi.encode(initArgs),
                    keccak256(abi.encode(type(YourComponent).name))
                )
            );
            yourComponent(block.chainid, yourComponent_);
        }
        return yourComponent(block.chainid);
    }
}
```

### 🎪 Integration & Cross-Protocol Testing (Tier 4)

#### **Multi-Protocol Orchestration Tests:**
```solidity
function testComprehensiveSwapOrchestration() public {
    // Test all 10 swap routes
    // Validate cross-protocol token flows
    // Ensure proper fee distribution
    // Verify strategy vault coordination
}
```

#### **Router Integration Tests:**
```solidity
function test_router_swap_integration() public {
    vm.startPrank(alice);
    
    uint256 amountIn = 100e18;
    uint256 initialDaiBalance = dai.balanceOf(alice);
    uint256 initialUsdcBalance = usdc.balanceOf(alice);
    
    // Setup approvals for Permit2
    dai.approve(address(permit2), amountIn);
    permit2.approve(address(dai), address(router), type(uint160).max, type(uint48).max);
    
    // ✅ Execute swap via router - pool is the proxy address
    router.swapSingleTokenExactIn(
        pool,  // ← Diamond proxy address
        dai,
        usdc,
        amountIn,
        0, // minAmountOut
        type(uint256).max, // deadline
        false, // ethIsWeth
        bytes("")
    );
    
    // Verify swap occurred
    assertEq(dai.balanceOf(alice), initialDaiBalance - amountIn, "Should spend exact DAI");
    assertGt(usdc.balanceOf(alice), initialUsdcBalance, "Should receive USDC");
    
    vm.stopPrank();
}
```

### ⚡ Performance Optimizations

1. **Comment out super.run()** for faster test execution:
```solidity
function run() public override(Script_Crane, TestBase_Indexedx) {
    // super.run(); // ✅ Comment out for performance optimization
}
```

2. **Run specific test categories:**
```bash
# Test all IFacet implementations
forge test --match-test test_IFacet -vvvv

# Test specific protocol integration
forge test --match-path test/foundry/vaults/standard/integrations/protocols/balancer/v3/ -vvv

# Test comprehensive orchestration
forge test --match-test testComprehensiveSwapOrchestration -vvvv
```

### 🛡️ Architecture Compliance Checklist

Before any code submission, verify ALL requirements:

#### Deployment Architecture
- [ ] **Zero `new` keywords** anywhere in codebase
- [ ] **All deployments use factory().create3()**
- [ ] **All scripts inherit from Script_Crane**
- [ ] **All components use CREATE3 deployment pattern**

#### Test Architecture  
- [ ] **All tests inherit from appropriate TestBase classes**
- [ ] **Test_Crane and Script_Crane explicitly imported**
- [ ] **Override specifications include ALL required contracts**
- [ ] **Variable names avoid "test" prefix**
- [ ] **Tests interact through proxies, not facets directly**

#### Code Quality
- [ ] **Consistent logging patterns following Script_Crane style**
- [ ] **Proper chain ID registration for all components**
- [ ] **Builder key patterns followed for all scripts**

This comprehensive testing architecture ensures your Diamond Proxy implementations maintain consistency, reliability, and full compliance with our CREATE3 factory system while providing thorough validation across all protocol integrations! 🏗️⚡

## 📊 Supported Protocols

| Protocol | Status | Vault Types | Features |
|----------|--------|-------------|----------|
| **Uniswap V2** | ✅ Active | Standard Strategy | LP token management, auto-compounding |
| **Camelot V2** | ✅ Active | Standard Strategy | LP token management, auto-compounding |
| **Balancer V3** | ✅ Active | Constant Product, Orchestrator | Pool creation, multi-token strategies |

## 🔒 Security Features

- **Diamond Pattern**: Modular, upgradeable architecture
- **CREATE3 Deployment**: Deterministic addresses across chains
- **Access Control**: Role-based permissions via Diamond facets
- **Fee Management**: Configurable fees with oracle integration
- **Registry System**: Centralized vault tracking and validation

## 📁 Project Structure

```
indexedex/
├── contracts/
│   ├── constants/           # Deployment constants and initcode
│   ├── interfaces/          # Contract interfaces
│   ├── oracles/            # Fee and price oracles
│   ├── registry/           # Vault registry system
│   ├── vaults/             # Vault implementations
│   └── scripts/            # Deployment scripts
├── test/                   # Test suites
├── docs/                   # Documentation
└── tasks/                  # Task management
```

## 🌟 Key Features

### Modular Architecture
- **Reusable Facets**: Logic components shared across protocols
- **Package System**: Bundled deployment for complex systems
- **Diamond Proxies**: Upgradeable business logic interfaces

### Cross-Protocol Orchestration
- **10 Swap Routes**: Comprehensive token exchange paths
- **Strategy Coordination**: Multi-vault orchestration
- **Unified Interface**: Single point of interaction

### Advanced Deployment
- **CREATE3 Factory**: Deterministic cross-chain addresses
- **Registry Integration**: Centralized component management
- **Automated Configuration**: Self-configuring deployment scripts

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Run the test suite: `forge test`
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the Business Source License 1.1 - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Documentation](docs/)
- [Balancer V3 Integration Guide](BALANCER_V3_IMPLEMENTATION_GUIDE.md)
- [Implementation Plan](PLAN.md)
- [Progress Tracking](PROGRESS.md)

## ⚠️ Disclaimer

This software is provided "as is" without warranty. Use at your own risk. Always conduct thorough testing and audits before deploying to mainnet.

## Balancer V3 Facets & Architecture

The Balancer V3 integration in IndexedEx is implemented using a modular set of facets, each responsible for a specific aspect of pool logic, fee management, and vault interaction. Key facets include:

- **BalancerV3ERC4626AdaptorPoolHooksFacet:** ERC4626 adaptation and pool hooks logic.
- **BalancerV3VaultAwareFacet:** Vault-aware pool logic for registry and orchestration.
- **BalancerV3ERC4626AdaptorPoolFacet:** Core ERC4626 pool logic.
- **BetterBalancerV3PoolTokenFacet:** Pool token management and accounting.
- **Fee and Invariant Facets:** `ZeroSwapFeePercentageBoundsFacet`, `StandardUnbalancedLiquidityInvariantRatioBoundsFacet`, `StandardSwapFeePercentageBoundsFacet`, `BalancedLiquidityInvariantRatioBoundsFacet` for enforcing protocol fee and invariant rules.
- **VaultGuardModifiers:** Access and state guard logic for vaults.

All facets are deployed via the CREATE3 factory pattern, ensuring deterministic addresses and upgradability.

## Balancer V3 Documentation

For detailed lifecycle, deployment, and testing patterns, see:

- [Balancer V3 Pool Lifecycle (Consolidated)](lib/crane/docs/protocols/dexes/balancer/v3/balancer-v3-pool-lifecycle-consolidated.md)
- [Balancer V3 Testing Guide (Consolidated)](lib/crane/docs/protocols/dexes/balancer/v3/balancer-v3-testing-guide-consolidated.md)

These documents provide step-by-step guidance for implementing, deploying, and testing Balancer V3 pools in IndexedEx.

## Balancer V3 Test Suites

Balancer V3 pool and strategy tests are located in:

- `lib/crane/test/foundry/spec/protocols/dexes/balancer/v3/`
- `test/foundry/protocols/dexes/balancer/v3/` (main repo, for IndexedEx-specific integration and orchestration tests)

Tests follow the multi-layered architecture described above, with dedicated suites for pool adaptors, strategy vaults, and comprehensive integration scenarios.

## Unique Features of Balancer V3 Integration

- **Vault Awareness:** Pools are tightly integrated with the IndexedEx vault registry for orchestration and cross-protocol strategies.
- **Advanced Fee Logic:** Multiple facets enforce protocol-specific fee bounds and invariant ratios.
- **Comprehensive Testing:** All pool logic is validated through a multi-tiered test suite, ensuring compliance with both Balancer and IndexedEx standards.

---

**IndexedEx** - Building the future of modular DeFi infrastructure 🚀

anvil --fork-url sepolia_alchemy

forge script scripts/foundry/UI_Dev_Anvil.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
