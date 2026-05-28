// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Math} from "@crane/contracts/utils/Math.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {DETFPreviewLib} from "contracts/vaults/detf/core/DETFPreviewLib.sol";
import {BaseDualSelfCommonDETFRepo} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRepo.sol";
import {EthereumDualSelfCommonDETFCommon} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFCommon.sol";
import {BaseDualSelfCommonDETFPreviewHelpers} from "contracts/vaults/protocol/BaseDualSelfCommonDETFPreviewHelpers.sol";
import {
	BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {
	PREVIEW_BUFFER_DENOMINATOR,
	PREVIEW_RICHIR_BUFFER_BPS,
	PREVIEW_BPT_BUFFER_DENOMINATOR,
	PREVIEW_BPT_BUFFER_BPS,
	PREVIEW_WETH_CHIR_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";

contract EthereumDualSelfCommonDETFExchangeOutTarget is EthereumDualSelfCommonDETFCommon, ReentrancyLockModifiers, IStandardExchangeOut {
	using BetterSafeERC20 for IERC20;
	using FixedPoint for uint256;
	using BaseDualSelfCommonDETFRepo for BaseDualSelfCommonDETFRepo.Storage;

	struct ExchangeOutParams {
		IERC20 tokenIn;
		uint256 maxAmountIn;
		IERC20 tokenOut;
		uint256 amountOut;
		address recipient;
		bool pretransferred;
		uint256 deadline;
		uint256 syntheticPrice;
	}

	struct ReservePoolBptPreviewOut {
		uint256[] balancesRaw;
		uint256 bptOut;
		uint256 poolSupply;
		uint256 chirIdx;
		uint256 richIdx;
	}

	function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
		external
		view
		returns (uint256 amountIn_)
	{
		BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();

		if (_isWethToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
			PoolReserves memory reserves;
			_loadPoolReserves(layoutStruct, reserves);
			uint256 syntheticPrice = _calcSyntheticPrice(reserves);
			if (!_isMintingAllowed(layoutStruct, syntheticPrice)) {
				revert MintingNotAllowed(syntheticPrice, layoutStruct.mintThreshold);
			}
			return _calcRequiredWethForExactChir(layoutStruct, amountOut_, reserves);
		}

		if (_isChirToken(tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
			return layoutStruct.richChirVault.previewExchangeOut(tokenIn_, tokenOut_, amountOut_);
		}

		if (_isRichirToken(layoutStruct, tokenIn_) && _isWethToken(layoutStruct, tokenOut_)) {
			revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
		}

		if (_isWethToken(layoutStruct, tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
			return _previewWethToRichExact(layoutStruct, amountOut_);
		}

		if (_isRichToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
			return _previewRichToChirExact(layoutStruct, amountOut_);
		}

		if (_isRichToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
			revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
		}

		if (_isWethToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
			revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
		}

		revert ExchangeOutNotAvailable();
	}

	function exchangeOut(
		IERC20 tokenIn_,
		uint256 maxAmountIn_,
		IERC20 tokenOut_,
		uint256 amountOut_,
		address recipient_,
		bool pretransferred_,
		uint256 deadline_
	) external lock returns (uint256 amountIn_) {
		if (block.timestamp > deadline_) {
			revert DeadlineExceeded(deadline_, block.timestamp);
		}

		BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
		PoolReserves memory reserves;
		_loadPoolReserves(layoutStruct, reserves);
		uint256 syntheticPrice = _calcSyntheticPrice(reserves);

		ExchangeOutParams memory params = ExchangeOutParams({
			tokenIn: tokenIn_,
			maxAmountIn: maxAmountIn_,
			tokenOut: tokenOut_,
			amountOut: amountOut_,
			recipient: recipient_,
			pretransferred: pretransferred_,
			deadline: deadline_,
			syntheticPrice: syntheticPrice
		});

		if (_isWethToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
			return _executeMintExactChir(layoutStruct, params);
		}
		if (_isChirToken(tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
			return _executeChirToRichExact(layoutStruct, params);
		}
		if (_isRichirToken(layoutStruct, tokenIn_) && _isWethToken(layoutStruct, tokenOut_)) {
			revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
		}
		if (_isWethToken(layoutStruct, tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
			return _executeWethToRichExact(layoutStruct, params);
		}
		if (_isRichToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
			return _executeRichToChirExact(layoutStruct, params);
		}
		if (_isRichToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
			revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
		}
		if (_isWethToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
			revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
		}

		revert ExchangeOutNotAvailable();
	}

	function _calcRequiredWethForExactChir(
		BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
		uint256 amountOut_,
		PoolReserves memory reserves_
	) internal view returns (uint256 amountIn_) {
		uint256 syntheticPrice = _calcSyntheticPrice(reserves_);

		if (syntheticPrice <= ONE_WAD) {
			amountIn_ = amountOut_;
		} else {
			uint256 incentivePercent = layoutStruct_._seigniorageIncentivePercentagePPM();
			uint256 full = 1e6;

			if (incentivePercent == 0 || incentivePercent >= full * 2) {
				amountIn_ = BetterMath._mulDiv(amountOut_, syntheticPrice, ONE_WAD, Math.Rounding.Ceil);
				amountIn_ = DETFPreviewLib._applyMarkupBps(
					amountIn_, PREVIEW_WETH_CHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR
				);
				return amountIn_;
			}

			uint256 userFactor = full - (incentivePercent / 2);
			uint256 boostFactor = full + incentivePercent;
			uint256 targetBaseCHIR = BetterMath._mulDiv(amountOut_, full, userFactor, Math.Rounding.Ceil);
			uint256 requiredBoostedWETH = ConstProdUtils._purchaseQuote(
				targetBaseCHIR,
				reserves_.wethReserve,
				reserves_.chirInWethPool,
				reserves_.chirWethFeePercent,
				10000
			);

			amountIn_ = BetterMath._mulDiv(requiredBoostedWETH, full, boostFactor, Math.Rounding.Ceil);
		}

		amountIn_ = DETFPreviewLib._applyMarkupBps(amountIn_, PREVIEW_WETH_CHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR);
	}

	function _calcRequiredWethForExactChirExec(uint256 amountOut_, uint256 syntheticPrice_)
		internal
		pure
		returns (uint256 amountIn_)
	{
		if (syntheticPrice_ <= ONE_WAD) {
			amountIn_ = amountOut_;
		} else {
			amountIn_ = BetterMath._mulDiv(amountOut_, syntheticPrice_, ONE_WAD, Math.Rounding.Ceil);
		}
	}

	function _executeMintExactChir(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
		internal
		returns (uint256 amountIn_)
	{
		if (!_isMintingAllowed(layoutStruct_, p_.syntheticPrice)) {
			revert MintingNotAllowed(p_.syntheticPrice, layoutStruct_.mintThreshold);
		}

		amountIn_ = _calcRequiredWethForExactChirExec(p_.amountOut, p_.syntheticPrice);
		if (amountIn_ > p_.maxAmountIn) {
			revert SlippageExceeded(p_.maxAmountIn, amountIn_);
		}

		uint256 actualIn = _secureTokenTransfer(p_.tokenIn, amountIn_, p_.pretransferred);

		SeigniorageCalc memory calc;
		calc.syntheticPrice = p_.syntheticPrice;
		_calcSeigniorage(layoutStruct_, calc, actualIn);

		p_.tokenIn.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
		layoutStruct_.chirWethVault.exchangeIn(
			p_.tokenIn, actualIn, IERC20(address(layoutStruct_.chirWethVault)), 0, address(this), true, p_.deadline
		);

		if (calc.seigniorageTokens > 0) {
			ERC20Repo._mint(address(layoutStruct_.protocolNFTVault), calc.seigniorageTokens);
		}

		ERC20Repo._mint(p_.recipient, p_.amountOut);

		if (p_.pretransferred && p_.maxAmountIn > amountIn_) {
			p_.tokenIn.safeTransfer(msg.sender, p_.maxAmountIn - amountIn_);
		}
	}

	function _executeChirToRichExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
		internal
		returns (uint256 amountIn_)
	{
		amountIn_ = layoutStruct_.richChirVault.previewExchangeOut(p_.tokenIn, p_.tokenOut, p_.amountOut);
		if (amountIn_ > p_.maxAmountIn) {
			revert SlippageExceeded(p_.maxAmountIn, amountIn_);
		}

		_secureChirBurn(msg.sender, amountIn_, p_.pretransferred);
		ERC20Repo._mint(address(layoutStruct_.richChirVault), amountIn_);
		layoutStruct_.richChirVault.exchangeOut(p_.tokenIn, amountIn_, p_.tokenOut, p_.amountOut, p_.recipient, true, p_.deadline);
	}

	function _previewChirToWethExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactWethOut_)
		internal
		view
		returns (uint256 chirIn_)
	{
		if (exactWethOut_ == 0) return 0;

		PoolReserves memory reserves;
		_loadPoolReserves(layoutStruct_, reserves);
		uint256 syntheticPrice = _calcSyntheticPrice(reserves);
		if (!_isBurningAllowed(layoutStruct_, syntheticPrice)) {
			revert BurningNotAllowed(syntheticPrice, layoutStruct_.burnThreshold);
		}

		uint256 low = exactWethOut_;
		uint256 high = exactWethOut_ * 2;
		uint256 maxIterations = 128;
		uint256 iterations = 0;
		uint256 wethFromHigh = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), high, layoutStruct_.wethToken);
		while (wethFromHigh < exactWethOut_ && high < type(uint128).max && iterations < maxIterations) {
			high = high * 2;
			wethFromHigh = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), high, layoutStruct_.wethToken);
			++iterations;
		}

		iterations = 0;
		while (low < high && iterations < maxIterations) {
			uint256 mid = (low + high) / 2;
			uint256 wethOut = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), mid, layoutStruct_.wethToken);
			if (wethOut < exactWethOut_) {
				low = mid + 1;
			} else {
				high = mid;
			}
			++iterations;
		}

		chirIn_ = low;
		uint256 wethCheck = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), chirIn_, layoutStruct_.wethToken);
		if (wethCheck < exactWethOut_) {
			chirIn_ += 1;
		}
	}

	function _executeChirToWethExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
		internal
		returns (uint256 amountIn_)
	{
		if (!_isBurningAllowed(layoutStruct_, p_.syntheticPrice)) {
			revert BurningNotAllowed(p_.syntheticPrice, layoutStruct_.burnThreshold);
		}

		amountIn_ = _previewChirToWethExact(layoutStruct_, p_.amountOut);
		if (amountIn_ > p_.maxAmountIn) {
			revert SlippageExceeded(p_.maxAmountIn, amountIn_);
		}

		_secureChirBurn(msg.sender, amountIn_, p_.pretransferred);
		ERC20Repo._mint(address(layoutStruct_.chirWethVault), amountIn_);
		uint256 wethOut = layoutStruct_.chirWethVault.exchangeIn(
			IERC20(address(this)), amountIn_, layoutStruct_.wethToken, p_.amountOut, p_.recipient, true, p_.deadline
		);
		if (wethOut < p_.amountOut) {
			revert SlippageExceeded(p_.amountOut, wethOut);
		}
	}

	function _previewWethToRichExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactRichOut_)
		internal
		view
		returns (uint256 wethIn_)
	{
		if (exactRichOut_ == 0) return 0;
		uint256 chirNeeded = layoutStruct_.richChirVault.previewExchangeOut(IERC20(address(this)), layoutStruct_.richToken, exactRichOut_);
		wethIn_ = layoutStruct_.chirWethVault.previewExchangeOut(layoutStruct_.wethToken, IERC20(address(this)), chirNeeded);
	}

	function _executeWethToRichExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
		internal
		returns (uint256 amountIn_)
	{
		amountIn_ = _previewWethToRichExact(layoutStruct_, p_.amountOut);
		if (amountIn_ > p_.maxAmountIn) {
			revert SlippageExceeded(p_.maxAmountIn, amountIn_);
		}

		uint256 actualIn = _secureTokenTransfer(layoutStruct_.wethToken, amountIn_, p_.pretransferred);
		layoutStruct_.wethToken.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
		uint256 chirOut = layoutStruct_.chirWethVault.exchangeIn(layoutStruct_.wethToken, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);
		IERC20(address(this)).safeTransfer(address(layoutStruct_.richChirVault), chirOut);
		layoutStruct_.richChirVault.exchangeOut(IERC20(address(this)), chirOut, layoutStruct_.richToken, p_.amountOut, p_.recipient, true, p_.deadline);
	}

	function _previewRichToChirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactChirOut_)
		internal
		view
		returns (uint256 richIn_)
	{
		if (exactChirOut_ == 0) return 0;

		PoolReserves memory reserves;
		_loadPoolReserves(layoutStruct_, reserves);
		uint256 syntheticPrice = _calcSyntheticPrice(reserves);
		if (!_isMintingAllowed(layoutStruct_, syntheticPrice)) {
			revert MintingNotAllowed(syntheticPrice, layoutStruct_.mintThreshold);
		}

		uint256 wethNeeded = _calcRequiredWethForExactChir(layoutStruct_, exactChirOut_, reserves);
		uint256 chirNeeded = layoutStruct_.chirWethVault.previewExchangeOut(IERC20(address(this)), layoutStruct_.wethToken, wethNeeded);
		richIn_ = layoutStruct_.richChirVault.previewExchangeOut(layoutStruct_.richToken, IERC20(address(this)), chirNeeded);
	}

	function _executeRichToChirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
		internal
		returns (uint256 amountIn_)
	{
		if (!_isMintingAllowed(layoutStruct_, p_.syntheticPrice)) {
			revert MintingNotAllowed(p_.syntheticPrice, layoutStruct_.mintThreshold);
		}

		amountIn_ = _previewRichToChirExact(layoutStruct_, p_.amountOut);
		if (amountIn_ > p_.maxAmountIn) {
			revert SlippageExceeded(p_.maxAmountIn, amountIn_);
		}

		uint256 actualIn = _secureTokenTransfer(layoutStruct_.richToken, amountIn_, p_.pretransferred);
		layoutStruct_.richToken.safeTransfer(address(layoutStruct_.richChirVault), actualIn);
		uint256 chirOut = layoutStruct_.richChirVault.exchangeIn(layoutStruct_.richToken, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);
		IERC20(address(this)).safeTransfer(address(layoutStruct_.chirWethVault), chirOut);
		uint256 wethOut = layoutStruct_.chirWethVault.exchangeIn(IERC20(address(this)), chirOut, layoutStruct_.wethToken, 0, address(this), true, p_.deadline);

		ExchangeOutParams memory mintParams = ExchangeOutParams({
			tokenIn: layoutStruct_.wethToken,
			maxAmountIn: wethOut,
			tokenOut: IERC20(address(this)),
			amountOut: p_.amountOut,
			recipient: p_.recipient,
			pretransferred: true,
			deadline: p_.deadline,
			syntheticPrice: p_.syntheticPrice
		});
		_executeMintExactChir(layoutStruct_, mintParams);
	}

	function _previewRichirOutFromVaultShares(
		BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
		uint256 vaultIndex_,
		uint256 vaultShares_
	) internal view returns (uint256 richirOut_) {
		ReservePoolBptPreviewOut memory preview_ = _previewReservePoolBptOut(vaultIndex_, vaultShares_);
		uint256 bptOut = preview_.bptOut;

		ReservePoolData memory resPoolData;
		_loadReservePoolData(resPoolData, new uint256[](0));

		BaseDualSelfCommonDETFPreviewHelpers.RichirCalc memory calc;
		calc.balV3Vault = address(resPoolData.balV3Vault);
		calc.reservePool = address(resPoolData.reservePool);
		calc.reservePoolSwapFee = resPoolData.reservePoolSwapFee;
		calc.weightsArray = resPoolData.weightsArray;
		calc.chirWethVault = address(layoutStruct_.chirWethVault);
		calc.richChirVault = address(layoutStruct_.richChirVault);
		calc.chirToken = address(this);
		calc.wethToken = address(layoutStruct_.wethToken);
		calc.poolBalsRaw = preview_.balancesRaw;
		calc.chirIdx = preview_.chirIdx;
		calc.richIdx = preview_.richIdx;
		calc.vaultIdx = vaultIndex_;
		calc.sharesAdded = vaultShares_;
		calc.poolSupply = preview_.poolSupply;
		calc.bptAdded = bptOut;
		calc.newPosShares = layoutStruct_.protocolNFTVault.getPosition(layoutStruct_.protocolNFTId).originalShares + bptOut;
		calc.newTotShares = layoutStruct_.richirToken.totalShares() + bptOut;

		richirOut_ = BaseDualSelfCommonDETFPreviewHelpers.computeRichirOutFromDeposit(calc);
	}

	function _previewReservePoolBptOut(uint256 vaultIndex_, uint256 vaultShares_)
		internal
		view
		returns (ReservePoolBptPreviewOut memory preview_)
	{
		ReservePoolData memory resPoolData;
		(TokenInfo[] memory tokenInfo, uint256[] memory balancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
		uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
		for (uint256 i = 0; i < balancesRaw.length; ++i) {
			balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
		}

		uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[vaultIndex_]);
		uint256 bptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
			balancesLiveScaled18,
			resPoolData.weightsArray,
			vaultIndex_,
			amountInLiveScaled18,
			resPoolData.resPoolTotalSupply,
			resPoolData.reservePoolSwapFee
		);
		bptOut = DETFPreviewLib._applyDiscountBps(bptOut, PREVIEW_BPT_BUFFER_BPS, PREVIEW_BPT_BUFFER_DENOMINATOR);

		preview_.balancesRaw = balancesRaw;
		preview_.bptOut = bptOut;
		preview_.poolSupply = resPoolData.resPoolTotalSupply;
		preview_.chirIdx = resPoolData.chirWethVaultIndex;
		preview_.richIdx = resPoolData.richChirVaultIndex;
	}

	function _addToReservePoolForExactOut(
		BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
		uint256 vaultShares_,
		uint256 vaultIndex_
	) internal returns (uint256 bptOut_) {
		ReservePoolData memory resPoolData;
		(TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
		uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
		for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
			balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
		}

		uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[vaultIndex_]);
		uint256[] memory amountsIn = new uint256[](2);
		amountsIn[vaultIndex_] = vaultShares_;

		bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
			balancesLiveScaled18,
			resPoolData.weightsArray,
			vaultIndex_,
			amountInLiveScaled18,
			resPoolData.resPoolTotalSupply,
			resPoolData.reservePoolSwapFee
		);

		IERC20 vaultToken = vaultIndex_ == layoutStruct_.chirWethVaultIndex
			? IERC20(address(layoutStruct_.chirWethVault))
			: IERC20(address(layoutStruct_.richChirVault));
		vaultToken.safeTransfer(address(resPoolData.balV3Vault), vaultShares_);
		layoutStruct_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut_, "");
		ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
	}

}