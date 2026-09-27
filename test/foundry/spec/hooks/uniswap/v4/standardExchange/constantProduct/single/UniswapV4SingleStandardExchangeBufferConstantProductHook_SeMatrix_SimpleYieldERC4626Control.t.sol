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

    /// @dev Production check retained from the original row, asserted on the observed path. This
    ///      package validates addresses and decimals only (`_validateArgs` in the family DFPkg has no
    ///      SE-surface probe, and neither `Repo._initializeBindings` nor the registry's
    ///      `deployHookVault` probes the candidate), so a bare protocol vault deploys and registers.
    ///      The first buffering operation probes `previewExchangeIn` on the candidate
    ///      (`_bufferPair` in DepositCommon); `SimpleYieldERC4626` has neither that selector nor a
    ///      fallback, so the deposit reverts with empty data, which the hook propagates unchanged.
    function test_control_bareProtocolVault_rejectedAtFirstBuffer() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange = address(pairProtocolVault);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertTrue(h.code.length > 0, "package accepted the bare vault at init");
        assertTrue(_registry().isVault(h), "registered through the vault registry");
        _ensureProductDoorsAndFinalize(h, address(rawToken), address(pairToken));
        vm.startPrank(user);
        rawToken.approve(h, type(uint256).max);
        pairToken.approve(h, type(uint256).max);
        vm.expectRevert(bytes(""));
        IHook(h).deposit(100 ether, 100 ether, user, 0, block.timestamp + 1 hours);
        vm.stopPrank();
    }
}
