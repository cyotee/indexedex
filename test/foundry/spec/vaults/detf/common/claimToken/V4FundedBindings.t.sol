// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Orbital} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {TestBase_UniswapV4Detf_CurveQuad} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_CurveQuad.sol";

/// @dev Integration assertions shared without inheriting another executable suite.
abstract contract V4FundedBindingBehavior is Test {
    function _subject() internal view virtual returns (IUniswapV4Detf);
    function _buyer() internal view virtual returns (address);
    function _hookPackage() internal view virtual returns (address);
    function _purchase(uint256 amount_) internal virtual returns (uint256 id_, uint256 lp_);
    function _leadPayment() internal view virtual returns (address);

    function test_bindingFirstBondPaymentPreviewMatchesEveryWalletDebit() public {
        address[] memory accepted_ = _subject().acceptedBondTokens();
        assertGt(accepted_.length, 1);
        for (uint256 i_; i_ < accepted_.length; ++i_) assertNotEq(accepted_[i_], address(_subject()), "DETF is minted separately, not paid by the first bonder");
        // Each fixture's first payment is its unsorted lead token, not necessarily accepted_[0].
        address lead_ = _leadPayment();
        (address[] memory tokens_, uint256[] memory amounts_) = _subject().previewFirstBondPayments(IERC20(lead_), 1_000 ether);
        assertEq(tokens_.length, accepted_.length);
        uint256[] memory before_ = new uint256[](tokens_.length);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            before_[i_] = IERC20(tokens_[i_]).balanceOf(_buyer());
            assertGt(amounts_[i_], 0);
        }
        _purchase(1_000 ether);
        for (uint256 i_; i_ < tokens_.length; ++i_) assertEq(before_[i_] - IERC20(tokens_[i_]).balanceOf(_buyer()), amounts_[i_]);
        vm.expectRevert(); _subject().previewFirstBondPayments(IERC20(lead_), 1_000 ether);
    }


    function _stake() internal view returns (IStakedDETF) {
        return IStakedDETF(_subject().rebasingClaimToken());
    }

    function _positions() internal view returns (IDetfBondNFT) {
        return IDetfBondNFT(_subject().bondNftVault());
    }

    function test_bindingHookComponentsFitAndSelectorsAreInstalled() public view {
        address pkg_ = _hookPackage();
        assertLe(pkg_.code.length, 24_576, "hook package runtime");
        address[] memory facets_ = IDiamondFactoryPackage(pkg_).facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertGt(facets_[i_].code.length, 0, "missing facet bytecode");
            assertLe(facets_[i_].code.length, 24_576, IFacet(facets_[i_]).facetName());
            if (i_ < 4) continue; // Initialization facets are removed during finalization.
            bytes4[] memory selectors_ = IFacet(facets_[i_]).facetFuncs();
            for (uint256 j_; j_ < selectors_.length; ++j_) {
                assertEq(IDiamondLoupe(_subject().hook()).facetAddress(selectors_[j_]), facets_[i_]);
            }
        }
    }

    function test_bindingRetiredLpClaimProjectionSelectorsAreAbsent() public view {
        IDiamondLoupe hook_ = IDiamondLoupe(_subject().hook());
        assertEq(hook_.facetAddress(bytes4(keccak256("previewClaimAfterJoin(uint256,uint256)"))), address(0));
        assertEq(hook_.facetAddress(bytes4(keccak256("previewClaimExit(uint256)"))), address(0));
    }

    function test_bindingHasNativeNineDecimalChildren() public view {
        address detf_ = address(_subject());
        assertEq(IERC20Metadata(detf_).decimals(), 9);
        assertEq(_stake().decimals(), 9);
        assertEq(_stake().detf(), detf_);
        IDETFStandardizedYield children_ = IDETFStandardizedYield(detf_);
        IStandardizedYield raw_ = IStandardizedYield(children_.rawSY());
        IStandardizedYield staked_ = IStandardizedYield(children_.stakingSY());
        assertEq(raw_.decimals(), 9);
        assertEq(staked_.decimals(), 9);
        assertEq(raw_.yieldToken(), detf_);
        assertEq(staked_.yieldToken(), address(_stake()));
        assertEq(raw_.exchangeRate(), 1e18);
    }

    function test_bindingFirstBondFundsPrincipalSeparatelyFromOwnedLP() public {
        (uint256 id_, uint256 lp_) = _purchase(1_000 ether);
        Math.BondPosition memory position_ = _positions().positionOf(id_);
        assertGt(position_.principal, 0);
        assertEq(position_.claimedPrincipal, 0);
        assertEq(position_.startTimestamp, block.timestamp);
        assertGt(lp_, 0);
        assertGe(IERC20(_subject().hook()).balanceOf(address(_positions())), lp_);
        assertGe(_stake().balanceOf(address(_positions())), position_.principal);
        uint256 held_ = IERC20(address(_subject())).balanceOf(address(_stake()));
        assertEq(held_, _stake().stakingState().accountedBacking);
        assertGe(held_, _stake().totalSupply());
        assertEq(IERC20(address(_subject())).balanceOf(_buyer()), 0);
    }

    function test_bindingHalfwayPrincipalUnstakesWithoutLPWithdrawal() public {
        (uint256 id_,) = _purchase(1_000 ether);
        Math.BondPosition memory p_ = _positions().positionOf(id_);
        vm.warp(p_.startTimestamp + p_.vestingDuration / 2);
        vm.startPrank(_buyer());
        uint256 claimed_ = _positions().claimPrincipal(id_, _buyer());
        vm.stopPrank();
        assertEq(claimed_, p_.principal / 2);
        uint256 lp_ = IERC20(_subject().hook()).balanceOf(address(_positions()));
        IStakedDETF staking_ = _stake();
        vm.startPrank(_buyer());(uint256 raw_,) = staking_.exchangeIn(IERC20(address(staking_)), claimed_, IERC20(address(_subject())),
            claimed_, _buyer(), false, block.timestamp
        );
        vm.stopPrank();
        assertEq(raw_, claimed_);
        assertEq(IERC20(address(_subject())).balanceOf(_buyer()), claimed_);
        assertEq(IERC20(_subject().hook()).balanceOf(address(_positions())), lp_);
        assertEq(_positions().positionOf(id_).claimedPrincipal, claimed_);
    }

    function test_bindingRewardsClaimWhilePrincipalRemainsLocked() public {
        (uint256 id_,) = _purchase(1_000 ether);
        Math.BondPosition memory before_ = _positions().positionOf(id_);
        vm.startPrank(_buyer());
        uint256 reward_ = _positions().claimRewards(id_, _buyer());
        vm.stopPrank();
        assertGt(reward_, 0, "funded immediate seigniorage");
        assertEq(_stake().balanceOf(_buyer()), reward_);
        Math.BondPosition memory after_ = _positions().positionOf(id_);
        assertEq(after_.principal, before_.principal);
        assertEq(after_.claimedPrincipal, 0);
        assertEq(after_.startTimestamp, before_.startTimestamp);
        assertEq(_positions().previewClaim(id_).principalDue, 0);
    }

    function test_bindingStaticSYReceivesLaterFundedBondRewards() public {
        (uint256 id_,) = _purchase(1_000 ether);
        Math.BondPosition memory position_ = _positions().positionOf(id_);
        vm.warp(position_.startTimestamp + position_.vestingDuration);
        vm.startPrank(_buyer());
        (uint256 principal_, uint256 rewards_) = _positions().claimBond(id_, _buyer());
        vm.stopPrank();
        IStandardizedYield sy_ = IStandardizedYield(
            IDETFStandardizedYield(address(_subject())).stakingSY()
        );
        IStakedDETF staking_ = _stake();
        vm.startPrank(_buyer());
        staking_.approve(address(sy_), principal_ + rewards_);
        uint256 shares_ = sy_.deposit(_buyer(), address(staking_), principal_ + rewards_, 0);
        vm.stopPrank();
        uint256 rate_ = sy_.exchangeRate();
        _purchase(10 ether);
        assertEq(sy_.balanceOf(_buyer()), shares_);
        assertGt(sy_.exchangeRate(), rate_);
        uint256 quoted_ = sy_.previewRedeem(address(_subject()), shares_);
        vm.prank(_buyer());
        uint256 raw_ = sy_.redeem(_buyer(), shares_, address(_subject()), quoted_, false);
        assertEq(raw_, quoted_);
        assertGt(raw_, principal_ + rewards_);
        assertGe(IERC20(address(_subject())).balanceOf(address(staking_)), staking_.totalSupply());
    }
}

contract WeightedFundedBindingTest is TestBase_UniswapV4Detf_Weighted, V4FundedBindingBehavior {
    function _hookPackage() internal view override returns (address) { return address(weightedHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return address(pairToken); }
}

contract OrbitalFundedBindingTest is TestBase_UniswapV4Detf_Orbital, V4FundedBindingBehavior {
    function _hookPackage() internal view override returns (address) { return address(orbitalHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return address(pairToken); }
}

contract CurveQuadFundedBindingTest is TestBase_UniswapV4Detf_CurveQuad, V4FundedBindingBehavior {
    function _hookPackage() internal view override returns (address) { return address(curveHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return address(pairToken); }
}

