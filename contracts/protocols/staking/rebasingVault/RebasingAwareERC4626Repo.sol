// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title RebasingAwareERC4626Repo
 * @notice Vault storage. `totalAssets` is live `asset.balanceOf(this)` so rebases accrue to shares.
 * @dev Preserve slot and first fields (`asset`, `decimalOffset`). Append captured asset
 *      decimals and registry once at init.
 */
library RebasingAwareERC4626Repo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.staking.rebasingAwareErc4626"))) - 1);

    struct Storage {
        IERC20 asset;
        uint8 decimalOffset;
        uint8 assetDecimals;
        address vaultRegistry;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _initialize(IERC20 asset_, uint8 decimalOffset_, uint8 assetDecimals_, address vaultRegistry_)
        internal
    {
        Storage storage layoutStruct = _layoutStruct();
        layoutStruct.asset = asset_;
        layoutStruct.decimalOffset = decimalOffset_;
        layoutStruct.assetDecimals = assetDecimals_;
        layoutStruct.vaultRegistry = vaultRegistry_;
    }

    function _asset() internal view returns (IERC20) {
        return _layoutStruct().asset;
    }

    function _decimalOffset() internal view returns (uint8) {
        return _layoutStruct().decimalOffset;
    }

    function _assetDecimals() internal view returns (uint8) {
        return _layoutStruct().assetDecimals;
    }

    function _vaultRegistry() internal view returns (address) {
        return _layoutStruct().vaultRegistry;
    }
}
