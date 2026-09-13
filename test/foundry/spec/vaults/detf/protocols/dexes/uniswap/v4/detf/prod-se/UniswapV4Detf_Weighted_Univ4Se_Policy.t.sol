// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted_Univ4Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Univ4Se.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {UniswapV4Detf_Stage11PolicySuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11PolicySuite.sol";

/// @notice H_WE_GV4 Stage 11 Policy (§7.0). FC names use fixture id (R-16).
contract UniswapV4Detf_Weighted_Univ4Se_Policy is
    TestBase_UniswapV4Detf_Weighted_Univ4Se,
    UniswapV4Detf_Stage11PolicySuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Weighted_Univ4Se, UniswapV4Detf_Stage11PolicySuite)
    {
        TestBase_UniswapV4Detf_Weighted_Univ4Se.setUp();
        policyCreator = makeAddr("creator");
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_ProdSe)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted_ProdSe._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_ProdSe)
    {
        TestBase_UniswapV4Detf_Weighted_ProdSe._assertNoJoinableDust();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override
        returns (address)
    {
        return _deployWeightedHookThenDetf(args);
    }

    function _baseArgs() internal override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(2);
    }














    function test_T6_openingLengthMismatch_reverts() public {
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.name = "BadOpenLen Wgt S11";
        args.symbol = "bOLWS11";
        args.openingPairPerDetfWad = new uint256[](1);
        args.openingPairPerDetfWad[0] = LAUNCH_RICH_START;
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        this.deployInstanceExternal(args);
    }

    function deployInstanceExternal(IUniswapV4Detf.PkgArgs memory args) external {
        _deployInstance(args);
    }

    function test_T8_4_policy_pairA_not_pairB_via_trades() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        address[] memory toks_ = IUniswapV4SeBufferHook(info.hook()).tokens();
        address a_;
        address b_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            if (a_ == address(0)) a_ = toks_[i];
            else if (b_ == address(0) && toks_[i] != a_) b_ = toks_[i];
        }
        IERC20 pairA = IERC20(a_);
        IERC20 pairB = IERC20(b_);
        _assertPairPolicyWithPublicTrades(d, pairA, pairB);
    }

}
