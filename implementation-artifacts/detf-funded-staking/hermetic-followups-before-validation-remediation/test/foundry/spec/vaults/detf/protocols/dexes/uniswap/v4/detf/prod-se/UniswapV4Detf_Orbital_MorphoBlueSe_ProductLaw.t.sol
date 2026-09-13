// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital_MorphoBlueSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_MorphoBlueSe.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {UniswapV4Detf_Stage11OpenSuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11OpenSuite.sol";

/// @notice H_OR_MB Stage 11 Open (§7.0). Layer abstracts only (R-24).
contract UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw is
    TestBase_UniswapV4Detf_Orbital_MorphoBlueSe,
    UniswapV4Detf_Stage11OpenSuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Orbital_MorphoBlueSe, UniswapV4Detf_Stage11OpenSuite)
    {
        TestBase_UniswapV4Detf_Orbital_MorphoBlueSe.setUp();
        _bindStage11OpenActors();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital_ProdSe)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Orbital_ProdSe._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital_ProdSe)
    {
        TestBase_UniswapV4Detf_Orbital_ProdSe._assertNoJoinableDust();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override
        returns (address)
    {
        return _deployOrbitalHookThenDetf(args);
    }

    function _baseArgs() internal override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(2);
    }

    bool internal _morphoDetfDonate;

    function test_DN13_burn_afterDonate_usesDonatedLp() public override {
        _morphoDetfDonate = true;
        super.test_DN13_burn_afterDonate_usesDonatedLp();
        _morphoDetfDonate = false;
    }

    function test_DN14_closeAfterDonate_userBasketUnchanged() public override {
        _morphoDetfDonate = true;
        super.test_DN14_closeAfterDonate_userBasketUnchanged();
        _morphoDetfDonate = false;
    }

    function _donatePair(address from_, uint256 amount_) internal override returns (uint256 lpOut_) {
        if (!_morphoDetfDonate) {
            return super._donatePair(from_, amount_);
        }
        uint256 amt_ = amount_ > 2 ether ? 2 ether : amount_;
        uint256 have_ = IERC20(detf).balanceOf(from_);
        if (have_ < amt_) deal(detf, from_, amt_, true);
        address nft_ = address(_nft());
        vm.startPrank(from_);
        IERC20(detf).approve(nft_, amt_);
        lpOut_ = IDetfNftReserveDonation(nft_).donate(IERC20(detf), amt_, 0, false, _deadline());
        vm.stopPrank();
    }
}
