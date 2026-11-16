---
name: Uniswap V4 Liquidity
description: This skill should be used when the user asks about "liquidity", "modifyLiquidity", "positions", "ERC6909", "add liquidity", "remove liquidity", "LP tokens", or needs to understand position management.
version: 0.1.0
---

# Uniswap V4 Liquidity

## Overview

V4 positions work similarly to V3—liquidity is concentrated within tick ranges. Key differences: positions are identified with a salt parameter (allowing multiple positions at same range), and LP claims use ERC6909 instead of NFTs.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        LIQUIDITY MANAGEMENT                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Position Identification:                                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  positionKey = keccak256(owner, tickLower, tickUpper, salt)          │   │
│  │                                                                       │   │
│  │  V3: owner + tickLower + tickUpper                                   │   │
│  │  V4: owner + tickLower + tickUpper + salt (allows multiple!)         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  LP Token Options:                                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Option 1: Direct position (no token, just state in PoolManager)     │   │
│  │  Option 2: ERC6909 claims (mint/burn LP tokens)                      │   │
│  │  Option 3: Custom wrapper (e.g., ERC721 for NFT-like positions)      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## ModifyLiquidityParams

```solidity
struct ModifyLiquidityParams {
    /// @notice Lower tick bound of position
    int24 tickLower;

    /// @notice Upper tick bound of position
    int24 tickUpper;

    /// @notice Liquidity delta
    /// Positive = add liquidity
    /// Negative = remove liquidity
    /// Zero = collect fees only
    int256 liquidityDelta;

    /// @notice Salt for position uniqueness
    /// Allows same owner to have multiple positions at same tick range
    bytes32 salt;
}
```

## PoolManager.modifyLiquidity()

```solidity
function modifyLiquidity(
    PoolKey memory key,
    ModifyLiquidityParams memory params,
    bytes calldata hookData
) external onlyWhenUnlocked noDelegateCall returns (BalanceDelta callerDelta, BalanceDelta feesAccrued) {
    PoolId id = key.toId();
    Pool.State storage pool = _pools[id];
    pool.checkPoolInitialized();

    bool isAddingLiquidity = params.liquidityDelta > 0;

    // === BEFORE HOOK ===
    if (isAddingLiquidity) {
        if (key.hooks.hasPermission(Hooks.BEFORE_ADD_LIQUIDITY_FLAG)) {
            bytes4 selector = key.hooks.beforeAddLiquidity(msg.sender, key, params, hookData);
            if (selector != IHooks.beforeAddLiquidity.selector) {
                Hooks.InvalidHookResponse.selector.revertWith();
            }
        }
    } else {
        if (key.hooks.hasPermission(Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG)) {
            bytes4 selector = key.hooks.beforeRemoveLiquidity(msg.sender, key, params, hookData);
            if (selector != IHooks.beforeRemoveLiquidity.selector) {
                Hooks.InvalidHookResponse.selector.revertWith();
            }
        }
    }

    // === CORE LOGIC ===
    BalanceDelta principalDelta;
    BalanceDelta feeDelta;
    (principalDelta, feeDelta) = pool.modifyLiquidity(
        Pool.ModifyLiquidityParams({
            owner: msg.sender,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidityDelta: params.liquidityDelta,
            tickSpacing: key.tickSpacing,
            salt: params.salt
        })
    );

    callerDelta = principalDelta + feeDelta;
    feesAccrued = feeDelta;

    // Account caller's delta
    _accountPoolBalanceDelta(key, callerDelta, msg.sender);

    // === AFTER HOOK ===
    BalanceDelta hookDelta;
    if (isAddingLiquidity) {
        if (key.hooks.hasPermission(Hooks.AFTER_ADD_LIQUIDITY_FLAG)) {
            (bytes4 selector, BalanceDelta returnDelta) = key.hooks.afterAddLiquidity(
                msg.sender, key, params, callerDelta, feesAccrued, hookData
            );
            if (selector != IHooks.afterAddLiquidity.selector) {
                Hooks.InvalidHookResponse.selector.revertWith();
            }

            if (key.hooks.hasPermission(Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG)) {
                hookDelta = returnDelta;
            }
        }
    } else {
        if (key.hooks.hasPermission(Hooks.AFTER_REMOVE_LIQUIDITY_FLAG)) {
            (bytes4 selector, BalanceDelta returnDelta) = key.hooks.afterRemoveLiquidity(
                msg.sender, key, params, callerDelta, feesAccrued, hookData
            );
            if (selector != IHooks.afterRemoveLiquidity.selector) {
                Hooks.InvalidHookResponse.selector.revertWith();
            }

            if (key.hooks.hasPermission(Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)) {
                hookDelta = returnDelta;
            }
        }
    }

    // Apply hook delta
    if (hookDelta != BalanceDeltaLibrary.ZERO_DELTA) {
        callerDelta = callerDelta + hookDelta;
        _accountPoolBalanceDelta(key, hookDelta, address(key.hooks));
    }

    emit ModifyLiquidity(id, msg.sender, params.tickLower, params.tickUpper, params.liquidityDelta, params.salt);
}
```

