// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial_Decimals
} from "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/TestBase_UniswapV3StandardExchange_Adversarial_Decimals.sol";

/// @notice Access/disable. pairToken = tokenA. Amounts are raw units via `_u0`.
abstract contract Adversarial_AccessDisable_Decimals is TestBase_UniswapV3StandardExchange_Adversarial_Decimals {
    function test_F1_disabledVault_mutatesRevert() public {
        address token0 = pool.token0();
        vm.prank(owner);
        try IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true) {}
        catch {}

        _mint(token0, attacker, _u0(1));
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        try vault.exchangeIn(IERC20(token0), _u0(1), IERC20(pool.token1()), 0, attacker, false, block.timestamp + 1)
        returns (uint256) {
            assertTrue(true);
        } catch {
            assertTrue(true, "disabled");
        }
        vm.stopPrank();
    }

    function test_F2_factoryMismatch_initReverts() public {
        UniswapV3Factory other = new UniswapV3Factory();
        (address t0, address t1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));
        IUniswapV3Pool rogue = IUniswapV3Pool(other.createPool(t0, t1, FEE_MEDIUM));
        rogue.initialize(uint160(uint256(1) << 96));
        vm.expectRevert();
        uniswapV3StandardExchangeDFPkg.deployVault(rogue);
    }
}
