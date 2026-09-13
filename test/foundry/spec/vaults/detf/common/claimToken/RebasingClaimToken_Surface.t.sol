// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Catalog J1-J3 on the registered DETF's real staking child.
/// @dev Controls come from the product interfaces independently of facetFuncs().
contract RebasingClaimToken_Surface_Test is TestBase_UniswapV4Detf {
    function _controls() private pure returns (bytes4[] memory s_) {
        s_ = new bytes4[](19);
        s_[0] = IERC20.totalSupply.selector;
        s_[1] = IERC20.balanceOf.selector;
        s_[2] = IERC20.transfer.selector;
        s_[3] = IERC20.allowance.selector;
        s_[4] = IERC20.approve.selector;
        s_[5] = IERC20.transferFrom.selector;
        s_[6] = IERC20Metadata.name.selector;
        s_[7] = IERC20Metadata.symbol.selector;
        s_[8] = IERC20Metadata.decimals.selector;
        s_[9] = IStakedDETF.detf.selector;
        s_[10] = IStakedDETF.gonsOf.selector;
        s_[11] = IStakedDETF.stakingState.selector;
        s_[12] = IStakedDETF.previewDistributions.selector;
        s_[13] = IStakedDETF.fundRewards.selector;
        s_[14] = IStakedDETF.retireEscrowDust.selector;
        s_[15] = IStandardExchangeIn.previewExchangeIn.selector;
        s_[16] = IStandardExchangeIn.exchangeIn.selector;
        s_[17] = IStandardExchangeOut.previewExchangeOut.selector;
        s_[18] = IStandardExchangeOut.exchangeOut.selector;
    }

    function _contains(bytes4[] memory selectors_, bytes4 selector_) private pure returns (bool) {
        for (uint256 i_; i_ < selectors_.length; ++i_) if (selectors_[i_] == selector_) return true;
        return false;
    }

    function test_J1_J2_fundedInterfaceMatchesFacetPackageAndProxy() public view {
        address proxy_ = detfInfo.rebasingClaimToken();
        IDiamondLoupe loupe_ = IDiamondLoupe(proxy_);
        address facet_ = loupe_.facetAddress(IStakedDETF.fundRewards.selector);
        assertTrue(facet_ != address(0) && facet_ != proxy_);
        assertLe(facet_.code.length, 24_576);
        bytes4[] memory controls_ = _controls();
        bytes4[] memory exported_ = IFacet(facet_).facetFuncs();
        assertEq(exported_.length, controls_.length);
        IDiamond.FacetCut[] memory cuts_ = rebasingClaimTokenPkg.facetCuts();
        address[] memory addresses_ = rebasingClaimTokenPkg.facetAddresses();
        assertEq(addresses_.length, cuts_.length);
        for (uint256 i_; i_ < cuts_.length; ++i_) {
            assertEq(addresses_[i_], cuts_[i_].facetAddress);
            assertLe(addresses_[i_].code.length, 24_576);
            for (uint256 j_; j_ < cuts_[i_].functionSelectors.length; ++j_) {
                assertEq(loupe_.facetAddress(cuts_[i_].functionSelectors[j_]), addresses_[i_]);
            }
        }
        for (uint256 i_; i_ < controls_.length; ++i_) {
            assertTrue(_contains(exported_, controls_[i_]), "interface selector missing from facet");
            assertEq(loupe_.facetAddress(controls_[i_]), facet_);
            bool inCut_;
            for (uint256 j_; j_ < cuts_.length; ++j_) {
                if (cuts_[j_].facetAddress == facet_) inCut_ = _contains(cuts_[j_].functionSelectors, controls_[i_]);
            }
            assertTrue(inCut_, "interface selector missing from package");
        }
    }

    function test_J2_retiredClaimSelectorsAreAbsent() public {
        address proxy_ = detfInfo.rebasingClaimToken();
        bytes4[19] memory retired_ = [
            IRebasingClaimToken.sharesOf.selector,
            IRebasingClaimToken.totalShares.selector,
            IRebasingClaimToken.redemptionRate.selector,
            IRebasingClaimToken.setDetf.selector,
            IRebasingClaimToken.detfNFTId.selector,
            IRebasingClaimToken.rateAsset.selector,
            IRebasingClaimToken.convertToShares.selector,
            IRebasingClaimToken.convertToClaim.selector,
            IRebasingClaimToken.previewRedeem.selector,
            IRebasingClaimToken.redeem.selector,
            IRebasingClaimToken.burnShares.selector,
            IRebasingClaimToken.transferHeldToken.selector,
            IRebasingClaimToken.updateRedemptionRate.selector,
            bytes4(keccak256("mintFromNFTSale(uint256,address)")),
            bytes4(keccak256("mintFromNFTSale(uint256,uint256,address)")),
            bytes4(keccak256("pendingRedeemDetfOut()")),
            bytes4(keccak256("hasOutstandingShares()")),
            bytes4(keccak256("previewMintFromNFTSale(uint256,uint256,uint256)")),
            bytes4(keccak256("mintClaim(uint256,address)"))
        ];
        for (uint256 i_; i_ < retired_.length; ++i_) {
            assertEq(IDiamondLoupe(proxy_).facetAddress(retired_[i_]), address(0));
            (bool ok_,) = proxy_.call(abi.encodePacked(retired_[i_]));
            assertFalse(ok_, "retired selector unexpectedly callable");
        }
    }

    function test_J3_proxyViewsAuthorizationAndPrincipalRoutes() public {
        IStakedDETF staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        IERC20 receipt_ = IERC20(address(staking_));
        IERC20 raw_ = IERC20(detf);
        address recipient_ = makeAddr("funded staking recipient");
        assertGt(bytes(staking_.name()).length, 0);
        assertGt(bytes(staking_.symbol()).length, 0);
        assertEq(staking_.decimals(), 9);
        assertEq(staking_.detf(), detf);
        assertEq(staking_.totalSupply(), 0);
        assertEq(staking_.balanceOf(detfUser), 0);
        assertEq(staking_.gonsOf(detfUser), 0);
        assertEq(staking_.allowance(detfUser, recipient_), 0);
        uint256[] memory noRewards_ = new uint256[](0);
        assertEq(abi.encode(staking_.previewDistributions(noRewards_)), abi.encode(staking_.stakingState()));
        assertEq(staking_.previewExchangeIn(raw_, 7, receipt_), 7);
        assertEq(staking_.previewExchangeOut(receipt_, raw_, 7), 7);
        vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.Unauthorized.selector, address(this)));
        staking_.fundRewards(1);
        vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.Unauthorized.selector, address(this)));
        staking_.retireEscrowDust(1);
        vm.prank(detfUser);
        assertTrue(staking_.transfer(recipient_, 0), "zero transfer before first funding");

        (uint256 id_,) = _firstBond(1_000 ether);
        IDetfBondNFT bonds_ = IDetfBondNFT(detfInfo.bondNftVault());
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        vm.startPrank(detfUser);
        (uint256 p_, uint256 r_) = bonds_.claimBond(id_, detfUser);
        uint256 amount_ = p_ + r_;
        uint256 before_ = raw_.balanceOf(detfUser);
        assertEq(staking_.exchangeIn(receipt_, amount_, raw_, amount_, detfUser, false, block.timestamp), amount_);
        assertEq(raw_.balanceOf(detfUser), before_ + amount_);
        raw_.approve(address(staking_), amount_);
        assertEq(staking_.exchangeOut(raw_, amount_, receipt_, amount_, detfUser, false, block.timestamp), amount_);
        assertEq(staking_.balanceOf(detfUser), amount_);
        assertTrue(staking_.transfer(recipient_, 7));
        assertTrue(staking_.approve(recipient_, 11));
        vm.stopPrank();
        vm.startPrank(recipient_);
        assertTrue(staking_.transferFrom(detfUser, recipient_, 11));
        assertEq(staking_.allowance(detfUser, recipient_), 0);
        assertEq(staking_.balanceOf(recipient_), 18);
        assertEq(staking_.exchangeOut(receipt_, 18, raw_, 18, address(0), false, block.timestamp), 18);
        vm.stopPrank();
        assertEq(raw_.balanceOf(recipient_), 18);
        assertEq(staking_.gonsOf(recipient_), 0);
        assertEq(staking_.balanceOf(detfUser), amount_ - 18);
    }
}
