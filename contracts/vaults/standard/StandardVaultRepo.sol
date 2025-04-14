// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {AddressSet, AddressSetRepo} from '@crane/contracts/utils/collections/sets/AddressSetRepo.sol';
import {Bytes4Set, Bytes4SetRepo} from "@crane/contracts/utils/collections/sets/Bytes4SetRepo.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
// import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

library StandardVaultRepo {
    using AddressSetRepo for AddressSet;
    // using BetterAddress for address[];
    using Bytes4SetRepo for Bytes4Set;
    using BetterEfficientHashLib for bytes;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.standard.vault");

    // TODO Add mapping for underlying decimals.
    struct Storage {
        IVaultFeeOracleQuery feeOracle;
        bytes32 vaultFeeTypeIds;
        bytes32 contentsId;
        Bytes4Set vaultTypes;
        mapping(address token => uint8 decimals) decimalOfToken;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(
        Storage storage layout,
        IVaultFeeOracleQuery feeOracle,
        bytes32 vaultFeeTypeIds,
        bytes4[] memory vaultTypes,
        bytes32 contentsId
    ) internal {
        // _initPermit2Aware(permit2);
        layout.feeOracle = feeOracle;
        layout.vaultFeeTypeIds = vaultFeeTypeIds;
        layout.vaultTypes._add(vaultTypes);
        // layout.contentsId = abi.encode(vaultTokens)._hash();
        layout.contentsId = contentsId;
        // MultiAssetBasicVaultRepo._addVaultTokens(vaultTokens);
    }

    function _initialize(
        IVaultFeeOracleQuery feeOracle,
        bytes32 vaultFeeTypeIds,
        bytes4[] memory vaultTypes,
        bytes32 contentsId
    ) internal {
        _initialize(_layout(), feeOracle, vaultFeeTypeIds, vaultTypes, contentsId);
    }

    function _feeOracle(Storage storage layout) internal view returns (IVaultFeeOracleQuery) {
        return layout.feeOracle;
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery) {
        return _feeOracle(_layout());
    }

    function _vaultFeeTypeIds(Storage storage layout) internal view returns (bytes32) {
        return layout.vaultFeeTypeIds;
    }

    function _vaultFeeTypeIds() internal view returns (bytes32) {
        return _vaultFeeTypeIds(_layout());
    }

    function _vaultTypes(Storage storage layout) internal view returns (bytes4[] memory vaultTypes_) {
        return layout.vaultTypes._values();
    }

    function _vaultTypes() internal view returns (bytes4[] memory vaultTypes_) {
        return _vaultTypes(_layout());
    }

    function _contentsId(Storage storage layout) internal view returns (bytes32) {
        return layout.contentsId;
    }

    function _contentsId() internal view returns (bytes32) {
        return _contentsId(_layout());
    }
}
