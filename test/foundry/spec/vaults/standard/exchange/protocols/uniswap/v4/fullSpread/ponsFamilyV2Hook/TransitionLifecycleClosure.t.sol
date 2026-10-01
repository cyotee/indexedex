// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {TestBase_FullSpreadG6TransitionLifecycleClosure as Closure} from "contracts/test/bases/TestBase_FullSpreadG6TransitionLifecycleClosure.sol";
import {TestBase_FullSpreadG6WorkLimitRollback as WorkLimit} from "contracts/test/bases/TestBase_FullSpreadG6WorkLimitRollback.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";

// tag::PonsTransitionLifecycleClosureTest[]
/// @notice G6 over the separate Pons registry proxy, real registered hook and six-decimal currencies.
contract PonsTransitionLifecycleClosureTest is Acceptance, Closure {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }

    /// @notice Reuses the real registered-pool fixture; this is not graduated-launch evidence.
    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        _bootstrap();
        _startG6(vault, poolManager, poolKey, token0, token1, unit0, unit1);
    }

    function _g6Blocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
    function _g6ExternalSwap(bool zeroForOne_, uint256 amount_) internal override { _externalSwap(zeroForOne_, amount_); }
    function _g6Repair() internal override { Reserve(address(vault)).rebalanceLiquidReserve(); }
    function _g6Rates() internal pure override returns (uint256, uint256) { return (100, 100); }
}
// end::PonsTransitionLifecycleClosureTest[]

// tag::PonsG6WorkLimitRollbackTest[]
/// @notice Separate registered Pons spacing-1 pool exercises the actual core work cap.
contract PonsG6WorkLimitRollbackTest is Acceptance, WorkLimit {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
    function _tickSpacing() internal pure override returns (int24) { return 1; }

    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        _bootstrap();
        _startG6Work(vault, poolManager, poolKey, token0, token1);
    }
}
// end::PonsG6WorkLimitRollbackTest[]
