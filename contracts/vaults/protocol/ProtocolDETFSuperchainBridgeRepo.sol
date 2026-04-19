// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";

library ProtocolDETFSuperchainBridgeRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.protocol.detf.superchain.bridge");

    struct PeerConfig {
        address relayer;
    }

    struct InitData {
        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        address localRelayer;
        uint256[] peerChainIds;
        address[] peerRelayers;
    }

    struct BridgeConfig {
        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        address localRelayer;
        address peerRelayer;
    }

    struct Storage {
        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        address localRelayer;
        address defaultPeerRelayer;
        mapping(uint256 => PeerConfig) peers;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(bytes memory initData_) internal {
        if (initData_.length == 0) {
            return;
        }

        InitData memory initData = abi.decode(initData_, (InitData));
        _initialize(_layout(), initData);
    }

    function _initialize(Storage storage layout_, InitData memory initData_) internal {
        layout_.bridgeTokenRegistry = initData_.bridgeTokenRegistry;
        layout_.standardBridge = initData_.standardBridge;
        layout_.messenger = initData_.messenger;
        layout_.localRelayer = initData_.localRelayer;

        uint256 peerCount = initData_.peerChainIds.length;
        if (peerCount != initData_.peerRelayers.length) {
            revert("ProtocolDETFSuperchainBridgeRepo: peer length mismatch");
        }

        for (uint256 i = 0; i < peerCount; ++i) {
            layout_.peers[initData_.peerChainIds[i]] = PeerConfig({relayer: initData_.peerRelayers[i]});
        }

        if (peerCount == 1) {
            layout_.defaultPeerRelayer = initData_.peerRelayers[0];
        }
    }

    function _initialize(BridgeConfig memory bridgeConfig_) internal {
        _initialize(_layout(), bridgeConfig_);
    }

    function _initialize(Storage storage layout_, BridgeConfig memory bridgeConfig_) internal {
        bool hasAnyCoreConfig = address(bridgeConfig_.bridgeTokenRegistry) != address(0)
            || address(bridgeConfig_.standardBridge) != address(0) || address(bridgeConfig_.messenger) != address(0)
            || bridgeConfig_.localRelayer != address(0);

        if (!hasAnyCoreConfig) {
            return;
        }

        if (
            address(bridgeConfig_.bridgeTokenRegistry) == address(0)
                || address(bridgeConfig_.standardBridge) == address(0)
                || address(bridgeConfig_.messenger) == address(0) || bridgeConfig_.localRelayer == address(0)
        ) {
            revert("ProtocolDETFSuperchainBridgeRepo: incomplete bridge config");
        }

        layout_.bridgeTokenRegistry = bridgeConfig_.bridgeTokenRegistry;
        layout_.standardBridge = bridgeConfig_.standardBridge;
        layout_.messenger = bridgeConfig_.messenger;
        layout_.localRelayer = bridgeConfig_.localRelayer;

        if (bridgeConfig_.peerRelayer == address(0)) {
            return;
        }

        layout_.defaultPeerRelayer = bridgeConfig_.peerRelayer;
    }

    function _bridgeTokenRegistry(Storage storage layout_)
        internal
        view
        returns (ISuperChainBridgeTokenRegistry bridgeTokenRegistry_)
    {
        return layout_.bridgeTokenRegistry;
    }

    function _bridgeTokenRegistry() internal view returns (ISuperChainBridgeTokenRegistry bridgeTokenRegistry_) {
        return _bridgeTokenRegistry(_layout());
    }

    function _standardBridge(Storage storage layout_) internal view returns (IStandardBridge standardBridge_) {
        return layout_.standardBridge;
    }

    function _standardBridge() internal view returns (IStandardBridge standardBridge_) {
        return _standardBridge(_layout());
    }

    function _messenger(Storage storage layout_) internal view returns (ICrossDomainMessenger messenger_) {
        return layout_.messenger;
    }

    function _messenger() internal view returns (ICrossDomainMessenger messenger_) {
        return _messenger(_layout());
    }

    function _localRelayer(Storage storage layout_) internal view returns (address localRelayer_) {
        return layout_.localRelayer;
    }

    function _localRelayer() internal view returns (address localRelayer_) {
        return _localRelayer(_layout());
    }

    function _defaultPeerRelayer(Storage storage layout_) internal view returns (address peerRelayer_) {
        return layout_.defaultPeerRelayer;
    }

    function _defaultPeerRelayer() internal view returns (address peerRelayer_) {
        return _defaultPeerRelayer(_layout());
    }

    function _peer(Storage storage layout_, uint256 chainId_) internal view returns (PeerConfig memory peer_) {
        return layout_.peers[chainId_];
    }

    function _peer(uint256 chainId_) internal view returns (PeerConfig memory peer_) {
        return _peer(_layout(), chainId_);
    }
}