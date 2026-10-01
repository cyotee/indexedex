// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {HermeticWETH} from "contracts/protocols/staking/etherfi/test/hermetic/HermeticEtherFiPorts.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {EETH} from "@crane/contracts/external/etherfi/core/EETH.sol";
import {WeETH} from "@crane/contracts/external/etherfi/core/WeETH.sol";
import {ERC1967Proxy} from "@crane/contracts/external/openzeppelin-contracts-v4/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    IEtherFiWeETHStandardVault
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {NativeEtherFiPool, NativeEtherFiPolicy} from "contracts/test/stubs/NativeEtherFiPorts.sol";

/// @dev External adversarial token; canonical WETH transfer must remain nominally exact.
contract EtherFiShortDeliveryWETH is HermeticWETH {
    bool public shortDelivery = true;

    function setShortDelivery(bool enabled_) external {
        shortDelivery = enabled_;
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override returns (bool) {
        return super.transferFrom(from_, to_, shortDelivery ? amount_ - 1 : amount_);
    }
}

contract EtherFiWeETHStandardExchange_NativeRounding is TestBase_EtherFiWeETHStandardExchange {
    EETH internal nativeE;
    WeETH internal nativeWe;
    NativeEtherFiPool internal nativePool;
    AtomicPretransferCaller internal atomic;
    address internal recipient = address(0xA11CE);

    function setUp() public override {
        super.setUp();
        NativeEtherFiPolicy policy_ = new NativeEtherFiPolicy();
        nativePool = new NativeEtherFiPool(policy_);
        EETH implementation_ = new EETH(address(nativePool), address(policy_), address(policy_), address(policy_));
        nativeE = EETH(address(new ERC1967Proxy(address(implementation_), abi.encodeCall(EETH.initialize, ()))));
        nativePool.bind(nativeE);
        WeETH wrapped_ = new WeETH(address(nativeE), address(nativePool), address(policy_), address(policy_));
        nativeWe = WeETH(address(new ERC1967Proxy(address(wrapped_), abi.encodeCall(WeETH.initialize, ()))));
        vm.deal(address(this), 200 ether);
        nativePool.deposit{value: 100 ether}();
        nativePool.setPooled(150 ether);
        nativeE.approve(address(nativeWe), 60 ether);
        nativeWe.wrap(60 ether);
        vm.prank(owner);
        seVault = etherFiSeDFPkg.deployVault(
            address(nativeE),
            address(nativeWe),
            address(hermeticWeth),
            address(nativePool),
            address(hermeticQueue),
            address(0)
        );
        etherFiSe = IEtherFiWeETHStandardVault(seVault);
        seIn = IStandardExchangeIn(seVault);
        seOut = IStandardExchangeOut(seVault);
        nativeWe.approve(seVault, type(uint256).max);
        nativeE.approve(seVault, type(uint256).max);
        seIn.exchangeIn(IERC20(address(nativeWe)), 20 ether, IERC20(seVault), 1, address(this), false, block.timestamp);
        _fundSleeve(20 ether);
        atomic = new AtomicPretransferCaller();
        nativeE.approve(address(atomic), type(uint256).max);
    }

    function _book() internal view returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(nativeE));
    }

    function _assertBooks() internal view {
        assertEq(_book(), nativeE.balanceOf(seVault));
        assertEq(IBasicVault(seVault).reserveOfToken(address(nativeWe)), nativeWe.balanceOf(seVault));
        assertGe(nativeE.shares(address(nativeWe)), nativeWe.totalSupply(), "real wrapper remains natively backed");
    }

    function _receive(uint256 held_, uint256 nominal_) internal view returns (uint256) {
        return
            nativePool.amountForShare(held_ + nativePool.sharesForAmount(nominal_)) - nativePool.amountForShare(held_);
    }

    function test_APEX_nativePullWrapCreditsOnlyActualReceipt() public {
        uint256 expected_ = nativePool.sharesForAmount(_receive(nativeE.shares(seVault), 5));
        uint256 before_ = nativeWe.balanceOf(recipient);
        uint256 out_ = seIn.exchangeIn(
            IERC20(address(nativeE)), 5, IERC20(address(nativeWe)), expected_, recipient, false, block.timestamp
        );
        assertEq(out_, expected_);
        assertEq(nativeWe.balanceOf(recipient) - before_, out_);
        _assertBooks();
    }

    function test_APEX_nativeUnwrapReportsActualRecipientDelta() public {
        uint256 expected_ = _receive(0, _receive(nativeE.shares(seVault), nativePool.amountForShare(5)));
        uint256 out_ = seIn.exchangeIn(
            IERC20(address(nativeWe)), 5, IERC20(address(nativeE)), expected_, recipient, false, block.timestamp
        );
        assertEq(out_, nativeE.balanceOf(recipient), "return is actual native delivery");
        assertEq(out_, expected_);
        _assertBooks();
    }

    function test_APEX_nativeUnwrapMinimumUsesActualRecipientDelta() public {
        bytes32 beforeState_ = _state();
        uint256 before_ = nativeWe.balanceOf(address(this));
        vm.expectRevert(IEtherFiWeETHStandardVault.Slippage.selector);
        seIn.exchangeIn(IERC20(address(nativeWe)), 5, IERC20(address(nativeE)), 7, recipient, false, block.timestamp);
        assertEq(nativeWe.balanceOf(address(this)), before_);
        assertEq(nativeE.balanceOf(recipient), 0);
        assertEq(_state(), beforeState_, "complete minimum failure rollback");
    }

    function test_APEX_nativeExactOutUnwrapDeliversRequestedMinimum() public {
        uint256 quote_ = seOut.previewExchangeOut(IERC20(address(nativeWe)), IERC20(address(nativeE)), 7);
        uint256 before_ = nativeWe.balanceOf(address(this));
        uint256 paid_ = seOut.exchangeOut(
            IERC20(address(nativeWe)), quote_, IERC20(address(nativeE)), 7, recipient, false, block.timestamp
        );
        assertEq(paid_, quote_);
        assertEq(before_ - nativeWe.balanceOf(address(this)), paid_);
        assertGe(nativeE.balanceOf(recipient), 7);
        _assertBooks();
    }

    function test_APEX_nativeExactOutPullWrapCoversBothFloors() public {
        uint256 quote_ = seOut.previewExchangeOut(IERC20(address(nativeE)), IERC20(address(nativeWe)), 7);
        uint256 beforeShares_ = nativeE.shares(address(this));
        uint256 paid_ = seOut.exchangeOut(
            IERC20(address(nativeE)), quote_, IERC20(address(nativeWe)), 7, recipient, false, block.timestamp
        );
        assertEq(paid_, quote_);
        assertEq(beforeShares_ - nativeE.shares(address(this)), nativePool.sharesForAmount(paid_));
        assertGe(nativeWe.balanceOf(recipient), 7);
        _assertBooks();
    }

    function test_APEX_nativePrepaidExactInUsesAlreadyDeliveredCredit() public {
        uint256 payer_ = nativeE.shares(address(this));
        uint256 out_ = abi.decode(
            atomic.consumePretransfer(
                IERC20(address(nativeE)),
                address(this),
                seVault,
                14,
                abi.encodeCall(
                    IStandardExchangeIn.exchangeIn,
                    (IERC20(address(nativeE)), 11, IERC20(address(nativeWe)), 7, recipient, true, block.timestamp)
                )
            ),
            (uint256)
        );
        assertEq(out_, 7);
        assertEq(nativeWe.balanceOf(recipient), 7);
        assertEq(nativeE.shares(address(this)), payer_ - nativePool.sharesForAmount(14));
        assertEq(nativeE.balanceOf(address(atomic)), 0, "exact input never refunds");
        assertGt(nativeE.balanceOf(seVault), 0);
        _assertBooks();
    }

    function test_APEX_nativePrepaidExactOutUsesCreditAndBoundsRefund() public {
        uint256 paid_ = abi.decode(
            atomic.consumePretransfer(
                IERC20(address(nativeE)),
                address(this),
                seVault,
                14,
                abi.encodeCall(
                    IStandardExchangeOut.exchangeOut,
                    (IERC20(address(nativeE)), 13, IERC20(address(nativeWe)), 7, recipient, true, block.timestamp)
                )
            ),
            (uint256)
        );
        assertEq(paid_, 11, "prepaid input skips incoming transfer inverse");
        assertEq(nativeWe.balanceOf(recipient), 7);
        assertEq(nativeE.shares(address(atomic)), nativePool.sharesForAmount(13 - paid_));
        assertLe(nativeE.balanceOf(address(atomic)), 13 - paid_);
        _assertBooks();
    }

    function test_APEX_nativeShareRedemptionReportsActualDeliveryAndHonorsClaimBudget() public {
        uint256 shares_ = IERC20(seVault).balanceOf(address(this)) / 13;
        uint256 budget_ = seIn.previewExchangeIn(IERC20(seVault), shares_, IERC20(address(nativeWe)));
        uint256 before_ = nativeWe.balanceOf(seVault);
        uint256 out_ =
            seIn.exchangeIn(IERC20(seVault), shares_, IERC20(address(nativeE)), 1, recipient, false, block.timestamp);
        assertEq(out_, nativeE.balanceOf(recipient));
        assertLe(before_ - nativeWe.balanceOf(seVault), budget_, "native exact input does not overspend share claim");
        _assertBooks();
    }

    function _state() internal view returns (bytes32 state_) {
        address[6] memory holders_ =
            [address(this), seVault, recipient, address(atomic), address(nativeWe), address(nativePool)];
        IERC20[4] memory tokens_ =
            [IERC20(address(nativeE)), IERC20(address(nativeWe)), IERC20(address(hermeticWeth)), IERC20(seVault)];
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            state_ = keccak256(
                abi.encode(state_, tokens_[i_].totalSupply(), IBasicVault(seVault).reserveOfToken(address(tokens_[i_])))
            );
            for (uint256 j_; j_ < holders_.length; ++j_) {
                state_ = keccak256(
                    abi.encode(
                        state_,
                        tokens_[i_].balanceOf(holders_[j_]),
                        tokens_[i_].allowance(holders_[j_], seVault),
                        tokens_[i_].allowance(holders_[j_], address(atomic))
                    )
                );
            }
        }
        for (uint256 j_; j_ < holders_.length; ++j_) {
            state_ = keccak256(abi.encode(state_, nativeE.shares(holders_[j_]), holders_[j_].balance));
        }
        return keccak256(
            abi.encode(
                state_, nativeE.totalShares(), nativePool.pooled(), nativeE.allowance(seVault, address(nativeWe))
            )
        );
    }

    function _in(IERC20 token_, uint256 amount_, IERC20 output_, uint256 minimum_) internal returns (uint256) {
        return seIn.exchangeIn(token_, amount_, output_, minimum_, recipient, false, block.timestamp);
    }

    function _nativeShareSum() internal view returns (uint256) {
        return nativeE.shares(address(this)) + nativeE.shares(seVault) + nativeE.shares(recipient)
            + nativeE.shares(address(atomic)) + nativeE.shares(address(nativeWe));
    }

    function _bookIdle() internal returns (uint256 held_) {
        nativeE.transfer(seVault, 5);
        _in(IERC20(address(nativeWe)), 3, IERC20(address(hermeticWeth)), 4);
        held_ = nativeE.shares(seVault);
        assertGt(held_, 0);
        _assertBooks();
    }

    function test_APEX_nativeExactInMintCreditsWrappedValue() public {
        uint256 received_ = _receive(nativeE.shares(seVault), 11);
        uint256 wrapped_ = nativePool.sharesForAmount(received_);
        uint256 quote_ = seIn.previewExchangeIn(IERC20(address(nativeWe)), wrapped_, IERC20(seVault));
        uint256 before_ = nativeWe.balanceOf(seVault);
        assertEq(seIn.previewExchangeIn(IERC20(address(nativeE)), 11, IERC20(seVault)), quote_);
        assertEq(_in(IERC20(address(nativeE)), 11, IERC20(seVault), quote_), quote_);
        assertEq(IERC20(seVault).balanceOf(recipient), quote_);
        assertEq(nativeWe.balanceOf(seVault) - before_, wrapped_);
        _assertBooks();
    }

    function test_APEX_nativeExactOutMintCoversIncomingFloor() public {
        uint256 wanted_ = 7000;
        uint256 quote_ = seOut.previewExchangeOut(IERC20(address(nativeE)), IERC20(seVault), wanted_);
        uint256 before_ = nativeE.shares(address(this));
        assertEq(
            seOut.exchangeOut(
                IERC20(address(nativeE)), quote_, IERC20(seVault), wanted_, recipient, false, block.timestamp
            ),
            quote_
        );
        assertEq(IERC20(seVault).balanceOf(recipient), wanted_);
        assertEq(before_ - nativeE.shares(address(this)), nativePool.sharesForAmount(quote_));
        _assertBooks();
    }

    function test_APEX_nativeInventoryWethPaysOnlyRetainedValue() public {
        uint256 before_ = nativeWe.balanceOf(seVault);
        uint256 liquid_ = hermeticWeth.balanceOf(seVault);
        uint256 expected_ = nativePool.amountForShare(nativePool.sharesForAmount(_receive(nativeE.shares(seVault), 11)));
        assertEq(_in(IERC20(address(nativeE)), 11, IERC20(address(hermeticWeth)), expected_), expected_);
        assertEq(hermeticWeth.balanceOf(recipient), expected_);
        assertEq(
            liquid_ - hermeticWeth.balanceOf(seVault), nativePool.amountForShare(nativeWe.balanceOf(seVault) - before_)
        );
        _assertBooks();
    }

    function test_APEX_nativeInventoryTransitionMatchesWrappedValue() public {
        (bytes memory state_,) =
            IStandardExchangeTransitionQuote(seVault).quoteState(address(hermeticWeth), address(this));
        (bytes memory next_, uint256 projected_, uint256 holder_) =
            IStandardExchangeExternalQuote(seVault).quoteExternalExchange(state_, address(nativeE), 11);
        assertEq(projected_, 9);
        assertEq(_in(IERC20(address(nativeE)), 11, IERC20(address(hermeticWeth)), projected_), projected_);
        (bytes memory actual_, uint256 actualHolder_) =
            IStandardExchangeTransitionQuote(seVault).quoteState(address(hermeticWeth), address(this));
        assertEq(keccak256(next_), keccak256(actual_), "entire projected state matches custody and native shares");
        assertEq(holder_, actualHolder_);
        _assertBooks();
    }

    function test_APEX_nativeExactOutBudgetFailureRollsBackAtomicFunding() public {
        bytes32 before_ = _state();
        vm.expectRevert(IEtherFiWeETHStandardVault.Slippage.selector);
        atomic.consumePretransfer(
            IERC20(address(nativeE)),
            address(this),
            seVault,
            14,
            abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (IERC20(address(nativeE)), 10, IERC20(address(nativeWe)), 7, recipient, true, block.timestamp)
            )
        );
        assertEq(_state(), before_, "atomic native shares, books and allowances rollback");
    }

    function test_APEX_nativeHeldBookSurvivesBoundedRefund() public {
        uint256 held_ = _bookIdle();
        uint256 shares_ = _nativeShareSum();
        uint256 paid_ = abi.decode(
            atomic.consumePretransfer(
                IERC20(address(nativeE)),
                address(this),
                seVault,
                14,
                abi.encodeCall(
                    IStandardExchangeOut.exchangeOut,
                    (IERC20(address(nativeE)), 12, IERC20(address(nativeWe)), 7, recipient, true, block.timestamp)
                )
            ),
            (uint256)
        );
        assertEq(paid_, 11);
        assertGe(nativeE.shares(seVault), held_, "held native book never funds wrap or refund");
        assertLe(nativeE.balanceOf(address(atomic)), 12 - paid_, "refund never includes excess delivery");
        assertEq(_nativeShareSum(), shares_, "all native shares remain owned across transfer/wrap/refund");
        _assertBooks();
    }

    function test_APEX_nativeExactOutShareRedemptionFundsRecipient() public {
        uint256 shares_ = IERC20(seVault).balanceOf(address(this));
        uint256 quote_ = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(nativeE)), 7);
        uint256 paid_ =
            seOut.exchangeOut(IERC20(seVault), quote_, IERC20(address(nativeE)), 7, recipient, false, block.timestamp);
        assertEq(paid_, quote_);
        assertEq(shares_ - IERC20(seVault).balanceOf(address(this)), quote_);
        assertGe(nativeE.balanceOf(recipient), 7);
        _assertBooks();
    }

    function test_APEX_nativeNonemptyRecipientReceivesMeasuredDelta() public {
        nativeE.transfer(recipient, 5);
        uint256 before_ = nativeE.balanceOf(recipient);
        uint256 quote_ = seIn.previewExchangeIn(IERC20(address(nativeWe)), 5, IERC20(address(nativeE)));
        uint256 delivered_ = _in(IERC20(address(nativeWe)), 5, IERC20(address(nativeE)), quote_);
        assertEq(delivered_, nativeE.balanceOf(recipient) - before_);
        assertGe(delivered_, quote_);
        _assertBooks();
    }

    function test_APEX_nativeWethStakeUsesActualTransfer() public {
        _dealWeth(address(this), 11);
        hermeticWeth.approve(seVault, 11);
        uint256 quote_ = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), 11, IERC20(address(nativeE)));
        assertEq(quote_, 9);
        assertEq(_in(IERC20(address(hermeticWeth)), 11, IERC20(address(nativeE)), quote_), quote_);
        assertEq(nativeE.balanceOf(recipient), quote_);
        _assertBooks();
    }

    function test_APEX_nativeZeroReceiptRejectsAndRollsBack() public {
        bytes32 before_ = _state();
        vm.expectRevert(WeETH.ZeroAmount.selector);
        _in(IERC20(address(nativeE)), 1, IERC20(seVault), 0);
        assertEq(_state(), before_, "zero native delivery issues no shares");
    }

    function testFuzz_APEX_nativePullWrapConservesShares(uint96 amountSeed_, uint64 rateSeed_, uint96 idleSeed_)
        public
    {
        uint256 amount_ = bound(uint256(amountSeed_), 10, 1 ether);
        uint256 rate_ = bound(uint256(rateSeed_), 0.5 ether, 3 ether);
        nativePool.setPooled(Math.mulDiv(nativeE.totalShares(), rate_, 1 ether));
        uint256 idle_ = bound(uint256(idleSeed_), 0, 1000);
        if (idle_ != 0) nativeE.transfer(seVault, idle_);
        uint256 held_ = nativeE.shares(seVault);
        uint256 sum_ = _nativeShareSum();
        uint256 incoming_ = nativePool.sharesForAmount(amount_);
        uint256 expected_ = nativePool.sharesForAmount(_receive(held_, amount_));
        uint256 quote_ = seIn.previewExchangeIn(IERC20(address(nativeE)), amount_, IERC20(address(nativeWe)));
        assertEq(quote_, expected_);
        assertEq(_in(IERC20(address(nativeE)), amount_, IERC20(address(nativeWe)), quote_), expected_);
        assertEq(nativeWe.balanceOf(recipient), expected_);
        assertEq(
            nativeE.shares(seVault) + expected_,
            held_ + incoming_,
            "native input shares split only into wrapper and held dust"
        );
        assertEq(_nativeShareSum(), sum_);
        _assertBooks();
    }

    function testFuzz_APEX_nativeExactOutStakeFundsDelivery(uint96 amountSeed_, uint64 rateSeed_, bool wrappedOutput_)
        public
    {
        uint256 amount_ = bound(uint256(amountSeed_), 3, 1 ether);
        uint256 rate_ = bound(uint256(rateSeed_), 0.5 ether, 3 ether);
        nativePool.setPooled(Math.mulDiv(nativeE.totalShares(), rate_, 1 ether));
        nativeE.transfer(seVault, 5);
        nativeE.transfer(recipient, 7);
        IERC20 output_ = wrappedOutput_ ? IERC20(address(nativeWe)) : IERC20(address(nativeE));
        uint256 before_ = output_.balanceOf(recipient);
        uint256 quote_ = seOut.previewExchangeOut(IERC20(address(hermeticWeth)), output_, amount_);
        _dealWeth(address(this), quote_);
        hermeticWeth.approve(seVault, quote_);
        uint256 paid_ = seOut.exchangeOut(
            IERC20(address(hermeticWeth)), quote_, output_, amount_, recipient, false, block.timestamp
        );
        assertEq(paid_, quote_);
        assertGe(output_.balanceOf(recipient) - before_, amount_);
        _assertBooks();
    }

    function test_APEX_nativeCorrectionKeepsOtherTokenPullsStrict() public {
        EtherFiShortDeliveryWETH short_ = new EtherFiShortDeliveryWETH();
        hermeticWeth = short_;
        vm.prank(owner);
        seVault = etherFiSeDFPkg.deployVault(
            address(nativeE),
            address(nativeWe),
            address(short_),
            address(nativePool),
            address(hermeticQueue),
            address(0)
        );
        seIn = IStandardExchangeIn(seVault);
        _dealWeth(address(this), 100);
        short_.approve(seVault, 100);
        bytes32 before_ = _state();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100, 99));
        _in(IERC20(address(short_)), 100, IERC20(seVault), 0);
        assertEq(_state(), before_, "other token short delivery rolls back balances/books/allowances");
        short_.setShortDelivery(false);
        assertGt(_in(IERC20(address(short_)), 100, IERC20(seVault), 1), 0);
        _assertBooks();
    }
}
