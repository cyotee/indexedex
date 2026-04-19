// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {ITokenTransferRelayer} from "@crane/contracts/protocols/l2s/superchain/relayers/token/ITokenTransferRelayer.sol";

contract MockProtocolDETFBridgeTokenRegistry {
    struct RemoteTokenConfig {
        IERC20 remoteToken;
        uint256 minGasLimit;
    }

    mapping(uint256 => mapping(address => RemoteTokenConfig)) internal _remoteTokens;

    function setRemoteToken(uint256 chainId, IERC20 localToken, IERC20 remoteToken, uint256 minGasLimit)
        external
        returns (bool)
    {
        _remoteTokens[chainId][address(localToken)] = RemoteTokenConfig({
            remoteToken: remoteToken,
            minGasLimit: minGasLimit
        });
        return true;
    }

    function getRemoteTokenAndLimit(uint256 chainId, IERC20 localToken)
        external
        view
        returns (IERC20 remoteToken, uint256 minGasLimit)
    {
        RemoteTokenConfig memory cfg = _remoteTokens[chainId][address(localToken)];
        return (cfg.remoteToken, cfg.minGasLimit);
    }

    function getRemoteToken(uint256 chainId, IERC20 localToken) external view returns (IERC20 remoteToken) {
        return _remoteTokens[chainId][address(localToken)].remoteToken;
    }
}

contract MockProtocolDETFStandardBridge {
    struct BridgeCall {
        address localToken;
        address remoteToken;
        address to;
        uint256 amount;
        uint32 minGasLimit;
        bytes extraData;
        address caller;
    }

    BridgeCall internal _lastBridgeCall;

    function lastBridgeCall() external view returns (BridgeCall memory call_) {
        return _lastBridgeCall;
    }

    function bridgeERC20To(
        address localToken,
        address remoteToken,
        address to,
        uint256 amount,
        uint32 minGasLimit,
        bytes memory extraData
    ) external {
        _lastBridgeCall = BridgeCall({
            localToken: localToken,
            remoteToken: remoteToken,
            to: to,
            amount: amount,
            minGasLimit: minGasLimit,
            extraData: extraData,
            caller: msg.sender
        });

        IERC20(localToken).transferFrom(msg.sender, address(this), amount);
    }
}

contract MockProtocolDETFMessenger {
    struct MessageCall {
        address target;
        bytes message;
        uint32 minGasLimit;
        address caller;
    }

    MessageCall internal _lastMessageCall;

    function lastMessageCall() external view returns (MessageCall memory call_) {
        return _lastMessageCall;
    }

    function sendMessage(address target, bytes memory message, uint32 minGasLimit) external payable {
        _lastMessageCall = MessageCall({target: target, message: message, minGasLimit: minGasLimit, caller: msg.sender});
    }
}

