// SPDX-License-Identifier: BSL-1.1
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
    error SeignioragePotShares_SumNotBelowWAD(uint256 feeToShare, uint256 creatorShare);

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
        /// @dev Global default liquid sleeve target as WAD fraction of total reserve (0 = unset).
        uint256 defaultLiquidReservePercentage;
        mapping(bytes4 vaultFeeTypeId => uint256 percentage) defaultLiquidReservePercentageOfType;
        mapping(address vault => uint256 percentage) liquidReservePercentageOfVault;
        /// @dev Global default `f` (feeTo share of pot). WAD. 0 = unset.
        uint256 defaultSeigniorageFeeToSharePercentage;
        mapping(bytes4 vaultFeeTypeId => uint256 percentage) seigniorageFeeToSharePercentageOfType;
        mapping(address vault => uint256 percentage) seigniorageFeeToSharePercentageOfVault;
        /// @dev Global default `c` (creator share of pot). WAD. 0 = unset.
        uint256 defaultSeigniorageCreatorSharePercentage;
        mapping(bytes4 vaultFeeTypeId => uint256 percentage) seigniorageCreatorSharePercentageOfType;
        mapping(address vault => uint256 percentage) seigniorageCreatorSharePercentageOfVault;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _validateWadPercentage(uint256 value_) internal pure {
        if (value_ > ONE_WAD) {
            revert Percentage_ExceedsWAD(value_, ONE_WAD);
        }
    }

    /// @notice Reject resolved `f + c >= 1e18`. Either value may be 0 (unset at that tier).
    function _assertPotSharesBelowWad(uint256 feeToShare_, uint256 creatorShare_) internal pure {
        if (feeToShare_ + creatorShare_ >= ONE_WAD) {
            revert SeignioragePotShares_SumNotBelowWAD(feeToShare_, creatorShare_);
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
        Storage storage layoutStruct,
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
        layoutStruct.feeTo = feeTo_;
        layoutStruct.defaultVaultUsageFee = defaultVaultUsageFee_;
        layoutStruct.defaultBondTerms = defaultBondTerms_;
        layoutStruct.defaultDexSwapFee = defaultDexSwapFee_;
        layoutStruct.defaultSeigniorageIncentivePercentage = defaultSeigniorageIncentivePercentage_;
        // layoutStruct.defaultLendingTerms = defaultLendingTerms_;
    }

    function _feeTo(Storage storage layoutStruct) internal view returns (IFeeCollectorProxy) {
        return layoutStruct.feeTo;
    }

    function _feeTo() internal view returns (IFeeCollectorProxy) {
        return _feeTo(_layoutStruct());
    }

    function _setFeeTo(Storage storage layoutStruct, IFeeCollectorProxy feeTo_)
        internal
        returns (IFeeCollectorProxy oldFeeTo)
    {
        oldFeeTo = layoutStruct.feeTo;
        layoutStruct.feeTo = feeTo_;
    }

    function _setFeeTo(IFeeCollectorProxy feeTo_) internal returns (IFeeCollectorProxy oldFeeTo) {
        return _setFeeTo(_layoutStruct(), feeTo_);
    }

    /* ------------------------------ Usage Fee ----------------------------- */

    function _defaultVaultUsageFee(Storage storage layoutStruct) internal view returns (uint256) {
        return layoutStruct.defaultVaultUsageFee;
    }

    function _defaultVaultUsageFee() internal view returns (uint256) {
        return _defaultVaultUsageFee(_layoutStruct());
    }

    function _setDefaultVaultUsageFee(Storage storage layoutStruct, uint256 defaultVaultUsageFee_)
        internal
        returns (uint256 oldDefaultVaultUsageFee)
    {
        _validateWadPercentage(defaultVaultUsageFee_);
        oldDefaultVaultUsageFee = layoutStruct.defaultVaultUsageFee;
        layoutStruct.defaultVaultUsageFee = defaultVaultUsageFee_;
    }

    function _setDefaultVaultUsageFee(uint256 defaultVaultUsageFee_)
        internal
        returns (uint256 oldDefaultVaultUsageFee)
    {
        return _setDefaultVaultUsageFee(_layoutStruct(), defaultVaultUsageFee_);
    }

    function _defaultUsageFeeOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return layoutStruct.defaultUsageFeeOfType[vaultFeeTypeId_];
    }

    function _defaultUsageFeeOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _defaultUsageFeeOfTypeId(_layoutStruct(), vaultFeeTypeId_);
    }

    function _setDefaultUsageFeeOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_, uint256 defaultUsageFee_)
        internal
        returns (uint256 oldDefaultUsageFee)
    {
        _validateWadPercentage(defaultUsageFee_);
        oldDefaultUsageFee = layoutStruct.defaultUsageFeeOfType[vaultFeeTypeId_];
        layoutStruct.defaultUsageFeeOfType[vaultFeeTypeId_] = defaultUsageFee_;
    }

    function _setDefaultUsageFeeOfTypeId(bytes4 vaultFeeTypeId_, uint256 defaultUsageFee_)
        internal
        returns (uint256 oldDefaultUsageFee)
    {
        return _setDefaultUsageFeeOfTypeId(_layoutStruct(), vaultFeeTypeId_, defaultUsageFee_);
    }

    function _usageFeeOfVault(Storage storage layoutStruct, address vault_) internal view returns (uint256) {
        return layoutStruct.usageFeeOfVault[vault_];
    }

    function _usageFeeOfVault(address vault_) internal view returns (uint256) {
        return _usageFeeOfVault(_layoutStruct(), vault_);
    }

    function _overrideUsageFeeOfVault(Storage storage layoutStruct, address vault_, uint256 usageFee_)
        internal
        returns (uint256 oldUsageFee)
    {
        _validateWadPercentage(usageFee_);
        oldUsageFee = layoutStruct.usageFeeOfVault[vault_];
        layoutStruct.usageFeeOfVault[vault_] = usageFee_;
    }

    function _overrideUsageFeeOfVault(address vault_, uint256 usageFee_) internal returns (uint256 oldUsageFee) {
        return _overrideUsageFeeOfVault(_layoutStruct(), vault_, usageFee_);
    }

    /* ----------------------------- Bond Terms ----------------------------- */

    function _defaultBondTerms(Storage storage layoutStruct) internal view returns (BondTerms memory) {
        return layoutStruct.defaultBondTerms;
    }

    function _defaultBondTerms() internal view returns (BondTerms memory) {
        return _defaultBondTerms(_layoutStruct());
    }

    function _setDefaultBondTerms(Storage storage layoutStruct, BondTerms memory defaultBondTerms_)
        internal
        returns (BondTerms memory oldDefaultBondTerms)
    {
        _validateBondTerms(defaultBondTerms_);
        oldDefaultBondTerms = layoutStruct.defaultBondTerms;
        layoutStruct.defaultBondTerms = defaultBondTerms_;
    }

    function _setDefaultBondTerms(BondTerms memory defaultBondTerms_)
        internal
        returns (BondTerms memory oldDefaultBondTerms)
    {
        return _setDefaultBondTerms(_layoutStruct(), defaultBondTerms_);
    }

    function _defaultBondTermsOfVaultTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (BondTerms memory)
    {
        return layoutStruct.defaultBondTermsOfType[vaultFeeTypeId_];
    }

    function _defaultBondTermsOfVaultTypeId(bytes4 vaultFeeTypeId_) internal view returns (BondTerms memory) {
        return _defaultBondTermsOfVaultTypeId(_layoutStruct(), vaultFeeTypeId_);
    }

    function _setDefaultBondTermsOfTypeId(
        Storage storage layoutStruct,
        bytes4 vaultFeeTypeId_,
        BondTerms memory defaultBondTerms_
    ) internal returns (BondTerms memory oldDefaultBondTerms) {
        _validateBondTerms(defaultBondTerms_);
        oldDefaultBondTerms = layoutStruct.defaultBondTermsOfType[vaultFeeTypeId_];
        layoutStruct.defaultBondTermsOfType[vaultFeeTypeId_] = defaultBondTerms_;
    }

    function _setDefaultBondTermsOfTypeId(bytes4 vaultFeeTypeId_, BondTerms memory defaultBondTerms_)
        internal
        returns (BondTerms memory oldDefaultBondTerms)
    {
        return _setDefaultBondTermsOfTypeId(_layoutStruct(), vaultFeeTypeId_, defaultBondTerms_);
    }

    function _bondTermsOfVault(Storage storage layoutStruct, address vault_) internal view returns (BondTerms memory) {
        return layoutStruct.bondTermsOfVault[vault_];
    }

    function _bondTermsOfVault(address vault_) internal view returns (BondTerms memory) {
        return _bondTermsOfVault(_layoutStruct(), vault_);
    }

    function _overrideBondTermsOfVault(Storage storage layoutStruct, address vault_, BondTerms memory bondTerms_)
        internal
        returns (BondTerms memory oldBondTerms)
    {
        _validateBondTerms(bondTerms_);
        oldBondTerms = layoutStruct.bondTermsOfVault[vault_];
        layoutStruct.bondTermsOfVault[vault_] = bondTerms_;
    }

    function _overrideBondTermsOfVault(address vault_, BondTerms memory bondTerms_)
        internal
        returns (BondTerms memory oldBondTerms)
    {
        return _overrideBondTermsOfVault(_layoutStruct(), vault_, bondTerms_);
    }

    /* ------------------------------ DEX Terms ----------------------------- */

    function _defaultDexSwapFee(Storage storage layoutStruct) internal view returns (uint256 defaultDexSwapFee_) {
        return layoutStruct.defaultDexSwapFee;
    }

    function _defaultDexSwapFee() internal view returns (uint256) {
        return _defaultDexSwapFee(_layoutStruct());
    }

    function _setDefaultDexSwapFee(Storage storage layoutStruct, uint256 defaultDexSwapFee_)
        internal
        returns (uint256 oldDefaultDexSwapFee)
    {
        _validateWadPercentage(defaultDexSwapFee_);
        oldDefaultDexSwapFee = layoutStruct.defaultDexSwapFee;
        layoutStruct.defaultDexSwapFee = defaultDexSwapFee_;
    }

    function _setDefaultDexSwapFee(uint256 defaultDexSwapFee_) internal returns (uint256 oldDefaultDexSwapFee) {
        return _setDefaultDexSwapFee(_layoutStruct(), defaultDexSwapFee_);
    }

    function _defaultDexSwapFeeOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.defaultDexSwapFeeOfType[vaultFeeTypeId_];
    }

    function _defaultDexSwapFeeOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _defaultDexSwapFeeOfTypeId(_layoutStruct(), vaultFeeTypeId_);
    }

    function _setDefaultDexSwapFeeOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_, uint256 defaultDexSwapFee_)
        internal
        returns (uint256 oldDefaultDexSwapFee)
    {
        _validateWadPercentage(defaultDexSwapFee_);
        oldDefaultDexSwapFee = layoutStruct.defaultDexSwapFeeOfType[vaultFeeTypeId_];
        layoutStruct.defaultDexSwapFeeOfType[vaultFeeTypeId_] = defaultDexSwapFee_;
    }

    function _setDefaultDexSwapFeeOfTypeId(bytes4 vaultFeeTypeId_, uint256 defaultDexSwapFee_)
        internal
        returns (uint256 oldDefaultDexSwapFee)
    {
        return _setDefaultDexSwapFeeOfTypeId(_layoutStruct(), vaultFeeTypeId_, defaultDexSwapFee_);
    }

    function _dexSwapFeeOfVault(Storage storage layoutStruct, address vault_) internal view returns (uint256) {
        return layoutStruct.dexSwapFeeOfVault[vault_];
    }

    function _dexSwapFeeOfVault(address vault_) internal view returns (uint256) {
        return _dexSwapFeeOfVault(_layoutStruct(), vault_);
    }

    function _overrideDexSwapFeeOfVault(Storage storage layoutStruct, address vault_, uint256 swapFee_)
        internal
        returns (uint256 oldSwapFee)
    {
        _validateWadPercentage(swapFee_);
        oldSwapFee = layoutStruct.dexSwapFeeOfVault[vault_];
        layoutStruct.dexSwapFeeOfVault[vault_] = swapFee_;
    }

    function _overrideDexSwapFeeOfVault(address vault_, uint256 swapFee_) internal returns (uint256 oldSwapFee) {
        return _overrideDexSwapFeeOfVault(_layoutStruct(), vault_, swapFee_);
    }

    /* ---------------------------- Seigniorage Terms --------------------------- */

    function _defaultSeigniorageIncentivePercentage(Storage storage layoutStruct) internal view returns (uint256) {
        return layoutStruct.defaultSeigniorageIncentivePercentage;
    }

    function _defaultSeigniorageIncentivePercentage() internal view returns (uint256) {
        return _defaultSeigniorageIncentivePercentage(_layoutStruct());
    }

    function _setDefaultSeigniorageIncentivePercentage(
        Storage storage layoutStruct,
        uint256 defaultSeigniorageIncentivePercentage_
    ) internal returns (uint256 oldDefaultSeigniorageIncentivePercentage) {
        _validateWadPercentage(defaultSeigniorageIncentivePercentage_);
        oldDefaultSeigniorageIncentivePercentage = layoutStruct.defaultSeigniorageIncentivePercentage;
        layoutStruct.defaultSeigniorageIncentivePercentage = defaultSeigniorageIncentivePercentage_;
    }

    function _setDefaultSeigniorageIncentivePercentage(uint256 defaultSeigniorageIncentivePercentage_)
        internal
        returns (uint256 oldDefaultSeigniorageIncentivePercentage)
    {
        return _setDefaultSeigniorageIncentivePercentage(_layoutStruct(), defaultSeigniorageIncentivePercentage_);
    }

    function _defaultSeigniorageIncentivePercentageOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.seigniorageIncentivePercentageOfType[vaultFeeTypeId_];
    }

    function _defaultSeigniorageIncentivePercentageOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _defaultSeigniorageIncentivePercentageOfTypeId(_layoutStruct(), vaultFeeTypeId_);
    }

    function _setDefaultSeigniorageIncentivePercentageOfTypeId(
        Storage storage layoutStruct,
        bytes4 vaultTypeId_,
        uint256 defaultSeigniorageIncentivePercentage_
    ) internal returns (uint256 oldDefaultSeigniorageIncentivePercentage) {
        _validateWadPercentage(defaultSeigniorageIncentivePercentage_);
        oldDefaultSeigniorageIncentivePercentage = layoutStruct.seigniorageIncentivePercentageOfType[vaultTypeId_];
        layoutStruct.seigniorageIncentivePercentageOfType[vaultTypeId_] = defaultSeigniorageIncentivePercentage_;
    }

    function _setDefaultSeigniorageIncentivePercentageOfTypeId(
        bytes4 vaultTypeId_,
        uint256 defaultSeigniorageIncentivePercentage_
    ) internal returns (uint256 oldDefaultSeigniorageIncentivePercentage) {
        return _setDefaultSeigniorageIncentivePercentageOfTypeId(
            _layoutStruct(), vaultTypeId_, defaultSeigniorageIncentivePercentage_
        );
    }

    function _seigniorageIncentivePercentageOfVault(Storage storage layoutStruct, address vault_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.seigniorageIncentivePercentageOfVault[vault_];
    }

    function _seigniorageIncentivePercentageOfVault(address vault_) internal view returns (uint256) {
        return _seigniorageIncentivePercentageOfVault(_layoutStruct(), vault_);
    }

    function _overrideSeigniorageIncentivePercentageOfVault(
        Storage storage layoutStruct,
        address vault_,
        uint256 incentivePercentage_
    ) internal returns (uint256 oldIncentivePercentage) {
        _validateWadPercentage(incentivePercentage_);
        oldIncentivePercentage = layoutStruct.seigniorageIncentivePercentageOfVault[vault_];
        layoutStruct.seigniorageIncentivePercentageOfVault[vault_] = incentivePercentage_;
    }

    function _overrideSeigniorageIncentivePercentageOfVault(address vault_, uint256 incentivePercentage_)
        internal
        returns (uint256 oldIncentivePercentage)
    {
        return _overrideSeigniorageIncentivePercentageOfVault(_layoutStruct(), vault_, incentivePercentage_);
    }

    /* ------------------------- Liquid reserve policy -------------------------- */

    function _defaultLiquidReservePercentage(Storage storage layoutStruct) internal view returns (uint256) {
        return layoutStruct.defaultLiquidReservePercentage;
    }

    function _defaultLiquidReservePercentage() internal view returns (uint256) {
        return _defaultLiquidReservePercentage(_layoutStruct());
    }

    function _setDefaultLiquidReservePercentage(Storage storage layoutStruct, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.defaultLiquidReservePercentage;
        layoutStruct.defaultLiquidReservePercentage = percentage_;
    }

    function _setDefaultLiquidReservePercentage(uint256 percentage_) internal returns (uint256 oldPercentage) {
        return _setDefaultLiquidReservePercentage(_layoutStruct(), percentage_);
    }

    function _defaultLiquidReservePercentageOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.defaultLiquidReservePercentageOfType[vaultFeeTypeId_];
    }

    function _defaultLiquidReservePercentageOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _defaultLiquidReservePercentageOfTypeId(_layoutStruct(), vaultFeeTypeId_);
    }

    function _setDefaultLiquidReservePercentageOfTypeId(
        Storage storage layoutStruct,
        bytes4 vaultTypeId_,
        uint256 percentage_
    ) internal returns (uint256 oldPercentage) {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.defaultLiquidReservePercentageOfType[vaultTypeId_];
        layoutStruct.defaultLiquidReservePercentageOfType[vaultTypeId_] = percentage_;
    }

    function _setDefaultLiquidReservePercentageOfTypeId(bytes4 vaultTypeId_, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        return _setDefaultLiquidReservePercentageOfTypeId(_layoutStruct(), vaultTypeId_, percentage_);
    }

    function _liquidReservePercentageOfVault(Storage storage layoutStruct, address vault_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.liquidReservePercentageOfVault[vault_];
    }

    function _liquidReservePercentageOfVault(address vault_) internal view returns (uint256) {
        return _liquidReservePercentageOfVault(_layoutStruct(), vault_);
    }

    function _overrideLiquidReservePercentageOfVault(
        Storage storage layoutStruct,
        address vault_,
        uint256 percentage_
    ) internal returns (uint256 oldPercentage) {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.liquidReservePercentageOfVault[vault_];
        layoutStruct.liquidReservePercentageOfVault[vault_] = percentage_;
    }

    function _overrideLiquidReservePercentageOfVault(address vault_, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        return _overrideLiquidReservePercentageOfVault(_layoutStruct(), vault_, percentage_);
    }

    /* ---------------------- Seigniorage pot shares f / c ---------------------- */

    function _defaultSeigniorageFeeToSharePercentage(Storage storage layoutStruct) internal view returns (uint256) {
        return layoutStruct.defaultSeigniorageFeeToSharePercentage;
    }

    function _defaultSeigniorageFeeToSharePercentage() internal view returns (uint256) {
        return _defaultSeigniorageFeeToSharePercentage(_layoutStruct());
    }

    function _setDefaultSeigniorageFeeToSharePercentage(Storage storage layoutStruct, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.defaultSeigniorageFeeToSharePercentage;
        layoutStruct.defaultSeigniorageFeeToSharePercentage = percentage_;
    }

    function _setDefaultSeigniorageFeeToSharePercentage(uint256 percentage_) internal returns (uint256 oldPercentage) {
        return _setDefaultSeigniorageFeeToSharePercentage(_layoutStruct(), percentage_);
    }

    function _seigniorageFeeToSharePercentageOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.seigniorageFeeToSharePercentageOfType[vaultFeeTypeId_];
    }

    function _seigniorageFeeToSharePercentageOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _seigniorageFeeToSharePercentageOfTypeId(_layoutStruct(), vaultFeeTypeId_);
    }

    function _setSeigniorageFeeToSharePercentageOfTypeId(
        Storage storage layoutStruct,
        bytes4 vaultTypeId_,
        uint256 percentage_
    ) internal returns (uint256 oldPercentage) {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.seigniorageFeeToSharePercentageOfType[vaultTypeId_];
        layoutStruct.seigniorageFeeToSharePercentageOfType[vaultTypeId_] = percentage_;
    }

    function _setSeigniorageFeeToSharePercentageOfTypeId(bytes4 vaultTypeId_, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        return _setSeigniorageFeeToSharePercentageOfTypeId(_layoutStruct(), vaultTypeId_, percentage_);
    }

    function _seigniorageFeeToSharePercentageOfVault(Storage storage layoutStruct, address vault_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.seigniorageFeeToSharePercentageOfVault[vault_];
    }

    function _seigniorageFeeToSharePercentageOfVault(address vault_) internal view returns (uint256) {
        return _seigniorageFeeToSharePercentageOfVault(_layoutStruct(), vault_);
    }

    function _overrideSeigniorageFeeToSharePercentageOfVault(
        Storage storage layoutStruct,
        address vault_,
        uint256 percentage_
    ) internal returns (uint256 oldPercentage) {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.seigniorageFeeToSharePercentageOfVault[vault_];
        layoutStruct.seigniorageFeeToSharePercentageOfVault[vault_] = percentage_;
    }

    function _overrideSeigniorageFeeToSharePercentageOfVault(address vault_, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        return _overrideSeigniorageFeeToSharePercentageOfVault(_layoutStruct(), vault_, percentage_);
    }

    function _defaultSeigniorageCreatorSharePercentage(Storage storage layoutStruct) internal view returns (uint256) {
        return layoutStruct.defaultSeigniorageCreatorSharePercentage;
    }

    function _defaultSeigniorageCreatorSharePercentage() internal view returns (uint256) {
        return _defaultSeigniorageCreatorSharePercentage(_layoutStruct());
    }

    function _setDefaultSeigniorageCreatorSharePercentage(Storage storage layoutStruct, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.defaultSeigniorageCreatorSharePercentage;
        layoutStruct.defaultSeigniorageCreatorSharePercentage = percentage_;
    }

    function _setDefaultSeigniorageCreatorSharePercentage(uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        return _setDefaultSeigniorageCreatorSharePercentage(_layoutStruct(), percentage_);
    }

    function _seigniorageCreatorSharePercentageOfTypeId(Storage storage layoutStruct, bytes4 vaultFeeTypeId_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.seigniorageCreatorSharePercentageOfType[vaultFeeTypeId_];
    }

    function _seigniorageCreatorSharePercentageOfTypeId(bytes4 vaultFeeTypeId_) internal view returns (uint256) {
        return _seigniorageCreatorSharePercentageOfTypeId(_layoutStruct(), vaultFeeTypeId_);
    }

    function _setSeigniorageCreatorSharePercentageOfTypeId(
        Storage storage layoutStruct,
        bytes4 vaultTypeId_,
        uint256 percentage_
    ) internal returns (uint256 oldPercentage) {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.seigniorageCreatorSharePercentageOfType[vaultTypeId_];
        layoutStruct.seigniorageCreatorSharePercentageOfType[vaultTypeId_] = percentage_;
    }

    function _setSeigniorageCreatorSharePercentageOfTypeId(bytes4 vaultTypeId_, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        return _setSeigniorageCreatorSharePercentageOfTypeId(_layoutStruct(), vaultTypeId_, percentage_);
    }

    function _seigniorageCreatorSharePercentageOfVault(Storage storage layoutStruct, address vault_)
        internal
        view
        returns (uint256)
    {
        return layoutStruct.seigniorageCreatorSharePercentageOfVault[vault_];
    }

    function _seigniorageCreatorSharePercentageOfVault(address vault_) internal view returns (uint256) {
        return _seigniorageCreatorSharePercentageOfVault(_layoutStruct(), vault_);
    }

    function _overrideSeigniorageCreatorSharePercentageOfVault(
        Storage storage layoutStruct,
        address vault_,
        uint256 percentage_
    ) internal returns (uint256 oldPercentage) {
        _validateWadPercentage(percentage_);
        oldPercentage = layoutStruct.seigniorageCreatorSharePercentageOfVault[vault_];
        layoutStruct.seigniorageCreatorSharePercentageOfVault[vault_] = percentage_;
    }

    function _overrideSeigniorageCreatorSharePercentageOfVault(address vault_, uint256 percentage_)
        internal
        returns (uint256 oldPercentage)
    {
        return _overrideSeigniorageCreatorSharePercentageOfVault(_layoutStruct(), vault_, percentage_);
    }
}
