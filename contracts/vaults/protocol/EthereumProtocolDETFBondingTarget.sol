// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
	BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {EthereumProtocolDETFCommon} from "contracts/vaults/protocol/EthereumProtocolDETFCommon.sol";
import {
	BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";

contract EthereumProtocolDETFBondingTarget is EthereumProtocolDETFCommon, ReentrancyLockModifiers {
	using BetterSafeERC20 for IERC20;
	using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

	error EthRefundFailed(address recipient, uint256 amount);

	struct BalancedLiquidityResult {
		uint256 wethUsed;
		uint256 chirUsed;
		uint256 lpMinted;
	}

	function _depositWethToChirWethVaultViaBalancedLp(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 wethAmount_,
		address wethRefundRecipient_,
		bool wethRefundAsEth_,
		uint256 deadline_
	) internal returns (uint256 vaultShares_) {
		deadline_;

		(ChirWethLiquidityQuote memory quote, uint256 chirAmount, uint256 wethUsed) =
			_quoteBalancedChirWethDepositAmounts(layout_, wethAmount_);
		if (chirAmount == 0 || wethUsed == 0) {
			revert ZeroAmount();
		}

		ERC20Repo._mint(address(this), chirAmount);

		BalancedLiquidityResult memory result = _addBalancedChirWethLiquidity(quote, wethUsed, chirAmount);

		if (chirAmount > result.chirUsed) {
			ERC20Repo._burn(address(this), chirAmount - result.chirUsed);
		}

		if (wethAmount_ > result.wethUsed) {
			_refundUnusedWeth(layout_, wethAmount_ - result.wethUsed, wethRefundRecipient_, wethRefundAsEth_);
		}

		IERC20(quote.pool).safeTransfer(address(layout_.chirWethVault), result.lpMinted);
		vaultShares_ = layout_.chirWethVault.exchangeIn(
			IERC20(quote.pool),
			result.lpMinted,
			IERC20(address(layout_.chirWethVault)),
			0,
			address(this),
			true,
			deadline_
		);
	}

	function acceptedBondTokens() external view returns (address[] memory tokens_) {
		return BaseProtocolDETFRepo._acceptedBondTokens();
	}

	function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted_) {
		return BaseProtocolDETFRepo._isAcceptedBondToken(address(token));
	}

	function _refundUnusedWeth(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 refundAmount_,
		address recipient_,
		bool refundAsEth_
	) internal {
		if (refundAmount_ == 0) {
			return;
		}

		if (!refundAsEth_) {
			layout_.wethToken.safeTransfer(recipient_, refundAmount_);
			return;
		}

		IWETH(address(layout_.wethToken)).withdraw(refundAmount_);
		(bool success,) = recipient_.call{value: refundAmount_}("");
		if (!success) {
			revert EthRefundFailed(recipient_, refundAmount_);
		}
	}

	function _collectBondInput(
		BaseProtocolDETFRepo.Storage storage layout_,
		IERC20 tokenIn_,
		uint256 amountIn_,
		bool wethAsEth_
	) internal {
		if (!layout_._isAcceptedBondToken(address(tokenIn_))) {
			revert BondTokenNotSupported(tokenIn_);
		}

		if (wethAsEth_) {
			if (!_isWethToken(layout_, tokenIn_)) {
				revert InvalidEthBondRoute(tokenIn_);
			}
			if (msg.value != amountIn_) {
				revert IncorrectEthValue(amountIn_, msg.value);
			}
			IWETH(address(layout_.wethToken)).deposit{value: amountIn_}();
			return;
		}

		if (msg.value != 0) {
			revert IncorrectEthValue(0, msg.value);
		}

		tokenIn_.safeTransferFrom(msg.sender, address(this), amountIn_);
	}

	function _addBalancedChirWethLiquidity(
		ChirWethLiquidityQuote memory quote_,
		uint256 wethUsed_,
		uint256 chirAmount_
	)
		internal
		returns (BalancedLiquidityResult memory result_)
	{
		if (quote_.token0 == address(BaseProtocolDETFRepo._layout().wethToken)) {
			IERC20(quote_.token0).safeTransfer(quote_.pool, wethUsed_);
			IERC20(quote_.token1).safeTransfer(quote_.pool, chirAmount_);
		} else {
			IERC20(quote_.token0).safeTransfer(quote_.pool, chirAmount_);
			IERC20(quote_.token1).safeTransfer(quote_.pool, wethUsed_);
		}

		result_.wethUsed = wethUsed_;
		result_.chirUsed = chirAmount_;
		result_.lpMinted = IUniswapV2Pair(quote_.pool).mint(address(this));
	}

	function claimLiquidity(uint256 lpAmount, address recipient) external lock returns (uint256 extractedWeth) {
		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}

		if (msg.sender != address(layout.protocolNFTVault)) {
			revert NotNFTVault(msg.sender);
		}

		if (recipient == address(0)) {
			recipient = msg.sender;
		}

		if (lpAmount == 0) {
			return 0;
		}

		ReservePoolData memory resPoolData;
		(TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
		uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
		for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
			balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
		}

		uint256 minChirWethVaultOut = _calcMinChirWethVaultOutRaw(resPoolData, tokenInfo, balancesLiveScaled18, lpAmount);
		(IERC20 bpt, uint256 chirWethVaultOut) = _exitReservePoolToChirWethVault(layout, resPoolData, lpAmount, minChirWethVaultOut);
		(address poolAddr, uint256 lpOut) = _redeemChirWethVaultToUniV2Lp(layout.chirWethVault, chirWethVaultOut);
		(uint256 chirAmount, uint256 wethAmount) = _burnUniV2LpToChirWeth(layout, poolAddr, lpOut);

		if (wethAmount > 0) {
			layout.wethToken.safeTransfer(recipient, wethAmount);
		}
		extractedWeth = wethAmount;

		if (chirAmount > 0) {
			_reinvestChir(layout, chirAmount);
		}

		ERC4626Repo._setLastTotalAssets(bpt.balanceOf(address(this)));
	}

	function _calcMinChirWethVaultOutRaw(
		ReservePoolData memory resPoolData,
		TokenInfo[] memory tokenInfo,
		uint256[] memory balancesLiveScaled18,
		uint256 lpAmount
	) internal view returns (uint256 minChirWethVaultOut) {
		uint256 minChirWethVaultOutScaled18 = BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn(
			balancesLiveScaled18,
			resPoolData.weightsArray,
			resPoolData.chirWethVaultIndex,
			lpAmount,
			resPoolData.resPoolTotalSupply,
			resPoolData.reservePoolSwapFee
		);

		uint256 chirWethRate = FixedPoint.ONE;
		if (address(tokenInfo[resPoolData.chirWethVaultIndex].rateProvider) != address(0)) {
			chirWethRate = tokenInfo[resPoolData.chirWethVaultIndex].rateProvider.getRate();
		}

		minChirWethVaultOut = FixedPoint.divDown(minChirWethVaultOutScaled18, chirWethRate);
		if (minChirWethVaultOut > 0) {
			unchecked {
				minChirWethVaultOut = minChirWethVaultOut - 1;
			}
		}
	}

	function _exitReservePoolToChirWethVault(
		BaseProtocolDETFRepo.Storage storage layout,
		ReservePoolData memory resPoolData,
		uint256 lpAmount,
		uint256 minChirWethVaultOut
	) internal returns (IERC20 bpt, uint256 chirWethVaultOut) {
		bpt = IERC20(address(ERC4626Repo._reserveAsset()));
		IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
		bpt.forceApprove(address(balV3Vault), lpAmount);
		bpt.forceApprove(address(layout.balancerV3PrepayRouter), lpAmount);

		chirWethVaultOut = layout.balancerV3PrepayRouter.prepayRemoveLiquiditySingleTokenExactIn(
			address(resPoolData.reservePool),
			lpAmount,
			IERC20(address(layout.chirWethVault)),
			minChirWethVaultOut,
			""
		);
	}

	function _redeemChirWethVaultToUniV2Lp(IStandardExchange chirWethVault_, uint256 chirWethVaultOut)
		internal
		returns (address poolAddr, uint256 lpOut)
	{
		poolAddr = IERC4626(address(chirWethVault_)).asset();
		lpOut = IERC4626(address(chirWethVault_)).redeem(chirWethVaultOut, address(this), address(this));
	}

	function _burnUniV2LpToChirWeth(BaseProtocolDETFRepo.Storage storage layout, address poolAddr, uint256 lpOut)
		internal
		returns (uint256 chirAmount, uint256 wethAmount)
	{
		IUniswapV2Pair pool = IUniswapV2Pair(poolAddr);
		IERC20(poolAddr).safeTransfer(address(pool), lpOut);
		(uint256 amount0, uint256 amount1) = pool.burn(address(this));

		if (pool.token0() == address(layout.wethToken)) {
			wethAmount = amount0;
			chirAmount = amount1;
		} else {
			wethAmount = amount1;
			chirAmount = amount0;
		}
	}

	function _reinvestChir(BaseProtocolDETFRepo.Storage storage layout, uint256 chirAmount) internal {
		IERC20(address(this)).safeTransfer(address(layout.chirWethVault), chirAmount);
		uint256 chirWethShares = layout.chirWethVault.exchangeIn(
			IERC20(address(this)),
			chirAmount,
			IERC20(address(layout.chirWethVault)),
			0,
			address(this),
			true,
			block.timestamp
		);

		_addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, block.timestamp);
	}

	function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool wethAsEth, uint256 deadline)
		external
		payable
		lock
		returns (uint256 tokenId, uint256 shares)
	{
		if (block.timestamp > deadline) {
			revert DeadlineExceeded(deadline, block.timestamp);
		}
		if (amountIn == 0) {
			revert ZeroAmount();
		}

		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}
		if (recipient == address(0)) {
			recipient = msg.sender;
		}

		_collectBondInput(layout, tokenIn, amountIn, wethAsEth);

		if (_isWethToken(layout, tokenIn)) {
			uint256 chirWethShares = _depositWethToChirWethVaultViaBalancedLp(
				layout,
				amountIn,
				msg.sender,
				wethAsEth,
				deadline
			);
			shares = _addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, deadline);
		} else if (_isRichToken(layout, tokenIn)) {
			layout.richToken.safeTransfer(address(layout.richChirVault), amountIn);
			uint256 richChirShares = layout.richChirVault.exchangeIn(
				layout.richToken,
				amountIn,
				IERC20(address(layout.richChirVault)),
				0,
				address(this),
				true,
				deadline
			);
			shares = _addToReservePool(layout, layout.richChirVaultIndex, richChirShares, deadline);
		} else {
			revert BondTokenNotSupported(tokenIn);
		}

		tokenId = layout.protocolNFTVault.createPosition(shares, lockDuration, recipient);
	}

	function captureSeigniorage() external lock returns (uint256 bptReceived) {
		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}

		uint256 chirBalance = layout.protocolNFTVault.reallocateProtocolRewards(address(this));
		if (chirBalance == 0) {
			revert NoSeigniorageToCapture();
		}
		IERC20(address(this)).safeTransfer(address(layout.chirWethVault), chirBalance);
		uint256 chirWethShares = layout.chirWethVault.exchangeIn(
			IERC20(address(this)),
			chirBalance,
			IERC20(address(layout.chirWethVault)),
			0,
			address(this),
			true,
			block.timestamp
		);

		bptReceived = _addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, block.timestamp);
		layout.protocolNFTVault.addToProtocolNFT(layout.protocolNFTId, bptReceived);
	}

	function sellNFT(uint256 tokenId, address recipient) external lock returns (uint256 richirMinted) {
		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}
		if (recipient == address(0)) {
			recipient = msg.sender;
		}

		(uint256 principalShares,) = layout.protocolNFTVault.sellPositionToProtocol(tokenId, msg.sender, recipient);
		if (principalShares == 0) {
			revert ZeroAmount();
		}

		uint256 richirShares = BetterMath._convertToSharesDown(
			principalShares,
			layout.richirToken.totalSupply(),
			layout.richirToken.totalShares(),
			0
		);

		richirMinted = layout.richirToken.mintFromNFTSale(richirShares, recipient);
	}

	function donate(IERC20 token, uint256 amount, bool pretransferred) external lock {
		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}
		if (amount == 0) {
			revert ZeroAmount();
		}
		if (!_isWethToken(layout, token) && !_isChirToken(token)) {
			revert InvalidDonationToken(token);
		}

		if (!pretransferred) {
			token.safeTransferFrom(msg.sender, address(this), amount);
		}

		if (_isWethToken(layout, token)) {
			token.safeTransfer(address(layout.chirWethVault), amount);
			uint256 vaultShares = layout.chirWethVault.exchangeIn(
				token,
				amount,
				IERC20(address(layout.chirWethVault)),
				0,
				address(this),
				true,
				block.timestamp
			);

			uint256 bptOut = _addToReservePool(layout, layout.chirWethVaultIndex, vaultShares, block.timestamp);
			IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
			reservePoolToken.forceApprove(address(layout.protocolNFTVault), bptOut);
			layout.protocolNFTVault.addToProtocolNFT(layout.protocolNFTId, bptOut);
		} else {
			ERC20Repo._burn(address(this), amount);
		}
	}

	function _addToReservePool(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 tokenIndexIn_,
		uint256 vaultShares,
		uint256 deadline_
	) internal returns (uint256 bptOut) {
		deadline_;
		ReservePoolData memory resPoolData;
		(TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
		uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
		for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
			balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
		}

		uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares, tokenInfo[tokenIndexIn_]);
		uint256[] memory amountsIn = new uint256[](2);
		amountsIn[tokenIndexIn_] = vaultShares;

		bptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
			balancesLiveScaled18,
			resPoolData.weightsArray,
			tokenIndexIn_,
			amountInLiveScaled18,
			resPoolData.resPoolTotalSupply,
			resPoolData.reservePoolSwapFee
		);

		IERC20 reserveVaultToken;
		if (tokenIndexIn_ == layout_.chirWethVaultIndex) {
			reserveVaultToken = IERC20(address(layout_.chirWethVault));
		} else if (tokenIndexIn_ == layout_.richChirVaultIndex) {
			reserveVaultToken = IERC20(address(layout_.richChirVault));
		} else {
			revert BaseProtocolDETFRepo.TokenNotSupported();
		}

		reserveVaultToken.safeTransfer(address(resPoolData.balV3Vault), vaultShares);
		layout_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut, "");
		ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
	}

}