// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_AaveCrossVersionLoop_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoop_Decimals.sol";

/// @notice Metadata + mintability for each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopHarness_Decimals is TestBase_AaveCrossVersionLoop_Decimals {
    function test_testTokens_deployed_distinct() public view {
        assertTrue(address(tokenA) != address(0), "tokenA deployed");
        assertTrue(address(tokenB) != address(0), "tokenB deployed");
        assertTrue(address(tokenA) != address(tokenB), "distinct tokens");
    }

    function test_testTokens_metadata() public view {
        assertEq(IERC20Metadata(address(tokenA)).decimals(), _tokenADecimals(), "tokenA decimals");
        assertEq(IERC20Metadata(address(tokenB)).decimals(), _tokenBDecimals(), "tokenB decimals");
        assertEq(IERC20Metadata(address(tokenA)).symbol(), "CLTA", "tokenA symbol");
        assertEq(IERC20Metadata(address(tokenB)).symbol(), "CLTB", "tokenB symbol");
    }

    function test_testTokens_mintable_by_owner() public {
        _mint(tokenA, address(this), _uA(1_000));
        _mint(tokenB, address(0xBEEF), _uB(2_000));
        assertEq(tokenA.balanceOf(address(this)), _uA(1_000), "tokenA minted");
        assertEq(tokenB.balanceOf(address(0xBEEF)), _uB(2_000), "tokenB minted");
    }
}
