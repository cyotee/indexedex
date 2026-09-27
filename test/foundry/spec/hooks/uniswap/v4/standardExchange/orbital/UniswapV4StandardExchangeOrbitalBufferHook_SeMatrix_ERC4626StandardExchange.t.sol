// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_ERC4626Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice D20: orbital × ERC4626StandardExchange (COMPATIBLE). Three legs (M4), each faced on the
///         18-decimal underlying of its own capped/pausable ERC-4626 stub wrapped by the production
///         ERC-4626 SE package; each leg binds that leg's SE.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_ERC4626StandardExchange is
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_ERC4626Fixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Retained from the original row: an under-consuming protocol vault leaves dust on the SE;
    ///      the joiner is never refunded from it. Runs on the TestBase tokens with a fresh hook.
    function test_underConsumption_leaveDust_doesNotPayCaller() public {
        UnderConsumeERC4626 proto = new UnderConsumeERC4626(SimpleMintableERC20(address(token0)));
        proto.setLeaveDust(1 ether);
        address underSe = _deployERC4626SE(address(proto));
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.se0 = underSe;
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);
        orbital = IUniswapV4StandardExchangeOrbitalBufferHook(h);
        hook = h;
        token0.mint(user, 400 ether);
        token1.mint(user, 400 ether);
        token2.mint(user, 400 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        orbital.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
        uint256 user0 = token0.balanceOf(user);
        orbital.addLiquidity(10 ether, 10 ether, 10 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();
        assertLt(token0.balanceOf(user), user0, "under-consume leftover is not caller refund");
    }
}
