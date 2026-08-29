// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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

    function _ownerSwap(address d, address tokenIn, address tokenOut, uint256 amount)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._ownerSwap(d, tokenIn, tokenOut, amount);
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

    function test_policy_burn_allowed_when_synthetic_below_burnThreshold() public override {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        if (info.isMintingAllowed()) {
            _mintOn(d, LIVE_MINT_AMT);
        }
        for (uint256 i; i < 40 && !info.isBurningAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        assertTrue(info.isBurningAllowed(), "burn allowed");
        IERC20 tok_ = _burnAllowedToken(d);
        assertTrue(info.isBurningAllowed(tok_), "token burn allowed");
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        require(bal_ > 0, "need free DETF to burn");
        uint256 burnAmt_ = bal_ / 10;
        if (burnAmt_ == 0) burnAmt_ = bal_;
        info.compoundProtocolRewards();
        tok_ = _burnAllowedToken(d);
        assertTrue(info.isBurningAllowed(tok_), "burn still allowed after realize");
        uint256 out_ = _burnOn(d, burnAmt_, tok_);
        assertGt(out_, 0, "burn succeeds below burnThreshold");
    }

    function test_D31_3_policyBurn_realizesThenGates() public override {
        address d = _deployD31LaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        if (info.isMintingAllowed()) _mintOn(d, LIVE_MINT_AMT);
        for (uint256 i; i < 40 && !info.isBurningAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        assertTrue(info.isBurningAllowed(), "D31-3 burn allowed");
        IERC20 tok_ = _burnAllowedToken(d);
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 2);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        uint256 nftBefore_ = IERC20(d).balanceOf(info.bondNftVault());
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        require(bal_ > 0, "D31-3 need DETF");
        uint256 burnAmt_ = bal_ / 10;
        if (burnAmt_ == 0) burnAmt_ = bal_;
        tok_ = _burnAllowedToken(d);
        if (!info.isBurningAllowed(tok_)) {
            vm.startPrank(detfUser);
            IERC20(d).approve(d, type(uint256).max);
            vm.expectRevert();
            info.burn(burnAmt_, tok_, 0, detfUser, _deadline());
            vm.stopPrank();
            assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-3 fail supply");
            assertEq(info.pendingExpansionDetf(), pending_, "D31-3 fail pending");
            return;
        }
        _burnOn(d, burnAmt_, tok_);
        if (pending_ > 0) {
            assertGe(IERC20(d).balanceOf(info.bondNftVault()), nftBefore_, "D31-3 realized or held");
        }
    }

    /// @notice R-13: Default mint table. Real donate/skew until pair A mint-allowed and pair B not, then live mint A.
    function test_T8_4_policy_pairA_not_pairB_via_trades() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 pairA = IERC20(address(pair0));
        IERC20 pairB = IERC20(address(pair1));
        IUniswapV4Detf.IoRoute[] memory mint_ = info.mintRoutes();
        assertTrue(_routeHas(mint_, address(pairA)), "Default mint includes A");
        assertTrue(_routeHas(mint_, address(pairB)), "Default mint includes B");

        // More pair raises that pair's synthetic (launch-rich). Donate A, dump B (DETF→B).
        for (uint256 i; i < 96 && (info.isMintingAllowed(pairB) || !info.isMintingAllowed(pairA)); ++i) {
            try this.donatePairExternal(d, pairA, 50 ether) {} catch {}
            uint256 bal_ = IERC20(d).balanceOf(detfUser);
            if (bal_ < 10 ether && info.isMintingAllowed(pairA)) {
                try this.mintExternal(d, LIVE_MINT_AMT) {} catch {}
                bal_ = IERC20(d).balanceOf(detfUser);
            }
            if (bal_ == 0) break;
            uint256 push_ = bal_ > 40 ether ? 40 ether : bal_;
            vm.prank(detfUser);
            IERC20(d).transfer(d, push_);
            _ownerSwap(d, d, address(pairB), push_);
        }
        assertTrue(info.isMintingAllowed(pairA), "A mintable via skew/donate");
        assertFalse(info.isMintingAllowed(pairB), "B not mintable");

        vm.startPrank(detfUser);
        uint256 out_ = info.mint(pairA, LIVE_MINT_AMT, 0, detfUser, false, _deadline());
        vm.stopPrank();
        assertGt(out_, 0, "live mint A");

        vm.startPrank(detfUser);
        vm.expectRevert();
        info.mint(pairB, 1 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
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
