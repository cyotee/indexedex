// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {BondTerms, VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

library VaultFeeOracleRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vault.registry.fee.oracle");

    // Use Crane's canonical ONE_WAD constant (1e18)

    error Percentage_ExceedsWAD(uint256 value, uint256 maxAllowed);
    error BondTerms_MaxBonusExceedsWAD(uint256 maxBonusPercentage, uint256 maxAllowed);
    error BondTerms_MinBonusExceedsMax(uint256 minBonusPercentage, uint256 maxBonusPercentage);
    error BondTerms_MinLockExceedsMax(uint256 minLockDuration, uint256 maxLockDuration);

    struct Storage {
        IFeeCollectorProxy feeTo;
        uint256 defaultVaultUsageFee;
        mapping(bytes4 vaultFeeTypeId => uint256 defaultUsageFee) defaultUsageFeeOfType;
        mapping(address vault => uint256 usageFee) usageFeeOfVault;
        BondTerms defaultBondTerms;
        mapping(bytes4 vaultFeeTypeId => BondTerms bondTerms) defaultBondTermsOfType;
        mapping(address vault => BondTerms bondTerms) bondTermsOfVault;
        // DexTerms defaultDexTerms;
        uint256 defaultDexSwapFee;
        // mapping(bytes4 vaultFeeTypeId => DexTerms dexTerms) defaultDexTermsOfType;
        mapping(bytes4 vaultFeeTypeId => uint256 swapFee) defaultDexSwapFeeOfType;
        // mapping(address vault => DexTerms dexTerms) dexTermsOfVault;
        mapping(address vault => uint256 swapFee) dexSwapFeeOfVault;
        uint256 defaultSeigniorageIncentivePercentage;
        mapping(bytes4 vaultFeeTypeId => uint256 incentivePercentage) seigniorageIncentivePercentageOfType;
        mapping(address vault => uint256 incentivePercentage) seigniorageIncentivePercentageOfVault;
        // KinkLendingTerms defaultLendingTerms;
        // mapping(bytes4 vaultFeeTypeId => KinkLendingTerms lendingTerms) defaultLendingTermsOfType;
        // mapping(address vault => KinkLendingTerms lendingTerms) lendingTermsOfVault;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _validateWadPercentage(uint256 value_) internal pure {
        if (value_ > ONE_WAD) {
            revert Percentage_ExceedsWAD(value_, ONE_WAD);
        }
    }

    function _validateBondTerms(BondTerms memory terms_) internal pure {
        if (terms_.maxBonusPercentage > ONE_WAD) {
            revert BondTerms_MaxBonusExceedsWAD(terms_.maxBonusPercentage, ONE_WAD);
        }
        if (terms_.minBonusPercentage > terms_.maxBonusPercentage) {
            revert BondTerms_MinBonusExceedsMax(terms_.minBonusPercentage, terms_.maxBonusPercentage);
        }
        if (terms_.minLockDuration > terms_.maxLockDuration) {
            revert BondTerms_MinLockExceedsMax(terms_.minLockDuration, terms_.maxLockDuration);
        }
    }

    function _initVaultRegistryFeeOracle(
        Storage storage layout,
        IFeeCollectorProxy feeTo_,
        uint256 defaultVaultUsageFee_,
        BondTerms memory defaultBondTerms_,
        // DexTerms memory defaultDexTerms_,
        uint256 defaultDexSwapFee_,
        uint256 defaultSeigniorageIncentivePercentage_
        // KinkLendingTerms memory defaultLendingTerms_
    ) internal {
        _validateWadPercentage(defaultVaultUsageFee_);
        _validateWadPercentage(defaultDexSwapFee_);
        _validateWadPercentage(defaultSeigniorageIncentivePercentage_);
        _validateBondTerms(defaultBondTerms_);
        layout.feeTo = feeTo_;
        layout.defaultVaultUsageFee = defaultVaultUsageFee_;
        layout.defaultBondTerms = defaultBondTerms_;
        layout.defaultDexSwapFee = defaultDexSwapFee_;
        layout.defaultSeigniorageIncentivePercentage = defaultSeigniorageIncentivePercentage_;
        // layout.defaultLendingTerms = defaultLendingTerms_;
    }

    function _feeTo(Storage storage layout) internal view returns (IFeeCollectorProxy) {
        return layout.feeTo;
    }

    function _feeTo() internal view returns (IFeeCollectorProxy) {
        return _feeTo(_layout());
    }

    function _setFeeTo(Storage storage layout, IFeeCollectorProxy feeTo_)
        internal
        returns (IFeeCollectorProxy oldFeeTo)
    {
        oldFeeTo = layout.feeTo;
        layout.feeTo = feeTo_;
    }

    function _setFeeTo(IFeeCollectorProxy feeTo_) internal returns (IFeeCollectorProxy oldFeeTo) {
        return _setFeeTo(_layout(), feeTo_);
    }

    /* ------------------------------ Usage Fee ----------------------------- */

    function _defaultVaultUsageFee(Storage storage layout) internal view returns (uint256) {
        return layout.defaultVaultUsageFee;
    }

    function _defaultVaultUsageFee() internal view returns (uint256) {
        return _defaultVaultUsageFee(_layout());
    }

    function _setDefaultVaultUsageFee(Storage storage layout, uint256 defaultVaultUsageFee_)
        internal
        returns (uint256 oldDefaultVaultUsageFee)
    {
        _validateWadPercentage(defaultVaultUsageFee_);
        oldDefaultVaultUsageFee = layout.defaultVaultUsageFee;
        layout.defaultVaultUsageFee = defaultVaultUsageFee_;
    }

    function _setDefaultVaultUsageFee(uint256 defaultVaultUsageFee_)
        internal
        returns (uint256 oldDefaultVaultUsageFee)
    {
        return _setDefaultVaultUsageFee(_layout(), defaultVaultUsageFee_);
    }

    function _defaultUsageFeeOfTypeId(Storage storage layout, bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return layout.defaultUsageFeeOfType[vaultFeeTypeId_];
    }

    function _defaultUsageFeeOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _defaultUsageFeeOfTypeId(_layout(), vaultFeeTypeId_);
    }

    function _setDefaultUsageFeeOfTypeId(Storage storage layout, bytes4 vaultFeeTypeId_, uint256 defaultUsageFee_)
        internal
        returns (uint256 oldDefaultUsageFee)
    {
        _validateWadPercentage(defaultUsageFee_);
        oldDefaultUsageFee = layout.defaultUsageFeeOfType[vaultFeeTypeId_];
        layout.defaultUsageFeeOfType[vaultFeeTypeId_] = defaultUsageFee_;
    }

    function _setDefaultUsageFeeOfTypeId(bytes4 vaultFeeTypeId_, uint256 defaultUsageFee_)
        internal
        returns (uint256 oldDefaultUsageFee)
    {
        return _setDefaultUsageFeeOfTypeId(_layout(), vaultFeeTypeId_, defaultUsageFee_);
    }

    function _usageFeeOfVault(Storage storage layout, address vault_) internal view returns (uint256) {
        return layout.usageFeeOfVault[vault_];
    }

    function _usageFeeOfVault(address vault_) internal view returns (uint256) {
        return _usageFeeOfVault(_layout(), vault_);
    }

    function _overrideUsageFeeOfVault(Storage storage layout, address vault_, uint256 usageFee_)
        internal
        returns (uint256 oldUsageFee)
    {
        _validateWadPercentage(usageFee_);
        oldUsageFee = layout.usageFeeOfVault[vault_];
        layout.usageFeeOfVault[vault_] = usageFee_;
    }

    function _overrideUsageFeeOfVault(address vault_, uint256 usageFee_) internal returns (uint256 oldUsageFee) {
        return _overrideUsageFeeOfVault(_layout(), vault_, usageFee_);
    }

    /* ----------------------------- Bond Terms ----------------------------- */

    function _defaultBondTerms(Storage storage layout) internal view returns (BondTerms memory) {
        return layout.defaultBondTerms;
    }

    function _defaultBondTerms() internal view returns (BondTerms memory) {
        return _defaultBondTerms(_layout());
    }

    function _setDefaultBondTerms(Storage storage layout, BondTerms memory defaultBondTerms_)
        internal
        returns (BondTerms memory oldDefaultBondTerms)
    {
        _validateBondTerms(defaultBondTerms_);
        oldDefaultBondTerms = layout.defaultBondTerms;
        layout.defaultBondTerms = defaultBondTerms_;
    }

    function _setDefaultBondTerms(BondTerms memory defaultBondTerms_)
        internal
        returns (BondTerms memory oldDefaultBondTerms)
    {
        return _setDefaultBondTerms(_layout(), defaultBondTerms_);
    }

    function _defaultBondTermsOfVaultTypeId(Storage storage layout, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (BondTerms memory)
    {
        return layout.defaultBondTermsOfType[vaultFeeTypeId_];
    }

    function _defaultBondTermsOfVaultTypeId(bytes4 vaultFeeTypeId_) internal view returns (BondTerms memory) {
        return _defaultBondTermsOfVaultTypeId(_layout(), vaultFeeTypeId_);
    }

    function _setDefaultBondTermsOfTypeId(
        Storage storage layout,
        bytes4 vaultFeeTypeId_,
        BondTerms memory defaultBondTerms_
    ) internal returns (BondTerms memory oldDefaultBondTerms) {
        _validateBondTerms(defaultBondTerms_);
        oldDefaultBondTerms = layout.defaultBondTermsOfType[vaultFeeTypeId_];
        layout.defaultBondTermsOfType[vaultFeeTypeId_] = defaultBondTerms_;
    }

    function _setDefaultBondTermsOfTypeId(bytes4 vaultFeeTypeId_, BondTerms memory defaultBondTerms_)
        internal
        returns (BondTerms memory oldDefaultBondTerms)
    {
        return _setDefaultBondTermsOfTypeId(_layout(), vaultFeeTypeId_, defaultBondTerms_);
    }

    function _bondTermsOfVault(Storage storage layout, address vault_) internal view returns (BondTerms memory) {
        return layout.bondTermsOfVault[vault_];
    }

    function _bondTermsOfVault(address vault_) internal view returns (BondTerms memory) {
        return _bondTermsOfVault(_layout(), vault_);
    }

    function _overrideBondTermsOfVault(Storage storage layout, address vault_, BondTerms memory bondTerms_)
        internal
        returns (BondTerms memory oldBondTerms)
    {
        _validateBondTerms(bondTerms_);
        oldBondTerms = layout.bondTermsOfVault[vault_];
        layout.bondTermsOfVault[vault_] = bondTerms_;
    }

    function _overrideBondTermsOfVault(address vault_, BondTerms memory bondTerms_)
        internal
        returns (BondTerms memory oldBondTerms)
    {
        return _overrideBondTermsOfVault(_layout(), vault_, bondTerms_);
    }

    /* ------------------------------ DEX Terms ----------------------------- */

    function _defaultDexSwapFee(Storage storage layout) internal view returns (uint256 defaultDexSwapFee_) {
        return layout.defaultDexSwapFee;
    }

    function _defaultDexSwapFee() internal view returns (uint256) {
        return _defaultDexSwapFee(_layout());
    }

    function _setDefaultDexSwapFee(Storage storage layout, uint256 defaultDexSwapFee_)
        internal
        returns (uint256 oldDefaultDexSwapFee)
    {
        _validateWadPercentage(defaultDexSwapFee_);
        oldDefaultDexSwapFee = layout.defaultDexSwapFee;
        layout.defaultDexSwapFee = defaultDexSwapFee_;
    }

    function _setDefaultDexSwapFee(uint256 defaultDexSwapFee_) internal returns (uint256 oldDefaultDexSwapFee) {
        return _setDefaultDexSwapFee(_layout(), defaultDexSwapFee_);
    }

    function _defaultDexSwapFeeOfTypeId(Storage storage layout, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (uint256)
    {
        return layout.defaultDexSwapFeeOfType[vaultFeeTypeId_];
    }

    function _defaultDexSwapFeeOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _defaultDexSwapFeeOfTypeId(_layout(), vaultFeeTypeId_);
    }

    function _setDefaultDexSwapFeeOfTypeId(Storage storage layout, bytes4 vaultFeeTypeId_, uint256 defaultDexSwapFee_)
        internal
        returns (uint256 oldDefaultDexSwapFee)
    {
        _validateWadPercentage(defaultDexSwapFee_);
        oldDefaultDexSwapFee = layout.defaultDexSwapFeeOfType[vaultFeeTypeId_];
        layout.defaultDexSwapFeeOfType[vaultFeeTypeId_] = defaultDexSwapFee_;
    }

    function _setDefaultDexSwapFeeOfTypeId(bytes4 vaultFeeTypeId_, uint256 defaultDexSwapFee_)
        internal
        returns (uint256 oldDefaultDexSwapFee)
    {
        return _setDefaultDexSwapFeeOfTypeId(_layout(), vaultFeeTypeId_, defaultDexSwapFee_);
    }

    function _dexSwapFeeOfVault(Storage storage layout, address vault_) internal view returns (uint256) {
        return layout.dexSwapFeeOfVault[vault_];
    }

    function _dexSwapFeeOfVault(address vault_) internal view returns (uint256) {
        return _dexSwapFeeOfVault(_layout(), vault_);
    }

    function _overrideDexSwapFeeOfVault(Storage storage layout, address vault_, uint256 swapFee_)
        internal
        returns (uint256 oldSwapFee)
    {
        _validateWadPercentage(swapFee_);
        oldSwapFee = layout.dexSwapFeeOfVault[vault_];
        layout.dexSwapFeeOfVault[vault_] = swapFee_;
    }

    function _overrideDexSwapFeeOfVault(address vault_, uint256 swapFee_) internal returns (uint256 oldSwapFee) {
        return _overrideDexSwapFeeOfVault(_layout(), vault_, swapFee_);
    }

    /* ---------------------------- Seigniorage Terms --------------------------- */

    function _defaultSeigniorageIncentivePercentage(Storage storage layout) internal view returns (uint256) {
        return layout.defaultSeigniorageIncentivePercentage;
    }

    function _defaultSeigniorageIncentivePercentage() internal view returns (uint256) {
        return _defaultSeigniorageIncentivePercentage(_layout());
    }

    function _setDefaultSeigniorageIncentivePercentage(
        Storage storage layout,
        uint256 defaultSeigniorageIncentivePercentage_
    ) internal returns (uint256 oldDefaultSeigniorageIncentivePercentage) {
        _validateWadPercentage(defaultSeigniorageIncentivePercentage_);
        oldDefaultSeigniorageIncentivePercentage = layout.defaultSeigniorageIncentivePercentage;
        layout.defaultSeigniorageIncentivePercentage = defaultSeigniorageIncentivePercentage_;
    }

    function _setDefaultSeigniorageIncentivePercentage(uint256 defaultSeigniorageIncentivePercentage_)
        internal
        returns (uint256 oldDefaultSeigniorageIncentivePercentage)
    {
        return _setDefaultSeigniorageIncentivePercentage(_layout(), defaultSeigniorageIncentivePercentage_);
    }

    function _defaultSeigniorageIncentivePercentageOfTypeId(Storage storage layout, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (uint256)
    {
        return layout.seigniorageIncentivePercentageOfType[vaultFeeTypeId_];
    }

    function _defaultSeigniorageIncentivePercentageOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _defaultSeigniorageIncentivePercentageOfTypeId(_layout(), vaultFeeTypeId_);
    }

    function _setDefaultSeigniorageIncentivePercentageOfTypeId(
        Storage storage layout,
        bytes4 vaultTypeId_,
        uint256 defaultSeigniorageIncentivePercentage_
    ) internal returns (uint256 oldDefaultSeigniorageIncentivePercentage) {
        _validateWadPercentage(defaultSeigniorageIncentivePercentage_);
        oldDefaultSeigniorageIncentivePercentage = layout.seigniorageIncentivePercentageOfType[vaultTypeId_];
        layout.seigniorageIncentivePercentageOfType[vaultTypeId_] = defaultSeigniorageIncentivePercentage_;
    }

    function _setDefaultSeigniorageIncentivePercentageOfTypeId(
        bytes4 vaultTypeId_,
        uint256 defaultSeigniorageIncentivePercentage_
    ) internal returns (uint256 oldDefaultSeigniorageIncentivePercentage) {
        return _setDefaultSeigniorageIncentivePercentageOfTypeId(
            _layout(), vaultTypeId_, defaultSeigniorageIncentivePercentage_
        );
    }

    function _seigniorageIncentivePercentageOfVault(Storage storage layout, address vault_)
        internal
        view
        returns (uint256)
    {
        return layout.seigniorageIncentivePercentageOfVault[vault_];
    }

    function _seigniorageIncentivePercentageOfVault(address vault_) internal view returns (uint256) {
        return _seigniorageIncentivePercentageOfVault(_layout(), vault_);
    }

    function _overrideSeigniorageIncentivePercentageOfVault(
        Storage storage layout,
        address vault_,
        uint256 incentivePercentage_
    ) internal returns (uint256 oldIncentivePercentage) {
        _validateWadPercentage(incentivePercentage_);
        oldIncentivePercentage = layout.seigniorageIncentivePercentageOfVault[vault_];
        layout.seigniorageIncentivePercentageOfVault[vault_] = incentivePercentage_;
    }

    function _overrideSeigniorageIncentivePercentageOfVault(address vault_, uint256 incentivePercentage_)
        internal
        returns (uint256 oldIncentivePercentage)
    {
        return _overrideSeigniorageIncentivePercentageOfVault(_layout(), vault_, incentivePercentage_);
    }
}
