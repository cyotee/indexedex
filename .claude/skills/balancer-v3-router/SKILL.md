---
name: Balancer V3 Router
description: This skill should be used when the user asks about "Balancer Router", "IRouter", "RouterHooks", "swapSingleTokenExactIn", "addLiquidityProportional", "removeLiquidityProportional", "Permit2 Balancer", "wethIsEth", or needs to understand how users interact with Balancer V3 via routers.
version: 0.1.0
---

# Balancer V3 Router

The Router is the user-facing entry point for all Balancer V3 operations. It handles ETH wrapping, Permit2, and the unlock callback pattern.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER                                     │
│                          │                                      │
│                          ▼                                      │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │                      ROUTER                               │   │
│ │  • ETH handling (wrap/unwrap WETH)                       │   │
│ │  • Permit2 integration                                   │   │
│ │  • Deadline checks                                       │   │
│ │  • User-friendly interfaces                              │   │
│ └────────────────────────────┬─────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │                      VAULT                                │   │
│ │  • unlock() callback                                     │   │
│ │  • Core swap/liquidity logic                             │   │
│ │  • Token accounting                                      │   │
│ └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Router Contract

```solidity
contract Router is IRouter, RouterHooks {
    constructor(
        IVault vault,
        IWETH weth,
        IPermit2 permit2,
        string memory routerVersion
    ) RouterHooks(vault, weth, permit2, routerVersion);
}
```

## Core Swap Functions

### swapSingleTokenExactIn

```solidity
function swapSingleTokenExactIn(
    address pool,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 exactAmountIn,
    uint256 minAmountOut,
    uint256 deadline,
    bool wethIsEth,
    bytes calldata userData
) external payable returns (uint256 amountOut);
```

### swapSingleTokenExactOut

```solidity
function swapSingleTokenExactOut(
    address pool,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 exactAmountOut,
    uint256 maxAmountIn,
    uint256 deadline,
    bool wethIsEth,
    bytes calldata userData
) external payable returns (uint256 amountIn);
```

### Query Functions (Read-Only)

```solidity
// Preview swap without executing
function querySwapSingleTokenExactIn(
    address pool,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 exactAmountIn,
    address sender,
    bytes memory userData
) external returns (uint256 amountCalculated);

function querySwapSingleTokenExactOut(
    address pool,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 exactAmountOut,
    address sender,
    bytes memory userData
) external returns (uint256 amountCalculated);
```

## Add Liquidity Functions

### Proportional

```solidity
function addLiquidityProportional(
    address pool,
    uint256[] memory maxAmountsIn,
    uint256 exactBptAmountOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256[] memory amountsIn);
```

### Unbalanced

```solidity
function addLiquidityUnbalanced(
    address pool,
    uint256[] memory exactAmountsIn,
    uint256 minBptAmountOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256 bptAmountOut);
```

### Single Token Exact Out

```solidity
function addLiquiditySingleTokenExactOut(
    address pool,
    IERC20 tokenIn,
    uint256 maxAmountIn,
    uint256 exactBptAmountOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256 amountIn);
```

### Donation

```solidity
function donate(
    address pool,
    uint256[] memory amountsIn,
    bool wethIsEth,
    bytes memory userData
) external payable;
```

### Custom

```solidity
function addLiquidityCustom(
    address pool,
    uint256[] memory maxAmountsIn,
    uint256 minBptAmountOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData);
```

## Remove Liquidity Functions

### Proportional

```solidity
function removeLiquidityProportional(
    address pool,
    uint256 exactBptAmountIn,
    uint256[] memory minAmountsOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256[] memory amountsOut);
```

### Single Token Exact In

```solidity
function removeLiquiditySingleTokenExactIn(
    address pool,
    uint256 exactBptAmountIn,
    IERC20 tokenOut,
    uint256 minAmountOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256 amountOut);
```

### Single Token Exact Out

```solidity
function removeLiquiditySingleTokenExactOut(
    address pool,
    uint256 maxBptAmountIn,
    IERC20 tokenOut,
    uint256 exactAmountOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256 bptAmountIn);
```

### Recovery Mode

```solidity
// Works even when pool is paused
function removeLiquidityRecovery(
    address pool,
    uint256 exactBptAmountIn,
    uint256[] memory minAmountsOut
) external payable returns (uint256[] memory amountsOut);
```

## Pool Initialization

