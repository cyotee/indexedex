// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeSYExecutionAssertions} from "contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol";

import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {Math as NativeLiquidityMath} from "@crane/contracts/utils/Math.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4DualSEBCPHook} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet.sol";

/// @notice Existing single-asset LP exits must work before exposing them through native SY.
contract DualBufferHookLiquidityRegressionTest is TestBase_UniswapV4DualSEBCPHook, NativeSYExecutionAssertions {
    function setUp() public override {
        super.setUp();
        _depositBoth(1_000 ether, 1_000 ether);
    }

    function test_dualSingleAssetExitPaysOnlyItsOwnRawOutput() public {
        _assertRawExit(address(tokenA));
        _assertRawExit(address(tokenB));
    }

    function test_dualSingleAssetExitPreservesPreexistingRawInventory() public {
        tokenA.mint(hook, 7 ether);
        tokenB.mint(hook, 11 ether);
        uint256 beforeA_ = _unbookedRaw(address(tokenA), seA);
        uint256 beforeB_ = _unbookedRaw(address(tokenB), seB);
        assertEq(beforeA_, 7 ether);
        assertEq(beforeB_, 11 ether);
        _assertRawExit(address(tokenA));
        assertEq(_unbookedRaw(address(tokenA), seA), beforeA_, "unbooked tokenA donation survives");
        assertEq(_unbookedRaw(address(tokenB), seB), beforeB_, "unbooked tokenB donation survives");
    }

    function test_dualSingleAssetExitDeliversSelectedSeShareToken() public {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(hook);
        uint256 shares_ = IERC20(hook).balanceOf(user) / 20;
        uint256 quote_ = host_.previewExitSingleAssetExactBptIn(seA, shares_);
        uint256 seBefore_ = IERC20(seA).balanceOf(user);
        uint256 rawBefore_ = tokenA.balanceOf(user);
        vm.prank(user);
        uint256 out_ = host_.exitSingleAssetExactBptIn(seA, shares_, user, quote_, block.timestamp);
        assertGt(out_, 0);
        assertGe(out_, quote_, "share exit preview");
        assertEq(IERC20(seA).balanceOf(user), seBefore_ + out_, "wrong payout token");
        assertEq(tokenA.balanceOf(user), rawBefore_, "share exit paid raw token");
    }

    function test_dualNativeSYMetadataAndRuntime() public view {
        IStandardizedYield sy = IStandardizedYield(hook);
        assertTrue(IERC165(hook).supportsInterface(type(IStandardizedYield).interfaceId));
        assertEq(sy.decimals(), 18); assertEq(sy.yieldToken(), address(0));
        (IStandardizedYield.AssetType kind, address host, uint8 decimals) = sy.assetInfo();
        assertEq(uint8(kind), uint8(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(host, hook); assertEq(decimals, 18);
        assertEq(sy.getTokensIn().length, 4);
        assertEq(sy.getTokensIn(), sy.getTokensOut());
        assertEq(sy.getRewardTokens().length, 0);
        assertGt(sy.exchangeRate(), 0);
        address[] memory facets = IDiamondLoupe(hook).facetAddresses();
        for (uint256 i; i < facets.length; ++i) assertLe(facets[i].code.length, 24_576);
    }

    function test_dualNativeSYPaidSingleInputsMintAndEveryOutputRedeems() public noSelfCalls(hook) {
        IStandardizedYield sy = IStandardizedYield(hook);
        vm.startPrank(user);
        tokenA.approve(seA, 20 ether);
        tokenB.approve(seB, 20 ether);IStandardExchangeIn(seA).exchangeIn(tokenA, 20 ether, IERC20(seA), 0, user, false, block.timestamp);IStandardExchangeIn(seB).exchangeIn(tokenB, 20 ether, IERC20(seB), 0, user, false, block.timestamp);
        address[] memory inputs = sy.getTokensIn();
        for (uint256 i; i < inputs.length; ++i) {
            IERC20(inputs[i]).approve(hook, 2 ether);
            uint256 shares = sy.previewDeposit(inputs[i], 2 ether);
            assertGt(shares, 0, "paid preparation funds both legs");
            (uint256 sePreview,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(inputs[i]), 2 ether, IERC20(hook));
            assertEq(sePreview, shares, "SY and SE share the component quote");
            uint256 lpBefore = sy.balanceOf(user);
            uint256 inputBefore = IERC20(inputs[i]).balanceOf(user);
            uint256 minted = sy.deposit(user, inputs[i], 2 ether, shares);
            assertEq(minted, shares);
            assertEq(sy.balanceOf(user) - lpBefore, minted);
            uint256 spent = inputBefore - IERC20(inputs[i]).balanceOf(user);
            assertGt(spent, 0);
            assertLe(spent, 2 ether);
            address output = inputs[(i + 1) % inputs.length];
            uint256 quoted = sy.previewRedeem(output, shares);
            uint256 before = IERC20(output).balanceOf(user);
            assertGt(quoted, 0, "real SY redemption remains feasible");
            uint256 paid = sy.redeem(user, shares, output, quoted, false);
            assertGe(paid, quoted, "SY redeem preview");
            assertEq(IERC20(output).balanceOf(user) - before, paid, "actual payout token");
        }
        vm.stopPrank();
    }

    function test_dualCompleteComponentJoinStillMintsPositiveLP() public {
        uint256 supply = IERC20(hook).totalSupply();
        uint256 balance = IERC20(hook).balanceOf(user);
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeBefore = IERC20(hook).balanceOf(feeTo);
        (uint256 preview,,) = dual.previewDeposit(10 ether, 10 ether);
        assertGt(preview, 0);
        uint256 net = _depositBoth(10 ether, 10 ether);
        assertEq(net, preview);
        assertEq(IERC20(hook).balanceOf(user) - balance, net);
        assertEq(IERC20(hook).totalSupply() - supply,
            net + IERC20(hook).balanceOf(feeTo) - feeBefore, "backed mint splits without extra LP");
    }

    function test_dualNativeSYInternalRedemptionAndLimits() public noSelfCalls(hook) {
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        IStandardizedYield sy = IStandardizedYield(hook);
        vm.startPrank(user);
        uint256 supply = sy.totalSupply();
        uint256 amount = sy.balanceOf(user) / 100;
        uint256 quoted = sy.previewRedeem(address(tokenA), amount);
        vm.expectRevert();
        sy.redeem(user, amount, address(tokenA), type(uint256).max, false);
        assertEq(sy.totalSupply(), supply);
        sy.transfer(hook, amount * 3);
        uint256 paid = abi.decode(atomic.execute(address(sy), abi.encodeCall(IStandardizedYield.redeem, (user, amount, address(tokenA), quoted, true))), (uint256));
        assertGe(paid, quoted, "internal SY redeem preview");
        assertEq(sy.balanceOf(hook), amount * 2, "unrequested internal shares retained");
        vm.stopPrank();
    }

    function test_quoteReceivedSharesMatchesActualTransferWithoutChangingBacking() public {
        address receiver = address(0xCA11);
        IStandardExchangeTransitionQuote transition = IStandardExchangeTransitionQuote(seA);
        (bytes memory state,) = transition.quoteState(address(tokenA), receiver);
        (bytes memory projected,,,) = transition.quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, 1 ether
        );
        uint256 supply = IERC20(seA).totalSupply();
        uint256 backing = vaultA.balanceOf(seA);
        vm.prank(hook); IERC20(seA).transfer(receiver, 1 ether);
        (bytes memory actual,) = transition.quoteState(address(tokenA), receiver);
        assertEq(actual, projected, "transfer projection matches the complete actual state");
        assertEq(IERC20(seA).totalSupply(), supply);
        assertEq(vaultA.balanceOf(seA), backing);
    }

    function test_dualNativeSYFundedYieldChangesRateWithoutRebasingShares() public {
        IStandardizedYield sy = IStandardizedYield(hook);
        uint256 rate = sy.exchangeRate();
        assertEq(rate, _expectedRate(), "rated SE shares plus local backing over actual supply");
        uint256 shares = sy.balanceOf(user);
        uint256 supply = sy.totalSupply();
        vm.startPrank(user);
        tokenA.approve(address(vaultA), 100 ether);
        vaultA.simulateYield(100 ether);
        vm.stopPrank();
        assertGt(sy.exchangeRate(), rate);
        assertEq(sy.exchangeRate(), _expectedRate());
        assertEq(sy.balanceOf(user), shares);
        assertEq(sy.totalSupply(), supply, "passive SE yield mints no Hook LP");
        assertEq(sy.claimRewards(user).length, 0);
    }

    function _expectedRate() private view returns (uint256) {
        uint256 backingA_ = tokenA.balanceOf(hook) + NativeLiquidityMath.mulDiv(IERC20(seA).balanceOf(hook),
            IRateProvider(IUniswapV4SeBufferHook(hook).rateProvider(address(tokenA))).getRate(), 1e18);
        uint256 backingB_ = tokenB.balanceOf(hook) + NativeLiquidityMath.mulDiv(IERC20(seB).balanceOf(hook),
            IRateProvider(IUniswapV4SeBufferHook(hook).rateProvider(address(tokenB))).getRate(), 1e18);
        return NativeLiquidityMath.mulDiv(NativeLiquidityMath.sqrt(backingA_ * backingB_), 1e18, IERC20(hook).totalSupply());
    }

    function _unbookedRaw(address token_, address se_) private view returns (uint256) {
        uint256 ratedShares_ = NativeLiquidityMath.mulDiv(IERC20(se_).balanceOf(hook),
            IRateProvider(IUniswapV4SeBufferHook(hook).rateProvider(token_)).getRate(), 1e18);
        uint256 reserve_ = token_ == dual.token0() ? dual.claimSupply0() : dual.claimSupply1();
        uint256 bookedLocal_ = reserve_ - ratedShares_;
        return IERC20(token_).balanceOf(hook) - bookedLocal_;
    }

    function _assertRawExit(address out_) private {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(hook);
        uint256 shares_ = IERC20(hook).balanceOf(user) / 20;
        uint256 quote_ = host_.previewExitSingleAssetExactBptIn(out_, shares_);
        address feeRecipient_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeLpBefore_ = IERC20(hook).balanceOf(feeRecipient_);
        uint256 supply_ = IERC20(hook).totalSupply();
        uint256 lpBefore_ = IERC20(hook).balanceOf(user);
        uint256 before_ = IERC20(out_).balanceOf(user);
        vm.prank(user);
        uint256 received_ = host_.exitSingleAssetExactBptIn(out_, shares_, user, quote_, block.timestamp);
        assertGt(received_, 0);
        assertGe(received_, quote_, "raw exit preview");
        assertEq(IERC20(out_).balanceOf(user), before_ + received_, "raw exit payout");
        assertEq(IERC20(hook).balanceOf(user), lpBefore_ - shares_, "actual holder burn");
        assertEq(IERC20(hook).balanceOf(feeRecipient_), feeLpBefore_, "withdrawal charges no LP mint fee");
        assertEq(IERC20(hook).totalSupply(), supply_ - shares_, "only the requested LP is burned");
    }
}

import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";

import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