abstract contract ProtocolDETFRichBridgeUnitTestBase is Test {
    uint256 internal constant TARGET_CHAIN_ID = 84_532;
    uint256 internal constant BRIDGE_MIN_GAS_LIMIT = 120_000;
    uint32 internal constant MESSAGE_GAS_LIMIT = 250_000;

    struct RelayEnvelope {
        address relayRecipient;
        address relayToken;
        uint256 relayAmount;
        uint256 relayNonce;
        bool pretransfer;
        bool permit2;
        bytes relayData;
    }

    struct ReceivePayload {
        address recipient;
        uint256 richAmount;
        uint256 deadline;
    }

    MockProtocolDETFBridgeTokenRegistry internal bridgeTokenRegistry;
    MockProtocolDETFStandardBridge internal standardBridge;
    MockProtocolDETFMessenger internal messenger;

    address internal localRelayer;
    address internal peerDetf;
    address internal peerRelayer;
    IERC20 internal remoteRichToken;

    function _detf() internal view virtual returns (IProtocolDETF);

    function _rich() internal view virtual returns (IERC20);

    function _richir() internal view virtual returns (IRICHIR);

    function _protocolNFTVault() internal view virtual returns (IProtocolNFTVault);

    function _alice() internal view virtual returns (address);

    function _owner() internal view virtual returns (address);

    function _mintRich(address recipient, uint256 amount) internal virtual;

    function _mintRichirFromBondSale(uint256 wethAmount) internal returns (uint256 richirMinted) {
        vm.startPrank(_alice());
        _detf().wethToken().approve(address(_detf()), wethAmount);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(_detf()))
            .bond(_detf().wethToken(), wethAmount, 30 days, _alice(), false, block.timestamp + 1 hours);
        vm.stopPrank();

        vm.prank(_alice());
        richirMinted = IBaseProtocolDETFBonding(address(_detf())).sellNFT(tokenId, _alice());
    }

    function _bridgeArgs(address recipient, uint256 richirAmount)
        internal
        view
        returns (IProtocolDETF.BridgeArgs memory)
    {
        return IProtocolDETF.BridgeArgs({
            targetChainId: TARGET_CHAIN_ID,
            richirAmount: richirAmount,
            recipient: recipient,
            minLocalRichirOut: 0,
            minRichOut: 0,
            messageGasLimit: MESSAGE_GAS_LIMIT,
            deadline: block.timestamp + 1 hours
        });
    }

    function _dropSelector(bytes memory data) internal pure returns (bytes memory tail) {
        tail = new bytes(data.length - 4);
        for (uint256 i = 4; i < data.length; ++i) {
            tail[i - 4] = data[i];
        }
    }

    function _decodeRelayEnvelope(bytes memory message) internal pure returns (RelayEnvelope memory envelope) {
        (
            envelope.relayRecipient,
            envelope.relayToken,
            envelope.relayAmount,
            envelope.relayNonce,
            envelope.pretransfer,
            envelope.permit2,
            envelope.relayData
        ) = abi.decode(_dropSelector(message), (address, address, uint256, uint256, bool, bool, bytes));
    }

    function _decodeReceivePayload(bytes memory relayData) internal pure returns (ReceivePayload memory payload) {
        (payload.recipient, payload.richAmount, payload.deadline) =
            abi.decode(_dropSelector(relayData), (address, uint256, uint256));
    }

    function _assertRelayMessage(MockProtocolDETFMessenger.MessageCall memory messageCall, address recipient, uint256 richOut)
        internal
        view
    {
        assertEq(messageCall.target, peerRelayer);
        assertEq(messageCall.minGasLimit, MESSAGE_GAS_LIMIT);
        assertEq(messageCall.caller, address(_detf()));
        assertEq(bytes4(messageCall.message), ITokenTransferRelayer.relayTokenTransfer.selector);

        RelayEnvelope memory envelope = _decodeRelayEnvelope(messageCall.message);
        assertEq(envelope.relayRecipient, peerDetf);
        assertEq(envelope.relayToken, address(remoteRichToken));
        assertEq(envelope.relayAmount, richOut);
        assertEq(envelope.relayNonce, 0);
        assertFalse(envelope.pretransfer);
        assertFalse(envelope.permit2);

        assertEq(bytes4(envelope.relayData), IProtocolDETF.receiveBridgedRich.selector);

        ReceivePayload memory payload = _decodeReceivePayload(envelope.relayData);
        assertEq(payload.recipient, recipient);
        assertEq(payload.richAmount, richOut);
        assertEq(payload.deadline, block.timestamp + 1 hours);
    }

    function test_previewBridgeRichir_matchesExecution_andEncodesRelayCall() public {
        uint256 richirMinted = _mintRichirFromBondSale(5_000e18);
        uint256 bridgeAmount = richirMinted / 2;
        if (bridgeAmount == 0) {
            bridgeAmount = richirMinted;
        }

        address recipient = makeAddr("bridgeRecipient");
        IProtocolDETF.BridgeQuote memory quote = _detf().previewBridgeRichir(TARGET_CHAIN_ID, bridgeAmount);
        uint256 richBefore = _rich().balanceOf(_alice());

        assertEq(quote.richirAmountIn, bridgeAmount);
        assertGt(quote.sharesBurned, 0);
        assertGt(quote.reserveSharesBurned, 0);
        assertGt(quote.localRichirOut, 0);
        assertGt(quote.richOut, 0);

        vm.startPrank(_alice());
        IERC20(address(_richir())).approve(address(_detf()), bridgeAmount);
        (uint256 localRichirOut, uint256 richOut) = _detf().bridgeRichir(_bridgeArgs(recipient, bridgeAmount));
        vm.stopPrank();

        assertGt(localRichirOut, 0);
        assertApproxEqAbs(richOut, quote.richOut, 32);
        assertEq(_rich().balanceOf(_alice()), richBefore);
        assertEq(_rich().balanceOf(address(_detf())), 0);
        assertEq(_rich().balanceOf(address(standardBridge)), richOut);

        MockProtocolDETFStandardBridge.BridgeCall memory bridgeCall = standardBridge.lastBridgeCall();
        assertEq(bridgeCall.localToken, address(_rich()));
        assertEq(bridgeCall.remoteToken, address(remoteRichToken));
        assertEq(bridgeCall.to, peerRelayer);
        assertEq(bridgeCall.amount, richOut);
        assertEq(bridgeCall.minGasLimit, BRIDGE_MIN_GAS_LIMIT);
        assertEq(bridgeCall.caller, address(_detf()));

        MockProtocolDETFMessenger.MessageCall memory messageCall = messenger.lastMessageCall();
        _assertRelayMessage(messageCall, recipient, richOut);
    }

    function test_bridgeRichir_reverts_whenRemoteTokenNotConfigured() public {
        uint256 richirMinted = _mintRichirFromBondSale(2_000e18);
        uint256 bridgeAmount = richirMinted / 2;
        if (bridgeAmount == 0) {
            bridgeAmount = richirMinted;
        }

        bridgeTokenRegistry.setRemoteToken(TARGET_CHAIN_ID, _rich(), IERC20(address(0)), 0);

        vm.startPrank(_alice());
        IERC20(address(_richir())).approve(address(_detf()), bridgeAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IProtocolDETFErrors.BridgeRemoteTokenNotConfigured.selector, TARGET_CHAIN_ID, _rich()
            )
        );
        _detf().bridgeRichir(_bridgeArgs(makeAddr("recipient"), bridgeAmount));
        vm.stopPrank();
    }

    function test_receiveBridgedRich_reverts_forNonRelayer() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IProtocolDETFErrors.NotBridgeRelayer.selector, makeAddr("nonRelayer"), localRelayer
            )
        );
        vm.prank(makeAddr("nonRelayer"));
        _detf().receiveBridgedRich(_alice(), 1e18, block.timestamp + 1 hours);
    }

    function test_receiveBridgedRich_pullsRichFromRelayer_andMintsRichir() public {
        uint256 richAmount = 5_000e18;
        address recipient = makeAddr("destinationRecipient");
        uint256 previewOut = IStandardExchangeIn(address(_detf())).previewExchangeIn(
            _rich(), richAmount, IERC20(address(_richir()))
        );

        _mintRich(localRelayer, richAmount);

        vm.startPrank(localRelayer);
        _rich().approve(address(_detf()), richAmount);
        uint256 richirOut = _detf().receiveBridgedRich(recipient, richAmount, block.timestamp + 1 hours);
        vm.stopPrank();

        assertGt(richirOut, 0);
        assertGe(richirOut, previewOut);
        assertEq(_rich().balanceOf(localRelayer), 0);
        assertEq(_rich().balanceOf(address(_detf())), 0);
        assertEq(_richir().balanceOf(recipient), richirOut);
        assertEq(_rich().balanceOf(recipient), 0);
    }
}