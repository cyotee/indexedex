---
name: Slipstream Position Manager
description: This skill should be used when the user asks about "NonfungiblePositionManager", "NFT", "tokenId", "mint position", "increase liquidity", "decrease liquidity", "multicall", or needs to understand the NFT position wrapper.
version: 0.1.0
---

# Slipstream Position Manager

NonfungiblePositionManager wraps concentrated liquidity positions as ERC721 NFTs, providing a user-friendly interface for managing positions.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│              NONFUNGIBLE POSITION MANAGER                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  User ◄─────────────────► Position Manager ◄─────► CLPool   │
│    │                            │                     │      │
│    │  mint()                    │  mint()            │      │
│    │  ─────────────────►        │  ─────────────►    │      │
│    │                            │                     │      │
│    │  ◄───────────────────      │  ◄─────────────    │      │
│    │  NFT (tokenId)             │  callback          │      │
│    │                            │                     │      │
│    │  increaseLiquidity()       │  mint()            │      │
│    │  decreaseLiquidity()       │  burn()            │      │
│    │  collect()                 │  collect()         │      │
│    │                            │                     │      │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    NFT Position                         │ │
│  │  ┌─────────────────────────────────────────────────┐    │ │
│  │  │  tokenId: 1234                                  │    │ │
│  │  │  pool: 0x1234...                                │    │ │
│  │  │  tickLower: -100                                │    │ │
│  │  │  tickUpper: 100                                 │    │ │
│  │  │  liquidity: 1000000                             │    │ │
│  │  │  tokensOwed0: 50                                │    │ │
│  │  │  tokensOwed1: 25                                │    │ │
│  │  └─────────────────────────────────────────────────┘    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Position Structure

```solidity
// NonfungiblePositionManager.sol

struct Position {
    uint96 nonce;                          // Permit nonce
    address operator;                       // Approved operator
    uint80 poolId;                          // Pool lookup ID
    int24 tickLower;                        // Range lower bound
    int24 tickUpper;                        // Range upper bound
    uint128 liquidity;                      // Liquidity amount
    uint256 feeGrowthInside0LastX128;      // Token0 fee snapshot
    uint256 feeGrowthInside1LastX128;      // Token1 fee snapshot
    uint128 tokensOwed0;                    // Uncollected token0
    uint128 tokensOwed1;                    // Uncollected token1
}

// Position storage
mapping(uint256 tokenId => Position) private _positions;

// Pool ID to pool data
mapping(uint80 poolId => PoolAddress.PoolKey) private _poolIdToPoolKey;
```

## Mint (Create Position)

```solidity
struct MintParams {
    address token0;
    address token1;
    int24 tickSpacing;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
    uint160 sqrtPriceX96;  // Optional: create pool if doesn't exist
}

/// @notice Create a new position
/// @return tokenId NFT token ID
/// @return liquidity Liquidity minted
/// @return amount0 Token0 deposited
/// @return amount1 Token1 deposited
function mint(MintParams calldata params)
    external
    payable
    checkDeadline(params.deadline)
    returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
{
    // Get or create pool
    ICLPool pool = ICLPool(
        CLFactory(factory).getPool(params.token0, params.token1, params.tickSpacing)
    );

    if (address(pool) == address(0)) {
        // Create pool with initial price
        pool = ICLPool(
            CLFactory(factory).createPool(
                params.token0,
                params.token1,
                params.tickSpacing,
                params.sqrtPriceX96
            )
        );
    }

    // Add liquidity
    (liquidity, amount0, amount1) = addLiquidity(
        AddLiquidityParams({
            pool: pool,
            recipient: address(this),  // NFT manager holds position
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min
        })
    );

    // Mint NFT
    _mint(params.recipient, (tokenId = _nextId++));

    // Get fee growth snapshots
    (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
        pool.getFeeGrowthInside(params.tickLower, params.tickUpper);

    // Get or create pool ID
    uint80 poolId = cachePoolKey(
        PoolAddress.PoolKey({token0: params.token0, token1: params.token1, tickSpacing: params.tickSpacing})
    );

    // Store position
    _positions[tokenId] = Position({
        nonce: 0,
        operator: address(0),
        poolId: poolId,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        liquidity: liquidity,
        feeGrowthInside0LastX128: feeGrowthInside0X128,
        feeGrowthInside1LastX128: feeGrowthInside1X128,
        tokensOwed0: 0,
        tokensOwed1: 0
    });

    emit IncreaseLiquidity(tokenId, liquidity, amount0, amount1);
}
```

