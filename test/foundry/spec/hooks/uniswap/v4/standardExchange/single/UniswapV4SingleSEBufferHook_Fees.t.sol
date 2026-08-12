// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

/// @notice SE dilution usage fee; no hook fee.
/// @dev ERC-4626 SE mints fee shares to feeTo (user still receives full preview shares).
contract UniswapV4SingleSEBufferHook_Fees_Test is TestBase {
    function setUp() public override {
        super.setUp();
        _initPool();
    }

    function test_HS7_wrapWithUsageFee_previewEqualsExec_feeToMints_noHookFee() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        require(feeTo != address(0), "feeTo");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.01e18);

        uint256 amountIn = 10 ether;
        uint256 preview = buffer.previewWrap(amountIn);
        assertGt(preview, 0, "preview");

        bool zfo = _isWrapZFO();
        uint256 feeBefore = IERC20(se).balanceOf(feeTo);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 hookPairBefore = pairToken.balanceOf(hook);
        uint256 hookSeBefore = IERC20(se).balanceOf(hook);

        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        // User receives full SE preview (dilution fee expands supply to feeTo)
        assertEq(IERC20(se).balanceOf(user) - seBefore, preview, "user gets preview");
        assertEq(IERC20(se).balanceOf(feeTo) - feeBefore, preview / 100, "SE fee to feeTo");
        // Hook retains no fee inventory
        assertEq(pairToken.balanceOf(hook), hookPairBefore, "no hook pair fee");
        assertEq(IERC20(se).balanceOf(hook), hookSeBefore, "no hook SE fee");
    }
}
