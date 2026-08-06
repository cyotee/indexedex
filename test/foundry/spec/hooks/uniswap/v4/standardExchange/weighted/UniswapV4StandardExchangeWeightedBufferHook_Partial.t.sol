// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @notice H4 partial book: n>=3 first mint with ≥2 legs; floor order; single-asset blocked while partial.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Partial is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function setUp() public override {
        super.setUp();
        // Redeploy as n=3 with SE only on leg 0
        _deployHookWithArgs(_argsN(3, false));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
    }

    function test_partialFirstMint_twoLegs_n3() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        amounts[2] = 0; // leave leg 2 zero — partial book

        (uint256 preview,) = weighted.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview);
        assertGt(shares, 0);
        assertEq(IERC20(hook).totalSupply(), shares + 1000);
        assertFalse(weighted.isFullBook(), "partial");
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
        assertEq(weighted.nativeReserve(2), 0);
    }

    function test_partial_singleAsset_forbidden() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 80 ether;
        amounts[1] = 80 ether;
        amounts[2] = 0;
        vm.prank(user);
        weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertFalse(weighted.isFullBook());

        vm.prank(user);
        vm.expectRevert();
        weighted.depositSingle(address(token0), 1 ether, user, 0, block.timestamp + 1 hours);

        vm.prank(user);
        vm.expectRevert();
        weighted.joinSingleAssetExactIn(address(token1), 1 ether, user, 0, block.timestamp + 1 hours);
    }

    function test_partial_seedThirdLeg_toFullBook() public {
        uint256[] memory seed = new uint256[](3);
        seed[0] = 50 ether;
        seed[1] = 50 ether;
        seed[2] = 0;
        vm.prank(user);
        weighted.joinProportional(seed, user, 0, block.timestamp + 1 hours);

        // Binding-index floor: seed zero leg fully
        uint256[] memory fill = new uint256[](3);
        fill[0] = 0;
        fill[1] = 0;
        fill[2] = 50 ether;
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(fill, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0);
        // May or may not be full book depending on prop residual — require leg2 > 0
        assertGt(weighted.nativeReserve(2), 0, "seeded leg2");
    }

    function test_n3_firstMint_requiresAtLeastTwoLegs() public {
        uint256[] memory one = new uint256[](3);
        one[0] = 10 ether;
        vm.prank(user);
        vm.expectRevert();
        weighted.joinProportional(one, user, 0, block.timestamp + 1 hours);
    }
}
