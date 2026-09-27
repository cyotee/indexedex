// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTestDeployLib as DeployLib
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTestDeployLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_SimpleYieldERC4626ControlFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20: balancer-quad × SimpleYieldERC4626 control row (M9): the plain yield stub wrapped by
///         the production ERC-4626 SE package on every leg (M4) runs the full row set with the
///         rounding-to-zero control. Not counted toward D16 coverage.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control is
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_SimpleYieldERC4626ControlFixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Production check retained from the original row: a bare protocol vault that is not an
    ///      SE diamond is rejected at package init. `_validateArgs` reaches `_requireSeOwnsToken`,
    ///      which probes `IBasicVault(se).vaultTokens()` on the candidate; `SimpleYieldERC4626` has
    ///      no such selector and no fallback, so the probe reverts with empty data, which the
    ///      package propagates unchanged (site: `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg`
    ///      `_requireSeOwnsToken`, reached before the SE decimals check).
    function test_control_bareProtocolVault_rejectedAtPackageInit() public {
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[0] = address(vault0);
        vm.expectRevert(bytes(""));
        DeployLib.deployHookInstance(hookFactory, hookPkg, args);
    }
}
