// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {LiquidityMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/LiquidityMath.sol";
import {UniswapV3FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV3FullSpreadStandardExchangeVaultRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo as PoolRepo} from "./UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultMath as Math} from "./UniswapV3FullSpreadStandardExchangeVaultMath.sol";

/// @notice One read-only sizing engine shared by execution and every supported preview.
/// @dev Funding, deadlines, authorization, disable and pool-lock checks belong to execution.
/// A plan must be executed against the state it reads, before unrelated pool actions.
library UniswapV3FullSpreadStandardExchangeVaultPlanner {
    enum Kind {
        Unsupported,
        PassThrough,
        OneSidedMint,
        BundleMint,
        OneTokenExit,
        BundleExit,
        Donate,
        Compound
    }

    /// @dev used0/1 are mint callback debts, not combined swap-plus-mint spending.
    /// swapIn is the original pool.swap amountSpecified; swapSpent is its quoted
    /// consumption. They differ only on a partial pass-through. Deposit execution
    /// swaps first, then snapshots/collects/books old-position fees, then mints.
    /// Exit fee claims/remainders are pre-burn snapshots and must not be counted
    /// again from collect's combined principal-plus-fee transfer.
    /// Maintenance refund0/1 describe eligible remainders to BOOK, never user refunds.
    struct Plan {
        Kind kind;
        bool failed;
        bool mintFloor;
        bool zeroForOne;
        bool emitDonation;
        bool emitCompounded;
        uint128 liquidityAdded;
        uint128 liquidityRemoved;
        uint256 amountOut;
        uint256 amountRefunded;
        uint256 grossShares;
        uint256 netShares;
        uint256 feeShares;
        uint256 floorShares;
        uint256 sharesBurned;
        address feeTo;
        uint256 swapIn;
        uint256 swapSpent;
        uint256 swapOut;
        uint256 used0;
        uint256 used1;
        uint256 refund0;
        uint256 refund1;
        uint256 out0;
        uint256 out1;
        uint256 feeClaim0;
        uint256 feeClaim1;
        uint256 feeRemainder0;
        uint256 feeRemainder1;
        uint256 bookedClaim0;
        uint256 bookedClaim1;
    }

    /// @dev Principal and unpaid fees only; booked and stray custody are absent.
    /// Header and optional endpoint reads belong only to this planner invocation.
    struct PositionRead {
        uint160 sqrtPriceX96;
        uint160 sqrtA;
        uint160 sqrtB;
        int24 tick;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint128 activeLiquidity;
        uint256 principal0;
        uint256 principal1;
        uint256 fee0;
        uint256 fee1;
        uint8 protocolFee;
        bool endpointGrossRead;
        uint128 lowerGross;
        uint128 upperGross;
        uint256 growthSinceLast0;
        uint256 growthSinceLast1;
        uint128 owed0;
        uint128 owed1;
    }

    /// @dev The pool's external positions stay live; only this vault's cumulative
    /// liquidity change is overlaid on their tick bitmap and liquidity nets.
    struct State {
        address vault;
        address pool;
        uint256 version;
        uint256 chainId;
        PositionRead position;
        uint128 initialLiquidity;
        uint256 supply;
        uint256 booked0;
        uint256 booked1;
    }

    function capture() public view returns (bytes memory) {
        return abi.encode(_snapshot());
    }

    function projectedSupply(bytes memory encoded_) public view returns (uint256) {
        return _decode(encoded_).supply;
    }

    function quote(bytes memory encoded_, address tokenIn_, uint256 amountIn_, address tokenOut_)
        public view returns (bytes memory next_, uint256 amountOut_, uint256 amountRefunded_)
    {
        State memory state_ = _decode(encoded_);
        if (amountIn_ == 0) return (encoded_, 0, 0);
        Plan memory plan_ = _planIn(state_, tokenIn_, amountIn_, tokenOut_);
        amountRefunded_ = plan_.amountRefunded;
        if (plan_.failed || plan_.kind == Kind.Unsupported) return (encoded_, 0, amountRefunded_);
        amountOut_ = plan_.amountOut;
        if (plan_.kind == Kind.OneTokenExit) {
            state_.booked0 = state_.booked0 - plan_.bookedClaim0 + plan_.feeRemainder0;
            state_.booked1 = state_.booked1 - plan_.bookedClaim1 + plan_.feeRemainder1;
            _resetFees(state_.position);
            _changePosition(state_.position, -int128(plan_.liquidityRemoved));
            state_.supply -= plan_.sharesBurned;
        }
        if (plan_.swapIn != 0) _applySwap(state_, plan_.swapIn, plan_.zeroForOne);
        if (plan_.kind == Kind.OneSidedMint && plan_.liquidityAdded != 0) {
            // Execution collects the incumbent position's fees AFTER the entry swap.
            state_.booked0 += state_.position.fee0;
            state_.booked1 += state_.position.fee1;
            _resetFees(state_.position);
            _changePosition(state_.position, int128(plan_.liquidityAdded));
            state_.supply += plan_.netShares + plan_.feeShares + plan_.floorShares;
        }
        (state_.position.principal0, state_.position.principal1) = Math.amountsForLiquidity(
            state_.position.sqrtPriceX96, state_.position.sqrtA, state_.position.sqrtB, state_.position.liquidity
        );
        return (abi.encode(state_), amountOut_, amountRefunded_);
    }

    function _snapshot() private view returns (State memory) {
        return _fromPosition(readPosition());
    }

    function _fromPosition(PositionRead memory position_) private view returns (State memory state_) {
        IUniswapV3Pool pool_ = PoolRepo._uniswapV3Pool();
        state_.vault = address(this);
        state_.pool = address(pool_);
        state_.version = 1;
        state_.chainId = block.chainid;
        if (!position_.endpointGrossRead) {
            (position_.lowerGross,,,,,,,) = pool_.ticks(position_.tickLower);
            (position_.upperGross,,,,,,,) = pool_.ticks(position_.tickUpper);
            position_.endpointGrossRead = true;
        }
        state_.position = position_;
        state_.initialLiquidity = position_.liquidity;
        state_.supply = ERC20Repo._totalSupply();
        state_.booked0 = Repo._layout().booked[0];
        state_.booked1 = Repo._layout().booked[1];
    }

    function _decode(bytes memory encoded_) private view returns (State memory state_) {
        // State v1 contains 28 static ABI words, including the position snapshot.
        if (encoded_.length != 28 * 32) revert IStandardExchangeStateQuote.InvalidQuoteState();
        state_ = abi.decode(encoded_, (State));
        IUniswapV3Pool pool_ = PoolRepo._uniswapV3Pool();
        int24 lower_;
        int24 upper_;
        if (Repo._isPositionCreated()) (lower_, upper_) = Repo._getPositionTicks();
        else {
            int24 spacing_ = pool_.tickSpacing();
            lower_ = TickMath.minUsableTick(spacing_);
            upper_ = TickMath.maxUsableTick(spacing_);
        }
        PositionRead memory position_ = state_.position;
        if (
            state_.vault != address(this) || state_.pool != address(pool_) || state_.version != 1
                || state_.chainId != block.chainid
                || position_.tickLower != lower_ || position_.tickUpper != upper_
                || position_.sqrtA != TickMath.getSqrtRatioAtTick(lower_)
                || position_.sqrtB != TickMath.getSqrtRatioAtTick(upper_)
                || position_.sqrtPriceX96 < TickMath.MIN_SQRT_RATIO
                || position_.sqrtPriceX96 >= TickMath.MAX_SQRT_RATIO
                || state_.supply > position_.liquidity || !position_.endpointGrossRead
                || position_.lowerGross < position_.liquidity || position_.upperGross < position_.liquidity
        ) revert IStandardExchangeStateQuote.InvalidQuoteState();
    }

    function _resetFees(PositionRead memory position_) private pure {
        position_.fee0 = 0;
        position_.fee1 = 0;
        position_.owed0 = 0;
        position_.owed1 = 0;
        position_.growthSinceLast0 = 0;
        position_.growthSinceLast1 = 0;
    }

    function _changePosition(PositionRead memory position_, int128 delta_) private pure {
        position_.liquidity = LiquidityMath.addDelta(position_.liquidity, delta_);
        position_.lowerGross = LiquidityMath.addDelta(position_.lowerGross, delta_);
        position_.upperGross = LiquidityMath.addDelta(position_.upperGross, delta_);
        if (position_.tick >= position_.tickLower && position_.tick < position_.tickUpper) {
            position_.activeLiquidity = LiquidityMath.addDelta(position_.activeLiquidity, delta_);
        }
    }

    function _applySwap(State memory state_, uint256 amount_, bool zeroForOne_) private view {
        (UniswapV3Quoter.SwapQuoteResult memory swap_, uint256 growth_) =
            _quote(amount_, zeroForOne_, state_, 0, true);
        PositionRead memory position_ = state_.position;
        position_.sqrtPriceX96 = swap_.sqrtPriceAfterX96;
        position_.tick = swap_.tickAfter;
        position_.activeLiquidity = swap_.liquidityAfter;
        unchecked {
            if (zeroForOne_) position_.growthSinceLast0 += growth_;
            else position_.growthSinceLast1 += growth_;
        }
        // Retain raw growth across swaps: rounding each swap's token fee separately
        // would lose the fractions that Position.update credits at the next touch.
        position_.fee0 = position_.owed0
            + uint128(FullMath.mulDiv(position_.growthSinceLast0, position_.liquidity, FixedPoint128.Q128));
        position_.fee1 = position_.owed1
            + uint128(FullMath.mulDiv(position_.growthSinceLast1, position_.liquidity, FixedPoint128.Q128));
    }

    /// @notice Plan a one-token mint, caller-owned share exit, or underlying pass-through.
    /// @dev amountIn is already resolved funding, not a request to use all held tokens.
    function planIn(address tokenIn_, uint256 amountIn_, address tokenOut_)
        internal
        view
        returns (Plan memory plan_)
    {
        if (tokenIn_ == tokenOut_ || tokenIn_ == address(0) || tokenOut_ == address(0)) return plan_;
        IUniswapV3Pool pool_ = PoolRepo._uniswapV3Pool();
        address token0_ = pool_.token0();
        address token1_ = pool_.token1();
        if (
            (tokenIn_ != address(this) && tokenIn_ != token0_ && tokenIn_ != token1_)
                || (tokenOut_ != address(this) && tokenOut_ != token0_ && tokenOut_ != token1_)
        ) return plan_;
        return _planIn(_snapshot(), tokenIn_, amountIn_, tokenOut_);
    }

    function _planIn(State memory state_, address tokenIn_, uint256 amountIn_, address tokenOut_)
        private view returns (Plan memory plan_)
    {
        if (tokenIn_ == tokenOut_ || tokenIn_ == address(0) || tokenOut_ == address(0)) return plan_;
        IUniswapV3Pool pool_ = PoolRepo._uniswapV3Pool();
        address token0_ = pool_.token0();
        address token1_ = pool_.token1();
        if (tokenIn_ == address(this) && (tokenOut_ == token0_ || tokenOut_ == token1_)) {
            return _exit(amountIn_, tokenOut_ == token0_, state_);
        }
        if (tokenOut_ == address(this) && (tokenIn_ == token0_ || tokenIn_ == token1_)) {
            return _mintOne(amountIn_, tokenIn_ == token0_, state_);
        }
        if ((tokenIn_ == token0_ || tokenIn_ == token1_) && (tokenOut_ == token0_ || tokenOut_ == token1_)) {
            return _pass(amountIn_, tokenIn_ == token0_, state_);
        }
    }

    /// @notice Proportional no-swap mint, also used for source-NFT proceeds on import.
    function planBundleIn(uint256 amount0_, uint256 amount1_) internal view returns (Plan memory plan_) {
        PositionRead memory position_ = readPosition();
        return _bundleIn(amount0_, amount1_, position_, _capacity(position_));
    }

    /// @notice Preview the same proportional mint after removing the source NFT.
    /// @dev Source ticks/liquidity must come from a validated NFT in the bound pool.
    /// Its burn frees matching endpoint capacity but changes neither price nor the
    /// vault-owned position's liquidity or supply. Execution calls planBundleIn
    /// after the actual source burn and collection, using the same mint engine.
    function planImport(
        uint256 amount0_,
        uint256 amount1_,
        int24 sourceLower_,
        int24 sourceUpper_,
        uint128 sourceLiquidity_
    ) internal view returns (Plan memory plan_) {
        PositionRead memory position_ = readPosition();
        return _bundleIn(
            amount0_,
            amount1_,
            position_,
            _capacity(position_, sourceLower_, sourceUpper_, sourceLiquidity_)
        );
    }

    /// @notice Exact-share exit paying each token's floored principal, fee and booked claims.
    /// @dev A liquidity removal rounded to zero can still have a nonzero fee/booked claim.
    function planBundleOut(uint256 shares_) internal view returns (Plan memory plan_) {
        plan_.kind = Kind.BundleExit;
        _claims(plan_, readPosition(), shares_);
    }

    /// @notice Process fees + booked balances + directed donation, never unrelated custody.
    /// @dev Call before collecting fees, or after collected fees have been added to booked.
    /// Supply must already exist. This plan never issues shares, including a genesis floor.
    function planMaintenance(uint256 donate0_, uint256 donate1_, bool donation_)
        internal
        view
        returns (Plan memory plan_)
    {
        plan_.kind = donation_ ? Kind.Donate : Kind.Compound;
        if (ERC20Repo._totalSupply() == 0) {
            plan_.failed = donation_;
            return plan_;
        }
        plan_.emitDonation = donation_;
        PositionRead memory position_ = readPosition();
        uint256 existing0_ = Repo._layout().booked[0] + position_.fee0;
        uint256 existing1_ = Repo._layout().booked[1] + position_.fee1;
        uint256 have0_ = existing0_ + donate0_;
        uint256 have1_ = existing1_ + donate1_;
        if (have0_ == 0 && have1_ == 0) return plan_;
        if (have0_ != 0 && have1_ != 0) {
            (plan_.liquidityAdded, plan_.used0, plan_.used1) = Math.proportional(
                position_.sqrtPriceX96, position_.sqrtA, position_.sqrtB, have0_, have1_, _capacity(position_)
            );
            plan_.refund0 = have0_ - plan_.used0;
            plan_.refund1 = have1_ - plan_.used1;
        } else {
            bool zeroForOne_ = have0_ != 0;
            _setSized(plan_, _size(zeroForOne_ ? have0_ : have1_, zeroForOne_, position_), zeroForOne_);
        }
        plan_.emitCompounded = plan_.liquidityAdded != 0 && (existing0_ != 0 || existing1_ != 0);
    }

    /// @notice Read the fixed full-range position, rounded-down principal and collectable fees.
    /// @dev Read again AFTER a deposit swap and BEFORE minting to book incumbent fees.
    /// Stored owed balances are fees only at route boundaries: execution must collect
    /// burn principal within the same operation before another boundary read.
    function readPosition() internal view returns (PositionRead memory position_) {
        IUniswapV3Pool pool_ = PoolRepo._uniswapV3Pool();
        (position_.sqrtPriceX96, position_.tick,,,, position_.protocolFee,) = pool_.slot0();
        position_.activeLiquidity = pool_.liquidity();
        if (Repo._isPositionCreated()) {
            (position_.tickLower, position_.tickUpper) = Repo._getPositionTicks();
        } else {
            int24 spacing_ = pool_.tickSpacing();
            position_.tickLower = TickMath.minUsableTick(spacing_);
            position_.tickUpper = TickMath.maxUsableTick(spacing_);
        }
        position_.sqrtA = TickMath.getSqrtRatioAtTick(position_.tickLower);
        position_.sqrtB = TickMath.getSqrtRatioAtTick(position_.tickUpper);
        if (!Repo._isPositionCreated()) return position_;
        uint256 last0_;
        uint256 last1_;
        uint128 owed0_;
        uint128 owed1_;
        (position_.liquidity, last0_, last1_, owed0_, owed1_) =
            pool_.positions(Repo._getPositionKey(address(this), position_.tickLower, position_.tickUpper));
        position_.owed0 = owed0_;
        position_.owed1 = owed1_;
        (position_.principal0, position_.principal1) =
            Math.amountsForLiquidity(position_.sqrtPriceX96, position_.sqrtA, position_.sqrtB, position_.liquidity);
        position_.fee0 = owed0_;
        position_.fee1 = owed1_;
        if (position_.liquidity == 0) return position_;
        uint256 growth0_;
        uint256 growth1_;
        (growth0_, growth1_, position_.lowerGross, position_.upperGross) =
            _feesInside(pool_, position_.tick, position_.tickLower, position_.tickUpper);
        position_.endpointGrossRead = true;
        uint128 accrued0_;
        uint128 accrued1_;
        unchecked {
            position_.growthSinceLast0 = growth0_ - last0_;
            position_.growthSinceLast1 = growth1_ - last1_;
            accrued0_ = uint128(FullMath.mulDiv(position_.growthSinceLast0, position_.liquidity, FixedPoint128.Q128));
            accrued1_ = uint128(FullMath.mulDiv(position_.growthSinceLast1, position_.liquidity, FixedPoint128.Q128));
        }
        // Match Position.update's uint128 credits and checked stored-owed addition.
        position_.fee0 = owed0_ + accrued0_;
        position_.fee1 = owed1_ + accrued1_;
    }

    /// @notice Bound-pool fee growth INSIDE arbitrary NFT ticks, in Q128 units.
    /// @dev This is growth, not a token claim. Import applies the NFT's last-growth
    /// checkpoint, liquidity and tokensOwed. Arithmetic follows canonical Tick.
    function feesInside(int24 lower_, int24 upper_) internal view returns (uint256 growth0_, uint256 growth1_) {
        IUniswapV3Pool pool_ = PoolRepo._uniswapV3Pool();
        (, int24 tick_,,,,,) = pool_.slot0();
        (growth0_, growth1_,,) = _feesInside(pool_, tick_, lower_, upper_);
    }

    /// @dev Reuse the current header, retaining gross values from the required fee reads.
    function _feesInside(IUniswapV3Pool pool_, int24 tick_, int24 lower_, int24 upper_)
        private view returns (uint256 growth0_, uint256 growth1_, uint128 lowerGross_, uint128 upperGross_)
    {
        uint256 lower0_;
        uint256 lower1_;
        uint256 upper0_;
        uint256 upper1_;
        (lowerGross_,, lower0_, lower1_,,,,) = pool_.ticks(lower_);
        (upperGross_,, upper0_, upper1_,,,,) = pool_.ticks(upper_);
        unchecked {
            if (tick_ < lower_) {
                growth0_ = lower0_ - upper0_;
                growth1_ = lower1_ - upper1_;
            } else if (tick_ < upper_) {
                growth0_ = pool_.feeGrowthGlobal0X128() - lower0_ - upper0_;
                growth1_ = pool_.feeGrowthGlobal1X128() - lower1_ - upper1_;
            } else {
                growth0_ = upper0_ - lower0_;
                growth1_ = upper1_ - lower1_;
            }
        }
    }

    function _mintOne(uint256 amount_, bool zeroForOne_, State memory state_) private view returns (Plan memory plan_) {
        plan_.kind = Kind.OneSidedMint;
        _setSized(plan_, _size(amount_, zeroForOne_, state_), zeroForOne_);
        _shares(plan_, state_.position.liquidity, state_.supply);
    }

    function _bundleIn(uint256 amount0_, uint256 amount1_, PositionRead memory position_, uint128 capacity_)
        private
        view
        returns (Plan memory plan_)
    {
        plan_.kind = Kind.BundleMint;
        (plan_.liquidityAdded, plan_.used0, plan_.used1) = Math.proportional(
            position_.sqrtPriceX96, position_.sqrtA, position_.sqrtB, amount0_, amount1_, capacity_
        );
        plan_.refund0 = amount0_ - plan_.used0;
        plan_.refund1 = amount1_ - plan_.used1;
        _shares(plan_, position_.liquidity);
    }

    function _pass(uint256 amount_, bool zeroForOne_, State memory state_) private view returns (Plan memory plan_) {
        plan_.kind = Kind.PassThrough;
        plan_.zeroForOne = zeroForOne_;
        (UniswapV3Quoter.SwapQuoteResult memory quote_,) = _quote(amount_, zeroForOne_, state_, 0, false);
        if (quote_.amountOut == 0) {
            plan_.failed = true;
            plan_.amountRefunded = amount_;
        } else {
            // Re-quoting quote_.amountIn instead can change the final tick/rounding.
            plan_.swapIn = amount_;
            plan_.swapSpent = quote_.amountIn;
            plan_.swapOut = quote_.amountOut;
            plan_.amountOut = quote_.amountOut;
            plan_.amountRefunded = amount_ - quote_.amountIn;
            if (zeroForOne_) plan_.out1 = quote_.amountOut;
            else plan_.out0 = quote_.amountOut;
        }
        if (zeroForOne_) plan_.refund0 = plan_.amountRefunded;
        else plan_.refund1 = plan_.amountRefunded;
    }

    function _exit(uint256 shares_, bool want0_, State memory state_) private view returns (Plan memory plan_) {
        plan_.kind = Kind.OneTokenExit;
        plan_.zeroForOne = !want0_;
        _claims(plan_, state_, shares_);
        if (plan_.failed) return plan_;
        uint256 unwanted_ = want0_ ? plan_.out1 : plan_.out0;
        uint256 wanted_ = want0_ ? plan_.out0 : plan_.out1;
        plan_.out0 = 0;
        plan_.out1 = 0;
        if (unwanted_ != 0) {
            (UniswapV3Quoter.SwapQuoteResult memory quote_,) =
                _quote(unwanted_, !want0_, state_, plan_.liquidityRemoved, false);
            if (!quote_.fullyFilled || quote_.amountIn != unwanted_) {
                plan_.failed = true;
                return plan_;
            }
            plan_.swapIn = unwanted_;
            plan_.swapSpent = unwanted_;
            plan_.swapOut = quote_.amountOut;
        }
        plan_.amountOut = wanted_ + plan_.swapOut;
        if (want0_) plan_.out0 = plan_.amountOut;
        else plan_.out1 = plan_.amountOut;
    }

    function _claims(Plan memory plan_, PositionRead memory position_, uint256 shares_) private view {
        _claims(plan_, _fromPosition(position_), shares_);
    }

    function _claims(Plan memory plan_, State memory state_, uint256 shares_) private pure {
        PositionRead memory position_ = state_.position;
        plan_.sharesBurned = shares_;
        uint256 supply_ = state_.supply;
        if (supply_ == 0 || shares_ > supply_) {
            plan_.failed = true;
            return;
        }
        plan_.liquidityRemoved = uint128(Math.claim(position_.liquidity, shares_, supply_));
        plan_.feeClaim0 = Math.claim(position_.fee0, shares_, supply_);
        plan_.feeClaim1 = Math.claim(position_.fee1, shares_, supply_);
        plan_.feeRemainder0 = position_.fee0 - plan_.feeClaim0;
        plan_.feeRemainder1 = position_.fee1 - plan_.feeClaim1;
        plan_.bookedClaim0 = Math.claim(state_.booked0, shares_, supply_);
        plan_.bookedClaim1 = Math.claim(state_.booked1, shares_, supply_);
        (uint256 principal0_, uint256 principal1_) = Math.amountsForLiquidity(
            position_.sqrtPriceX96, position_.sqrtA, position_.sqrtB, plan_.liquidityRemoved
        );
        // burn credits principal into the same uint128 owed counters as fees.
        // A receipt that cannot survive that credit/collect boundary is not payable.
        if (
            principal0_ > type(uint128).max - position_.fee0
                || principal1_ > type(uint128).max - position_.fee1
        ) {
            plan_.failed = true;
            return;
        }
        plan_.out0 = principal0_ + plan_.feeClaim0 + plan_.bookedClaim0;
        plan_.out1 = principal1_ + plan_.feeClaim1 + plan_.bookedClaim1;
    }

    function _size(uint256 amount_, bool zeroForOne_, PositionRead memory position_)
        private
        view
        returns (Math.Sized memory sized_)
    {
        return _size(amount_, zeroForOne_, _fromPosition(position_));
    }

    function _size(uint256 amount_, bool zeroForOne_, State memory state_)
        private view returns (Math.Sized memory sized_)
    {
        PositionRead memory position_ = state_.position;
        sized_.remainder = amount_;
        if (amount_ == 0 || position_.sqrtPriceX96 == 0) return sized_;
        uint128 capacity_ = _capacity(position_);
        if (position_.sqrtPriceX96 <= position_.sqrtA || position_.sqrtPriceX96 >= position_.sqrtB) {
            return Math.singleTokenAdd(
                amount_, zeroForOne_, position_.sqrtPriceX96, position_.sqrtA, position_.sqrtB, capacity_
            );
        }
        if (position_.activeLiquidity == 0 || capacity_ == 0) return sized_;
        uint256 swapIn_ = FullMath.mulDiv(amount_, 49, 100);
        if (swapIn_ == 0) return sized_;
        (UniswapV3Quoter.SwapQuoteResult memory quote_,) = _quote(swapIn_, zeroForOne_, state_, 0, false);
        if (!quote_.fullyFilled || quote_.amountIn != swapIn_ || quote_.amountOut == 0) return sized_;
        return Math.sizeOneSided(
            amount_, zeroForOne_, swapIn_, quote_.amountOut,
            quote_.sqrtPriceAfterX96, position_.sqrtA, position_.sqrtB, capacity_
        );
    }

    function _setSized(Plan memory plan_, Math.Sized memory sized_, bool zeroForOne_) private pure {
        plan_.zeroForOne = zeroForOne_;
        plan_.liquidityAdded = sized_.liquidity;
        plan_.used0 = sized_.used0;
        plan_.used1 = sized_.used1;
        plan_.swapIn = sized_.swapIn;
        plan_.swapSpent = sized_.swapIn;
        plan_.swapOut = sized_.swapOut;
        plan_.amountRefunded = sized_.remainder;
        if (zeroForOne_) plan_.refund0 = sized_.remainder;
        else plan_.refund1 = sized_.remainder;
    }

    function _shares(Plan memory plan_, uint128 liquidityBefore_) private view {
        _shares(plan_, liquidityBefore_, ERC20Repo._totalSupply());
    }

    function _shares(Plan memory plan_, uint128 liquidityBefore_, uint256 supply_) private view {
        (plan_.grossShares, plan_.failed) = Math.grossShares(plan_.liquidityAdded, supply_, liquidityBefore_);
        if (plan_.failed || (supply_ != 0 && plan_.liquidityAdded == 0)) return;
        if (supply_ == 0) {
            plan_.mintFloor = true;
            plan_.floorShares = Math.MIN_SHARES;
        }
        IVaultFeeOracleQuery oracle_ = StandardVaultRepo._feeOracle();
        plan_.feeTo = address(oracle_.feeTo());
        (plan_.feeShares, plan_.netShares) =
            Math.netShares(plan_.grossShares, oracle_.usageFeeOfVault(address(this)), plan_.feeTo);
        plan_.amountOut = plan_.netShares;
    }

    /// @dev The endpoint cap is unchanged by swaps and collection. Pool.mint also
    /// requires a signed-int128 delta; bound the plan before any narrowing cast.
    function _capacity(PositionRead memory position_) private view returns (uint128 capacity_) {
        return _capacity(position_, 0, 0, 0);
    }

    function _capacity(
        PositionRead memory position_,
        int24 sourceLower_,
        int24 sourceUpper_,
        uint128 sourceLiquidity_
    ) private view returns (uint128 capacity_) {
        IUniswapV3Pool pool_ = PoolRepo._uniswapV3Pool();
        uint128 lowerGross_ = position_.lowerGross;
        uint128 upperGross_ = position_.upperGross;
        if (!position_.endpointGrossRead) {
            (lowerGross_,,,,,,,) = pool_.ticks(position_.tickLower);
            (upperGross_,,,,,,,) = pool_.ticks(position_.tickUpper);
        }
        if (position_.tickLower == sourceLower_ || position_.tickLower == sourceUpper_) {
            lowerGross_ -= sourceLiquidity_;
        }
        if (position_.tickUpper == sourceLower_ || position_.tickUpper == sourceUpper_) {
            upperGross_ -= sourceLiquidity_;
        }
        uint128 max_ = pool_.maxLiquidityPerTick();
        capacity_ = max_ - (lowerGross_ > upperGross_ ? lowerGross_ : upperGross_);
        if (capacity_ > uint128(type(int128).max)) capacity_ = uint128(type(int128).max);
    }

    /// @dev Canonical unrestricted tick walk. Neither unlocked nor disable is read.
    /// A zero result represents an invalid amount/price limit. An exit projects the
    /// burn into active liquidity, endpoint liquidityNet and endpoint bitmap bits.
    function _quote(uint256 amount_, bool zeroForOne_, State memory state_, uint128 removed_, bool trackFees_)
        private
        view
        returns (UniswapV3Quoter.SwapQuoteResult memory quote_, uint256 growth_)
    {
        PositionRead memory position_ = state_.position;
        uint160 limit_ = zeroForOne_ ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        if (
            amount_ == 0 || amount_ > uint256(type(int256).max) || position_.sqrtPriceX96 == 0
                || (zeroForOne_ ? position_.sqrtPriceX96 <= limit_ : position_.sqrtPriceX96 >= limit_)
                || removed_ > uint128(type(int128).max)
        ) return (quote_, 0);
        UniswapV3Quoter.SwapQuoteParams memory params_ = UniswapV3Quoter.SwapQuoteParams({
            pool: PoolRepo._uniswapV3Pool(),
            zeroForOne: zeroForOne_,
            amount: amount_,
            sqrtPriceLimitX96: limit_,
            maxSteps: 0
        });
        int128 existingDelta_ = int128(int256(uint256(position_.liquidity)) - int256(uint256(state_.initialLiquidity)));
        UniswapV3Quoter.LiquidityChange memory change_ = UniswapV3Quoter.LiquidityChange({
            tickLower: position_.tickLower,
            tickUpper: position_.tickUpper,
            liquidityDelta: existingDelta_ - int128(removed_)
        });
        uint128 baseActive_ = position_.activeLiquidity;
        if (position_.tick >= position_.tickLower && position_.tick < position_.tickUpper) {
            // quoteFromHeader applies the full cumulative overlay exactly once.
            baseActive_ = LiquidityMath.addDelta(baseActive_, -existingDelta_);
        }
        return UniswapV3Quoter.quoteFromHeader(
            params_,
            true,
            change_,
            UniswapV3Quoter.PoolHeader(
                position_.sqrtPriceX96, position_.tick, baseActive_, position_.protocolFee
            ),
            trackFees_
        );
    }
}
