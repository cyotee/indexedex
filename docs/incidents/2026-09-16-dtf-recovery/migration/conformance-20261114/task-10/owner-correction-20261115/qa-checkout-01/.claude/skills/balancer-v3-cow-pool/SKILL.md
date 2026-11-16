---
name: Balancer V3 CoW Pool
description: This skill should be used when the user asks about "CoW pool", "CoW AMM", "MEV protection", "CowPoolFactory", "CowRouter", "trusted router", "batch auction", or needs to understand Balancer V3 CoW Pool implementation for MEV-protected trading.
version: 0.1.0
---

# Balancer V3 CoW Pool

CoW Pools integrate with CoW Protocol to provide MEV-protected trading through batch auctions. They extend Weighted Pools with hooks that restrict trading to a trusted CoW Router.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      COW POOL                                │
├──────────────────────────────────────────────────────────────┤
│ • Extends WeightedPool with hooks                            │
│ • Only accepts swaps from trusted CoW Router                 │
│ • Donations only from trusted router (MEV rebates)           │
│ • Disables unbalanced liquidity for security                 │
│ • Benefits from CoW Protocol batch auction pricing           │
└──────────────────────────────────────────────────────────────┘
```

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        COW PROTOCOL FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Users     │ => │ CoW Protocol│ => │  CoW Router │         │
│  │  (intents)  │    │  (solvers)  │    │  (Balancer) │         │
│  └─────────────┘    └─────────────┘    └──────┬──────┘         │
│                                               │                 │
│                                               ▼                 │
│                                        ┌─────────────┐         │
│                                        │  CoW Pool   │         │
│                                        │  (Vault)    │         │
│                                        └─────────────┘         │
│                                                                 │
│  Benefits:                                                      │
│  • MEV protection via batch auctions                           │
│  • Coincidence of Wants (CoW) matching                         │
│  • MEV rebates via donations                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## CowPool Contract

```solidity
contract CowPool is ICowPool, BaseHooks, WeightedPool {
    address internal _trustedCowRouter;
    CowPoolFactory internal _cowPoolFactory;

    constructor(
        WeightedPool.NewPoolParams memory params,
        IVault vault,
        address trustedCowRouter
    ) WeightedPool(params, vault) {
        _cowPoolFactory = CowPoolFactory(msg.sender);
        _setTrustedCowRouter(trustedCowRouter);
    }
}
```

## Hook Implementation

CoW Pool implements `IHooks` to restrict access:

### onRegister

```solidity
function onRegister(
    address factory,
    address pool,
    TokenConfig[] memory,
    LiquidityManagement calldata liquidityManagement
) public view override returns (bool) {
    return
        pool == address(this) &&
        factory == address(_cowPoolFactory) &&
        liquidityManagement.enableDonation == true &&
        liquidityManagement.disableUnbalancedLiquidity == true;
}
```

**Key Requirements:**
- Pool must be registered by its own factory
- Donation must be enabled (for MEV rebates)
- Unbalanced liquidity must be disabled (for security)

### getHookFlags

```solidity
function getHookFlags() public pure override returns (HookFlags memory hookFlags) {
    hookFlags.shouldCallBeforeSwap = true;
    hookFlags.shouldCallBeforeAddLiquidity = true;
}
```

### onBeforeSwap

```solidity
function onBeforeSwap(
    PoolSwapParams calldata params,
    address
) public view override returns (bool) {
    // Only allow swaps from the trusted CoW router
    return params.router == _trustedCowRouter;
}
```

### onBeforeAddLiquidity

```solidity
function onBeforeAddLiquidity(
    address router,
    address,
    AddLiquidityKind kind,
    uint256[] memory,
    uint256,
    uint256[] memory,
    bytes memory
) public view override returns (bool success) {
    // Donations only from trusted router (MEV rebates)
    // Other liquidity operations allowed from any router
    return kind != AddLiquidityKind.DONATION || router == _trustedCowRouter;
}
```

## Trusted Router Management

```solidity
// Get current trusted router
function getTrustedCowRouter() external view returns (address);

// Refresh from factory (if factory updates the router)
function refreshTrustedCowRouter() external;

