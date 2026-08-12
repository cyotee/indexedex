// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

/**
 * @title AaveV4SpokeAwareRepo
 * @author cyotee doge <doge.cyotee>
 * @notice Dependency-injection storage for the Aave V4 source contracts used by the
 *         cross-version loop vault, plus the per-token `assetId` / `reserveId` resolved at
 *         deploy time (spike WS3: `Hub.getAssetId(token)` -> `Spoke.getReserveId(hub, assetId)`).
 *         Initialized in the Package `initAccount` (PRD decision 32).
 */
library AaveV4SpokeAwareRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode("indexedex.protocols.lending.aave.cross-version.v4.spoke.aware"));

    struct Storage {
        ISpoke spoke;
        IHub hub;
        IAaveOracleV4 oracle;
        mapping(address token => uint256 assetId) assetIdOf;
        mapping(address token => uint256 reserveId) reserveIdOf;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layoutStruct) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, ISpoke spoke_, IHub hub_, IAaveOracleV4 oracle_) internal {
        layoutStruct.spoke = spoke_;
        layoutStruct.hub = hub_;
        layoutStruct.oracle = oracle_;
    }

    function _initialize(ISpoke spoke_, IHub hub_, IAaveOracleV4 oracle_) internal {
        _initialize(_layout(), spoke_, hub_, oracle_);
    }

    /// @dev Records the resolved V4 identifiers for a pair token at deploy time.
    function _setTokenIds(Storage storage layoutStruct, address token, uint256 assetId_, uint256 reserveId_)
        internal
    {
        layoutStruct.assetIdOf[token] = assetId_;
        layoutStruct.reserveIdOf[token] = reserveId_;
    }

    function _setTokenIds(address token, uint256 assetId_, uint256 reserveId_) internal {
        _setTokenIds(_layout(), token, assetId_, reserveId_);
    }

    function _spoke(Storage storage layoutStruct) internal view returns (ISpoke) {
        return layoutStruct.spoke;
    }

    function _spoke() internal view returns (ISpoke) {
        return _spoke(_layout());
    }

    function _hub(Storage storage layoutStruct) internal view returns (IHub) {
        return layoutStruct.hub;
    }

    function _hub() internal view returns (IHub) {
        return _hub(_layout());
    }

    function _oracle(Storage storage layoutStruct) internal view returns (IAaveOracleV4) {
        return layoutStruct.oracle;
    }

    function _oracle() internal view returns (IAaveOracleV4) {
        return _oracle(_layout());
    }

    function _assetIdOf(address token) internal view returns (uint256) {
        return _layout().assetIdOf[token];
    }

    function _reserveIdOf(address token) internal view returns (uint256) {
        return _layout().reserveIdOf[token];
    }
}
