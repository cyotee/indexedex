// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponentBindings} from "./UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers} from "./UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol";
import {UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers} from "./UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol";
import {UniswapV4FullSpreadStandardExchangeVaultExecution as Execution} from "./UniswapV4FullSpreadStandardExchangeVaultExecution.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {
    IStandardExchangeBundleIn,
    IStandardExchangeBundleOut
} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV4FullSpreadStandardExchangeVaultMoneyTarget is
    UniswapV4FullSpreadStandardExchangeVaultComponentBindings,
    UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers,
    UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers
{
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded) {
        _deadline(deadline);
        address in_ = tokenIn;
        address out_ = tokenOut;
        bool withdrawal_ = in_ == address(this) && _isFace(out_);
        _disable(withdrawal_);
        if (in_ == out_) revert IVault.InvalidRoute();
        if (amountIn == 0) revert IVault.EmptyExchange();
        if (!_known(in_) || !_known(out_)) revert IVault.TokenNotExchangeable();
        if (recipient == address(0) || recipient == address(this)) revert IVault.InvalidRecipient();
        if (pretransferred && msg.sender.code.length == 0) revert ISecurePullErrors.EOAPretransferNotAllowed();
        return Execution.exchangeIn(in_, amountIn, out_, minAmountOut, recipient, pretransferred);
    }

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded) {
        _deadline(deadline);
        _disable(false);
        (address face0_, address face1_) = _faces();
        if (amountsIn.length != 2) revert IStandardExchangeBundleIn.AmountsLengthMismatch();
        if (tokenOut != address(this)) revert IStandardExchangeBundleIn.ExchangeBundleInForSingleOutNotAvailable();
        if (recipient == address(0) || recipient == address(this)) revert IVault.InvalidRecipient();
        if (pretransferred && msg.sender.code.length == 0) revert ISecurePullErrors.EOAPretransferNotAllowed();
        (uint256 out_, uint256 refund0_, uint256 refund1_) =
            Execution.bundleIn(amountsIn[0], amountsIn[1], minAmountOut, recipient, pretransferred);
        amountsRefunded = new uint256[](2);
        amountsRefunded[0] = refund0_;
        amountsRefunded[1] = refund1_;
        amountOut = out_;
        face0_;
        face1_;
    }

    function exchangeBundleOut(
        address tokenIn,
        uint256 amountIn,
        address[] calldata tokensOut,
        uint256[] calldata minAmountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut, uint256 amountRefunded) {
        _deadline(deadline);
        (address face0_, address face1_) = _faces();
        bool withdrawal_ = tokenIn == address(this) && _facesInEitherOrder(tokensOut, face0_, face1_);
        _disable(withdrawal_);
        if (tokensOut.length != 2 || minAmountsOut.length != 2) revert IStandardExchangeBundleOut.TokenAmountsLengthMismatch();
        if (tokensOut[0] == tokensOut[1]) revert IStandardExchangeBundleOut.DuplicateOutput();
        if (tokenIn == tokensOut[0] || tokenIn == tokensOut[1] || !withdrawal_) {
            revert IStandardExchangeBundleOut.ExchangeBundleOutNotAvailable();
        }
        if (recipient == address(0) || recipient == address(this)) revert IVault.InvalidRecipient();
        if (pretransferred && msg.sender.code.length == 0) revert ISecurePullErrors.EOAPretransferNotAllowed();
        (uint256 min0_, uint256 min1_) = tokensOut[0] == face0_
            ? (minAmountsOut[0], minAmountsOut[1])
            : (minAmountsOut[1], minAmountsOut[0]);
        uint256 index0_ = tokensOut[0] == face0_ ? 0 : 1;
        (uint256 out0_, uint256 out1_) = Execution.bundleOut(amountIn, recipient, min0_, min1_, index0_, 1 - index0_);
        amountsOut = new uint256[](2);
        if (tokensOut[0] == face0_) {
            amountsOut[0] = out0_;
            amountsOut[1] = out1_;
        } else {
            amountsOut[0] = out1_;
            amountsOut[1] = out0_;
        }
    }

    function donate(address token, uint256 amount, bool pretransferred)
        external
        onlyLiveFeeToOwnerOrOperator
    {
        if (token != address(this) && !_isFace(token)) revert IVault.TokenNotExchangeable();
        if (pretransferred && msg.sender.code.length == 0) revert ISecurePullErrors.EOAPretransferNotAllowed();
        Execution.maintain(token, amount, pretransferred, true);
    }

    function compound() external onlyLiveFeeToOwnerOrOperator {
        Execution.maintain(address(0), 0, false, false);
    }

    function setOperator(address operator, bool status) external onlyLiveFeeToOwner returns (bool) {
        Execution.appoint(operator, status);
        return true;
    }

    function setOperatorFor(bytes4 func, address operator, bool status) external onlyLiveFeeToOwner returns (bool) {
        Execution.appointFor(func, operator, status);
        return true;
    }

    function _deadline(uint256 deadline_) internal view {
        if (block.timestamp > deadline_) revert IStandardExchangeErrors.DeadlineExceeded(deadline_, block.timestamp);
    }

    function _disable(bool allowed_) internal view {
        if (allowed_) return;
        if (IVaultRegistryDisableQuery(address(StandardVaultRepo._feeOracle())).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function _known(address token_) internal view returns (bool) {
        return token_ == address(this) || _isFace(token_);
    }

    function _isFace(address token_) internal view returns (bool) {
        (address face0_, address face1_) = _faces();
        return token_ == face0_ || token_ == face1_;
    }

    function _faces() internal view returns (address face0_, address face1_) {
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        address weth_ = address(WETHAwareRepo._weth());
        face0_ = Currency.unwrap(key_.currency0);
        if (face0_ == address(0)) face0_ = weth_;
        face1_ = Currency.unwrap(key_.currency1);
        if (face1_ == address(0)) face1_ = weth_;
    }

    function _facesInEitherOrder(address[] calldata tokens_, address face0_, address face1_) internal pure returns (bool) {
        if (tokens_.length != 2) return false;
        return (tokens_[0] == face0_ && tokens_[1] == face1_) || (tokens_[0] == face1_ && tokens_[1] == face0_);
    }
}
