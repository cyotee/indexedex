// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_ERC4626Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20: balancer-quad × ERC4626StandardExchange (COMPATIBLE). Every leg (M4) is faced on the
///         18-decimal underlying of its own capped/pausable ERC-4626 stub wrapped by the production
///         ERC-4626 SE package; the lowest-address leg is the leg under test.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_ERC4626StandardExchange is
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_ERC4626Fixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Retained from the original row: an under-consuming protocol vault leaves dust on the SE;
    ///      the joiner is never refunded from it. Runs on the TestBase default binding (SE on leg 0).
    function test_underConsumption_leaveDust_doesNotPayCaller() public {
        UnderConsumeERC4626 proto = new UnderConsumeERC4626(SimpleMintableERC20(address(token0)));
        proto.setLeaveDust(1 ether);
        address underSe = _deployERC4626SE(address(proto));
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[0] = underSe;
        _deployHookWithArgs(args);
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        _firstMintEqual(100 ether);
        uint256 user0 = token0.balanceOf(user);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        vm.prank(user);
        quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertLt(token0.balanceOf(user), user0, "under-consume leftover is not caller refund");
    }
}
