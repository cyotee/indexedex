// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals.sol";
import {UniswapV4Detf_Stage11OpenSuite_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Stage11OpenSuite_Decimals.sol";

abstract contract UniswapV4Detf_Cp_Univ3Se_ProductLaw_Decimals is
    TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals,
    UniswapV4Detf_Stage11OpenSuite_Decimals
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals, UniswapV4Detf_Stage11OpenSuite_Decimals)
    {
        TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals.setUp();
        _bindStage11OpenActors();
    }
    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals)
    {
        TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals._assertNoJoinableDust();
    }
}
