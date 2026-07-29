// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {SingleVaultDetfInfoTarget} from "contracts/vaults/detf/composed/single/SingleVaultDetfInfoTarget.sol";

contract SingleVaultDetfInfoFacet is SingleVaultDetfInfoTarget, IFacet {
    function facetName() external pure returns (string memory name_) {
        return type(SingleVaultDetfInfoFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IDetf).interfaceId;
        interfaces_[1] = type(ISingleVaultDetf).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](16);
        funcs_[0] = IDetf.detfToken.selector;
        funcs_[1] = IDetf.pairToken.selector;
        funcs_[2] = IDetf.rebasingClaimToken.selector;
        funcs_[3] = IDetf.rateAsset.selector;
        funcs_[4] = IDetf.detfNFTVault.selector;
        funcs_[5] = IDetf.underlyingVault.selector;
        funcs_[6] = IDetf.reservePool.selector;
        funcs_[7] = IDetf.detfNFTId.selector;
        funcs_[8] = IDetf.syntheticPrice.selector;
        funcs_[9] = IDetf.mintThreshold.selector;
        funcs_[10] = IDetf.burnThreshold.selector;
        funcs_[11] = IDetf.thresholdMode.selector;
        funcs_[12] = IDetf.isMintingAllowed.selector;
        funcs_[13] = IDetf.isBurningAllowed.selector;
        funcs_[14] = ISingleVaultDetf.vaultRateProvider.selector;
        funcs_[15] = ISingleVaultDetf.reservePoolIndexes.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(SingleVaultDetfInfoFacet).name;
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IDetf).interfaceId;
        interfaces_[1] = type(ISingleVaultDetf).interfaceId;
        functions_ = new bytes4[](16);
        functions_[0] = IDetf.detfToken.selector;
        functions_[1] = IDetf.pairToken.selector;
        functions_[2] = IDetf.rebasingClaimToken.selector;
        functions_[3] = IDetf.rateAsset.selector;
        functions_[4] = IDetf.detfNFTVault.selector;
        functions_[5] = IDetf.underlyingVault.selector;
        functions_[6] = IDetf.reservePool.selector;
        functions_[7] = IDetf.detfNFTId.selector;
        functions_[8] = IDetf.syntheticPrice.selector;
        functions_[9] = IDetf.mintThreshold.selector;
        functions_[10] = IDetf.burnThreshold.selector;
        functions_[11] = IDetf.thresholdMode.selector;
        functions_[12] = IDetf.isMintingAllowed.selector;
        functions_[13] = IDetf.isBurningAllowed.selector;
        functions_[14] = ISingleVaultDetf.vaultRateProvider.selector;
        functions_[15] = ISingleVaultDetf.reservePoolIndexes.selector;
    }
}
