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

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(bytes memory initData_) internal {
        if (initData_.length == 0) {
            return;
        }

        InitData memory initData = abi.decode(initData_, (InitData));
        _initialize(_layoutStruct(), initData);
    }

    function _initialize(Storage storage layoutStruct_, InitData memory initData_) internal {
        layoutStruct_.bridgeTokenRegistry = initData_.bridgeTokenRegistry;
        layoutStruct_.standardBridge = initData_.standardBridge;
        layoutStruct_.messenger = initData_.messenger;
        layoutStruct_.localRelayer = initData_.localRelayer;

        uint256 peerCount = initData_.peerChainIds.length;
        if (peerCount != initData_.peerRelayers.length) {
            revert("ProtocolDETFSuperchainBridgeRepo: peer length mismatch");
        }

        for (uint256 i = 0; i < peerCount; ++i) {
            layoutStruct_.peers[initData_.peerChainIds[i]] = PeerConfig({relayer: initData_.peerRelayers[i]});
        }

        if (peerCount == 1) {
            layoutStruct_.defaultPeerRelayer = initData_.peerRelayers[0];
        }
    }

    function _initialize(BridgeConfig memory bridgeConfig_) internal {
        _initialize(_layoutStruct(), bridgeConfig_);
    }

    function _initialize(Storage storage layoutStruct_, BridgeConfig memory bridgeConfig_) internal {
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

        layoutStruct_.bridgeTokenRegistry = bridgeConfig_.bridgeTokenRegistry;
        layoutStruct_.standardBridge = bridgeConfig_.standardBridge;
        layoutStruct_.messenger = bridgeConfig_.messenger;
        layoutStruct_.localRelayer = bridgeConfig_.localRelayer;

        if (bridgeConfig_.peerRelayer == address(0)) {
            return;
        }

        layoutStruct_.defaultPeerRelayer = bridgeConfig_.peerRelayer;
    }

    function _bridgeTokenRegistry(Storage storage layoutStruct_)
        internal
        view
        returns (ISuperChainBridgeTokenRegistry bridgeTokenRegistry_)
    {
        return layoutStruct_.bridgeTokenRegistry;
    }

    function _bridgeTokenRegistry() internal view returns (ISuperChainBridgeTokenRegistry bridgeTokenRegistry_) {
        return _bridgeTokenRegistry(_layoutStruct());
    }

    function _standardBridge(Storage storage layoutStruct_) internal view returns (IStandardBridge standardBridge_) {
        return layoutStruct_.standardBridge;
    }

    function _standardBridge() internal view returns (IStandardBridge standardBridge_) {
        return _standardBridge(_layoutStruct());
    }

    function _messenger(Storage storage layoutStruct_) internal view returns (ICrossDomainMessenger messenger_) {
        return layoutStruct_.messenger;
    }

    function _messenger() internal view returns (ICrossDomainMessenger messenger_) {
        return _messenger(_layoutStruct());
    }

    function _localRelayer(Storage storage layoutStruct_) internal view returns (address localRelayer_) {
        return layoutStruct_.localRelayer;
    }

    function _localRelayer() internal view returns (address localRelayer_) {
        return _localRelayer(_layoutStruct());
    }

    function _defaultPeerRelayer(Storage storage layoutStruct_) internal view returns (address peerRelayer_) {
        return layoutStruct_.defaultPeerRelayer;
    }

    function _defaultPeerRelayer() internal view returns (address peerRelayer_) {
        return _defaultPeerRelayer(_layoutStruct());
    }

    function _peer(Storage storage layoutStruct_, uint256 chainId_) internal view returns (PeerConfig memory peer_) {
        return layoutStruct_.peers[chainId_];
    }

    function _peer(uint256 chainId_) internal view returns (PeerConfig memory peer_) {
        return _peer(_layoutStruct(), chainId_);
    }
}