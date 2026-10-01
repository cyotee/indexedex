// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_ERC4626Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual-CP × ERC4626StandardExchange (COMPATIBLE). Both legs (M4) bind an 18-decimal
///         underlying of a capped/pausable ERC-4626 stub wrapped by the production ERC-4626 SE package.
contract UniswapV4DualSEBCPHook_SeMatrix_ERC4626StandardExchange is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_ERC4626Fixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Retained from the original row: an under-consuming protocol vault leaves dust on the SE;
    ///      the joiner is never refunded from it. Runs on the TestBase's own pair (`tokenA` / `seB`)
    ///      through the same package path.
    function test_underConsumption_leaveDust_doesNotPayCaller() public {
        UnderConsumeERC4626 proto = new UnderConsumeERC4626(SimpleMintableERC20(address(tokenA)));
        proto.setLeaveDust(1 ether);
        address underSe = _deployERC4626SE(address(proto));
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange0 = underSe;
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = DualFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h, address(tokenA), address(tokenB));
        dual = IDualHook(h);
        hook = h;
        _bindProductPoolKey();
        tokenA.mint(user, 400 ether);
        tokenB.mint(user, 400 ether);
        vm.startPrank(user);
        tokenA.approve(h, type(uint256).max);
        tokenB.approve(h, type(uint256).max);
        vm.stopPrank();
        _depositBoth(100 ether, 100 ether);
        uint256 userA = tokenA.balanceOf(user);
        _depositBoth(10 ether, 10 ether);
        assertLt(tokenA.balanceOf(user), userA, "under-consume leftover is not caller refund");
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
        IERC20 tout = IERC20(other);
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
