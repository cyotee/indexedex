// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Cp_MorphoBlueSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_MorphoBlueSe.sol";
import {UniswapV4Detf_Stage11PolicySuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11PolicySuite.sol";

/// @notice H_CP_MB Stage 11 Policy (§7.0). FC names use fixture id (R-16).
contract UniswapV4Detf_Cp_MorphoBlueSe_Policy is
    TestBase_UniswapV4Detf_Cp_MorphoBlueSe,
    UniswapV4Detf_Stage11PolicySuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Cp_MorphoBlueSe, UniswapV4Detf_Stage11PolicySuite)
    {
        TestBase_UniswapV4Detf_Cp_MorphoBlueSe.setUp();
        policyCreator = makeAddr("creator");
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Cp_MorphoBlueSe)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Cp_MorphoBlueSe._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Cp_MorphoBlueSe)
    {
        TestBase_UniswapV4Detf_Cp_MorphoBlueSe._assertNoJoinableDust();
    }














}
