// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Cp_Univ4Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ4Se.sol";
import {UniswapV4Detf_Stage11OpenSuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11OpenSuite.sol";

/// @notice H_CP_GV4 Stage 11 Open (§7.0). Layer abstracts only (R-24).
contract UniswapV4Detf_Cp_Univ4Se_ProductLaw is
    TestBase_UniswapV4Detf_Cp_Univ4Se,
    UniswapV4Detf_Stage11OpenSuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Cp_Univ4Se, UniswapV4Detf_Stage11OpenSuite)
    {
        TestBase_UniswapV4Detf_Cp_Univ4Se.setUp();
        _bindStage11OpenActors();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Cp_Univ4Se)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Cp_Univ4Se._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Cp_Univ4Se)
    {
        TestBase_UniswapV4Detf_Cp_Univ4Se._assertNoJoinableDust();
    }
}
