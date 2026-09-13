// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/**
 * @title Adversarial_MixedBuffer_Surface_Test
 * @notice J1–J3 diamond surface: Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** smoke (not facet impl alone).
 * @dev WP-J-DETF-CS-MB-001 (MB half). Production DETF proxy via TestBase; CREATE3 facet vs loupe.
 *      MB CODE (I suite) already on main — this file is TEST-only surface coverage.
 */
contract Adversarial_MixedBuffer_Surface_Test is TestBase_MixedBufferMultiVaultStableDetf_Adversarial {
    /// @dev Target-derived control set: money + bonding + info (not incomplete Facet copy).
    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](40);
        sels_[0] = bytes4(keccak256("exchangeIn(address,uint256,address,uint256,address,bool,uint256)"));
        sels_[1] = bytes4(keccak256("previewExchangeIn(address,uint256,address)"));
        sels_[2] = bytes4(keccak256("exchangeOut(address,uint256,address,uint256,address,bool,uint256)"));
        sels_[3] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        sels_[4] = bytes4(keccak256("executeReserveSwap((uint8,address,address,address,uint256,uint256,bytes))"));
        sels_[5] = bytes4(keccak256("bond(address,uint256,uint256,address,bool,uint256)"));
        sels_[6] = bytes4(keccak256("bootstrapFirstBond(uint256,uint256[],uint256,address,uint256)"));
        sels_[7] = bytes4(keccak256("previewBond(address,uint256,uint256)"));
        sels_[8] = bytes4(keccak256("previewBootstrapFirstBond(uint256,uint256[],uint256)"));
        sels_[9] = bytes4(keccak256("acceptedBondTokens()"));
        sels_[10] = bytes4(keccak256("joinDonatedCapital(address,uint256,uint256)"));
        sels_[11] = bytes4(keccak256("previewJoinDonatedCapital(address,uint256)"));
        sels_[12] = bytes4(keccak256("notifyReserveDonated()"));
        sels_[13] = bytes4(keccak256("donate(address,uint256,bool)"));
        sels_[14] = bytes4(keccak256("vaultCount()"));
        sels_[15] = bytes4(keccak256("underlyingVaults()"));
        sels_[16] = bytes4(keccak256("vaultShares()"));
        sels_[17] = bytes4(keccak256("rateProvider(uint256)"));
        sels_[18] = bytes4(keccak256("bufferToken()"));
        sels_[19] = bytes4(keccak256("amplificationParameter()"));
        sels_[20] = bytes4(keccak256("detfIndex()"));
        sels_[21] = bytes4(keccak256("bufferIndex()"));
        sels_[22] = bytes4(keccak256("shareIndex(uint256)"));
        sels_[23] = bytes4(keccak256("isReserveLive()"));
        sels_[24] = bytes4(keccak256("reservePool()"));
        sels_[25] = bytes4(keccak256("syntheticPrice()"));
        sels_[26] = bytes4(keccak256("mintThreshold()"));
        sels_[27] = bytes4(keccak256("burnThreshold()"));
        sels_[28] = bytes4(keccak256("isMintingAllowed()"));
        sels_[29] = bytes4(keccak256("isBurningAllowed()"));
        sels_[30] = bytes4(keccak256("bondNftVault()"));
        sels_[31] = bytes4(keccak256("rebasingClaimToken()"));
        sels_[32] = bytes4(keccak256("lastExpansionTimestamp()"));
        sels_[33] = bytes4(keccak256("epochAnchor()"));
        sels_[34] = bytes4(keccak256("expansionClosureRatePerSecond()"));
        sels_[35] = bytes4(keccak256("pendingExpansionDetf()"));
        sels_[36] = bytes4(keccak256("synchronizeRewards()"));
        sels_[37] = bytes4(keccak256("rawSY()"));
        sels_[38] = bytes4(keccak256("stakingSY()"));
        sels_[39] = bytes4(keccak256("previewStakingGonsPerUnit(address,uint256)"));
    }


    function _contains(bytes4[] memory arr_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < arr_.length; ++i) {
            if (arr_[i] == sel_) return true;
        }
        return false;
    }

    /* ---------------------------------------------------------------------- */
    /*  J1: Target/product selectors ⊆ Facet.facetFuncs()                     */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: Target/product API selectors ⊆ role facetFuncs(); sellNFT is gone.
    function test_J1_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory exports_ = _unionFacetFuncs(); bytes4[] memory controls_ = _controlSelectors();
        assertEq(exports_.length, controls_.length);
        for (uint256 i_; i_ < controls_.length; ++i_) {
            uint256 matches_;
            for (uint256 j_; j_ < exports_.length; ++j_) if (exports_[j_] == controls_[i_]) ++matches_;
            assertEq(matches_, 1, "each independent funded control exported once");
        }
    }


    function _unionFacetFuncs() internal view returns (bytes4[] memory union_) {
        bytes4[] memory a = mixedBufferDetfExchangeInFacet.facetFuncs();
        bytes4[] memory b = mixedBufferDetfBondingFacet.facetFuncs();
        bytes4[] memory c = mixedBufferDetfInfoFacet.facetFuncs();
        union_ = new bytes4[](a.length + b.length + c.length);
        uint256 n;
        for (uint256 i; i < a.length; ++i) {
            union_[n++] = a[i];
        }
        for (uint256 i; i < b.length; ++i) {
            union_[n++] = b[i];
        }
        for (uint256 i; i < c.length; ++i) {
            union_[n++] = c[i];
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production proxy                            */
    /* ---------------------------------------------------------------------- */

    /// @notice J2: every facetFuncs selector is registered on the production proxy loupe.
    function test_J2_facetFuncs_subseteq_loupe_onProxy() public {
        address instance_ = _openLiveGated();
        IDiamond.FacetCut[] memory cuts_ = mixedBufferDetfPkg.facetCuts();
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i_; i_ < controls_.length; ++i_) {
            address final_;
            for (uint256 j_; j_ < cuts_.length; ++j_) if (_contains(cuts_[j_].functionSelectors, controls_[i_])) final_ = cuts_[j_].facetAddress;
            assertTrue(final_ != address(0) && final_ != instance_);
            assertEq(IDiamondLoupe(instance_).facetAddress(controls_[i_]), final_);
            assertLe(final_.code.length, 24_576);
        }
    }


    /* ---------------------------------------------------------------------- */
    /*  J3: money path + view smoke on proxy (not facet impl)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: proxy smoke — loupe-routed selectors execute on the production diamond.
    function test_J3_proxySmoke_loupeRoutedCalls() public {
        address instance_ = _openLiveGated();
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        IMixedBufferMultiVaultStableDetfBonding bonding_ = IMixedBufferMultiVaultStableDetfBonding(instance_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(instance_);
        IStakedDETF staking_ = IStakedDETF(info_.rebasingClaimToken()); IERC20 buffer_ = IERC20(info_.bufferToken());
        assertEq(IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector), address(mixedBufferDetfExchangeInFacet));
        assertTrue(info_.isReserveLive()); assertEq(info_.vaultCount(), 1);
        assertGt(info_.syntheticPrice(), 0); assertGt(info_.epochAnchor(), 0);
        assertTrue(info_.rawSY() != address(0) && info_.stakingSY() != address(0));
        assertEq(info_.previewStakingGonsPerUnit(buffer_, 1e18), staking_.stakingState().gonsPerUnit);
        assertEq(info_.synchronizeRewards(), 0); assertEq(info_.pendingExpansionDetf(), 0);
        vm.prank(attacker); vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        ex_.exchangeIn(buffer_, 0, IERC20(instance_), 0, attacker, false, block.timestamp);
        vm.prank(attacker); vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        bonding_.bond(buffer_, 0, DEFAULT_MIN_LOCK, attacker, false, block.timestamp);
        uint256 raw_ = _mintDetfFromBuffer(instance_, bob, 50e18);
        assertGt(raw_, 0); assertEq(IERC20(instance_).balanceOf(bob), raw_);
        vm.startPrank(bob); IERC20(instance_).approve(instance_, raw_);
        assertEq(IStandardExchangeOut(instance_).previewExchangeOut(IERC20(instance_), IERC20(address(staking_)), raw_), raw_);
        assertEq(IStandardExchangeOut(instance_).exchangeOut(IERC20(instance_), raw_, IERC20(address(staking_)), raw_, bob, false, block.timestamp), raw_);
        assertEq(staking_.balanceOf(bob), raw_);
        staking_.approve(instance_, raw_);
        assertEq(ex_.exchangeIn(IERC20(address(staking_)), raw_, IERC20(instance_), raw_, bob, false, block.timestamp), raw_);
        vm.stopPrank();
        assertEq(IERC20(instance_).balanceOf(bob), raw_);
        _fundBuffer(bob, 10e18);
        (uint256 principal_,,) = bonding_.previewBond(buffer_, 10e18, DEFAULT_MIN_LOCK);
        vm.startPrank(bob); buffer_.approve(instance_, 10e18);
        (uint256 id_,) = bonding_.bond(buffer_, 10e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp);
        vm.stopPrank();
        assertGt(principal_, 0);
        assertEq(IDetfBondNFT(info_.bondNftVault()).positionOf(id_).principal, principal_);
    }


    /// @notice J facet metadata parity (extends IFacet unit test onto CREATE3-deployed facet).
    function test_J_facetMetadata_matches_CREATE3_facet() public view {
        IFacet facet_ = mixedBufferDetfExchangeInFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MixedBufferMultiVaultStableDetfExchangeInFacet")));
        assertTrue(ifaces_.length >= 1, "interfaces");
        assertEq(facet_.facetFuncs().length, funcs_.length, "funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(facet_.facetFuncs())),
            "metadata funcs == facetFuncs"
        );
    }
    function test_J2_retiredSelectorsCannotBeCalled() public {
        string[17] memory retired_ = ["sellPositionToDetfNft(uint256,uint256,address)",
            "redeemClaim(uint256,address,uint256,address,uint256)",
            "buyClaim(address,uint256,uint256,address,bool,uint256)",
            "previewBuyClaim(address,uint256)",
            "closeBondMature(uint256,address,uint256[],address,uint256)",
            "previewCloseBondMature(uint256,address)",
            "previewRedeemClaim(uint256,address)",
            "claimLiquidity()",
            "protocolBondOriginalShares()",
            "thresholdMode()",
            "compoundProtocolRewards()",
            "compoundProtocolRewardsAtomic()",
            "expansionCatchUpMaxSeconds()",
            "expansionCatchUpCapBps()",
            "sellNFT(uint256,address)",
            "setMintThreshold(uint256)",
            "mintClaim(uint256,address)"];
        for (uint256 i_; i_ < retired_.length; ++i_) {
            bytes4 selector_ = bytes4(keccak256(bytes(retired_[i_])));
            assertEq(IDiamondLoupe(detf).facetAddress(selector_), address(0));
            (bool ok_,) = detf.call(abi.encodePacked(selector_)); assertFalse(ok_);
        }
    }
}
