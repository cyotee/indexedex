// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as HooklessReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as PonsReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";

/// @notice Renaming a family must not create a new usage-fee or sleeve-default domain.
contract FullSpreadConsumerPolicyTest is Test {
    function test_liquidReserveUsageIdPreservesHistoricalSelectorSet() public pure {
        // Historical seven-selector policy, independent of either new interface declaration.
        // Do not import a retired interface solely to recover its ERC-165 value.
        bytes4 expected = bytes4(keccak256("canOpenPoolManagerUnlock()"))
            ^ bytes4(keccak256("localReserve(address)"))
            ^ bytes4(keccak256("deployedReserve()"))
            ^ bytes4(keccak256("targetLiquidReservePercentage()"))
            ^ bytes4(keccak256("actualLiquidReservePercentage(address)"))
            ^ bytes4(keccak256("rebalanceLiquidReserve()"))
            ^ bytes4(keccak256("twapOracle()"));
        assertEq(type(HooklessReserve).interfaceId, expected);
        assertEq(type(PonsReserve).interfaceId, expected);
    }
}
