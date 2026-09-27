// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookTestDeployLib as DeployLib
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTestDeployLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_SimpleYieldERC4626ControlFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20: curve-quad × SimpleYieldERC4626 control row (M9): the plain yield stub wrapped by
///         the production ERC-4626 SE package on all four legs runs the full row set with the
///         rounding-to-zero control. Not counted toward D16 coverage.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control is
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_SimpleYieldERC4626ControlFixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Production check retained from the original row: a bare protocol vault that is not an
    ///      SE diamond is rejected at package init. `_validateArgs` -> `_requireSeOwnsToken` probes
    ///      `IBasicVault(se).vaultTokens()` on the candidate; `SimpleYieldERC4626` has no such
    ///      selector and no fallback, so the call reverts with empty data, which the package
    ///      propagates unchanged (site: `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg`
    ///      `_requireSeOwnsToken`).
    function test_control_bareProtocolVault_rejectedAtPackageInit() public {
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[0] = address(vault0);
        vm.expectRevert(bytes(""));
        DeployLib.deployHookInstance(hookFactory, hookPkg, args);
    }
}
