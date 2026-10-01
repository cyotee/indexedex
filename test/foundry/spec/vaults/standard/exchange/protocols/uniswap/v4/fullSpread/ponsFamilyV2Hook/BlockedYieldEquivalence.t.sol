// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as LaunchBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {TestBase_UniswapV4FullSpreadBlockedYield as YieldChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadBlockedYield.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

contract UniswapV4FullSpreadPonsFamilyHookBlockedYieldEquivalenceTest is Launch, YieldChecks {
    using PoolIdLibrary for *;
    function setUp() public override(LaunchBase) {
        LaunchBase.setUp(); _activatePonsSe(); _wrapWeth(address(this), 1 ether);
        bool token0IsLaunch = Currency.unwrap(graduatedPoolKey.currency0) == launchToken;
        _startYield(ponsSe, [token0IsLaunch ? uint256(1e16) : uint256(1e10), token0IsLaunch ? uint256(1e10) : uint256(1e16)]);
    }
    function _yieldBlocked(bytes memory data_) internal override returns (bytes memory) { return _launchBlocked(data_); }
    function _yieldFeesHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(
            ponsHook.pendingFees(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency0)),
            ponsHook.pendingFees(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency1)),
            ponsHook.pendingCreatorTax(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency0)),
            ponsHook.pendingCreatorTax(graduatedPoolKey.toId(), Currency.unwrap(graduatedPoolKey.currency1))));
    }
    function test_blockedSYDepositBothDirections() public { _yieldEquivalence(0); }
    function test_blockedSYExternalRedeemBothDirections() public { _yieldEquivalence(1); }
    function test_blockedSYInternalRedeemRetainsSurplusBothDirections() public { _yieldEquivalence(2); }
    function test_blockedSYExternalShortageRollsBack() public { _yieldCoverRollback(false); }
    function test_blockedSYInternalShortageRollsBackAndClearsContext() public { _yieldCoverRollback(true); }
}

contract UniswapV4FullSpreadPonsFamilyHookNativeBlockedYieldEquivalenceTest
    is UniswapV4FullSpreadPonsFamilyHookBlockedYieldEquivalenceTest
{
    function _nativeLaunch() internal pure override returns (bool) { return true; }
}
