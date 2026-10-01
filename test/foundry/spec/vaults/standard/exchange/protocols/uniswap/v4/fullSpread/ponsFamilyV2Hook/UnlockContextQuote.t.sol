// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as LaunchBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as ContextChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

contract UniswapV4FullSpreadPonsFamilyHookUnlockContextQuoteTest is Launch, ContextChecks {
    using PoolIdLibrary for *;
    function setUp() public override(LaunchBase) {
        LaunchBase.setUp(); _activatePonsSe(); _wrapWeth(address(this), 1 ether);
        bool token0IsLaunch = Currency.unwrap(graduatedPoolKey.currency0) == launchToken;
        _startContext(ponsSe, poolManager, uniswapV4StandardExchangeInQueryFacet,
            [token0IsLaunch ? uint256(1e16) : uint256(1e10), token0IsLaunch ? uint256(1e10) : uint256(1e16)]);
    }
    function _contextBlocked(bytes memory data_) internal override returns (bytes memory) { return _launchBlocked(data_); }
    function _contextOtherManager() internal view override returns (address) { return address(ponsHook); }
    function _contextFeesHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(
            ponsHook.pendingFees(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency0)),
            ponsHook.pendingFees(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency1)),
            ponsHook.pendingCreatorTax(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency0)),
            ponsHook.pendingCreatorTax(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency1))));
    }
}
