// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    ISeigniorageDETFUnderwriting,
    SeigniorageDETFUnderwritingTarget
} from "contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol";

import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";

interface ISeigniorageDETFReservePoolView {
    function reservePool() external view returns (address);
}

/**
 * @title SeigniorageDETFUnderwritingFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Seigniorage DETF underwriting (bonding) operations.
 * @dev Extends SeigniorageDETFUnderwritingTarget and implements IFacet.
 */
contract SeigniorageDETFUnderwritingFacet is SeigniorageDETFUnderwritingTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(SeigniorageDETFUnderwritingFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(ISeigniorageDETFUnderwriting).interfaceId;
        interfaces_[1] = type(ISeigniorageDETF).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](11);
        funcs_[0] = ISeigniorageDETFUnderwriting.underwrite.selector;
        funcs_[1] = ISeigniorageDETFUnderwriting.previewUnderwrite.selector;
        funcs_[2] = ISeigniorageDETFUnderwriting.redeem.selector;
        funcs_[3] = ISeigniorageDETFUnderwriting.previewRedeem.selector;
        funcs_[4] = ISeigniorageDETFUnderwriting.claimLiquidity.selector;
        funcs_[5] = ISeigniorageDETF.previewClaimLiquidity.selector;
        funcs_[6] = ISeigniorageDETF.seigniorageToken.selector;
        funcs_[7] = ISeigniorageDETF.seigniorageNFTVault.selector;
        funcs_[8] = ISeigniorageDETF.reserveVaultRateTarget.selector;
        funcs_[9] = ISeigniorageDETFReservePoolView.reservePool.selector;
        funcs_[10] = ISeigniorageDETF.withdrawRewards.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(SeigniorageDETFUnderwritingFacet).name;
        interfaces = new bytes4[](2);
        interfaces[0] = type(ISeigniorageDETFUnderwriting).interfaceId;
        interfaces[1] = type(ISeigniorageDETF).interfaceId;
        functions = new bytes4[](11);
        functions[0] = ISeigniorageDETFUnderwriting.underwrite.selector;
        functions[1] = ISeigniorageDETFUnderwriting.previewUnderwrite.selector;
        functions[2] = ISeigniorageDETFUnderwriting.redeem.selector;
        functions[3] = ISeigniorageDETFUnderwriting.previewRedeem.selector;
        functions[4] = ISeigniorageDETFUnderwriting.claimLiquidity.selector;
        functions[5] = ISeigniorageDETF.previewClaimLiquidity.selector;
        functions[6] = ISeigniorageDETF.seigniorageToken.selector;
        functions[7] = ISeigniorageDETF.seigniorageNFTVault.selector;
        functions[8] = ISeigniorageDETF.reserveVaultRateTarget.selector;
        functions[9] = ISeigniorageDETFReservePoolView.reservePool.selector;
        functions[10] = ISeigniorageDETF.withdrawRewards.selector;
    }
}
