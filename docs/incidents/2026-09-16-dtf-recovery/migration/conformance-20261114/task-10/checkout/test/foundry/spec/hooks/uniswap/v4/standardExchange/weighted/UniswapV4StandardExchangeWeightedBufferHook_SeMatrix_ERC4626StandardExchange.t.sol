// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_ERC4626Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted × ERC4626StandardExchange (COMPATIBLE). Face: 18-decimal underlying of a
///         capped/pausable ERC-4626 stub wrapped by the production ERC-4626 SE package.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_ERC4626StandardExchange is
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_ERC4626Fixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Retained from the original row: an under-consuming protocol vault leaves dust on the SE;
    ///      the joiner is never refunded from it.
    function test_underConsumption_leaveDust_doesNotPayCaller() public {
        UnderConsumeERC4626 proto = new UnderConsumeERC4626(SimpleMintableERC20(address(token0)));
        proto.setLeaveDust(1 ether);
        address underSe = _deployERC4626SE(address(proto));
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[0] = underSe;
        _deployHookWithArgs(args);
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _firstMintEqual(100 ether);
        uint256 user0 = token0.balanceOf(user);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;
        vm.prank(user);
        weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertLt(token0.balanceOf(user), user0, "under-consume leftover is not caller refund");
    }
}
