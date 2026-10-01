// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as LaunchBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {TestBase_UniswapV4FullSpreadExactOutputQuantity as QuantityChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadExactOutputQuantity.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
contract UniswapV4FullSpreadPonsFamilyHookExactOutputQuantityQuoteTest is Launch, QuantityChecks {
    function setUp() public override(LaunchBase) {
        LaunchBase.setUp(); _activatePonsSe(); _wrapWeth(address(this), 1 ether);
        bool launch0 = Currency.unwrap(graduatedPoolKey.currency0) == launchToken;
        _startQuantity(ponsSe, address(poolManager), [launch0 ? uint256(1e16) : uint256(1e10), launch0 ? uint256(1e10) : uint256(1e16)]);
    }
    function _quantityBlocked(bytes memory data_) internal override returns (bytes memory) { return _launchBlocked(data_); }
}
