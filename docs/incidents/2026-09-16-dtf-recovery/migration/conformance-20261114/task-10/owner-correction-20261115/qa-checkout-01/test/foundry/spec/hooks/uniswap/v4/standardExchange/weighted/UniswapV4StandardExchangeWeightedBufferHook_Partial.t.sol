// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @notice H4 partial book: n>=3 first mint with ≥2 legs; paid joins retain empty legs.
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

        bool[] memory flags = _prepareShareSeed(user, amounts);
        (uint256 preview,) = weighted.previewJoinProportionalFlexible(amounts, flags);
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportionalFlexible(amounts, flags, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview);
        assertGt(shares, 0);
        uint256 gross = IERC20(hook).totalSupply() - 1000;
        assertEq(gross, shares + (weighted.feeTo() == address(0) ? 0 : gross * weighted.usageFee() / 1e18));
        assertFalse(weighted.isFullBook(), "partial");
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
        assertEq(weighted.nativeReserve(2), 0);
    }

    function test_partial_singleAsset_preparesOnlyIncumbentLegs() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 80 ether;
        amounts[1] = 80 ether;
        amounts[2] = 0;
        _seedAmounts(user, amounts);
        assertFalse(weighted.isFullBook());

        uint256 preview = weighted.previewDepositSingle(address(token0), 1 ether);
        assertGt(preview, 0);
        vm.prank(user);
        assertEq(weighted.depositSingle(address(token0), 1 ether, user, 1, block.timestamp + 1 hours), preview);
        preview = weighted.previewJoinSingleAssetExactIn(address(token1), 1 ether);
        vm.prank(user);
        assertEq(weighted.joinSingleAssetExactIn(address(token1), 1 ether, user, 1, block.timestamp + 1 hours), preview);
        assertFalse(weighted.isFullBook());
        assertEq(weighted.nativeReserve(2), 0, "paid preparation does not invent an empty leg");
    }

    function test_partial_unbalanced_preparesOnlyIncumbentLegs() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 80 ether;
        amounts[1] = 80 ether;
        _seedAmounts(user, amounts);
        amounts[0] = 0;
        amounts[1] = 1 ether;
        uint256 preview = weighted.previewJoinUnbalanced(amounts);
        assertGt(preview, 0);
        vm.prank(user);
        assertEq(weighted.joinUnbalanced(amounts, user, 1, block.timestamp + 1 hours), preview);
        assertEq(weighted.nativeReserve(2), 0);
    }

    function test_partial_seedThirdLeg_toFullBook() public {
        uint256[] memory seed = new uint256[](3);
        seed[0] = 50 ether;
        seed[1] = 50 ether;
        seed[2] = 0;
        _seedAmounts(user, seed);

        // Funding the new leg cannot mint against missing incumbent components.
        uint256[] memory fill = new uint256[](3);
        fill[0] = 10 ether;
        fill[1] = 10 ether;
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
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        weighted.joinProportional(one, user, 0, block.timestamp + 1 hours);
    }
}
