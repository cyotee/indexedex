// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {TestBase_UniswapV4Detf_Quad_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Decimals.sol";
import {TestBase_UniswapV4Detf_Policy_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy_Decimals.sol";
import {UniswapV4Detf_Stage11PolicySuite_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Stage11PolicySuite_Decimals.sol";

abstract contract UniswapV4Detf_Quad_Policy_Decimals is
    TestBase_UniswapV4Detf_Quad_Decimals,
    UniswapV4Detf_Stage11PolicySuite_Decimals
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Quad_Decimals, UniswapV4Detf_Stage11PolicySuite_Decimals)
    {
        TestBase_UniswapV4Detf_Quad_Decimals.setUp();
        policyCreator = makeAddr("creator");
    }
    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(3);
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployQuadHookThenDetf(args);
    }

    function _deployHookThenDetf(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployQuadHookThenDetf(args);
    }

    function _mintTokenOf(address) internal view virtual override returns (IERC20 tok) {
        return IERC20(address(pair0));
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual override {
        _deployQuadHookForArgs(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Quad_Decimals)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad_Decimals._firstBond(pairAmount_);
    }
}
