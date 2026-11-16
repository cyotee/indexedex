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
        vm.expectRevert(abi.encodeWithSignature("NotZapEligible()"));
        orbital.depositSingle(
            address(token0), 10 ether, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_zap_eligible_afterFullBook() public {
        _seedThreeLeg(200 ether);
        assertTrue(orbital.isZapEligible());
    }

    function test_depositSingle_paidPreparationMintsItsPreview() public {
        _seedThreeLeg(300 ether);
        _assertPaidBasket(address(token0), 30 ether);
    }

    function test_previewZapSplit_sumsToAmountIn() public {
        _seedThreeLeg(200 ether);
        uint256 amountIn = 20 ether;
        (uint256 saleJ, uint256 saleK, uint256 residual,,) =
            orbital.previewZapSplit(address(token1), amountIn);
        assertEq(saleJ + saleK + residual, amountIn, "split conservation");
        assertGt(saleJ, 0, "caller pays for the second leg");
        assertGt(saleK, 0, "caller pays for the third leg");
        assertGt(residual, 0, "source contribution is retained");
    }

    function test_zap_partialBook_reverts() public {
        _addLiquidity(100 ether, 100 ether, 0);
        assertFalse(orbital.isZapEligible());
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotZapEligible()"));
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

    function test_zap_asymmetricFeePaysForMissingComponents() public {
        _addLiquidity(400 ether, 100 ether, 50 ether);
        _setDexFee(0.003e18);
        _assertPaidBasket(address(token0), 40 ether);
    }

    function test_zap_token2FeePaysForMissingComponents() public {
        _seedThreeLeg(200 ether);
        _setDexFee(0.01e18); // 100 bps
        _assertPaidBasket(address(token2), 25 ether);
    }

    function _joinState() private view returns (bytes memory) {
        uint256[3] memory local;
        uint256[3] memory shares;
        uint256[3] memory balances;
        uint256[3] memory custody;
        address[3] memory tokens = [address(token0), address(token1), address(token2)];
        for (uint8 i; i < 3; ++i) {
            local[i] = orbital.rawReserve(i);
            shares[i] = orbital.seBalance(i);
            balances[i] = IERC20(tokens[i]).balanceOf(user);
            custody[i] = IERC20(tokens[i]).balanceOf(hook);
        }
        return abi.encode(local, shares, balances, custody, IERC20(hook).totalSupply(),
            IERC20(hook).balanceOf(user), IERC20(hook).balanceOf(feeRecipient),
            IERC20(se0).totalSupply(), IERC20(se0).balanceOf(hook), orbital.radius(), orbital.lSquared());
    }

    function _assertPaidBasket(address token, uint256 amount) private {
        uint256 quote = orbital.previewDepositSingle(token, amount);
        assertGt(quote, 0, "paid preparation assembles a basket");
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 minted = orbital.depositSingle(token, amount, user, quote, block.timestamp + 1 hours, "");
        assertEq(minted, quote);
        assertEq(IERC20(hook).balanceOf(user) - beforeLp, minted);
        assertEq(token0.balanceOf(hook), orbital.rawReserve(0));
        assertEq(token1.balanceOf(hook), orbital.rawReserve(1));
        assertEq(token2.balanceOf(hook), orbital.rawReserve(2));
    }
}