// Event emitted when router changes
event CowTrustedRouterChanged(address indexed newRouter);
```

## CowPoolFactory

```solidity
contract CowPoolFactory is BasePoolFactory {
    address private _trustedCowRouter;

    function create(
        string memory name,
        string memory symbol,
        TokenConfig[] memory tokens,
        uint256[] memory normalizedWeights,
        PoolRoleAccounts memory roleAccounts,
        uint256 swapFeePercentage,
        bytes32 salt
    ) external returns (address pool);

    // Admin can update trusted router
    function setTrustedCowRouter(address newRouter) external;
    function getTrustedCowRouter() external view returns (address);
}
```

### Factory Configuration

The factory enforces CoW Pool requirements:

```solidity
LiquidityManagement memory liquidityManagement = LiquidityManagement({
    disableUnbalancedLiquidity: true,   // Security: prevent manipulation
    enableAddLiquidityCustom: false,
    enableRemoveLiquidityCustom: false,
    enableDonation: true                 // Allow MEV rebates
});
```

## CowRouter

Specialized router for interacting with CoW Pools:

```solidity
contract CowRouter is ICowRouter, RouterHooks {
    constructor(
        IVault vault,
        IWETH weth,
        IPermit2 permit2,
        string memory routerVersion
    ) RouterHooks(vault, weth, permit2, routerVersion);

    // Swap through CoW Pool
    function swapExactIn(
        SwapExactInParams memory params
    ) external returns (uint256 amountOut);

    // Donate to CoW Pool (MEV rebates)
    function donate(
        address pool,
        uint256[] memory amountsIn
    ) external;
}
```

## Querying Pool Data

```solidity
// Get dynamic data
function getCowPoolDynamicData() external view returns (CoWPoolDynamicData memory);

struct CoWPoolDynamicData {
    uint256[] balancesLiveScaled18;
    uint256[] tokenRates;
    uint256 staticSwapFeePercentage;
    uint256 totalSupply;
    address trustedCowRouter;
    bool isPoolInitialized;
    bool isPoolPaused;
    bool isPoolInRecoveryMode;
}

// Get immutable data
function getCowPoolImmutableData() external view returns (CoWPoolImmutableData memory);

struct CoWPoolImmutableData {
    IERC20[] tokens;
    uint256[] decimalScalingFactors;
    uint256[] normalizedWeights;
}
```

## Factory Usage Example

```solidity
// Create a 50/50 CoW Pool for WETH/USDC
TokenConfig[] memory tokens = new TokenConfig[](2);
tokens[0] = TokenConfig({
    token: IERC20(WETH),
    tokenType: TokenType.STANDARD,
    rateProvider: IRateProvider(address(0)),
    paysYieldFees: false
});
tokens[1] = TokenConfig({
    token: IERC20(USDC),
    tokenType: TokenType.STANDARD,
    rateProvider: IRateProvider(address(0)),
    paysYieldFees: false
});

uint256[] memory weights = new uint256[](2);
weights[0] = 50e16;  // 50%
weights[1] = 50e16;  // 50%

address pool = cowPoolFactory.create(
    "CoW WETH-USDC",
    "COW-WETH-USDC",
    tokens,
    weights,
    PoolRoleAccounts(address(0), address(0), address(0)),
    0.003e16,  // 0.3% swap fee
    keccak256("my-cow-pool-salt")
);
```

## MEV Protection Benefits

| Feature | Benefit |
|---------|---------|
| Batch Auctions | Uniform clearing prices, no front-running |
| CoW Matching | Direct peer-to-peer trades when possible |
| Solver Competition | Best execution from competing solvers |
| MEV Rebates | Captured MEV returned to LPs via donations |
| Trusted Router | Only authorized router can execute swaps |

## Security Considerations

1. **Trusted Router**: Only the CoW Router can execute swaps
2. **Disabled Unbalanced**: Prevents manipulation via add/remove
3. **Donation Control**: MEV rebates only from trusted source
4. **Factory Validation**: Pool validates its factory on registration

## Comparison to Standard Weighted Pool

| Aspect | Weighted Pool | CoW Pool |
|--------|---------------|----------|
| Swap Access | Any router | Trusted CoW Router only |
| MEV Exposure | Vulnerable | Protected via batching |
| Donations | Optional | Required (for rebates) |
| Unbalanced Liquidity | Allowed | Disabled |
| Price Source | Direct AMM | Batch auction |

## Reference Files

- `pkg/pool-cow/contracts/CowPool.sol` - Pool implementation
- `pkg/pool-cow/contracts/CowPoolFactory.sol` - Factory
- `pkg/pool-cow/contracts/CowRouter.sol` - Specialized router
- `pkg/interfaces/contracts/pool-cow/ICowPool.sol` - Interface
- [CoW Protocol Docs](https://docs.cow.fi/)
