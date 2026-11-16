# Camelot V2 Service Reference

## Directory Structure

```
contracts/protocols/dexes/camelot/v2/
├── services/
│   └── CamelotV2Service.sol
├── CamelotV2RouterAwareRepo.sol
├── CamelotV2FactoryAwareRepo.sol
├── stubs/
│   ├── CamelotFactory.sol
│   ├── CamelotRouter.sol
│   ├── CamelotPair.sol
│   ├── UniswapV2ERC20.sol
│   └── libraries/
│       ├── Math.sol
│       ├── SafeMath.sol
│       ├── TransferHelper.sol
│       ├── UQ112x112.sol
│       └── UniswapV2Library.sol
└── test/bases/
    └── TestBase_CamelotV2.sol
```

## Interfaces

```
contracts/interfaces/protocols/dexes/camelot/v2/
├── ICamelotFactory.sol
├── ICamelotV2Router.sol
└── ICamelotPair.sol
```

## SwapParams Struct

```solidity
struct SwapParams {
    ICamelotV2Router router;
    uint256 amountIn;
    IERC20 tokenIn;
    uint256 reserveIn;
    uint256 feePercent;
    IERC20 tokenOut;
    uint256 reserveOut;
    address referrer;
}
```

## BalanceParams Struct

```solidity
struct BalanceParams {
    ICamelotV2Router router;
    uint256 saleAmt;
    IERC20 tokenIn;
    uint256 saleReserve;
    uint256 saleTokenFeePerc;
    IERC20 tokenOut;
    uint256 reserveOut;
    address referrer;
}
```

## WithdrawSwapParams Struct

```solidity
struct WithdrawSwapParams {
    ICamelotPair pool;
    ICamelotV2Router router;
    uint256 amt;
    IERC20 tokenOut;
    IERC20 opToken;
    address referrer;
}
```

## ReserveInfo Struct

```solidity
struct ReserveInfo {
    uint256 reserveIn;
    uint256 reserveOut;
    uint256 feePercent;
    uint256 unknownFee;
}
```

## Complete Swap Example

```solidity
import {CamelotV2Service} from "@crane/contracts/protocols/dexes/camelot/v2/services/CamelotV2Service.sol";
import {ICamelotV2Router} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotV2Router.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ICamelotFactory} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotFactory.sol";
import {CamelotV2RouterAwareRepo} from "@crane/contracts/protocols/dexes/camelot/v2/CamelotV2RouterAwareRepo.sol";

contract CamelotVault {
    using CamelotV2Service for ICamelotV2Router;

    ICamelotV2Router public router;
    ICamelotFactory public factory;

    function swapExact(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        // Get pool
        ICamelotPair pool = ICamelotPair(
            factory.getPair(address(tokenIn), address(tokenOut))
        );

        // Transfer tokens in
        tokenIn.transferFrom(msg.sender, address(this), amountIn);

        // Execute swap (no referrer)
        amountOut = CamelotV2Service._swap(
            router,
            pool,
            amountIn,
            tokenIn,
            tokenOut,
            address(0)
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
    ICamelotPair pool = ICamelotPair(
        factory.getPair(address(tokenIn), address(opposingToken))
    );

    tokenIn.transferFrom(msg.sender, address(this), amountIn);

    lpOut = CamelotV2Service._swapDeposit(
        router,
        pool,
        tokenIn,
        amountIn,
        opposingToken,
        address(0)  // referrer
    );

    // Transfer LP tokens to user
    IERC20(address(pool)).transfer(msg.sender, lpOut);
}
```

## Zap Out (Withdraw and Swap)

Withdraw LP tokens to single token:

```solidity
function zapOut(
    ICamelotPair pool,
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
    amountOut = CamelotV2Service._withdrawSwapDirect(
        pool,
        router,
        lpAmount,
        tokenOut,
        opToken,
        address(0)
    );

    // Transfer result
    tokenOut.transfer(msg.sender, amountOut);
}
```

## Balance Assets Helper

Swap to achieve balanced token amounts for deposit:

```solidity
function balanceForDeposit(
    ICamelotPair pool,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 totalAmount
) external returns (uint256[] memory balancedAmounts) {
    tokenIn.transferFrom(msg.sender, address(this), totalAmount);

    balancedAmounts = CamelotV2Service._balanceAssets(
        router,
        pool,
        totalAmount,
        tokenIn,
        tokenOut,
        address(0)
    );

    // balancedAmounts[0] = remaining tokenIn
    // balancedAmounts[1] = swapped tokenOut
}
```

## Referrer Support

