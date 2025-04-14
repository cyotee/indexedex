# Aerodrome Service Reference

## Directory Structure

```
contracts/protocols/dexes/aerodrome/
├── v1/
│   ├── aware/
│   │   ├── AerodromePoolMetadataRepo.sol
│   │   └── AerodromeRouterAwareRepo.sol
│   ├── interfaces/
│   │   ├── IPool.sol
│   │   ├── IRouter.sol
│   │   ├── IPoolFactory.sol
│   │   └── factories/
│   ├── services/
│   │   ├── AerodromService.sol (deprecated)
│   │   ├── AerodromServiceVolatile.sol
│   │   └── AerodromServiceStable.sol
│   ├── stubs/
│   │   ├── Pool.sol
│   │   ├── Router.sol
│   │   ├── PoolFactory.sol
│   │   └── ... (full protocol implementation)
│   └── test/bases/
│       ├── TestBase_Aerodrome.sol
│       └── TestBase_Aerodrome_Pools.sol
└── slipstream/
    ├── SlipstreamRewardUtils.sol
    ├── interfaces/
    │   └── ICLPool.sol
    └── test/bases/
        └── TestBase_Slipstream.sol
```

## SwapVolatileParams Struct

```solidity
struct SwapVolatileParams {
    IRouter router;
    IPoolFactory factory;
    IPool pool;
    IERC20 tokenIn;
    IERC20 tokenOut;
    uint256 amountIn;
    address recipient;
    uint256 deadline;
}
```

## SwapDepositVolatileParams Struct

```solidity
struct SwapDepositVolatileParams {
    IRouter router;
    IPoolFactory factory;
    IPool pool;
    IERC20 token0;
    IERC20 tokenIn;
    IERC20 opposingToken;
    uint256 amountIn;
    address recipient;
    uint256 deadline;
}
```

## Complete Swap Example

```solidity
import {AerodromServiceVolatile} from "@crane/contracts/protocols/dexes/aerodrome/v1/services/AerodromServiceVolatile.sol";
import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {IPool} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IPool.sol";
import {IPoolFactory} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/factories/IPoolFactory.sol";

contract AerodromeSwapper {
    IRouter public router;
    IPoolFactory public factory;

    function swapExact(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        bool stable
    ) external returns (uint256 amountOut) {
        IPool pool = IPool(factory.getPool(
            address(tokenIn),
            address(tokenOut),
            stable
        ));

        if (stable) {
            return AerodromServiceStable._swapStable(
                AerodromServiceStable.SwapStableParams({
                    router: router,
                    factory: factory,
                    pool: pool,
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountIn,
                    recipient: msg.sender,
                    deadline: block.timestamp
                })
            );
        } else {
            return AerodromServiceVolatile._swapVolatile(
                AerodromServiceVolatile.SwapVolatileParams({
                    router: router,
                    factory: factory,
                    pool: pool,
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountIn,
                    recipient: msg.sender,
                    deadline: block.timestamp
                })
            );
        }
    }
}
```

## Swap and Deposit (Zap In)

Single-token deposit with automatic swap to balance:

```solidity
function zapIn(
    IERC20 tokenIn,
    IERC20 opposingToken,
    uint256 amountIn
) external returns (uint256 lpOut) {
    IPool pool = IPool(factory.getPool(
        address(tokenIn),
        address(opposingToken),
        false  // volatile
    ));

    return AerodromServiceVolatile._swapDepositVolatile(
        AerodromServiceVolatile.SwapDepositVolatileParams({
            router: router,
            factory: factory,
            pool: pool,
            token0: pool.token0(),
            tokenIn: tokenIn,
            opposingToken: opposingToken,
            amountIn: amountIn,
            recipient: address(this),
            deadline: block.timestamp
        })
    );
}
```

## TestBase_Aerodrome

Deploys full Aerodrome protocol stack:

```solidity
abstract contract TestBase_Aerodrome is TestBase_Weth9 {
    // Core contracts
    IPoolFactory internal poolFactory;
    IRouter internal aerodromeRouter;
    IVoter internal voter;
    IVotingEscrow internal votingEscrow;
    IMinter internal minter;
    IRewardsDistributor internal rewardsDistributor;
    IAero internal aero;

    // Factories
    IGaugeFactory internal gaugeFactory;
    IManagedRewardsFactory internal managedRewardsFactory;
    IVotingRewardsFactory internal votingRewardsFactory;
    IFactoryRegistry internal factoryRegistry;

    function setUp() public virtual override {
        super.setUp();
        // Deploys all contracts
    }
}
```

## TestBase_Aerodrome_Pools

Extends with pool creation helpers:

```solidity
abstract contract TestBase_Aerodrome_Pools is TestBase_Aerodrome {
    // Helper to create volatile pool
    function _createVolatilePool(
        IERC20 tokenA,
        IERC20 tokenB
    ) internal returns (IPool pool) {
        pool = IPool(poolFactory.createPool(
            address(tokenA),
            address(tokenB),
            false  // stable
        ));
    }

    // Helper to create stable pool
    function _createStablePool(
        IERC20 tokenA,
        IERC20 tokenB
    ) internal returns (IPool pool) {
        pool = IPool(poolFactory.createPool(
            address(tokenA),
            address(tokenB),
            true  // stable
        ));
    }
}
```

## Slipstream (Concentrated Liquidity)

For CL pools, use SlipstreamRewardUtils:

```solidity
import {SlipstreamRewardUtils} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/SlipstreamRewardUtils.sol";

// Calculate rewards for a position
uint256 rewards = SlipstreamRewardUtils._calculateRewards(clPool, tokenId);
```

## Storage Slots

| Repo | Slot |
|------|------|
| AerodromeRouterAwareRepo | `"protocols.dexes.aerodrome.v1.router.aware"` |
| AerodromePoolMetadataRepo | `"protocols.dexes.aerodrome.v1.pool.metadata"` |

## Migration from Deprecated Service

The original `AerodromService` is deprecated. Migrate as follows:

| Old | New |
|-----|-----|
| `AerodromService.SwapParams` | `AerodromServiceVolatile.SwapVolatileParams` |
| `AerodromService._swap()` | `AerodromServiceVolatile._swapVolatile()` |
| `AerodromService._swapDepositVolatile()` | `AerodromServiceVolatile._swapDepositVolatile()` |
| `AerodromService._quoteSwapDepositSaleAmt()` | `AerodromServiceVolatile._quoteSwapDepositSaleAmtVolatile()` |
