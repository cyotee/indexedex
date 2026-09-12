"""Extend the existing shared policy test with ERC20-authorized LP transfer and redemption."""
from pathlib import Path
p=Path('test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol');s=p.read_text()
old='''            hook_.joinSingleAssetExactIn(lead_, 1 ether, collector_, 0, block.timestamp);
        }
    }
}'''
new='''            hook_.joinSingleAssetExactIn(lead_, 1 ether, collector_, 0, block.timestamp);
        }
        _assertApprovedLpTransferDoesNotGrantLiquidityPermission();
    }

    function _assertApprovedLpTransferDoesNotGrantLiquidityPermission() private {
        IERC20 lp = _lp();
        address holder = _buyer();
        address spender = makeAddr("approved external LP spender");
        uint256 shares = lp.balanceOf(holder) / 4;
        assertGt(shares, 0);
        vm.prank(holder); lp.approve(spender, shares);
        vm.prank(spender); lp.transferFrom(holder, spender, shares);
        assertEq(lp.allowance(holder, spender), 0);
        assertEq(lp.balanceOf(spender), shares);
        IUniswapV4SeBufferHook hook = _hook();
        uint256[] memory minimum = hook.previewExitProportional(shares);
        if (_policy()) {
            vm.prank(spender); vm.expectRevert();
            hook.exitProportional(shares, spender, minimum, block.timestamp);
            assertEq(lp.balanceOf(spender), shares, "LP ownership cannot override restricted removal policy");
        } else {
            address[] memory tokens = hook.tokens();
            uint256[] memory balances = new uint256[](tokens.length);
            for (uint256 i; i < tokens.length; ++i) balances[i] = IERC20(tokens[i]).balanceOf(spender);
            vm.prank(spender);
            uint256[] memory paid = hook.exitProportional(shares, spender, minimum, block.timestamp);
            assertEq(paid, minimum);
            assertEq(lp.balanceOf(spender), 0);
            for (uint256 i; i < tokens.length; ++i) assertEq(IERC20(tokens[i]).balanceOf(spender) - balances[i], paid[i]);
        }
    }
}'''
assert old in s;s=s.replace(old,new);p.write_text(s)
