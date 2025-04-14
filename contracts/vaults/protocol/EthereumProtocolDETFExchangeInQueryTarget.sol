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
		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}

		PoolReserves memory reserves;
		_loadPoolReserves(layout, reserves);
		uint256 syntheticPrice = _calcSyntheticPrice(reserves);

		if (_isChirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
			if (!_isBurningAllowed(layout, syntheticPrice)) {
				revert BurningNotAllowed(syntheticPrice, layout.burnThreshold);
			}
			return _previewChirRedemption(layout, amountIn);
		}

		if (_isWethToken(layout, tokenIn) && _isChirToken(tokenOut)) {
			if (!_isMintingAllowed(layout, syntheticPrice)) {
				revert MintingNotAllowed(syntheticPrice, layout.mintThreshold);
			}
			return _previewMintChirFromWeth(layout, amountIn);
		}

		if (_isRichToken(layout, tokenIn) && _isChirToken(tokenOut)) {
			if (!_isMintingAllowed(layout, syntheticPrice)) {
				revert MintingNotAllowed(syntheticPrice, layout.mintThreshold);
			}

			uint256 chirOut = layout.richChirVault.previewExchangeIn(tokenIn, amountIn, IERC20(address(this)));
			uint256 wethOut = layout.chirWethVault.previewExchangeIn(IERC20(address(this)), chirOut, layout.wethToken);
			return _previewMintChirFromWeth(layout, wethOut);
		}

		if (_isRichirToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
			return _previewRichirToWeth(layout, amountIn);
		}

		if (_isRichToken(layout, tokenIn) && _isRichirToken(layout, tokenOut)) {
			return _previewRichToRichir(layout, amountIn);
		}

		if (_isWethToken(layout, tokenIn) && _isRichirToken(layout, tokenOut)) {
			return _previewWethToRichir(layout, amountIn);
		}

		if (_isWethToken(layout, tokenOut) && (address(tokenIn) == address(_reservePool()) || address(tokenIn) == address(ERC4626Repo._reserveAsset()))) {
			return _previewBptToWeth(layout, amountIn);
		}

		if (_isWethToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) {
			return _previewWethToRich(layout, amountIn);
		}

		if (_isRichToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
			return _previewRichToWeth(layout, amountIn);
		}

		revert InvalidToken(tokenIn);
	}

	function _previewBptToWeth(BaseProtocolDETFRepo.Storage storage layout_, uint256 bptAmount)
		internal
		view
		returns (uint256 wethOut)
	{
		if (bptAmount == 0) {
			return 0;
		}

		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _previewChirRedemptionReserveShares(layout_, bptAmount);
		wethOut = _previewChirRedemptionUnwind(layout_, chirWethVaultSharesOut, richChirVaultSharesOut);
	}

	function _previewChirRedemption(BaseProtocolDETFRepo.Storage storage layout_, uint256 amountIn_)
		internal
		view
		returns (uint256 amountOut_)
	{
		uint256 bptIn = _previewChirRedemptionBptIn(amountIn_);
		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _previewChirRedemptionReserveShares(layout_, bptIn);
		amountOut_ = _previewChirRedemptionUnwind(layout_, chirWethVaultSharesOut, richChirVaultSharesOut);
	}

	function _previewRichirToWeth(BaseProtocolDETFRepo.Storage storage layout_, uint256 richirAmount_)
		internal
		view
		returns (uint256 amountOut_)
	{
		uint256 bptIn = _previewRichirRedemptionBptIn(layout_, richirAmount_);
		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
			_previewChirRedemptionReserveShares(layout_, bptIn);
		amountOut_ = _previewRichirRedemptionUnwind(layout_, chirWethVaultSharesOut, richChirVaultSharesOut);
	}

	function _previewRichirRedemptionBptIn(BaseProtocolDETFRepo.Storage storage layout_, uint256 richirAmount_)
		internal
		view
		returns (uint256 bptIn_)
	{
		uint256 richirShares = layout_.richirToken.convertToShares(richirAmount_);
		uint256 totalRichirShares = layout_.richirToken.totalShares();
		uint256 protocolNftBpt = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId);
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

	function _previewChirRedemptionReserveShares(BaseProtocolDETFRepo.Storage storage layout_, uint256 bptIn_)
		internal
		view
		returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
	{
		ReservePoolData memory resPoolData;
		uint256[] memory currentBalancesRaw = _loadReservePoolData(resPoolData, new uint256[](0));
		if (resPoolData.resPoolTotalSupply == 0) {
			revert ZeroAmount();
		}

		chirWethVaultSharesOut_ = (currentBalancesRaw[layout_.chirWethVaultIndex] * bptIn_) / resPoolData.resPoolTotalSupply;
		richChirVaultSharesOut_ = (currentBalancesRaw[layout_.richChirVaultIndex] * bptIn_) / resPoolData.resPoolTotalSupply;
	}

	function _previewChirRedemptionUnwind(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 chirWethVaultSharesOut_,
		uint256 richChirVaultSharesOut_
	) internal view returns (uint256 amountOut_) {
		uint256 wethFromChirWeth = layout_.chirWethVault.previewExchangeIn(IERC20(address(layout_.chirWethVault)), chirWethVaultSharesOut_, layout_.wethToken);
		uint256 chirFromRichChir = layout_.richChirVault.previewExchangeIn(IERC20(address(layout_.richChirVault)), richChirVaultSharesOut_, IERC20(address(this)));
		uint256 wethFromChirSwap = layout_.chirWethVault.previewExchangeIn(IERC20(address(this)), chirFromRichChir, layout_.wethToken);
		amountOut_ = wethFromChirWeth + wethFromChirSwap;
	}

	function _previewRichirRedemptionUnwind(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 chirWethVaultSharesOut_,
		uint256 richChirVaultSharesOut_
	) internal view returns (uint256 amountOut_) {
		uint256 wethFromChirWeth = layout_.chirWethVault.previewExchangeIn(
			IERC20(address(layout_.chirWethVault)), chirWethVaultSharesOut_, layout_.wethToken
		);

		(, uint256 chirFromBurn) = _previewRichChirVaultBurn(layout_, richChirVaultSharesOut_);

		uint256 wethFromChirSwap =
			layout_.chirWethVault.previewExchangeIn(IERC20(address(this)), chirFromBurn, layout_.wethToken);

		amountOut_ = wethFromChirWeth + wethFromChirSwap;
		amountOut_ = amountOut_ - ((amountOut_ * RICHIR_REDEMPTION_PREVIEW_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
	}

	function _previewRichChirVaultBurn(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 richChirVaultSharesOut_
	) internal view returns (uint256 richOut_, uint256 chirOut_) {
		IERC20 richChirVaultToken = IERC20(address(layout_.richChirVault));
		IERC20 lpToken = IERC20(IERC4626(address(layout_.richChirVault)).asset());
		uint256 lpOut =
			layout_.richChirVault.previewExchangeIn(richChirVaultToken, richChirVaultSharesOut_, lpToken);

		IUniswapV2Pair pool = IUniswapV2Pair(address(lpToken));
		(uint256 reserve0, uint256 reserve1,) = pool.getReserves();
		uint256 totalSupply = lpToken.totalSupply();

		if (pool.token0() == address(layout_.richToken)) {
			richOut_ = (lpOut * reserve0) / totalSupply;
			chirOut_ = (lpOut * reserve1) / totalSupply;
		} else {
			richOut_ = (lpOut * reserve1) / totalSupply;
			chirOut_ = (lpOut * reserve0) / totalSupply;
		}
	}

	function _previewRichToRichir(BaseProtocolDETFRepo.Storage storage layout_, uint256 richIn_)
		internal
		view
		returns (uint256 richirOut_)
	{
		richirOut_ = _previewDepositToRichir(layout_, layout_.richChirVault, layout_.richToken, richIn_, layout_.richChirVaultIndex);
	}

	function _previewWethToRichir(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
		internal
		view
		returns (uint256 richirOut_)
	{
		if (wethIn_ == 0) {
			return 0;
		}

		uint256 vaultShares = _previewBalancedChirWethVaultShares(layout_, wethIn_);
		ReservePoolBptPreview memory p = _previewReservePoolBptOut(layout_, layout_.chirWethVaultIndex, vaultShares);

		ReservePoolData memory resPoolData;
		_loadReservePoolData(resPoolData, new uint256[](0));

		BaseProtocolDETFPreviewHelpers.RichirCalc memory calc = BaseProtocolDETFPreviewHelpers.RichirCalc({
			balV3Vault: address(resPoolData.balV3Vault),
			reservePool: address(resPoolData.reservePool),
			reservePoolSwapFee: resPoolData.reservePoolSwapFee,
			weightsArray: resPoolData.weightsArray,
			chirWethVault: address(layout_.chirWethVault),
			richChirVault: address(layout_.richChirVault),
			chirToken: address(this),
			wethToken: address(layout_.wethToken),
			poolBalsRaw: p.balancesRaw,
			chirIdx: p.chirIdx,
			richIdx: p.richIdx,
			vaultIdx: layout_.chirWethVaultIndex,
			sharesAdded: vaultShares,
			poolSupply: p.poolSupply,
			bptAdded: p.bptOut,
			newPosShares: layout_.protocolNFTVault.getPosition(layout_.protocolNFTId).originalShares + p.bptOut,
			newTotShares: layout_.richirToken.totalShares() + p.bptOut
		});

		richirOut_ = BaseProtocolDETFPreviewHelpers.computeRichirOutFromDeposit(calc);
		richirOut_ = richirOut_ - ((richirOut_ * PREVIEW_RICHIR_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);

		if (_buildCompoundSim(layout_.chirWethVault).compoundLP == 0) {
			richirOut_ = richirOut_ - ((richirOut_ * DIRECT_PREVIEW_EXTRA_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
		}
	}

	function _previewDepositToRichir(
		BaseProtocolDETFRepo.Storage storage layout_,
		IStandardExchange vault_,
		IERC20 tokenIn_,
		uint256 amountIn_,
		uint256 vaultIndex_
	) internal view returns (uint256 richirOut_) {
		if (amountIn_ == 0) {
			return 0;
		}

		uint256 vaultShares = _previewVaultSharesPostCompound(vault_, tokenIn_, amountIn_);
		ReservePoolBptPreview memory p = _previewReservePoolBptOut(layout_, vaultIndex_, vaultShares);

		ReservePoolData memory resPoolData;
		_loadReservePoolData(resPoolData, new uint256[](0));

		BaseProtocolDETFPreviewHelpers.RichirCalc memory calc = BaseProtocolDETFPreviewHelpers.RichirCalc({
			balV3Vault: address(resPoolData.balV3Vault),
			reservePool: address(resPoolData.reservePool),
			reservePoolSwapFee: resPoolData.reservePoolSwapFee,
			weightsArray: resPoolData.weightsArray,
			chirWethVault: address(layout_.chirWethVault),
			richChirVault: address(layout_.richChirVault),
			chirToken: address(this),
			wethToken: address(layout_.wethToken),
			poolBalsRaw: p.balancesRaw,
			chirIdx: p.chirIdx,
			richIdx: p.richIdx,
			vaultIdx: vaultIndex_,
			sharesAdded: vaultShares,
			poolSupply: p.poolSupply,
			bptAdded: p.bptOut,
			newPosShares: layout_.protocolNFTVault.getPosition(layout_.protocolNFTId).originalShares + p.bptOut,
			newTotShares: layout_.richirToken.totalShares() + p.bptOut
		});

		richirOut_ = BaseProtocolDETFPreviewHelpers.computeRichirOutFromDeposit(calc);
		richirOut_ = richirOut_ - ((richirOut_ * PREVIEW_RICHIR_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);

		if (_buildCompoundSim(vault_).compoundLP == 0) {
			richirOut_ = richirOut_ - ((richirOut_ * DIRECT_PREVIEW_EXTRA_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
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

		bptOut = bptOut - ((bptOut * PREVIEW_BPT_BUFFER_BPS) / PREVIEW_BPT_BUFFER_DENOMINATOR);

		p_.balancesRaw = currentBalancesRaw;
		p_.bptOut = bptOut;
		p_.poolSupply = resPoolData.resPoolTotalSupply;
		p_.chirIdx = resPoolData.chirWethVaultIndex;
		p_.richIdx = resPoolData.richChirVaultIndex;
	}

	function _previewWethToRich(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
		internal
		view
		returns (uint256 richOut_)
	{
		richOut_ = _previewSwapViaChir(layout_, layout_.chirWethVault, layout_.wethToken, wethIn_, layout_.richChirVault, layout_.richToken);
	}

	function _previewRichToWeth(BaseProtocolDETFRepo.Storage storage layout_, uint256 richIn_)
		internal
		view
		returns (uint256 wethOut_)
	{
		wethOut_ = _previewSwapViaChir(layout_, layout_.richChirVault, layout_.richToken, richIn_, layout_.chirWethVault, layout_.wethToken);
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

	function _previewMintChirFromWeth(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
		internal
		view
		returns (uint256 chirOut_)
	{
		IUniswapV2Pair chirWethPool = IUniswapV2Pair(address(IERC4626(address(layout_.chirWethVault)).asset()));
		(uint256 reserve0, uint256 reserve1,) = chirWethPool.getReserves();
		address token0 = chirWethPool.token0();

		uint256 wethReserve;
		uint256 chirReserve;
		if (token0 == address(layout_.wethToken)) {
			wethReserve = reserve0;
			chirReserve = reserve1;
		} else {
			wethReserve = reserve1;
			chirReserve = reserve0;
		}

		uint256 swapFeePercent = _poolSwapFeePercent(address(chirWethPool));
		uint256 seignioragePct = layout_._feeOracle().seigniorageIncentivePercentageOfVault(address(this));
		uint256 wethWithIncentive = wethIn_ + (wethIn_ * seignioragePct / FixedPoint.ONE);
		uint256 baseChir = ConstProdUtils._saleQuote(wethWithIncentive, wethReserve, chirReserve, swapFeePercent);
		chirOut_ = baseChir * (FixedPoint.ONE - seignioragePct / 2) / FixedPoint.ONE;
	}

}