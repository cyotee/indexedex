// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

/// @dev Seeds a V4 pool that may use native ETH as currency0.
contract UniswapV4NativeEthPoolSeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    receive() external payable {}

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
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
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
            if (currency.isAddressZero()) {
                poolManager.settle{value: amount}();
            } else {
                IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
                poolManager.settle();
            }
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

/**
 * @title UniswapV4StandardExchange_NativeEthWrap
 * @notice Native ETH PoolKey: vault face is WETH; settle unwraps; take wraps.
 */
contract UniswapV4StandardExchange_NativeEthWrap is TestBase_UniswapV4StandardExchange {
    ERC20PermitMintableStub internal pairToken;
    IStandardExchangeProxy internal vault;
    UniswapV4NativeEthPoolSeeder internal seeder;
    PoolKey internal poolKey;

    function setUp() public override {
        super.setUp();

        pairToken = new ERC20PermitMintableStub("Pair", "PAIR", 18, address(this), 0);
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(pairToken)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        seeder = new UniswapV4NativeEthPoolSeeder(poolManager);
        pairToken.mint(address(seeder), 1_000_000 ether);
        vm.deal(address(seeder), 1_000_000 ether);

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
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 days;
    }

    function _assertNoNativeDust() internal view {
        assertEq(address(vault).balance, 0, "vault must not hold native ETH");
    }

    /// @notice Zap-in WETH and pairToken: vault unwraps WETH to settle native ETH, leftover ETH is re-wrapped.
    function test_zapIn_nativeEthPool_unwrapsWethAndLeavesNoEthDust() public {
        assertEq(IBasicVault(address(vault)).vaultTokens()[0], address(weth), "WETH face");

        vm.deal(address(this), 20 ether);
        weth.deposit{value: 10 ether}();
        pairToken.mint(address(this), 10 ether);
        IERC20(address(weth)).approve(address(vault), 10 ether);
        pairToken.approve(address(vault), 10 ether);

        uint256 shares0 = vault.exchangeIn(
            IERC20(address(weth)), 10 ether, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        _assertNoNativeDust();
        uint256 shares1 = vault.exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        _assertNoNativeDust();

        assertGt(shares0, 0, "WETH zap-in minted shares");
        assertGt(shares1, 0, "pairToken zap-in minted shares");
        assertGt(IERC20(address(vault)).balanceOf(address(this)), 0, "user holds vault shares");
    }

    /// @notice Direct swap WETH -> pairToken and back: take native ETH is wrapped to WETH before transfer.
    function test_swap_nativeEthPool_wrapsTakenEthToWeth() public {
        vm.deal(address(this), 30 ether);
        weth.deposit{value: 20 ether}();
        pairToken.mint(address(this), 10 ether);
        IERC20(address(weth)).approve(address(vault), type(uint256).max);
        pairToken.approve(address(vault), type(uint256).max);

        vault.exchangeIn(IERC20(address(weth)), 10 ether, IERC20(address(vault)), 0, address(this), false, _deadline());
        vault.exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        _assertNoNativeDust();

        uint256 pairBefore = pairToken.balanceOf(address(this));
        uint256 pairOut = vault.exchangeIn(
            IERC20(address(weth)), 1 ether, IERC20(address(pairToken)), 0, address(this), false, _deadline()
        );
        _assertNoNativeDust();
        assertGt(pairOut, 0, "WETH->pair out");
        assertEq(pairToken.balanceOf(address(this)), pairBefore + pairOut, "pair delivered as ERC-20");

        uint256 wethBefore = IERC20(address(weth)).balanceOf(address(this));
        uint256 wethOut = vault.exchangeIn(
            IERC20(address(pairToken)), pairOut / 2, IERC20(address(weth)), 0, address(this), false, _deadline()
        );
        _assertNoNativeDust();
        assertGt(wethOut, 0, "pair->WETH out");
        assertEq(IERC20(address(weth)).balanceOf(address(this)), wethBefore + wethOut, "WETH delivered not native ETH");
        assertEq(address(this).balance, 10 ether, "user ETH unchanged after WETH swaps");
    }

    /// @notice Redeem vault shares for WETH: PoolManager take of native ETH is wrapped before payout.
    function test_zapOut_nativeEthPool_paysWethNotEth() public {
        vm.deal(address(this), 20 ether);
        weth.deposit{value: 10 ether}();
        pairToken.mint(address(this), 10 ether);
        IERC20(address(weth)).approve(address(vault), type(uint256).max);
        pairToken.approve(address(vault), type(uint256).max);
        IERC20(address(vault)).approve(address(vault), type(uint256).max);

        vault.exchangeIn(IERC20(address(weth)), 10 ether, IERC20(address(vault)), 0, address(this), false, _deadline());
        vault.exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(address(vault)), 0, address(this), false, _deadline()
        );

        uint256 shares = IERC20(address(vault)).balanceOf(address(this));
        assertGt(shares, 0, "shares");
        uint256 ethBefore = address(this).balance;
        uint256 wethBefore = IERC20(address(weth)).balanceOf(address(this));

        uint256 wethOut = vault.exchangeIn(
            IERC20(address(vault)), shares / 2, IERC20(address(weth)), 0, address(this), false, _deadline()
        );
        _assertNoNativeDust();
        assertGt(wethOut, 0, "share->WETH out");
        assertEq(IERC20(address(weth)).balanceOf(address(this)), wethBefore + wethOut, "payout is WETH");
        assertEq(address(this).balance, ethBefore, "payout is not native ETH");
    }
}
