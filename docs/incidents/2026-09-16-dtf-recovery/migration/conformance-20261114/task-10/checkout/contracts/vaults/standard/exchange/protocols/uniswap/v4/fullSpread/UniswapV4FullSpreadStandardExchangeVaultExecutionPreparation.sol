// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {UniswapV4ProtocolAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "./UniswapV4FullSpreadStandardExchangeVaultTypes.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV4FullSpreadStandardExchangeVaultRepo.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

/// @notice Per-action commitment and that action's settlement.
library UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation {
    using BetterSafeERC20 for IERC20;

    function payload(Types.Action memory action_) internal pure returns (bytes memory) {
        return abi.encode(uint8(action_.kind), action_.zeroForOne, action_.amountIn, action_.liquidityDelta);
    }

    function commit(bytes memory payload_) internal {
        Repo._layoutStruct().callbackHash = keccak256(payload_);
    }

    function consume(bytes memory payload_) internal {
        bytes32 expected_ = keccak256(payload_);
        Repo.Storage storage state_ = Repo._layoutStruct();
        if (expected_ == bytes32(0) || state_.callbackHash != expected_) revert IVault.SettlementMismatch();
        state_.callbackHash = bytes32(0);
    }

    function run(Types.Action memory action_) internal returns (uint256 fee0_, uint256 fee1_) {
        IPoolManager manager_ = UniswapV4ProtocolAwareRepo._poolManager();
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        if (action_.kind == Types.ActionKind.Swap) {
            if (action_.amountIn == 0) return (0, 0);
            manager_.swap(
                key_,
                SwapParams({
                    zeroForOne: action_.zeroForOne,
                    amountSpecified: -int256(action_.amountIn),
                    sqrtPriceLimitX96: action_.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                }),
                ""
            );
        } else if (action_.kind == Types.ActionKind.Modify) {
            (, BalanceDelta fees_) = manager_.modifyLiquidity(
                key_,
                ModifyLiquidityParams({
                    tickLower: UniswapV4SinglePositionAwareRepo._tickLower(),
                    tickUpper: UniswapV4SinglePositionAwareRepo._tickUpper(),
                    liquidityDelta: action_.liquidityDelta,
                    salt: UniswapV4SinglePositionAwareRepo._salt()
                }),
                ""
            );
            if (fees_.amount0() > 0) fee0_ = uint256(int256(fees_.amount0()));
            if (fees_.amount1() > 0) fee1_ = uint256(int256(fees_.amount1()));
        }
    }

    function settle() internal {
        IPoolManager manager_ = UniswapV4ProtocolAwareRepo._poolManager();
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        _settle(manager_, key_.currency0);
        _settle(manager_, key_.currency1);
    }

    function ownDeltasZero() internal view returns (bool) {
        IPoolManager manager_ = UniswapV4ProtocolAwareRepo._poolManager();
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        return TransientStateLibrary.currencyDelta(manager_, address(this), key_.currency0) == 0
            && TransientStateLibrary.currencyDelta(manager_, address(this), key_.currency1) == 0;
    }

    function _settle(IPoolManager manager_, Currency currency_) private {
        int256 delta_ = TransientStateLibrary.currencyDelta(manager_, address(this), currency_);
        if (delta_ == 0) return;
        address weth_ = address(WETHAwareRepo._weth());
        if (delta_ < 0) {
            uint256 debt_ = uint256(-delta_);
            if (Currency.unwrap(currency_) == address(0)) {
                IWETH(weth_).withdraw(debt_);
                manager_.sync(currency_);
                if (manager_.settle{value: debt_}() != debt_) revert IVault.SettlementMismatch();
            } else {
                manager_.sync(currency_);
                IERC20(Currency.unwrap(currency_)).safeTransfer(address(manager_), debt_);
                if (manager_.settle() != debt_) revert IVault.SettlementMismatch();
            }
        } else {
            manager_.take(currency_, address(this), uint256(delta_));
            if (Currency.unwrap(currency_) == address(0)) IWETH(weth_).deposit{value: uint256(delta_)}();
        }
        if (TransientStateLibrary.currencyDelta(manager_, address(this), currency_) != 0) revert IVault.SettlementMismatch();
    }
}
