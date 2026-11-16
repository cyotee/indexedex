// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDetfReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";

import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";

import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

contract Adversarial_ComposedStable_Surface_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    function _has(IFacet facet_, bytes4 selector_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        bool found_;
        for (uint256 i_; i_ < funcs_.length; ++i_) {
            if (funcs_[i_] == selector_) found_ = true;
        }
        assertTrue(found_, "target selector declared");
        assertEq(
            IDiamondLoupe(deployedDetfVault).facetAddress(selector_),
            address(facet_),
            "selector reaches production facet"
        );
    }

    function test_J1_exchangeIn_targetSelectors_subseteq_facetFuncs() public view {
        assertEq(exchangeInFacet.facetFuncs().length, 2);
        _has(exchangeInFacet, IStandardExchangeIn.exchangeIn.selector);
        _has(pricingFacet, IStandardExchangeIn.previewExchangeIn.selector);
    }

    function test_J1_bonding_targetSelectors_subseteq_facetFuncs() public view {
        assertEq(bondingFacet.facetFuncs().length, 9);
        _has(bondingFacet, IDetfReserveDonation.joinDonatedCapital.selector);
        _has(bondingFacet, IDetfReserveDonation.notifyReserveDonated.selector);
        _has(bondingFacet, bytes4(keccak256("donate(address,uint256,bool)")));
        _has(bondingFacet, IComposedStableCommonDetfBonding.bond.selector);
        _has(bondingFacet, IComposedStableCommonDetfBonding.previewBond.selector);
        _has(bondingFacet, IComposedStableCommonDetfBonding.initializeReserve.selector);
        _has(bondingFacet, IComposedStableCommonDetfBonding.previewInitializeReserve.selector);
        _has(bondingFacet, IComposedStableCommonDetfBonding.acceptedBondTokens.selector);
        _has(bondingFacet, IComposedStableCommonDetfBonding.isAcceptedBondToken.selector);
    }

    function test_J1_exchangeOut_targetSelectors_subseteq_facetFuncs() public view {
        assertEq(exchangeOutQueryFacet.facetFuncs().length, 2);
        _has(exchangeOutQueryFacet, IStandardExchangeOut.previewExchangeOut.selector);
        _has(exchangeOutQueryFacet, IStandardExchangeOut.exchangeOut.selector);
        assertEq(
            IDiamondLoupe(deployedDetfVault).facetAddress(IDetf.claimLiquidity.selector),
            address(0),
            "legacy reserve claim removed"
        );
    }

    function test_J1_pricing_targetSelectors_subseteq_facetFuncs() public view {
        assertEq(pricingFacet.facetFuncs().length, 25);
        _has(pricingFacet, IComposedStableCommonDetfInfo.bondNftVault.selector);
        _has(pricingFacet, IComposedStableCommonDetfInfo.rebasingClaimToken.selector);
        _has(pricingFacet, IComposedStableCommonDetfInfo.reservePool.selector);
        _has(pricingFacet, IComposedStableCommonDetfInfo.syntheticDetfEthPrice.selector);
        _has(pricingFacet, IComposedStableCommonDetfInfo.previewReservePoolDecomposition.selector);
        _has(pricingFacet, IComposedStableCommonDetfInfo.openingConfiguration.selector);
    }

    function test_J2_facetFuncs_subseteq_loupe_onProxy() public view {
        IFacet[4] memory facets_ = [
            IFacet(address(exchangeInFacet)),
            IFacet(address(bondingFacet)),
            IFacet(address(exchangeOutQueryFacet)),
            IFacet(address(pricingFacet))
        ];
        for (uint256 f_; f_ < facets_.length; ++f_) {
            bytes4[] memory funcs_ = facets_[f_].facetFuncs();
            for (uint256 i_; i_ < funcs_.length; ++i_) {
                _has(facets_[f_], funcs_[i_]);
            }
        }
    }

    function test_J3_proxySmoke_moneyAndViews() public {
        uint256 paid_ = _buyFixtureRaw(bob);
        assertGt(paid_, 0);
        assertEq(detfToken.balanceOf(bob), paid_);
        IComposedStableCommonDetfInfo info_ = IComposedStableCommonDetfInfo(deployedDetfVault);
        assertTrue(info_.isReserveLive());
        assertGt(info_.syntheticDetfEthPrice(), 0);
        assertEq(info_.bondNftVault(), address(bondNFTVault));
        assertEq(info_.rebasingClaimToken(), address(rebasingDetfToken));
        info_.mintThreshold();
        info_.burnThreshold();
        info_.isMintingAllowed();
        info_.isBurningAllowed();
        info_.lastExpansionTimestamp();
        info_.expansionClosureRatePerSecond();
        info_.openingConfiguration();
        uint256 id_ = _buyFixtureBond(alice);
        _assertBondMaturePreviewEqualsPayment(deployedDetfVault, id_, alice);
    }

    function test_J_facetMetadata_matches_CREATE3_facets() public view {
        IFacet[4] memory facets_ = [
            IFacet(address(exchangeInFacet)),
            IFacet(address(bondingFacet)),
            IFacet(address(exchangeOutQueryFacet)),
            IFacet(address(pricingFacet))
        ];
        for (uint256 i_; i_ < facets_.length; ++i_) {
            (string memory name_, bytes4[] memory ids_, bytes4[] memory funcs_) = facets_[i_].facetMetadata();
            assertEq(name_, facets_[i_].facetName());
            assertGt(bytes(name_).length, 0);
            assertEq(keccak256(abi.encode(ids_)), keccak256(abi.encode(facets_[i_].facetInterfaces())));
            assertEq(keccak256(abi.encode(funcs_)), keccak256(abi.encode(facets_[i_].facetFuncs())));
        }
    }
}
