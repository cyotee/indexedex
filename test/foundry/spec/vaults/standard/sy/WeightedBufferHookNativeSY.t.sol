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
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";

contract WeightedBufferHookNativeSYTest is TestBase_UniswapV4StandardExchangeWeightedBufferHook, DETFFundedStakingArtifacts {
    IStandardizedYield private sy_;

    function setUp() public override {
        super.setUp();
        _seedFullBook(1_000 ether);
        sy_ = IStandardizedYield(hook);
        _userAcquireSeShares(se0, token0, 100 ether);
        vm.prank(user);
        IERC20(se0).approve(hook, type(uint256).max);
    }

    function test_weightedSYMetadataNativeRateAndAllFacetSelectors() public view {
        assertEq(sy_.decimals(), 18);
        assertEq(sy_.yieldToken(), address(0));
        (IStandardizedYield.AssetType kind_, address unit_, uint8 precision_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(unit_, hook);
        assertEq(precision_, 18);
        assertTrue(IERC165(hook).supportsInterface(type(IStandardizedYield).interfaceId));
        address[] memory tokens_ = sy_.getTokensIn();
        assertEq(tokens_.length, 3);
        assertEq(tokens_[0], address(token0));
        assertEq(tokens_[1], address(token1));
        assertEq(tokens_[2], se0);
        assertEq(abi.encode(tokens_), abi.encode(sy_.getTokensOut()));
        assertEq(sy_.getRewardTokens().length, 0);
        assertFalse(sy_.isValidTokenIn(hook));
        uint256 root_ = Math.sqrt(IERC20(se0).balanceOf(hook) * token1.balanceOf(hook));
        // Existing Balancer powDown subtracts a 1e-14 relative error per power.
        // Two half-weight powers plus integer product rounding fit within 3e-14.
        assertApproxEqRel(sy_.exchangeRate(), Math.mulDiv(root_, 1e18, sy_.totalSupply()), 30_000, "native book matches the geometric mean within the existing conservative power bound");
        address[] memory facets_ = hookPkg.facetAddresses();
        assertLe(address(hookPkg).code.length, 24_576);
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertLe(facets_[i_].code.length, 24_576);
            bytes4[] memory selectors_ = IFacet(facets_[i_]).facetFuncs();
            for (uint256 j_; j_ < selectors_.length; ++j_) {
                address installed_ = IDiamondLoupe(hook).facetAddress(selectors_[j_]);
                if (facets_[i_] == address(hookPkg)) {
                    // Finalization removes the package's initialization selectors;
                    // production hooks may install their own versions of the views.
                    assertNotEq(installed_, facets_[i_], "initialization package still installed");
                } else {
                    assertEq(installed_, facets_[i_], IFacet(facets_[i_]).facetName());
                }
            }
        }
    }

    function test_weightedSYAllPairAndShareInputsAndOutputs() public {
        address[3] memory tokens_ = [address(token0), address(token1), se0];
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            address in_ = tokens_[i_];
            address out_ = tokens_[(i_ + 1) % tokens_.length];
            uint256 amount_ = 5 ether;
            uint256 expected_ = sy_.previewDeposit(in_, amount_);
            uint256 paidBefore_ = IERC20(in_).balanceOf(user);
            assertEq(IStandardExchangeIn(hook).previewExchangeIn(IERC20(in_), amount_, IERC20(hook)), expected_);
            vm.prank(user);
            uint256 minted_ = sy_.deposit(user, in_, amount_, expected_);
            assertEq(minted_, expected_);
            assertEq(IERC20(in_).balanceOf(user), paidBefore_ - amount_);
            uint256 quote_ = sy_.previewRedeem(out_, minted_);
            uint256 receivedBefore_ = IERC20(out_).balanceOf(user);
            vm.prank(user);
            uint256 received_ = sy_.redeem(user, minted_, out_, quote_, false);
            assertEq(received_, quote_);
            assertEq(IERC20(out_).balanceOf(user), receivedBefore_ + received_);
        }
    }

    function test_weightedStandardExactOutputLiquidityUsesRequiredAmountOnly() public {
        uint256 wanted_ = 1 ether;
        uint256 required_ = IStandardExchangeOut(hook).previewExchangeOut(token1, IERC20(hook), wanted_);
        uint256 before_ = token1.balanceOf(user);
        uint256 lpBefore_ = sy_.balanceOf(user);
        vm.prank(user);
        uint256 spent_ = IStandardExchangeOut(hook).exchangeOut(token1, required_ + 100 ether, IERC20(hook), wanted_, user, false, block.timestamp);
        assertEq(spent_, required_);
        assertEq(token1.balanceOf(user), before_ - required_);
        assertEq(sy_.balanceOf(user), lpBefore_ + wanted_);
        required_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(hook), token1, wanted_);
        lpBefore_ = sy_.balanceOf(user);
        before_ = token1.balanceOf(user);
        vm.prank(user);
        spent_ = IStandardExchangeOut(hook).exchangeOut(IERC20(hook), required_ + 100 ether, token1, wanted_, user, false, block.timestamp);
        assertEq(spent_, required_);
        assertEq(sy_.balanceOf(user), lpBefore_ - required_);
        assertEq(token1.balanceOf(user), before_ + wanted_);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(hook).previewExchangeOut(IERC20(se0), IERC20(hook), wanted_);
    }

    function test_weightedSYInternalSharesBurnOnlyRequestedAmountAndPaySeShares() public {
        uint256 held_ = sy_.balanceOf(user) / 4;
        uint256 redeem_ = held_ / 3;
        uint256 quote_ = sy_.previewRedeem(se0, redeem_);
        uint256 before_ = IERC20(se0).balanceOf(user);
        vm.startPrank(user);
        sy_.transfer(hook, held_);
        assertEq(sy_.redeem(user, redeem_, se0, quote_, true), quote_);
        vm.stopPrank();
        assertEq(sy_.balanceOf(hook), held_ - redeem_);
        assertEq(IERC20(se0).balanceOf(user), before_ + quote_);
    }

    function test_weightedSYLimitsAndPrepaidShareInventoryCannotCreditCaller() public {
        uint256 before_ = IERC20(se0).balanceOf(user);
        uint256 shares_ = sy_.balanceOf(user);
        vm.startPrank(user);
        vm.expectRevert();
        sy_.deposit(user, se0, 1 ether, type(uint256).max);
        vm.expectRevert();
        sy_.redeem(user, 1 ether, se0, type(uint256).max, false);
        IERC20(se0).transfer(hook, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        IStandardExchangeIn(hook).exchangeIn(IERC20(se0), 1 ether, IERC20(hook), 0, user, true, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(se0).balanceOf(user), before_ - 1 ether);
        assertEq(sy_.balanceOf(user), shares_);
    }

    function test_weightedStandardSwapsRemainSupplyNeutral() public {
        uint256 supply_ = sy_.totalSupply();
        uint256 quote_ = IStandardExchangeIn(hook).previewExchangeIn(token1, 1 ether, token0);
        vm.prank(user);
        assertEq(IStandardExchangeIn(hook).exchangeIn(token1, 1 ether, token0, quote_, user, false, block.timestamp), quote_);
        assertEq(sy_.totalSupply(), supply_);
    }
}

contract WeightedBufferHookRestrictedSYTest is TestBase_UniswapV4StandardExchangeWeightedBufferHook, DETFFundedStakingArtifacts {
    function _pkgOwnerOnlyLiquidity() internal pure override returns (bool) { return true; }
    function _pkgOwner() internal view override returns (address) { return user; }

    function test_restrictedSYInternalRedemptionPreservesCallerAndClearsAuthorization() public {
        _seedFullBook(1_000 ether);
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

    function test_weightedSYKeepsExistingLiquidityOwnerRestriction() public {
        _seedFullBook(1_000 ether);
        address outsider_ = makeAddr("weighted restricted outsider");
        token1.mint(outsider_, 5 ether);
        vm.startPrank(outsider_);
        token1.approve(hook, 5 ether);
        vm.expectRevert();
        IStandardizedYield(hook).deposit(outsider_, address(token1), 5 ether, 0);
        vm.stopPrank();
        assertEq(token1.balanceOf(outsider_), 5 ether);
        assertEq(IERC20(hook).balanceOf(outsider_), 0);
        vm.prank(user);
        assertGt(IStandardizedYield(hook).deposit(user, address(token1), 5 ether, 0), 0);
    }
}
