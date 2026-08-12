// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

contract Adversarial_Griefing_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    function test_H1_extremeWidthMultiplier_noOverflow() public {
        // Distinct fee tier so createPool does not collide with setUp pool.
        IUniswapV3Pool p = _createPoolOneToOne(address(tokenA), address(tokenB), 500);
        _seedExternalLiquidity(p, 50_000_000e18);
        // Large but safe width (tick math snaps/clamps).
        address v = uniswapV3StandardExchangeDFPkg.deployVault(p, 2000);
        address token0 = p.token0();
        ERC20PermitMintableStub(token0).mint(attacker, 20 ether);
        vm.startPrank(attacker);
        IERC20(token0).approve(v, type(uint256).max);
        uint256 shares = IStandardExchangeProxy(v).exchangeIn(
            IERC20(token0), 20 ether, IERC20(v), 0, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertGt(shares, 0);
    }
}
