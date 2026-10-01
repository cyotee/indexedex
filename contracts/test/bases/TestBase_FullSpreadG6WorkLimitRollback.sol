// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {UniswapV4Quoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as Shapes} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";
import {IFullSpreadCampaignFeeLedger} from "contracts/test/bases/TestBase_UniswapV4FullSpreadCrossModeCampaign.sol";

// tag::TestBase_FullSpreadG6WorkLimitRollback[]
/// @notice Actual spacing-1 pool: F6 cannot accept a 64-step prefix that has not reached the price limit.
/// @dev Uses the existing CoreSettlement spacing-1/bitmap-word fixture pattern, not invented tick storage.
abstract contract TestBase_FullSpreadG6WorkLimitRollback is Test {
    using PoolIdLibrary for PoolKey;

    struct Observation {
        bytes state;
        uint256 shares;
        uint256 allowance;
        uint256[2] caller;
        uint256[2] manager;
        uint256[2] hook;
        uint256[2] booked;
        uint256[2] growth;
        uint256[2] checkpoints;
        uint256[4] charges;
    }

    IStandardExchangeProxy internal workVault;
    IPoolManager internal workManager;
    PoolKey internal workKey;
    IERC20[2] internal workTokens;

    function _startG6Work(IStandardExchangeProxy vault_, IPoolManager manager_, PoolKey memory key_,
        IERC20 token0_, IERC20 token1_) internal
    {
        workVault = vault_; workManager = manager_; workKey = key_; workTokens = [token0_, token1_];
        vault_.approve(address(vault_), type(uint256).max);
    }

    // tag::test_F6WorkLimitPrefixRollsBackBothFaces[]
    /// @notice Both partial directions stop at exactly 64 simulated steps short of the endpoint and revert atomically.
    function test_F6WorkLimitPrefixRollsBackBothFaces() public {
        assertEq(workKey.tickSpacing, 1, "real spacing-1 fixture required");
        for (uint256 leg; leg < 2; ++leg) {
            uint256 clean = vm.snapshotState();
            workTokens[1 - leg].transfer(address(workVault), 5e31);
            Observation memory before = _observeWork(leg);
            _assertTruncatedCorePrefix(abi.decode(before.state, (Shapes.Snapshot)), before.shares, leg);
            vm.expectRevert(abi.encodeWithSignature("QuoteWorkLimit()"));
            Transition(address(workVault)).quoteState(address(workTokens[leg]), address(this));
            vm.expectRevert(abi.encodeWithSignature("QuoteWorkLimit()"));
            workVault.previewExchangeIn(IERC20(address(workVault)), before.shares, workTokens[leg]);
            vm.expectRevert(abi.encodeWithSignature("QuoteWorkLimit()"));
            workVault.exchangeIn(IERC20(address(workVault)), before.shares, workTokens[leg], 0,
                address(this), false, block.timestamp);
            _assertWorkRollback(before, _observeWork(leg));
            assertTrue(vm.revertToStateAndDelete(clean));
        }
    }
    // end::test_F6WorkLimitPrefixRollsBackBothFaces[]

    function _assertTruncatedCorePrefix(Shapes.Snapshot memory q, uint256 burn_, uint256 leg_) private view {
        uint128 removed = uint128(Math.mulDiv(q.positionLiquidity, burn_, q.supply));
        uint256 amount = leg_ == 0
            ? SqrtPriceMath.getAmount1Delta(TickMath.getSqrtPriceAtTick(q.lower), q.pool.sqrtPriceX96, removed, false)
                + Math.mulDiv(q.free1 + q.fees1, burn_, q.supply)
            : SqrtPriceMath.getAmount0Delta(q.pool.sqrtPriceX96, TickMath.getSqrtPriceAtTick(q.upper), removed, false)
                + Math.mulDiv(q.free0 + q.fees0, burn_, q.supply);
        uint160 limit = leg_ == 1 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        (UniswapV4Quoter.SwapQuoteResult memory prefix,) = UniswapV4Quoter.quoteFromState(
            UniswapV4Quoter.SwapQuoteParams(workManager, workKey, leg_ == 1, amount, limit, 64), true,
            UniswapV4Quoter.LiquidityChange(q.lower, q.upper, -int128(removed)),
            UniswapV4Quoter.PoolState(q.pool.sqrtPriceX96, q.pool.tick, q.pool.liquidity - removed), true);
        assertEq(prefix.steps, 64, "actual bounded core loop reached its cap");
        assertFalse(prefix.fullyFilled);
        assertGt(prefix.amountIn, 0); assertLt(prefix.amountIn, amount);
        assertTrue(prefix.sqrtPriceAfterX96 != limit, "work exhaustion is not a terminal-price partial fill");
    }

    function _observeWork(uint256 leg_) private view returns (Observation memory f) {
        // Discovery with no holder performs no unsupported full-claim valuation.
        (f.state,) = Transition(address(workVault)).quoteState(address(workTokens[leg_]), address(0));
        Shapes.Snapshot memory q = abi.decode(f.state, (Shapes.Snapshot));
        f.shares = workVault.balanceOf(address(this)); f.allowance = workVault.allowance(address(this), address(workVault));
        for (uint256 i; i < 2; ++i) {
            f.caller[i] = workTokens[i].balanceOf(address(this));
            f.manager[i] = workTokens[i].balanceOf(address(workManager));
            f.hook[i] = workTokens[i].balanceOf(address(workKey.hooks));
            f.booked[i] = workVault.reserveOfToken(address(workTokens[i]));
            if (address(workKey.hooks) != address(0)) {
                IFullSpreadCampaignFeeLedger hook = IFullSpreadCampaignFeeLedger(address(workKey.hooks));
                f.charges[2 * i] = hook.pendingFees(workKey.toId(), address(workTokens[i]));
                f.charges[2 * i + 1] = hook.pendingCreatorTax(workKey.toId(), address(workTokens[i]));
            }
        }
        (f.growth[0], f.growth[1]) = StateLibrary.getFeeGrowthGlobals(workManager, workKey.toId());
        (, f.checkpoints[0], f.checkpoints[1]) = StateLibrary.getPositionInfo(
            workManager, workKey.toId(), address(workVault), q.lower, q.upper, bytes32(0));
    }

    function _assertWorkRollback(Observation memory before_, Observation memory after_) private view {
        // Exact ABI bytes, not a book hash: includes local/own-fee/position/pool/endpoints/supply fields.
        assertEq(after_.state, before_.state, "entire zero-holder financial snapshot restored");
        assertEq(after_.shares, before_.shares); assertEq(after_.allowance, before_.allowance);
        for (uint256 i; i < 2; ++i) {
            assertEq(after_.caller[i], before_.caller[i]); assertEq(after_.manager[i], before_.manager[i]);
            assertEq(after_.hook[i], before_.hook[i]); assertEq(after_.booked[i], before_.booked[i]);
            assertEq(after_.growth[i], before_.growth[i]); assertEq(after_.checkpoints[i], before_.checkpoints[i]);
        }
        for (uint256 i; i < 4; ++i) assertEq(after_.charges[i], before_.charges[i]);
        assertEq(workVault.reserveOfToken(address(workVault)), 0); assertEq(workVault.balanceOf(address(workVault)), 0);
        assertEq(address(workVault).balance, 0);
    }
}
// end::TestBase_FullSpreadG6WorkLimitRollback[]
