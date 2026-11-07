// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

/// @notice Inlined holder-aware withdrawal settlement shared by LP, SE and native SY entrypoints.
library UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib {
    using SafeERC20 for IERC20;
    error DeadlineExpired();
    error ZeroAmount();
    error InvalidToken();
    error NotZapEligible();
    error InsufficientLpOut();
    error InsufficientTokenOut();
    event WithdrawSingle(address indexed sender, address indexed to, uint256 lpAmount, address tokenOut, uint256 amountOut);
    event ZapSwap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    function withdrawFrom(address holder, uint256 lpAmount, address tokenOut, address to, uint256 minAmountOut, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        if (block.timestamp > deadline) revert DeadlineExpired();
        Repo.Layout storage l = Repo._layout();
        if (tokenOut != l.rawToken && tokenOut != l.pairToken) revert InvalidToken();
        if (!(isLive() && ERC20Repo._totalSupply() > Repo.MINIMUM_LIQUIDITY)) revert NotZapEligible();
        amountOut = ClaimLib.singleComponentExit(holder, lpAmount, to, minAmountOut, tokenOut == l.pairToken);
        syncReserves();
        emit WithdrawSingle(msg.sender, to, lpAmount, tokenOut, amountOut);
    }

    function bufferPair(uint256 amount) internal returns (uint256 seOut) {
        return ClaimLib.bufferPoolPair(amount);
    }

    function unwrapSeShares(uint256 seIn) internal returns (uint256 pairOut) {
        uint256 cap = spendableShares();
        if (seIn > cap) seIn = cap;
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (l.pairToken == l.standardExchange) return seIn;(uint256 minOut,) = IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.standardExchange), seIn, IERC20(l.pairToken));
        IERC20(l.standardExchange).forceApprove(l.standardExchange, seIn);(pairOut,) = IStandardExchangeIn(l.standardExchange).exchangeIn(IERC20(l.standardExchange), seIn, IERC20(l.pairToken), minOut, address(this), false, block.timestamp
        );
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
    }

    function proRata(uint256 lpAmount) internal view returns (uint256 rawOut, uint256 seOut) {
        ClaimLib.Basket memory claim = ClaimLib.componentClaim(lpAmount);
        return (claim.raw, claim.shares);
    }

    function syncReserves() internal {
        Repo.Layout storage l = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.rawToken), l.bookedRaw);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.pairToken), ClaimLib.ratedReserve());
    }




    function spendableShares() internal view returns (uint256) {
        return Repo._layout().bookedSeShares;
    }
    function spendableRaw() internal view returns (uint256) {
        return Repo._layout().bookedRaw;
    }
    function isLive() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return ERC20Repo._totalSupply() != 0 && l.bookedRaw != 0 && (l.bookedSeShares != 0 || l.localPairReserve != 0);
    }
    function wadProduct() internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return Math.toWad(_reserve(l.currency0), decimalsOf(l.currency0)) * Math.toWad(_reserve(l.currency1), decimalsOf(l.currency1));
    }
    function decimalsOf(address token) internal view returns (uint8 d) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.currency0) d = l.decimalsCurrency0;
        else if (token == l.currency1) d = l.decimalsCurrency1;
        else revert InvalidToken();
        if (d == 0) d = 18;
    }
    function _reserve(address token) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.rawToken) return IERC20(token).balanceOf(address(this));
        if (token == l.pairToken) return ClaimLib.ratedReserve();
        return 0;
    }
}
