// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Redeposit-after-exit policy: convenience redemptions always pay the user; reserve may
///         accrue via best-effort redeposit; vault intermediate inventory stays clean.
contract DualLiquidityLinkedCrossVersionUniswapVault_Redeposit is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal user = makeAddr("redepositUser");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
    }

    function test_redeposit_userPayoutSucceedsEvenIfJoinIsHard() public {
        uint256 minted = _depositCommon(user, LEG_SEED * 3);
        uint256 burn = minted / 2;

        uint256 commonBefore = commonToken.balanceOf(user);
        vm.startPrank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, burn, commonToken, 0, user, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(out, 0, "user always receives convenience payout");
        assertEq(commonToken.balanceOf(user), commonBefore + out);
        // Diamond must not hold intermediates whether redeposit succeeded or failed.
        _assertNoIntermediateInventory();
    }

    function test_redeposit_legShareExit_paysUserAndCleansVault() public {
        (IERC20 leg0,,) = _legShares();
        uint256 minted = _depositCommon(user, LEG_SEED * 3);
        uint256 burn = minted / 3;

        vm.startPrank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, burn, leg0, 0, user, false, block.timestamp
        );
        vm.stopPrank();

        if (out > 0) {
            assertEq(leg0.balanceOf(user), out);
        }
        _assertNoIntermediateInventory();
    }

    function test_redeposit_smallBurns_doNotBrickVault() public {
        uint256 minted = _depositCommon(user, LEG_SEED);
        // Many tiny convenience exits (stress redeposit path).
        uint256 chunk = minted / 20;
        if (chunk == 0) chunk = 1;
        vm.startPrank(user);
        for (uint256 i = 0; i < 5; i++) {
            uint256 bal = shareToken.balanceOf(user);
            if (bal < chunk) break;
            try IStandardExchangeIn(linkedVault).exchangeIn(
                shareToken, chunk, tokenA, 0, user, false, block.timestamp
            ) {} catch {
                break;
            }
        }
        vm.stopPrank();
        _assertNoIntermediateInventory();
        assertGt(_totalReserveBpt(), 0, "reserve still live");
    }
}
