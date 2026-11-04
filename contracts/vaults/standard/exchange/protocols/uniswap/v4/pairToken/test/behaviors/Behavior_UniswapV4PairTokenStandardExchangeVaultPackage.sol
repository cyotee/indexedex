// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "../../interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "../../interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";

// tag::Behavior_UniswapV4PairTokenStandardExchangeVaultPackage[]
/// @notice Independent typed S1-ARCH-04/API-05 product manifest and local package checks.
/// @dev Controls never read facet metadata or the package's own selector manifest.
library Behavior_UniswapV4PairTokenStandardExchangeVaultPackage {
    /// @notice Expected twelve addresses in explicit package-input order.
    function components(IPackage.PkgInit memory init_) internal pure returns (IFacet[] memory facets_) {
        facets_ = new IFacet[](12);
        facets_[0] = init_.erc20Facet;
        facets_[1] = init_.erc2612Facet;
        facets_[2] = init_.erc5267Facet;
        facets_[3] = init_.basicVaultFacet;
        facets_[4] = init_.standardVaultFacet;
        facets_[5] = init_.moneyFacet;
        facets_[6] = init_.quoteFacet;
        facets_[7] = init_.outFacet;
        facets_[8] = init_.queryFacet;
        facets_[9] = init_.syMoneyFacet;
        facets_[10] = init_.syQueryFacet;
        facets_[11] = init_.callbackFacet;
    }

    /// @notice Product/interface-derived selector controls for all twelve facets.
    function selectors(uint256 index_) internal pure returns (bytes4[] memory s_) {
        uint256[12] memory counts_ = [uint256(9), 3, 1, 3, 4, 5, 5, 2, 11, 4, 12, 1];
        require(index_ < 12, "manifest index");
        s_ = new bytes4[](counts_[index_]);
        if (index_ == 0) {
            s_[0] = IERC20Metadata.name.selector;
            s_[1] = IERC20Metadata.symbol.selector;
            s_[2] = IERC20Metadata.decimals.selector;
            s_[3] = IERC20.totalSupply.selector;
            s_[4] = IERC20.balanceOf.selector;
            s_[5] = IERC20.allowance.selector;
            s_[6] = IERC20.approve.selector;
            s_[7] = IERC20.transfer.selector;
            s_[8] = IERC20.transferFrom.selector;
        } else if (index_ == 1) {
            s_[0] = IERC20Permit.permit.selector;
            s_[1] = IERC20Permit.nonces.selector;
            s_[2] = IERC20Permit.DOMAIN_SEPARATOR.selector;
        } else if (index_ == 2) {
            s_[0] = IERC5267.eip712Domain.selector;
        } else if (index_ == 3) {
            s_[0] = IBasicVault.vaultTokens.selector;
            s_[1] = IBasicVault.reserveOfToken.selector;
            s_[2] = IBasicVault.reserves.selector;
        } else if (index_ == 4) {
            s_[0] = IStandardVault.vaultFeeTypeIds.selector;
            s_[1] = IStandardVault.contentsId.selector;
            s_[2] = IStandardVault.vaultTypes.selector;
            s_[3] = IStandardVault.vaultConfig.selector;
        } else if (index_ == 5) {
            s_[0] = IStandardExchangeIn.exchangeIn.selector;
            s_[1] = IVault.depositPair.selector;
            s_[2] = IVault.redeemPair.selector;
            s_[3] = IVault.donate.selector;
            s_[4] = IVault.compound.selector;
        } else if (index_ == 6) {
            s_[0] = IStandardExchangeIn.previewExchangeIn.selector;
            s_[1] = IVault.previewDepositPair.selector;
            s_[2] = IVault.previewRedeemPair.selector;
            s_[3] = IVault.previewWithdrawalMode.selector;
            s_[4] = IVault.previewZapCredit.selector;
        } else if (index_ == 7) {
            s_[0] = IStandardExchangeOut.previewExchangeOut.selector;
            s_[1] = IStandardExchangeOut.exchangeOut.selector;
        } else if (index_ == 8) {
            s_[0] = IVault.poolManager.selector;
            s_[1] = IVault.poolKey.selector;
            s_[2] = IVault.wrappedNative.selector;
            s_[3] = IVault.rateAsset.selector;
            s_[4] = IVault.tickLower.selector;
            s_[5] = IVault.tickUpper.selector;
            s_[6] = IVault.positionLiquidity.selector;
            s_[7] = IVault.localReserves.selector;
            s_[8] = IVault.basket.selector;
            s_[9] = IVault.maxZapBps.selector;
            s_[10] = IVault.maxZapTickMove.selector;
        } else if (index_ == 9) {
            s_[0] = IStandardizedYield.deposit.selector;
            s_[1] = IStandardizedYield.redeem.selector;
            s_[2] = IStandardizedYield.rewardIndexesCurrent.selector;
            s_[3] = IStandardizedYield.claimRewards.selector;
        } else if (index_ == 10) {
            s_[0] = IStandardizedYield.previewDeposit.selector;
            s_[1] = IStandardizedYield.previewRedeem.selector;
            s_[2] = IStandardizedYield.getTokensIn.selector;
            s_[3] = IStandardizedYield.getTokensOut.selector;
            s_[4] = IStandardizedYield.yieldToken.selector;
            s_[5] = IStandardizedYield.assetInfo.selector;
            s_[6] = IStandardizedYield.exchangeRate.selector;
            s_[7] = IStandardizedYield.isValidTokenIn.selector;
            s_[8] = IStandardizedYield.isValidTokenOut.selector;
            s_[9] = IStandardizedYield.getRewardTokens.selector;
            s_[10] = IStandardizedYield.accruedRewards.selector;
            s_[11] = IStandardizedYield.rewardIndexesStored.selector;
        } else {
            s_[0] = IUnlockCallback.unlockCallback.selector;
        }
    }

    /// @notice Expected declarations; split family/SY IDs close only on the full proxy.
    function interfaces(uint256 index_) internal pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](index_ == 0 ? 3 : (index_ == 5 || index_ == 6 ? 2 : 1));
        if (index_ == 0) {
            ids_[0] = type(IERC20).interfaceId;
            ids_[1] = type(IERC20Metadata).interfaceId;
            ids_[2] = type(IERC20Metadata).interfaceId ^ type(IERC20).interfaceId;
        } else if (index_ == 1) ids_[0] = type(IERC20Permit).interfaceId;
        else if (index_ == 2) ids_[0] = type(IERC5267).interfaceId;
        else if (index_ == 3) ids_[0] = type(IBasicVault).interfaceId;
        else if (index_ == 4) ids_[0] = type(IStandardVault).interfaceId;
        else if (index_ == 5 || index_ == 6) {
            ids_[0] = type(IVault).interfaceId;
            ids_[1] = type(IStandardExchangeIn).interfaceId;
        } else if (index_ == 7) ids_[0] = type(IStandardExchangeOut).interfaceId;
        else if (index_ == 8) ids_[0] = type(IVault).interfaceId;
        else if (index_ == 9 || index_ == 10) ids_[0] = type(IStandardizedYield).interfaceId;
        else {
            require(index_ == 11, "manifest index");
            ids_[0] = type(IUnlockCallback).interfaceId;
        }
    }

    /// @notice Canonical names independent of the deployed facet getters.
    function facetName(uint256 index_) internal pure returns (string memory) {
        string[12] memory names_ = [
            string("ERC20Facet"), "ERC2612Facet", "ERC5267Facet", "MultiAssetBasicVaultFacet",
            "MultiAssetStandardVaultFacet", "UniswapV4PairTokenStandardExchangeVaultMoneyFacet",
            "UniswapV4PairTokenStandardExchangeVaultQuoteFacet", "UniswapV4PairTokenStandardExchangeVaultOutFacet",
            "UniswapV4PairTokenStandardExchangeVaultQueryFacet", "UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet",
            "UniswapV4PairTokenStandardExchangeVaultSYQueryFacet", "UniswapV4PairTokenStandardExchangeVaultCallbackFacet"
        ];
        return names_[index_];
    }

    /// @notice Exact set equality with duplicate rejection, including length.
    function sameSet(bytes4[] memory expected_, bytes4[] memory actual_) internal pure returns (bool) {
        if (expected_.length != actual_.length) return false;
        for (uint256 i_; i_ < expected_.length; ++i_) {
            uint256 matches_;
            for (uint256 j_; j_ < actual_.length; ++j_) if (expected_[i_] == actual_[j_]) ++matches_;
            if (matches_ != 1) return false;
            for (uint256 j_; j_ < i_; ++j_) if (expected_[i_] == expected_[j_]) return false;
        }
        return true;
    }

    /// @notice Deduplicated package-owned interface union, excluding factory capabilities.
    function packageInterfaces() internal pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](12);
        uint256 used_;
        for (uint256 i_; i_ < 12; ++i_) {
            bytes4[] memory next_ = interfaces(i_);
            for (uint256 j_; j_ < next_.length; ++j_) {
                bool exists_;
                for (uint256 k_; k_ < used_; ++k_) if (ids_[k_] == next_[j_]) exists_ = true;
                if (!exists_) ids_[used_++] = next_[j_];
            }
        }
        require(used_ == 12, "interface union");
    }

    /// @notice Validate package metadata/config/cuts and binding identity against independent controls.
    function hasValidDeclaration(IPackage package_, IPackage.PkgInit memory init_) internal view returns (bool) {
        string memory name_ = "UniswapV4PairTokenStandardExchangeVaultDFPkg";
        require(keccak256(bytes(package_.packageName())) == keccak256(bytes(name_)), "package name");
        require(keccak256(bytes(package_.name())) == keccak256(bytes(name_)), "standard package name");
        require(package_.bindingHash() == keccak256(abi.encode(init_)), "binding hash");
        require(package_.vaultFeeTypeIds() == bytes32(0), "package fee ids");
        bytes4[] memory expectedIds_ = packageInterfaces();
        require(sameSet(expectedIds_, package_.facetInterfaces()), "package interfaces");
        require(sameSet(expectedIds_, package_.vaultTypes()), "package types");
        IStandardVaultPkg.VaultPkgDeclaration memory declaration_ = package_.vaultDeclaration();
        require(keccak256(bytes(declaration_.name)) == keccak256(bytes(name_)), "declaration name");
        require(declaration_.vaultFeeTypeIds == bytes32(0), "declaration fees");
        require(sameSet(expectedIds_, declaration_.vaultTypes), "declaration types");
        _checkCuts(package_, init_);
        (string memory metadataName_, bytes4[] memory ids_, address[] memory addresses_) = package_.packageMetadata();
        require(keccak256(bytes(metadataName_)) == keccak256(bytes(name_)), "metadata name");
        require(sameSet(expectedIds_, ids_), "metadata interfaces");
        require(keccak256(abi.encode(addresses_)) == keccak256(abi.encode(package_.facetAddresses())), "metadata addresses");
        return true;
    }

    function _checkCuts(IPackage package_, IPackage.PkgInit memory init_) private view {
        IFacet[] memory expected_ = components(init_);
        address[] memory actual_ = package_.facetAddresses();
        IDiamond.FacetCut[] memory cuts_ = package_.facetCuts();
        IDiamondFactoryPackage.DiamondConfig memory config_ = package_.diamondConfig();
        require(actual_.length == 12 && cuts_.length == 12, "component count");
        require(keccak256(abi.encode(config_.facetCuts)) == keccak256(abi.encode(cuts_)), "diamond cuts");
        require(sameSet(packageInterfaces(), config_.interfaces), "diamond interfaces");
        bytes4[] memory seen_ = new bytes4[](60);
        uint256 used_;
        for (uint256 i_; i_ < 12; ++i_) {
            require(actual_[i_] == address(expected_[i_]) && cuts_[i_].facetAddress == actual_[i_], "component address");
            require(cuts_[i_].action == IDiamond.FacetCutAction.Add, "cut action");
            bytes4[] memory controls_ = selectors(i_);
            require(sameSet(controls_, cuts_[i_].functionSelectors), "typed cut");
            for (uint256 j_; j_ < controls_.length; ++j_) {
                for (uint256 k_; k_ < used_; ++k_) require(seen_[k_] != controls_[j_], "selector overlap");
                seen_[used_++] = controls_[j_];
            }
        }
        require(used_ == 60, "product selector count");
    }
}
// end::Behavior_UniswapV4PairTokenStandardExchangeVaultPackage[]
