// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad_MorphoMix} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_MorphoMix.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol";
import {UniswapV4Detf_Stage11OpenSuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11OpenSuite.sol";

/// @notice M_QD_MorphoMix Stage 11 Open (§7.0). Layer abstracts only (R-24).
contract UniswapV4Detf_Quad_MorphoMix_ProductLaw is
    TestBase_UniswapV4Detf_Quad_MorphoMix,
    UniswapV4Detf_Stage11OpenSuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Quad_ProdSe, UniswapV4Detf_Stage11OpenSuite)
    {
        TestBase_UniswapV4Detf_Quad_ProdSe.setUp();
        _bindStage11OpenActors();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Quad_ProdSe)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad_ProdSe._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Quad_ProdSe)
    {
        TestBase_UniswapV4Detf_Quad_ProdSe._assertNoJoinableDust();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override
        returns (address)
    {
        return _deployQuadHookThenDetf(args);
    }

    function _baseArgs() internal override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(3);
    }
}
