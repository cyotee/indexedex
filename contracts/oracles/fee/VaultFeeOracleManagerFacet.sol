// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";
import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {VaultFeeOracleRepo} from "contracts/oracles/fee/VaultFeeOracleRepo.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

contract VaultFeeOracleManagerFacet is MultiStepOwnableModifiers, OperableModifiers, IVaultFeeOracleManager, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(VaultFeeOracleManagerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVaultFeeOracleManager).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](13);
        funcs[0] = IVaultFeeOracleManager.setFeeTo.selector;
        funcs[1] = IVaultFeeOracleManager.setDefaultUsageFee.selector;
        funcs[2] = IVaultFeeOracleManager.setDefaultUsageFeeOfTypeId.selector;
        funcs[3] = IVaultFeeOracleManager.setUsageFeeOfVault.selector;
        funcs[4] = IVaultFeeOracleManager.setDefaultBondTerms.selector;
        funcs[5] = IVaultFeeOracleManager.setDefaultBondTermsOfTypeId.selector;
        funcs[6] = IVaultFeeOracleManager.setVaultBondTerms.selector;
        funcs[7] = IVaultFeeOracleManager.setDefaultDexSwapFee.selector;
        funcs[8] = IVaultFeeOracleManager.setDefaultDexSwapFeeOfTypeId.selector;
        funcs[9] = IVaultFeeOracleManager.setVaultDexSwapFee.selector;
        funcs[10] = IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentage.selector;
        funcs[11] = IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentageOfTypeId.selector;
        funcs[12] = IVaultFeeOracleManager.setSeigniorageIncentivePercentageOfVault.selector;
        return funcs;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    function setFeeTo(IFeeCollectorProxy feeTo) external onlyOwner returns (bool success) {
        VaultFeeOracleRepo._setFeeTo(feeTo);
        return true;
    }

    function setDefaultUsageFee(uint256 usageFee) external onlyOwnerOrOperator returns (bool success) {
        uint256 oldFee = VaultFeeOracleRepo._setDefaultVaultUsageFee(usageFee);
        emit NewDefaultVaultFee(oldFee, usageFee);
        return true;
    }

    function setDefaultUsageFeeOfTypeId(bytes4 vaultTypeId, uint256 usageFee)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldFee = VaultFeeOracleRepo._setDefaultUsageFeeOfTypeId(vaultTypeId, usageFee);
        emit NewDefaultVaultFeeOfTypeId(vaultTypeId, oldFee, usageFee);
        return true;
    }

    function setUsageFeeOfVault(address vault, uint256 usageFee) external onlyOwnerOrOperator returns (bool success) {
        uint256 oldFee = VaultFeeOracleRepo._overrideUsageFeeOfVault(vault, usageFee);
        emit NewVaultFee(vault, oldFee, usageFee);
        return true;
    }

    function setDefaultBondTerms(BondTerms calldata bondTerms) external onlyOwnerOrOperator returns (bool success) {
        VaultFeeOracleRepo._setDefaultBondTerms(bondTerms);
        return true;
    }

    function setDefaultBondTermsOfTypeId(bytes4 vaultTypeId, BondTerms calldata bondTerms)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        VaultFeeOracleRepo._setDefaultBondTermsOfTypeId(vaultTypeId, bondTerms);
        return true;
    }

    function setVaultBondTerms(address vault, BondTerms calldata bondTerms)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        VaultFeeOracleRepo._overrideBondTermsOfVault(vault, bondTerms);
        return true;
    }

    function setDefaultDexSwapFee(uint256 swapFee) external onlyOwnerOrOperator returns (bool success) {
        uint256 oldFee = VaultFeeOracleRepo._setDefaultDexSwapFee(swapFee);
        emit NewDefaultDexFee(oldFee, swapFee);
        return true;
    }

    function setDefaultDexSwapFeeOfTypeId(bytes4 vaultTypeId, uint256 dexSwapFee)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldFee = VaultFeeOracleRepo._setDefaultDexSwapFeeOfTypeId(vaultTypeId, dexSwapFee);
        emit NewDefaultDexFeeOfTypeId(vaultTypeId, oldFee, dexSwapFee);
        return true;
    }

    function setVaultDexSwapFee(address vault, uint256 swapFee) external onlyOwnerOrOperator returns (bool success) {
        uint256 oldFee = VaultFeeOracleRepo._overrideDexSwapFeeOfVault(vault, swapFee);
        emit NewDexSwapFeeOfVault(vault, oldFee, swapFee);
        return true;
    }

    function setDefaultSeigniorageIncentivePercentage(uint256 incentivePercentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldPercentage = VaultFeeOracleRepo._setDefaultSeigniorageIncentivePercentage(incentivePercentage);
        emit NewDefaultSeigniorageIncentivePercentage(oldPercentage, incentivePercentage);
        return true;
    }

    function setDefaultSeigniorageIncentivePercentageOfTypeId(bytes4 vaultTypeId, uint256 incentivePercentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldPercentage = VaultFeeOracleRepo._setDefaultSeigniorageIncentivePercentageOfTypeId(
            vaultTypeId, incentivePercentage
        );
        emit NewDefaultSeigniorageIncentivePercentageOfTypeId(vaultTypeId, oldPercentage, incentivePercentage);
        return true;
    }

    function setSeigniorageIncentivePercentageOfVault(address vault, uint256 incentivePercentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldPercentage =
            VaultFeeOracleRepo._overrideSeigniorageIncentivePercentageOfVault(vault, incentivePercentage);
        emit NewSeigniorageIncentivePercentageOfVault(vault, oldPercentage, incentivePercentage);
        return true;
    }
}
