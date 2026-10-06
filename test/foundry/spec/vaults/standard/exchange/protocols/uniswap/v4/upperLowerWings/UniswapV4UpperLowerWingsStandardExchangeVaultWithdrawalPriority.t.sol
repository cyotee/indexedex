// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as RebalanceFixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultWithdrawalPriorityTest[]
contract UniswapV4UpperLowerWingsStandardExchangeVaultWithdrawalPriorityTest is RebalanceFixture {
    using StateLibrary for IPoolManager;
    function testFuzz_fundedCoreWithdrawalAcrossPrices(int24 tickSeed_, uint16 fractionSeed_, bool target0_) public {
        IUniswapV4UpperLowerWingsStandardExchangeVault vault = target0_ ? wings0 : wings1;
        IERC20 target = IERC20(vault.targetToken());
        IStandardExchangeIn exchange = IStandardExchangeIn(address(vault));
        exchange.exchangeIn(target, 1e12, IERC20(address(vault)), 1e12, address(this), false, block.timestamp);
        IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance(address(vault)).rebalance(0, block.timestamp);
        int24 tick = int24(bound(tickSeed_, -12000, 12000));
        (uint160 current,,,) = pool.getSlot0(key.toId());
        uint160 destination = TickMath.getSqrtPriceAtTick(tick);
        if (destination != current) externalLp.swapTo(key, destination < current, 1e25, destination);
        uint256 shares = 1e12 * bound(fractionSeed_, 1, 10000) / 10000;
        uint256 entitled = exchange.previewExchangeIn(IERC20(address(vault)), shares, target);
        uint256 beforeBalance = target.balanceOf(address(this));
        uint256 paid = exchange.exchangeIn(IERC20(address(vault)), shares, target, entitled, address(this), false, block.timestamp);
        assertEq(paid, entitled); assertEq(target.balanceOf(address(this)) - beforeBalance, entitled);
        assertEq(IERC20(address(vault)).totalSupply(), 1e12 - shares);
        (uint256 local0, uint256 local1) = vault.localReserves();
        assertEq(token0.balanceOf(address(vault)), local0); assertEq(token1.balanceOf(address(vault)), local1);
        if (shares != 1e12) assertGe(target0_ ? local0 : local1, 1);
    }
    function test_regression_partialExitAfterMarketMove() public {
        testFuzz_fundedCoreWithdrawalAcrossPrices(5661228, 14214, false);
    }
    function test_localTargetFundsExitWithoutClosingPositions() public {
        _fund(wings0);
        (,, uint128 core,) = wings0.position(0);
        (,, uint128 upper,) = wings0.position(1);
        (,, uint128 lower,) = wings0.position(2);
        (uint256 local0,) = wings0.localReserves();
        uint256 preview = IStandardExchangeIn(address(wings0)).previewExchangeIn(IERC20(address(wings0)), 1, token0);
        assertLe(preview, local0, "stage 1 must be fundable from the sleeve");
        IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), 1, token0, preview, address(this), false, block.timestamp);
        (,, uint128 afterCore,) = wings0.position(0);
        (,, uint128 afterUpper,) = wings0.position(1);
        (,, uint128 afterLower,) = wings0.position(2);
        assertEq(afterCore, core);
        assertEq(afterUpper, upper);
        assertEq(afterLower, lower);
    }
    function test_oneSidedTargetWingClosesBeforeCore() public {
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(0);
        _fund(wings0);
        (int24 upperLower,, uint128 upper,) = wings0.position(1);
        (,, uint128 core,) = wings0.position(0);
        assertGt(upper, 0, "stage 2 requires a funded target wing");
        (uint160 price,,,) = pool.getSlot0(key.toId());
        assertLt(price, TickMath.getSqrtPriceAtTick(upperLower), "target wing must be out of range");
        (uint256 local0,) = wings0.localReserves();
        uint256 shares = _smallestSharesAbove(local0);
        IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), shares, token0, 0, address(this), false, block.timestamp);
        (,, uint128 afterUpper,) = wings0.position(1);
        (,, uint128 afterCore,) = wings0.position(0);
        assertLt(afterUpper, upper, "stage 2 must consume target-wing liquidity before replacing any residual");
        assertEq(afterCore, core, "stage 2 must not touch core");
    }
    function test_disabledInboundStillAllowsTargetExit() public {
        IStandardExchangeIn exchange = IStandardExchangeIn(address(wings0));
        exchange.exchangeIn(token0, 1e12, IERC20(address(wings0)), 1e12, address(this), false, block.timestamp);
        vm.prank(owner); indexedexManager.setVaultAddressDisabled(address(wings0), true);
        vm.expectRevert(Money.VaultDisabled.selector);
        exchange.exchangeIn(token0, 1000, IERC20(address(wings0)), 0, address(this), false, block.timestamp);
        assertGt(exchange.exchangeIn(IERC20(address(wings0)), 1e12, token0, 0, address(this), false, block.timestamp), 0);
        assertEq(IERC20(address(wings0)).totalSupply(), 0);
    }
    function _fund(IUniswapV4UpperLowerWingsStandardExchangeVault vault_) private {
        IERC20 target = IERC20(vault_.targetToken());
        IStandardExchangeIn(address(vault_)).exchangeIn(target, 1e12, IERC20(address(vault_)), 1e12, address(this), false, block.timestamp);
        IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance(address(vault_)).rebalance(0, block.timestamp);
    }
    function _smallestSharesAbove(uint256 localTarget_) private view returns (uint256 shares_) {
        IStandardExchangeIn exchange = IStandardExchangeIn(address(wings0));
        uint256 supply = IERC20(address(wings0)).totalSupply();
        uint256 low = 1;
        uint256 high = supply;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (exchange.previewExchangeIn(IERC20(address(wings0)), mid, token0) > localTarget_) high = mid;
            else low = mid + 1;
        }
        assertGt(exchange.previewExchangeIn(IERC20(address(wings0)), low, token0), localTarget_);
        return low;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultWithdrawalPriorityTest[]
