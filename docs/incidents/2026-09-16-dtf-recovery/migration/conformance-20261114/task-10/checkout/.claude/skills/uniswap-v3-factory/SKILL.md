---
name: Uniswap V3 Factory
description: This skill should be used when the user asks about "factory", "createPool", "pool deployment", "fee tiers", "tick spacing", "pool creation", or needs to understand how pools are deployed and configured.
version: 0.1.0
---

# Uniswap V3 Factory

## Overview

The UniswapV3Factory contract is responsible for deploying new pools and managing the available fee tiers. Pools are deployed deterministically using CREATE2, enabling address computation without on-chain queries.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FACTORY ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      UniswapV3Factory                                 │   │
│  │                                                                       │   │
│  │  State:                                                               │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │ owner: address              │ Can modify fee tiers             │  │   │
│  │  │ feeAmountTickSpacing: map   │ fee → tickSpacing                │  │   │
│  │  │ getPool: map                │ token0 → token1 → fee → pool    │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                       │   │
│  │  Default Fee Tiers:                                                   │   │
│  │  ┌──────────┬─────────────┬───────────────┬─────────────────────┐    │   │
│  │  │   Fee    │ Fee (bps)   │ Tick Spacing  │ Use Case            │    │   │
│  │  ├──────────┼─────────────┼───────────────┼─────────────────────│    │   │
│  │  │   100    │   0.01%     │      1        │ Very stable pairs   │    │   │
│  │  │   500    │   0.05%     │     10        │ Stable pairs        │    │   │
│  │  │  3000    │   0.30%     │     60        │ Standard pairs      │    │   │
│  │  │ 10000    │   1.00%     │    200        │ Exotic/volatile     │    │   │
│  │  └──────────┴─────────────┴───────────────┴─────────────────────┘    │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                              │                                               │
│                              │ createPool()                                  │
│                              ▼                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     UniswapV3PoolDeployer                             │   │
│  │                                                                       │   │
│  │  Uses CREATE2 for deterministic deployment:                          │   │
│  │  salt = keccak256(token0, token1, fee)                               │   │
│  │  address = CREATE2(factory, salt, initCodeHash)                      │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                              │                                               │
│                              │ new UniswapV3Pool()                          │
│                              ▼                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                       UniswapV3Pool                                   │   │
│  │  Immutables set via constructor read from deployer:                  │   │
│  │  - factory, token0, token1, fee, tickSpacing                         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Factory Contract

```solidity
contract UniswapV3Factory is IUniswapV3Factory, UniswapV3PoolDeployer, NoDelegateCall {
    /// @inheritdoc IUniswapV3Factory
    address public override owner;

    /// @inheritdoc IUniswapV3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;

    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        // Initialize default fee tiers
        feeAmountTickSpacing[500] = 10;
        emit FeeAmountEnabled(500, 10);

        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);

        feeAmountTickSpacing[10000] = 200;
        emit FeeAmountEnabled(10000, 200);
    }
}
```

## Pool Creation

```solidity
/// @inheritdoc IUniswapV3Factory
function createPool(
    address tokenA,
    address tokenB,
    uint24 fee
) external override noDelegateCall returns (address pool) {
    require(tokenA != tokenB);
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(token0 != address(0));

    int24 tickSpacing = feeAmountTickSpacing[fee];
    require(tickSpacing != 0);
    require(getPool[token0][token1][fee] == address(0));

    // Deploy pool using CREATE2
    pool = deploy(address(this), token0, token1, fee, tickSpacing);

    // Store in mapping (both directions for easy lookup)
    getPool[token0][token1][fee] = pool;
    getPool[token1][token0][fee] = pool;

    emit PoolCreated(token0, token1, fee, tickSpacing, pool);
}
```

## Pool Deployer

```solidity
contract UniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    // Parameters passed to pool constructor
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    /// @inheritdoc IUniswapV3PoolDeployer
    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        // Store parameters for pool constructor to read
        parameters = Parameters({
            factory: factory,
            token0: token0,
            token1: token1,
            fee: fee,
            tickSpacing: tickSpacing
        });

        // CREATE2 deployment with deterministic address
        pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());

        delete parameters;
    }
}
```

## Pool Constructor

The pool reads its immutable parameters from the deployer.

```solidity
contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
    /// @inheritdoc IUniswapV3PoolImmutables
    address public immutable override factory;
    /// @inheritdoc IUniswapV3PoolImmutables
    address public immutable override token0;
    /// @inheritdoc IUniswapV3PoolImmutables
    address public immutable override token1;
    /// @inheritdoc IUniswapV3PoolImmutables
    uint24 public immutable override fee;
    /// @inheritdoc IUniswapV3PoolImmutables
    int24 public immutable override tickSpacing;
    /// @inheritdoc IUniswapV3PoolImmutables
    uint128 public immutable override maxLiquidityPerTick;

    constructor() {
        int24 _tickSpacing;
        (factory, token0, token1, fee, _tickSpacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
        tickSpacing = _tickSpacing;

        // Calculate max liquidity per tick to prevent overflow
        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }
}
```

