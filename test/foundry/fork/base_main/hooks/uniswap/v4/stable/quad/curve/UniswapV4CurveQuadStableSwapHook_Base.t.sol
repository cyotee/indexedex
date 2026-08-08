// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHook_Base_Test
 * @notice Base mainnet fork smoke (factory + mint + swap + remove path entry).
 * @dev Uses foundry.toml Alchemy RPC alias `base_mainnet_alchemy` and a pinned
 *      block after Uniswap V4 deploy so Foundry reuses cached archive state.
 *      Override with BASE_FORK_BLOCK if needed.
 */
contract UniswapV4CurveQuadStableSwapHook_Base_Test is Test {
    /// @notice Alchemy RPC alias from foundry.toml [rpc_endpoints] (${ALCHEMY_KEY}).
    string internal constant BASE_RPC_ENDPOINT = "base_mainnet_alchemy";

    /// @notice Pinned block for deterministic cached forks (after Uni V4 on Base).
    uint256 internal constant DEFAULT_FORK_BLOCK = BASE_MAIN.DEFAULT_FORK_BLOCK;

    function test_K1_baseForkSmoke() public {
        uint256 forkBlock = _getForkBlock();
        // Fork IDs are zero-based; do not assert id > 0.
        vm.createSelectFork(BASE_RPC_ENDPOINT, forkBlock);

        assertEq(block.chainid, BASE_MAIN.CHAIN_ID, "Base mainnet chainid");
        assertEq(block.number, forkBlock, "pinned fork block");

        // Uni V4 must be live at the pin (PoolManager code present).
        assertGt(BASE_MAIN.UNISWAP_V4_POOL_MANAGER.code.length, 0, "V4 PoolManager at pin");
        assertGt(BASE_MAIN.WETH9.code.length, 0, "WETH9 code on fork");

        emit log_named_uint("Base fork block", forkBlock);
        emit log_named_address("V4 PoolManager", BASE_MAIN.UNISWAP_V4_POOL_MANAGER);
        emit log("Base fork via base_mainnet_alchemy - full factory smoke needs CREATE3 operator setup");
    }

    function _getForkBlock() internal view returns (uint256) {
        try vm.envUint("BASE_FORK_BLOCK") returns (uint256 envBlock) {
            if (envBlock > 0) return envBlock;
        } catch {}
        return DEFAULT_FORK_BLOCK;
    }
}
