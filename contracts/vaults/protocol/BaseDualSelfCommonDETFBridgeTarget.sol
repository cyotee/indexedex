// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
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
import {DETFBondLifecycleLib} from "contracts/vaults/detf/core/DETFBondLifecycleLib.sol";
import {BaseDualSelfCommonDETFRepo} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRepo.sol";
import {BaseDualSelfCommonDETFCommon} from "contracts/vaults/protocol/BaseDualSelfCommonDETFCommon.sol";
import {DualSelfCommonDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/DualSelfCommonDETFSuperchainBridgeRepo.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";

contract BaseDualSelfCommonDETFBridgeTarget is BaseDualSelfCommonDETFCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BaseDualSelfCommonDETFRepo for BaseDualSelfCommonDETFRepo.Storage;

    struct BridgeExecution {
        DualSelfCommonDETFSuperchainBridgeRepo.PeerConfig peer;
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

        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        DualSelfCommonDETFSuperchainBridgeRepo.Storage storage bridgeLayout = DualSelfCommonDETFSuperchainBridgeRepo._layoutStruct();
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
            execution.peer = DualSelfCommonDETFSuperchainBridgeRepo.PeerConfig({
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
            bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(args.targetChainId, layoutStruct.richToken);
        if (address(execution.remoteRichToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(args.targetChainId, layoutStruct.richToken);
        }

        uint256 richirBalanceBefore = layoutStruct.richirToken.balanceOf(address(this));
        IERC20(address(layoutStruct.richirToken)).safeTransferFrom(msg.sender, address(this), args.richirAmount);
        execution.actualRichirIn = layoutStruct.richirToken.balanceOf(address(this)) - richirBalanceBefore;

        execution.sharesBurned = layoutStruct.richirToken.convertToShares(execution.actualRichirIn);
        execution.reserveSharesBurned = _calcRichirBridgeBptIn(layoutStruct, execution.actualRichirIn);

        IERC20(address(layoutStruct.richirToken)).safeTransfer(address(layoutStruct.richirToken), execution.actualRichirIn);
        layoutStruct.richirToken.burnShares(execution.actualRichirIn, address(0), true);

        (execution.chirWethVaultSharesOut, execution.richChirVaultSharesOut) =
            _exitReservePoolProportionalForBridge(layoutStruct, execution.reserveSharesBurned);

        if (execution.chirWethVaultSharesOut > 0) {
            execution.localBptOut =
                _addToReservePool(layoutStruct, layoutStruct.chirWethVaultIndex, execution.chirWethVaultSharesOut, args.deadline);
            if (execution.localBptOut > 0) {
                localRichirOut = _mintRichirAgainstProtocolNft(layoutStruct, execution.localBptOut, msg.sender);
            }
        }

        if (localRichirOut < args.minLocalRichirOut) {
            revert SlippageExceeded(args.minLocalRichirOut, localRichirOut);
        }

        if (execution.richChirVaultSharesOut > 0) {
            IERC20 richChirVaultToken = IERC20(address(layoutStruct.richChirVault));
            richChirVaultToken.forceApprove(address(layoutStruct.richChirVault), execution.richChirVaultSharesOut);
            richOut = layoutStruct.richChirVault.exchangeIn(
                richChirVaultToken,
                execution.richChirVaultSharesOut,
                layoutStruct.richToken,
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

        layoutStruct.richToken.forceApprove(address(bridgeLayout.standardBridge), richOut);
        bridgeLayout.standardBridge.bridgeERC20To(
            address(layoutStruct.richToken),
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

        _sweepBridgeRichDust(layoutStruct);

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
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        address expectedRelayer = DualSelfCommonDETFSuperchainBridgeRepo._localRelayer();

        if (expectedRelayer == address(0)) {
            revert BridgeConfigNotSet();
        }

        if (msg.sender != expectedRelayer) {
            revert NotBridgeRelayer(msg.sender, expectedRelayer);
        }

        recipient = recipient == address(0) ? msg.sender : recipient;
        richirOut = _receiveBridgedRichToRichir(layoutStruct, richAmount, recipient, deadline);

        emit BridgeReceived(msg.sender, recipient, richAmount, richirOut);
    }

    function _receiveBridgedRichToRichir(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 richAmount_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 richirOut_) {
        uint256 actualIn = _secureTokenTransfer(layoutStruct_.richToken, richAmount_, false);

        layoutStruct_.richToken.safeTransfer(address(layoutStruct_.richChirVault), actualIn);
        uint256 richChirShares = layoutStruct_.richChirVault.exchangeIn(
            layoutStruct_.richToken,
            actualIn,
            IERC20(address(layoutStruct_.richChirVault)),
            0,
            address(this),
            true,
            deadline_
        );

        uint256 bptOut = _addToReservePool(layoutStruct_, layoutStruct_.richChirVaultIndex, richChirShares, deadline_);
        richirOut_ = _mintRichirAgainstProtocolNft(layoutStruct_, bptOut, recipient_);
    }

    function _mintRichirAgainstProtocolNft(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 bptOut_,
        address recipient_
    ) internal returns (uint256 richirOut_) {
        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
            reservePoolToken, layoutStruct_.protocolNFTVault, layoutStruct_.protocolNFTId, bptOut_
        );

        richirOut_ = layoutStruct_.richirToken.mintFromNFTSale(bptOut_, recipient_);
    }

    function _calcRichirBridgeBptIn(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 richirAmount_)
        internal
        view
        returns (uint256 bptIn_)
    {
        uint256 richirShares = layoutStruct_.richirToken.convertToShares(richirAmount_);
        uint256 totalRichirShares = layoutStruct_.richirToken.totalShares();
        uint256 protocolNftBpt = layoutStruct_.protocolNFTVault.originalSharesOf(layoutStruct_.protocolNFTId);
        bptIn_ = (richirShares * protocolNftBpt) / totalRichirShares;
    }

    function _exitReservePoolProportionalForBridge(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 bptIn_)
        internal
        returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
    {
        IWeightedPool pool = _reservePool();
        IERC20(address(pool)).forceApprove(address(layoutStruct_.balancerV3PrepayRouter), bptIn_);
        uint256[] memory minAmountsOut = new uint256[](2);
        uint256[] memory amountsOut =
            layoutStruct_.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(address(pool), bptIn_, minAmountsOut, "");
        chirWethVaultSharesOut_ = amountsOut[layoutStruct_.chirWethVaultIndex];
        richChirVaultSharesOut_ = amountsOut[layoutStruct_.richChirVaultIndex];
    }

    function _sweepBridgeRichDust(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_) internal {
        uint256 richDust = layoutStruct_.richToken.balanceOf(address(this));
        if (richDust == 0) {
            return;
        }

        address feeTo = address(layoutStruct_._feeOracle().feeTo());
        layoutStruct_.richToken.safeTransfer(feeTo, richDust);
        emit BridgeDustSent(layoutStruct_.richToken, feeTo, richDust);
    }

    function _addToReservePool(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 tokenIndexIn_,
        uint256 vaultShares,
        uint256 deadline_
    ) internal returns (uint256 bptOut) {
        deadline_;
        bptOut = _addSingleSidedVaultSharesToReservePool(layoutStruct_, tokenIndexIn_, vaultShares);
    }
}