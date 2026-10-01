// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {GraduationPhase} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookRegisteredLaunchTest[]
/// @notice Full real factory/curve graduation and registered P proxy, not registrar-only controls.
contract UniswapV4FullSpreadPonsFamilyHookRegisteredLaunchTest is Launch {
    using PoolIdLibrary for *;

    function test_realLaunchGraduatesOnBoundManagerAndSwapsBothDirections() public {
        assertEq(uint256(ponsV2Factory.getLaunchedToken(launchToken).phase), uint256(GraduationPhase.PoolCreated));
        assertEq(address(graduatedPoolKey.hooks), address(ponsV2MemeHook));
        (,,, uint24 lpFee) = StateLibrary.getSlot0(poolManager, graduatedPoolKey.toId());
        assertEq(lpFee, 0);
        _wrapWeth(address(this), 1 ether);
        IERC20(address(weth)).approve(address(ponsSe), type(uint256).max);
        IERC20(launchToken).approve(address(ponsSe), type(uint256).max);
        _swapLaunch(IERC20(address(weth)), IERC20(launchToken), 1e12);
        _swapLaunch(IERC20(launchToken), IERC20(address(weth)), 1e18);
        _activatePonsSe();
        assertGt(_seLiquidity(address(ponsSe)), 0);
        _assertLaunchBooked();
    }

    function test_registeredRatesRemainAfterGlobalDefaultsChange() public {
        uint256 quote = ponsSe.previewExchangeIn(IERC20(address(weth)), 1e12, IERC20(launchToken));
        vm.prank(ponsV2Owner);
        ponsV2MemeHook.setHookFeeBps(1_000);
        assertEq(ponsSe.previewExchangeIn(IERC20(address(weth)), 1e12, IERC20(launchToken)), quote);
        _wrapWeth(address(this), 1e12);
        IERC20(address(weth)).approve(address(ponsSe), 1e12);
        assertEq(ponsSe.exchangeIn(IERC20(address(weth)), 1e12, IERC20(launchToken), quote,
            address(this), false, block.timestamp), quote);
    }

    function _swapLaunch(IERC20 input_, IERC20 output_, uint256 amount_) private {
        uint256 quote = ponsSe.previewExchangeIn(input_, amount_, output_);
        uint256 beforeBalance = output_.balanceOf(address(this));
        assertEq(ponsSe.exchangeIn(input_, amount_, output_, quote, address(this), false, block.timestamp), quote);
        assertEq(output_.balanceOf(address(this)) - beforeBalance, quote);
        _assertLaunchBooked();
    }

    function _assertLaunchBooked() private view {
        assertEq(ponsSe.reserveOfToken(address(weth)), weth.balanceOf(address(ponsSe)));
        assertEq(ponsSe.reserveOfToken(launchToken), IERC20(launchToken).balanceOf(address(ponsSe)));
        assertEq(ponsSe.reserveOfToken(address(ponsSe)), ponsSe.balanceOf(address(ponsSe)));
        assertEq(address(ponsSe).balance, 0);
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookRegisteredLaunchTest[]

contract UniswapV4FullSpreadPonsFamilyHookNativeRegisteredLaunchTest is UniswapV4FullSpreadPonsFamilyHookRegisteredLaunchTest {
    function _nativeLaunch() internal pure override returns (bool) { return true; }
}
