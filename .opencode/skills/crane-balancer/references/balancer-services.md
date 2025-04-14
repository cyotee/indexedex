# Balancer V3 Service Reference

## Directory Structure

```
contracts/protocols/dexes/balancer/v3/
├── pool-weighted/
│   ├── BalancerV3WeightedPoolDFPkg.sol
│   ├── BalancerV3WeightedPoolFacet.sol
│   ├── BalancerV3WeightedPoolTarget.sol
│   ├── BalancerV3WeightedPoolTargetStub.sol
│   ├── BalancerV3WeightedPoolRepo.sol
│   └── WeightedTokenConfigUtils.sol
├── pool-constProd/
│   ├── BalancerV3ConstantProductPoolDFPkg.sol
│   ├── BalancerV3ConstantProductPoolFacet.sol
│   └── BalancerV3ConstantProductPoolTarget.sol
├── pool-utils/
│   ├── BalancerV3BasePoolFactory.sol
│   ├── BalancerV3BasePoolFactoryRepo.sol
│   └── FactoryWidePauseWindowTarget.sol
├── vault/
│   ├── BalancerV3VaultAwareRepo.sol
│   ├── BalancerV3VaultAwareFacet.sol
│   ├── BalancerV3VaultAwareTarget.sol
│   ├── BalancerV3PoolRepo.sol
│   ├── BalancerV3PoolFacet.sol
│   ├── BalancerV3PoolTarget.sol
│   ├── BalancerV3AuthenticationRepo.sol
│   ├── BalancerV3AuthenticationFacet.sol
│   ├── BalancerV3AuthenticationTarget.sol
│   ├── BalancerV3AuthenticationService.sol
│   ├── BalancerV3VaultGuardModifiers.sol
│   ├── VaultGuardModifiers.sol
│   └── BetterBalancerV3PoolTokenFacet.sol
├── rateProviders/
│   ├── ERC4626RateProviderFacetDFPkg.sol
│   ├── ERC4626RateProviderFacet.sol
│   └── ERC4626RateProviderTarget.sol
├── utils/
│   ├── TokenConfigUtils.sol
│   └── BalancerV38020WeightedPoolMath.sol
└── test/bases/
    ├── TestBase_BalancerV3.sol
    ├── TestBase_BalancerV3Vault.sol
    └── TestBase_BalancerV3_8020WeightedPool.sol
```

## PkgInit Struct (Weighted Pool)

```solidity
struct PkgInit {
    IFacet balancerV3VaultAwareFacet;
    IFacet betterBalancerV3PoolTokenFacet;
    IFacet defaultPoolInfoFacet;
    IFacet standardSwapFeePercentageBoundsFacet;
    IFacet unbalancedLiquidityInvariantRatioBoundsFacet;
    IFacet balancerV3AuthenticationFacet;
    IFacet balancerV3WeightedPoolFacet;
    IVault balancerV3Vault;
    IDiamondPackageCallBackFactory diamondFactory;
    address poolFeeManager;
}
```

## PkgArgs Struct (Weighted Pool)

```solidity
struct PkgArgs {
    TokenConfig[] tokenConfigs;
    uint256[] normalizedWeights;
    address hooksContract;
}
```

## Complete Pool Deployment Example

