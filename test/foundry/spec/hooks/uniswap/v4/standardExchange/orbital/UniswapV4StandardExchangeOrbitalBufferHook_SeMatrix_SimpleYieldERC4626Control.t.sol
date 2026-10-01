// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_SimpleYieldERC4626ControlFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice D20: orbital × SimpleYieldERC4626 control row (M9): the plain yield stub wrapped by the
///         production ERC-4626 SE package on all three legs (M4) runs the full row set with the
///         rounding-to-zero control. Not counted toward D16 coverage.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_SimpleYieldERC4626Control is
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_SimpleYieldERC4626ControlFixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Production check retained from the original row: a bare protocol vault that is not an
    ///      SE diamond is rejected at package init. `_validateArgs` -> `_requireSeOwnsToken` probes
    ///      `IBasicVault(se).vaultTokens()` on the candidate (orbital DFPkg, SE validation site);
    ///      `SimpleYieldERC4626` has neither that selector nor a fallback, so the probe reverts with
    ///      empty data and the package propagates it unchanged. The first site that reaches
    ///      `_validateArgs` is `processArgs`, which `PkgFactory.findMineNonce` calls, so the
    ///      helper wraps nonce mining and `deployVault` in one external call for `expectRevert`.
    function test_control_bareProtocolVault_rejectedAtPackageInit() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.se0 = address(vault0);
        vm.expectRevert(bytes(""));
        this.deployHookArgs(args);
    }

    function deployHookArgs(IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args) public {
        uint256 n = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        PkgFactory.deployHook(hookPkg, args, n);
    }
}
