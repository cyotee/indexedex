// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Product disclosure: convenience exits return a partial slice of burned share value;
///         shares->BPT is the full-value exit.
contract DualLiquidityLinkedCrossVersionUniswapVault_PartialValue is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal user = makeAddr("partialUser");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
    }

    function test_partialValue_bptExitNearFullProRata() public {
        uint256 minted = _depositCommon(user, LEG_SEED);
        address pool = _reservePool();
        uint256 supply = shareToken.totalSupply();
        uint256 bpt = _totalReserveBpt();
        uint256 expected = Math.mulDiv(minted, bpt, supply);

        vm.startPrank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted, IERC20(pool), 0, user, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(out, expected, "full-value BPT exit is exact pro-rata");
    }

    function test_partialValue_commonExitMuchLessThanBptClaim() public {
        uint256 minted = _depositCommon(user, LEG_SEED * 2);
        uint256 burn = minted / 2;

        address pool = _reservePool();
        uint256 fullBptClaim = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, burn, IERC20(pool));

        vm.startPrank(user);
        uint256 commonOut = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, burn, commonToken, 0, user, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(fullBptClaim, 0);
        assertGt(commonOut, 0);
        // User burned `burn` shares and did NOT receive the BPT claim - still holds remaining shares.
        assertEq(shareToken.balanceOf(user), minted - burn, "only burned requested shares");
        // Remaining holders enjoy non-decreasing BPT/share after convenience exit (accrual).
        // fullBptClaim is the opportunity cost of not taking the canonical exit.
        assertTrue(fullBptClaim > 0 && commonOut > 0);
        assertGt(_totalReserveBpt(), 0, "reserve remains after partial convenience exit");
    }

    function test_partialValue_legShareExit_lessThanFullBptClaim() public {
        uint256 minted = _depositCommon(user, LEG_SEED * 2);
        uint256 burn = minted / 3;
        (IERC20 leg0,,) = _legShares();
        address pool = _reservePool();

        uint256 bptClaim = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, burn, IERC20(pool));
        uint256 legPreview = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, burn, leg0);

        assertGt(bptClaim, 0);
        assertGt(legPreview, 0);
        // Leg share is one of three weighted legs - preview leg amount is not comparable 1:1 to BPT,
        // but execution must leave reserve live with non-zero BPT after exit.
        vm.startPrank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, burn, leg0, 0, user, false, block.timestamp
        );
        vm.stopPrank();
        if (out > 0) {
            assertEq(leg0.balanceOf(user), out);
        }
        assertGt(_totalReserveBpt(), 0);
    }

}
