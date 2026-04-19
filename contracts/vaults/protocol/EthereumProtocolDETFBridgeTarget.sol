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

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {SuperchainSenderNonceRepo} from "@crane/contracts/protocols/l2s/superchain/senders/SuperchainSenderNonceRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {ITokenTransferRelayer} from "@crane/contracts/interfaces/ITokenTransferRelayer.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {EthereumProtocolDETFCommon} from "contracts/vaults/protocol/EthereumProtocolDETFCommon.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";

contract EthereumProtocolDETFBridgeTarget is EthereumProtocolDETFCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

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
            execution.peer = ProtocolDETFSuperchainBridgeRepo.PeerConfig({
                relayer: bridgeLayout.defaultPeerRelayer
            });
        }
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
                _addToReservePool(layout, layout.chirWethVaultIndex, execution.chirWethVaultSharesOut);
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

        uint256 bptOut = _addToReservePool(layout_, layout_.richChirVaultIndex, richChirShares);
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

    function _addToReservePool(BaseProtocolDETFRepo.Storage storage layout_, uint256 tokenIndexIn_, uint256 vaultShares)
        internal
        returns (uint256 bptOut)
    {
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