// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_AaveCrossVersionLoop} from "contracts/test/bases/TestBase_AaveCrossVersionLoop.sol";

/**
 * @title AaveCrossVersionLoopHarness_Test
 * @notice Proves the non-fork test harness stands up: the two pair test tokens deploy via
 *         ERC20MintBurnOwnableOperableDFPkg and the test can mint them (to later seed local
 *         Aave V3.6 + V4 markets). Foundation for the deterministic profitable-loop tests.
 */
contract AaveCrossVersionLoopHarness_Test is TestBase_AaveCrossVersionLoop {
    function test_testTokens_deployed_distinct() public view {
        assertTrue(address(tokenA) != address(0), "tokenA deployed");
        assertTrue(address(tokenB) != address(0), "tokenB deployed");
        assertTrue(address(tokenA) != address(tokenB), "distinct tokens");
    }

    function test_testTokens_metadata() public view {
        assertEq(IERC20Metadata(address(tokenA)).decimals(), 18, "tokenA 18dp");
        assertEq(IERC20Metadata(address(tokenB)).decimals(), 6, "tokenB 6dp");
        assertEq(IERC20Metadata(address(tokenA)).symbol(), "CLTA", "tokenA symbol");
        assertEq(IERC20Metadata(address(tokenB)).symbol(), "CLTB", "tokenB symbol");
    }

    function test_testTokens_mintable_by_owner() public {
        _mint(tokenA, address(this), 1_000e18);
        _mint(tokenB, address(0xBEEF), 2_000e6);
        assertEq(tokenA.balanceOf(address(this)), 1_000e18, "tokenA minted");
        assertEq(tokenB.balanceOf(address(0xBEEF)), 2_000e6, "tokenB minted");
    }
}
