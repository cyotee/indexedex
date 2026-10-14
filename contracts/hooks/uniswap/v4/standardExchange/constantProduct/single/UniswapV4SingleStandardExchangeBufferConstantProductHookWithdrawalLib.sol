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
        if (lpAmount == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (tokenOut != l.rawToken && tokenOut != l.pairToken) revert InvalidToken();
        if (!(isLive() && ERC20Repo._totalSupply() > Repo.MINIMUM_LIQUIDITY)) revert NotZapEligible();
        mintProtocolFee();
        if (lpAmount > ERC20Repo._balanceOf(holder)) revert InsufficientLpOut();
        (uint256 rawUser, uint256 seUser) = proRata(lpAmount);
        ClaimLib.WithdrawalPlan memory plan = ClaimLib.withdrawalPlan(rawUser, seUser,
            IERC20(l.rawToken).balanceOf(address(this)) - rawUser, tokenOut == l.pairToken);
        amountOut = (tokenOut == l.pairToken ? plan.pairUser : rawUser) + plan.residualOut;
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        ERC20Repo._burn(holder, lpAmount);
        uint256 pairUser = seUser > 0 ? unwrapSeShares(seUser) : 0;
        if (pairUser < plan.pairUser) revert InsufficientTokenOut();
        if (tokenOut == l.pairToken) {
            amountOut = pairUser;
            if (plan.residualShares != 0) {
                uint256 got = ClaimLib.unwrapQuoted(ClaimLib.ExactInOutput(plan.residualOut, plan.residualShares));
                emit ZapSwap(msg.sender, l.rawToken, l.pairToken, rawUser, got);
                amountOut += got;
            }
            if (amountOut < minAmountOut) revert InsufficientTokenOut();
            if (amountOut > 0) IERC20(l.pairToken).safeTransfer(to, amountOut);
        } else {
            uint256 residual = amountOut > rawUser ? amountOut - rawUser : 0;
            if (pairUser > 0) {
                bufferPair(pairUser);
                emit ZapSwap(msg.sender, l.pairToken, l.rawToken, pairUser, residual);
            }
            uint256 capRaw = spendableRaw();
            if (amountOut > capRaw) amountOut = capRaw;
            if (amountOut < minAmountOut) revert InsufficientTokenOut();
            if (amountOut > 0) IERC20(l.rawToken).safeTransfer(to, amountOut);
        }
        syncReserves();
        setKLast();
        refundPairDust();
        emit WithdrawSingle(msg.sender, to, lpAmount, tokenOut, amountOut);
    }

    function bufferPair(uint256 amount) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (l.pairToken == l.standardExchange) return amount;
        uint256 minOut = IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.pairToken), amount, IERC20(l.standardExchange));
        if (minOut == 0) return 0;
        IERC20(l.pairToken).forceApprove(l.standardExchange, amount);
        return IStandardExchangeIn(l.standardExchange).exchangeIn(
            IERC20(l.pairToken), amount, IERC20(l.standardExchange), minOut, address(this), false, block.timestamp
        );
    }

    function unwrapSeShares(uint256 seIn) internal returns (uint256 pairOut) {
        uint256 cap = spendableShares();
        if (seIn > cap) seIn = cap;
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (l.pairToken == l.standardExchange) return seIn;
        uint256 minOut = IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.standardExchange), seIn, IERC20(l.pairToken));
        IERC20(l.standardExchange).forceApprove(l.standardExchange, seIn);
        pairOut = IStandardExchangeIn(l.standardExchange).exchangeIn(
            IERC20(l.standardExchange), seIn, IERC20(l.pairToken), minOut, address(this), false, block.timestamp
        );
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
    }

    function proRata(uint256 lpAmount) internal view returns (uint256 rawOut, uint256 seOut) {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seBal = IERC20(l.standardExchange).balanceOf(address(this));
        rawOut = (rawBal * lpAmount) / supply;
        seOut = (seBal * lpAmount) / supply;
        uint256 dust = Repo.MAX_DUST_WEI;
        if (rawBal <= dust) rawOut = 0;
        else if (rawOut > rawBal - dust) rawOut = rawBal - dust;
        if (seBal <= dust) seOut = 0;
        else if (seOut > seBal - dust) seOut = seBal - dust;
    }

    function syncReserves() internal {
        Repo.Layout storage l = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.rawToken), IERC20(l.rawToken).balanceOf(address(this)));
        if (l.pairToken == l.standardExchange) l.localPairReserve = IERC20(l.pairToken).balanceOf(address(this));
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.pairToken), ClaimLib.ratedReserve());
    }

    function mintProtocolFee() internal {
        (bool feeOn, address feeTo_, uint256 share) = feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) { l.kLast = 0; return; }
        if (l.kLast == 0) return;
        uint256 amount = Math.calculateProtocolFee(ERC20Repo._totalSupply(), wadProduct(), l.kLast, share);
        if (amount > 0) ERC20Repo._mint(feeTo_, amount);
    }

    function setKLast() internal {
        (bool feeOn,,) = feeOnAndShare();
        Repo._layout().kLast = feeOn ? wadProduct() : 0;
    }

    function refundPairDust() internal {
        Repo.Layout storage l = Repo._layout();
        if (l.pairToken == l.standardExchange) return;
        for (uint256 i; i < 3; ++i) {
            uint256 bal = IERC20(l.pairToken).balanceOf(address(this));
            if (bal <= Repo.MAX_DUST_WEI) return;
            uint256 excess = bal - Repo.MAX_DUST_WEI;
            uint256 preview = ClaimLib.previewResidualBuffer(excess);
            if (preview == 0) return;
            ClaimLib.bufferQuotedResidual(excess, preview);
        }
    }

    function feeOnAndShare() internal view returns (bool feeOn, address feeTo_, uint256 share) {
        (IFeeCollectorProxy recipient, uint256 fee) = IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        feeTo_ = address(recipient);
        feeOn = feeTo_ != address(0) && fee != 0;
        share = (fee * Repo.TRADING_FEE_DENOMINATOR) / 1e18;
    }
    function spendableShares() internal view returns (uint256) {
        uint256 balance = IERC20(Repo._layout().standardExchange).balanceOf(address(this));
        return balance > 1 ? balance - 1 : 0;
    }
    function spendableRaw() internal view returns (uint256) {
        uint256 balance = IERC20(Repo._layout().rawToken).balanceOf(address(this));
        return balance > 1 ? balance - 1 : 0;
    }
    function isLive() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (_reserve(l.currency0) > 0 && _reserve(l.currency1) > 0) return true;
        return IERC20(l.rawToken).balanceOf(address(this)) > 0 && IERC20(l.standardExchange).balanceOf(address(this)) > 0;
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
