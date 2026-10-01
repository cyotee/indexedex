// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_FullSpreadG6TransitionLifecycleClosure as Closure} from "contracts/test/bases/TestBase_FullSpreadG6TransitionLifecycleClosure.sol";
import {TestBase_FullSpreadG6WorkLimitRollback as WorkLimit} from "contracts/test/bases/TestBase_FullSpreadG6WorkLimitRollback.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";

// tag::HooklessTransitionLifecycleClosureTest[]
/// @notice G6 over the hookless registry proxy with real six-decimal tokens and external liquidity.
contract HooklessTransitionLifecycleClosureTest is Acceptance, Closure {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }

    /// @notice Ordinary dual activation precedes all lifecycle assertions.
    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        _bootstrap();
        _startG6(vault, poolManager, poolKey, token0, token1, unit0, unit1);
    }

    function _g6Blocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
    function _g6ExternalSwap(bool zeroForOne_, uint256 amount_) internal override { _externalSwap(zeroForOne_, amount_); }
    function _g6Repair() internal override { Reserve(address(vault)).rebalanceLiquidReserve(); }
}
// end::HooklessTransitionLifecycleClosureTest[]

// tag::HooklessG6WorkLimitRollbackTest[]
/// @notice Separate real spacing-1 pool preserves the original spacing-60 acceptance fixtures.
contract HooklessG6WorkLimitRollbackTest is Acceptance, WorkLimit {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
    function _tickSpacing() internal pure override returns (int24) { return 1; }

    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        _bootstrap();
        _startG6Work(vault, poolManager, poolKey, token0, token1);
    }
}
// end::HooklessG6WorkLimitRollbackTest[]
