// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {DETFPreviewLib} from "contracts/vaults/detf/core/DETFPreviewLib.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {EthereumProtocolDETFCommon} from "contracts/vaults/protocol/EthereumProtocolDETFCommon.sol";
import {
	BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {BaseProtocolDETFPreviewHelpers} from "contracts/vaults/protocol/BaseProtocolDETFPreviewHelpers.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
	BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {
	PREVIEW_BUFFER_DENOMINATOR,
	PREVIEW_RICHIR_BUFFER_BPS,
	PREVIEW_BPT_BUFFER_DENOMINATOR,
	PREVIEW_BPT_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";

contract EthereumProtocolDETFExchangeInQueryTarget is EthereumProtocolDETFCommon {
	using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;
	using FixedPoint for uint256;

	uint256 private constant DIRECT_PREVIEW_EXTRA_BUFFER_BPS = 20;
	uint256 private constant RICHIR_REDEMPTION_PREVIEW_BUFFER_BPS = 1750;

	error PreviewRouteNotSupported();

	struct ReservePoolBptPreview {
		uint256[] balancesRaw;
		uint256 bptOut;
		uint256 poolSupply;
		uint256 chirIdx;
		uint256 richIdx;
	}

	function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
		external
		view
		returns (uint256 amountOut)
	{
		BaseProtocolDETFRepo.Storage storage layoutStruct = BaseProtocolDETFRepo._layoutStruct();

		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}

		PoolReserves memory reserves;
		_loadPoolReserves(layoutStruct, reserves);
		uint256 syntheticPrice = _calcSyntheticPrice(reserves);

		if (_isChirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
			if (!_isBurningAllowed(layoutStruct, syntheticPrice)) {
				revert BurningNotAllowed(syntheticPrice, layoutStruct.burnThreshold);
			}
			return _previewChirRedemption(layoutStruct, amountIn);
		}

		if (_isWethToken(layoutStruct, tokenIn) && _isChirToken(tokenOut)) {
			if (!_isMintingAllowed(layoutStruct, syntheticPrice)) {
				revert MintingNotAllowed(syntheticPrice, layoutStruct.mintThreshold);
			}
			return _previewMintChirFromWeth(layoutStruct, amountIn);
		}

		if (_isRichToken(layoutStruct, tokenIn) && _isChirToken(tokenOut)) {
			if (!_isMintingAllowed(layoutStruct, syntheticPrice)) {
				revert MintingNotAllowed(syntheticPrice, layoutStruct.mintThreshold);
			}

			uint256 chirOut = layoutStruct.richChirVault.previewExchangeIn(tokenIn, amountIn, IERC20(address(this)));
			uint256 wethOut = layoutStruct.chirWethVault.previewExchangeIn(IERC20(address(this)), chirOut, layoutStruct.wethToken);
			return _previewMintChirFromWeth(layoutStruct, wethOut);
		}

		if (_isRichirToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
			return _previewRichirToWeth(layoutStruct, amountIn);
		}

		if (_isRichToken(layoutStruct, tokenIn) && _isRichirToken(layoutStruct, tokenOut)) {
			return _previewRichToRichir(layoutStruct, amountIn);
		}

		if (_isWethToken(layoutStruct, tokenIn) && _isRichirToken(layoutStruct, tokenOut)) {
			return _previewWethToRichir(layoutStruct, amountIn);
		}

		if (_isWethToken(layoutStruct, tokenOut) && (address(tokenIn) == address(_reservePool()) || address(tokenIn) == address(ERC4626Repo._reserveAsset()))) {
			return _previewBptToWeth(layoutStruct, amountIn);
		}

		if (_isWethToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) {
			return _previewWethToRich(layoutStruct, amountIn);
		}

		if (_isRichToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
			return _previewRichToWeth(layoutStruct, amountIn);
		}

		revert InvalidToken(tokenIn);
	}

	function _previewBptToWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 bptAmount)
		internal
		view
		returns (uint256 wethOut)
	{
		if (bptAmount == 0) {
			return 0;
		}

		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _previewChirRedemptionReserveShares(layoutStruct_, bptAmount);
		wethOut = _previewChirRedemptionUnwind(layoutStruct_, chirWethVaultSharesOut, richChirVaultSharesOut);
	}

	function _previewChirRedemption(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 amountIn_)
		internal
		view
		returns (uint256 amountOut_)
	{
		uint256 bptIn = _previewChirRedemptionBptIn(amountIn_);
		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _previewChirRedemptionReserveShares(layoutStruct_, bptIn);
		amountOut_ = _previewChirRedemptionUnwind(layoutStruct_, chirWethVaultSharesOut, richChirVaultSharesOut);
	}

	function _previewRichirToWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 richirAmount_)
		internal
		view
		returns (uint256 amountOut_)
	{
		uint256 bptIn = _previewRichirRedemptionBptIn(layoutStruct_, richirAmount_);
		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
			_previewChirRedemptionReserveShares(layoutStruct_, bptIn);
		amountOut_ = _previewRichirRedemptionUnwind(layoutStruct_, chirWethVaultSharesOut, richChirVaultSharesOut);
	}

	function _previewRichirRedemptionBptIn(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 richirAmount_)
		internal
		view
		returns (uint256 bptIn_)
	{
		uint256 richirShares = layoutStruct_.richirToken.convertToShares(richirAmount_);
		uint256 totalRichirShares = layoutStruct_.richirToken.totalShares();
		uint256 protocolNftBpt = layoutStruct_.protocolNFTVault.originalSharesOf(layoutStruct_.protocolNFTId);
		bptIn_ = (richirShares * protocolNftBpt) / totalRichirShares;
	}

	function _previewChirRedemptionBptIn(uint256 amountIn_) internal view virtual returns (uint256 bptIn_) {
		uint256 chirTotalSupply = ERC20Repo._totalSupply();
		if (chirTotalSupply == 0) {
			revert ZeroAmount();
		}

		uint256 bptHeld = IERC20(address(_reservePool())).balanceOf(address(this));
		if (bptHeld == 0) {
			revert ZeroAmount();
		}

		bptIn_ = (amountIn_ * bptHeld) / chirTotalSupply;
		if (bptIn_ == 0) {
			revert ZeroAmount();
		}
	}

	function _previewChirRedemptionReserveShares(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 bptIn_)
		internal
		view
		returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
	{
		ReservePoolData memory resPoolData;
		(, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
		if (resPoolData.resPoolTotalSupply == 0) {
			revert ZeroAmount();
		}

		uint256[] memory amountsOut = BalancerV38020WeightedPoolMath.calcProportionalAmountsOutGivenBptIn(
			currentBalancesRaw,
			resPoolData.resPoolTotalSupply,
			bptIn_
		);

		chirWethVaultSharesOut_ = amountsOut[layoutStruct_.chirWethVaultIndex];
		richChirVaultSharesOut_ = amountsOut[layoutStruct_.richChirVaultIndex];
	}

	function _previewChirRedemptionUnwind(
		BaseProtocolDETFRepo.Storage storage layoutStruct_,
		uint256 chirWethVaultSharesOut_,
		uint256 richChirVaultSharesOut_
	) internal view returns (uint256 amountOut_) {
		uint256 wethFromChirWeth =
			layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(layoutStruct_.chirWethVault)), chirWethVaultSharesOut_, layoutStruct_.wethToken);

		uint256 chirFromRichChir =
			layoutStruct_.richChirVault.previewExchangeIn(IERC20(address(layoutStruct_.richChirVault)), richChirVaultSharesOut_, IERC20(address(this)));

		uint256 wethFromChirSwap = _previewChirSwapAfterChirWethUnwind(layoutStruct_, wethFromChirWeth, chirFromRichChir);
		amountOut_ = wethFromChirWeth + wethFromChirSwap;
	}

	function _previewRichirRedemptionUnwind(
		BaseProtocolDETFRepo.Storage storage layoutStruct_,
		uint256 chirWethVaultSharesOut_,
		uint256 richChirVaultSharesOut_
	) internal view returns (uint256 amountOut_) {
		uint256 wethFromChirWeth = layoutStruct_.chirWethVault.previewExchangeIn(
			IERC20(address(layoutStruct_.chirWethVault)), chirWethVaultSharesOut_, layoutStruct_.wethToken
		);

		(, uint256 chirFromBurn) = _previewRichChirVaultBurn(layoutStruct_, richChirVaultSharesOut_);

		uint256 wethFromChirSwap =
			layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), chirFromBurn, layoutStruct_.wethToken);

		amountOut_ = wethFromChirWeth + wethFromChirSwap;
		amountOut_ = DETFPreviewLib._applyDiscountBps(
			amountOut_, RICHIR_REDEMPTION_PREVIEW_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR
		);
	}

	function _previewRichChirVaultBurn(
		BaseProtocolDETFRepo.Storage storage layoutStruct_,
		uint256 richChirVaultSharesOut_
	) internal view returns (uint256 richOut_, uint256 chirOut_) {
		IERC20 richChirVaultToken = IERC20(address(layoutStruct_.richChirVault));
		IERC20 lpToken = IERC20(IERC4626(address(layoutStruct_.richChirVault)).asset());
		uint256 lpOut =
			layoutStruct_.richChirVault.previewExchangeIn(richChirVaultToken, richChirVaultSharesOut_, lpToken);

		IUniswapV2Pair pool = IUniswapV2Pair(address(lpToken));
		(uint256 reserve0, uint256 reserve1,) = pool.getReserves();
		uint256 totalSupply = lpToken.totalSupply();

		if (pool.token0() == address(layoutStruct_.richToken)) {
			richOut_ = (lpOut * reserve0) / totalSupply;
			chirOut_ = (lpOut * reserve1) / totalSupply;
		} else {
			richOut_ = (lpOut * reserve1) / totalSupply;
			chirOut_ = (lpOut * reserve0) / totalSupply;
		}
	}

	function _previewRichToRichir(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 richIn_)
		internal
		view
		returns (uint256 richirOut_)
	{
		richirOut_ = _previewDepositToRichir(layoutStruct_, layoutStruct_.richChirVault, layoutStruct_.richToken, richIn_, layoutStruct_.richChirVaultIndex);
	}

	/**
	 * @notice Previews the direct WETH -> RICHIR deposit route.
	 * @dev Models the same direct CHIR/WETH vault deposit used by execution.
	 *      This path does not preview any synthetic CHIR mint because the route
	 *      deposits WETH directly into the CHIR/WETH vault before reserve-pool routing.
	 * @param layoutStruct_ Storage layoutStruct reference
	 * @param wethIn_ Amount of WETH deposited
	 * @return richirOut_ Expected RICHIR output
	 */
	function _previewWethToRichir(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 wethIn_)
		internal
		view
		returns (uint256 richirOut_)
	{
		richirOut_ = _previewDepositToRichir(
			layoutStruct_,
			layoutStruct_.chirWethVault,
			layoutStruct_.wethToken,
			wethIn_,
			layoutStruct_.chirWethVaultIndex
		);
	}

	function _previewDepositToRichir(
		BaseProtocolDETFRepo.Storage storage layoutStruct_,
		IStandardExchange vault_,
		IERC20 tokenIn_,
		uint256 amountIn_,
		uint256 vaultIndex_
	) internal view returns (uint256 richirOut_) {
		if (amountIn_ == 0) {
			return 0;
		}

		uint256 vaultShares = _previewVaultSharesPostCompound(vault_, tokenIn_, amountIn_);
		ReservePoolBptPreview memory p = _previewReservePoolBptOut(layoutStruct_, vaultIndex_, vaultShares);

		ReservePoolData memory resPoolData;
		_loadReservePoolData(resPoolData, new uint256[](0));

		BaseProtocolDETFPreviewHelpers.RichirCalc memory calc = BaseProtocolDETFPreviewHelpers.RichirCalc({
			balV3Vault: address(resPoolData.balV3Vault),
			reservePool: address(resPoolData.reservePool),
			reservePoolSwapFee: resPoolData.reservePoolSwapFee,
			weightsArray: resPoolData.weightsArray,
			chirWethVault: address(layoutStruct_.chirWethVault),
			richChirVault: address(layoutStruct_.richChirVault),
			chirToken: address(this),
			wethToken: address(layoutStruct_.wethToken),
			poolBalsRaw: p.balancesRaw,
			chirIdx: p.chirIdx,
			richIdx: p.richIdx,
			vaultIdx: vaultIndex_,
			sharesAdded: vaultShares,
			poolSupply: p.poolSupply,
			bptAdded: p.bptOut,
			newPosShares: layoutStruct_.protocolNFTVault.getPosition(layoutStruct_.protocolNFTId).originalShares + p.bptOut,
			newTotShares: layoutStruct_.richirToken.totalShares() + p.bptOut
		});

		richirOut_ = BaseProtocolDETFPreviewHelpers.computeRichirOutFromDeposit(calc);
		richirOut_ = DETFPreviewLib._applyDiscountBps(richirOut_, PREVIEW_RICHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR);

		if (_buildCompoundSim(vault_).compoundLP == 0) {
			richirOut_ = DETFPreviewLib._applyDiscountBps(
				richirOut_, DIRECT_PREVIEW_EXTRA_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR
			);
		}
	}

	function _previewReservePoolBptOut(
		BaseProtocolDETFRepo.Storage storage,
		uint256 vaultIndex_,
		uint256 vaultShares_
	) internal view returns (ReservePoolBptPreview memory p_) {
		ReservePoolData memory resPoolData;
		IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
		address pool = address(ERC4626Repo._reserveAsset());
		(, TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw,) = balV3Vault.getPoolTokenInfo(pool);

		_loadReservePoolData(resPoolData, currentBalancesRaw);

		uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
		for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
			balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
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

		p_.balancesRaw = currentBalancesRaw;
		p_.bptOut = bptOut;
		p_.poolSupply = resPoolData.resPoolTotalSupply;
		p_.chirIdx = resPoolData.chirWethVaultIndex;
		p_.richIdx = resPoolData.richChirVaultIndex;
	}

	function _previewWethToRich(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 wethIn_)
		internal
		view
		returns (uint256 richOut_)
	{
		richOut_ = _previewSwapViaChir(layoutStruct_, layoutStruct_.chirWethVault, layoutStruct_.wethToken, wethIn_, layoutStruct_.richChirVault, layoutStruct_.richToken);
	}

	function _previewRichToWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 richIn_)
		internal
		view
		returns (uint256 wethOut_)
	{
		wethOut_ = _previewSwapViaChir(layoutStruct_, layoutStruct_.richChirVault, layoutStruct_.richToken, richIn_, layoutStruct_.chirWethVault, layoutStruct_.wethToken);
	}

	function _previewSwapViaChir(
		BaseProtocolDETFRepo.Storage storage,
		IStandardExchange vaultIn_,
		IERC20 tokenIn_,
		uint256 amountIn_,
		IStandardExchange vaultOut_,
		IERC20 tokenOut_
	) internal view returns (uint256 amountOut_) {
		if (amountIn_ == 0) {
			return 0;
		}

		uint256 chirOut = vaultIn_.previewExchangeIn(tokenIn_, amountIn_, IERC20(address(this)));
		amountOut_ = vaultOut_.previewExchangeIn(IERC20(address(this)), chirOut, tokenOut_);
	}

	function _previewMintChirFromWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 wethIn_)
		internal
		view
		returns (uint256 chirOut_)
	{
		IUniswapV2Pair chirWethPool = IUniswapV2Pair(address(IERC4626(address(layoutStruct_.chirWethVault)).asset()));
		(uint256 reserve0, uint256 reserve1,) = chirWethPool.getReserves();
		address token0 = chirWethPool.token0();

		uint256 wethReserve;
		uint256 chirReserve;
		if (token0 == address(layoutStruct_.wethToken)) {
			wethReserve = reserve0;
			chirReserve = reserve1;
		} else {
			wethReserve = reserve1;
			chirReserve = reserve0;
		}

		uint256 swapFeePercent = _poolSwapFeePercent(address(chirWethPool));
		uint256 seignioragePct = layoutStruct_._feeOracle().seigniorageIncentivePercentageOfVault(address(this));
		uint256 wethWithIncentive = wethIn_ + (wethIn_ * seignioragePct / FixedPoint.ONE);
		uint256 baseChir = ConstProdUtils._saleQuote(wethWithIncentive, wethReserve, chirReserve, swapFeePercent);
		chirOut_ = baseChir * (FixedPoint.ONE - seignioragePct / 2) / FixedPoint.ONE;
	}

	function _previewChirSwapAfterChirWethUnwind(
		BaseProtocolDETFRepo.Storage storage layoutStruct_,
		uint256 wethFromChirWeth_,
		uint256 chirIn_
	) internal view returns (uint256 wethOut_) {
		if (chirIn_ == 0) {
			return 0;
		}

		IUniswapV2Pair chirWethPool = IUniswapV2Pair(address(IERC4626(address(layoutStruct_.chirWethVault)).asset()));
		(uint256 reserve0, uint256 reserve1,) = chirWethPool.getReserves();

		uint256 wethReserve;
		uint256 chirReserve;
		if (chirWethPool.token0() == address(layoutStruct_.wethToken)) {
			wethReserve = reserve0;
			chirReserve = reserve1;
		} else {
			wethReserve = reserve1;
			chirReserve = reserve0;
		}

		if (wethFromChirWeth_ >= wethReserve) {
			return 0;
		}

		uint256 swapFeePercent = _poolSwapFeePercent(address(chirWethPool));
		uint256 postUnwindWethReserve = wethReserve - wethFromChirWeth_;
		wethOut_ = ConstProdUtils._saleQuote(chirIn_, chirReserve, postUnwindWethReserve, swapFeePercent);
	}

}