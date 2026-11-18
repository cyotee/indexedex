// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {FullSpreadV3ProductLawFunding as Funding} from "contracts/test/libs/FullSpreadV3ProductLawFunding.sol";

import {UniswapV4DetfProductionSeDeployLib as SeLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe_Decimals.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals.sol";
import {UniswapV4Detf_Stage11PolicySuite_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Stage11PolicySuite_Decimals.sol";

abstract contract UniswapV4Detf_Quad_Univ3Se_Policy_Decimals is
    TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals,
    UniswapV4Detf_Stage11PolicySuite_Decimals
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Quad_ProdSe_Decimals, UniswapV4Detf_Stage11PolicySuite_Decimals)
    {
        TestBase_UniswapV4Detf_Quad_ProdSe_Decimals.setUp();
        policyCreator = makeAddr("creator");
    }
    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Quad_ProdSe_Decimals)
        returns (uint256 tokenId, uint256 shares)
    {
        if (detfInfo.isReserveLive()) return TestBase_UniswapV4Detf_Quad_ProdSe_Decimals._firstBond(pairAmount_);
        (tokenId, shares,) = SeLib.bondFirstPositionBasket(
            detfInfo, address(pairToken), pairAmount_, detfUser, DEFAULT_MIN_LOCK
        );
    }

    function _firstBondOn(address d, uint256 amt)
        internal virtual override returns (uint256 tokenId, uint256 shares)
    {
        if (IUniswapV4Detf(d).isReserveLive()) return super._firstBondOn(d, amt);
        uint256 paid;
        (tokenId, shares, paid) = SeLib.bondFirstPositionBasket(
            IUniswapV4Detf(d), address(_mintTokenOf(d)), amt, detfUser, DEFAULT_MIN_LOCK
        );
        _policyInitialBond[d] = tokenId;
        _policyFirstBondPaid[d] = paid;
    }

    function _preparePositivePayment(address instance_, IERC20 token_, uint256 amount_, address payer_)
        internal virtual override returns (IERC20, uint256)
    {
        return Funding.preparePayment(instance_, address(token_), amount_, payer_);
    }

    function _bondOn(address instance_, address bonder_, uint256 amount_)
        internal virtual override returns (uint256 tokenId_, uint256 shares_)
    {
        (bool handled_, uint256 id_, uint256 lp_) = Funding.tryBond(
            instance_, address(_leadPairOf(instance_)), amount_, bonder_, DEFAULT_MIN_LOCK
        );
        if (handled_) return (id_, lp_);
        return super._bondOn(instance_, bonder_, amount_);
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

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual override {
        _deployQuadHookForArgs(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(3);
    }












}
