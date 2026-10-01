// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4SingleStandardExchangeBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_SimpleYieldERC4626ControlFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20: non-CP single × SimpleYieldERC4626 control row (M9): the plain yield stub wrapped
///         by the production ERC-4626 SE package runs the full row set with the rounding-to-zero
///         control. Not counted toward D16 coverage.
contract UniswapV4SingleSEBufferHook_SeMatrix_SimpleYieldERC4626Control is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_SimpleYieldERC4626ControlFixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Production check retained from the original row: a bare protocol vault that is not an
    ///      SE diamond is rejected at package init. `UniswapV4SingleStandardExchangeBufferHookDFPkg`
    ///      `_validateArgs` -> `_requirePairInVaultTokens` probes `IBasicVault(se).vaultTokens()`
    ///      on the candidate; a contract without that selector reverts with empty data, which the
    ///      package propagates unchanged through `processArgs` (the first call of both
    ///      `findMineNonce` and the hook factory's `_prepare`).
    function test_control_bareProtocolVault_rejectedAtPackageInit() public {
        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange = address(SeMatrix_SimpleYieldERC4626ControlFixture(address(fx)).protocolVault());
        vm.expectRevert(bytes(""));
        hookPkg.processArgs(abi.encode(args));
    }
}
