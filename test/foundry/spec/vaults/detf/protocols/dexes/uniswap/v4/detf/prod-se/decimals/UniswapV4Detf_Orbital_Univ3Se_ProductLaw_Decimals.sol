// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {FullSpreadV3ProductLawFunding as Funding} from "contracts/test/libs/FullSpreadV3ProductLawFunding.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals.sol";
import {UniswapV4Detf_Stage11OpenSuite_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Stage11OpenSuite_Decimals.sol";

abstract contract UniswapV4Detf_Orbital_Univ3Se_ProductLaw_Decimals is
    TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals,
    UniswapV4Detf_Stage11OpenSuite_Decimals
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals, UniswapV4Detf_Stage11OpenSuite_Decimals)
    {
        TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals.setUp();
        _bindStage11OpenActors();
    }
    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals)
        returns (uint256 tokenId, uint256 shares)
    {
        (bool handled_, uint256 id_, uint256 lp_) =
            Funding.tryBond(detf, address(pairToken), pairAmount_, detfUser, DEFAULT_MIN_LOCK);
        if (handled_) return (id_, lp_);
        return TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals._firstBond(pairAmount_);
    }

    function _bondAs(address bonder_, uint256 amount_)
        internal virtual override returns (uint256 tokenId_, uint256 shares_)
    {
        (bool handled_, uint256 id_, uint256 lp_) =
            Funding.tryBond(detf, address(pairToken), amount_, bonder_, DEFAULT_MIN_LOCK);
        if (handled_) return (id_, lp_);
        return super._bondAs(bonder_, amount_);
    }

    function _bondAs(address instance_, address bonder_, uint256 amount_)
        internal virtual override returns (uint256 tokenId_, uint256 shares_)
    {
        (bool handled_, uint256 id_, uint256 lp_) =
            Funding.tryBond(instance_, address(pairToken), amount_, bonder_, DEFAULT_MIN_LOCK);
        if (handled_) return (id_, lp_);
        return super._bondAs(instance_, bonder_, amount_);
    }

    function _bondOn(address instance_, address bonder_, uint256 amount_)
        internal virtual override returns (uint256 tokenId_, uint256 shares_)
    {
        (bool handled_, uint256 id_, uint256 lp_) =
            Funding.tryBond(instance_, address(_leadPairOf(instance_)), amount_, bonder_, DEFAULT_MIN_LOCK);
        if (handled_) return (id_, lp_);
        return super._bondOn(instance_, bonder_, amount_);
    }

    function _acquireDonationShares(address vault_, IERC20 payment_, uint256 amount_, address payer_)
        internal virtual override returns (uint256)
    {
        return SeLib.acquirePositionShares(vault_, address(payment_), amount_, payer_);
    }

    function _preparePositivePayment(address instance_, IERC20 token_, uint256 amount_, address payer_)
        internal virtual override returns (IERC20 payment_, uint256 paid_)
    {
        return Funding.preparePayment(instance_, address(token_), amount_, payer_);
    }

    /// @notice Keep the original raw pair budgets alongside positive funded donation coverage.
    function test_DN23_rawPair_refundOrFundedDonation() public {
        _assertDnRawPairPolicy();
    }

    function test_DN16_lastClose_thenDonate_nextBondDoesNotCapture() public virtual override {
        _dnLastCloseThenDonate();
    }

    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals)
    {
        TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals._assertNoJoinableDust();
    }

    function _deployHookThenDetf(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals._deployHookThenDetf(args);
    }

    function _pairInToJoinWad(uint256 pairAmount_)
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals)
        returns (uint256)
    {
        return TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals._pairInToJoinWad(pairAmount_);
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployOrbitalHookThenDetf(args);
    }

    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(2);
    }
}
