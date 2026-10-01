// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_ERC4626Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";

/// @notice D20: single-CP × ERC4626StandardExchange (COMPATIBLE). Face: 18-decimal underlying of a
///         capped/pausable ERC-4626 stub wrapped by the production ERC-4626 SE package, bound as
///         `pairToken` with the base's raw token on the other leg.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_ERC4626StandardExchange is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_ERC4626Fixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Retained from the original row: an under-consuming protocol vault leaves dust on the SE;
    ///      the joiner is never refunded from it. Uses the base's own pair/raw tokens and default
    ///      PkgArgs, redeploying a hook whose SE wraps the under-consuming stub.
    function test_underConsumption_leaveDust_doesNotPayCaller() public {
        UnderConsumeERC4626 proto = new UnderConsumeERC4626(SimpleMintableERC20(address(pairToken)));
        proto.setLeaveDust(1 ether);
        address underSe = _deployERC4626SE(address(proto));
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange = underSe;
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);
        single = IHook(h);
        hook = h;
        _bindProductPoolKey();
        pairToken.mint(user, 400 ether);
        rawToken.mint(user, 400 ether);
        vm.startPrank(user);
        pairToken.approve(h, type(uint256).max);
        rawToken.approve(h, type(uint256).max);
        vm.stopPrank();
        _depositBoth(100 ether, 100 ether);
        uint256 userPair = pairToken.balanceOf(user);
        _depositBoth(10 ether, 10 ether);
        assertLt(pairToken.balanceOf(user), userPair, "under-consume leftover is not caller refund");
    }
    /// @notice Buffered prepayment equal to the SE claim is fully available as local credit.
    function test_APEX008_bufferedPretransfer_equalRatedReserve_refundsAllUnused() public {
        _assertBufferedPretransferRefund(1);
    }

    /// @notice Fat maxima above the SE claim return every unused input token.
    function test_APEX008_bufferedPretransfer_aboveRatedReserve_refundsAllUnused() public {
        _assertBufferedPretransferRefund(2);
    }

    function _assertBufferedPretransferRefund(uint256 multiple) internal {
        _seed();
        uint256 maxIn = IBasicVault(hook).reserveOfToken(face) * multiple;
        IERC20 tin = IERC20(face);
        IERC20 tout = IERC20(raw);
        uint256 wantOut = 1 ether;
        uint256 used = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        assertGt(maxIn, used, "maximum exceeds quoted input");
        fx.fund(address(this), maxIn);
        tin.approve(address(rowCaller), maxIn);
        bytes memory returned = rowCaller.consumePretransfer(
            tin, address(this), hook, maxIn,
            abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (tin, maxIn, tout, wantOut, address(rowCaller), true, block.timestamp + 1 hours))
        );
        assertEq(abi.decode(returned, (uint256)), used, "quoted input consumed");
        assertEq(tin.balanceOf(address(rowCaller)), maxIn - used, "all unused credit refunded");
        assertEq(tout.balanceOf(address(rowCaller)), wantOut, "exact output paid");
        assertEq(tin.balanceOf(hook), 0, "no prepayment stranded");
    }

}
