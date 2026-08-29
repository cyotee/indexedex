// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfTarget} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {TestBase_UniswapV4Detf_Weighted_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Adversarial.sol";

/**
 * @title UniswapV4Detf_Weighted_Adversarial_Surface
 * @notice Weighted gold J1–J3. claimLiquidity selector 0xcaaf4702.
 */
contract UniswapV4Detf_Weighted_Adversarial_Surface is TestBase_UniswapV4Detf_Weighted_Adversarial {
    bytes4 internal constant CLAIM_LIQUIDITY_SEL = bytes4(0xcaaf4702);

    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](49);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = IUniswapV4Detf.mint.selector;
        sels_[3] = IUniswapV4Detf.previewMint.selector;
        sels_[4] = IUniswapV4Detf.burn.selector;
        sels_[5] = IUniswapV4Detf.previewBurn.selector;
        sels_[6] = IUniswapV4Detf.bond.selector;
        sels_[7] = IUniswapV4Detf.closeBondMature.selector;
        sels_[8] = IUniswapV4Detf.previewCloseBondMature.selector;
        sels_[9] = IUniswapV4Detf.donate.selector;
        sels_[10] = IUniswapV4Detf.sweepDust.selector;
        sels_[11] = IUniswapV4Detf.hook.selector;
        sels_[12] = IUniswapV4Detf.reservePool.selector;
        sels_[13] = IUniswapV4Detf.isReserveLive.selector;
        sels_[14] = IUniswapV4Detf.isReserveWired.selector;
        sels_[15] = IUniswapV4Detf.mintRoutes.selector;
        sels_[16] = IUniswapV4Detf.burnRoutes.selector;
        sels_[17] = IUniswapV4Detf.bondRoutes.selector;
        sels_[18] = IUniswapV4Detf.closeRoutes.selector;
        sels_[19] = IUniswapV4Detf.donateRoutes.selector;
        sels_[20] = IUniswapV4Detf.mintRouteMode.selector;
        sels_[21] = IUniswapV4Detf.burnRouteMode.selector;
        sels_[22] = IUniswapV4Detf.bondRouteMode.selector;
        sels_[23] = IUniswapV4Detf.closeRouteMode.selector;
        sels_[24] = IUniswapV4Detf.donateRouteMode.selector;
        sels_[25] = IUniswapV4Detf.creationPairPerDetfWad.selector;
        sels_[26] = IUniswapV4Detf.openingPairPerDetfWad.selector;
        sels_[27] = IUniswapV4Detf.mintThreshold.selector;
        sels_[28] = IUniswapV4Detf.burnThreshold.selector;
        sels_[29] = IUniswapV4Detf.thresholdMode.selector;
        sels_[30] = IUniswapV4Detf.syntheticPrice.selector;
        sels_[31] = IUniswapV4Detf.pendingExpansionDetf.selector;
        sels_[32] = IUniswapV4Detf.bondNftVault.selector;
        sels_[33] = IUniswapV4Detf.detfNFTVault.selector;
        sels_[34] = IUniswapV4Detf.rebasingClaimToken.selector;
        sels_[35] = IUniswapV4Detf.acceptedBondTokens.selector;
        sels_[36] = bytes4(keccak256("isMintingAllowed()"));
        sels_[37] = bytes4(keccak256("isMintingAllowed(address)"));
        sels_[38] = bytes4(keccak256("isBurningAllowed()"));
        sels_[39] = bytes4(keccak256("isBurningAllowed(address)"));
        sels_[40] = IUniswapV4Detf.compoundProtocolRewards.selector;
        sels_[41] = IDetf.claimLiquidity.selector;
        sels_[42] = IDetf.previewClaimLiquidity.selector;
        sels_[43] = IUniswapV4Detf.joinDonatedCapital.selector;
        sels_[44] = IUniswapV4Detf.previewJoinDonatedCapital.selector;
        sels_[45] = IUniswapV4Detf.notifyReserveDonated.selector;
        sels_[46] = IUniswapV4Detf.completeReserveBondNft.selector;
        sels_[47] = IUniswapV4Detf.completeReserveClaim.selector;
        sels_[48] = UniswapV4DetfTarget.peekPairEq.selector;
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /// @notice J1: Target/product API selectors ⊆ Facet.facetFuncs(). Includes claimLiquidity 0xcaaf4702.
    function test_J1_facetFuncs_coversTargetApi() public view {
        assertEq(IDetf.claimLiquidity.selector, CLAIM_LIQUIDITY_SEL, "claimLiquidity 0xcaaf4702");
        IFacet facet_ = detfProductFacet;
        bytes4[] memory funcs_ = facet_.facetFuncs();
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            assertTrue(
                _facetFuncsContains(funcs_, controls_[i]),
                string.concat("J1 missing selector idx ", vm.toString(i))
            );
        }
    }

    /// @notice J2: loupe facetAddress(sel) != 0 for all product controls on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        _goLive(500 ether);
        IDiamondLoupe loupe_ = IDiamondLoupe(detf);
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != detf, "J2 facet != proxy");
        }
        assertTrue(loupe_.facetAddress(CLAIM_LIQUIDITY_SEL) != address(0), "J2 claimLiquidity");
        assertTrue(
            loupe_.facetAddress(IDetf.previewClaimLiquidity.selector) != address(0),
            "J2 previewClaimLiquidity"
        );
    }

    /// @notice J3: smoke-call money + view selectors on **proxy** (not facet impl address).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        _goLive(500 ether);
        address mintFacet_ = IDiamondLoupe(detf).facetAddress(IUniswapV4Detf.mint.selector);
        assertTrue(mintFacet_ != address(0) && mintFacet_ != detf, "proxy cut");
        assertTrue(
            IDiamondLoupe(detf).facetAddress(CLAIM_LIQUIDITY_SEL) != address(0),
            "J3 loupe claimLiquidity"
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IDetf.previewClaimLiquidity.selector) != address(0),
            "J3 loupe previewClaimLiquidity"
        );

        IUniswapV4Detf info_ = detfInfo;
        assertTrue(info_.isReserveLive());
        assertTrue(info_.hook() != address(0));
        assertTrue(info_.reservePool() != address(0));
        assertTrue(info_.bondNftVault() != address(0));
        assertTrue(info_.rebasingClaimToken() != address(0));
        info_.isReserveWired();
        info_.mintRoutes();
        info_.burnRoutes();
        info_.bondRoutes();
        info_.closeRoutes();
        info_.donateRoutes();
        info_.mintRouteMode();
        info_.burnRouteMode();
        info_.bondRouteMode();
        info_.closeRouteMode();
        info_.donateRouteMode();
        info_.creationPairPerDetfWad();
        info_.openingPairPerDetfWad();
        info_.mintThreshold();
        info_.burnThreshold();
        info_.thresholdMode();
        info_.syntheticPrice();
        info_.pendingExpansionDetf();
        info_.detfNFTVault();
        info_.acceptedBondTokens();
        info_.isMintingAllowed();
        info_.isMintingAllowed(IERC20(address(pairToken)));
        info_.isBurningAllowed();
        info_.isBurningAllowed(IERC20(address(pairToken)));
        info_.previewMint(IERC20(address(pairToken)), 1 ether);
        info_.previewBurn(1 ether, IERC20(address(pairToken)));
        info_.previewCloseBondMature(1);
        info_.previewJoinDonatedCapital(IERC20(detf), 1 ether);
        try info_.previewJoinDonatedCapital(IERC20(address(pairToken)), 1 ether) {} catch {}
        IDetf(detf).previewClaimLiquidity(1 ether);

        vm.prank(attacker);
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        info_.mint(IERC20(address(pairToken)), 0, 0, attacker, false, _deadline());

        vm.prank(attacker);
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        info_.bond(IERC20(address(pairToken)), 0, DEFAULT_MIN_LOCK, attacker, false, _deadline());

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, attacker));
        IDetf(detf).claimLiquidity(1 ether, attacker);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, attacker));
        info_.joinDonatedCapital(IERC20(address(pairToken)), 1 ether, _deadline());

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, attacker));
        info_.notifyReserveDonated();

        uint256 minted_ = _mintPairTo(detf, detfUser, 25 ether);
        assertGt(minted_, 0, "J3 mint on proxy");
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, minted_ / 2);
        uint256 burnedOut_ = info_.burn(minted_ / 2, IERC20(address(pairToken)), 0, detfUser, _deadline());
        vm.stopPrank();
        assertGt(burnedOut_, 0, "J3 burn on proxy");

        info_.compoundProtocolRewards();
        info_.sweepDust();

        assertTrue(mintFacet_ != detf, "J3 primary target is proxy");
    }
}
