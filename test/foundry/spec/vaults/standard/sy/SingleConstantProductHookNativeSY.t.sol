// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";

contract SingleConstantProductHookNativeSYTest is TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook, DETFFundedStakingArtifacts {
    IStandardizedYield private sy_;
    function setUp() public override {
        super.setUp();
        _seedLiveLiquidity();
        sy_ = IStandardizedYield(hook);
    }

    function test_hookSYNativeLiquidityMetadataAndInstalledSelectors() public view {
        assertEq(sy_.decimals(), 18);
        assertEq(sy_.yieldToken(), address(0));
        (IStandardizedYield.AssetType kind_, address host_, uint8 decimals_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(host_, hook);
        assertEq(decimals_, 18);
        assertTrue(IERC165(hook).supportsInterface(type(IStandardizedYield).interfaceId));
        address[] memory inputs_ = sy_.getTokensIn();
        assertEq(inputs_.length, 3);
        assertEq(inputs_[0], address(rawToken));
        assertEq(inputs_[1], address(pairToken));
        assertEq(inputs_[2], se);
        assertEq(sy_.getTokensOut().length, 2);
        assertFalse(sy_.isValidTokenOut(se), "share output remains directionally unsupported");
        assertTrue(sy_.isValidTokenIn(address(rawToken)) && sy_.isValidTokenOut(address(pairToken)));
        assertFalse(sy_.isValidTokenIn(hook) || sy_.isValidTokenOut(address(0)));
        assertEq(sy_.getRewardTokens().length, 0);
        assertEq(sy_.accruedRewards(user).length, 0);
        assertEq(sy_.rewardIndexesStored().length, 0);
        address[] memory facets_ = hookPkg.facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) assertLe(facets_[i_].code.length, 24_576);
        address facet_ = IDiamondLoupe(hook).facetAddress(IStandardizedYield.deposit.selector);
        bytes4[] memory exported_ = IFacet(facet_).facetFuncs();
        for (uint256 i_; i_ < exported_.length; ++i_) assertEq(IDiamondLoupe(hook).facetAddress(exported_[i_]), facet_);
    }

    function test_hookSYRateUsesExistingGeometricBookAndStaticShares() public {
        _enableProtocolFee(0.05e18);
        uint256 before_ = sy_.exchangeRate();
        uint256 shares_ = sy_.balanceOf(user);
        vm.startPrank(user);
        pairToken.approve(address(pairProtocolVault), 20 ether);
        pairProtocolVault.simulateYield(20 ether);
        vm.stopPrank();
        uint256 root_ = Math.sqrt(single.reserveCurrency0() * single.reserveCurrency1());
        uint256 oldRoot_ = Math.sqrt(single.kLast());
        // At the configured 5% fee, protocol LP = supply * growth / (19 * current root + old root).
        uint256 feeLp_ = sy_.totalSupply() * (root_ - oldRoot_) / (19 * root_ + oldRoot_);
        uint256 expected_ = Math.mulDiv(root_, 1e18, sy_.totalSupply() + feeLp_);
        assertEq(sy_.exchangeRate(), expected_);
        assertGt(expected_, before_);
        assertEq(sy_.balanceOf(user), shares_);
        address feeTo_ = _feeTo();
        uint256 feeBefore_ = sy_.balanceOf(feeTo_);
        _depositBoth(1 ether, 1 ether);
        assertEq(sy_.balanceOf(feeTo_) - feeBefore_, feeLp_, "quoted fee dilution is actually minted by the next liquidity operation");
    }

    function test_hookSYBothBookDirectionsUseSameStandardLiquidityRoutes() public {
        vm.startPrank(user);
        pairToken.approve(se, 20 ether);
        IStandardExchangeIn(se).exchangeIn(pairToken, 20 ether, IERC20(se), 0, user, false, block.timestamp);
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
        IERC20[3] memory tokens_ = [IERC20(address(rawToken)), IERC20(address(pairToken)), IERC20(se)];
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            uint256 expected_ = sy_.previewDeposit(address(tokens_[i_]), 5 ether);
            assertGt(expected_, 0);
            assertEq(IStandardExchangeIn(hook).previewExchangeIn(tokens_[i_], 5 ether, IERC20(hook)), expected_);
            vm.prank(user);
            uint256 minted_ = sy_.deposit(user, address(tokens_[i_]), 5 ether, expected_);
            assertEq(minted_, expected_);
            address out_ = address(tokens_[i_ == 0 ? 1 : 0]);
            uint256 quoted_ = sy_.previewRedeem(out_, minted_);
            uint256 before_ = IERC20(out_).balanceOf(user);
            vm.prank(user);
            uint256 received_ = sy_.redeem(user, minted_, out_, quoted_, false);
            assertGe(received_, quoted_);
            assertEq(IERC20(out_).balanceOf(user), before_ + received_);
        }
    }

    function test_hookSYInternalRedemptionBurnsOnlyRequestedShares() public {
        uint256 held_ = sy_.balanceOf(user) / 2;
        uint256 amount_ = held_ / 3;
        vm.startPrank(user);
        sy_.transfer(hook, held_);
        uint256 expected_ = sy_.previewRedeem(address(rawToken), amount_);
        uint256 received_ = sy_.redeem(user, amount_, address(rawToken), expected_, true);
        vm.stopPrank();
        assertGe(received_, expected_);
        assertEq(sy_.balanceOf(hook), held_ - amount_);
    }

    function test_hookSYSlippageAndPrepaidInventoryCannotCreateCredit() public {
        uint256 amount_ = 5 ether;
        uint256 before_ = rawToken.balanceOf(user);
        uint256 shares_ = sy_.balanceOf(user);
        vm.startPrank(user);
        vm.expectRevert();
        sy_.deposit(user, address(rawToken), amount_, type(uint256).max);
        vm.expectRevert();
        sy_.redeem(user, shares_ / 100, address(pairToken), type(uint256).max, false);
        rawToken.transfer(hook, amount_);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount_, 0));
        IStandardExchangeIn(hook).exchangeIn(rawToken, amount_, IERC20(hook), 0, user, true, block.timestamp);
        vm.stopPrank();
        assertEq(rawToken.balanceOf(user), before_ - amount_);
        assertEq(sy_.balanceOf(user), shares_);
    }

    function test_hookStandardSwapStillExecutesWithoutMintingLP() public {
        uint256 supply_ = sy_.totalSupply();
        uint256 expected_ = IStandardExchangeIn(hook).previewExchangeIn(rawToken, 1 ether, pairToken);
        vm.prank(user);
        assertEq(IStandardExchangeIn(hook).exchangeIn(rawToken, 1 ether, pairToken, expected_, user, false, block.timestamp), expected_);
        assertEq(sy_.totalSupply(), supply_);
    }
}

