// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4WeightedSwapHook_Decimals
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook_Decimals.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";

/**
 * @title UniswapV4WeightedSwapHook_Math_Decimals
 * @notice FIX-S1 extended with `baseScaleFromDecimals(9)`. InvalidDecimals 5 and 19 stay;
 *         9-dec deploy succeeds.
 */
contract UniswapV4WeightedSwapHook_Math_Decimals is TestBase_UniswapV4WeightedSwapHook_Decimals {
    function test_FIX_S1_scaleDescalemixedDecimals() public pure {
        uint256 scale6 = Math.baseScaleFromDecimals(6);
        uint256 scale8 = Math.baseScaleFromDecimals(8);
        uint256 scale9 = Math.baseScaleFromDecimals(9);
        uint256 scale18 = Math.baseScaleFromDecimals(18);
        assertEq(Math.scaleTo(1e6, scale6), 1e18);
        assertEq(Math.scaleTo(1e8, scale8), 1e18);
        assertEq(Math.scaleTo(1e9, scale9), 1e18);
        assertEq(Math.scaleTo(1e18, scale18), 1e18);
        assertEq(Math.descale(1e18, scale6), 1e6);
        assertEq(Math.descale(1e18, scale9), 1e9);
        assertEq(Math.descale(1e18, scale18), 1e18);
        assertEq(Math.scaleToUp(1, scale18), 1);
        assertGe(Math.descaleUp(1, scale6), Math.descale(1, scale6));
    }

    function test_baseScaleFromDecimals_5_reverts() public {
        vm.expectRevert(Math.MathDomain.selector);
        this.baseScale5();
    }

    function test_baseScaleFromDecimals_19_reverts() public {
        vm.expectRevert(Math.MathDomain.selector);
        this.baseScale19();
    }

    function baseScale5() external pure returns (uint256) {
        return Math.baseScaleFromDecimals(5);
    }

    function baseScale19() external pure returns (uint256) {
        return Math.baseScaleFromDecimals(19);
    }

    function test_deploy_9dec_succeeds() public {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", 9);
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", 18);
        (MintableERC20Decimals t0, MintableERC20Decimals t1) = _sortTwo(a, b);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        (address hook_,) = _mineAndDeploy(tokens, weights, providers);
        assertTrue(hook_ != address(0));
        _fundAndApproveDec(hook_, tokens);
        uint256 shares = _joinFullN2(hook_, t0, t1, 100);
        assertGt(shares, 0);
    }

    function test_deploy_5dec_reverts() public {
        _expectInvalidDecimalsDeploy(5);
    }

    function test_deploy_19dec_reverts() public {
        _expectInvalidDecimalsDeploy(19);
    }

    function _expectInvalidDecimalsDeploy(uint8 badDec) internal {
        vm.expectRevert();
        this.deployAndJoinBadDecimals(badDec);
    }

    function deployAndJoinBadDecimals(uint8 badDec) external {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", badDec);
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", 18);
        (MintableERC20Decimals t0, MintableERC20Decimals t1) = _sortTwo(a, b);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        (address hook_,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApproveDec(hook_, tokens);
        _joinFullN2(hook_, t0, t1, 100);
    }
}
