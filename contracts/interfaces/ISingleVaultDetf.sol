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
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

/**
 * @title ISingleVaultDetf
 * @notice Single-vault DETF surface for the Uniswap V4-composed DETF.
 * @dev Extends the existing Protocol DETF interface to remain compatible with
 *      ProtocolNFTVault, while adding explicit single-vault getters.
 */
interface ISingleVaultDetf is IProtocolDETF {
    /**
     * @notice Returns the canonical WETH/RICH Standard Exchange vault.
     */
    function wethRichVault() external view returns (IStandardExchange);

    /**
     * @notice Returns the Balancer rate provider used to value vault shares in WETH terms.
     */
    function vaultRateProvider() external view returns (IRateProvider);

    /**
     * @notice Returns the token ordering used by the reserve pool.
     * @return chirIndex_ Index of CHIR in the reserve pool token list.
     * @return vaultTokenIndex_ Index of the WETH/RICH vault share token in the reserve pool token list.
     */
    function reservePoolIndexes() external view returns (uint256 chirIndex_, uint256 vaultTokenIndex_);

    /**
     * @notice Returns the accepted bond tokens for the single-vault bond path.
     */
    function acceptedBondTokens() external view returns (address[] memory tokens);

    /**
     * @notice Returns whether `token` is accepted by the bond path.
     */
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);
}