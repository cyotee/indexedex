// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadBlockedYield as YieldChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadBlockedYield.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultBlockedYieldEquivalenceTest is Acceptance, YieldChecks {
    function setUp() public override(Acceptance) {
        Acceptance.setUp(); _bootstrap();
        _startYield(vault, [unit0 / 1_000, unit1 / 1_000]);
    }
    function _yieldBlocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
    function test_blockedSYDepositBothDirections() public { _yieldEquivalence(0); }
    function test_blockedSYExternalRedeemBothDirections() public { _yieldEquivalence(1); }
    function test_blockedSYInternalRedeemRetainsSurplusBothDirections() public { _yieldEquivalence(2); }
    function test_blockedSYExternalShortageRollsBack() public { _yieldCoverRollback(false); }
    function test_blockedSYInternalShortageRollsBackAndClearsContext() public { _yieldCoverRollback(true); }
}

contract UniswapV4FullSpreadHooklessStandardExchangeVaultNativeBlockedYieldEquivalenceTest
    is UniswapV4FullSpreadHooklessStandardExchangeVaultBlockedYieldEquivalenceTest
{
    function _native() internal pure override returns (bool) { return true; }
}
