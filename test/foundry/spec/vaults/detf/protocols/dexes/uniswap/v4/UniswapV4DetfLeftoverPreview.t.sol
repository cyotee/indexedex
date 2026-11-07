// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Vm} from "forge-std/Vm.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf_Cp_Univ3Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ3Se.sol";

/// @notice RC-06: residual decisions use the real SE preview through the production DETF sweep.
/// @dev This fixture's FullSpread SE does not advertise the optional exact-output quantity interface.
/// It proves the public sweep outcome, not an isolated write by the private retention helper.
contract UniswapV4DetfLeftoverPreview_Test is TestBase_UniswapV4Detf_Cp_Univ3Se {
    struct Balances {
        uint256 held;
        uint256 booked;
        uint256 sePair;
        uint256 seSupply;
        uint256 detfSupply;
        uint256 lp;
        uint256 caller;
        uint256 feeRecipient;
    }

    /// @notice Activate the real reserve through the production first-bond path.
    function setUp() public override {
        super.setUp();
        _firstBond(100 ether);
        assertEq(detfInfo.isReserveLive(), true);
        assertEq(mintToken, address(pairToken));
        assertEq(IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(mintToken), se);
        assertEq(IERC165(se).supportsInterface(type(IStandardExchangeExactOutputQuantityQuote).interfaceId), false);
    }

    /// @notice A zero preview retains custody and books all local tokens, including earlier retained tokens.
    function test_RC06_zeroPreview_retainsTokensAndBooksFullLocalBalance() public {
        // Raise backing per share using only the fixture's funding tokens.
        pairToken.mint(se, 1e30);
        seOther.mint(se, 1e30);
        pairToken.mint(detf, 100);
        _assertZeroPreviewSweep(true);
        uint256 booked_ = IBasicVault(detf).reserveOfToken(mintToken);
        pairToken.mint(detf, 100);
        assertEq(pairToken.balanceOf(detf), booked_ + 100, "new residual shares the existing local balance");
        _assertZeroPreviewSweep(false);
        assertEq(IBasicVault(detf).reserveOfToken(mintToken), booked_ + 100, "not only the latest residual");
    }

    /// @notice A funded one-leg residual uses the restored paid unbalanced route.
    function test_RC06_nonzeroPreview_usesPaidUnbalancedJoin() public {
        pairToken.mint(detf, 5 ether);
        Balances memory before_ = _balances();
        assertGt(_preview(before_.held), 0, "nonzero actual-amount SE preview");
        address[] memory tokens_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);
        tokens_[0] = mintToken;
        amounts_[0] = before_.held;
        IUniswapV4SeBufferHook hook_ = IUniswapV4SeBufferHook(reserveHook);
        uint256 expectedLp_ = hook_.previewJoinUnbalanced(tokens_, amounts_);
        assertGt(expectedLp_, 0, "paid route can deploy this residual");
        assertEq(expectedLp_, hook_.previewJoinSingleAssetExactIn(mintToken, before_.held));
        uint256 supplyBefore_ = IERC20(reserveHook).totalSupply();
        vm.expectCall(reserveHook, abi.encodeWithSelector(
            IUniswapV4SeBufferHook.joinUnbalanced.selector, tokens_, amounts_,
            detfInfo.bondNftVault(), expectedLp_, block.timestamp + 1
        ));
        vm.recordLogs();
        detfInfo.sweepDust{gas: 30_000_000}();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 minted_;
        uint256 custodyMinted_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != reserveHook || logs_[i_].topics.length != 3
                || logs_[i_].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            if (logs_[i_].topics[1] == bytes32(0)) {
                uint256 amount_ = abi.decode(logs_[i_].data, (uint256));
                minted_ += amount_;
                if (address(uint160(uint256(logs_[i_].topics[2]))) == detfInfo.bondNftVault()) custodyMinted_ += amount_;
            }
            assertTrue(logs_[i_].topics[2] != bytes32(0), "sweep does not unwind existing LP");
        }
        assertGe(custodyMinted_, expectedLp_);
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()) - before_.lp, custodyMinted_);
        assertEq(IERC20(reserveHook).totalSupply(), supplyBefore_ + minted_);
        assertLt(pairToken.balanceOf(detf), before_.held, "mintable residual deployed");
        assertEq(IBasicVault(detf).reserveOfToken(mintToken), pairToken.balanceOf(detf), "book remaining local custody");
        assertEq(IERC20(detf).totalSupply(), before_.detfSupply, "no new user entitlement");
        assertEq(pairToken.balanceOf(address(this)), before_.caller, "no caller payout");
        assertEq(pairToken.balanceOf(address(feeCollector)), before_.feeRecipient, "no fee-recipient payout");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "LP belongs in NFT custody");
        assertEq(pairToken.allowance(detf, reserveHook), 0, "join approval cleared");
        assertEq(pairToken.allowance(detf, se), 0, "SE approval cleared");
        _assertNoJoinableDust();
    }

    /// @notice A failure inside the real SE preview propagates and leaves the prior reserve unchanged.
    function test_RC06_revertingPreview_doesNotBookOrDeposit() public {
        pairToken.mint(detf, 100);
        Balances memory before_ = _balances();
        bytes memory failure_ = abi.encodeWithSignature("ResidualPreviewDependencyFailure()");
        // Fault only a non-SUT funding token query. Both SE and DETF proxies remain real.
        vm.mockCallRevert(address(seOther), abi.encodeWithSelector(IERC20.balanceOf.selector, se), failure_);
        vm.expectRevert(failure_);IStandardExchangeIn(se).previewExchangeIn(IERC20(mintToken), before_.held, IERC20(se));
        vm.expectRevert(failure_);
        detfInfo.sweepDust{gas: 30_000_000}();
        vm.clearMockedCalls();
        assertEq(IBasicVault(detf).reserveOfToken(mintToken), before_.booked, "failed preview books nothing");
        _assertUnmoved(before_);
    }

    function _assertZeroPreviewSweep(bool expectNoOneShareQuote_) internal {
        Balances memory before_ = _balances();
        assertGt(before_.held, 0, "funded residual");
        assertEq(_preview(before_.held), 0, "actual residual cannot mint a share");
        vm.expectCall(se, abi.encodeWithSelector(
            IStandardExchangeIn.previewExchangeIn.selector, IERC20(mintToken), before_.held, IERC20(se)
        ));
        if (expectNoOneShareQuote_) {
            vm.expectCall(se, abi.encodeWithSelector(
                IStandardExchangeExactOutputQuantityQuote.quoteInputForExactShares.selector
            ), uint64(0));
        }
        detfInfo.sweepDust{gas: 30_000_000}();
        assertEq(IBasicVault(detf).reserveOfToken(mintToken), before_.held, "book full local custody");
        _assertUnmoved(before_);
    }

    function _preview(uint256 amount_) internal view returns (uint256) {(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(mintToken), amount_, IERC20(se));
        return quotedAmountOut;
    }

    function _balances() internal view returns (Balances memory b_) {
        b_.held = pairToken.balanceOf(detf);
        b_.booked = IBasicVault(detf).reserveOfToken(mintToken);
        b_.sePair = pairToken.balanceOf(se);
        b_.seSupply = IERC20(se).totalSupply();
        b_.detfSupply = IERC20(detf).totalSupply();
        b_.lp = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        b_.caller = pairToken.balanceOf(address(this));
        b_.feeRecipient = pairToken.balanceOf(address(feeCollector));
    }

    function _assertUnmoved(Balances memory before_) internal view {
        assertEq(pairToken.balanceOf(detf), before_.held, "residual not deposited");
        assertEq(pairToken.balanceOf(se), before_.sePair, "no SE deposit");
        assertEq(IERC20(se).totalSupply(), before_.seSupply, "no SE shares issued");
        assertEq(IERC20(detf).totalSupply(), before_.detfSupply, "no DETF shares issued");
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), before_.lp, "no LP issued");
        assertEq(pairToken.balanceOf(address(this)), before_.caller, "no caller payout");
        assertEq(pairToken.balanceOf(address(feeCollector)), before_.feeRecipient, "no fee-recipient payout");
    }
}
