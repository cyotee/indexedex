// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValueTest as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValue.t.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultExecutionCostTest is Fixture {
    function _request(bool target0_) private view returns (Quote.Request memory q_) {
        q_.manager = manager; q_.key = key; q_.owner = address(portfolio);
        q_.target0 = target0_; q_.stepLimit = 512;
    }
    function testFuzz_singleFundedStepCostUsesActualFeeAndRounding(uint64 seed_, bool target0_) public {
        uint256 amount = bound(seed_, 1000, 1e9);
        externalLp.modify(key, -887220, 887220, 1e18, bytes32(0));
        // At q=1 a single funded exact-input step has ceil(amount*fee/1e6)
        // input fee and one input/output rounding unit. This expected formula is
        // independent of the production step-cost helper.
        uint256 expected = (amount * key.fee + 999999) / 1000000 + 2;
        assertEq(Quote.swapCost(_request(target0_), amount), expected);
    }
    function test_emptyTraversalDoesNotCreateCostAllowance() public view {
        assertEq(Quote.swapCost(_request(true), 1e9), 0);
        assertEq(Quote.swapCost(_request(false), 1e9), 0);
        assertEq(Quote.swapCost(_request(true), 0), 0);
    }
}
