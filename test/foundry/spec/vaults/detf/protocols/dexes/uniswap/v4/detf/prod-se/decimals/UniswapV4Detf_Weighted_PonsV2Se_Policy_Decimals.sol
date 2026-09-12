// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {TestBase_UniswapV4Detf_Weighted_PonsV2Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_PonsV2Se_Decimals.sol";
import {UniswapV4Detf_Stage11PolicySuite_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Stage11PolicySuite_Decimals.sol";

abstract contract UniswapV4Detf_Weighted_PonsV2Se_Policy_Decimals is
    TestBase_UniswapV4Detf_Weighted_PonsV2Se_Decimals,
    UniswapV4Detf_Stage11PolicySuite_Decimals
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Weighted_PonsV2Se_Decimals, UniswapV4Detf_Stage11PolicySuite_Decimals)
    {
        TestBase_UniswapV4Detf_Weighted_PonsV2Se_Decimals.setUp();
        policyCreator = makeAddr("creator");
    }
    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals)
    {
        TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals._assertNoJoinableDust();
    }

    function _deployHookThenDetf(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals._deployHookThenDetf(args);
    }

    function _pairInToJoinWad(uint256 pairAmount_)
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals)
        returns (uint256)
    {
        return TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals._pairInToJoinWad(pairAmount_);
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployWeightedHookThenDetf(args);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual override {
        _deployWeightedHookForArgs(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(2);
    }

    function _fundTokenFallback(address token_, address to_, uint256 amount_) internal virtual override {
        if (IERC20(token_).balanceOf(to_) >= amount_) return;
        deal(token_, to_, amount_, true);
    }













}
