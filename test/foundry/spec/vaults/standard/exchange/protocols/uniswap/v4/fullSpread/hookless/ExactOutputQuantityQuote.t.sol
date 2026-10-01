// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadExactOutputQuantity as QuantityChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadExactOutputQuantity.sol";
contract UniswapV4FullSpreadHooklessStandardExchangeVaultExactOutputQuantityQuoteTest is Acceptance, QuantityChecks {
    function setUp() public override(Acceptance) {
        Acceptance.setUp(); _bootstrap();
        _startQuantity(vault, address(poolManager), [unit0, unit1]);
    }
    function _quantityBlocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
}
