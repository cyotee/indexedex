// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_SimpleYieldERC4626ControlFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";

/// @notice D20: single-CP × SimpleYieldERC4626 control row (M9): the plain yield stub wrapped by the
///         production ERC-4626 SE package runs the full row set with the rounding-to-zero control.
///         Not counted toward D16 coverage.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_SimpleYieldERC4626Control is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_SimpleYieldERC4626ControlFixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev A bare yield stub is not wrapper-share inventory and has no `vaultTokens()`. Bind rejects
    ///      it. `asset()` is not enough to deploy.
    function test_control_bareProtocolVault_rejectedAtFirstBuffer() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange = address(pairProtocolVault);
        vm.expectRevert(
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.TokenNotInVaultTokens.selector
        );
        this.deployBare(args);
    }

    function deployBare(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args)
        external
    {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        PkgFactory.deployHook(hookPkg, args, mineNonce);
    }
}
