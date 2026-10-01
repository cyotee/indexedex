// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as ContextChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultUnlockContextQuoteTest is Acceptance, ContextChecks {
    function setUp() public override(Acceptance) {
        Acceptance.setUp(); _bootstrap();
        _startContext(vault, poolManager, uniswapV4StandardExchangeInQueryFacet, [unit0, unit1]);
    }
    function _contextBlocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
}
