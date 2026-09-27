// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTestDeployLib as DeployLib
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_SimpleYieldERC4626ControlFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted × SimpleYieldERC4626 control row (M9): the plain yield stub wrapped by the
///         production ERC-4626 SE package runs the full row set with the rounding-to-zero control.
///         Not counted toward D16 coverage.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_SimpleYieldERC4626Control is
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_SimpleYieldERC4626ControlFixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Production check retained from the original row: a bare protocol vault that is not an
    ///      SE diamond is rejected at package init. The package probes `vaultTokens()` on the
    ///      candidate SE; a contract without that selector reverts with empty data, which the
    ///      package propagates unchanged (site: hook DFPkg SE validation, 2026-09-21 trace).
    function test_control_bareProtocolVault_rejectedAtPackageInit() public {
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[0] = address(vault0);
        vm.expectRevert(bytes(""));
        DeployLib.deployHookInstance(hookFactory, hookPkg, args);
    }
}
