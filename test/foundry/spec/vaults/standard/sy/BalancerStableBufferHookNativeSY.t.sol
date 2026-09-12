// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";

contract BalancerStableBufferHookNativeSYTest is TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook, DETFFundedStakingArtifacts {
    IStandardizedYield private sy_;

    function setUp() public override {
        super.setUp();
        _seedFullBook(1_000 ether);
        sy_ = IStandardizedYield(hook);
        vm.startPrank(user);
        token0.approve(se0, 100 ether);
        IStandardExchangeIn(se0).exchangeIn(token0, 100 ether, IERC20(se0), 0, user, false, block.timestamp);
        vm.stopPrank();
        vm.prank(user);
        IERC20(se0).approve(hook, type(uint256).max);
    }

    function test_balancerStableSYMetadataNativeRateAndAllFacetSelectors() public view {
        assertEq(sy_.decimals(), 18);
        assertEq(sy_.yieldToken(), address(0));
        (IStandardizedYield.AssetType kind_, address unit_, uint8 precision_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(unit_, hook);
        assertEq(precision_, 18);
        assertTrue(IERC165(hook).supportsInterface(type(IStandardizedYield).interfaceId));
        address[] memory tokens_ = sy_.getTokensIn();
        assertEq(tokens_.length, 5);
        assertEq(tokens_[0], address(token0));
        assertEq(tokens_[1], address(token1));
        assertEq(tokens_[2], address(token2));
        assertEq(tokens_[3], address(token3));
        assertEq(tokens_[4], se0);
        assertEq(abi.encode(tokens_), abi.encode(sy_.getTokensOut()));
        assertEq(sy_.getRewardTokens().length, 0);
        assertFalse(sy_.isValidTokenIn(hook));
        uint256[] memory balances_ = new uint256[](4);
        balances_[0] = IStandardExchangeIn(se0).previewExchangeIn(IERC20(se0), IERC20(se0).balanceOf(hook), token0);
        balances_[1] = token1.balanceOf(hook);
        balances_[2] = token2.balanceOf(hook);
        balances_[3] = token3.balanceOf(hook);
        uint256 liquidity_ = StableMath.computeInvariant(DEFAULT_BASE_AMP * 1000, balances_) / 4;
        assertEq(sy_.exchangeRate(), Math.mulDiv(liquidity_, 1e18, sy_.totalSupply()));
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

    function test_balancerStableSYAllPairAndShareInputsAndOutputs() public {
        address[5] memory tokens_ = [address(token0), address(token1), address(token2), address(token3), se0];
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

    function test_balancerStableStandardExactOutputLiquidityUsesRequiredAmountOnly() public {
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
        uint256 sharePayment_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(se0), IERC20(hook), wanted_);
        before_ = IERC20(se0).balanceOf(user);
        vm.prank(user);
        assertEq(IStandardExchangeOut(hook).exchangeOut(IERC20(se0), sharePayment_ + 100 ether, IERC20(hook), wanted_, user, false, block.timestamp), sharePayment_);
        assertEq(IERC20(se0).balanceOf(user), before_ - sharePayment_);
    }

    function test_balancerStableSYInternalSharesBurnOnlyRequestedAmountAndPaySeShares() public {
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

    function test_balancerStableSYLimitsAndPrepaidShareInventoryCannotCreditCaller() public {
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

    function test_balancerStableStandardSwapsRemainSupplyNeutral() public {
        uint256 supply_ = sy_.totalSupply();
        uint256 quote_ = IStandardExchangeIn(hook).previewExchangeIn(token1, 1 ether, token0);
        vm.prank(user);
        assertEq(IStandardExchangeIn(hook).exchangeIn(token1, 1 ether, token0, quote_, user, false, block.timestamp), quote_);
        assertEq(sy_.totalSupply(), supply_);
    }
}
