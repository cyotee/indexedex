// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    MultiVaultWeightedDetfExchangeQueryTarget
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfExchangeQueryTarget.sol";
import {
    MultiVaultWeightedDetfBondingTarget,
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    MultiVaultWeightedDetfInfoTarget,
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @dev Combined facet for exchange/bond/info/query (split later if size requires).
contract MultiVaultWeightedDetfExchangeInFacet is
    IFacet,
    MultiVaultWeightedDetfExchangeQueryTarget,
    MultiVaultWeightedDetfBondingTarget,
    MultiVaultWeightedDetfInfoTarget
{
    function facetName() external pure returns (string memory) {
        return "MultiVaultWeightedDetfExchangeInFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IMultiVaultWeightedDetfBonding).interfaceId;
        interfaces_[2] = type(IMultiVaultWeightedDetfInfo).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](26);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        funcs_[3] = bytes4(keccak256("exchangeOut(address,address,uint256,uint256,address,bool,uint256)"));
        funcs_[4] = IMultiVaultWeightedDetfBonding.bond.selector;
        funcs_[5] = IMultiVaultWeightedDetfBonding.initializeReserve.selector;
        funcs_[6] = IMultiVaultWeightedDetfBonding.sellPositionToProtocol.selector;
        funcs_[7] = IMultiVaultWeightedDetfBonding.sellNFT.selector;
        funcs_[8] = IMultiVaultWeightedDetfBonding.acceptedBondTokens.selector;
        funcs_[9] = IMultiVaultWeightedDetfBonding.redeemClaim.selector;
        funcs_[10] = IMultiVaultWeightedDetfInfo.isReserveLive.selector;
        funcs_[11] = IMultiVaultWeightedDetfInfo.vaultCount.selector;
        funcs_[12] = IMultiVaultWeightedDetfInfo.underlyingVaults.selector;
        funcs_[13] = IMultiVaultWeightedDetfInfo.vaultShares.selector;
        funcs_[14] = IMultiVaultWeightedDetfInfo.weights.selector;
        funcs_[15] = IMultiVaultWeightedDetfInfo.rateProvider.selector;
        funcs_[16] = IMultiVaultWeightedDetfInfo.rateAsset.selector;
        funcs_[17] = IMultiVaultWeightedDetfInfo.rateAssets.selector;
        funcs_[18] = IMultiVaultWeightedDetfInfo.reservePool.selector;
        funcs_[19] = IMultiVaultWeightedDetfInfo.syntheticPrice.selector;
        funcs_[20] = IMultiVaultWeightedDetfInfo.mintThreshold.selector;
        funcs_[21] = IMultiVaultWeightedDetfInfo.burnThreshold.selector;
        funcs_[22] = IMultiVaultWeightedDetfInfo.isMintingAllowed.selector;
        funcs_[23] = IMultiVaultWeightedDetfInfo.isBurningAllowed.selector;
        funcs_[24] = IMultiVaultWeightedDetfInfo.bondNftVault.selector;
        funcs_[25] = IMultiVaultWeightedDetfInfo.rebasingClaimToken.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "MultiVaultWeightedDetfExchangeInFacet";
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IMultiVaultWeightedDetfBonding).interfaceId;
        interfaces_[2] = type(IMultiVaultWeightedDetfInfo).interfaceId;
        funcs_ = new bytes4[](26);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        funcs_[3] = bytes4(keccak256("exchangeOut(address,address,uint256,uint256,address,bool,uint256)"));
        funcs_[4] = IMultiVaultWeightedDetfBonding.bond.selector;
        funcs_[5] = IMultiVaultWeightedDetfBonding.initializeReserve.selector;
        funcs_[6] = IMultiVaultWeightedDetfBonding.sellPositionToProtocol.selector;
        funcs_[7] = IMultiVaultWeightedDetfBonding.sellNFT.selector;
        funcs_[8] = IMultiVaultWeightedDetfBonding.acceptedBondTokens.selector;
        funcs_[9] = IMultiVaultWeightedDetfBonding.redeemClaim.selector;
        funcs_[10] = IMultiVaultWeightedDetfInfo.isReserveLive.selector;
        funcs_[11] = IMultiVaultWeightedDetfInfo.vaultCount.selector;
        funcs_[12] = IMultiVaultWeightedDetfInfo.underlyingVaults.selector;
        funcs_[13] = IMultiVaultWeightedDetfInfo.vaultShares.selector;
        funcs_[14] = IMultiVaultWeightedDetfInfo.weights.selector;
        funcs_[15] = IMultiVaultWeightedDetfInfo.rateProvider.selector;
        funcs_[16] = IMultiVaultWeightedDetfInfo.rateAsset.selector;
        funcs_[17] = IMultiVaultWeightedDetfInfo.rateAssets.selector;
        funcs_[18] = IMultiVaultWeightedDetfInfo.reservePool.selector;
        funcs_[19] = IMultiVaultWeightedDetfInfo.syntheticPrice.selector;
        funcs_[20] = IMultiVaultWeightedDetfInfo.mintThreshold.selector;
        funcs_[21] = IMultiVaultWeightedDetfInfo.burnThreshold.selector;
        funcs_[22] = IMultiVaultWeightedDetfInfo.isMintingAllowed.selector;
        funcs_[23] = IMultiVaultWeightedDetfInfo.isBurningAllowed.selector;
        funcs_[24] = IMultiVaultWeightedDetfInfo.bondNftVault.selector;
        funcs_[25] = IMultiVaultWeightedDetfInfo.rebasingClaimToken.selector;
    }
}
