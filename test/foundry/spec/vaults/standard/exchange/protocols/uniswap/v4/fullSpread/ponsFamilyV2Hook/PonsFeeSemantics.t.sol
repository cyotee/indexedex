// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4FullSpreadPonsFamilyHookCoreSettlementTest as Core} from "./CoreSettlement.t.sol";
import {UniswapV4FullSpreadPonsFamilyHookQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookQuoteService.sol";
import {UniswapV4FullSpreadPonsFamilyHookFeeService as Fees} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookFeeService.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookFeeSemanticsTest[]
contract UniswapV4FullSpreadPonsFamilyHookFeeSemanticsTest is Core {
    using PoolIdLibrary for *;
    using BalanceDeltaLibrary for BalanceDelta;

    function test_fiftyAtTwoHundredBasisPointTermsKeepsSeparateFloors() public pure {
        assertEq(Fees._charge(50, 100, 100), 0);
        assertEq(50 * uint256(200) / 10_000, 1);
    }

    function test_exactInputTaxesOutputAndExactOutputTaxesInputBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            for (uint256 mode; mode < 2; ++mode) {
                uint256 snapshot = vm.snapshotState();
                bool zeroForOne = direction == 0;
                bool exactInput = mode == 0;
                Quotes.Params memory params = _params(zeroForOne, 1e18);
                Types.Swap memory quote = exactInput ? Quotes._forward(params) : Quotes._exactOutput(params);
                BalanceDelta delta = _swap(zeroForOne, exactInput ? -int256(params.amount) : int256(params.amount));
                _assertSwap(quote, delta);
                address charged = Currency.unwrap(exactInput
                    ? (zeroForOne ? key.currency1 : key.currency0) : (zeroForOne ? key.currency0 : key.currency1));
                uint256 fee = ponsHook.pendingFees(key.toId(), charged);
                uint256 tax = ponsHook.pendingCreatorTax(key.toId(), charged);
                uint256 coreUnspecified = exactInput ? quote.amountOut + fee + tax : quote.amountIn - fee - tax;
                assertEq(fee, coreUnspecified * 100 / 10_000);
                assertEq(tax, coreUnspecified * 100 / 10_000);
                assertEq(quote.feeGrowthInsideX128, 0, "hook charge is not LP growth");
                assertTrue(vm.revertToStateAndDelete(snapshot));
            }
        }
    }

    function test_defaultsRecipientsAndBuybackCannotAlterRegisteredSwapperCharge() public {
        Types.Swap memory beforeQuote = Quotes._forward(_params(true, 1e18));
        Types.Swap memory beforeOut = Quotes._exactOutput(_params(false, 1e18));
        ponsHook.setHookFeeBps(1_000);
        ponsHook.setProtocolFeeRecipient(address(0x123));
        ponsHook.setProtocolFeeShareBps(5_000);
        ponsHook.setBuybackBurnBps(8_000);
        ponsHook.setCreatorFeeRecipient(key.toId(), address(0x456));
        ponsHook.setBuybackEnabled(key.toId(), true);
        assertEq(keccak256(abi.encode(Quotes._forward(_params(true, 1e18)))), keccak256(abi.encode(beforeQuote)));
        assertEq(keccak256(abi.encode(Quotes._exactOutput(_params(false, 1e18)))), keccak256(abi.encode(beforeOut)));
        _assertSwap(beforeQuote, _swap(true, -int256(1e18)));
    }

    function test_actualCoreOutputFiftyChargesZeroRatherThanOne() public {
        bool found;
        // Independent test-side finite enumeration locates a gross core output of 50.
        // There is no search in the production exact-output implementation.
        for (uint256 amount = 45; amount <= 55; ++amount) {
            Types.Swap memory quote = Quotes._forward(_params(true, amount));
            if (quote.amountOut != 50) continue;
            _assertSwap(quote, _swap(true, -int256(amount)));
            assertEq(ponsHook.pendingFees(key.toId(), Currency.unwrap(key.currency1)), 0);
            assertEq(ponsHook.pendingCreatorTax(key.toId(), Currency.unwrap(key.currency1)), 0);
            found = true;
            break;
        }
        assertTrue(found);
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookFeeSemanticsTest[]
