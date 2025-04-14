// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {BondTerms} from 
// DexTerms,
// KinkLendingTerms
"contracts/interfaces/VaultFeeTypes.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

/**
 * @title IVaultFeeOracleManager
 * @notice Interface for managing vault fee oracle settings.
 * @notice All fee percentages are denominated in WAD (1e18 = 100%).
 * @notice Fee resolution follows a three-tier fallback: vault-specific -> vault-type default -> global default.
 * @notice Setting a fee to 0 resets it to "unset", causing fallback to the next tier.
 */
interface IVaultFeeOracleManager {
    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    event NewFeeTo(address indexed oldFeeTo, address indexed feeTo);
    event NewDefaultVaultFee(uint256 indexed oldVaultFee, uint256 indexed vaultFee);
    event NewDefaultVaultFeeOfTypeId(bytes4 indexed vaultTypeId, uint256 indexed oldVaultFee, uint256 indexed vaultFee);
    event NewDefaultDexFee(uint256 indexed oldDexFee, uint256 indexed dexFee);
    event NewDefaultDexFeeOfTypeId(bytes4 indexed vaultTypeId, uint256 indexed oldDexFee, uint256 indexed dexFee);
    event NewDefaultLendingFee(uint256 indexed oldLendingFee, uint256 indexed lendingFee);
    event NewVaultFee(address indexed vault, uint256 indexed oldVaultFee, uint256 indexed vaultFee);
    event NewDexSwapFeeOfVault(address indexed vault, uint256 indexed oldDexFee, uint256 indexed dexFee);
    event NewDexVault(address indexed vault);
    event NewLendingVault(address indexed vault);
    event NewDefaultSeigniorageIncentivePercentage(uint256 indexed oldPercentage, uint256 indexed newPercentage);
    event NewDefaultSeigniorageIncentivePercentageOfTypeId(
        bytes4 indexed vaultTypeId, uint256 indexed oldPercentage, uint256 indexed newPercentage
    );
    event NewSeigniorageIncentivePercentageOfVault(
        address indexed vault, uint256 indexed oldPercentage, uint256 indexed newPercentage
    );

    /* ---------------------------------------------------------------------- */
    /*                                Functions                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @custom:selector 0xf46901ed
     */
    function setFeeTo(IFeeCollectorProxy feeTo) external returns (bool success);

    /// @param usageFee The global default usage fee in WAD (e.g., 1e15 = 0.1%).
    function setDefaultUsageFee(uint256 usageFee) external returns (bool success);

    /// @param usageFee The default usage fee for this vault type in WAD.
    function setDefaultUsageFeeOfTypeId(bytes4 vaultTypeId, uint256 usageFee) external returns (bool success);

    /// @param usageFee The usage fee override for this vault in WAD. Set to 0 to clear the override.
    function setUsageFeeOfVault(address vault, uint256 usageFee) external returns (bool success);

    function setDefaultBondTerms(BondTerms calldata bondTerms) external returns (bool success);

    function setDefaultBondTermsOfTypeId(bytes4 vaultTypeId, BondTerms calldata bondTerms)
        external
        returns (bool success);

    function setVaultBondTerms(address vault, BondTerms calldata bondTerms) external returns (bool success);

    // function setDefaultDexTerms(DexTerms calldata dexTerms) external returns (bool success);

    /// @param swapFee The global default DEX swap fee in WAD (e.g., 5e16 = 5%).
    function setDefaultDexSwapFee(uint256 swapFee) external returns (bool success);

    // function setDefaultDexTermsOfTypeId(bytes4 vaultTypeId, DexTerms calldata dexTerms) external returns (bool success);

    /// @param dexSwapFee The default DEX swap fee for this vault type in WAD.
    function setDefaultDexSwapFeeOfTypeId(bytes4 vaultTypeId, uint256 dexSwapFee) external returns (bool success);

    // function setVaultDexTerms(address vault, DexTerms calldata dexTerms) external returns (bool success);

    /// @param swapFee The DEX swap fee override for this vault in WAD. Set to 0 to clear the override.
    function setVaultDexSwapFee(address vault, uint256 swapFee) external returns (bool success);

    /// @param incentivePercentage The global default seigniorage incentive percentage in WAD.
    function setDefaultSeigniorageIncentivePercentage(uint256 incentivePercentage) external returns (bool success);

    /// @param incentivePercentage The default seigniorage incentive percentage for this vault type in WAD.
    function setDefaultSeigniorageIncentivePercentageOfTypeId(bytes4 vaultTypeId, uint256 incentivePercentage)
        external
        returns (bool success);

    /// @param incentivePercentage The seigniorage incentive percentage override for this vault in WAD. Set to 0 to clear the override.
    function setSeigniorageIncentivePercentageOfVault(address vault, uint256 incentivePercentage)
        external
        returns (bool success);

    // function setDefaultLendingTerms(KinkLendingTerms calldata lendingTerms) external returns (bool success);

    // function setDefaultLendingTermsOfTypeId(bytes4 vaultTypeId, KinkLendingTerms calldata lendingTerms) external returns (bool success);

    // function setVaultLendingTerms(address vault, KinkLendingTerms calldata lendingTerms) external returns (bool success);

    // /**
    //  * @custom:selector 0x850c80f6
    //  */
    // function setDefaultVaultFee(uint256 vaultFee) external returns (bool success);

    // /**
    //  * @custom:selector 0xd6c3509a
    //  */
    // function setDefaultDexFee(uint256 dexFee) external returns (bool success);

    // /**
    //  * @custom:selector 0xb2e93dda
    //  */
    // function setDefaultLendingFee(uint256 lendingFee) external returns (bool success);

    // /**
    //  * @custom:selector 0xdf5ed1c0
    //  */
    // function overrideFeeOfVault(address vault, uint256 vaultFee) external returns (bool success);

    // /**
    //  * @custom:selector 0xc701add3
    //  */
    // function declareDexVault(address vault) external returns (bool success);

    // /**
    //  * @custom:selector 0x7790263f
    //  */
    // function declareLendingVault(address vault) external returns (bool success);
}
