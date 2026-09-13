// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

/// @dev Holds Uni V4 SE shares and redeems with pretransferred=false (transferFrom).
contract Univ4SeNestedShareHolder {
    function redeemShares(address se, uint256 shares, address tokenOut, uint256 deadline)
        external
        returns (uint256)
    {
        return IStandardExchangeIn(se).exchangeIn(
            IERC20(se), shares, IERC20(tokenOut), 0, address(this), false, deadline
        );
    }

    function approve(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }
}

contract Univ4SeNestedCallerSeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));
        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(liquidity)),
                salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey.currency0, callerDelta.amount0());
        _settle(poolKey.currency1, callerDelta.amount1());
        return abi.encode(callerDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

/**
 * @title Uni V4 SE nested-caller share pull
 * @notice Documents vault law: exchangeIn(shares, false) is transferFrom. Contract holders need approve.
 */
contract UniswapV4StandardExchange_Univ4SeNestedCaller_Test is TestBase_UniswapV4StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    Univ4SeNestedShareHolder internal holder;
    PoolKey internal poolKey;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        poolKey = PoolKey({
            currency0: Currency.wrap(t0),
            currency1: Currency.wrap(t1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        Univ4SeNestedCallerSeeder seeder = new Univ4SeNestedCallerSeeder(IPoolManager(address(poolManager)));
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liq);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        holder = new Univ4SeNestedShareHolder();
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 days;
    }

    function _tokenOut() internal view returns (address) {
        return IBasicVault(address(vault)).vaultTokens()[0];
    }

    function test_exchangeIn_shares_contractHolder_zeroAllowance_revertsTransferFromFailed() public {
        uint256 amountIn = 10 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);
        uint256 shares = IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "minted shares");

        IERC20(address(vault)).transfer(address(holder), shares);
        assertEq(IERC20(address(vault)).allowance(address(holder), address(vault)), 0, "holder allowance 0");

        address tokenOut = _tokenOut();
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        holder.redeemShares(address(vault), shares, tokenOut, _deadline());
    }

    function test_exchangeIn_shares_contractHolder_afterApprove_succeeds() public {
        uint256 amountIn = 10 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);
        uint256 shares = IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "minted shares");

        IERC20(address(vault)).transfer(address(holder), shares);
        holder.approve(address(vault), address(vault), shares);
        uint256 pairOut = holder.redeemShares(address(vault), shares, _tokenOut(), _deadline());
        assertGt(pairOut, 0, "unwrap after approve");
        assertGt(IERC20(_tokenOut()).balanceOf(address(holder)), 0, "holder received pair");
    }
}
