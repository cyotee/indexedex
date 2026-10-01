// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {TestBase_FullSpreadRegistryMaintenanceObservation} from "contracts/test/bases/TestBase_FullSpreadRegistryMaintenanceObservation.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

/// @notice Genuine launch/graduation, registered P proxy, actual public maintenance and independent observations.
// tag::PonsFamilyRegistryMaintenanceObservationTest[]
contract PonsFamilyRegistryMaintenanceObservationTest is
    TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch,
    TestBase_FullSpreadRegistryMaintenanceObservation
{
    using PoolIdLibrary for PoolKey;

    function setUp() public override {
        super.setUp();
        // Real WETH wrapping from existing fixture ETH; actual launch tokens were bought on the curve.
        weth.deposit{value: 1 ether}();
        IERC20[2] memory tokens = _registryTokens();
        (uint160 price,,,) = StateLibrary.getSlot0(poolManager, graduatedPoolKey.toId());
        (int24 lo, int24 hi) = _registryBounds();
        uint256 budget0 = address(tokens[0]) == address(weth) ? 1e15 : 1e30;
        uint256 budget1 = address(tokens[1]) == address(weth) ? 1e15 : 1e30;
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(price, TickMath.getSqrtPriceAtTick(lo),
            TickMath.getSqrtPriceAtTick(hi), budget0, budget1);
        uint256[2] memory funding = _registryPrincipal(price, liquidity, true);
        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            assets[i] = address(tokens[i]); amounts[i] = funding[i];
            assertGe(tokens[i].balanceOf(address(this)), funding[i]);
            tokens[i].approve(address(ponsSe), funding[i]);
        }
        assertGt(IStandardExchangeInMulti(address(ponsSe)).exchangeInManyToOne(assets, amounts,
            IERC20(address(ponsSe)), 0, address(this), false, block.timestamp), 0);
        for (uint256 i; i < 2; ++i) tokens[i].approve(address(ponsSe), 0);
    }
    function _registrySubject() internal view override returns (address) { return address(ponsSe); }
    function _registryManager() internal view override returns (IPoolManager) { return poolManager; }
    function _registryKey() internal view override returns (PoolKey memory) { return graduatedPoolKey; }
    function _registryPermit2() internal view override returns (address) { return address(permit2); }
    function _registryExtraAllowances() internal view override {
        IERC20[2] memory tokens = _registryTokens();
        for (uint256 i; i < 2; ++i) {
            assertEq(tokens[i].allowance(address(ponsSe), address(ponsPositionManager)), 0);
            assertEq(tokens[i].allowance(address(ponsSe), address(ponsV2MemeHook)), 0);
        }
    }
}
// end::PonsFamilyRegistryMaintenanceObservationTest[]