```solidity
import {IBalancerV3WeightedPoolDFPkg, BalancerV3WeightedPoolDFPkg} from "@crane/contracts/protocols/dexes/balancer/v3/pool-weighted/BalancerV3WeightedPoolDFPkg.sol";
import {TokenConfig, TokenType} from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {ERC4626RateProviderFacetDFPkg} from "@crane/contracts/protocols/dexes/balancer/v3/rateProviders/ERC4626RateProviderFacetDFPkg.sol";

contract BalancerPoolFactory {
    BalancerV3WeightedPoolDFPkg public weightedPoolDFPkg;
    ERC4626RateProviderFacetDFPkg public rateProviderDFPkg;

    /// @notice Deploy an 80/20 weighted pool
    function deploy8020Pool(
        IERC20 majorToken,
        IERC20 minorToken
    ) external returns (address pool) {
        TokenConfig[] memory configs = new TokenConfig[](2);
        configs[0] = TokenConfig({
            token: majorToken,
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        configs[1] = TokenConfig({
            token: minorToken,
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        uint256[] memory weights = new uint256[](2);
        weights[0] = 80e16;  // 80%
        weights[1] = 20e16;  // 20%

        pool = weightedPoolDFPkg.deployPool(configs, weights, address(0));
    }

    /// @notice Deploy pool with yield-bearing tokens
    function deployYieldPool(
        IERC4626 yieldToken,
        IERC20 baseToken
    ) external returns (address pool) {
        // Deploy rate provider for yield token
        IRateProvider rateProvider = rateProviderDFPkg.deployRateProvider(yieldToken);

        TokenConfig[] memory configs = new TokenConfig[](2);
        configs[0] = TokenConfig({
            token: IERC20(address(yieldToken)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: rateProvider,
            paysYieldFees: true
        });
        configs[1] = TokenConfig({
            token: baseToken,
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        uint256[] memory weights = new uint256[](2);
        weights[0] = 50e16;
        weights[1] = 50e16;

        pool = weightedPoolDFPkg.deployPool(configs, weights, address(0));
    }
}
```

## TokenConfigUtils

Utilities for working with token configurations:

```solidity
import {TokenConfigUtils} from "@crane/contracts/protocols/dexes/balancer/v3/utils/TokenConfigUtils.sol";
import {TokenConfig} from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

using TokenConfigUtils for TokenConfig[];

// Sort configs by token address (required by Balancer)
configs._sort();

// Extract token addresses
address[] memory tokens = configs._tokens();
```

## WeightedTokenConfigUtils

Utilities that sort configs and weights together:

```solidity
import {WeightedTokenConfigUtils} from "@crane/contracts/protocols/dexes/balancer/v3/pool-weighted/WeightedTokenConfigUtils.sol";

using WeightedTokenConfigUtils for TokenConfig[];

// Sort configs AND weights together to maintain alignment
(TokenConfig[] memory sortedConfigs, uint256[] memory sortedWeights) =
    configs._sortWithWeights(weights);
```

## Pool Registration Flow

The DFPkg handles vault registration automatically in `postDeploy`:

```solidity
function postDeploy(address proxy) public returns (bool) {
    _registerPoolWithBalV3Vault(
        proxy,
        BalancerV3BasePoolFactoryRepo._getTokenConfigs(proxy),
        5e16,  // 5% initial swap fee
        false, // not paused
        _roleAccounts(),
        BalancerV3BasePoolFactoryRepo._getHooksContract(proxy),
        _liquidityManagement()
    );
    return true;
}
```

## Repo Storage Patterns

### BalancerV3VaultAwareRepo

```solidity
library BalancerV3VaultAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("protocols.dexes.balancer.v3.vault.aware");

    struct Storage {
        IVault balancerV3Vault;
    }

    function _initialize(IVault vault) internal;
    function _balancerV3Vault() internal view returns (IVault);
}
```

### BalancerV3PoolRepo

```solidity
library BalancerV3PoolRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("protocols.dexes.balancer.v3.pool");

    struct Storage {
        uint256 minInvariantRatio;
        uint256 maxInvariantRatio;
        uint256 minSwapFeePercentage;
        uint256 maxSwapFeePercentage;
        address[] tokens;
    }

    function _initialize(
        uint256 minInvariantRatio,
        uint256 maxInvariantRatio,
        uint256 minSwapFeePercentage,
        uint256 maxSwapFeePercentage,
        address[] memory tokens
    ) internal;
}
```

### BalancerV3WeightedPoolRepo

```solidity
library BalancerV3WeightedPoolRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("protocols.dexes.balancer.v3.pool.weighted");

    struct Storage {
        uint256[] normalizedWeights;
    }

    function _initialize(uint256[] memory normalizedWeights) internal;
    function _getNormalizedWeights() internal view returns (uint256[] memory);
}
```

## TestBase_BalancerV3Vault

Comprehensive test base deploying full Balancer V3 infrastructure:

```solidity
abstract contract TestBase_BalancerV3Vault is
    TestBase_BalancerV3,
    TestBase_Permit2,
    CraneTest,
    VaultContractsDeployer
{
    // Main contracts
    IVaultMock internal vault;
    IVaultExtension internal vaultExtension;
    IVaultAdmin internal vaultAdmin;
    RouterMock internal router;
    BatchRouterMock internal batchRouter;
    BufferRouterMock internal bufferRouter;
    BasicAuthorizerMock internal authorizer;
    CompositeLiquidityRouterMock internal compositeLiquidityRouter;
    IProtocolFeeController internal feeController;

    // Rate provider DFPkg
    IERC4626RateProviderFacetDFPkg erc4626RateProviderDFPkg;

    function setUp() public virtual override {
        super.setUp();
        // vault, router, batchRouter, etc. available
        // erc4626RateProviderDFPkg available
    }

    // Helper to create standard token config
    function standardTokenConfig(IERC20 token)
        public
        virtual
        returns (TokenConfig memory);

    // Helper to create ERC4626 token config with rate provider
    function erc4626TokenConfig(IERC4626 token)
        public
        virtual
        returns (TokenConfig memory);
}
```

## Pool Initialization in Tests

```solidity
function test_initializePool() public {
    TokenConfig[] memory configs = new TokenConfig[](2);
    configs[0] = standardTokenConfig(dai);
    configs[1] = standardTokenConfig(usdc);

    uint256[] memory weights = new uint256[](2);
    weights[0] = 50e16;
    weights[1] = 50e16;

    // Deploy pool
    address pool = weightedPoolDFPkg.deployPool(configs, weights, address(0));

    // Approve tokens for router
    _approveForAllUsers(IERC20(pool));

    // Initialize with liquidity
    uint256[] memory amountsIn = new uint256[](2);
    amountsIn[0] = 1000e18;
    amountsIn[1] = 1000e18;

    vm.startPrank(lp);
    router.initialize(pool, vault.getPoolTokens(pool), amountsIn, 0, false, "");
    vm.stopPrank();
}
```

## Weight Validation

The DFPkg validates weights on deployment:

```solidity
// Weights must sum to 1e18 (100%)
// Minimum 2 tokens, maximum 8 tokens
// Each weight must be > 0

error InvalidTokensLength(uint256 maxLength, uint256 minLength, uint256 providedLength);
error WeightsTokensMismatch(uint256 tokensLength, uint256 weightsLength);
```

## Pool Constants

```solidity
// Swap fee bounds
uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e12;    // 0.0001%
uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 0.1e18;  // 10%

// Invariant ratio bounds (for unbalanced liquidity)
uint256 private constant _MIN_INVARIANT_RATIO = 60e16;   // 60%
uint256 private constant _MAX_INVARIANT_RATIO = 500e16;  // 500%
```

## BalancerV3WeightedPoolFacet Interface

```solidity
interface IBalancerV3WeightedPool {
    /// @notice Get the normalized weights of all tokens
    function getNormalizedWeights() external view returns (uint256[] memory);
}

interface IBalancerV3Pool {
    /// @notice Compute the pool's invariant
    function computeInvariant(
        uint256[] memory balancesLiveScaled18,
        Rounding rounding
    ) external view returns (uint256 invariant);

    /// @notice Compute balance after swap
    function computeBalance(
        uint256[] memory balancesLiveScaled18,
        uint256 tokenInIndex,
        uint256 invariantRatio
    ) external view returns (uint256 newBalance);

    /// @notice Execute a swap
    function onSwap(PoolSwapParams calldata request)
        external
        returns (uint256 amountCalculated);
}
```
