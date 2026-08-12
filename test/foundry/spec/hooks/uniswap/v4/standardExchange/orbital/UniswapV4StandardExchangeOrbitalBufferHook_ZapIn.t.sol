// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_ZapInTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_zap_notEligible_beforeLive() public {
        assertFalse(orbital.isZapEligible());
        vm.prank(user);
        vm.expectRevert();
        orbital.depositSingle(
            address(token0), 10 ether, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_zap_eligible_afterFullBook() public {
        _seedThreeLeg(200 ether);
        assertTrue(orbital.isZapEligible());
    }

    function test_depositSingle_previewEqualsExec() public {
        _seedThreeLeg(300 ether);
        uint256 amountIn = 30 ether;
        uint256 preview = orbital.previewDepositSingle(address(token0), amountIn);
        assertGt(preview, 0, "preview shares");
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 shares = orbital.depositSingle(
            address(token0), amountIn, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, preview, "preview==exec zap");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, shares);
    }

    function test_previewZapSplit_sumsToAmountIn() public {
        _seedThreeLeg(200 ether);
        uint256 amountIn = 20 ether;
        (uint256 saleJ, uint256 saleK, uint256 residual,,) =
            orbital.previewZapSplit(address(token1), amountIn);
        assertEq(saleJ + saleK + residual, amountIn, "split conservation");
        assertGt(saleJ, 0);
        assertGt(saleK, 0);
        assertGt(residual, 0);
    }

    function test_zap_partialBook_reverts() public {
        _addLiquidity(100 ether, 100 ether, 0);
        assertFalse(orbital.isZapEligible());
        vm.prank(user);
        vm.expectRevert();
        orbital.depositSingle(
            address(token0), 10 ether, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_no_withdrawSingle_on_product_surface() public {
        // Diamond has no withdrawSingle selector — call must fail (not a working zap-out).
        (bool ok, bytes memory ret) = hook.call(
            abi.encodeWithSignature(
                "withdrawSingle(uint256,address,address,uint256,uint256)",
                uint256(1),
                address(token0),
                user,
                uint256(0),
                block.timestamp + 1
            )
        );
        assertFalse(ok, "withdrawSingle must not succeed");
        // Also assert production source has no withdrawSingle (static structural via selector miss)
        assertTrue(ret.length > 0 || !ok, "call rejected");
    }

    function test_zap_asymmetric_fee_preview_eq_exec() public {
        // Asymmetric book so min-ratio is sensitive to second-leg out + trading residual.
        _addLiquidity(400 ether, 100 ether, 50 ether);
        _setDexFee(0.003e18);
        uint256 amountIn = 40 ether;
        uint256 preview = orbital.previewDepositSingle(address(token0), amountIn);
        vm.prank(user);
        uint256 shares = orbital.depositSingle(
            address(token0), amountIn, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, preview, "asymmetric+fee preview==exec");
    }

    function test_zap_token2_in_fee_preview_eq_exec() public {
        _seedThreeLeg(200 ether);
        _setDexFee(0.01e18); // 100 bps
        uint256 amountIn = 25 ether;
        uint256 preview = orbital.previewDepositSingle(address(token2), amountIn);
        vm.prank(user);
        uint256 shares = orbital.depositSingle(
            address(token2), amountIn, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, preview, "token2 in + fee preview==exec");
    }
}