contract SingleConstantProductHookRestrictedSYTest is TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook, DETFFundedStakingArtifacts {
    function _pkgOwnerOnlyLiquidity() internal pure override returns (bool) { return true; }
    function _pkgOwner() internal view override returns (address) { return user; }

    function test_restrictedSYInternalRedemptionPreservesCallerAndClearsAuthorization() public {
        _seedLiveLiquidity();
        IStandardizedYield sy = IStandardizedYield(hook);
        uint256 shares = sy.balanceOf(user) / 100;
        vm.prank(user); sy.transfer(hook, shares * 2);
        address output = sy.getTokensOut()[0];
        address outsider = makeAddr("unauthorized internal SY redeemer");
        vm.expectRevert(); vm.prank(outsider); sy.redeem(outsider, shares, output, 0, true);
        assertEq(sy.balanceOf(hook), shares * 2);
        uint256 quoted = sy.previewRedeem(output, shares);
        uint256 before = IERC20(output).balanceOf(user);
        vm.prank(user); uint256 received = sy.redeem(user, shares, output, quoted, true);
        assertEq(IERC20(output).balanceOf(user) - before, received);
        assertEq(sy.balanceOf(hook), shares);
        vm.expectRevert(); vm.prank(outsider); sy.redeem(outsider, shares, output, 0, true);
        assertEq(sy.balanceOf(hook), shares, "owner's completed call leaves no public removal authority");
    }

    function test_hookSYRetainsConfiguredLiquidityOwnerRestriction() public {
        _seedLiveLiquidity();
        address outsider_ = makeAddr("restricted hook outsider");
        rawToken.mint(outsider_, 5 ether);
        vm.startPrank(outsider_);
        rawToken.approve(hook, 5 ether);
        vm.expectRevert();
        IStandardizedYield(hook).deposit(outsider_, address(rawToken), 5 ether, 0);
        vm.stopPrank();
        assertEq(rawToken.balanceOf(outsider_), 5 ether);
        assertEq(IERC20(hook).balanceOf(outsider_), 0);
        vm.prank(user);
        uint256 minted_ = IStandardizedYield(hook).deposit(user, address(rawToken), 5 ether, 0);
        assertGt(minted_, 0);
    }
}
