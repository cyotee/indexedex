// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {UniswapV4ProtocolAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {SafeCast} from "@crane/contracts/protocols/dexes/uniswap/libraries/SafeCast.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "./UniswapV4FullSpreadStandardExchangeVaultTypes.sol";
import {UniswapV4FullSpreadStandardExchangeVaultMath as Math} from "./UniswapV4FullSpreadStandardExchangeVaultMath.sol";
import {UniswapV4FullSpreadStandardExchangeVaultProjection as Projection} from "./UniswapV4FullSpreadStandardExchangeVaultProjection.sol";
import {UniswapV4FullSpreadStandardExchangeVaultSwapProjection as SwapProjection} from "./UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV4FullSpreadStandardExchangeVaultRepo.sol";

/// @notice The one quote engine. Execution calls these same functions.
library UniswapV4FullSpreadStandardExchangeVaultPlanner {
    function planIn(address tokenIn_, uint256 amountIn_, address tokenOut_) internal view returns (Types.Plan memory plan_) {
        return planIn(Projection.snapshot(), tokenIn_, amountIn_, tokenOut_);
    }

    /// @dev The same plan drives execution and evolves hypothetical memory state.
    /// A rejected candidate's state is discarded by the public quote boundary.
    function planIn(Types.QuoteState memory state_, address tokenIn_, uint256 amountIn_, address tokenOut_)
        internal view returns (Types.Plan memory plan_)
    {
        (address face0_, address face1_) = _faces();
        address share_ = address(this);
        if (tokenIn_ == tokenOut_ || tokenIn_ == address(0) || tokenOut_ == address(0)) return plan_;
        if (tokenIn_ == share_ && (tokenOut_ == face0_ || tokenOut_ == face1_)) {
            return _exit(state_, amountIn_, tokenOut_ == face0_);
        }
        if (tokenOut_ == share_ && (tokenIn_ == face0_ || tokenIn_ == face1_)) {
            return _mintOne(state_, amountIn_, tokenIn_ == face0_);
        }
        if ((tokenIn_ == face0_ || tokenIn_ == face1_) && (tokenOut_ == face0_ || tokenOut_ == face1_)) {
            return _pass(state_, amountIn_, tokenIn_ == face0_);
        }
        return plan_;
    }

    function planBundleIn(uint256 amount0_, uint256 amount1_) internal view returns (Types.Plan memory plan_) {
        Types.QuoteState memory state_ = Projection.snapshot();
        Projection.PositionRead memory read_ = Projection.read(state_);
        (uint128 liquidity_, uint256 used0_, uint256 used1_) =
            Math.proportional(read_.sqrtPriceX96, read_.sqrtA, read_.sqrtB, amount0_, amount1_);
        plan_.kind = Types.Kind.BundleMint;
        plan_.liquidityAdded = liquidity_;
        plan_.refund0 = amount0_ - used0_;
        plan_.refund1 = amount1_ - used1_;
        plan_.emitPairDeposited = true;
        _shares(plan_, read_.liquidity, state_);
        if (liquidity_ != 0) _push(plan_, Types.ActionKind.Modify, false, 0, int256(uint256(liquidity_)));
    }

    function planBundleOut(uint256 shares_) internal view returns (Types.Plan memory plan_) {
        Projection.PositionRead memory read_ = Projection.read();
        uint256 supply_ = ERC20Repo._totalSupply();
        plan_.kind = Types.Kind.BundleExit;
        plan_.sharesBurned = shares_;
        plan_.emitPairRedeemed = true;
        if (supply_ == 0 || shares_ == 0) return plan_;
        uint256 liquidityOut_ = Math.claim(read_.liquidity, shares_, supply_);
        plan_.feeClaim0 = Math.claim(read_.fee0, shares_, supply_);
        plan_.feeClaim1 = Math.claim(read_.fee1, shares_, supply_);
        plan_.feeRemainder0 = read_.fee0 - plan_.feeClaim0;
        plan_.feeRemainder1 = read_.fee1 - plan_.feeClaim1;
        plan_.bookedClaim0 = Math.claim(Repo._booked(0), shares_, supply_);
        plan_.bookedClaim1 = Math.claim(Repo._booked(1), shares_, supply_);
        (uint256 principal0_, uint256 principal1_) = Math.amountsForLiquidity(
            read_.sqrtPriceX96, read_.sqrtA, read_.sqrtB, uint128(liquidityOut_)
        );
        plan_.out0 = principal0_ + plan_.feeClaim0 + plan_.bookedClaim0;
        plan_.out1 = principal1_ + plan_.feeClaim1 + plan_.bookedClaim1;
        if (liquidityOut_ != 0) _push(plan_, Types.ActionKind.Modify, false, 0, -int256(liquidityOut_));
    }

    function planMaintenance(uint256 donate0_, uint256 donate1_, bool donation_) internal view returns (Types.Plan memory plan_) {
        Types.QuoteState memory state_ = Projection.snapshot();
        Projection.PositionRead memory read_ = Projection.read(state_);
        plan_.kind = donation_ ? Types.Kind.Donate : Types.Kind.Compound;
        plan_.emitDonation = donation_;
        uint256 have0_ = Repo._booked(0) + donate0_;
        uint256 have1_ = Repo._booked(1) + donate1_;
        if (read_.fee0 != 0 || read_.fee1 != 0) {
            _push(plan_, Types.ActionKind.Modify, false, 0, 0);
            have0_ += read_.fee0;
            have1_ += read_.fee1;
        }
        if (have0_ == 0 && have1_ == 0) return plan_;
        if (have0_ != 0 && have1_ != 0) {
            (uint128 liquidity_, uint256 used0_, uint256 used1_) =
                Math.proportional(read_.sqrtPriceX96, read_.sqrtA, read_.sqrtB, have0_, have1_);
            plan_.liquidityAdded = liquidity_;
            if (liquidity_ != 0) {
                _push(plan_, Types.ActionKind.Modify, false, 0, int256(uint256(liquidity_)));
                plan_.emitCompounded = read_.fee0 != 0 || read_.fee1 != 0 || Repo._booked(0) != 0 || Repo._booked(1) != 0;
            }
            return plan_;
        }
        bool zeroForOne_ = have0_ != 0;
        uint256 amount_ = zeroForOne_ ? have0_ : have1_;
        Math.Sized memory sized_ = _size(amount_, zeroForOne_, read_, state_);
        plan_.liquidityAdded = sized_.liquidity;
        if (sized_.swapIn != 0) _push(plan_, Types.ActionKind.Swap, zeroForOne_, sized_.swapIn, 0);
        if (sized_.liquidity != 0) {
            _push(plan_, Types.ActionKind.Modify, false, 0, int256(uint256(sized_.liquidity)));
            plan_.emitCompounded = read_.fee0 != 0 || read_.fee1 != 0 || Repo._booked(0) != 0 || Repo._booked(1) != 0;
        }
    }

    function _mintOne(Types.QuoteState memory state_, uint256 amount_, bool zeroForOne_)
        private view returns (Types.Plan memory plan_)
    {
        Projection.PositionRead memory read_ = Projection.read(state_);
        Math.Sized memory sized_ = _size(amount_, zeroForOne_, read_, state_);
        plan_.kind = Types.Kind.OneSidedMint;
        plan_.liquidityAdded = sized_.liquidity;
        plan_.amountRefunded = sized_.remainder;
        if (zeroForOne_) plan_.refund0 = sized_.remainder;
        else plan_.refund1 = sized_.remainder;
        if (sized_.swapIn != 0) _push(plan_, Types.ActionKind.Swap, zeroForOne_, sized_.swapIn, 0);
        _shares(plan_, read_.liquidity, state_);
        if (sized_.liquidity != 0 && !plan_.failed) {
            _push(plan_, Types.ActionKind.Modify, false, 0, int256(uint256(sized_.liquidity)));
            (uint256 fee0_, uint256 fee1_) = Projection.modify(state_, SafeCast.toInt128(uint256(sized_.liquidity)));
            state_.booked[0] += fee0_;
            state_.booked[1] += fee1_;
            state_.supply += plan_.grossShares + (plan_.mintFloor ? Types.MIN_SHARES : 0);
        }
    }

    function _pass(Types.QuoteState memory state_, uint256 amount_, bool zeroForOne_)
        private view returns (Types.Plan memory plan_)
    {
        Types.QuoteState memory candidate_ = abi.decode(abi.encode(state_), (Types.QuoteState));
        Types.SwapQuote memory quote_ = SwapProjection.exactInput(
            UniswapV4ProtocolAwareRepo._poolManager(), UniswapV4SinglePositionAwareRepo._poolKey(), candidate_, zeroForOne_, amount_
        );
        plan_.kind = Types.Kind.PassThrough;
        plan_.amountOut = quote_.received;
        plan_.amountRefunded = amount_ - quote_.spent;
        if (zeroForOne_) plan_.refund0 = plan_.amountRefunded;
        else plan_.refund1 = plan_.amountRefunded;
        if (quote_.spent != 0) {
            _push(plan_, Types.ActionKind.Swap, zeroForOne_, quote_.spent, 0);
            // Execution submits the spent amount. A partial candidate can traverse
            // empty liquidity after its last paid step; that traversal is not executed.
            SwapProjection.exactInput(
                UniswapV4ProtocolAwareRepo._poolManager(), UniswapV4SinglePositionAwareRepo._poolKey(),
                state_, zeroForOne_, quote_.spent
            );
        }
    }

    function _exit(Types.QuoteState memory state_, uint256 shares_, bool want0_) private view returns (Types.Plan memory plan_) {
        Projection.PositionRead memory read_ = Projection.read(state_);
        uint256 supply_ = state_.supply;
        plan_.kind = Types.Kind.OneTokenExit;
        plan_.sharesBurned = shares_;
        if (supply_ == 0 || shares_ == 0 || read_.liquidity == 0) return plan_;
        uint256 liquidityOut_ = Math.claim(read_.liquidity, shares_, supply_);
        plan_.feeClaim0 = Math.claim(read_.fee0, shares_, supply_);
        plan_.feeClaim1 = Math.claim(read_.fee1, shares_, supply_);
        plan_.feeRemainder0 = read_.fee0 - plan_.feeClaim0;
        plan_.feeRemainder1 = read_.fee1 - plan_.feeClaim1;
        plan_.bookedClaim0 = Math.claim(state_.booked[0], shares_, supply_);
        plan_.bookedClaim1 = Math.claim(state_.booked[1], shares_, supply_);
        (uint256 principal0_, uint256 principal1_) = Math.amountsForLiquidity(
            read_.sqrtPriceX96, read_.sqrtA, read_.sqrtB, uint128(liquidityOut_)
        );
        uint256 unwanted_ = want0_
            ? principal1_ + plan_.feeClaim1 + plan_.bookedClaim1
            : principal0_ + plan_.feeClaim0 + plan_.bookedClaim0;
        uint256 wanted_ = want0_
            ? principal0_ + plan_.feeClaim0 + plan_.bookedClaim0
            : principal1_ + plan_.feeClaim1 + plan_.bookedClaim1;
        if (liquidityOut_ != 0) {
            _push(plan_, Types.ActionKind.Modify, false, 0, -int256(liquidityOut_));
            Projection.modify(state_, SafeCast.toInt128(-int256(liquidityOut_)));
        }
        uint256 swapped_ = 0;
        if (unwanted_ != 0) {
            bool zeroForOne_ = !want0_;
            Types.SwapQuote memory quote_ = SwapProjection.exactInput(
                UniswapV4ProtocolAwareRepo._poolManager(),
                UniswapV4SinglePositionAwareRepo._poolKey(),
                state_,
                zeroForOne_,
                unwanted_
            );
            if (quote_.spent != unwanted_) {
                plan_.failed = true;
                return plan_;
            }
            swapped_ = quote_.received;
            _push(plan_, Types.ActionKind.Swap, zeroForOne_, unwanted_, 0);
        }
        plan_.amountOut = wanted_ + swapped_;
        if (want0_) plan_.out0 = plan_.amountOut;
        else plan_.out1 = plan_.amountOut;
        state_.booked[0] = state_.booked[0] - plan_.bookedClaim0 + plan_.feeRemainder0;
        state_.booked[1] = state_.booked[1] - plan_.bookedClaim1 + plan_.feeRemainder1;
        state_.supply -= shares_;
    }

    /// @dev Owner lock 2026-11-06: one exact-input 49% swap, not a search.
    function _size(uint256 amount_, bool zeroForOne_, Projection.PositionRead memory read_, Types.QuoteState memory state_)
        private
        view
        returns (Math.Sized memory best_)
    {
        if (amount_ == 0) return best_;
        if (read_.sqrtPriceX96 <= read_.sqrtA || read_.sqrtPriceX96 >= read_.sqrtB) {
            bool wantsProvided_ = read_.sqrtPriceX96 <= read_.sqrtA ? zeroForOne_ : !zeroForOne_;
            if (!wantsProvided_) {
                best_.remainder = amount_;
                return best_;
            }
            return Math.singleTokenAdd(amount_, zeroForOne_, read_.sqrtPriceX96, read_.sqrtA, read_.sqrtB);
        }
        IPoolManager manager_ = UniswapV4ProtocolAwareRepo._poolManager();
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        if (state_.poolLiquidity == 0) {
            best_.remainder = amount_;
            return best_;
        }
        // FS-OWN-33, 2026-11-06: the whole fixed 49% input must be spent.
        // mulDiv keeps a uint256 token amount from overflowing the product. The quote casts the
        // swap to int256, so an amount that cannot be quoted is refunded whole.
        uint256 swapIn_ = FullMath.mulDiv(amount_, 49, 100);
        if (swapIn_ == 0 || swapIn_ > uint256(type(int256).max)) {
            best_.remainder = amount_;
            return best_;
        }
        Types.SwapQuote memory quote_ = SwapProjection.exactInput(manager_, key_, state_, zeroForOne_, swapIn_);
        if (quote_.received == 0 || quote_.spent != swapIn_) {
            best_.remainder = amount_;
            return best_;
        }
        best_ = Math.sizeOneSided(
            amount_, zeroForOne_, quote_.spent, quote_.received, quote_.sqrtPriceX96, read_.sqrtA, read_.sqrtB
        );
        if (best_.liquidity == 0 || best_.swapIn == 0) {
            best_.swapIn = 0;
            best_.swapOut = 0;
            best_.unswapped = 0;
            best_.liquidity = 0;
            best_.remainder = amount_;
        }
    }

    function _shares(Types.Plan memory plan_, uint128 liquidityBefore_, Types.QuoteState memory state_) private pure {
        uint256 supply_ = state_.supply;
        if (supply_ == 0) {
            if (plan_.liquidityAdded <= Types.MIN_SHARES) {
                plan_.failed = true;
                return;
            }
            plan_.mintFloor = true;
            plan_.grossShares = uint256(plan_.liquidityAdded) - Types.MIN_SHARES;
        } else {
            if (plan_.liquidityAdded == 0) return;
            plan_.grossShares = Math.claim(plan_.liquidityAdded, supply_, liquidityBefore_);
        }
        (plan_.feeShares, plan_.netShares) = Math.netShares(plan_.grossShares, state_.usageFee, state_.feeTo);
        plan_.amountOut = plan_.netShares;
    }

    function _faces() private view returns (address face0_, address face1_) {
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        address weth_ = address(WETHAwareRepo._weth());
        face0_ = Currency.unwrap(key_.currency0);
        if (face0_ == address(0)) face0_ = weth_;
        face1_ = Currency.unwrap(key_.currency1);
        if (face1_ == address(0)) face1_ = weth_;
    }

    function _push(Types.Plan memory plan_, Types.ActionKind kind_, bool zeroForOne_, uint256 amountIn_, int256 liquidityDelta_)
        private
        pure
    {
        Types.Action memory action_ = Types.Action(kind_, zeroForOne_, amountIn_, liquidityDelta_);
        if (plan_.actionCount == 0) plan_.actions[0] = action_;
        else if (plan_.actionCount == 1) plan_.actions[1] = action_;
        else plan_.actions[2] = action_;
        ++plan_.actionCount;
    }
}
