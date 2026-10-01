// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {Uv4DetfDonateDuringUnlockHarness} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital_PonsV1Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_PonsV1Se.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {UniswapV4Detf_Stage11OpenSuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11OpenSuite.sol";

/// @notice H_OR_P1 Stage 11 Open (§7.0). Layer abstracts only (R-24).
contract UniswapV4Detf_Orbital_PonsV1Se_ProductLaw is
    TestBase_UniswapV4Detf_Orbital_PonsV1Se,
    UniswapV4Detf_Stage11OpenSuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Orbital_PonsV1Se, UniswapV4Detf_Stage11OpenSuite)
    {
        TestBase_UniswapV4Detf_Orbital_PonsV1Se.setUp();
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

    /// @notice Legacy V3 zero-share residuals stay booked across retries and cannot fund an unpaid mint.
    function test_DN22_legacyV3Residual_booked_repeatSweep_noFreePretransfer() public {
        test_DN22_donate_whilePoolManagerUnlocked();
        (IERC20 pair_, address se_, uint256 retained_) = _legacyZeroShareResidual();
        Uv4DetfDonateDuringUnlockHarness harness_ = new Uv4DetfDonateDuringUnlockHarness(pm);
        bytes32 before_ = _legacyResidualState(pair_, se_);
        for (uint256 i_; i_ < 2; ++i_) {
            harness_.run(detf, abi.encodeCall(IUniswapV4Detf.sweepDust, ()));
            _assertPairResidualBooked(address(pair_), se_);
            assertEq(_legacyResidualState(pair_, se_), before_, "retry preserves custody, supply and booking");
            assertEq(pair_.allowance(detf, reserveHook), 0, "no residual hook allowance");
            assertEq(pair_.allowance(reserveHook, se_), 0, "no residual SE allowance");
        }

        bytes memory unpaid_ = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (pair_, retained_, IERC20(detf), 0, address(harness_), true, _deadline()));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, retained_, 0));
        harness_.run(detf, unpaid_);
        assertEq(_legacyResidualState(pair_, se_), before_, "unpaid pretransfer is atomic");
    }

    /// @notice New real capital makes a previously zero-share residual joinable on a later sweep.
    function test_DN22_legacyV3Residual_laterFundedRetry() public {
        test_DN22_donate_whilePoolManagerUnlocked();
        (IERC20 pair_, address se_, uint256 retained_) = _legacyZeroShareResidual();
        // Derive a small, mintable top-up from this book, with room for the
        // hook's used-input rounding rather than retrying exactly at one share.
        uint256 topUp_ = retained_;
        for (uint256 i_; i_ < 64; ++i_) {
            if (IStandardExchangeIn(se_).previewExchangeIn(pair_, retained_ + topUp_, IERC20(se_)) >= 1024) break;
            topUp_ *= 2;
        }
        assertGt(topUp_, retained_, "fixture has real capital for retry");
        assertLe(topUp_, pair_.balanceOf(detfUser), "real holder funds the full top-up");
        assertGe(IStandardExchangeIn(se_).previewExchangeIn(pair_, retained_ + topUp_, IERC20(se_)), 1024,
            "accumulated input now buys SE shares");
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        uint256 seSupplyBefore_ = IERC20(se_).totalSupply();
        uint256 detfSupplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(detfUser);
        assertTrue(pair_.transfer(detf, topUp_), "fund retry from real holder");
        detfInfo.sweepDust();
        assertLt(pair_.balanceOf(detf), retained_ + topUp_, "retry consumes accumulated capital");
        assertGt(IERC20(se_).totalSupply(), seSupplyBefore_, "retry mints actual SE shares");
        assertGt(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lpBefore_, "retry acquires protocol LP");
        assertEq(IERC20(detf).totalSupply(), detfSupplyBefore_, "sweep issues no DETF");
        _assertNoJoinableDust();
        assertEq(pair_.allowance(detf, reserveHook), 0, "hook allowance cleared");
        assertEq(pair_.allowance(reserveHook, se_), 0, "SE allowance cleared");
    }

    /// @dev Discover the actual terminal residual; do not depend on CREATE3 addresses or rounding constants.
    function _legacyZeroShareResidual() private view returns (IERC20 pair_, address se_, uint256 retained_) {
        address[] memory tokens_ = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            address candidateSe_ = IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(tokens_[i_]);
            if (candidateSe_ == address(0) || candidateSe_ == tokens_[i_]) continue;
            uint256 balance_ = IERC20(tokens_[i_]).balanceOf(detf);
            if (balance_ <= 10) continue;
            assertFalse(IERC165(candidateSe_).supportsInterface(type(IStandardExchangeExactOutputQuantityQuote).interfaceId),
                "exercise explicit unsupported inverse");
            assertEq(IStandardExchangeIn(candidateSe_).previewExchangeIn(IERC20(tokens_[i_]), balance_, IERC20(candidateSe_)), 0,
                "entire residual independently previews zero shares");
            _assertPairResidualBooked(tokens_[i_], candidateSe_);
            return (IERC20(tokens_[i_]), candidateSe_, balance_);
        }
        revert("DN22 must leave a proven above-dust legacy V3 residual");
    }

    /// @dev Include the SE and hook supplies as well as the funded DETF ledger in no-issuance checks.
    function _legacyResidualState(IERC20 pair_, address se_) private view returns (bytes32) {
        return keccak256(abi.encode(
            _snapLive(dnUserOriginal), pair_.balanceOf(detf), IBasicVault(detf).reserveOfToken(address(pair_)),
            pair_.balanceOf(se_), pair_.balanceOf(reserveHook), IERC20(se_).totalSupply(),
            IERC20(se_).balanceOf(reserveHook), IERC20(reserveHook).totalSupply()
        ));
    }
}
