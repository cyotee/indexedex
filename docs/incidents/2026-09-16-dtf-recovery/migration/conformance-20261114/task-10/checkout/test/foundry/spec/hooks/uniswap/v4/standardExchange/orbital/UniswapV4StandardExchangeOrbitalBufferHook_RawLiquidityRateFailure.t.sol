// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";

/// @dev Non-SUT provider. Modes characterize fail-closed exits. Not a recovery route.
contract ModeRate {
    uint256 public rate;
    uint8 public mode;

    constructor(uint256 rate_) {
        rate = rate_;
    }

    function setMode(uint8 mode_) external {
        mode = mode_;
    }

    function getRate() external view returns (uint256) {
        if (mode == 1) revert("rate fail");
        if (mode == 2) return 0;
        if (mode == 3) {
            assembly {
                return(0, 0)
            }
        }
        return rate;
    }
}

/// @notice Raw payout does not make the exit survive a provider outage. OD-2 stays deferred.
contract UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityRateFailureTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    ModeRate internal rp;

    function _defaultPkgArgs()
        internal
        override
        returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args)
    {
        args = super._defaultPkgArgs();
        if (address(rp) == address(0)) rp = new ModeRate(1e18);
        args.rp0 = address(rp);
    }

    function test_exit_feesOff_providerRevert_rollsBack() public {
        _setUsageFee(0);
        _assertExitRollsBack(1);
    }

    function test_exit_feesOn_providerRevert_rollsBack() public {
        _setUsageFee(0.05e18);
        _assertExitRollsBack(1);
    }

    function test_exit_feesOff_zeroRate_rollsBack() public {
        _setUsageFee(0);
        _assertExitRollsBack(2);
    }

    function test_exit_feesOff_shortReturn_rollsBack() public {
        _setUsageFee(0);
        _assertExitRollsBack(3);
    }

    function _assertExitRollsBack(uint8 mode_) internal {
        uint256 shares = _seedThreeLeg(100 ether);
        uint256 half = shares / 2;
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 t1Before = token1.balanceOf(user);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        rp.setMode(mode_);
        vm.prank(user);
        vm.expectRevert(ClaimLib.RateProviderFailed.selector);
        orbital.removeLiquidity(half, user, 0, 0, 0, block.timestamp + 1 hours);
        assertEq(IERC20(hook).balanceOf(user), lpBefore, "lp rolled back");
        assertEq(token1.balanceOf(user), t1Before, "token rolled back");
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "supply rolled back");
        assertEq(orbital.rawReserve(1), 100 ether, "raw book rolled back");
    }
}
