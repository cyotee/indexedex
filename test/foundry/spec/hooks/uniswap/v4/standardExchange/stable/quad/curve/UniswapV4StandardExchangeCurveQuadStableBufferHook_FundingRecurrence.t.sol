// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {TaxedERC20Harness} from "contracts/test/stubs/TaxedERC20Harness.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @notice I4/I5/L2: raw-token liquidity inputs must arrive in full through either funding branch.
/// @dev Other catalog controls remain in the existing package adversarial suites.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_FundingRecurrence is TestBase {
    TaxedERC20Harness internal taxed;
    address[4] internal fundingTokens;

    function setUp() public override {
        super.setUp();
        taxed = new TaxedERC20Harness("Funding token", "FUND", 18, 0);
        address[4] memory tokens = [address(token0), address(taxed), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (tokens[j] < tokens[i]) {
                    (tokens[i], tokens[j]) = (tokens[j], tokens[i]);
                    (ses[i], ses[j]) = (ses[j], ses[i]);
                }
            }
        }
        fundingTokens = tokens;
        address[4] memory rps;
        _deployHookWithArgs(_pkgArgs(tokens, ses, rps, DEFAULT_BASE_AMP));
        taxed.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        for (uint256 i; i < 4; ++i) IERC20(tokens[i]).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function test_L2_FoT_forbidden_directLiquidity() public { _rejectShortReceipt(false); }
    function test_L2_FoT_forbidden_permit2Liquidity() public { _rejectShortReceipt(true); }

    function _rejectShortReceipt(bool throughPermit2) private {
        if (throughPermit2) {
            vm.startPrank(user);
            taxed.approve(hook, 0);
            taxed.approve(PERMIT2_ADDR, type(uint256).max);
            IAllowanceTransfer(PERMIT2_ADDR).approve(address(taxed), hook, type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 100 ether;
        uint256 snapshot = vm.snapshotState();
        (uint256 quoted,) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, quoted, block.timestamp);
        assertGt(shares, 0);
        assertEq(shares, quoted, "untaxed funded control");
        assertEq(taxed.balanceOf(hook), 100 ether);
        assertTrue(vm.revertToState(snapshot));
        taxed.setTaxBps(1000);
        uint256 payerBefore = taxed.balanceOf(user);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100 ether, 90 ether));
        vm.prank(user);
        quad.joinProportional(amounts, user, quoted, block.timestamp);
        assertEq(taxed.balanceOf(user), payerBefore);
        assertEq(IERC20(hook).totalSupply(), 0);
        for (uint256 i; i < 4; ++i) {
            assertEq(IERC20(fundingTokens[i]).balanceOf(hook), 0, "all funding rolls back");
            assertEq(quad.nativeReserve(i), 0, "no unbacked reserve");
        }
    }
}
