// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";

/**
 * @title UniswapV4QuadStableSwapHook_Robinhood_Test
 * @notice Robinhood Chain (4663) fork smoke.
 * @dev Uses foundry.toml Alchemy RPC alias `robinhood_mainnet_alchemy` and a
 *      pinned block after Uniswap V4 PoolManager deploy (block ~9070) so Foundry
 *      reuses Alchemy archive state. Override with ROBINHOOD_FORK_BLOCK /
 *      ROBINHOOD_RPC_ALIAS if needed.
 *
 *      Requires ROBINHOOD_MAINNET enabled on the Alchemy app for ${ALCHEMY_KEY}.
 */
contract UniswapV4QuadStableSwapHook_Robinhood_Test is Test {
    /// @notice Alchemy RPC alias from foundry.toml (archive-capable).
    string internal constant DEFAULT_RPC_ALIAS = "robinhood_mainnet_alchemy";

    /// @notice Crane default pin — well after V4 PoolManager (deployed ~block 9070).
    uint256 internal constant DEFAULT_FORK_BLOCK = ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK;

    function test_K2_robinhoodForkSmoke() public {
        string memory rpcAlias = _getRpcAlias();
        uint256 forkBlock = _getForkBlock();
        // Fork IDs are zero-based; do not assert id > 0.
        vm.createSelectFork(rpcAlias, forkBlock);

        assertEq(block.chainid, ROBINHOOD_MAIN.CHAIN_ID, "Robinhood chainid 4663");
        assertEq(block.number, forkBlock, "pinned fork block");

        // Uni V4 must be live at the pin (PoolManager code present).
        assertGt(ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER.code.length, 0, "V4 PoolManager at pin");
        assertGt(address(ROBINHOOD_MAIN.WETH9).code.length, 0, "WETH9 code on fork");

        emit log_named_string("Robinhood RPC alias", rpcAlias);
        emit log_named_uint("Robinhood fork block", forkBlock);
        emit log_named_address("V4 PoolManager", ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER);
    }

    function _getRpcAlias() internal view returns (string memory) {
        try vm.envString("ROBINHOOD_RPC_ALIAS") returns (string memory alias_) {
            if (bytes(alias_).length > 0) return alias_;
        } catch {}
        return DEFAULT_RPC_ALIAS;
    }

    function _getForkBlock() internal view returns (uint256) {
        try vm.envUint("ROBINHOOD_FORK_BLOCK") returns (uint256 envBlock) {
            if (envBlock > 0) return envBlock;
        } catch {}
        return DEFAULT_FORK_BLOCK;
    }
}
