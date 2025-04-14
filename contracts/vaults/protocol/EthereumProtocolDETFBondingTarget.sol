// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {SuperchainSenderNonceRepo} from "@crane/contracts/protocols/l2s/superchain/senders/SuperchainSenderNonceRepo.sol";
import {
	BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ITokenTransferRelayer} from "@crane/contracts/interfaces/ITokenTransferRelayer.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {EthereumProtocolDETFCommon} from "contracts/vaults/protocol/EthereumProtocolDETFCommon.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {
	BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";

contract EthereumProtocolDETFBondingTarget is EthereumProtocolDETFCommon, ReentrancyLockModifiers {
	using BetterSafeERC20 for IERC20;
	using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

	struct BalancedLiquidityResult {
		uint256 wethUsed;
		uint256 chirUsed;
		uint256 lpMinted;
	}

	struct BridgeExecution {
		ProtocolDETFSuperchainBridgeRepo.PeerConfig peer;
		IERC20 remoteDetfToken;
		IERC20 remoteRichToken;
		uint256 bridgeMinGasLimit;
		uint256 actualRichirIn;
		uint256 sharesBurned;
		uint256 reserveSharesBurned;
		uint256 chirWethVaultSharesOut;
		uint256 richChirVaultSharesOut;
		uint256 localBptOut;
		uint256 senderNonce;
	}

	event BridgeInitiated(
		address indexed sender,
		uint256 indexed targetChainId,
		address indexed recipient,
		uint256 richirAmountIn,
		uint256 sharesBurned,
		uint256 reserveSharesBurned,
		uint256 localRichirOut,
		uint256 richOut,
		uint256 nonce
	);

	event BridgeReceived(address indexed relayer, address indexed recipient, uint256 richAmount, uint256 richirOut);

	event BridgeDustSent(IERC20 indexed token, address indexed feeTo, uint256 amount);

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

	function initBridge(bytes calldata initData) external lock {
		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}

		ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layout();
		if (
			address(bridgeLayout.messenger) != address(0)
				|| address(bridgeLayout.standardBridge) != address(0)
				|| address(bridgeLayout.bridgeTokenRegistry) != address(0)
				|| bridgeLayout.localRelayer != address(0)
		) {
			revert BridgeConfigAlreadySet();
		}

		ProtocolDETFSuperchainBridgeRepo._initialize(initData);

		if (
			address(bridgeLayout.messenger) == address(0)
				|| address(bridgeLayout.standardBridge) == address(0)
				|| address(bridgeLayout.bridgeTokenRegistry) == address(0)
				|| bridgeLayout.localRelayer == address(0)
		) {
			revert BridgeConfigNotSet();
		}
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

	function bridgeRichir(IProtocolDETF.BridgeArgs calldata args)
		external
		lock
		returns (uint256 localRichirOut, uint256 richOut)
	{
		if (block.timestamp > args.deadline) {
			revert DeadlineExceeded(args.deadline, block.timestamp);
		}

		if (args.richirAmount == 0) {
			revert ZeroAmount();
		}

		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}

		ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layout();
		if (
			address(bridgeLayout.messenger) == address(0)
				|| address(bridgeLayout.standardBridge) == address(0)
				|| address(bridgeLayout.bridgeTokenRegistry) == address(0)
		) {
			revert BridgeConfigNotSet();
		}

		BridgeExecution memory execution;

		execution.peer = bridgeLayout.peers[args.targetChainId];
		if (execution.peer.relayer == address(0)) {
			revert BridgePeerNotConfigured(args.targetChainId);
		}

		execution.remoteDetfToken = bridgeLayout.bridgeTokenRegistry.getRemoteToken(
			args.targetChainId, IERC20(address(this))
		);
		if (address(execution.remoteDetfToken) == address(0)) {
			revert BridgeRemoteTokenNotConfigured(args.targetChainId, IERC20(address(this)));
		}

		(execution.remoteRichToken, execution.bridgeMinGasLimit) =
			bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(args.targetChainId, layout.richToken);
		if (address(execution.remoteRichToken) == address(0)) {
			revert BridgeRemoteTokenNotConfigured(args.targetChainId, layout.richToken);
		}

		uint256 richirBalanceBefore = layout.richirToken.balanceOf(address(this));
		IERC20(address(layout.richirToken)).safeTransferFrom(msg.sender, address(this), args.richirAmount);
		execution.actualRichirIn = layout.richirToken.balanceOf(address(this)) - richirBalanceBefore;

		execution.sharesBurned = layout.richirToken.convertToShares(execution.actualRichirIn);
		execution.reserveSharesBurned = _calcRichirBridgeBptIn(layout, execution.actualRichirIn);

		IERC20(address(layout.richirToken)).safeTransfer(address(layout.richirToken), execution.actualRichirIn);
		layout.richirToken.burnShares(execution.actualRichirIn, address(0), true);

		(execution.chirWethVaultSharesOut, execution.richChirVaultSharesOut) =
			_exitReservePoolProportionalForBridge(layout, execution.reserveSharesBurned);

		if (execution.chirWethVaultSharesOut > 0) {
			execution.localBptOut =
				_addToReservePool(layout, layout.chirWethVaultIndex, execution.chirWethVaultSharesOut, args.deadline);
			if (execution.localBptOut > 0) {
				IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
				reservePoolToken.forceApprove(address(layout.protocolNFTVault), execution.localBptOut);
				layout.protocolNFTVault.addToProtocolNFT(layout.protocolNFTId, execution.localBptOut);
				localRichirOut = layout.richirToken.mintFromNFTSale(execution.localBptOut, msg.sender);
			}
		}

		if (localRichirOut < args.minLocalRichirOut) {
			revert SlippageExceeded(args.minLocalRichirOut, localRichirOut);
		}

		if (execution.richChirVaultSharesOut > 0) {
			IERC20 richChirVaultToken = IERC20(address(layout.richChirVault));
			richChirVaultToken.forceApprove(address(layout.richChirVault), execution.richChirVaultSharesOut);
			richOut = layout.richChirVault.exchangeIn(
				richChirVaultToken,
				execution.richChirVaultSharesOut,
				layout.richToken,
				0,
				address(this),
				false,
				args.deadline
			);
		}

		if (richOut < args.minRichOut) {
			revert SlippageExceeded(args.minRichOut, richOut);
		}

		execution.senderNonce = SuperchainSenderNonceRepo._useNonce(address(this), args.targetChainId);

		layout.richToken.forceApprove(address(bridgeLayout.standardBridge), richOut);
		bridgeLayout.standardBridge.bridgeERC20To(
			address(layout.richToken),
			address(execution.remoteRichToken),
			execution.peer.relayer,
			richOut,
			uint32(execution.bridgeMinGasLimit),
			bytes("")
		);

		bytes memory receiveData = abi.encodeCall(
			IProtocolDETF.receiveBridgedRich,
			(args.recipient == address(0) ? msg.sender : args.recipient, richOut, args.deadline)
		);
		bytes memory relayData = abi.encodeCall(
			ITokenTransferRelayer.relayTokenTransfer,
			(
				address(execution.remoteDetfToken),
				execution.remoteRichToken,
				richOut,
				execution.senderNonce,
				false,
				false,
				receiveData
			)
		);
		bridgeLayout.messenger.sendMessage(execution.peer.relayer, relayData, args.messageGasLimit);

		_sweepBridgeRichDust(layout);

		emit BridgeInitiated(
			msg.sender,
			args.targetChainId,
			args.recipient == address(0) ? msg.sender : args.recipient,
			execution.actualRichirIn,
			execution.sharesBurned,
			execution.reserveSharesBurned,
			localRichirOut,
			richOut,
			execution.senderNonce
		);
	}

	function receiveBridgedRich(address recipient, uint256 richAmount, uint256 deadline)
		external
		lock
		returns (uint256 richirOut)
	{
		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
		address expectedRelayer = ProtocolDETFSuperchainBridgeRepo._localRelayer();

		if (expectedRelayer == address(0)) {
			revert BridgeConfigNotSet();
		}

		if (msg.sender != expectedRelayer) {
			revert NotBridgeRelayer(msg.sender, expectedRelayer);
		}

		recipient = recipient == address(0) ? msg.sender : recipient;
		richirOut = _receiveBridgedRichToRichir(layout, richAmount, recipient, deadline);

		emit BridgeReceived(msg.sender, recipient, richAmount, richirOut);
	}

	function _receiveBridgedRichToRichir(
		BaseProtocolDETFRepo.Storage storage layout_,
		uint256 richAmount_,
		address recipient_,
		uint256 deadline_
	) internal returns (uint256 richirOut_) {
		uint256 actualIn = _secureTokenTransfer(layout_.richToken, richAmount_, false);

		layout_.richToken.safeTransfer(address(layout_.richChirVault), actualIn);
		uint256 richChirShares = layout_.richChirVault.exchangeIn(
			layout_.richToken,
			actualIn,
			IERC20(address(layout_.richChirVault)),
			0,
			address(this),
			true,
			deadline_
		);

		uint256 bptOut = _addToReservePool(layout_, layout_.richChirVaultIndex, richChirShares, deadline_);
		IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
		reservePoolToken.forceApprove(address(layout_.protocolNFTVault), bptOut);
		layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);

		richirOut_ = layout_.richirToken.mintFromNFTSale(bptOut, recipient_);
	}

	function _calcRichirBridgeBptIn(BaseProtocolDETFRepo.Storage storage layout_, uint256 richirAmount_)
		internal
		view
		returns (uint256 bptIn_)
	{
		uint256 richirShares = layout_.richirToken.convertToShares(richirAmount_);
		uint256 totalRichirShares = layout_.richirToken.totalShares();
		uint256 protocolNftBpt = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId);
		bptIn_ = (richirShares * protocolNftBpt) / totalRichirShares;
	}

	function _exitReservePoolProportionalForBridge(BaseProtocolDETFRepo.Storage storage layout_, uint256 bptIn_)
		internal
		returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
	{
		IWeightedPool pool = _reservePool();
		IERC20(address(pool)).forceApprove(address(layout_.balancerV3PrepayRouter), bptIn_);
		uint256[] memory minAmountsOut = new uint256[](2);
		uint256[] memory amountsOut =
			layout_.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(address(pool), bptIn_, minAmountsOut, "");
		chirWethVaultSharesOut_ = amountsOut[layout_.chirWethVaultIndex];
		richChirVaultSharesOut_ = amountsOut[layout_.richChirVaultIndex];
	}

	function _sweepBridgeRichDust(BaseProtocolDETFRepo.Storage storage layout_) internal {
		uint256 richDust = layout_.richToken.balanceOf(address(this));
		if (richDust == 0) {
			return;
		}

		address feeTo = address(layout_._feeOracle().feeTo());
		layout_.richToken.safeTransfer(feeTo, richDust);
		emit BridgeDustSent(layout_.richToken, feeTo, richDust);
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

	function bondWithWeth(uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)
		external
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

		layout.wethToken.safeTransferFrom(msg.sender, address(this), amountIn);
		uint256 chirWethShares = _depositWethToChirWethVaultViaBalancedLp(layout, amountIn, msg.sender, deadline);
		shares = _addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, deadline);
		tokenId = layout.protocolNFTVault.createPosition(shares, lockDuration, recipient);
	}

	function bondWithRich(uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)
		external
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

		layout.richToken.safeTransferFrom(msg.sender, address(this), amountIn);
		layout.richToken.safeTransfer(address(layout.richChirVault), amountIn);
		uint256 richChirShares = layout.richChirVault.exchangeIn(
			layout.richToken, amountIn, IERC20(address(layout.richChirVault)), 0, address(this), true, deadline
		);
		shares = _addToReservePool(layout, layout.richChirVaultIndex, richChirShares, deadline);
		tokenId = layout.protocolNFTVault.createPosition(shares, lockDuration, recipient);
	}

	function captureSeigniorage() external lock returns (uint256 bptReceived) {
		BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
		if (!_isInitialized()) {
			revert ReservePoolNotInitialized();
		}

		uint256 chirBalance = ERC20Repo._balanceOf(address(layout.protocolNFTVault));
		if (chirBalance == 0) {
			revert NoSeigniorageToCapture();
		}

		IERC20(address(this)).safeTransferFrom(address(layout.protocolNFTVault), address(this), chirBalance);
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