## Pool Address Computation

Addresses can be computed off-chain without querying the blockchain.

```solidity
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey with tokens sorted
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address
    function computeAddress(address factory, PoolKey memory key)
        internal pure
        returns (address pool)
    {
        require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            factory,
                            keccak256(abi.encode(key.token0, key.token1, key.fee)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
```

## Fee Tier Management

The factory owner can enable new fee tiers.

```solidity
/// @inheritdoc IUniswapV3Factory
function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
    require(msg.sender == owner);
    require(fee < 1000000);
    require(tickSpacing > 0 && tickSpacing < 16384);
    require(feeAmountTickSpacing[fee] == 0);

    feeAmountTickSpacing[fee] = tickSpacing;
    emit FeeAmountEnabled(fee, tickSpacing);
}
```

## Ownership Transfer

```solidity
/// @inheritdoc IUniswapV3Factory
function setOwner(address _owner) external override {
    require(msg.sender == owner);
    emit OwnerChanged(owner, _owner);
    owner = _owner;
}
```

## Pool Initializer (Periphery)

Creates and initializes pools in one transaction.

```solidity
abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    /// @inheritdoc IPoolInitializer
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable override returns (address pool) {
        require(token0 < token1);
        pool = IUniswapV3Factory(factory).getPool(token0, token1, fee);

        if (pool == address(0)) {
            // Create new pool
            pool = IUniswapV3Factory(factory).createPool(token0, token1, fee);
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        } else {
            // Check if already initialized
            (uint160 sqrtPriceX96Existing, , , , , , ) = IUniswapV3Pool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                IUniswapV3Pool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
```

## Fee Tier Selection Guidelines

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FEE TIER SELECTION GUIDE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  0.01% (100 bps) - tickSpacing: 1                                           │
│  ────────────────────────────────────────────────                           │
│  • Stablecoin pairs (USDC/USDT, DAI/USDC)                                   │
│  • Very low volatility                                                       │
│  • Tight spreads required                                                    │
│  • Fine-grained price control                                               │
│                                                                              │
│  0.05% (500 bps) - tickSpacing: 10                                          │
│  ────────────────────────────────────────────────                           │
│  • Stable pairs (stETH/ETH, WBTC/renBTC)                                    │
│  • Correlated assets                                                         │
│  • Low volatility but not stable                                            │
│                                                                              │
│  0.30% (3000 bps) - tickSpacing: 60                                         │
│  ────────────────────────────────────────────────                           │
│  • Standard token pairs (ETH/USDC, ETH/DAI)                                 │
│  • Most common tier                                                          │
│  • Good balance of fees vs spreads                                          │
│                                                                              │
│  1.00% (10000 bps) - tickSpacing: 200                                       │
│  ────────────────────────────────────────────────                           │
│  • Exotic or volatile pairs                                                  │
│  • Low liquidity tokens                                                      │
│  • High impermanent loss risk                                               │
│  • Fewer initialized ticks (gas savings)                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Tick Spacing Impact

```solidity
// Tick spacing determines which ticks can be initialized
// Only ticks divisible by tickSpacing can hold liquidity boundaries

// For tickSpacing = 60 (0.3% fee):
// Valid ticks: ..., -120, -60, 0, 60, 120, ...
// Invalid ticks: -59, -1, 1, 59, 61, ...

// Price step per valid tick = 1.0001^tickSpacing
// tickSpacing = 1   → 0.01% per step
// tickSpacing = 10  → 0.10% per step
// tickSpacing = 60  → 0.60% per step
// tickSpacing = 200 → 2.02% per step
```

## Events

```solidity
/// @notice Emitted when a new pool is created
event PoolCreated(
    address indexed token0,
    address indexed token1,
    uint24 indexed fee,
    int24 tickSpacing,
    address pool
);

/// @notice Emitted when a new fee amount is enabled
event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

/// @notice Emitted when the owner changes
event OwnerChanged(address indexed oldOwner, address indexed newOwner);
```

## NoDelegateCall Protection

Prevents pools from being used as implementation contracts.

```solidity
abstract contract NoDelegateCall {
    /// @dev The original address of this contract
    address private immutable original;

    constructor() {
        original = address(this);
    }

    /// @dev Prevents delegatecall into the modified method
    modifier noDelegateCall() {
        require(address(this) == original);
        _;
    }
}
```

## Reference Files

### v3-core
- `contracts/UniswapV3Factory.sol` - Factory contract
- `contracts/UniswapV3PoolDeployer.sol` - CREATE2 deployment logic
- `contracts/NoDelegateCall.sol` - Security protection

### v3-periphery
- `contracts/base/PoolInitializer.sol` - Create + initialize helper
- `contracts/libraries/PoolAddress.sol` - Address computation
