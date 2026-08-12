// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/**
 * @title Adversarial_Surface_Test
 * @notice J1–J3 diamond surface: Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** smoke (not facet impl alone).
 * @dev WP-J-DETF-MV-001. Production DETF proxy via TestBase; compares CREATE3 facet metadata to loupe.
 */
contract Adversarial_Surface_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    /// @notice J1: exchange + bonding facetFuncs include core Target selectors; sellNFT is gone.
    function test_J1_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory xfuncs_ = multiVaultWeightedDetfExchangeInFacet.facetFuncs();
        assertTrue(_contains(xfuncs_, IStandardExchangeIn.exchangeIn.selector), "exchangeIn");
        assertTrue(_contains(xfuncs_, IStandardExchangeIn.previewExchangeIn.selector), "previewExchangeIn");

        bytes4[] memory funcs_ = multiVaultWeightedDetfBondingFacet.facetFuncs();
        assertTrue(_contains(funcs_, IMultiVaultWeightedDetfBonding.bond.selector), "bond");
        assertTrue(_contains(funcs_, IMultiVaultWeightedDetfBonding.initializeReserve.selector), "initializeReserve");
        assertTrue(_contains(funcs_, IMultiVaultWeightedDetfBonding.redeemClaim.selector), "redeemClaim");
        assertTrue(_contains(funcs_, IMultiVaultWeightedDetfBonding.buyClaim.selector), "buyClaim");
        assertTrue(_contains(funcs_, IMultiVaultWeightedDetfBonding.closeBondMature.selector), "closeBondMature");
        assertTrue(!_contains(funcs_, bytes4(keccak256("sellNFT(uint256,address)"))), "sellNFT gone");

        bytes4[] memory ifuncs_ = multiVaultWeightedDetfInfoFacet.facetFuncs();
        assertTrue(_contains(ifuncs_, IMultiVaultWeightedDetfInfo.isReserveLive.selector), "isReserveLive");
        assertTrue(_contains(ifuncs_, IMultiVaultWeightedDetfInfo.syntheticPrice.selector), "syntheticPrice");
        assertTrue(_contains(ifuncs_, IMultiVaultWeightedDetfInfo.compoundProtocolRewards.selector), "compound");
    }

    /// @notice J2: every facetFuncs selector is registered on the production proxy loupe.
    function test_J2_facetFuncs_subseteq_loupe_onProxy() public {
        address instance_ = _openLiveN1();
        bytes4[] memory funcs_ = multiVaultWeightedDetfExchangeInFacet.facetFuncs();
        address expectedFacet_ = address(multiVaultWeightedDetfExchangeInFacet);

        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = IDiamondLoupe(instance_).facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "loupe maps selector to exchange facet");
        }

        bytes4[] memory bfuncs_ = multiVaultWeightedDetfBondingFacet.facetFuncs();
        address expectedBonding_ = address(multiVaultWeightedDetfBondingFacet);
        for (uint256 i; i < bfuncs_.length; ++i) {
            address loupeFacet_ = IDiamondLoupe(instance_).facetAddress(bfuncs_[i]);
            assertEq(loupeFacet_, expectedBonding_, "loupe maps selector to bonding facet");
        }
        assertEq(
            IDiamondLoupe(instance_).facetAddress(bytes4(keccak256("sellNFT(uint256,address)"))),
            address(0),
            "sellNFT absent from loupe"
        );
    }

    /// @notice J3: proxy smoke — loupe-routed selectors execute on the production diamond (not facet impl).
    function test_J3_proxySmoke_loupeRoutedCalls() public {
        address instance_ = _openLiveN1();
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(instance_);

        // View surface via proxy
        assertTrue(info_.isReserveLive(), "proxy isReserveLive");
        assertTrue(info_.vaultCount() >= 1, "proxy vaultCount");
        assertTrue(info_.reservePool() != address(0), "proxy reservePool");
        assertTrue(info_.syntheticPrice() > 0, "proxy syntheticPrice");
        assertTrue(info_.isMintingAllowed() || info_.isBurningAllowed(), "proxy threshold views");

        // Mutating surface via proxy (mint)
        uint256 shares_ = _fundSeSharesLeg(0, bob, 25e18);
        uint256 preview_ = ex_.previewExchangeIn(seShares[0], shares_, IERC20(instance_));
        vm.startPrank(bob);
        seShares[0].approve(instance_, shares_);
        uint256 out_ = ex_.exchangeIn(
            seShares[0], shares_, IERC20(instance_), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out_, preview_, "proxy mint preview==exec");
        assertTrue(out_ > 0, "proxy mint ok");

        // Loupe: exchangeIn selector routes to CREATE3 facet, not zero / not the proxy itself.
        address loupeFacet_ = IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(loupeFacet_, address(multiVaultWeightedDetfExchangeInFacet), "exchangeIn loupe facet");
        assertTrue(loupeFacet_ != instance_, "not self-facet");
        assertTrue(loupeFacet_ != address(0), "facet set");

        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        assertEq(bonding_.protocolBondOriginalShares(), 0, "proxy protocol bond empty at live");
        bonding_.previewBuyClaim(1e18);
        address buyFacet_ = IDiamondLoupe(instance_).facetAddress(IMultiVaultWeightedDetfBonding.buyClaim.selector);
        assertEq(buyFacet_, address(multiVaultWeightedDetfBondingFacet), "buyClaim loupe");
    }

    /// @notice J facet metadata parity (extends IFacet unit test onto CREATE3-deployed facet).
    function test_J_facetMetadata_matches_CREATE3_facet() public view {
        IFacet facet_ = multiVaultWeightedDetfExchangeInFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfExchangeInFacet")));
        assertTrue(ifaces_.length >= 1, "interfaces");
        assertEq(facet_.facetFuncs().length, funcs_.length, "funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(facet_.facetFuncs())),
            "metadata funcs == facetFuncs"
        );
    }

    function _contains(bytes4[] memory arr_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < arr_.length; ++i) {
            if (arr_[i] == sel_) return true;
        }
        return false;
    }
}
