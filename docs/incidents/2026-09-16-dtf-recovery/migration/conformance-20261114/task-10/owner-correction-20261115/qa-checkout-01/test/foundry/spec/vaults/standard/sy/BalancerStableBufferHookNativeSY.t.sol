// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeSYExecutionAssertions} from "contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

contract BalancerStableBufferHookNativeSYTest is TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook, NativeSYExecutionAssertions {
    function test_nativeSYHeldRedemptionHelperIsNotPublic() public {
        address facet_ = IDiamondLoupe(hook).facetAddress(IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector);
        bytes memory data_ = abi.encodeWithSignature(
            "executeVaultHeldRedemption(address,uint256,address,uint256)", user, 1, address(token0), 0
        );
        (bool ok_, bytes memory reason_) = facet_.call(data_);
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("DelegateCallRequired()"));
        (ok_, reason_) = hook.call(data_);
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("NoTargetFor(bytes4)", bytes4(data_)));
    }

    IStandardizedYield private sy_;

    function setUp() public override {
        super.setUp();
        _seedFullBook(1_000 ether);
        sy_ = IStandardizedYield(hook);
        vm.startPrank(user);
        token0.approve(se0, 100 ether);IStandardExchangeIn(se0).exchangeIn(token0, 100 ether, IERC20(se0), 0, user, false, block.timestamp);
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
        balances_[0] = Math.mulDiv(IERC20(se0).balanceOf(hook),
            IRateProvider(quad.rateProvider(address(token0))).getRate(), 1e18) + token0.balanceOf(hook);
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

    function test_balancerStableSYPaidSingleInputsMintAndAllOutputsRedeem() public noSelfCalls(hook) {
        address[5] memory tokens_ = [address(token0), address(token1), address(token2), address(token3), se0];
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            address in_ = tokens_[i_];
            address out_ = tokens_[(i_ + 1) % tokens_.length];
            uint256 amount_ = 5 ether;
            uint256 expected_ = sy_.previewDeposit(in_, amount_);
            assertGt(expected_, 0, "paid preparation funds the complete basket");
            (uint256 previewAmountOut1,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(in_), amount_, IERC20(hook));
            assertEq(previewAmountOut1, expected_);
            uint256 lpBefore_ = sy_.balanceOf(user);
            uint256 inputBefore_ = IERC20(in_).balanceOf(user);
            vm.prank(user);
            uint256 minted_ = sy_.deposit(user, in_, amount_, expected_);
            assertEq(minted_, expected_);
            assertEq(sy_.balanceOf(user) - lpBefore_, minted_);
            uint256 spent_ = inputBefore_ - IERC20(in_).balanceOf(user);
            assertGt(spent_, 0);
            assertLe(spent_, amount_);
            uint256 quote_ = sy_.previewRedeem(out_, minted_);
            assertGt(quote_, 0, "real SY redemption remains feasible");
            uint256 receivedBefore_ = IERC20(out_).balanceOf(user);
            vm.prank(user);
            uint256 received_ = sy_.redeem(user, minted_, out_, quote_, false);
            assertEq(received_, quote_);
            assertEq(IERC20(out_).balanceOf(user), receivedBefore_ + received_);
        }
    }

    function test_balancerStableStandardExactOutputPaidJoinAndRedemptionRespectBudgets() public {
        uint256 wanted_ = 1 ether;
        uint256 requiredIn_ = IStandardExchangeOut(hook).previewExchangeOut(token1, IERC20(hook), wanted_);
        assertGt(requiredIn_, 0);
        bytes32 state_ = _componentOwnershipState(user);
        vm.prank(user);
        vm.expectRevert();
        IStandardExchangeOut(hook).exchangeOut(token1, 0, IERC20(hook), wanted_, user, false, block.timestamp);
        assertEq(_componentOwnershipState(user), state_, "insufficient input budget restores all custody");
        uint256 inputBefore_ = token1.balanceOf(user);
        uint256 lpBefore_ = sy_.balanceOf(user);
        vm.prank(user);
        uint256 used_ = IStandardExchangeOut(hook).exchangeOut(token1, requiredIn_ + 100 ether, IERC20(hook), wanted_, user, false, block.timestamp);
        assertGt(used_, 0);
        assertLe(used_, requiredIn_, "forward quote bounds actual input, not caller fat maximum");
        assertEq(inputBefore_ - token1.balanceOf(user), used_);
        assertEq(sy_.balanceOf(user) - lpBefore_, wanted_, "exact net LP delivered after mint fee");
        uint256 before_ = token1.balanceOf(user);
        lpBefore_ = sy_.balanceOf(user);
        uint256 required_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(hook), token1, wanted_);
        assertGt(required_, 0);
        vm.prank(user);
        uint256 spent_ = IStandardExchangeOut(hook).exchangeOut(IERC20(hook), required_ + 100 ether, token1, wanted_, user, false, block.timestamp);
        assertEq(spent_, required_);
        assertEq(sy_.balanceOf(user), lpBefore_ - required_);
        assertEq(token1.balanceOf(user), before_ + wanted_);
        uint256 shareRequired_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(se0), IERC20(hook), wanted_);
        uint256 shareBefore_ = IERC20(se0).balanceOf(user);
        lpBefore_ = sy_.balanceOf(user);
        vm.prank(user);
        uint256 shareSpent_ = IStandardExchangeOut(hook).exchangeOut(IERC20(se0), shareRequired_ + 1 ether, IERC20(hook), wanted_, user, false, block.timestamp);
        assertGt(shareSpent_, 0);
        assertLe(shareSpent_, shareRequired_);
        assertEq(shareBefore_ - IERC20(se0).balanceOf(user), shareSpent_);
        assertEq(sy_.balanceOf(user) - lpBefore_, wanted_);
    }

    function test_balancerStableCompleteComponentJoinStillMintsPositiveLP() public {
        uint256[] memory amounts_ = new uint256[](4);
        for (uint256 i_; i_ < 4; ++i_) amounts_[i_] = 5 ether;
        (uint256 preview_,) = quad.previewJoinProportional(amounts_);
        assertGt(preview_, 0);
        uint256 before_ = sy_.balanceOf(user);
        vm.prank(user);
        (uint256 net_,) = quad.joinProportional(amounts_, user, preview_, block.timestamp);
        assertEq(net_, preview_);
        assertEq(sy_.balanceOf(user) - before_, net_);
    }

    function test_balancerStableSYInternalSharesBurnOnlyRequestedAmountAndPaySeShares() public noSelfCalls(hook) {
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        uint256 held_ = sy_.balanceOf(user) / 4;
        uint256 redeem_ = held_ / 3;
        uint256 quote_ = sy_.previewRedeem(se0, redeem_);
        uint256 before_ = IERC20(se0).balanceOf(user);
        vm.startPrank(user);
        sy_.transfer(hook, held_);
        assertEq(abi.decode(atomic.execute(address(sy_), abi.encodeCall(IStandardizedYield.redeem, (user, redeem_, se0, quote_, true))), (uint256)), quote_);
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
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);IStandardExchangeIn(hook).exchangeIn(IERC20(se0), 1 ether, IERC20(hook), 0, user, true, block.timestamp);
        vm.stopPrank();
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        atomic.execute(
            hook,
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                IERC20(se0),
                uint256(1 ether),
                IERC20(hook),
                uint256(0),
                address(atomic),
                true,
                block.timestamp
            )
        );
        assertEq(IERC20(se0).balanceOf(user), before_ - 1 ether);
        assertEq(sy_.balanceOf(user), shares_);
    }

    function test_balancerStableStandardSwapsRemainSupplyNeutral() public {
        uint256 supply_ = sy_.totalSupply();(uint256 quote_,) = IStandardExchangeIn(hook).previewExchangeIn(token1, 1 ether, token0);
        vm.prank(user);
        (uint256 exchangeAmountOut2,) = IStandardExchangeIn(hook).exchangeIn(token1, 1 ether, token0, quote_, user, false, block.timestamp);
        assertEq(exchangeAmountOut2, quote_);
        assertEq(sy_.totalSupply(), supply_);
    }
}
