// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";

/**
 * @title ISingleVaultDetf
 * @notice Single-vault DETF surface for a DETF composed over one IStandardExchange.
 * @dev Extends the Protocol DETF interface to remain compatible with DETFNFTVault,
 *      while adding explicit single-vault getters.
 *
 *      Role model:
 *      - rateAsset: Rate Provider target and mint/bond/redeem settlement token
 *      - pairToken: any other token declared by the underlying vault
 *      - underlyingVault: the IStandardExchange (any tokens() set containing rateAsset)
 */
interface ISingleVaultDetf is IProtocolDETF {
    /**
     * @notice Returns the Balancer rate provider used to value vault shares in rateAsset terms.
     */
    function vaultRateProvider() external view returns (IRateProvider);

    /**
     * @notice Returns the token ordering used by the reserve pool.
     * @return detfIndex_ Index of the DETF token in the reserve pool token list.
     * @return vaultTokenIndex_ Index of the underlying vault share token in the reserve pool token list.
     */
    function reservePoolIndexes() external view returns (uint256 detfIndex_, uint256 vaultTokenIndex_);

    /**
     * @notice Returns the accepted bond tokens for the single-vault bond path.
     */
    function acceptedBondTokens() external view returns (address[] memory tokens);

    /**
     * @notice Returns whether `token` is accepted by the bond path.
     */
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);
}
