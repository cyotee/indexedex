// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {UniswapV4BufferHookLiquidityExecutionBase} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityExecutionBase.sol";
import {UniswapV4HookOwnerOnlyLiquidityLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib as PullLib} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib as Withdrawal} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol";

abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookInExecutionBase is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon, UniswapV4BufferHookLiquidityExecutionBase
{
    using SafeERC20 for IERC20;

    modifier onlyLiquidityRemover() {
        UniswapV4HookOwnerOnlyLiquidityLib.enforceRemoval(Repo._layout().ownerOnlyLiquidity,
            address(IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo()));
        _;
    }

    function _joinLiquidityExactIn(address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline, address)
        internal override onlyLiquidityOwner nonReentrant accrueProtocolFee returns (uint256)
    {
        if (!_isLive()) revert NotLive();
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind = UniswapV4SeBufferHookLegLib.classify(l.legs, tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
        PullLib.pullErc20Single(tokenIn, amountIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            uint256 pairOut = _unwrapSeShares(amountIn);
            return _depositSingle(l.pairToken, pairOut, to, sharesMin, deadline);
        }
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function _exitLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address)
        internal override onlyLiquidityRemover nonReentrant returns (uint256)
    {
        return Withdrawal.withdrawFrom(msg.sender, amount_, token_, receiver_, minimum_, deadline_);
    }

    function _swapExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline)
        internal nonReentrant returns (uint256 amountOut)
    {
        _requireDeadline(deadline);
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        ClaimLib.ExactInOutput memory output = _singleExchangeQuotePlan(zfo, amountIn, address(0));
        amountOut = output.amountOut;
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        if (amountOut == 0) revert ZeroAmount();
        _secureSwapPull(tokenIn, amountIn, pretransferred);
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zfo == _zeroForOneIsRawIn();
        if (rawIn) {
            amountOut = ClaimLib.unwrapQuoted(output);
            if (amountOut < minAmountOut) revert InsufficientTokenOut();
            IERC20(l.pairToken).safeTransfer(recipient, amountOut);
        } else {
            Withdrawal.bufferPair(amountIn);
            if (amountOut > Withdrawal.spendableRaw()) revert InsufficientTokenOut();
            IERC20(l.rawToken).safeTransfer(recipient, amountOut);
        }
        Withdrawal.syncReserves();
    }

    function _secureSwapPull(IERC20 tokenIn, uint256 claimed, bool prepaid) private returns (uint256) {
        uint256 beforeBalance = tokenIn.balanceOf(address(this));
        if (!prepaid) {
            tokenIn.safeTransferFrom(msg.sender, address(this), claimed);
            uint256 delta = tokenIn.balanceOf(address(this)) - beforeBalance;
            if (delta != claimed) revert ISecurePullErrors.TransferDeltaInsufficient(claimed, delta);
            return claimed;
        }
        LocalCreditLib.requirePretransferCaller(msg.sender);
        Repo.Layout storage l = Repo._layout();
        uint256 booked;
        if (address(tokenIn) == l.rawToken) booked = MultiAssetBasicVaultRepo._reserveOfToken(l.rawToken);
        else if (l.pairToken == l.standardExchange) booked = l.localPairReserve;
        uint256 available = LocalCreditLib.available(tokenIn.balanceOf(address(this)), booked);
        if (claimed > available) revert ISecurePullErrors.TransferDeltaInsufficient(claimed, available);
        return claimed;
    }
}
