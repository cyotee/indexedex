// SPDX-License-Identifier: BSL-1.1
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
import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";
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
        funcs = new bytes4[](25);
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
        funcs[13] = IVaultFeeOracleManager.setDefaultLiquidReservePercentage.selector;
        funcs[14] = IVaultFeeOracleManager.setDefaultLiquidReservePercentageOfTypeId.selector;
        funcs[15] = IVaultFeeOracleManager.setLiquidReservePercentageOfVault.selector;
        funcs[16] = IVaultFeeOracleManager.setDefaultSeigniorageFeeToSharePercentage.selector;
        funcs[17] = IVaultFeeOracleManager.setDefaultSeigniorageFeeToSharePercentageOfTypeId.selector;
        funcs[18] = IVaultFeeOracleManager.setSeigniorageFeeToSharePercentageOfVault.selector;
        funcs[19] = IVaultFeeOracleManager.setDefaultSeigniorageCreatorSharePercentage.selector;
        funcs[20] = IVaultFeeOracleManager.setDefaultSeigniorageCreatorSharePercentageOfTypeId.selector;
        funcs[21] = IVaultFeeOracleManager.setSeigniorageCreatorSharePercentageOfVault.selector;
        funcs[22] = IVaultFeeOracleManager.setDefaultSeignioragePotShares.selector;
        funcs[23] = IVaultFeeOracleManager.setDefaultSeignioragePotSharesOfTypeId.selector;
        funcs[24] = IVaultFeeOracleManager.setSeignioragePotSharesOfVault.selector;
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

    function setDefaultLiquidReservePercentage(uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldPercentage = VaultFeeOracleRepo._setDefaultLiquidReservePercentage(percentage);
        emit NewDefaultLiquidReservePercentage(oldPercentage, percentage);
        return true;
    }

    function setDefaultLiquidReservePercentageOfTypeId(bytes4 vaultTypeId, uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldPercentage = VaultFeeOracleRepo._setDefaultLiquidReservePercentageOfTypeId(vaultTypeId, percentage);
        emit NewDefaultLiquidReservePercentageOfTypeId(vaultTypeId, oldPercentage, percentage);
        return true;
    }

    function setLiquidReservePercentageOfVault(address vault, uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        uint256 oldPercentage = VaultFeeOracleRepo._overrideLiquidReservePercentageOfVault(vault, percentage);
        emit NewLiquidReservePercentageOfVault(vault, oldPercentage, percentage);
        return true;
    }

    function setDefaultSeigniorageFeeToSharePercentage(uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        VaultFeeOracleRepo._assertPotSharesBelowWad(
            percentage, VaultFeeOracleRepo._defaultSeigniorageCreatorSharePercentage()
        );
        uint256 oldPercentage = VaultFeeOracleRepo._setDefaultSeigniorageFeeToSharePercentage(percentage);
        emit NewDefaultSeigniorageFeeToSharePercentage(oldPercentage, percentage);
        return true;
    }

    function setDefaultSeigniorageFeeToSharePercentageOfTypeId(bytes4 vaultTypeId, uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        _assertTypePotShares(vaultTypeId, percentage, VaultFeeOracleRepo._seigniorageCreatorSharePercentageOfTypeId(vaultTypeId));
        uint256 oldPercentage =
            VaultFeeOracleRepo._setSeigniorageFeeToSharePercentageOfTypeId(vaultTypeId, percentage);
        emit NewDefaultSeigniorageFeeToSharePercentageOfTypeId(vaultTypeId, oldPercentage, percentage);
        return true;
    }

    function setSeigniorageFeeToSharePercentageOfVault(address vault, uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        _assertVaultPotShares(vault, percentage, VaultFeeOracleRepo._seigniorageCreatorSharePercentageOfVault(vault));
        uint256 oldPercentage = VaultFeeOracleRepo._overrideSeigniorageFeeToSharePercentageOfVault(vault, percentage);
        emit NewSeigniorageFeeToSharePercentageOfVault(vault, oldPercentage, percentage);
        return true;
    }

    function setDefaultSeigniorageCreatorSharePercentage(uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        VaultFeeOracleRepo._assertPotSharesBelowWad(
            VaultFeeOracleRepo._defaultSeigniorageFeeToSharePercentage(), percentage
        );
        uint256 oldPercentage = VaultFeeOracleRepo._setDefaultSeigniorageCreatorSharePercentage(percentage);
        emit NewDefaultSeigniorageCreatorSharePercentage(oldPercentage, percentage);
        return true;
    }

    function setDefaultSeigniorageCreatorSharePercentageOfTypeId(bytes4 vaultTypeId, uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        _assertTypePotShares(vaultTypeId, VaultFeeOracleRepo._seigniorageFeeToSharePercentageOfTypeId(vaultTypeId), percentage);
        uint256 oldPercentage =
            VaultFeeOracleRepo._setSeigniorageCreatorSharePercentageOfTypeId(vaultTypeId, percentage);
        emit NewDefaultSeigniorageCreatorSharePercentageOfTypeId(vaultTypeId, oldPercentage, percentage);
        return true;
    }

    function setSeigniorageCreatorSharePercentageOfVault(address vault, uint256 percentage)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        _assertVaultPotShares(vault, VaultFeeOracleRepo._seigniorageFeeToSharePercentageOfVault(vault), percentage);
        uint256 oldPercentage =
            VaultFeeOracleRepo._overrideSeigniorageCreatorSharePercentageOfVault(vault, percentage);
        emit NewSeigniorageCreatorSharePercentageOfVault(vault, oldPercentage, percentage);
        return true;
    }

    function setDefaultSeignioragePotShares(uint256 feeToShare, uint256 creatorShare)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        VaultFeeOracleRepo._assertPotSharesBelowWad(feeToShare, creatorShare);
        uint256 oldF = VaultFeeOracleRepo._setDefaultSeigniorageFeeToSharePercentage(feeToShare);
        uint256 oldC = VaultFeeOracleRepo._setDefaultSeigniorageCreatorSharePercentage(creatorShare);
        emit NewDefaultSeignioragePotShares(oldF, oldC, feeToShare, creatorShare);
        return true;
    }

    function setDefaultSeignioragePotSharesOfTypeId(bytes4 vaultTypeId, uint256 feeToShare, uint256 creatorShare)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        _assertTypePotShares(vaultTypeId, feeToShare, creatorShare);
        uint256 oldF = VaultFeeOracleRepo._setSeigniorageFeeToSharePercentageOfTypeId(vaultTypeId, feeToShare);
        uint256 oldC = VaultFeeOracleRepo._setSeigniorageCreatorSharePercentageOfTypeId(vaultTypeId, creatorShare);
        emit NewDefaultSeignioragePotSharesOfTypeId(vaultTypeId, oldF, oldC, feeToShare, creatorShare);
        return true;
    }

    function setSeignioragePotSharesOfVault(address vault, uint256 feeToShare, uint256 creatorShare)
        external
        onlyOwnerOrOperator
        returns (bool success)
    {
        _assertVaultPotShares(vault, feeToShare, creatorShare);
        uint256 oldF = VaultFeeOracleRepo._overrideSeigniorageFeeToSharePercentageOfVault(vault, feeToShare);
        uint256 oldC = VaultFeeOracleRepo._overrideSeigniorageCreatorSharePercentageOfVault(vault, creatorShare);
        emit NewSeignioragePotSharesOfVault(vault, oldF, oldC, feeToShare, creatorShare);
        return true;
    }

    function _resolvedTypeShare(uint256 typeShare_, uint256 globalShare_) private pure returns (uint256) {
        return typeShare_ == 0 ? globalShare_ : typeShare_;
    }

    function _assertTypePotShares(bytes4 vaultTypeId_, uint256 typeF_, uint256 typeC_) private view {
        uint256 resolvedF_ = _resolvedTypeShare(typeF_, VaultFeeOracleRepo._defaultSeigniorageFeeToSharePercentage());
        uint256 resolvedC_ = _resolvedTypeShare(typeC_, VaultFeeOracleRepo._defaultSeigniorageCreatorSharePercentage());
        VaultFeeOracleRepo._assertPotSharesBelowWad(resolvedF_, resolvedC_);
        vaultTypeId_;
    }

    function _assertVaultPotShares(address vault_, uint256 vaultF_, uint256 vaultC_) private view {
        bytes4 typeId_ = VaultRegistryVaultRepo._seigniorageIncentiveIdOfVault(vault_);
        uint256 typeF_ = VaultFeeOracleRepo._seigniorageFeeToSharePercentageOfTypeId(typeId_);
        uint256 typeC_ = VaultFeeOracleRepo._seigniorageCreatorSharePercentageOfTypeId(typeId_);
        uint256 resolvedF_ = vaultF_ == 0
            ? _resolvedTypeShare(typeF_, VaultFeeOracleRepo._defaultSeigniorageFeeToSharePercentage())
            : vaultF_;
        uint256 resolvedC_ = vaultC_ == 0
            ? _resolvedTypeShare(typeC_, VaultFeeOracleRepo._defaultSeigniorageCreatorSharePercentage())
            : vaultC_;
        VaultFeeOracleRepo._assertPotSharesBelowWad(resolvedF_, resolvedC_);
    }
}
