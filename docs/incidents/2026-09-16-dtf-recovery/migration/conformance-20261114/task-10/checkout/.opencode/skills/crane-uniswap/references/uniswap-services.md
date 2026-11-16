# Uniswap Service Reference

## Directory Structure

```
contracts/protocols/dexes/uniswap/
├── v2/
│   ├── services/
│   │   └── UniswapV2Service.sol
│   ├── aware/
│   │   ├── UniswapV2RouterAwareRepo.sol
│   │   └── UniswapV2FactoryAwareRepo.sol
│   ├── stubs/
│   │   ├── UniV2Factory.sol
│   │   ├── UniV2Pair.sol
│   │   ├── UniV2Router02.sol
│   │   └── deps/libs/
│   │       ├── Math.sol
│   │       ├── SafeMath.sol
│   │       ├── TransferHelper.sol
│   │       ├── UQ112x112.sol
│   │       ├── UniswapV2Library.sol
│   │       └── ...
│   └── test/bases/
│       ├── TestBase_UniswapV2.sol
│       └── TestBase_UniswapV2_Pools.sol
├── v3/
│   ├── UniswapV3Factory.sol
│   ├── UniswapV3Pool.sol
│   ├── UniswapV3PoolDeployer.sol
│   ├── NoDelegateCall.sol
│   ├── interfaces/
│   │   ├── IUniswapV3Factory.sol
│   │   ├── IUniswapV3Pool.sol
│   │   ├── IUniswapV3PoolDeployer.sol
│   │   ├── IERC20Minimal.sol
│   │   ├── callback/
│   │   │   ├── IUniswapV3SwapCallback.sol
│   │   │   ├── IUniswapV3MintCallback.sol
│   │   │   └── IUniswapV3FlashCallback.sol
│   │   └── pool/
│   │       ├── IUniswapV3PoolActions.sol
│   │       ├── IUniswapV3PoolEvents.sol
│   │       ├── IUniswapV3PoolState.sol
│   │       ├── IUniswapV3PoolOwnerActions.sol
│   │       ├── IUniswapV3PoolDerivedState.sol
│   │       └── IUniswapV3PoolImmutables.sol
│   ├── libraries/
│   │   ├── TickMath.sol
│   │   ├── SqrtPriceMath.sol
│   │   ├── SwapMath.sol
│   │   ├── FullMath.sol
│   │   ├── TickBitmap.sol
│   │   ├── LiquidityMath.sol
│   │   ├── Tick.sol
│   │   ├── Position.sol
│   │   ├── Oracle.sol
│   │   ├── BitMath.sol
│   │   ├── FixedPoint96.sol
│   │   ├── FixedPoint128.sol
│   │   ├── SafeCast.sol
│   │   ├── UnsafeMath.sol
│   │   ├── TransferHelper.sol
│   │   └── LowGasSafeMath.sol
│   └── test/bases/
│       └── TestBase_UniswapV3.sol
└── v4/
    ├── interfaces/
    │   ├── IHooks.sol
    │   └── IPoolManager.sol
    ├── libraries/
    │   ├── BitMath.sol
    │   ├── FixedPoint96.sol
    │   ├── FullMath.sol
    │   ├── LiquidityMath.sol
    │   ├── SafeCast.sol
    │   ├── SqrtPriceMath.sol
    │   ├── SwapMath.sol
    │   ├── TickMath.sol
    │   └── UnsafeMath.sol
    ├── types/
    │   ├── Currency.sol
    │   ├── PoolId.sol
    │   ├── PoolKey.sol
    │   └── Slot0.sol
    └── utils/
        ├── UniswapV4Utils.sol
        ├── UniswapV4Quoter.sol
        └── UniswapV4ZapQuoter.sol
```

## UniswapV2Service Structs

### ReserveInfo

```solidity
struct ReserveInfo {
    uint256 knownReserve;
    uint256 opposingReserve;
    uint256 feePercent;     // Always 300 (0.3%)
    uint256 unknownFee;     // Always 300 (0.3%)
}
```

### SwapParams

```solidity
struct SwapParams {
    IUniswapV2Router router;
    uint256 amountIn;
    IERC20 tokenIn;
    uint256 reserveIn;
    uint256 feePercent;
    IERC20 tokenOut;
    uint256 reserveOut;
}
```

### BalanceParams

