// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe_Decimals.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {TestBase_UniswapV4Detf_Quad_PonsMix_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_PonsMix_Decimals.sol";
import {UniswapV4Detf_Stage11OpenSuite_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Stage11OpenSuite_Decimals.sol";

abstract contract UniswapV4Detf_Quad_PonsMix_ProductLaw_Decimals is
    TestBase_UniswapV4Detf_Quad_PonsMix_Decimals,
    UniswapV4Detf_Stage11OpenSuite_Decimals
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Quad_ProdSe_Decimals, UniswapV4Detf_Stage11OpenSuite_Decimals)
    {
        TestBase_UniswapV4Detf_Quad_ProdSe_Decimals.setUp();
        _bindStage11OpenActors();
    }
    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Quad_ProdSe_Decimals)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad_ProdSe_Decimals._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Quad_ProdSe_Decimals)
    {
        TestBase_UniswapV4Detf_Quad_ProdSe_Decimals._assertNoJoinableDust();
    }

    function _deployHookThenDetf(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Quad_ProdSe_Decimals)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Quad_ProdSe_Decimals._deployHookThenDetf(args);
    }

    function _pairInToJoinWad(uint256 pairAmount_)
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Quad_ProdSe_Decimals)
        returns (uint256)
    {
        return TestBase_UniswapV4Detf_Quad_ProdSe_Decimals._pairInToJoinWad(pairAmount_);
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployQuadHookThenDetf(args);
    }

    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(3);
    }
}
