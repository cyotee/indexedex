// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";

// tag::AaveV3StataMarkerTarget[]
/**
 * @title AaveV3StataMarkerTarget - Marker implementation for Stata wrapper vaults.
 * @notice Exposes the bound StataToken address via a marker interface whose
 *         interface ID is used for vault fee type configuration.
 */
contract AaveV3StataMarkerTarget is IAaveV3StataStandardVault {
    /* -------------------------------------------------------------------------- */
    /*                        IAaveV3StataStandardVault                           */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IAaveV3StataStandardVault
    function stataToken() public view returns (address stataToken_) {
        // The reserve asset of this ERC4626-based vault is the StataToken.
        stataToken_ = address(ERC4626Repo._reserveAsset());
    }
}
// end::AaveV3StataMarkerTarget[]
