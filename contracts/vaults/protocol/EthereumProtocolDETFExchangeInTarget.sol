// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
	BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {EthereumProtocolDETFCommon} from "contracts/vaults/protocol/EthereumProtocolDETFCommon.sol";
import {
	BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

contract EthereumProtocolDETFExchangeInTarget is EthereumProtocolDETFCommon, ReentrancyLockModifiers {
	using BetterSafeERC20 for IERC20;
	using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

	struct BalancedLiquidityResult {
		uint256 wethUsed;
		uint256 chirUsed;
		uint256 lpMinted;
	}

	struct ExchangeInParams {
		IERC20 tokenIn;
		uint256 amountIn;
		IERC20 tokenOut;
		uint256 minAmountOut;
		address recipient;
		bool pretransferred;
		uint256 deadline;
		uint256 syntheticPrice;
	}

	struct MintCalc {
		uint256 userChir;
		uint256 protocolChir;
	}

	function _depositWethToChirWethVaultViaBalancedLp(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 wethAmount_,
		address wethRefundRecipient_,
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
			layout_.wethToken.safeTransfer(wethRefundRecipient_, wethAmount_ - result.wethUsed);
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

	function exchangeIn(
		IERC20 tokenIn,
		uint256 amountIn,
		IERC20 tokenOut,
		uint256 minAmountOut,
		address recipient,
		bool pretransferred,
		uint256 deadline
	) external lock returns (uint256 amountOut) {
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

		PoolReserves memory reserves;
		_loadPoolReserves(layout, reserves);

		ExchangeInParams memory params = ExchangeInParams({
			tokenIn: tokenIn,
			amountIn: amountIn,
			tokenOut: tokenOut,
			minAmountOut: minAmountOut,
			recipient: recipient == address(0) ? msg.sender : recipient,
			pretransferred: pretransferred,
			deadline: deadline,
			syntheticPrice: _calcSyntheticPrice(reserves)
		});

		if (_isWethToken(layout, tokenIn) && _isChirToken(tokenOut)) {
			return _executeMintWithWeth(layout, params);
		}
		if (_isChirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
			return _executeChirRedemption(layout, params);
		}
		if (_isRichToken(layout, tokenIn) && _isChirToken(tokenOut)) {
			return _executeRichToChir(layout, params);
		}
		if (_isRichirToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
			return _executeRichirRedemption(layout, params);
		}
		if (_isRichToken(layout, tokenIn) && _isRichirToken(layout, tokenOut)) {
			return _executeRichToRichir(layout, params);
		}
		if (_isWethToken(layout, tokenIn) && _isRichirToken(layout, tokenOut)) {
			return _executeWethToRichir(layout, params);
		}
		if (_isWethToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) {
			return _executeWethToRich(layout, params);
		}
		if (_isRichToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
			return _executeRichToWeth(layout, params);
		}

		revert InvalidToken(tokenIn);
	}

	function _executeMintWithWeth(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		if (!_isMintingAllowed(layout_, p_.syntheticPrice)) {
			revert MintingNotAllowed(p_.syntheticPrice, layout_.mintThreshold);
		}

		uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);
		MintCalc memory calc = _calcMintFromWeth(layout_, actualIn);

		p_.tokenIn.safeTransfer(address(layout_.chirWethVault), actualIn);
		uint256 chirWethShares = layout_.chirWethVault.exchangeIn(
			p_.tokenIn, actualIn, IERC20(address(layout_.chirWethVault)), 0, address(this), true, p_.deadline
		);

		if (chirWethShares > 0) {
			_unbalancedDepositChirWethAndAddToProtocolNFT(layout_, chirWethShares);
		}

		if (calc.userChir < p_.minAmountOut) {
			revert SlippageExceeded(p_.minAmountOut, calc.userChir);
		}

		if (calc.protocolChir > 0) {
			ERC20Repo._mint(address(layout_.protocolNFTVault), calc.protocolChir);
			layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, calc.protocolChir);
		}

		ERC20Repo._mint(p_.recipient, calc.userChir);
		amountOut_ = calc.userChir;
	}

	function _calcMintFromWeth(BaseProtocolDETFRepo.Storage storage layout_, uint256 actualIn_)
		internal
		view
		returns (MintCalc memory calc_)
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
		uint256 wethWithIncentive = actualIn_ + (actualIn_ * seignioragePct / FixedPoint.ONE);
		uint256 baseChir = ConstProdUtils._saleQuote(wethWithIncentive, wethReserve, chirReserve, swapFeePercent);

		calc_.userChir = baseChir * (FixedPoint.ONE - seignioragePct / 2) / FixedPoint.ONE;
		calc_.protocolChir = baseChir * seignioragePct / 2 / FixedPoint.ONE;
	}

	function _executeRichToChir(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		if (!_isMintingAllowed(layout_, p_.syntheticPrice)) {
			revert MintingNotAllowed(p_.syntheticPrice, layout_.mintThreshold);
		}

		uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);
		p_.tokenIn.safeTransfer(address(layout_.richChirVault), actualIn);

		uint256 chirOut = layout_.richChirVault
			.exchangeIn(p_.tokenIn, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);

		IERC20(address(this)).safeTransfer(address(layout_.chirWethVault), chirOut);
		uint256 wethOut = layout_.chirWethVault
			.exchangeIn(IERC20(address(this)), chirOut, layout_.wethToken, 0, address(this), true, p_.deadline);

		ExchangeInParams memory mintParams = ExchangeInParams({
			tokenIn: layout_.wethToken,
			amountIn: wethOut,
			tokenOut: IERC20(address(this)),
			minAmountOut: p_.minAmountOut,
			recipient: p_.recipient,
			pretransferred: true,
			deadline: p_.deadline,
			syntheticPrice: p_.syntheticPrice
		});

		amountOut_ = _executeMintWithWeth(layout_, mintParams);
	}

	function _executeRichirRedemption(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		if (!p_.pretransferred) {
			p_.tokenIn.safeTransferFrom(msg.sender, address(this), p_.amountIn);
		}

		uint256 richirBalance = p_.tokenIn.balanceOf(address(this));
		uint256 bptIn = _calcRichirRedemptionBptIn(layout_, richirBalance);

		p_.tokenIn.safeTransfer(address(layout_.richirToken), richirBalance);
		layout_.richirToken.burnShares(richirBalance, address(0), true);

		amountOut_ = _exitRecycleAndUnwindToWeth(layout_, bptIn, p_.deadline);
		if (amountOut_ < p_.minAmountOut) {
			revert SlippageExceeded(p_.minAmountOut, amountOut_);
		}

		layout_.wethToken.safeTransfer(p_.recipient, amountOut_);
	}

	function _calcRichirRedemptionBptIn(BaseProtocolDETFRepo.Storage storage layout_, uint256 richirAmount_)
		internal
		view
		returns (uint256 bptIn_)
	{
		uint256 richirShares = layout_.richirToken.convertToShares(richirAmount_);
		uint256 totalRichirShares = layout_.richirToken.totalShares();
		uint256 protocolNftBpt = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId);
		bptIn_ = (richirShares * protocolNftBpt) / totalRichirShares;
	}

	function _exitRecycleAndUnwindToWeth(BaseProtocolDETFRepo.Storage storage layout_, uint256 bptIn_, uint256 deadline_)
		internal
		returns (uint256 wethOut_)
	{
		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _exitReservePoolProportional(layout_, bptIn_);
		uint256 chirFromRecycle = _recycleRichToReservePool(layout_, richChirVaultSharesOut, deadline_);
		uint256 wethFromChirSwap = _swapChirToWethViaChirWethVault(layout_, chirFromRecycle, deadline_);
		uint256 wethFromChirWeth = _unwindChirWethVaultToWeth(layout_, chirWethVaultSharesOut, deadline_);
		wethOut_ = wethFromChirWeth + wethFromChirSwap;
	}

	function _recycleRichToReservePool(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 richChirVaultSharesIn_,
		uint256 deadline_
	) internal returns (uint256 chirOut_) {
		uint256 lpTokens = _redeemRichChirVaultToLP(layout_, richChirVaultSharesIn_, deadline_);
		(uint256 richOut, uint256 chirFromBurn) = _burnRichChirLP(layout_, lpTokens);
		uint256 newVaultShares = _depositRichToRichChirVault(layout_, richOut, deadline_);
		_unbalancedDepositAndAddToProtocolNFT(layout_, newVaultShares);
		chirOut_ = chirFromBurn;
	}

	function _redeemRichChirVaultToLP(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 vaultSharesIn_,
		uint256 deadline_
	) internal returns (uint256 lpOut_) {
		IERC20 vaultToken = IERC20(address(layout_.richChirVault));
		IERC20 lpToken = IERC20(IERC4626(address(layout_.richChirVault)).asset());
		vaultToken.forceApprove(address(layout_.richChirVault), vaultSharesIn_);
		lpOut_ = layout_.richChirVault.exchangeIn(vaultToken, vaultSharesIn_, lpToken, 0, address(this), false, deadline_);
	}

	function _burnRichChirLP(BaseProtocolDETFRepo.Storage storage layout_, uint256 lpAmount_)
		internal
		returns (uint256 richOut_, uint256 chirOut_)
	{
		IUniswapV2Pair pool = IUniswapV2Pair(address(IERC4626(address(layout_.richChirVault)).asset()));
		IERC20(address(pool)).safeTransfer(address(pool), lpAmount_);
		(uint256 amount0, uint256 amount1) = pool.burn(address(this));
		address token0 = pool.token0();
		if (token0 == address(layout_.richToken)) {
			richOut_ = amount0;
			chirOut_ = amount1;
		} else {
			richOut_ = amount1;
			chirOut_ = amount0;
		}
	}

	function _depositRichToRichChirVault(BaseProtocolDETFRepo.Storage storage layout_, uint256 richIn_, uint256 deadline_)
		internal
		returns (uint256 vaultSharesOut_)
	{
		IERC20 richToken = layout_.richToken;
		IERC20 vaultToken = IERC20(address(layout_.richChirVault));
		richToken.forceApprove(address(layout_.richChirVault), richIn_);
		vaultSharesOut_ = layout_.richChirVault.exchangeIn(richToken, richIn_, vaultToken, 0, address(this), false, deadline_);
	}

	function _unbalancedDepositAndAddToProtocolNFT(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 richChirVaultShares_
	) internal {
		IWeightedPool pool = _reservePool();
		IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
		uint256[] memory exactAmountsIn = new uint256[](2);
		exactAmountsIn[layout_.richChirVaultIndex] = richChirVaultShares_;
		exactAmountsIn[layout_.chirWethVaultIndex] = 0;
		IERC20(address(layout_.richChirVault)).safeTransfer(address(balV3Vault), richChirVaultShares_);
		uint256 bptOut = layout_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(address(pool), exactAmountsIn, 0, "");
		if (bptOut > 0) {
			IERC20(address(pool)).forceApprove(address(layout_.protocolNFTVault), bptOut);
			layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);
		}
	}

	function _unbalancedDepositChirWethAndAddToProtocolNFT(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 chirWethVaultShares_
	) internal {
		IWeightedPool pool = _reservePool();
		IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
		uint256[] memory exactAmountsIn = new uint256[](2);
		exactAmountsIn[layout_.chirWethVaultIndex] = chirWethVaultShares_;
		exactAmountsIn[layout_.richChirVaultIndex] = 0;
		IERC20(address(layout_.chirWethVault)).safeTransfer(address(balV3Vault), chirWethVaultShares_);
		uint256 bptOut = layout_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(address(pool), exactAmountsIn, 0, "");
		if (bptOut > 0) {
			IERC20(address(pool)).forceApprove(address(layout_.protocolNFTVault), bptOut);
			layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);
		}
	}

	function _executeChirRedemption(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		if (!_isBurningAllowed(layout_, p_.syntheticPrice)) {
			revert BurningNotAllowed(p_.syntheticPrice, layout_.burnThreshold);
		}

		uint256 bptIn = _previewChirRedemptionBptIn(p_.amountIn);
		_secureChirBurn(msg.sender, p_.amountIn, p_.pretransferred);
		(uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _exitReservePoolProportional(layout_, bptIn);
		uint256 wethFromChirWeth = _unwindChirWethVaultToWeth(layout_, chirWethVaultSharesOut, p_.deadline);
		uint256 chirFromRichChir = _unwindRichChirVaultToChir(layout_, richChirVaultSharesOut, p_.deadline);
		uint256 wethFromChirSwap = _swapChirToWethViaChirWethVault(layout_, chirFromRichChir, p_.deadline);
		amountOut_ = wethFromChirWeth + wethFromChirSwap;

		if (amountOut_ < p_.minAmountOut) {
			revert SlippageExceeded(p_.minAmountOut, amountOut_);
		}

		layout_.wethToken.safeTransfer(p_.recipient, amountOut_);
	}

	function _exitReservePoolProportional(BaseProtocolDETFRepo.Storage storage layout_, uint256 bptIn_)
		internal
		returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
	{
		IWeightedPool pool = _reservePool();
		IERC20(address(pool)).forceApprove(address(layout_.balancerV3PrepayRouter), bptIn_);
		uint256[] memory minAmountsOut = new uint256[](2);
		uint256[] memory amountsOut = layout_.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(address(pool), bptIn_, minAmountsOut, "");
		chirWethVaultSharesOut_ = amountsOut[layout_.chirWethVaultIndex];
		richChirVaultSharesOut_ = amountsOut[layout_.richChirVaultIndex];
	}

	function _unwindChirWethVaultToWeth(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 chirWethVaultSharesIn_,
		uint256 deadline_
	) internal returns (uint256 wethOut_) {
		IERC20 chirWethVaultToken = IERC20(address(layout_.chirWethVault));
		chirWethVaultToken.forceApprove(address(layout_.chirWethVault), chirWethVaultSharesIn_);
		wethOut_ = layout_.chirWethVault.exchangeIn(chirWethVaultToken, chirWethVaultSharesIn_, layout_.wethToken, 0, address(this), false, deadline_);
	}

	function _unwindRichChirVaultToChir(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 richChirVaultSharesIn_,
		uint256 deadline_
	) internal returns (uint256 chirOut_) {
		IERC20 richChirVaultToken = IERC20(address(layout_.richChirVault));
		richChirVaultToken.forceApprove(address(layout_.richChirVault), richChirVaultSharesIn_);
		chirOut_ = layout_.richChirVault.exchangeIn(richChirVaultToken, richChirVaultSharesIn_, IERC20(address(this)), 0, address(this), false, deadline_);
	}

	function _swapChirToWethViaChirWethVault(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 chirIn_,
		uint256 deadline_
	) internal returns (uint256 wethOut_) {
		IERC20(address(this)).forceApprove(address(layout_.chirWethVault), chirIn_);
		wethOut_ = layout_.chirWethVault.exchangeIn(IERC20(address(this)), chirIn_, layout_.wethToken, 0, address(this), false, deadline_);
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

	function _executeRichToRichir(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);
		p_.tokenIn.safeTransfer(address(layout_.richChirVault), actualIn);
		uint256 richChirShares = layout_.richChirVault.exchangeIn(
			p_.tokenIn, actualIn, IERC20(address(layout_.richChirVault)), 0, address(this), true, p_.deadline
		);

		uint256 bptOut = _addToReservePoolForRichir(layout_, richChirShares, p_.deadline);
		IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
		reservePoolToken.forceApprove(address(layout_.protocolNFTVault), bptOut);
		layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);
		amountOut_ = layout_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

		if (amountOut_ < p_.minAmountOut) {
			revert SlippageExceeded(p_.minAmountOut, amountOut_);
		}
	}

	function _addToReservePoolForRichir(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 vaultShares_,
		uint256 deadline_
	) internal returns (uint256 bptOut_) {
		deadline_;
		ReservePoolData memory resPoolData;
		(TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

		uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
		for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
			balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
		}

		uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[layout_.richChirVaultIndex]);
		uint256[] memory amountsIn = new uint256[](2);
		amountsIn[layout_.richChirVaultIndex] = vaultShares_;

		bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
			balancesLiveScaled18,
			resPoolData.weightsArray,
			layout_.richChirVaultIndex,
			amountInLiveScaled18,
			resPoolData.resPoolTotalSupply,
			resPoolData.reservePoolSwapFee
		);

		IERC20(address(layout_.richChirVault)).safeTransfer(address(resPoolData.balV3Vault), vaultShares_);
		layout_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut_, "");
		ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
	}

	function _executeWethToRichir(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);
		uint256 chirWethShares = _depositWethToChirWethVaultViaBalancedLp(layout_, actualIn, msg.sender, p_.deadline);

		uint256 bptOut = _addToReservePoolForWethToRichir(layout_, chirWethShares, p_.deadline);
		IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
		reservePoolToken.forceApprove(address(layout_.protocolNFTVault), bptOut);
		layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);
		amountOut_ = layout_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

		if (amountOut_ < p_.minAmountOut) {
			revert SlippageExceeded(p_.minAmountOut, amountOut_);
		}
	}

	function _addToReservePoolForWethToRichir(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 vaultShares_,
		uint256 deadline_
	) internal returns (uint256 bptOut_) {
		deadline_;
		ReservePoolData memory resPoolData;
		(TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

		uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
		for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
			balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
		}

		uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[layout_.chirWethVaultIndex]);
		uint256[] memory amountsIn = new uint256[](2);
		amountsIn[layout_.chirWethVaultIndex] = vaultShares_;

		bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
			balancesLiveScaled18,
			resPoolData.weightsArray,
			layout_.chirWethVaultIndex,
			amountInLiveScaled18,
			resPoolData.resPoolTotalSupply,
			resPoolData.reservePoolSwapFee
		);

		IERC20(address(layout_.chirWethVault)).safeTransfer(address(resPoolData.balV3Vault), vaultShares_);
		layout_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut_, "");
		ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
	}

	function _executeWethToRich(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);
		p_.tokenIn.safeTransfer(address(layout_.chirWethVault), actualIn);
		uint256 chirOut = layout_.chirWethVault.exchangeIn(p_.tokenIn, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);
		IERC20(address(this)).safeTransfer(address(layout_.richChirVault), chirOut);
		amountOut_ = layout_.richChirVault.exchangeIn(IERC20(address(this)), chirOut, layout_.richToken, p_.minAmountOut, p_.recipient, true, p_.deadline);
	}

	function _executeRichToWeth(BaseProtocolDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
		internal
		returns (uint256 amountOut_)
	{
		uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);
		p_.tokenIn.safeTransfer(address(layout_.richChirVault), actualIn);
		uint256 chirOut = layout_.richChirVault.exchangeIn(p_.tokenIn, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);
		IERC20(address(this)).safeTransfer(address(layout_.chirWethVault), chirOut);
		amountOut_ = layout_.chirWethVault.exchangeIn(IERC20(address(this)), chirOut, layout_.wethToken, p_.minAmountOut, p_.recipient, true, p_.deadline);
	}

}