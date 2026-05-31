// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {UniswapV4ZapQuoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4ZapQuoter.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {UniswapV4QuoteService} from "contracts/protocols/dexes/uniswap/v4/UniswapV4QuoteService.sol";
import {UniswapV4StandardExchangeCommon} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

abstract contract UniswapV4StandardExchangeInBase is UniswapV4StandardExchangeCommon, ReentrancyLockModifiers {
    struct ZapInState {
        address token0;
        address token1;
        bool zeroForOne;
        uint256 totalSharesBefore;
        uint256 reserve0Before;
        uint256 reserve1Before;
        ManagedTicks managedTicks;
        ManagedLiquidityPlan plan;
        uint256 balance0Before;
        uint256 balance1Before;
        uint256 amount0Used;
        uint256 amount1Used;
    }

    error UniswapV4ExchangeIn_DeadlineExceeded();
    error UniswapV4ExchangeIn_SlippageExceeded();
    error UniswapV4ExchangeIn_PositionImportUnavailable();
    error UniswapV4ExchangeIn_InvalidImportedPool();

    function _swapExactIn(bool zeroForOne, uint256 amountSpecified) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.SwapExactIn,
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                tickLower: 0,
                tickUpper: 0,
                liquidity: 0,
                salt: bytes32(0)
            })
        );
    }

    function _addLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.AddLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _removeLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _createManagedPositionsIfNeeded(ManagedTicks memory managedTicks) internal {
        if (UniswapV4PositionRepo._isPositionCreated()) {
            return;
        }

        UniswapV4PositionRepo._createPositionIfNeeded(
            UniswapV4PositionRepo.PositionKind.Center,
            managedTicks.centerLower,
            managedTicks.centerUpper
        );
        UniswapV4PositionRepo._createPositionIfNeeded(
            UniswapV4PositionRepo.PositionKind.LowerWing,
            managedTicks.lowerWingLower,
            managedTicks.lowerWingUpper
        );
        UniswapV4PositionRepo._createPositionIfNeeded(
            UniswapV4PositionRepo.PositionKind.UpperWing,
            managedTicks.upperWingLower,
            managedTicks.upperWingUpper
        );
    }

    function _quoteImportedPositionShares(PositionInfo info, uint128 liquidity) internal view returns (uint256 sharesOut) {
        (uint160 sqrtPriceX96, int24 currentTick,,) = _slot0();
        (uint256 amount0Used, uint256 amount1Used) = _amountsForLiquidityAtPrice(
            sqrtPriceX96,
            currentTick,
            info.tickLower(),
            info.tickUpper(),
            liquidity
        );

        sharesOut = _quoteSharesOut(amount0Used, amount1Used, 0);
    }

    function _executeDirectSwapIn(address tokenIn, uint256 amountIn, address recipient) internal returns (uint256 amountOut) {
        bool zeroForOne = tokenIn == _token0();
        address tokenOut = zeroForOne ? _token1() : _token0();
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        _swapExactIn(zeroForOne, amountIn);

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        _transferCurrency(tokenOut, recipient, amountOut);
    }

    function _previewZapOutExactIn(address tokenOut, uint256 sharesBurned) internal view returns (uint256 amountOut) {
        if (sharesBurned == 0) {
            return 0;
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0 || (!UniswapV4PositionRepo._isPositionCreated() && !UniswapV4PositionRepo._isImportedPosition())) {
            return 0;
        }

        return _quoteZapOutAmount(tokenOut, sharesBurned, totalShares);
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        if (tokenOut == _token0()) {
            return amount0 + _quoteSwapIn(amount1, false);
        }
        return amount1 + _quoteSwapIn(amount0, true);
    }

    function _executeZapOutExactIn(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient)
        internal
        returns (uint256 amountOut)
    {
        if (sharesBurned == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        address token0 = _token0();
        address token1 = _token1();
        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.Center, sharesBurned, totalShares);
        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing, sharesBurned, totalShares);
        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing, sharesBurned, totalShares);

        uint256 amount0 = IERC20(token0).balanceOf(address(this)) - balance0Before;
        uint256 amount1 = IERC20(token1).balanceOf(address(this)) - balance1Before;

        if (tokenOut == token0 && amount1 > 0) {
            _swapExactIn(false, amount1);
        } else if (tokenOut == token1 && amount0 > 0) {
            _swapExactIn(true, amount0);
        }

        _refreshStoredLiquidity();
        _syncVaultReserves();

        amountOut = IERC20(tokenOut).balanceOf(address(this));
        if (amountOut < minAmountOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        ERC20Repo._burn(address(this), sharesBurned);

        _transferCurrency(tokenOut, recipient, amountOut);
    }

    function _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind kind, uint256 sharesBurned, uint256 totalShares)
        internal
    {
        uint128 currentLiquidity = _currentLiquidity(kind);
        if (currentLiquidity == 0) {
            return;
        }

        uint128 liquidityToBurn = uint128((sharesBurned * currentLiquidity) / totalShares);
        if (liquidityToBurn == 0) {
            return;
        }

        if (UniswapV4PositionRepo._isImportedPosition()) {
            if (kind != UniswapV4PositionRepo.PositionKind.Center) {
                return;
            }

            bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(
                UniswapV4PositionRepo._importedPositionTokenId(), uint256(liquidityToBurn), uint128(0), uint128(0), bytes("")
            );
            params[1] = abi.encode(_currency0(), _currency1(), address(this));
            UniswapV4PositionRepo._importedPositionManager().modifyLiquidities(abi.encode(actions, params), block.timestamp);
            return;
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        _removeLiquidity(tickLower, tickUpper, liquidityToBurn, UniswapV4PositionRepo._salt(kind));
    }

    function _previewZapInDeposit(address tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        if (amountIn == 0) {
            return 0;
        }

        if (UniswapV4PositionRepo._isImportedPosition()) {
            return _previewImportedPositionDeposit(tokenIn, amountIn);
        }

        bool initialDeposit = !UniswapV4PositionRepo._isPositionCreated();
        ManagedTicks memory managedTicks = initialDeposit ? _deriveManagedTicks() : _managedTicks();

        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        UniswapV4ZapQuoter.ZapInQuote memory quote = UniswapV4QuoteService._quoteZapInDetail(
            UniswapV4QuoteService.ZapInQuoteParams({
                manager: _poolManager(),
                key: _poolKey(),
                tickLower: managedTicks.centerLower,
                tickUpper: managedTicks.centerUpper,
                zeroForOne: tokenIn == _token0(),
                amountIn: amountIn,
                totalShares: totalShares,
                reserve0: reserve0,
                reserve1: reserve1,
                initialDeposit: initialDeposit || totalShares == 0
            })
        );

        uint256 available0;
        uint256 available1;
        if (tokenIn == _token0()) {
            available0 = amountIn - quote.swap.amountIn;
            available1 = quote.swap.amountOut;
        } else {
            available0 = quote.swap.amountOut;
            available1 = amountIn - quote.swap.amountIn;
        }

        (uint160 currentSqrtPriceX96, int24 currentTick,,) = _slot0();
        uint160 priceForMint = quote.swapAmountIn > 0 ? quote.swap.sqrtPriceAfterX96 : currentSqrtPriceX96;
        int24 tickForMint = quote.swapAmountIn > 0 ? quote.swap.tickAfter : currentTick;
        ManagedLiquidityPlan memory plan =
            _managedLiquidityPlanAtState(managedTicks, available0, available1, priceForMint, tickForMint);
        return _quoteSharesOut(plan.amount0Used, plan.amount1Used, totalShares);
    }

    function _executeZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        if (amountIn == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        if (UniswapV4PositionRepo._isImportedPosition()) {
            return _executeImportedPositionDeposit(tokenIn, amountIn, minSharesOut, recipient);
        }

        ZapInState memory state;
        state.token0 = _token0();
        state.token1 = _token1();
        state.zeroForOne = tokenIn == state.token0;
        state.totalSharesBefore = IERC20(address(this)).totalSupply();
        (state.reserve0Before, state.reserve1Before) = _totalVaultReserves();
        state.managedTicks = _managedTicks();

        uint256 swapPortion = UniswapV4QuoteService._quoteZapInSwapAmount(
            UniswapV4QuoteService.ZapInQuoteParams({
                manager: _poolManager(),
                key: _poolKey(),
                tickLower: state.managedTicks.centerLower,
                tickUpper: state.managedTicks.centerUpper,
                zeroForOne: state.zeroForOne,
                amountIn: amountIn,
                totalShares: state.totalSharesBefore,
                reserve0: state.reserve0Before,
                reserve1: state.reserve1Before,
                initialDeposit: !UniswapV4PositionRepo._isPositionCreated() || state.totalSharesBefore == 0
            })
        );

        if (swapPortion > 0) {
            _swapExactIn(state.zeroForOne, swapPortion);
        }

        _createManagedPositionsIfNeeded(state.managedTicks);

        uint256 available0 = IERC20(state.token0).balanceOf(address(this));
        uint256 available1 = IERC20(state.token1).balanceOf(address(this));
        state.plan = _managedLiquidityPlan(state.managedTicks, available0, available1);

        state.balance0Before = IERC20(state.token0).balanceOf(address(this));
        state.balance1Before = IERC20(state.token1).balanceOf(address(this));

        if (state.plan.centerLiquidity > 0) {
            _addLiquidity(
                state.managedTicks.centerLower,
                state.managedTicks.centerUpper,
                state.plan.centerLiquidity,
                UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.Center)
            );
        }
        if (state.plan.lowerWingLiquidity > 0) {
            _addLiquidity(
                state.managedTicks.lowerWingLower,
                state.managedTicks.lowerWingUpper,
                state.plan.lowerWingLiquidity,
                UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.LowerWing)
            );
        }
        if (state.plan.upperWingLiquidity > 0) {
            _addLiquidity(
                state.managedTicks.upperWingLower,
                state.managedTicks.upperWingUpper,
                state.plan.upperWingLiquidity,
                UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.UpperWing)
            );
        }

        state.amount0Used = state.balance0Before - IERC20(state.token0).balanceOf(address(this));
        state.amount1Used = state.balance1Before - IERC20(state.token1).balanceOf(address(this));

        _refreshStoredLiquidity();
        _syncVaultReserves();

        if (state.totalSharesBefore == 0) {
            sharesOut = state.amount0Used + state.amount1Used;
        } else {
            sharesOut = ConstProdUtils._depositQuote(
                state.amount0Used,
                state.amount1Used,
                state.totalSharesBefore,
                state.reserve0Before,
                state.reserve1Before
            );
        }

        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        ERC20Repo._mint(recipient, sharesOut);

        _refundRemainder(state.token0);
        _refundRemainder(state.token1);
    }

    function _refundRemainder(address token) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            _transferCurrency(token, msg.sender, balance);
        }
    }

    function _previewImportedPositionDeposit(address tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        bool zeroForOne = tokenIn == _token0();
        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.Center);
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return UniswapV4QuoteService._quoteZapInShares(
            UniswapV4QuoteService.ZapInQuoteParams({
                manager: _poolManager(),
                key: _poolKey(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                totalShares: IERC20(address(this)).totalSupply(),
                reserve0: reserve0,
                reserve1: reserve1,
                initialDeposit: false
            })
        );
    }

    function _executeImportedPositionDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        bool zeroForOne = tokenIn == _token0();
        uint256 totalSharesBefore = IERC20(address(this)).totalSupply();
        (uint256 reserve0Before, uint256 reserve1Before) = _totalVaultReserves();
        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.Center);

        uint256 swapPortion = UniswapV4QuoteService._quoteZapInSwapAmount(
            UniswapV4QuoteService.ZapInQuoteParams({
                manager: _poolManager(),
                key: _poolKey(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                totalShares: totalSharesBefore,
                reserve0: reserve0Before,
                reserve1: reserve1Before,
                initialDeposit: false
            })
        );

        if (swapPortion > 0) {
            _swapExactIn(zeroForOne, swapPortion);
        }

        uint256 balance0Before = IERC20(_token0()).balanceOf(address(this));
        uint256 balance1Before = IERC20(_token1()).balanceOf(address(this));
        (uint160 sqrtPriceX96,,,) = _slot0();
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            balance0Before,
            balance1Before
        );

        if (liquidity > 0) {
            _increaseImportedPosition(liquidity, uint128(balance0Before), uint128(balance1Before));
        }

        uint256 amount0Used = balance0Before - IERC20(_token0()).balanceOf(address(this));
        uint256 amount1Used = balance1Before - IERC20(_token1()).balanceOf(address(this));
        sharesOut = _quoteSharesOut(amount0Used, amount1Used, totalSharesBefore);
        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        _refreshStoredLiquidity();
        _syncVaultReserves();
        ERC20Repo._mint(recipient, sharesOut);
        _refundRemainder(_token0());
        _refundRemainder(_token1());
    }

    function _increaseImportedPosition(uint128 liquidity, uint128 amount0Max, uint128 amount1Max) internal {
        Permit2AwareRepo._permit2().approve(_token0(), address(UniswapV4PositionRepo._importedPositionManager()), type(uint160).max, type(uint48).max);
        Permit2AwareRepo._permit2().approve(_token1(), address(UniswapV4PositionRepo._importedPositionManager()), type(uint160).max, type(uint48).max);
        IERC20(_token0()).approve(address(UniswapV4PositionRepo._importedPositionManager()), amount0Max);
        IERC20(_token1()).approve(address(UniswapV4PositionRepo._importedPositionManager()), amount1Max);

        bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(UniswapV4PositionRepo._importedPositionTokenId(), uint256(liquidity), amount0Max, amount1Max, bytes(""));
        params[1] = abi.encode(_currency0(), _currency1());
        UniswapV4PositionRepo._importedPositionManager().modifyLiquidities(abi.encode(actions, params), block.timestamp);

        IERC20(_token0()).approve(address(UniswapV4PositionRepo._importedPositionManager()), 0);
        IERC20(_token1()).approve(address(UniswapV4PositionRepo._importedPositionManager()), 0);
    }
}