```solidity
struct BalanceParams {
    IUniswapV2Router router;
    uint256 saleAmt;
    IERC20 tokenIn;
    uint256 saleReserve;
    uint256 saleTokenFeePerc;
    IERC20 tokenOut;
    uint256 reserveOut;
}
```

### WithdrawSwapParams

```solidity
struct WithdrawSwapParams {
    IUniswapV2Pair pool;
    IUniswapV2Router router;
    uint256 amt;
    IERC20 tokenOut;
    IERC20 opToken;
}
```

## Complete V2 Swap Example

```solidity
import {UniswapV2Service} from "@crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {UniswapV2RouterAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2RouterAwareRepo.sol";

contract UniswapVault {
    using UniswapV2Service for IUniswapV2Router;

    IUniswapV2Router public router;
    IUniswapV2Factory public factory;

    function swapExact(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        // Get pool
        IUniswapV2Pair pool = IUniswapV2Pair(
            factory.getPair(address(tokenIn), address(tokenOut))
        );

        // Transfer tokens in
        tokenIn.transferFrom(msg.sender, address(this), amountIn);

        // Execute swap
        amountOut = UniswapV2Service._swap(
            router,
            pool,
            amountIn,
            tokenIn,
            tokenOut
        );

        // Transfer result to user
        tokenOut.transfer(msg.sender, amountOut);
    }
}
```

## Zap In (Swap and Deposit)

Single-token deposit with automatic swap to balance:

```solidity
function zapIn(
    IERC20 tokenIn,
    IERC20 opposingToken,
    uint256 amountIn
) external returns (uint256 lpOut) {
    IUniswapV2Pair pool = IUniswapV2Pair(
        factory.getPair(address(tokenIn), address(opposingToken))
    );

    tokenIn.transferFrom(msg.sender, address(this), amountIn);

    lpOut = UniswapV2Service._swapDeposit(
        router,
        pool,
        tokenIn,
        amountIn,
        opposingToken
    );

    // Transfer LP tokens to user
    IERC20(address(pool)).transfer(msg.sender, lpOut);
}
```

## Zap Out (Withdraw and Swap)

Withdraw LP tokens to single token:

```solidity
function zapOut(
    IUniswapV2Pair pool,
    IERC20 tokenOut,
    uint256 lpAmount
) external returns (uint256 amountOut) {
    // Get opposing token
    address token0 = pool.token0();
    IERC20 opToken = address(tokenOut) == token0
        ? IERC20(pool.token1())
        : IERC20(token0);

    // Transfer LP from user
    IERC20(address(pool)).transferFrom(msg.sender, address(this), lpAmount);

    // Withdraw and swap
    amountOut = UniswapV2Service._withdrawSwapDirect(
        pool,
        router,
        lpAmount,
        tokenOut,
        opToken
    );

    // Transfer result
    tokenOut.transfer(msg.sender, amountOut);
}
```

## TestBase_UniswapV2

Deploys Uniswap V2 protocol stack:

```solidity
abstract contract TestBase_UniswapV2 is TestBase_Weth9 {
    address uniswapV2FeeToSetter;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router internal uniswapV2Router;

    function setUp() public virtual override {
        TestBase_Weth9.setUp();
        uniswapV2FeeToSetter = makeAddr("uniswapV2FeeToSetter");
        uniswapV2Factory = new UniV2Factory(uniswapV2FeeToSetter);
        uniswapV2Router = new UniV2Router02(
            address(uniswapV2Factory),
            address(weth)
        );
    }

    // Helper to get sorted reserves
    function sortedReserves(
        address tokenA_,
        IUniswapV2Pair pair_
    ) internal view returns (uint256 reserveA, uint256 reserveB);

    // Helper to add balanced liquidity
    function addBalancedUniswapLiquidity(
        IUniswapV2Pair pair_,
        address tokenA_,
        address tokenB_,
        uint256 amountADesired_,
        uint256 amountBDesired_,
        address recipient_
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}
```

## ConstProdUtils Integration

UniswapV2Service uses ConstProdUtils for calculations:

```solidity
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

// Quote output amount (with 0.3% fee)
uint256 amountOut = ConstProdUtils._saleQuote(
    amountIn,
    reserveIn,
    reserveOut,
    300  // 0.3% fee
);

// Calculate optimal swap amount for balanced deposit
uint256 swapAmount = ConstProdUtils._swapDepositSaleAmt(
    saleAmt,
    saleReserve,
    300  // 0.3% fee
);

// Calculate equivalent liquidity amounts
uint256 amountB = ConstProdUtils._equivLiquidity(
    amountA,
    reserveA,
    reserveB
);
```