## Increase Liquidity

```solidity
struct IncreaseLiquidityParams {
    uint256 tokenId;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}

/// @notice Add liquidity to existing position
function increaseLiquidity(IncreaseLiquidityParams calldata params)
    external
    payable
    checkDeadline(params.deadline)
    returns (uint128 liquidity, uint256 amount0, uint256 amount1)
{
    Position storage position = _positions[params.tokenId];

    PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
    ICLPool pool = ICLPool(
        PoolAddress.computeAddress(factory, poolKey)
    );

    // Add liquidity
    (liquidity, amount0, amount1) = addLiquidity(
        AddLiquidityParams({
            pool: pool,
            recipient: address(this),
            tickLower: position.tickLower,
            tickUpper: position.tickUpper,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min
        })
    );

    // Update fee snapshots and calculate owed
    (
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) = pool.getFeeGrowthInside(position.tickLower, position.tickUpper);

    position.tokensOwed0 += uint128(
        FullMath.mulDiv(
            feeGrowthInside0X128 - position.feeGrowthInside0LastX128,
            position.liquidity,
            FixedPoint128.Q128
        )
    );
    position.tokensOwed1 += uint128(
        FullMath.mulDiv(
            feeGrowthInside1X128 - position.feeGrowthInside1LastX128,
            position.liquidity,
            FixedPoint128.Q128
        )
    );

    position.feeGrowthInside0LastX128 = feeGrowthInside0X128;
    position.feeGrowthInside1LastX128 = feeGrowthInside1X128;
    position.liquidity += liquidity;

    emit IncreaseLiquidity(params.tokenId, liquidity, amount0, amount1);
}
```

## Decrease Liquidity

```solidity
struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}

/// @notice Remove liquidity from position
function decreaseLiquidity(DecreaseLiquidityParams calldata params)
    external
    payable
    isAuthorizedForToken(params.tokenId)
    checkDeadline(params.deadline)
    returns (uint256 amount0, uint256 amount1)
{
    require(params.liquidity > 0, "NL");

    Position storage position = _positions[params.tokenId];
    require(position.liquidity >= params.liquidity, "NP");

    PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
    ICLPool pool = ICLPool(PoolAddress.computeAddress(factory, poolKey));

    // Burn liquidity from pool
    (amount0, amount1) = pool.burn(
        position.tickLower,
        position.tickUpper,
        params.liquidity
    );

    require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "PS");

    // Update fee snapshots
    (
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) = pool.getFeeGrowthInside(position.tickLower, position.tickUpper);

    position.tokensOwed0 += uint128(
        amount0 +
        FullMath.mulDiv(
            feeGrowthInside0X128 - position.feeGrowthInside0LastX128,
            position.liquidity,
            FixedPoint128.Q128
        )
    );
    position.tokensOwed1 += uint128(
        amount1 +
        FullMath.mulDiv(
            feeGrowthInside1X128 - position.feeGrowthInside1LastX128,
            position.liquidity,
            FixedPoint128.Q128
        )
    );

    position.feeGrowthInside0LastX128 = feeGrowthInside0X128;
    position.feeGrowthInside1LastX128 = feeGrowthInside1X128;
    position.liquidity -= params.liquidity;

    emit DecreaseLiquidity(params.tokenId, params.liquidity, amount0, amount1);
}
```

## Collect

