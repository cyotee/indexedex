// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Weighted_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Policy.sol";
import {UniswapV4Detf_PolicyBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_PolicyBase.sol";

/// @notice Weighted gold Policy / D31 / compound / Open expansion IDs (WP-UDPL-WE).
/// @dev T8.4 Policy instance via real reserve skew/donate (R-13). Custom-table T8.4 stays on UniswapV4Detf_Weighted.t.sol.
contract UniswapV4Detf_Weighted_Policy is
    TestBase_UniswapV4Detf_Weighted_Policy,
    UniswapV4Detf_PolicyBase
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Weighted_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }

    function _baseArgs()
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._baseArgs();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._deployInstance(args);
    }

    function _mintTokenOf(address d)
        internal
        view
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (IERC20)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._mintTokenOf(d);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._expectInvalidCreationRate(args);
    }



    function _pushSyntheticUp(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._pushSyntheticUp(d);
    }

    function _skewSyntheticDown(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._skewSyntheticDown(d);
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (uint256 amountOut)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._burnOn(d, detfIn, tokenOut);
    }





    /// @notice R-13: Default mint table. Real donate/skew until pair A mint-allowed and pair B not, then live mint A.
    function test_T8_4_policy_pairA_not_pairB_via_trades() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IERC20 pairA_ = IERC20(address(pair0));
        IERC20 pairB_ = IERC20(address(pair1));
        assertTrue(_routeHas(info_.mintRoutes(), address(pairA_)), "default mint includes A");
        assertTrue(_routeHas(info_.mintRoutes(), address(pairB_)), "default mint includes B");
        _ensureFreeDetf(d, 1e9);
        for (uint256 i_; i_ < 48 && (info_.isMintingAllowed(pairB_) || !info_.isMintingAllowed(pairA_)); ++i_) {
            _donatePair(d, pairA_, 50 ether);
            uint256 balance_ = IERC20(d).balanceOf(detfUser);
            if (balance_ < 1e9) {
                _mintOn(d, LIVE_MINT_AMT);
                balance_ = IERC20(d).balanceOf(detfUser);
            }
            uint256 input_ = balance_ / 2;
            uint256 reserveBudget_ = IERC20(d).balanceOf(info_.hook()) / 10;
            if (input_ > reserveBudget_) input_ = reserveBudget_;
            assertGt(input_, 0, "funded DETF available for public reserve swap");
            vm.startPrank(detfUser);
            IERC20(d).approve(info_.hook(), input_);
            IStandardExchangeIn(info_.hook()).exchangeIn(
                IERC20(d), input_, pairB_, 0, detfUser, false, _deadline()
            );
            vm.stopPrank();
        }
        assertTrue(info_.isMintingAllowed(pairA_), "A primary mint gate open");
        assertFalse(info_.isMintingAllowed(pairB_), "B primary mint gate closed");
        uint256 supply_ = IERC20(d).totalSupply();
        uint256 pending_ = info_.pendingExpansionDetf();
        _assertStandardSettlementOrder(d, pairB_, 1 ether, IERC20(d));
        assertEq(IERC20(d).totalSupply(), supply_ + pending_, "B uses funded reserve swap");
        assertTrue(info_.isMintingAllowed(pairA_), "A primary route remains available");
        supply_ = IERC20(d).totalSupply();
        _assertStandardSettlementOrder(d, pairA_, LIVE_MINT_AMT, IERC20(d));
        assertGt(IERC20(d).totalSupply(), supply_, "A executes new issuance");
    }

    function donatePairExternal(address d, IERC20 tok, uint256 amt) external {
        _donatePair(d, tok, amt);
    }

    function _routeHas(IUniswapV4Detf.IoRoute[] memory rows_, address token_)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < rows_.length; ++i) {
            if (address(rows_[i].token) == token_) return true;
        }
        return false;
    }
}
