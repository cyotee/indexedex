# Balancer V3 Pool Implementation and Testing Guide (Diamond Proxy Pattern)

This guide provides a comprehensive overview of how to implement custom Balancer V3 pools using our **Diamond Proxy Package-based deployment pattern**, based on proven patterns from successful implementations in our codebase.

## 🚨 CRITICAL DEPLOYMENT REQUIREMENT

**NEVER USE `new` TO DEPLOY ANYTHING IN OUR CODEBASE**

All component deployments MUST use the Create2CallBackFactory with the create3 function. This is a non-negotiable architectural requirement that ensures:

- **Deterministic addresses** across chains
- **Consistent deployment patterns** throughout the codebase  
- **Factory-managed lifecycles** for all components
- **Proper registration and tracking** of deployed contracts

### ❌ FORBIDDEN PATTERNS
```solidity
// NEVER DO THIS - Will cause compilation/test failures
StandardVaultFacet facet = new StandardVaultFacet();
YourPoolPackage package = new YourPoolPackage(initData);
AnyContract instance = new AnyContract();
```

### ✅ REQUIRED PATTERNS
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

**This requirement applies to:**
- All facet deployments
- All package deployments  
- All test contract deployments
- All component initialization
- Any contract creation whatsoever

## Table of Contents

1. [Diamond Proxy Pool Architecture](#diamond-proxy-pool-architecture)
2. [Factory System and CREATE3 Deployment](#factory-system-and-create3-deployment)
3. [Package Structure](#package-structure)
4. [Common Facet Implementations](#common-facet-implementations)
5. [Pool-Specific Facet Implementation](#pool-specific-facet-implementation)
6. [Package Deployment](#package-deployment)
7. [Testing Infrastructure](#testing-infrastructure)
8. [Core Functionality Tests](#core-functionality-tests)
9. [Integration Tests](#integration-tests)
10. [Common Pitfalls](#common-pitfalls)

## Diamond Proxy Pool Architecture

### Why Diamond Proxy Pattern

Unlike standard Balancer V3 pools that inherit from `BalancerPoolToken`, we use the **Diamond Proxy pattern** to:

- **Modular Design**: Break functionality into composable facets
- **Code Reuse**: Common implementations shared across pool types
- **Upgrade Safety**: Add/remove/replace functionality without redeployment
- **Gas Efficiency**: Only include needed functionality per pool
- **Standardization**: Consistent deployment via Package pattern

### Core Components

1. **Diamond Proxy**: The deployed pool contract (EIP-2535)
2. **Facets**: Individual contracts implementing specific functionality
3. **Package**: Factory that defines which facets to combine
4. **Package Factory**: Deploys diamonds using the package configuration

## Factory System and CREATE3 Deployment

### 🔥 MANDATORY CREATE3 DEPLOYMENT PATTERN

Our system **REQUIRES** all component deployment through the Create2CallBackFactory system. **NO EXCEPTIONS.**

### Understanding Our Factory Architecture

Our system uses a layered factory approach for deterministic deployment:

1. **Create2CallBackFactory**: Base factory for CREATE3 deployments (**REQUIRED FOR ALL DEPLOYMENTS**)
2. **DiamondPackageCallBackFactory**: Specialized for diamond proxy packages
3. **Package Contracts**: Define which facets to combine
4. **Individual Facets**: Deployed using CREATE3 for consistent addresses

### ⚠️ CRITICAL: Never Use `new` - Always Use create3

**The `new` keyword is FORBIDDEN in our codebase.** All deployments must follow the CREATE3 pattern:

#### ❌ NEVER DO THIS:
```solidity
// FORBIDDEN - Will cause test failures and architectural violations
standardVaultFacet = new StandardVaultFacet();
yourPoolFacet = new YourPoolFacet();
package = new YourPoolPackage(initData);
```

#### ✅ ALWAYS DO THIS:
```solidity
// REQUIRED - Use factory().create3() for ALL deployments
standardVaultFacet = StandardVaultFacet(
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

### Deploying Facets with CREATE3 - MANDATORY PATTERN

Follow the pattern from `Script_Crane.sol` for **ALL** component deployments:

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { Script_Crane } from "@crane/contracts/script/Script_Crane.sol";
import { YourPoolFacet } from "./YourPoolFacet.sol";

contract Script_YourPool is Script_Crane {
    
    function yourPoolFacet(
        uint256 chainid,
        YourPoolFacet yourPoolFacet_
    ) public returns(bool) {
        console.log("Script_YourPool:yourPoolFacet(uint256,YourPoolFacet):: Entering function.");
        console.log("Script_YourPool:yourPoolFacet(uint256,YourPoolFacet):: Storing instance mapped to chainId %s.", chainid);
        console.log("Script_YourPool:yourPoolFacet(uint256,YourPoolFacet):: Storing instance mapped to initCodeHash: %s.", YOUR_POOL_FACET_INIT_CODE_HASH);
        console.log("Script_YourPool:yourPoolFacet(uint256,YourPoolFacet):: Instance to store: %s.", address(yourPoolFacet_));
        registerInstance(chainid, YOUR_POOL_FACET_INIT_CODE_HASH, address(yourPoolFacet_));
        console.log("Script_YourPool:yourPoolFacet(uint256,YourPoolFacet):: Declaring instance.");
        declare(builderKey_YourPool(), "yourPoolFacet", address(yourPoolFacet_));
        console.log("Script_YourPool:yourPoolFacet(uint256,YourPoolFacet):: Exiting function.");
        return true;
    }

    function yourPoolFacet(YourPoolFacet yourPoolFacet_) public returns(bool) {
        console.log("Script_YourPool:yourPoolFacet(YourPoolFacet):: Entering function.");
        console.log("Script_YourPool:yourPoolFacet(YourPoolFacet):: Setting provided facet of %s.", address(yourPoolFacet_));
        yourPoolFacet(block.chainid, yourPoolFacet_);
        console.log("Script_YourPool:yourPoolFacet(YourPoolFacet):: Exiting function.");
        return true;
    }

    function yourPoolFacet(uint256 chainid)
    public virtual view returns(YourPoolFacet yourPoolFacet_) {
        console.log("Script_YourPool:yourPoolFacet(uint256):: Entering function.");
        console.log("Script_YourPool:yourPoolFacet(uint256):: Retrieving instance mapped to chainId %s.", chainid);
        console.log("Script_YourPool:yourPoolFacet(uint256):: Retrieving instance mapped to initCodeHash: %s.", YOUR_POOL_FACET_INIT_CODE_HASH);
        yourPoolFacet_ = YourPoolFacet(chainInstance(chainid, YOUR_POOL_FACET_INIT_CODE_HASH));
        console.log("Script_YourPool:yourPoolFacet(uint256):: Instance retrieved: %s.", address(yourPoolFacet_));
        console.log("Script_YourPool:yourPoolFacet(uint256):: Exiting function.");
        return yourPoolFacet_;
    }

    /**
     * @notice Deploy your pool facet using CREATE3 for deterministic addresses
     * @dev CRITICAL: NEVER use 'new' - ALWAYS use factory().create3()
     * @return yourPoolFacet_ The deployed facet
     */
    function yourPoolFacet() public returns(YourPoolFacet yourPoolFacet_) {
        console.log("Script_YourPool:yourPoolFacet():: Entering function.");
        console.log("Script_YourPool:yourPoolFacet():: Checking if YourPoolFacet is declared.");
        if(address(yourPoolFacet(block.chainid)) == address(0)) {
            console.log("YourPoolFacet not set on this chain, deploying...");
            console.log("Script_YourPool:yourPoolFacet():: Creating instance using CREATE3 - NEVER use new!");
            
            // ✅ REQUIRED PATTERN: factory().create3() deployment
            yourPoolFacet_ = YourPoolFacet(
                factory().create3(
                    YOUR_POOL_FACET_INIT_CODE,
                    abi.encode(ICreate3Aware.CREATE3InitData({
                        salt: keccak256(abi.encode(type(YourPoolFacet).name)),
                        initData: ""
                    })),
                    keccak256(abi.encode(type(YourPoolFacet).name))
                )
            );
            console.log("Script_YourPool:yourPoolFacet():: YourPoolFacet deployed @ ", address(yourPoolFacet_));
            console.log("Script_YourPool:yourPoolFacet():: Storing facet for later use.");
            yourPoolFacet(block.chainid, yourPoolFacet_);
        }
        console.log("Script_YourPool:yourPoolFacet():: Returning stored instance.");
        yourPoolFacet_ = yourPoolFacet(block.chainid);
        console.log("Script_YourPool:yourPoolFacet():: Exiting function.");
        return yourPoolFacet_;
    }

    function builderKey_YourPool() public pure returns (string memory) {
        return "yourpool";
    }
}
```

### Deploying Packages with DiamondFactory

```solidity
function yourPoolPackage() public returns (YourPoolPackage yourPoolPackage_) {
    console.log("Script_YourPool:yourPoolPackage():: Entering function.");
    console.log("Script_YourPool:yourPoolPackage():: Checking if YourPoolPackage is declared.");
    if (address(yourPoolPackage(block.chainid)) == address(0)) {
        console.log("Script_YourPool:yourPoolPackage():: YourPoolPackage not declared, deploying...");
        console.log("Script_YourPool:yourPoolPackage():: Setting Package initialization arguments.");
        
        IYourPoolPackage.YourPoolPackageInit memory yourPoolPkgInit;
        console.log("Script_YourPool:yourPoolPackage():: Setting standardVaultFacet to ", address(standardVaultFacet()));
        yourPoolPkgInit.standardVaultFacet = standardVaultFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting balancerV3VaultAwareFacet to ", address(balancerV3VaultAwareFacet()));
        yourPoolPkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting betterBalancerv3PoolTokenFacet to ", address(betterBalancerV3PoolTokenFacet()));
        yourPoolPkgInit.betterBalancerv3PoolTokenFacet = betterBalancerV3PoolTokenFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting defaultPoolInfoFacet to ", address(defaultPoolInfoFacet()));
        yourPoolPkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting standardSwapFeePercentageBoundsFacet to ", address(standardSwapFeePercentageBoundsFacet()));
        yourPoolPkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting balancedLiquidityInvariantRatioBoundsFacet to ", address(balancedLiquidityInvariantRatioBoundsFacet()));
        yourPoolPkgInit.balancedLiquidityInvariantRatioBoundsFacet = balancedLiquidityInvariantRatioBoundsFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting balancerV3AuthenticationFacet to ", address(balancerV3AuthenticationFacet()));
        yourPoolPkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting yourPoolFacet to ", address(yourPoolFacet()));
        yourPoolPkgInit.yourPoolFacet = yourPoolFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting vaultRegistry to ", address(vaultRegistryDeploymentFacet()));
        yourPoolPkgInit.vaultRegistry = vaultRegistryDeploymentFacet();
        console.log("Script_YourPool:yourPoolPackage():: Setting vaultFeeOracle to ", address(vaultFeeOracle()));
        yourPoolPkgInit.vaultFeeOracle = vaultFeeOracle();
        console.log("Script_YourPool:yourPoolPackage():: Setting balancerV3Vault to ", address(balancerV3Vault()));
        yourPoolPkgInit.balancerV3Vault = balancerV3Vault();

        console.log("Script_YourPool:yourPoolPackage():: Deploying YourPoolPackage using CREATE3.");
        yourPoolPackage_ = YourPoolPackage(
            factory().create3(
                YOUR_POOL_PACKAGE_INIT_CODE,
                abi.encode(yourPoolPkgInit),
                keccak256(abi.encode(type(YourPoolPackage).name))
            )
        );
        console.log("Script_YourPool:yourPoolPackage():: YourPoolPackage deployed @ ", address(yourPoolPackage_));
        console.log("Script_YourPool:yourPoolPackage():: Setting package for later use.");
        yourPoolPackage(yourPoolPackage_);
        console.log("Script_YourPool:yourPoolPackage():: Package set for later use.");
    }
    console.log("Script_YourPool:yourPoolPackage():: Returning stored instance.");
    yourPoolPackage_ = yourPoolPackage(block.chainid);
    console.log("Script_YourPool:yourPoolPackage():: Exiting function.");
    return yourPoolPackage_;
}
```

### Constants File (CraneINITCODE.sol)

Add your init code constants:

```solidity
// Add to crane/contracts/constants/CraneINITCODE.sol

// Your Pool Facet
bytes constant YOUR_POOL_FACET_INIT_CODE = /* compiled bytecode */;
bytes32 constant YOUR_POOL_FACET_INIT_CODE_HASH = keccak256(YOUR_POOL_FACET_INIT_CODE);

// Your Pool Package  
bytes constant YOUR_POOL_PACKAGE_INIT_CODE = /* compiled bytecode */;
bytes32 constant YOUR_POOL_PACKAGE_INIT_CODE_HASH = keccak256(YOUR_POOL_PACKAGE_INIT_CODE);
```

## Package Structure

### Package Base Class

All Balancer V3 pool packages inherit from our base classes:

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { Create3AwareContract } from "@crane/contracts/factories/create2/aware/Create3AwareContract.sol";
import { BalancerV3BasePoolFactoryTarget } from "@crane/contracts/protocols/dexes/balancer/v3/pool-utils/BalancerV3BasePoolFactoryTarget.sol";
import { IDiamondFactoryPackage } from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import { IStandardVaultPkg } from "../../../../../../interfaces/IStandardVaultPkg.sol";

contract YourPoolPackage is 
    Create3AwareContract,
    BalancerV3BasePoolFactoryTarget,
    StandardVaultStorage,
    BetterBalancerV3PoolTokenStorage,
    IDiamondFactoryPackage,
    IStandardVaultPkg
{
    // Package implementation...
}
```

### Package Interface Definition

Define the package initialization structure:

```solidity
interface IYourPoolPackage {
    struct YourPoolPackageInit {
        IFacet standardVaultFacet;
        IFacet balancerV3VaultAwareFacet;
        IFacet betterBalancerv3PoolTokenFacet;
        IFacet defaultPoolInfoFacet;
        IFacet standardSwapFeePercentageBoundsFacet;
        IFacet balancedLiquidityInvariantRatioBoundsFacet;
        IFacet balancerV3AuthenticationFacet;
        IFacet yourPoolSpecificFacet;  // Your custom facet
        IVaultRegistryDeployment vaultRegistry;
        IVaultFeeOracle vaultFeeOracle;
        IVault balancerV3Vault;
    }

    struct YourPoolPackageArgs {
        TokenConfig[] tokenConfigs;
        address hooksContract;
        // Additional pool-specific arguments
    }
}
```

## Common Facet Implementations

We provide standard facet implementations for common Balancer V3 functionality:

### 1. **BetterBalancerV3PoolTokenFacet** 
*Replaces inheriting from `BalancerPoolToken`*

```solidity
// Provides ERC20 functionality and pool token behavior
// Located at: crane/contracts/protocols/dexes/balancer/v3/BetterBalancerV3PoolTokenFacet.sol

contract BetterBalancerV3PoolTokenFacet is 
    Create3AwareContract,
    BetterBalancerV3PoolTokenStorage,
    BetterERC20Permit,
    VaultGuardModifiers,
    IBalancerPoolToken,
    IFacet
{
    // Implements ERC20, ERC20Permit, IRateProvider, IBalancerPoolToken
    function getRate() public view virtual returns (uint256) {
        return _balV3Vault().getBptRate(address(this));
    }
}
```

### 2. **DefaultPoolInfoFacet**
*Provides pool information interface*

```solidity
// Located at: crane/contracts/protocols/dexes/balancer/v3/pool-utils/DefaultPoolInfoFacet.sol

contract DefaultPoolInfoFacet is 
    Create3AwareContract, 
    BalancerV3VaultAwareStorage, 
    IFacet, 
    IPoolInfo 
{
    function getTokens() external view returns (IERC20[] memory) {
        return _balV3Vault().getPoolTokens(address(this));
    }
    
    function getCurrentLiveBalances() external view returns (uint256[] memory) {
        return _balV3Vault().getCurrentLiveBalances(address(this));
    }
    // ... other IPoolInfo implementations
}
```

### 3. **Swap Fee Bounds Facets**

Choose appropriate swap fee bounds for your pool:

**StandardSwapFeePercentageBoundsFacet**: 0.0001% - 10%
```solidity
// crane/contracts/protocols/dexes/balancer/v3/StandardSwapFeePercentageBoundsFacet.sol
function getMinimumSwapFeePercentage() external pure returns (uint256) {
    return 1e12; // 0.0001%
}
function getMaximumSwapFeePercentage() external pure returns (uint256) {
    return 0.10e18; // 10%
}
```

**ZeroSwapFeePercentageBoundsFacet**: 0% - 0% (no fees)
```solidity
// crane/contracts/protocols/dexes/balancer/v3/ZeroSwapFeePercentageBoundsFacet.sol
function getMinimumSwapFeePercentage() external pure returns (uint256) {
    return 0;
}
function getMaximumSwapFeePercentage() external pure returns (uint256) {
    return 0;
}
```

### 4. **Invariant Ratio Bounds Facets**

**StandardUnbalancedLiquidityInvariantRatioBoundsFacet**: 70% - 300%
```solidity
// crane/contracts/protocols/dexes/balancer/v3/StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol
function getMinimumInvariantRatio() external pure returns (uint256) {
    return 70e16; // 70%
}
function getMaximumInvariantRatio() external pure returns (uint256) {
    return 300e16; // 300%
}
```

**BalancedLiquidityInvariantRatioBoundsFacet**: 100% - 100% (proportional only)
```solidity
// crane/contracts/protocols/dexes/balancer/v3/BalancedLiquidityInvariantRatioBoundsFacet.sol
function getMinimumInvariantRatio() external pure returns (uint256) {
    return ONE_WAD; // 100%
}
function getMaximumInvariantRatio() external pure returns (uint256) {
    return ONE_WAD; // 100% - Only balanced additions allowed
}
```

## Pool-Specific Facet Implementation

Create your custom pool math facet implementing `IBasePool`:

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { IBasePool } from "@balancer-labs/v3-interfaces/contracts/vault/IBasePool.sol";
import { PoolSwapParams, Rounding } from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import { SwapKind } from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import { Create3AwareContract } from "@crane/contracts/factories/create2/aware/Create3AwareContract.sol";
import { IFacet } from "@crane/contracts/interfaces/IFacet.sol";

contract YourPoolFacet is Create3AwareContract, IBasePool, IFacet {
    
    constructor(CREATE3InitData memory create3InitData_)
    Create3AwareContract(create3InitData_) {}

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBasePool).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = IBasePool.onSwap.selector;
        funcs[1] = IBasePool.computeInvariant.selector;
        funcs[2] = IBasePool.computeBalance.selector;
    }

    function onSwap(PoolSwapParams calldata params) 
        external 
        pure 
        returns (uint256 amountCalculatedScaled18) 
    {
        // Implement your pool's swap math
        if (params.kind == SwapKind.EXACT_IN) {
            // Calculate amount out for given amount in
            amountCalculatedScaled18 = _calcAmountOut(
                params.balancesScaled18[params.indexIn],
                params.balancesScaled18[params.indexOut],
                params.amountGivenScaled18
            );
        } else {
            // Calculate amount in for given amount out
            amountCalculatedScaled18 = _calcAmountIn(
                params.balancesScaled18[params.indexIn],
                params.balancesScaled18[params.indexOut],
                params.amountGivenScaled18
            );
        }
    }

    function computeInvariant(
        uint256[] memory balancesLiveScaled18,
        Rounding rounding
    ) public pure returns (uint256 invariant) {
        // Implement your pool's invariant calculation
        // Example for constant product: invariant = sqrt(x * y)
        return _computeConstantProductInvariant(balancesLiveScaled18);
    }

    function computeBalance(
        uint256[] memory balancesLiveScaled18,
        uint256 tokenInIndex,
        uint256 invariantRatio
    ) external pure returns (uint256 newBalance) {
        // Implement balance calculation for add/remove liquidity
        return _computeBalanceForInvariantRatio(
            balancesLiveScaled18, 
            tokenInIndex, 
            invariantRatio
        );
    }

    // Internal math functions...
    function _calcAmountOut(uint256 balanceIn, uint256 balanceOut, uint256 amountIn) 
        internal pure returns (uint256) {
        // Constant product: dy = (Y * dx) / (X + dx)
        return (balanceOut * amountIn) / (balanceIn + amountIn);
    }
}
```

## Package Deployment

### Package Configuration

```solidity
contract YourPoolPackage is /* base classes */ {
    
    // Store facet references
    IFacet immutable STANDARD_VAULT_FACET;
    IFacet immutable BALANCER_V3_VAULT_AWARE_FACET;
    IFacet immutable BETTER_BALANCER_V3_POOL_TOKEN_FACET;
    IFacet immutable DEFAULT_POOL_INFO_FACET;
    IFacet immutable STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET;
    IFacet immutable UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET;
    IFacet immutable BALANCER_V3_AUTHENTICATION_FACET;
    IFacet immutable YOUR_POOL_FACET;

    constructor(CREATE3InitData memory create3InitData) 
    Create3AwareContract(create3InitData) {
        YourPoolPackageInit memory init_ = abi.decode(initData, (YourPoolPackageInit));
        
        // Store all facet references
        STANDARD_VAULT_FACET = init_.standardVaultFacet;
        BALANCER_V3_VAULT_AWARE_FACET = init_.balancerV3VaultAwareFacet;
        BETTER_BALANCER_V3_POOL_TOKEN_FACET = init_.betterBalancerv3PoolTokenFacet;
        DEFAULT_POOL_INFO_FACET = init_.defaultPoolInfoFacet;
        STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET = init_.standardSwapFeePercentageBoundsFacet;
        UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET = init_.balancedLiquidityInvariantRatioBoundsFacet;
        BALANCER_V3_AUTHENTICATION_FACET = init_.balancerV3AuthenticationFacet;
        YOUR_POOL_FACET = init_.yourPoolFacet;
        
        VAULT_REGISTRY = init_.vaultRegistry;
        VAULT_FEE_ORACLE = init_.vaultFeeOracle;
        BALANCER_V3_VAULT = init_.balancerV3Vault;

        _initBalancerV3BasePoolFactory(
            BALANCER_V3_VAULT,
            keccak256(abi.encode(SELF)),
            365 days
        );
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](8);

        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: STANDARD_VAULT_FACET.facetFuncs()
        });

        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_VAULT_AWARE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_VAULT_AWARE_FACET.facetFuncs()
        });

        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(BETTER_BALANCER_V3_POOL_TOKEN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BETTER_BALANCER_V3_POOL_TOKEN_FACET.facetFuncs()
        });

        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(DEFAULT_POOL_INFO_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: DEFAULT_POOL_INFO_FACET.facetFuncs()
        });

        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET.facetFuncs()
        });

        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET.facetFuncs()
        });

        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_AUTHENTICATION_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_AUTHENTICATION_FACET.facetFuncs()
        });

        facetCuts_[7] = IDiamond.FacetCut({
            facetAddress: address(YOUR_POOL_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: YOUR_POOL_FACET.facetFuncs()
        });
    }

    function initAccount(bytes memory initArgs) public {
        YourPoolPackageArgs memory decodedArgs = 
            abi.decode(initArgs, (YourPoolPackageArgs));

        address[] memory tokens = new address[](decodedArgs.tokenConfigs.length);
        for (uint256 i = 0; i < decodedArgs.tokenConfigs.length; i++) {
            tokens[i] = address(decodedArgs.tokenConfigs[i].token);
        }

        _initStandardVault(VAULT_FEE_ORACLE, vaultTypes(), tokens);
        _initBetterBalancerV3PoolToken(BALANCER_V3_VAULT, "Your Pool Name", tokens);
        _initBalancerV3Authentication(BALANCER_V3_VAULT, keccak256(abi.encode(address(this))));
    }

    function postDeploy(address proxy) public returns (bytes memory) {
        _registerPoolWithBalV3Vault(
            BALANCER_V3_VAULT,
            proxy,
            _getTokenConfigs(proxy),
            VAULT_FEE_ORACLE.defaultDexFee(),
            getNewPoolPauseWindowEndTime(),
            false, // protocolFeeExempt
            _roleAccounts(),
            _getHooksContract(proxy),
            _liquidityManagement()
        );
        return "";
    }
}
```

## Testing Infrastructure

### 🚨 CRITICAL: Tests MUST Use CREATE3 Factory Pattern

**ALL TEST DEPLOYMENTS MUST USE factory().create3() - NEVER use `new`**

#### ❌ FORBIDDEN IN TESTS:
```solidity
// NEVER DO THIS - Violates our deployment architecture
function setUp() public override {
    standardVaultFacet = new StandardVaultFacet();  // FORBIDDEN
    yourPoolFacet = new YourPoolFacet();            // FORBIDDEN
    package = new YourPoolPackage(initData);        // FORBIDDEN
}

// DON'T DO THIS - This bypasses the proxy
function createPool() internal override returns (address newPool, bytes memory poolArgs) {
    // Wrong: calling package directly like a factory
    newPool = yourPoolPackage.deployVault(tokenConfigs, address(0));
}
```

#### ✅ REQUIRED IN TESTS:
```solidity
// ALWAYS DO THIS - Use factory().create3() deployment in tests
function setUp() public override {
    super.setUp();
    
    // ✅ Deploy facet using CREATE3 factory pattern
    standardVaultFacet = StandardVaultFacet(
        factory().create3(
            type(StandardVaultFacet).creationCode,
            abi.encode(ICreate3Aware.CREATE3InitData({
                salt: keccak256(abi.encode(type(StandardVaultFacet).name)),
                initData: ""
            })),
            keccak256(abi.encode(type(StandardVaultFacet).name))
        )
    );
}
```

**✅ CORRECT** - Using proxy deployment through vault registry:
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { BetterBalancerV3BasePoolTest } from "@crane/contracts/test/bases/protocols/BetterBalancerV3BasePoolTest.sol";
import { Script_YourPool } from "./Script_YourPool.sol";

contract YourPoolTest is BetterBalancerV3BasePoolTest, Script_YourPool {
    using CastingHelpers for address[];
    using ArrayHelpers for *;

    uint256 constant TOKEN_AMOUNT = 1e3 * 1e18;

    function setUp() public override {
        expectedAddLiquidityBptAmountOut = TOKEN_AMOUNT;
        super.setUp();
        
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

### Proper Proxy Interaction Pattern

```solidity
// ✅ CORRECT: Access facets through proxy
function test_pool_functionality() public {
    // The 'pool' variable is the diamond proxy address
    // All calls go through the proxy, not to facets directly
    
    // Test pool token functionality (via BetterBalancerV3PoolTokenFacet)
    assertEq(IERC20(pool).name(), "Your Pool Name");
    assertGt(IERC20(pool).totalSupply(), 0);
    
    // Test pool info functionality (via DefaultPoolInfoFacet)
    IERC20[] memory tokens = IPoolInfo(pool).getTokens();
    assertEq(tokens.length, 2);
    
    // Test swap functionality (via YourPoolFacet)
    PoolSwapParams memory params = PoolSwapParams({
        kind: SwapKind.EXACT_IN,
        amountGivenScaled18: 100e18,
        balancesScaled18: tokenAmounts,
        indexIn: 0,
        indexOut: 1,
        router: address(this),
        userData: ""
    });
    
    uint256 amountOut = IBasePool(pool).onSwap(params);
    assertGt(amountOut, 0);
}
```

### Script Integration in Tests

Inherit from your Script to get proper component deployment:

```solidity
contract YourPoolTest is BetterBalancerV3BasePoolTest, Script_YourPool {
    
    function setUp() public override {
        super.setUp();
        
        // Deploy all components via script
        run();
    }
    
    // Access deployed components via script functions
    function test_deployment_addresses() public view {
        assertNotEq(address(yourPoolFacet()), address(0), "Facet should be deployed");
        assertNotEq(address(yourPoolPackage()), address(0), "Package should be deployed");
        
        // Verify components are properly registered
        assertEq(
            address(yourPoolFacet()),
            address(yourPoolFacet(block.chainid)),
            "Facet should be registered for current chain"
        );
    }
}
```

## Core Functionality Tests

### Test Pool Math Functions Through Proxy

```solidity
function test_onSwap_exact_in() public view {
    PoolSwapParams memory params = PoolSwapParams({
        kind: SwapKind.EXACT_IN,
        amountGivenScaled18: 100e18,
        balancesScaled18: tokenAmounts,
        indexIn: 0,
        indexOut: 1,
        router: address(this),
        userData: ""
    });

    // ✅ Call through proxy (pool is the diamond proxy address)
    uint256 amountOut = IBasePool(pool).onSwap(params);
    assertGt(amountOut, 0, "Should return positive amount out");
}

function test_compute_invariant() public view {
    // ✅ Call through proxy
    uint256 invariant = IBasePool(pool).computeInvariant(
        tokenAmounts, 
        Rounding.ROUND_DOWN
    );
    assertGt(invariant, 0, "Invariant should be positive");
}

function test_facet_interfaces() public view {
    // ✅ Test proxy interface support
    assertTrue(IERC165(pool).supportsInterface(type(IERC20).interfaceId));
    assertTrue(IERC165(pool).supportsInterface(type(IBasePool).interfaceId));
    assertTrue(IERC165(pool).supportsInterface(type(IPoolInfo).interfaceId));
    assertTrue(IERC165(pool).supportsInterface(type(ISwapFeePercentageBounds).interfaceId));
}
```

### Test Diamond Proxy Functionality

```solidity
function test_diamond_configuration() public view {
    // ✅ Verify proxy configuration
    IDiamondLoupe diamond = IDiamondLoupe(pool);
    
    address[] memory facetAddresses = diamond.facetAddresses();
    assertGt(facetAddresses.length, 0, "Should have facets installed");
    
    // Test specific facet functions
    bytes4[] memory selectors = diamond.facetFunctionSelectors(facetAddresses[0]);
    assertGt(selectors.length, 0, "Facet should have selectors");
}

function test_package_deployment() public {
    // ✅ Test package can deploy pools via vault registry
    TokenConfig[] memory newTokenConfigs = /* create configs */;
    IYourPoolPackage.YourPoolPackageArgs memory packageArgs = IYourPoolPackage.YourPoolPackageArgs({
        tokenConfigs: newTokenConfigs,
        hooksContract: address(0)
    });

    address newPool = vaultRegistryDeploymentFacet().deployVault(
        IStandardVaultPkg(address(yourPoolPackage())),
        abi.encode(packageArgs)
    );
    
    assertNotEq(newPool, address(0), "Should deploy valid pool");
    assertNotEq(newPool, pool, "Should deploy different pool");
}
```

## Integration Tests

### Router Integration Tests

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
        pool,
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

## Solidity Override Specification Requirements

### 🔥 CRITICAL: Explicit Contract Imports for Override Specifications

When working with multiple inheritance in Solidity, you **MUST** explicitly import any contract that you reference in `override()` specifications. This is a fundamental Solidity requirement that our codebase strictly enforces.

#### The Problem
```solidity
// ❌ COMPILATION ERROR - Test_Crane not imported
contract MyTest is TestBase_IFacet, TestBase_Indexedex {
    function setUp() public override(Test_Crane) {  // ERROR: Test_Crane not in scope
        super.setUp();
    }
}
```

#### The Solution
```solidity
// ✅ CORRECT - Import all override contracts explicitly
import { TestBase_IFacet } from "@crane/contracts/test/bases/TestBase_IFacet.sol";
import { Test_Crane } from "@crane/contracts/test/Test_Crane.sol";          // ✅ EXPLICIT IMPORT
import { Script_Crane } from "@crane/contracts/script/Script_Crane.sol";    // ✅ EXPLICIT IMPORT
import { TestBase_Indexedex } from "contracts/test/bases/TestBase_Indexedex.sol";

contract MyTest is TestBase_IFacet, TestBase_Indexedex {
    function setUp() public override(Test_Crane, TestBase_Indexedex) {  // ✅ NOW WORKS
        super.setUp();
    }
}
```

### Multiple Inheritance Override Requirements

When inheriting from multiple contracts that define the same function, Solidity requires you to specify **ALL** contracts that implement that function:

#### ❌ Insufficient Override Specification
```solidity
// This will fail if both TestBase_IFacet and TestBase_Indexedex define setUp()
function setUp() public override(TestBase_Indexedex) {  // ❌ Missing Test_Crane
    super.setUp();
}
```

#### ✅ Complete Override Specification
```solidity
// Must specify ALL contracts in the inheritance chain that define this function
function setUp() public override(Test_Crane, TestBase_Indexedex) {  // ✅ Complete specification
    super.setUp();
}

function run() public override(Script_Crane, TestBase_Indexedex) {   // ✅ Complete specification
    // super.run();  // Often commented out for performance
}
```

### Standard Import Pattern for Tests

**ALWAYS** include these imports in test files:

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { TestBase_IFacet } from "@crane/contracts/test/bases/TestBase_IFacet.sol";
import { Test_Crane } from "@crane/contracts/test/Test_Crane.sol";        // ✅ REQUIRED FOR OVERRIDE
import { Script_Crane } from "@crane/contracts/script/Script_Crane.sol";  // ✅ REQUIRED FOR OVERRIDE
import { IFacet } from "@crane/contracts/interfaces/IFacet.sol";
import { YourFacet } from "contracts/path/to/YourFacet.sol";                // ✅ Your specific facet
import { IYourInterface } from "contracts/interfaces/IYourInterface.sol";   // ✅ Your facet's interface
import { TestBase_Indexedex } from "contracts/test/bases/TestBase_Indexedex.sol";
```

### Performance Optimization: Commenting out super.run()

For faster test execution, we typically comment out `super.run()` to avoid deploying unnecessary components:

```solidity
function run() public override(Script_Crane, TestBase_Indexedex) {
    // super.run();  // ✅ Commented out to avoid deploying unused components
}
```

This optimization prevents the deployment of components that won't be used in the specific test, significantly reducing test execution time.

## IFacet Testing Patterns

### 🔥 MANDATORY: Dedicated IFacet Tests for Every Facet

Based on practical implementation, **EVERY facet MUST have a dedicated IFacet test** that validates its interface compliance and function selectors. This is non-negotiable for maintaining architectural consistency.

### Complete IFacet Test Template

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

/**
 * @title YourFacet_IFacet_Test
 * @dev Tests the YourFacet implementation of IFacet interface
 */
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
    function testFacet() public view override returns (IFacet) {
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
        // Count your interface functions and adjust array size
        controlFuncs = new bytes4[](3);
        controlFuncs[0] = IYourInterface.function1.selector;
        controlFuncs[1] = IYourInterface.function2.selector;
        controlFuncs[2] = IYourInterface.function3.selector;
        return controlFuncs;
    }
}
```

### Critical Implementation Details

#### 1. **Function Selector Accuracy**
Ensure your `controlFacetFuncs()` returns **exactly** the selectors your facet implements:

```solidity
// ✅ CORRECT: Match your interface exactly
function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
    controlFuncs = new bytes4[](5);  // Count must match exactly
    controlFuncs[0] = IStandardVault.vaultTypes.selector;
    controlFuncs[1] = IStandardVault.tokens.selector;
    controlFuncs[2] = IStandardVault.vaultConfig.selector;
    controlFuncs[3] = IStandardVault.reserveOfToken.selector;
    controlFuncs[4] = IStandardVault.reserves.selector;
    return controlFuncs;
}

// ❌ WRONG: Mismatched count or incorrect selectors will cause test failures
```

#### 2. **Interface ID Specification**
Use `type(YourInterface).interfaceId` for automatic calculation:

```solidity
// ✅ CORRECT: Automatic interface ID calculation
controlInterfaces[0] = type(IStandardVault).interfaceId;
controlInterfaces[1] = type(IYourCustomInterface).interfaceId;

// ❌ WRONG: Hardcoded values can become outdated
controlInterfaces[0] = 0x12345678;
```

#### 3. **Variable Naming Convention**
Follow the established pattern to avoid Solidity reserved word conflicts:

```solidity
// ✅ CORRECT: Descriptive names with Instance suffix
StandardVaultFacet public standardVaultFacetInstance;
YourCustomFacet public yourCustomFacetInstance;

// ❌ FORBIDDEN: "test" prefix is reserved for test functions
StandardVaultFacet public testStandardVaultFacet;  // Compilation error!
```

### Testing Multiple Facets Pattern

When creating tests for multiple facets, follow this consistent structure:

```bash
# Directory structure for facet tests
test/foundry/vaults/standard/
├── StandardVaultFacet_IFacet_Test.t.sol
├── ConstantProductStrategyVaultFacet_IFacet_Test.t.sol
└── integrations/
    └── dexes/
        └── uniswap/
            └── v2/
                ├── UniswapV2StandardExchangeInFacet_IFacet_Test.t.sol
                └── UniswapV2StandardExchangeOutFacet_IFacet_Test.t.sol
```

Each test follows the **identical pattern**, ensuring consistency and maintainability across the entire codebase.

### Test Execution and Verification

Run tests with proper verbosity for debugging:

```bash
# Test specific facet
forge test --match-path test/foundry/vaults/standard/YourFacet_IFacet_Test.t.sol -vvvv

# Test all IFacet implementations
forge test --match-test test_IFacet -vvvv
```

Expected output for successful tests:
```
✅ test_IFacet_FacetFunctions() - Validates function selectors
✅ test_IFacet_FacetInterfaces() - Validates interface IDs  
✅ testFacet() - Validates facet deployment and accessibility
```

## Common Pitfalls

### 🚨 CRITICAL DEPLOYMENT VIOLATIONS

### ❌ What NOT to Do

1. **🚫 NEVER USE `new` FOR ANY DEPLOYMENT** - **MOST CRITICAL VIOLATION**:
```solidity
// ❌ FORBIDDEN - Will break our entire architecture
StandardVaultFacet facet = new StandardVaultFacet();
YourPoolFacet pool = new YourPoolFacet();
YourPoolPackage pkg = new YourPoolPackage(initData);
AnyContract anything = new AnyContract();
```

2. **Don't call facets directly**:
```solidity
// DON'T DO THIS - Bypasses proxy
uint256 result = yourPoolFacet().onSwap(params);
```

3. **Don't deploy components without factory**:
```solidity
// DON'T DO THIS - MUST use factory().create3()
YourPoolFacet facet = new YourPoolFacet();
```

4. **Don't call package as a factory**:
```solidity
// DON'T DO THIS - Use vault registry deployment facet
address pool = yourPoolPackage.deployVault(configs, hooks);
```

5. **Don't skip script inheritance**:
```solidity
// DON'T DO THIS - Missing script deployment
contract YourPoolTest is BetterBalancerV3BasePoolTest {
    // Missing Script_YourPool inheritance
}
```

6. **Don't use `new` in tests**:
```solidity
// DON'T DO THIS - Tests must also use factory().create3()
function setUp() public {
    facet = new MyFacet(); // FORBIDDEN IN TESTS TOO
}
```

7. **Don't use "test" prefix in variable names**:
```solidity
// DON'T DO THIS - Causes Solidity compilation errors
StandardVaultFacet public testStandardVaultFacet;  // FORBIDDEN

// DO THIS INSTEAD
StandardVaultFacet public standardVaultFacetInstance;  // ✅ CORRECT
```

8. **Don't forget explicit imports for override specifications**:
```solidity
// DON'T DO THIS - Missing explicit imports
function setUp() public override(Test_Crane) {  // ERROR: Test_Crane not imported
    super.setUp();
}

// DO THIS INSTEAD - Import explicitly
import { Test_Crane } from "@crane/contracts/test/Test_Crane.sol";
```

9. **Don't mismatch function selectors in IFacet tests**:
```solidity
// DON'T DO THIS - Wrong array size or selectors
function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
    controlFuncs = new bytes4[](3);  // Wrong size for 5 functions!
    controlFuncs[0] = 0x12345678;    // Wrong hardcoded selector!
}

// DO THIS INSTEAD - Match exactly
function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
    controlFuncs = new bytes4[](5);  // Correct size
    controlFuncs[0] = IYourInterface.function1.selector;  // Correct selector
}
```

### ✅ Best Practices

1. **🔥 ALWAYS USE factory().create3() - NEVER use `new`** - **TOP PRIORITY**
2. **Use CREATE3 deployment via Script_Crane pattern** for all components
3. **Interact with components through proxies** (vault registry deployment facet)
4. **Inherit from Script classes** in tests for proper component deployment
5. **Test through proxy addresses** not facet addresses directly
6. **Use vault registry deployment facet** for pool creation
7. **Follow the Script_Crane.sol pattern** for all component deployment
8. **Register all components** with proper chain ID mapping
9. **Test both pool math and router integration** through proxies
10. **Apply CREATE3 factory pattern in ALL tests** - no exceptions
11. **🆕 Create dedicated IFacet tests** for each facet using TestBase_IFacet pattern
12. **🆕 Use descriptive variable names** avoiding "test" prefix (use "Instance" suffix instead)
13. **🆕 Implement all required virtual functions** when inheriting from TestBase_IFacet
14. **🆕 Comment out super.run()** for performance unless components are actually needed
15. **🆕 Validate function selectors exactly** match interface implementations
16. **🆕 Use automatic interface ID calculation** with type().interfaceId pattern

## IFacet Testing Patterns

### 🔥 MANDATORY: Dedicated IFacet Tests for Every Facet

Based on practical implementation, **EVERY facet MUST have a dedicated IFacet test** that validates its interface compliance and function selectors. This is non-negotiable for maintaining architectural consistency.

### Complete IFacet Test Template

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

/**
 * @title YourFacet_IFacet_Test
 * @dev Tests the YourFacet implementation of IFacet interface
 */
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
        // Count your interface functions and adjust array size
        controlFuncs = new bytes4[](3);
        controlFuncs[0] = IYourInterface.function1.selector;
        controlFuncs[1] = IYourInterface.function2.selector;
        controlFuncs[2] = IYourInterface.function3.selector;
        return controlFuncs;
    }
}
```

### Critical Implementation Details

#### 1. **Function Selector Accuracy**
Ensure your `controlFacetFuncs()` returns **exactly** the selectors your facet implements:

```solidity
// ✅ CORRECT: Match your interface exactly
function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
    controlFuncs = new bytes4[](5);  // Count must match exactly
    controlFuncs[0] = IStandardVault.vaultTypes.selector;
    controlFuncs[1] = IStandardVault.tokens.selector;
    controlFuncs[2] = IStandardVault.vaultConfig.selector;
    controlFuncs[3] = IStandardVault.reserveOfToken.selector;
    controlFuncs[4] = IStandardVault.reserves.selector;
    return controlFuncs;
}

// ❌ WRONG: Mismatched count or incorrect selectors will cause test failures
```

#### 2. **Interface ID Specification**
Use `type(YourInterface).interfaceId` for automatic calculation:

```solidity
// ✅ CORRECT: Automatic interface ID calculation
controlInterfaces[0] = type(IStandardVault).interfaceId;
controlInterfaces[1] = type(IYourCustomInterface).interfaceId;

// ❌ WRONG: Hardcoded values can become outdated
controlInterfaces[0] = 0x12345678;
```

#### 3. **Variable Naming Convention**
Follow the established pattern to avoid Solidity reserved word conflicts:

```solidity
// ✅ CORRECT: Descriptive names with Instance suffix
StandardVaultFacet public standardVaultFacetInstance;
YourCustomFacet public yourCustomFacetInstance;

// ❌ FORBIDDEN: "test" prefix is reserved for test functions
StandardVaultFacet public testStandardVaultFacet;  // Compilation error!
```

### Testing Multiple Facets Pattern

When creating tests for multiple facets, follow this consistent structure:

```bash
# Directory structure for facet tests
test/foundry/vaults/standard/
├── StandardVaultFacet_IFacet_Test.t.sol
├── ConstantProductStrategyVaultFacet_IFacet_Test.t.sol
└── integrations/
    └── dexes/
        └── uniswap/
            └── v2/
                ├── UniswapV2StandardExchangeInFacet_IFacet_Test.t.sol
                └── UniswapV2StandardExchangeOutFacet_IFacet_Test.t.sol
```

Each test follows the **identical pattern**, ensuring consistency and maintainability across the entire codebase.

### Test Execution and Verification

Run tests with proper verbosity for debugging:

```bash
# Test specific facet
forge test --match-path test/foundry/vaults/standard/YourFacet_IFacet_Test.t.sol -vvvv

# Test all IFacet implementations
forge test --match-test test_IFacet -vvvv
```

Expected output for successful tests:
```
✅ test_IFacet_FacetFunctions() - Validates function selectors
✅ test_IFacet_FacetInterfaces() - Validates interface IDs  
✅ facetTestInstance() - Validates facet deployment and accessibility
```

## Applying This Knowledge Consistently

### 🔥 MANDATORY PATTERNS FOR ALL DEVELOPMENT

These patterns are **NON-NEGOTIABLE** and must be applied consistently across the entire codebase:

#### 1. CREATE3 Factory Deployment Pattern

**NEVER use `new` - ALWAYS use factory().create3()** for every single deployment:

```solidity
// ❌ FORBIDDEN - Will break architecture
MyContract instance = new MyContract();

// ✅ REQUIRED - Always use factory().create3()
MyContract instance = MyContract(
    factory().create3(
        MY_CONTRACT_INITCODE,
        abi.encode(initArgs),
        keccak256(abi.encode(type(MyContract).name))
    )
);
```

#### 2. Script_Crane Inheritance Pattern

**ALL scripts MUST inherit from Script_Crane** and follow the exact pattern:

```solidity
// ✅ REQUIRED SCRIPT STRUCTURE
contract Script_YourComponent is Script_Crane {
    
    // Storage functions (chainid, instance)
    function yourComponent(uint256 chainid, YourComponent yourComponent_) public returns(bool) { }
    function yourComponent(YourComponent yourComponent_) public returns(bool) { }
    function yourComponent(uint256 chainid) public view returns(YourComponent) { }
    
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

#### 3. Test Inheritance and Override Pattern

**ALL tests MUST follow this exact pattern**:

```solidity
// ✅ REQUIRED TEST STRUCTURE - IFacet Testing Pattern
import { TestBase_IFacet } from "@crane/contracts/test/bases/TestBase_IFacet.sol";
import { Test_Crane } from "@crane/contracts/test/Test_Crane.sol";          // ✅ EXPLICIT IMPORT REQUIRED
import { Script_Crane } from "@crane/contracts/script/Script_Crane.sol";    // ✅ EXPLICIT IMPORT REQUIRED
import { TestBase_Indexedex } from "contracts/test/bases/TestBase_Indexedex.sol";

contract YourFacet_IFacet_Test is TestBase_IFacet, TestBase_Indexedex {
    
    YourFacet public yourFacetInstance;  // ✅ AVOID "test" prefix for variables
    
    // ✅ REQUIRED: Complete override specification with explicit imports
    function setUp() public override(Test_Crane, TestBase_Indexedex) {
        super.setUp();
        console.log("Setting up YourFacet IFacet test...");
        
        // ✅ Deploy via CREATE3 factory pattern - NEVER use new!
        yourFacetInstance = yourFacet();
        
        console.log("YourFacet deployed at: %s", address(yourFacetInstance));
    }
    
    // ✅ REQUIRED: Complete override specification  
    function run() public override(Script_Crane, TestBase_Indexedx) {
        // super.run(); // ✅ Comment out for performance optimization
    }
    
    // ✅ REQUIRED: Implement TestBase_IFacet virtual functions
    function facetTestInstance() public view override returns (IFacet) {
        return IFacet(address(yourFacetInstance));
    }
    
    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IYourInterface).interfaceId;
        return controlInterfaces;
    }
    
    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](3);  // Adjust size based on your interface
        controlFuncs[0] = IYourInterface.function1.selector;
        controlFuncs[1] = IYourInterface.function2.selector;
        controlFuncs[2] = IYourInterface.function3.selector;
        return controlFuncs;
    }
}
```

#### 4. Variable Naming Conventions

**CRITICAL naming rules**:

```solidity
// ❌ FORBIDDEN - "test" prefix reserved for test functions
TestContract public testInstance;
TestContract public testContract;

// ✅ REQUIRED - Use descriptive names without "test" prefix
TestContract public testContractInstance;
TestContract public contractInstance;
StandardVaultFacet public standardVaultFacetInstance;
```

#### 5. Diamond Proxy Interaction Pattern

**ALWAYS interact through proxies, NEVER directly with facets**:

```solidity
// ❌ FORBIDDEN - Calling facets directly
uint256 result = yourPoolFacet().onSwap(params);

// ✅ REQUIRED - Call through proxy
uint256 result = IBasePool(poolProxyAddress).onSwap(params);
```

### Consistency Enforcement Checklist

Before any code submission, verify ALL of these requirements:

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

#### Performance Optimizations
- [ ] **super.run() commented out when not needed**
- [ ] **Only necessary components deployed in tests**
- [ ] **Proper proxy interaction patterns used**

#### Code Quality
- [ ] **Consistent logging patterns following Script_Crane style**
- [ ] **Proper chain ID registration for all components**
- [ ] **Builder key patterns followed for all scripts**

### Error Resolution Patterns

When you encounter these common errors, apply these solutions:

#### "Contract not found" in override
```
Error (4327): Function needs to specify overridden contract "Test_Crane"
```
**Solution**: Add explicit import and update override specification:
```solidity
import { Test_Crane } from "@crane/contracts/test/Test_Crane.sol";
function setUp() public override(Test_Crane, TestBase_Indexedex) {
```

#### "Variable name conflicts"
```
Error: Identifier already declared
```
**Solution**: Avoid "test" prefix and use descriptive instance names:
```solidity
StandardVaultFacet public standardVaultFacetInstance; // ✅ NOT testStandardVaultFacet
```

#### "Architecture violation in tests"
```
Test fails with deployment errors
```
**Solution**: Ensure Script inheritance and CREATE3 usage:
```solidity
contract YourTest is TestBase_IFacet, TestBase_Indexedex, Script_YourComponent {
    function setUp() public override {
        super.setUp();
        run(); // ✅ Deploy via script
    }
}
```

### Universal Application Rules

1. **🔥 FACTORY FIRST**: Every single deployment MUST use factory().create3()
2. **📜 SCRIPT PATTERN**: Every component MUST have a Script_Crane-based deployment script  
3. **🧪 TEST CONSISTENCY**: Every test MUST follow the exact inheritance and override patterns
4. **📛 NAMING DISCIPLINE**: Variable names MUST avoid reserved prefixes and be descriptive
5. **🔌 PROXY INTERACTION**: All functionality MUST be accessed through proxy addresses
6. **⚡ PERFORMANCE AWARENESS**: Unnecessary deployments MUST be avoided via commenting super.run()

These patterns are **architectural requirements**, not suggestions. Deviation from any of these patterns will result in compilation failures, test failures, or runtime issues. Consistency across the entire codebase is essential for maintainability and reliability.

## Testing Checklist

### 🚨 CRITICAL DEPLOYMENT REQUIREMENTS
- [ ] **NO `new` KEYWORDS ANYWHERE** - All deployments use factory().create3()
- [ ] **Test deployments use CREATE3** - Never `new` in test setUp() or anywhere
- [ ] **All components deployed via Script_Crane pattern** - No manual deployment

### Component Deployment Verification  
- [ ] Script deploys all facets via CREATE3 (never `new`)
- [ ] Script deploys package via CREATE3 (never `new`)
- [ ] Package is registered with vault registry deployment facet
- [ ] Pool deploys successfully via vault registry deployment facet (not package directly)
- [ ] All facets are properly installed in diamond proxy

### Functionality Testing Through Proxies
- [ ] `onSwap()` works through proxy interface
- [ ] `computeInvariant()` calculates correctly through proxy
- [ ] `computeBalance()` handles liquidity operations through proxy
- [ ] Router swaps execute with proper token movements
- [ ] Liquidity operations (add/remove) work correctly
- [ ] Fee boundaries are enforced via proxy
- [ ] Invariant ratios are respected via proxy  
- [ ] All interface support is verified on proxy
- [ ] Edge cases are covered through proxy calls

### Architecture Compliance
- [ ] **Verified NO `new` usage anywhere in codebase**
- [ ] All tests inherit from Script classes for proper deployment
- [ ] Components registered with proper chain ID mapping
- [ ] Factory deployment pattern followed throughout

This comprehensive approach ensures your Diamond Proxy Balancer V3 pool implementation properly uses our CREATE3 factory system and maintains the proxy pattern throughout testing and deployment. The key is always interacting with components through their intended proxy interfaces, never calling facets directly 🏗️⚡ 