## Position State

```solidity
library Position {
    struct State {
        /// @notice Amount of liquidity in the position
        uint128 liquidity;

        /// @notice Fee growth inside the position's tick range as of last update
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    /// @notice Update position and calculate fees owed
    function update(
        State storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal returns (uint256 feesOwed0, uint256 feesOwed1) {
        uint128 liquidity = self.liquidity;

        // Calculate fees accrued since last update
        if (liquidity > 0) {
            feesOwed0 = FullMath.mulDiv(
                feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
                liquidity,
                FixedPoint128.Q128
            );
            feesOwed1 = FullMath.mulDiv(
                feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
                liquidity,
                FixedPoint128.Q128
            );
        }

        // Update position
        if (liquidityDelta != 0) {
            self.liquidity = liquidity.addDelta(liquidityDelta);
        }

        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
    }
}
```

## ERC6909 LP Tokens

V4 uses ERC6909 for multi-token LP representation:

```solidity
/// @notice ERC6909 Claims - multi-token standard for LP positions
abstract contract ERC6909Claims is IERC6909Claims {
    mapping(address owner => mapping(uint256 id => uint256 balance)) public balanceOf;
    mapping(address owner => mapping(address operator => bool)) public isOperator;
    mapping(address owner => mapping(uint256 id => mapping(address spender => uint256))) public allowance;

    function transfer(address to, uint256 id, uint256 amount) external returns (bool) {
        balanceOf[msg.sender][id] -= amount;
        balanceOf[to][id] += amount;
        emit Transfer(msg.sender, msg.sender, to, id, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 id, uint256 amount) external returns (bool) {
        if (msg.sender != from && !isOperator[from][msg.sender]) {
            uint256 allowed = allowance[from][id][msg.sender];
            if (allowed != type(uint256).max) {
                allowance[from][id][msg.sender] = allowed - amount;
            }
        }
        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;
        emit Transfer(msg.sender, from, to, id, amount);
        return true;
    }

    function approve(address spender, uint256 id, uint256 amount) external returns (bool) {
        allowance[msg.sender][id][spender] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    function _mint(address to, uint256 id, uint256 amount) internal {
        balanceOf[to][id] += amount;
        emit Transfer(msg.sender, address(0), to, id, amount);
    }

    function _burn(address from, uint256 id, uint256 amount) internal {
        balanceOf[from][id] -= amount;
        emit Transfer(msg.sender, from, address(0), id, amount);
    }
}
```

### Minting/Burning LP Claims

