// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Cp_MorphoBlueSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_MorphoBlueSe.sol";
import {UniswapV4Detf_Stage11OpenSuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11OpenSuite.sol";

/// @notice H_CP_MB Stage 11 Open (§7.0). Layer abstracts only (R-24).
contract UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw is
    TestBase_UniswapV4Detf_Cp_MorphoBlueSe,
    UniswapV4Detf_Stage11OpenSuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Cp_MorphoBlueSe, UniswapV4Detf_Stage11OpenSuite)
    {
        TestBase_UniswapV4Detf_Cp_MorphoBlueSe.setUp();
        _bindStage11OpenActors();
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
