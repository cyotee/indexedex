// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

// import {BetterIERC20 as IERC20} from "contracts/crane/interfaces/BetterIERC20.sol";

/**
 * @custom:interfaceid 0xe4e506c5
 */
interface IStandardVault {
    /* ---------------------------------------------------------------------- */
    /*                                 Structs                                */
    /* ---------------------------------------------------------------------- */

    struct VaultConfig {
        bytes32 vaultFeeTypeIds;
        bytes32 contentsId;
        bytes4[] vaultTypes;
        address[] tokens;
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    // error VaultInsufficientAllowance(
    //     address token, address owner, address spender, uint256 allowance, uint256 required
    // );

    error AllowanceExpired(OZIERC20 token, address owner, uint48 expiration, uint48 currentTime);

    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                Functions                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Vault type ID used to determine fee.
     */
    function vaultFeeTypeIds() external view returns (bytes32 vaultFeeTypeIds_);

    function contentsId() external view returns (bytes32 contentsId_);

    /**
     * @notice Vault type is the ERC165 interface IDs exposed by the vault.
     * @dev Returns the vault types of the vault.
     * @custom:selector 0x36abf3dc
     */
    function vaultTypes() external view returns (bytes4[] memory vaultTypes_);

    // /**
    //  * @dev Returns the tokens this vault will accept/produce for exchanges.
    //  * @custom:selector 0x9d63848a
    //  */
    // function vaultTokens() external view returns (address[] memory tokens_);

    /**
     * @custom:selector 0x7cc34bb4
     */
    function vaultConfig() external view returns (VaultConfig memory vaultConfig_);

    // /**
    //  * @custom:selector 0x46f910ac
    //  */
    // function reserveOfToken(address token) external view returns (uint256 reserve_);

    // /**
    //  * @custom:selector 0x75172a8b
    //  */
    // function reserves() external view returns (uint256[] memory reserves_);
}
