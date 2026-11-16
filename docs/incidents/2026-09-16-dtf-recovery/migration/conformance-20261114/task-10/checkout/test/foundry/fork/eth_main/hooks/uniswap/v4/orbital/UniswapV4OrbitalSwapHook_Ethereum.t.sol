// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";

/**
 * @title UniswapV4OrbitalSwapHook_Ethereum_Fork_Test
 * @notice Ethereum mainnet fork: mintable test tokens + package path + LP + swap (P3).
 * @dev Protocol integration on fork env; not live stables. Requires ethereum_mainnet_alchemy RPC.
 */
contract UniswapV4OrbitalSwapHook_Ethereum_Fork_Test is TestBase_UniswapV4OrbitalSwapHook {
    string internal constant RPC = "ethereum_mainnet_alchemy";

    function setUp() public override {
        try vm.envUint("ETH_FORK_BLOCK") returns (uint256 b) {
            if (b > 0) {
                vm.createSelectFork(RPC, b);
            } else {
                vm.createSelectFork(RPC, ETHEREUM_MAIN.DEFAULT_FORK_BLOCK);
            }
        } catch {
            vm.createSelectFork(RPC, ETHEREUM_MAIN.DEFAULT_FORK_BLOCK);
        }
        assertEq(block.chainid, ETHEREUM_MAIN.CHAIN_ID);
        TestBase_UniswapV4OrbitalSwapHook.setUp();
    }

    function test_fork_package_lp_swap_mintableTokens() public {
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(hook));
        _seedThreeLeg(100 ether);
        assertGt(orbital.radius(), 0);
        _setDexFee(0.003e18);
        uint256 pred = orbital.previewSwapExactIn(address(token0), address(token1), 1 ether);
        assertGt(pred, 0);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertGt(address(pm).code.length, 0);
    }
}
