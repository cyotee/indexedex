// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {LiquidityMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityMath.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {UniswapV4ProtocolAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultMath as Math} from "./UniswapV4FullSpreadStandardExchangeVaultMath.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "./UniswapV4FullSpreadStandardExchangeVaultTypes.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV4FullSpreadStandardExchangeVaultRepo.sol";

/// @notice Position amounts and unpaid fees. Booked balances are not included.
library UniswapV4FullSpreadStandardExchangeVaultProjection {
    uint256 internal constant Q128 = 1 << 128;

    struct PositionRead {
        uint128 liquidity;
        uint160 sqrtPriceX96;
        int24 tick;
        uint160 sqrtA;
        uint160 sqrtB;
        uint256 amount0;
        uint256 amount1;
        uint256 fee0;
        uint256 fee1;
    }

    function read() internal view returns (PositionRead memory read_) {
        return read(poolState(UniswapV4ProtocolAwareRepo._poolManager(), UniswapV4SinglePositionAwareRepo._poolKey()));
    }

    function domain() internal view returns (bytes32) {
        UniswapV4SinglePositionAwareRepo.Storage storage position_ = UniswapV4SinglePositionAwareRepo._layoutStruct();
        return keccak256(abi.encode(
            "indexedex.uniswap.v4.fullSpread.quote", block.chainid, address(this),
            UniswapV4ProtocolAwareRepo._poolManager(), position_.poolKey,
            position_.tickLower, position_.tickUpper, position_.salt
        ));
    }

    function snapshot() internal view returns (Types.QuoteState memory state_) {
        state_ = poolState(UniswapV4ProtocolAwareRepo._poolManager(), UniswapV4SinglePositionAwareRepo._poolKey());
        state_.domain = domain();
        state_.version = 1;
        state_.booked[0] = Repo._booked(0);
        state_.booked[1] = Repo._booked(1);
        state_.supply = ERC20Repo._totalSupply();
        IVaultFeeOracleQuery oracle_ = IVaultFeeOracleQuery(address(StandardVaultRepo._feeOracle()));
        state_.feeTo = address(oracle_.feeTo());
        state_.usageFee = oracle_.usageFeeOfVault(address(this));
        if (state_.usageFee > Types.FEE_CAP) state_.usageFee = Types.FEE_CAP;
    }

    function poolState(IPoolManager manager_, PoolKey memory key_) internal view returns (Types.QuoteState memory state_) {
        UniswapV4SinglePositionAwareRepo.Storage storage position_ = UniswapV4SinglePositionAwareRepo._layoutStruct();
        (state_.sqrtPriceX96, state_.tick, state_.protocolFee, state_.lpFee) =
            StateLibrary.getSlot0(manager_, key_.toId());
        state_.poolLiquidity = StateLibrary.getLiquidity(manager_, key_.toId());
        (state_.positionLiquidity, state_.last[0], state_.last[1]) = StateLibrary.getPositionInfo(
            manager_, key_.toId(), address(this), position_.tickLower, position_.tickUpper, position_.salt
        );
        (state_.global[0], state_.global[1]) = StateLibrary.getFeeGrowthGlobals(manager_, key_.toId());
        (state_.lower.gross, state_.lower.net, state_.lower.outside0, state_.lower.outside1) =
            StateLibrary.getTickInfo(manager_, key_.toId(), position_.tickLower);
        (state_.upper.gross, state_.upper.net, state_.upper.outside0, state_.upper.outside1) =
            StateLibrary.getTickInfo(manager_, key_.toId(), position_.tickUpper);
    }

    function read(Types.QuoteState memory state_) internal view returns (PositionRead memory read_) {
        read_.liquidity = state_.positionLiquidity;
        read_.sqrtPriceX96 = state_.sqrtPriceX96;
        read_.tick = state_.tick;
        read_.sqrtA = TickMath.getSqrtPriceAtTick(UniswapV4SinglePositionAwareRepo._tickLower());
        read_.sqrtB = TickMath.getSqrtPriceAtTick(UniswapV4SinglePositionAwareRepo._tickUpper());
        (read_.amount0, read_.amount1) =
            Math.amountsForLiquidity(read_.sqrtPriceX96, read_.sqrtA, read_.sqrtB, read_.liquidity);
        if (read_.liquidity == 0) return read_;
        (uint256 inside0_, uint256 inside1_) = inside(state_);
        unchecked {
            read_.fee0 = FullMath.mulDiv(read_.liquidity, inside0_ - state_.last[0], Q128);
            read_.fee1 = FullMath.mulDiv(read_.liquidity, inside1_ - state_.last[1], Q128);
        }
    }

    function inside(Types.QuoteState memory state_) internal view returns (uint256 fee0_, uint256 fee1_) {
        unchecked {
            if (state_.tick < UniswapV4SinglePositionAwareRepo._tickLower()) {
                return (state_.lower.outside0 - state_.upper.outside0, state_.lower.outside1 - state_.upper.outside1);
            }
            if (state_.tick >= UniswapV4SinglePositionAwareRepo._tickUpper()) {
                return (state_.upper.outside0 - state_.lower.outside0, state_.upper.outside1 - state_.lower.outside1);
            }
            return (
                state_.global[0] - state_.lower.outside0 - state_.upper.outside0,
                state_.global[1] - state_.lower.outside1 - state_.upper.outside1
            );
        }
    }

    /// @dev Mirrors Pool.modifyLiquidity: initialize boundaries, settle old-position fees,
    /// checkpoint, then change liquidity and clear emptied boundaries.
    function modify(Types.QuoteState memory state_, int128 delta_)
        internal view returns (uint256 fee0_, uint256 fee1_)
    {
        int24 lower_ = UniswapV4SinglePositionAwareRepo._tickLower();
        int24 upper_ = UniswapV4SinglePositionAwareRepo._tickUpper();
        if (delta_ != 0) {
            _modifyTick(state_, state_.lower, lower_, delta_, false);
            _modifyTick(state_, state_.upper, upper_, delta_, true);
        }
        (uint256 inside0_, uint256 inside1_) = inside(state_);
        unchecked {
            fee0_ = FullMath.mulDiv(state_.positionLiquidity, inside0_ - state_.last[0], Q128);
            fee1_ = FullMath.mulDiv(state_.positionLiquidity, inside1_ - state_.last[1], Q128);
        }
        state_.last[0] = inside0_;
        state_.last[1] = inside1_;
        state_.positionLiquidity = LiquidityMath.addDelta(state_.positionLiquidity, delta_);
        if (state_.tick >= lower_ && state_.tick < upper_) {
            state_.poolLiquidity = LiquidityMath.addDelta(state_.poolLiquidity, delta_);
        }
        if (delta_ < 0) {
            if (state_.lower.gross == 0) delete state_.lower;
            if (state_.upper.gross == 0) delete state_.upper;
        }
    }

    function _modifyTick(
        Types.QuoteState memory state_, Types.QuoteTick memory boundary_, int24 tick_, int128 delta_, bool upper_
    ) private pure {
        if (boundary_.gross == 0 && tick_ <= state_.tick) {
            boundary_.outside0 = state_.global[0];
            boundary_.outside1 = state_.global[1];
        }
        boundary_.gross = LiquidityMath.addDelta(boundary_.gross, delta_);
        boundary_.net = upper_ ? boundary_.net - delta_ : boundary_.net + delta_;
    }
}
