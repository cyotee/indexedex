// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {TestBase_UniswapV4Detf_Quad_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Policy.sol";
import {UniswapV4Detf_PolicyBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_PolicyBase.sol";

/// @notice Quad gold Policy / D31 / compound / Open expansion IDs (WP-UDPL-QD).
contract UniswapV4Detf_Quad_Policy is TestBase_UniswapV4Detf_Quad_Policy, UniswapV4Detf_PolicyBase {
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function _baseArgs()
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Quad_Policy._baseArgs();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Quad_Policy._deployInstance(args);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy._expectInvalidCreationRate(args);
    }

    function _mintTokenOf(address d)
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
        returns (IERC20)
    {
        return TestBase_UniswapV4Detf_Quad_Policy._mintTokenOf(d);
    }

    function _pushSyntheticUp(address d)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy._pushSyntheticUp(d);
    }

    function _skewSyntheticDown(address d)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy._skewSyntheticDown(d);
    }

    function test_policy_mint_blocked_in_deadband_then_allowed_after_push() public override {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = _mintAllowedToken(d);
        assertTrue(info.isMintingAllowed(tok_), "launch-rich mint can pass");
        uint256 opened_ = _mintOn(d, LIVE_MINT_AMT);
        assertGt(opened_, 0, "mint while allowed");

        for (uint256 i; i < 24 && info.isMintingAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        assertFalse(info.isMintingAllowed(), "skewed into mint-blocked");
        vm.startPrank(detfUser);
        vm.expectRevert();
        info.mint(tok_, 1 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();

        for (uint256 j; j < 24 && !info.isMintingAllowed(); ++j) {
            _pushSyntheticUp(d);
        }
        assertTrue(info.isMintingAllowed(), "mint allowed after push");
        IERC20 mintTok_ = _mintAllowedToken(d);
        (uint256 grossPred, uint256 userPred,) = info.previewMint(mintTok_, LIVE_MINT_AMT);
        grossPred;
        vm.startPrank(detfUser);
        uint256 userOut_ = info.mint(mintTok_, LIVE_MINT_AMT, 0, detfUser, false, _deadline());
        vm.stopPrank();
        assertEq(userOut_, userPred, "preview==exec after push");
        assertGt(userOut_, 0);
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
}