```solidity
struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
}

/// @notice Collect tokens owed from position
function collect(CollectParams calldata params)
    external
    payable
    isAuthorizedForToken(params.tokenId)
    returns (uint256 amount0, uint256 amount1)
{
    require(params.recipient != address(0), "RA");

    Position storage position = _positions[params.tokenId];

    PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
    ICLPool pool = ICLPool(PoolAddress.computeAddress(factory, poolKey));

    // Trigger position update to calculate latest fees
    pool.burn(position.tickLower, position.tickUpper, 0);

    // Update fee snapshots
    (
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) = pool.getFeeGrowthInside(position.tickLower, position.tickUpper);

    uint128 tokensOwed0 = position.tokensOwed0 + uint128(
        FullMath.mulDiv(
            feeGrowthInside0X128 - position.feeGrowthInside0LastX128,
            position.liquidity,
            FixedPoint128.Q128
        )
    );
    uint128 tokensOwed1 = position.tokensOwed1 + uint128(
        FullMath.mulDiv(
            feeGrowthInside1X128 - position.feeGrowthInside1LastX128,
            position.liquidity,
            FixedPoint128.Q128
        )
    );

    position.feeGrowthInside0LastX128 = feeGrowthInside0X128;
    position.feeGrowthInside1LastX128 = feeGrowthInside1X128;

    // Cap at owed
    (amount0, amount1) = (
        params.amount0Max > tokensOwed0 ? tokensOwed0 : params.amount0Max,
        params.amount1Max > tokensOwed1 ? tokensOwed1 : params.amount1Max
    );

    // Collect from pool
    (uint128 amount0Collect, uint128 amount1Collect) = pool.collect(
        params.recipient,
        position.tickLower,
        position.tickUpper,
        uint128(amount0),
        uint128(amount1)
    );

    // Update owed
    position.tokensOwed0 = tokensOwed0 - uint128(amount0);
    position.tokensOwed1 = tokensOwed1 - uint128(amount1);

    emit Collect(params.tokenId, params.recipient, amount0Collect, amount1Collect);
}
```

## Burn (Remove NFT)

```solidity
/// @notice Burn a position NFT
/// @dev Position must have 0 liquidity and 0 tokensOwed
function burn(uint256 tokenId) external payable isAuthorizedForToken(tokenId) {
    Position storage position = _positions[tokenId];
    require(position.liquidity == 0 && position.tokensOwed0 == 0 && position.tokensOwed1 == 0, "NC");

    delete _positions[tokenId];
    _burn(tokenId);
}
```

## Multicall

```solidity
/// @notice Execute multiple calls in a single transaction
function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
    results = new bytes[](data.length);
    for (uint256 i = 0; i < data.length; i++) {
        (bool success, bytes memory result) = address(this).delegatecall(data[i]);

        if (!success) {
            if (result.length < 68) revert();
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }

        results[i] = result;
    }
}

// Example: Mint and stake in one transaction
bytes[] memory calls = new bytes[](2);
calls[0] = abi.encodeCall(nft.mint, (mintParams));
calls[1] = abi.encodeCall(gauge.deposit, (expectedTokenId));
nft.multicall(calls);
```

## Position Query

```solidity
/// @notice Get position details
function positions(uint256 tokenId)
    external
    view
    returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        int24 tickSpacing,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    )
{
    Position memory position = _positions[tokenId];
    require(position.poolId != 0, "NP");

    PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];

    return (
        position.nonce,
        position.operator,
        poolKey.token0,
        poolKey.token1,
        poolKey.tickSpacing,
        position.tickLower,
        position.tickUpper,
        position.liquidity,
        position.feeGrowthInside0LastX128,
        position.feeGrowthInside1LastX128,
        position.tokensOwed0,
        position.tokensOwed1
    );
}
```

## Events

```solidity
event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, uint256 amount1);
```

## Reference Files

- `contracts/periphery/NonfungiblePositionManager.sol` - Main contract
- `contracts/periphery/base/LiquidityManagement.sol` - Add liquidity logic
- `contracts/periphery/base/PoolInitializer.sol` - Pool creation
- `contracts/periphery/base/Multicall.sol` - Batch operations
