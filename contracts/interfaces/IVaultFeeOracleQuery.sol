// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {
    BondTerms,

    // DexTerms,
    // KinkLendingTerms,
    VaultFeeType
} from "contracts/interfaces/VaultFeeTypes.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

/**
 * @title IVaultFeeOracleQuery
 * @notice Interface for querying the vault fee oracle.
 * @notice All fee percentages are denominated in WAD (1e18 = 100%).
 * @notice 1e15  = 0.1%
 * @notice 1e16  = 1%
 * @notice 5e16  = 5%
 * @notice 1e17  = 10%
 * @notice 1e18  = 100%
 * @notice Fee resolution follows a three-tier fallback: vault-specific -> vault-type default -> global default.
 * @notice A stored value of 0 means "unset" and triggers fallback to the next tier.
 * @notice Setting an explicit 0% fee for a specific vault or type is not supported; 0 always means "use default".
 * @custom:interfaceid 0xc6a03847
 */
// TODO Change fee queries to mapping by vault type as interface ID.
interface IVaultFeeOracleQuery {
    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                Functions                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @custom:selector 0x017e7e58
     */
    function feeTo() external view returns (IFeeCollectorProxy feeTo_);

    // function tokens() external view returns (address[] memory tokens_);

    /* ---------------------------------------------------------------------- */
    /*                               Usage Terms                              */
    /* ---------------------------------------------------------------------- */

    function usageFeeVaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_);

    function defaultUsageFee() external view returns (uint256 defaultFee_);

    function defaultUsageFeeOfTypeId(bytes4 vaultFeeTypeId) external view returns (uint256 defaultFee_);

    function usageFeeOfVault(address vault) external view returns (uint256 usageFee_);

    function usageFeeAndFeeToOfVault(address vault) external view returns (IFeeCollectorProxy feeTo, uint256 usageFee_);

    /* ---------------------------------------------------------------------- */
    /*                                DEX Terms                               */
    /* ---------------------------------------------------------------------- */

    /* ----------------------------- Swap Terms ----------------------------- */

    function dexSwapFeeVaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_);

    // function defaultDexTerms() external view returns (DexTerms memory dexTerms_);

    function defaultDexSwapFee() external view returns (uint256 swapFee_);

    // function defaultDexTermsOfTypeId(bytes4 vaultFeeTypeId) external view returns (DexTerms memory dexTerms_);

    function defaultDexSwapFeeOfTypeId(bytes4 vaultFeeTypeId) external view returns (uint256 swapFee_);

    // function dexTermsOfVault(address vault) external view returns (DexTerms memory dexTerms_);

    function dexSwapFeeOfVault(address vault) external view returns (uint256 swapFee_);

    // function dexTermsAndFeeToOfVault(address vault) external view returns (address feeTo, DexTerms memory dexTerms_);

    function dexSwapFeeAndFeeToOfVault(address vault) external view returns (IFeeCollectorProxy feeTo, uint256 swapFee_);

    /* ---------------------------------------------------------------------- */
    /*                               Bond Terms                               */
    /* ---------------------------------------------------------------------- */

    function bondVaultTypesIds() external view returns (bytes4[] memory vaultTypeIds_);

    function defaultBondTerms() external view returns (BondTerms memory bondTerms_);

    function defaultBondTermsOfVaultTypeId(bytes4 vaultFeeTypeId) external view returns (BondTerms memory bondTerms_);

    function bondTermsOfVault(address vault) external view returns (BondTerms memory bondTerms_);

    function bondTermsAndFeeToOfVault(address vault)
        external
        view
        returns (IFeeCollectorProxy feeTo, BondTerms memory bondTerms_);

    /* -------------------------------------------------------------------------- */
    /*                              Seigniorage Terms                             */
    /* -------------------------------------------------------------------------- */

    function seigniorageVaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_);

    function defaultSeigniorageIncentivePercentage() external view returns (uint256 percentage);

    function seigniorageIncentivePercentageOfTypeId(bytes4 vaultTypeId) external view returns (uint256 percentage);

    function seigniorageIncentivePercentageOfVault(address vault) external view returns (uint256 percentage);

    function seigniorageIncentivePercentageOfVaultAndFeeTo(address vault)
        external
        view
        returns (IFeeCollectorProxy feeTo, uint256 percentage);

    /* ---------------------------------------------------------------------- */
    /*                              Lending Terms                             */
    /* ---------------------------------------------------------------------- */

    // function lendingVaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_);

    // function defaultLendingTerms() external view returns (KinkLendingTerms memory defaultKinkLendingTerms_);

    // function defaultLendingTermsOfTypeId(bytes3 vaultTypeId) external view returns (KinkLendingTerms memory lendingTerms_);

    // function lendingTermsOfVault(address vault) external view returns (KinkLendingTerms memory lendingTerms_);

    // function lendingTermsAndFeeToOfVault(address vault) external view returns (address feeTo, KinkLendingTerms memory lendingTerms_);

    /* ---------------------------------------------------------------------- */

    // /**
    //  * @custom:selector 0x103b33f7
    //  */
    // function defaultVaultFee() external view returns (uint256 vaultFee_);

    // function defaultFeeOfVaultType(bytes4 vaultFeeTypeId) external view returns (uint256 defaultFee);

    // /**
    //  * @custom:selector 0x3eecaf4d
    //  */
    // function defaultDexFee() external view returns (uint256 dexFee_);

    // function defaultDDexFeeOfType(bytes4 vaultFeeTypeId) external view returns (uint256 dexFee_);

    // /**
    //  * @custom:selector 0x7498884e
    //  */
    // function defaultLendingFee() external view returns (uint256 lendingFee_);

    // function defaultLendingFeeOfVaultType(bytes4 vaultFeeTypeId) external view returns (uint256 lendingFee_);

    // /**
    //  * @custom:selector 0xc33b8137
    //  */
    // function feeOfVault(address vault) external view returns (uint256 vaultFee_);

    // function vaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_);

    // /**
    //  * @custom:selector 0x70486640
    //  */
    // function dexVaults() external view returns (address[] memory dexVaults_);

    // /**
    //  * @custom:selector 0xf17a0eba
    //  */
    // function isDexVault(address vault) external view returns (bool isDexVault_);

    // function bondVaults() external view returns (address[] memory bondVaults_);

    // function isBondVault(address vault) external view returns (bool isBondVault_);

    // /**
    //  * @custom:selector 0x2a194b16
    //  */
    // function lendingVaults() external view returns (address[] memory lendingVaults_);

    // /**
    //  * @custom:selector 0xb1490563
    //  */
    // function isLendingVault(address vault) external view returns (bool isLendingVault_);
}