```solidity
// In PoolManager

/// @notice Mint LP claim tokens
function mint(address to, uint256 id, uint256 amount) external onlyWhenUnlocked {
    // Caller must have positive delta (owed tokens)
    // Minting converts their claim to ERC6909 balance
    _accountDelta(CurrencyLibrary.fromId(id), amount.toInt128(), msg.sender);
    _mint(to, id, amount);
}

/// @notice Burn LP claim tokens
function burn(address from, uint256 id, uint256 amount) external onlyWhenUnlocked {
    // Burning converts ERC6909 balance back to claim
    _accountDelta(CurrencyLibrary.fromId(id), -(amount.toInt128()), msg.sender);
    _burn(from, id, amount);
}
```

## Adding Liquidity (Example)

```solidity
contract LiquidityRouter is IUnlockCallback {
    IPoolManager public immutable poolManager;

    function addLiquidity(
        PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        bytes memory data = abi.encode(
            key, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min
        );
        bytes memory result = poolManager.unlock(data);
        return abi.decode(result, (uint128, uint256, uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager));

        (
            PoolKey memory key,
            int24 tickLower,
            int24 tickUpper,
            uint256 amount0Desired,
            uint256 amount1Desired,
            uint256 amount0Min,
            uint256 amount1Min
        ) = abi.decode(data, (PoolKey, int24, int24, uint256, uint256, uint256, uint256));

        // Calculate optimal liquidity
        uint128 liquidity = _calculateLiquidity(
            key, tickLower, tickUpper, amount0Desired, amount1Desired
        );

        // Add liquidity
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(liquidity)),
                salt: bytes32(0)
            }),
            ""
        );

        // Verify slippage
        uint256 amount0 = uint256(-delta.amount0());
        uint256 amount1 = uint256(-delta.amount1());
        require(amount0 >= amount0Min && amount1 >= amount1Min, "Slippage");

        // Settle tokens
        _payTokens(key.currency0, amount0);
        _payTokens(key.currency1, amount1);

        return abi.encode(liquidity, amount0, amount1);
    }

    function _payTokens(Currency currency, uint256 amount) internal {
        IERC20(Currency.unwrap(currency)).transferFrom(
            tx.origin,
            address(poolManager),
            amount
        );
        poolManager.sync(currency);
        poolManager.settle();
    }
}
```

## Removing Liquidity (Example)

```solidity
function removeLiquidity(
    PoolKey calldata key,
    int24 tickLower,
    int24 tickUpper,
    uint128 liquidity,
    uint256 amount0Min,
    uint256 amount1Min,
    bytes32 salt
) external returns (uint256 amount0, uint256 amount1) {
    // Remove liquidity (negative delta)
    (BalanceDelta delta, BalanceDelta feesAccrued) = poolManager.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: -int256(uint256(liquidity)),
            salt: salt
        }),
        ""
    );

    // delta.amount0/1 are positive (we're owed tokens)
    amount0 = uint256(delta.amount0());
    amount1 = uint256(delta.amount1());

    require(amount0 >= amount0Min && amount1 >= amount1Min, "Slippage");

    // Take tokens
    poolManager.take(key.currency0, msg.sender, amount0);
    poolManager.take(key.currency1, msg.sender, amount1);
}
```

## Collecting Fees Only

```solidity
function collectFees(
    PoolKey calldata key,
    int24 tickLower,
    int24 tickUpper,
    bytes32 salt
) external returns (uint256 fees0, uint256 fees1) {
    // Zero liquidity delta = collect fees only
    (BalanceDelta delta, BalanceDelta feesAccrued) = poolManager.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: 0,
            salt: salt
        }),
        ""
    );

    fees0 = uint256(feesAccrued.amount0());
    fees1 = uint256(feesAccrued.amount1());

    // Take fee tokens
    if (fees0 > 0) poolManager.take(key.currency0, msg.sender, fees0);
    if (fees1 > 0) poolManager.take(key.currency1, msg.sender, fees1);
}
```

## Reference Files

### v4-core
- `src/PoolManager.sol` - modifyLiquidity(), mint(), burn()
- `src/libraries/Pool.sol` - Core liquidity logic
- `src/libraries/Position.sol` - Position state
- `src/ERC6909Claims.sol` - LP token implementation

### v4-periphery
- `src/PositionManager.sol` - Position management router