```solidity
function initialize(
    address pool,
    IERC20[] memory tokens,
    uint256[] memory exactAmountsIn,
    uint256 minBptAmountOut,
    bool wethIsEth,
    bytes memory userData
) external payable returns (uint256 bptAmountOut);
```

## The Unlock Callback Pattern

All operations use the unlock pattern:

```solidity
// Example: swapSingleTokenExactIn internal flow
function swapSingleTokenExactIn(...) external payable saveSender(msg.sender) returns (uint256) {
    return abi.decode(
        _vault.unlock(
            abi.encodeCall(
                RouterHooks.swapSingleTokenHook,
                SwapSingleTokenHookParams({
                    sender: msg.sender,
                    kind: SwapKind.EXACT_IN,
                    pool: pool,
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountGiven: exactAmountIn,
                    limit: minAmountOut,
                    deadline: deadline,
                    wethIsEth: wethIsEth,
                    userData: userData
                })
            )
        ),
        (uint256)
    );
}
```

## RouterHooks

Implements the actual logic called by the Vault:

```solidity
abstract contract RouterHooks is RouterCommon {
    // Called by Vault during unlock
    function swapSingleTokenHook(SwapSingleTokenHookParams calldata params) external returns (uint256);
    function addLiquidityHook(AddLiquidityHookParams calldata params) external returns (...);
    function removeLiquidityHook(RemoveLiquidityHookParams calldata params) external returns (...);
    function initializeHook(InitializeHookParams calldata params) external returns (uint256);
}
```

## ETH Handling

```solidity
// When wethIsEth = true:
// - For input: Router wraps ETH to WETH
// - For output: Router unwraps WETH to ETH

// Receive ETH (used for unwrapping)
receive() external payable {
    // Only accept from WETH contract
}

// Return unused ETH
function _returnEth(address sender) internal {
    uint256 balance = address(this).balance;
    if (balance > 0) {
        payable(sender).sendValue(balance);
    }
}
```

## Permit2 Integration

```solidity
// Take tokens from user via Permit2
function _takeTokenIn(
    address sender,
    IERC20 token,
    uint256 amountIn,
    bool wethIsEth
) internal {
    if (wethIsEth && address(token) == address(_weth)) {
        _wrapEth(sender, amountIn);
    } else {
        permit2.transferFrom(sender, address(_vault), uint160(amountIn), address(token));
    }
}
```

## saveSender Modifier

```solidity
// Stores msg.sender in transient storage for hook callbacks
modifier saveSender(address sender) {
    _currentSwapTokensInSlot().tstore(0);
    _currentSwapTokensOutSlot().tstore(0);
    _currentSwapTokenInAmounts().tstore(0, 0);
    _currentSwapTokenOutAmounts().tstore(0, 0);
    _sender().tstore(sender);
    _;
}
```

## BatchRouter

For multi-hop swaps and batch operations:

```solidity
contract BatchRouter is IBatchRouter, BatchRouterHooks {
    // Multi-hop swaps
    function swapExactIn(
        SwapPathExactAmountIn[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256[] memory pathAmountsOut, ...);

    function swapExactOut(
        SwapPathExactAmountOut[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256[] memory pathAmountsIn, ...);
}
```

## CompositeLiquidityRouter

For nested pool operations (pools containing BPT):

```solidity
contract CompositeLiquidityRouter is ICompositeLiquidityRouter, CompositeLiquidityRouterHooks {
    // Add liquidity to nested pools in one transaction
    // Remove liquidity from nested pools in one transaction
}
```

## BufferRouter

For ERC4626 buffer operations:

```solidity
contract BufferRouter is IBufferRouter {
    // Initialize buffers
    // Add/remove buffer liquidity
    // Direct wrap/unwrap through buffers
}
```

## Security Considerations

1. **Deadline**: All user-facing functions have deadline checks
2. **Slippage**: Limit parameters for min/max amounts
3. **Sender Storage**: Uses transient storage to track original sender
4. **Reentrancy**: Protected via Vault's transient modifier

## Reference Files

- `pkg/vault/contracts/Router.sol` - Main Router implementation
- `pkg/vault/contracts/RouterHooks.sol` - Hook implementations
- `pkg/vault/contracts/RouterCommon.sol` - Shared utilities
- `pkg/vault/contracts/BatchRouter.sol` - Multi-hop operations
- `pkg/vault/contracts/CompositeLiquidityRouter.sol` - Nested pools
