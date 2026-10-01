// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {Uv4DetfDonateDuringUnlockHarness} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital_PonsV2Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_PonsV2Se.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {UniswapV4Detf_Stage11OpenSuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11OpenSuite.sol";

/// @notice H_OR_P2 Stage 11 Open (§7.0). Layer abstracts only (R-24).
contract UniswapV4Detf_Orbital_PonsV2Se_ProductLaw is
    TestBase_UniswapV4Detf_Orbital_PonsV2Se,
    UniswapV4Detf_Stage11OpenSuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Orbital_PonsV2Se, UniswapV4Detf_Stage11OpenSuite)
    {
        TestBase_UniswapV4Detf_Orbital_PonsV2Se.setUp();
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

    /// @notice A real nested donation retains sub-share capital, retries safely and cannot fund a free mint.
    function test_DN22_terminalResidual_booked_repeatSweep_noFreePretransfer() public {
        test_DN22_donate_whilePoolManagerUnlocked();
        IERC20 pair_ = _openPairToken();
        uint256 retained_ = pair_.balanceOf(detf);
        assertGt(retained_, 10, "exercise retained capital above native dust floor");
        assertEq(IBasicVault(detf).reserveOfToken(address(pair_)), retained_, "all retained capital booked");

        Uv4DetfDonateDuringUnlockHarness harness_ = new Uv4DetfDonateDuringUnlockHarness(pm);
        address se_ = IUniswapV4SeBufferHook(detfInfo.hook()).standardExchangeOf(address(pair_));
        (bytes memory state_,) = abi.decode(harness_.run(se_, abi.encodeCall(
            IStandardExchangeTransitionQuote.quoteState, (address(pair_), detf)
        )), (bytes, uint256));
        assertLt(retained_, IStandardExchangeExactOutputQuantityQuote(se_).quoteInputForExactShares(state_, 1),
            "actual blocked snapshot proves less than one share");

        bytes32 before_ = keccak256(abi.encode(_snapLive(dnUserOriginal)));
        for (uint256 i_; i_ < 2; ++i_) {
            harness_.run(detf, abi.encodeCall(IUniswapV4Detf.sweepDust, ()));
            assertEq(pair_.balanceOf(detf), retained_, "blocked retry retains custody");
            assertEq(IBasicVault(detf).reserveOfToken(address(pair_)), retained_, "blocked retry retains booking");
            assertEq(keccak256(abi.encode(_snapLive(dnUserOriginal))), before_, "retry issues no shares or LP");
        }

        bytes memory unpaid_ = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (pair_, retained_, IERC20(detf), 0, address(harness_), true, _deadline()));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, retained_, 0));
        harness_.run(detf, unpaid_);
        assertEq(pair_.balanceOf(detf), retained_, "failed pretransfer retains custody");
        assertEq(IBasicVault(detf).reserveOfToken(address(pair_)), retained_, "failed pretransfer retains booking");
        assertEq(keccak256(abi.encode(_snapLive(dnUserOriginal))), before_, "failed pretransfer is atomic");
    }
}