Camelot supports referrer fees. Pass a referrer address to earn fees:

```solidity
address referrer = 0x...;  // Your referrer address

CamelotV2Service._swap(
    router,
    pool,
    amountIn,
    tokenIn,
    tokenOut,
    referrer  // Referrer earns portion of fees
);
```

## TestBase_CamelotV2

Deploys Camelot protocol stack for testing:

```solidity
abstract contract TestBase_CamelotV2 is TestBase_Weth9 {
    address camelotV2FeeToSetter;
    ICamelotFactory internal camelotV2Factory;
    ICamelotV2Router internal camelotV2Router;

    function setUp() public virtual override {
        camelotV2FeeToSetter = makeAddr("camelotV2FeeToSetter");
        TestBase_Weth9.setUp();

        camelotV2Factory = new CamelotFactory(camelotV2FeeToSetter);
        camelotV2Router = new CamelotRouter(
            address(camelotV2Factory),
            address(weth)
        );
    }
}
```

## ConstProdUtils Integration

CamelotV2Service uses ConstProdUtils for quote calculations:

```solidity
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

// Quote output amount
uint256 amountOut = ConstProdUtils._saleQuote(
    amountIn,
    reserveIn,
    reserveOut,
    feePercent
);

// Calculate optimal swap amount for balanced deposit
uint256 swapAmount = ConstProdUtils._swapDepositSaleAmt(
    saleAmt,
    saleReserve,
    saleTokenFeePerc
);
```

## Asymmetric Fee Handling

The key difference from Uniswap V2 - Camelot has directional fees:

```solidity
function _sortReservesStruct(
    ICamelotPair pool,
    IERC20 knownToken
) internal view returns (ReserveInfo memory reserves) {
    // Camelot's getReserves returns 4 values including both fees
    (
        uint112 reserve0,
        uint112 reserve1,
        uint16 token0feePercent,
        uint16 token1FeePercent
    ) = pool.getReserves();

    address token0 = pool.token0();

    if (address(knownToken) == token0) {
        reserves.reserveIn = reserve0;
        reserves.reserveOut = reserve1;
        reserves.feePercent = token0feePercent;  // Fee for token0 → token1
        reserves.unknownFee = token1FeePercent;   // Fee for token1 → token0
    } else {
        reserves.reserveIn = reserve1;
        reserves.reserveOut = reserve0;
        reserves.feePercent = token1FeePercent;  // Fee for token1 → token0
        reserves.unknownFee = token0feePercent;   // Fee for token0 → token1
    }
}
```

## Storage Slots (AwareRepos)

| Repo | Slot |
|------|------|
| CamelotV2RouterAwareRepo | `"protocols.dexes.camelot.v2.router.aware"` |
| CamelotV2FactoryAwareRepo | `"protocols.dexes.camelot.v2.factory.aware"` |

## Test Helper Example

```solidity
import {TestBase_CamelotV2} from "@crane/contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2.sol";
import {CamelotV2Service} from "@crane/contracts/protocols/dexes/camelot/v2/services/CamelotV2Service.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

contract MyCamelotTest is TestBase_CamelotV2 {
    ERC20PermitMintableStub tokenA;
    ERC20PermitMintableStub tokenB;
    ICamelotPair pair;

    function setUp() public override {
        super.setUp();

        // Create test tokens
        tokenA = new ERC20PermitMintableStub("TokenA", "TKA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("TokenB", "TKB", 18, address(this), 0);

        // Create pair
        pair = ICamelotPair(
            camelotV2Factory.createPair(address(tokenA), address(tokenB))
        );
    }

    function test_swapWithAsymmetricFees() public {
        // Mint and approve tokens
        uint256 initAmount = 10000e18;
        tokenA.mint(address(this), initAmount);
        tokenB.mint(address(this), initAmount);
        tokenA.approve(address(camelotV2Router), initAmount);
        tokenB.approve(address(camelotV2Router), initAmount);

        // Add liquidity
        CamelotV2Service._deposit(
            camelotV2Router,
            tokenA,
            tokenB,
            initAmount,
            initAmount
        );

        // Mint tokens for swap
        uint256 swapAmount = 100e18;
        tokenA.mint(address(this), swapAmount);
        tokenA.approve(address(camelotV2Router), swapAmount);

        // Execute swap
        uint256 amountOut = CamelotV2Service._swap(
            camelotV2Router,
            pair,
            swapAmount,
            tokenA,
            tokenB,
            address(0)
        );

        assertGt(amountOut, 0, "Should receive tokens");
    }
}
```
