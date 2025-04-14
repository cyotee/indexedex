// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IERC20MintBurnProxy} from "@crane/contracts/interfaces/proxies/IERC20MintBurnProxy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";

library SeigniorageVaultRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode("indexedex.protocols.dexes.balancer.v3.vaults.seigniorage"));

    struct Storage {
        // IWeightedPool reservePool;
        IStandardExchangeProxy reserveVault;
        // uint256 reserveVaultIndexinReservePool;
        // uint256 reserveVaultWeightInReservePool;
        // uint256 selfIndexInReservePool;
        // uint256 selfWeightInReservePool;
        IERC20MintBurnProxy seigniorageToken;
        ISeigniorageNFTVault seigniorageNFTVault;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    // function _setReservePool(Storage storage layout, IWeightedPool reservePool_) internal {
    //     layout.reservePool = reservePool_;
    // }

    // function _reservePool(Storage storage layout) internal view returns (IWeightedPool reservePool_) {
    //     return layout.reservePool;
    // }

    // function _reservePool() internal view returns (IWeightedPool reservePool_) {
    //     return _reservePool(_layout());
    // }

    function _setReserveVault(Storage storage layout_, IStandardExchangeProxy reserveVault_) internal {
        layout_.reserveVault = reserveVault_;
    }

    function _reserveVault(Storage storage layout_) internal view returns (IStandardExchangeProxy reserveVault_) {
        return layout_.reserveVault;
    }

    function _reserveVault() internal view returns (IStandardExchangeProxy reserveVault_) {
        return _reserveVault(_layout());
    }

    // function _setReserveVaultIndexInReservePool(Storage storage layout_, uint256 index_) internal {
    //     layout_.reserveVaultIndexinReservePool = index_;
    // }

    // function _reserveVaultIndexInReservePool(Storage storage layout_) internal view returns (uint256 index_) {
    //     return layout_.reserveVaultIndexinReservePool;
    // }

    // function _reserveVaultIndexInReservePool() internal view returns (uint256 index_) {
    //     return _reserveVaultIndexInReservePool(_layout());
    // }

    // function _setReserveVaultWeightInReservePool(Storage storage layout_, uint256 weight_) internal {
    //     layout_.reserveVaultWeightInReservePool = weight_;
    // }

    // function _reserveVaultWeightInReservePool(Storage storage layout_) internal view returns (uint256 weight_) {
    //     return layout_.reserveVaultWeightInReservePool;
    // }

    // function _reserveVaultWeightInReservePool() internal view returns (uint256 weight_) {
    //     return _reserveVaultWeightInReservePool(_layout());
    // }

    // function _setSelfIndexInReservePool(Storage storage layout_, uint256 index_) internal {
    //     layout_.selfIndexInReservePool = index_;
    // }

    // function _selfIndexInReservePool(Storage storage layout_) internal view returns (uint256 index_) {
    //     return layout_.selfIndexInReservePool;
    // }

    // function _selfIndexInReservePool() internal view returns (uint256 index_) {
    //     return _selfIndexInReservePool(_layout());
    // }

    // function _setSelfWeightInReservePool(Storage storage layout_, uint256 weight_) internal {
    //     layout_.selfWeightInReservePool = weight_;
    // }

    // function _selfWeightInReservePool(Storage storage layout_) internal view returns (uint256 weight_) {
    //     return layout_.selfWeightInReservePool;
    // }

    // function _selfWeightInReservePool() internal view returns (uint256 weight_) {
    //     return _selfWeightInReservePool(_layout());
    // }

    function _setSeigniorageToken(Storage storage layout_, IERC20MintBurnProxy seigniorageToken_) internal {
        layout_.seigniorageToken = seigniorageToken_;
    }

    function _seigniorageToken(Storage storage layout_) internal view returns (IERC20MintBurnProxy seigniorageToken_) {
        return layout_.seigniorageToken;
    }

    function _seigniorageToken() internal view returns (IERC20MintBurnProxy seigniorageToken_) {
        return _seigniorageToken(_layout());
    }

    function _setSeigniorageNFTVault(Storage storage layout_, ISeigniorageNFTVault seigniorageNFTVault_) internal {
        layout_.seigniorageNFTVault = seigniorageNFTVault_;
    }

    function _seigniorageNFTVault(Storage storage layout_)
        internal
        view
        returns (ISeigniorageNFTVault seigniorageNFTVault_)
    {
        return layout_.seigniorageNFTVault;
    }

    function _seigniorageNFTVault() internal view returns (ISeigniorageNFTVault seigniorageNFTVault_) {
        return _seigniorageNFTVault(_layout());
    }
}
