// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Id, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";

/**
 * @title MorphoBlueStandardExchangeRepo
 * @notice Bound Morpho Blue `MarketParams` + `Id` for one SE instance.
 * @dev Slot: ERC1967 `keccak256(abi.encode("indexedex.vaults.standard.exchange.protocols.morpho.blue")) - 1`.
 */
library MorphoBlueStandardExchangeRepo {
    using MarketParamsLib for MarketParams;

    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.protocols.morpho.blue"))) - 1);

    struct Storage {
        MarketParams marketParams;
        Id marketId;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, MarketParams memory marketParams_) internal {
        layoutStruct.marketParams = marketParams_;
        layoutStruct.marketId = marketParams_.id();
    }

    function _initialize(MarketParams memory marketParams_) internal {
        _initialize(_layoutStruct(), marketParams_);
    }

    function _marketParams(Storage storage layoutStruct) internal view returns (MarketParams memory) {
        return layoutStruct.marketParams;
    }

    function _marketParams() internal view returns (MarketParams memory) {
        return _marketParams(_layoutStruct());
    }

    function _marketId(Storage storage layoutStruct) internal view returns (Id) {
        return layoutStruct.marketId;
    }

    function _marketId() internal view returns (Id) {
        return _marketId(_layoutStruct());
    }
}