## Uniswap V3 Math Libraries

Key V3 libraries for concentrated liquidity:

### TickMath

```solidity
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";

// Get sqrt price from tick
uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

// Get tick from sqrt price
int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

// Constants
int24 MIN_TICK = TickMath.MIN_TICK;  // -887272
int24 MAX_TICK = TickMath.MAX_TICK;  // 887272
```

### SqrtPriceMath

```solidity
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SqrtPriceMath.sol";

// Calculate amount0 delta
uint256 amount0 = SqrtPriceMath.getAmount0Delta(
    sqrtPriceLowerX96,
    sqrtPriceUpperX96,
    liquidity,
    roundUp
);

// Calculate amount1 delta
uint256 amount1 = SqrtPriceMath.getAmount1Delta(
    sqrtPriceLowerX96,
    sqrtPriceUpperX96,
    liquidity,
    roundUp
);
```

### SwapMath

```solidity
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SwapMath.sol";

// Compute swap step
(
    uint160 sqrtRatioNextX96,
    uint256 amountIn,
    uint256 amountOut,
    uint256 feeAmount
) = SwapMath.computeSwapStep(
    sqrtRatioCurrentX96,
    sqrtRatioTargetX96,
    liquidity,
    amountRemaining,
    feePips
);
```

## Uniswap V4 Utilities

### UniswapV4Quoter

```solidity
import {UniswapV4Quoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol";

// Quote a swap
(uint256 amountOut, uint256 priceAfter) = UniswapV4Quoter.quoteSwap(
    poolManager,
    poolKey,
    amountIn,
    zeroForOne  // true if swapping token0 for token1
);
```

### UniswapV4ZapQuoter

```solidity
import {UniswapV4ZapQuoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4ZapQuoter.sol";

// Quote a single-token zap
(uint256 amount0, uint256 amount1, uint256 liquidity) = UniswapV4ZapQuoter.quoteZap(
    poolManager,
    poolKey,
    amountIn,
    isToken0  // true if depositing token0
);
```

### PoolKey Type

```solidity
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

PoolKey memory key = PoolKey({
    currency0: Currency.wrap(address(token0)),
    currency1: Currency.wrap(address(token1)),
    fee: 3000,  // 0.3%
    tickSpacing: 60,
    hooks: IHooks(address(0))
});
```

## Storage Slots (AwareRepos)

| Repo | Slot |
|------|------|
| UniswapV2RouterAwareRepo | `"protocols.dexes.uniswap.v2.router.aware"` |
| UniswapV2FactoryAwareRepo | `"protocols.dexes.uniswap.v2.factory.aware"` |

## Test Example

```solidity
import {TestBase_UniswapV2} from "@crane/contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2.sol";
import {UniswapV2Service} from "@crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

contract MyUniswapTest is TestBase_UniswapV2 {
    ERC20PermitMintableStub tokenA;
    ERC20PermitMintableStub tokenB;
    IUniswapV2Pair pair;

    function setUp() public override {
        super.setUp();

        // Create test tokens
        tokenA = new ERC20PermitMintableStub("TokenA", "TKA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("TokenB", "TKB", 18, address(this), 0);

        // Create pair
        pair = IUniswapV2Pair(
            uniswapV2Factory.createPair(address(tokenA), address(tokenB))
        );
    }

    function test_swapAndDeposit() public {
        // Mint and approve tokens
        uint256 initAmount = 10000e18;
        tokenA.mint(address(this), initAmount);
        tokenB.mint(address(this), initAmount);
        tokenA.approve(address(uniswapV2Router), initAmount);
        tokenB.approve(address(uniswapV2Router), initAmount);

        // Add initial liquidity
        UniswapV2Service._deposit(
            uniswapV2Router,
            tokenA,
            tokenB,
            initAmount,
            initAmount
        );

        // Zap in with single token
        uint256 zapAmount = 1000e18;
        tokenA.mint(address(this), zapAmount);
        tokenA.approve(address(uniswapV2Router), zapAmount);

        uint256 lpOut = UniswapV2Service._swapDeposit(
            uniswapV2Router,
            pair,
            tokenA,
            zapAmount,
            tokenB
        );

        assertGt(lpOut, 0, "Should receive LP tokens");
    }
}
```
