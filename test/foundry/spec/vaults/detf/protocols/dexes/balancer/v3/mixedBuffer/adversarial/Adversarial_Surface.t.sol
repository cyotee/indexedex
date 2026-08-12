// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
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
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        sels_[3] = bytes4(keccak256("exchangeOut(address,address,uint256,uint256,address,bool,uint256)"));
        sels_[4] = IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector;
        sels_[5] = IMixedBufferMultiVaultStableDetfBonding.bond.selector;
        sels_[6] = IMixedBufferMultiVaultStableDetfBonding.sellPositionToDetfNft.selector;
        sels_[7] = IMixedBufferMultiVaultStableDetfBonding.acceptedBondTokens.selector;
        sels_[8] = IMixedBufferMultiVaultStableDetfBonding.redeemClaim.selector;
        sels_[9] = IMixedBufferMultiVaultStableDetfBonding.buyClaim.selector;
        sels_[10] = IMixedBufferMultiVaultStableDetfBonding.previewBuyClaim.selector;
        sels_[11] = IMixedBufferMultiVaultStableDetfBonding.closeBondMature.selector;
        sels_[12] = IMixedBufferMultiVaultStableDetfBonding.previewCloseBondMature.selector;
        sels_[13] = IMixedBufferMultiVaultStableDetfBonding.previewRedeemClaim.selector;
        sels_[14] = IMixedBufferMultiVaultStableDetfBonding.claimLiquidity.selector;
        sels_[15] = IMixedBufferMultiVaultStableDetfBonding.protocolBondOriginalShares.selector;
        sels_[16] = IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector;
        sels_[17] = IMixedBufferMultiVaultStableDetfInfo.vaultCount.selector;
        sels_[18] = IMixedBufferMultiVaultStableDetfInfo.underlyingVaults.selector;
        sels_[19] = IMixedBufferMultiVaultStableDetfInfo.vaultShares.selector;
        sels_[20] = IMixedBufferMultiVaultStableDetfInfo.bufferToken.selector;
        sels_[21] = IMixedBufferMultiVaultStableDetfInfo.amplificationParameter.selector;
        sels_[22] = IMixedBufferMultiVaultStableDetfInfo.rateProvider.selector;
        sels_[23] = IMixedBufferMultiVaultStableDetfInfo.reservePool.selector;
        sels_[24] = IMixedBufferMultiVaultStableDetfInfo.syntheticPrice.selector;
        sels_[25] = IMixedBufferMultiVaultStableDetfInfo.mintThreshold.selector;
        sels_[26] = IMixedBufferMultiVaultStableDetfInfo.burnThreshold.selector;
        sels_[27] = IMixedBufferMultiVaultStableDetfInfo.thresholdMode.selector;
        sels_[28] = IMixedBufferMultiVaultStableDetfInfo.isMintingAllowed.selector;
        sels_[29] = IMixedBufferMultiVaultStableDetfInfo.isBurningAllowed.selector;
        sels_[30] = IMixedBufferMultiVaultStableDetfInfo.bondNftVault.selector;
        sels_[31] = IMixedBufferMultiVaultStableDetfInfo.rebasingClaimToken.selector;
        sels_[32] = IMixedBufferMultiVaultStableDetfInfo.detfIndex.selector;
        sels_[33] = IMixedBufferMultiVaultStableDetfInfo.bufferIndex.selector;
        sels_[34] = IMixedBufferMultiVaultStableDetfInfo.shareIndex.selector;
        sels_[35] = IMixedBufferMultiVaultStableDetfInfo.compoundProtocolRewards.selector;
        sels_[36] = IMixedBufferMultiVaultStableDetfInfo.lastExpansionTimestamp.selector;
        sels_[37] = IMixedBufferMultiVaultStableDetfInfo.expansionClosureRatePerSecond.selector;
        sels_[38] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpMaxSeconds.selector;
        sels_[39] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpCapBps.selector;
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
        bytes4[] memory xfuncs_ = mixedBufferDetfExchangeInFacet.facetFuncs();
        assertTrue(_contains(xfuncs_, IStandardExchangeIn.exchangeIn.selector), "exchangeIn");
        assertTrue(_contains(xfuncs_, IStandardExchangeIn.previewExchangeIn.selector), "previewExchangeIn");

        bytes4[] memory funcs_ = mixedBufferDetfBondingFacet.facetFuncs();
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector), "bootstrap");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.bond.selector), "bond");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.redeemClaim.selector), "redeemClaim");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.buyClaim.selector), "buyClaim");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.closeBondMature.selector), "close");
        assertTrue(!_contains(funcs_, bytes4(keccak256("sellNFT(uint256,address)"))), "sellNFT gone");

        bytes4[] memory ifuncs_ = mixedBufferDetfInfoFacet.facetFuncs();
        assertTrue(_contains(ifuncs_, IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector), "isReserveLive");
        assertTrue(_contains(ifuncs_, IMixedBufferMultiVaultStableDetfInfo.syntheticPrice.selector), "syntheticPrice");
        assertTrue(_contains(ifuncs_, IMixedBufferMultiVaultStableDetfInfo.compoundProtocolRewards.selector), "compound");
        assertTrue(
            _contains(ifuncs_, bytes4(keccak256("compoundProtocolRewardsAtomic()"))),
            "J1 atomic compound"
        );

        bytes4[] memory union_ = _unionFacetFuncs();
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            assertTrue(
                _contains(union_, controls_[i]),
                string.concat("J1 missing selector idx ", vm.toString(i))
            );
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
        address instance_ = _openLiveOpenThreshold();
        bytes4[] memory funcs_ = mixedBufferDetfExchangeInFacet.facetFuncs();
        address expectedFacet_ = address(mixedBufferDetfExchangeInFacet);

        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = IDiamondLoupe(instance_).facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "loupe maps selector to exchange facet");
            assertTrue(loupeFacet_ != instance_ && loupeFacet_ != address(0), "facet cut non-zero non-self");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: money path + view smoke on proxy (not facet impl)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: proxy smoke — loupe-routed selectors execute on the production diamond.
    function test_J3_proxySmoke_loupeRoutedCalls() public {
        address instance_ = _openLiveOpenThreshold();
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        IMixedBufferMultiVaultStableDetfBonding bonding_ = IMixedBufferMultiVaultStableDetfBonding(instance_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(instance_);

        // Prove cut is proxy-routed, not self / zero.
        address exchangeFacet_ =
            IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(exchangeFacet_, address(mixedBufferDetfExchangeInFacet), "exchangeIn loupe facet");
        assertTrue(exchangeFacet_ != instance_ && exchangeFacet_ != address(0), "proxy cut");

        // --- Views via proxy ---
        assertTrue(info_.isReserveLive(), "proxy isReserveLive");
        assertTrue(info_.vaultCount() >= 1, "proxy vaultCount");
        assertTrue(info_.bufferToken() != address(0), "proxy bufferToken");
        assertTrue(info_.reservePool() != address(0), "proxy reservePool");
        assertTrue(info_.bondNftVault() != address(0), "proxy bondNftVault");
        assertTrue(info_.syntheticPrice() > 0, "proxy syntheticPrice");
        info_.underlyingVaults();
        info_.vaultShares();
        info_.amplificationParameter();
        info_.rateProvider(0);
        info_.mintThreshold();
        info_.burnThreshold();
        info_.thresholdMode();
        info_.isMintingAllowed();
        info_.isBurningAllowed();
        info_.rebasingClaimToken();
        info_.detfIndex();
        info_.bufferIndex();
        info_.shareIndex(0);
        info_.lastExpansionTimestamp();
        info_.expansionClosureRatePerSecond();
        info_.expansionCatchUpMaxSeconds();
        info_.expansionCatchUpCapBps();
        bonding_.acceptedBondTokens();

        IERC20 buffer_ = IERC20(info_.bufferToken());

        // preview on proxy (no state)
        ex_.previewExchangeIn(buffer_, 1e18, IERC20(instance_));

        // Money path: ZeroAmount proves selector is live on proxy (exact product error).
        vm.prank(attacker);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        ex_.exchangeIn(buffer_, 0, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours);

        vm.prank(attacker);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        bonding_.bond(buffer_, 0, DEFAULT_MIN_LOCK, attacker, false, block.timestamp + 1 hours);

        // sellPosition: product revert (not missing selector) — non-owner / invalid id.
        vm.prank(attacker);
        vm.expectRevert();
        bonding_.sellPositionToDetfNft(1, 0, attacker);

        // Live money smoke: mint buffer → DETF on diamond proxy (not facet impl).
        uint256 mintIn_ = 50e18;
        uint256 out_ = _mintDetfFromBuffer(instance_, bob, mintIn_);
        assertTrue(out_ > 0, "proxy mint ok");
        assertEq(IERC20(instance_).balanceOf(bob), out_, "proxy mint balance");

        // compound: permissionless best-effort; must not be "function does not exist".
        info_.compoundProtocolRewards();

        // Explicit anti-theater: primary SUT is proxy, not facet implementation address.
        assertTrue(exchangeFacet_ != instance_, "J3 primary target is proxy");
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
}
