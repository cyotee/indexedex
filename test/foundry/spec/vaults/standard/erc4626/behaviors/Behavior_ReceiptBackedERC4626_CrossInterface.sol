// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC4626Errors} from "@crane/contracts/tokens/ERC4626/IERC4626Errors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ReceiptBackedERC4626Target} from "contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

/**
 * @title Behavior_ReceiptBackedERC4626_CrossInterface
 * @notice R14.17 — shared I/K cross-interface controls for the receipt-backed ERC-4626 adapter,
 *         exercised identically on the generic ERC-4626 SE and the Aave V3 Stata SE families.
 *
 * @dev The adapter (`IERC4626`) and the SE (`IStandardExchange`) share one durable booked ledger.
 *      Receipts booked through an adapter `deposit`/`mint` are holder backing, never pretransfer
 *      credit: a contract-caller `exchangeIn(receipt, …, pretransferred=true)` over the booked
 *      inventory reverts `TransferDeltaInsufficient(claimed, 0)` (I/K), while a genuine atomic
 *      push-and-consume of unbooked receipts succeeds (positive control). The end-route sync keeps
 *      `reserveOfToken(t) == balanceOf(t)`; a stale-high reserve never gates a later credit; and
 *      reverted adapter calls (`ZeroAmount`, `InvalidReceiver`, `ERC4626ExceededMaxWithdraw`)
 *      change nothing.
 *
 *      RED (vulnerable version): a balance-delta credit (or backing sourced from raw custody) would
 *      let the contract caller mint against holder-owned booked receipts; the I/K revert assertions
 *      and the unchanged-backing checks below would fail on both families.
 *
 *      Selectors re-derived with `cast sig` from the declaring source:
 *        - ISecurePullErrors.TransferDeltaInsufficient(uint256,uint256) = 0x0b7f868c
 *        - ReceiptBackedERC4626Target.ZeroAmount()                       = 0x1f2a2005
 *        - ReceiptBackedERC4626Target.InvalidReceiver()                  = 0x1e4ec46b
 *        - IERC4626Errors.ERC4626ExceededMaxWithdraw(address,uint256,uint256) = 0xfe9cceec
 */
abstract contract Behavior_ReceiptBackedERC4626_CrossInterface is Test {
    /* ------------------------------- host hooks ------------------------------- */
    function _se() internal view virtual returns (address);
    function _receipt() internal view virtual returns (IERC20);
    function _underlyingToken() internal view virtual returns (IERC20);
    function _actor() internal view virtual returns (address);

    /// @dev Give `_actor()` `human` (human units) of the receipt via a real deposit, approved to the SE.
    function _giveActorReceipts(uint256 human) internal virtual returns (uint256 receiptsOut);

    /// @dev Hosts override setUp; keep the multi-base override explicit.
    function setUp() public virtual {}

    /* ------------------------------- helpers ---------------------------------- */

    function _assertAllReservesSynced() internal view {
        address[] memory tokens = IBasicVault(_se()).vaultTokens();
        assertGt(tokens.length, 0, "vault has tokens");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(
                IBasicVault(_se()).reserveOfToken(tokens[i]),
                IERC20(tokens[i]).balanceOf(_se()),
                "reserve synced to custody"
            );
        }
    }

    /* --------------------------------- tests ---------------------------------- */

    /// @dev I/K: booked receipts (adapter deposit) cannot free-credit a contract-caller SE pretransfer.
    function test_R14_17_adapterBookedReceipts_blockStaleContractPretransfer() public {
        uint256 r = _giveActorReceipts(100);
        vm.prank(_actor());
        uint256 shares = IERC4626(_se()).deposit(r, _actor());
        assertGt(shares, 0, "adapter deposit mints on booked receipts");
        _assertAllReservesSynced();

        uint256 sharesBefore = IERC20(_se()).balanceOf(_actor());
        uint256 receiptReserveBefore = IBasicVault(_se()).reserveOfToken(address(_receipt()));
        uint256 underlyingReserveBefore = IBasicVault(_se()).reserveOfToken(address(_underlyingToken()));
        uint256 claimed = receiptReserveBefore; // everything booked; unbooked U == 0
        assertGt(claimed, 0, "receipts are booked backing");

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (_receipt(), claimed, IERC20(_se()), 0, _actor(), true, block.timestamp)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0))
        );
        caller.execute(_se(), data);

        assertEq(IERC20(_se()).balanceOf(_actor()), sharesBefore, "holder shares unchanged");
        assertEq(IBasicVault(_se()).reserveOfToken(address(_receipt())), receiptReserveBefore, "receipt backing unchanged");
        assertEq(
            IBasicVault(_se()).reserveOfToken(address(_underlyingToken())),
            underlyingReserveBefore,
            "underlying local backing survives the rejection"
        );
    }

    /// @dev Positive control: a genuine atomic push-and-consume of unbooked receipts succeeds.
    function test_R14_17_atomicReceiptPretransferSucceeds() public {
        uint256 r = _giveActorReceipts(100);
        vm.prank(_actor());
        IERC4626(_se()).deposit(r / 2, _actor()); // book half; actor keeps the rest

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 amt = r / 4;
        vm.prank(_actor());
        _receipt().approve(address(caller), amt);

        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (_receipt(), amt, IERC20(_se()), 0, _actor(), true, block.timestamp)
        );
        caller.consumePretransfer(_receipt(), _actor(), _se(), amt, data);
        _assertAllReservesSynced();
    }

    /// @dev A payout syncs the receipt reserve DOWN; a later smaller deposit still credits on the
    ///      synced backing (no stale-high gate), on both families.
    function test_R14_17_stalePayoutReserve_doesNotGateSmallerCredit() public {
        uint256 r = _giveActorReceipts(200);
        vm.prank(_actor());
        IERC4626(_se()).deposit((r * 4) / 5, _actor());

        uint256 maxW = IERC4626(_se()).maxWithdraw(_actor());
        assertGt(maxW, 0, "withdrawable");
        vm.prank(_actor());
        IERC4626(_se()).withdraw(maxW / 4, _actor(), _actor());
        _assertAllReservesSynced();

        uint256 r2 = r / 10;
        uint256 preview = IERC4626(_se()).previewDeposit(r2);
        vm.prank(_actor());
        uint256 got = IERC4626(_se()).deposit(r2, _actor());
        assertEq(got, preview, "smaller deposit priced on synced backing");
        assertGt(got, 0, "smaller deposit still credits");
        _assertAllReservesSynced();
    }

    /// @dev Reverted adapter calls change nothing (both families).
    function test_R14_17_revertedAdapterCallsChangeNothing() public {
        uint256 r = _giveActorReceipts(100);
        vm.prank(_actor());
        IERC4626(_se()).deposit(r / 2, _actor());

        uint256 sharesBefore = IERC20(_se()).balanceOf(_actor());
        uint256 receiptReserveBefore = IBasicVault(_se()).reserveOfToken(address(_receipt()));

        vm.prank(_actor());
        vm.expectRevert(ReceiptBackedERC4626Target.ZeroAmount.selector);
        IERC4626(_se()).deposit(0, _actor());

        vm.prank(_actor());
        vm.expectRevert(ReceiptBackedERC4626Target.InvalidReceiver.selector);
        IERC4626(_se()).deposit(1, address(0));

        uint256 maxW = IERC4626(_se()).maxWithdraw(_actor());
        vm.prank(_actor());
        vm.expectRevert(
            abi.encodeWithSelector(IERC4626Errors.ERC4626ExceededMaxWithdraw.selector, _actor(), maxW + 1, maxW)
        );
        IERC4626(_se()).withdraw(maxW + 1, _actor(), _actor());

        assertEq(IERC20(_se()).balanceOf(_actor()), sharesBefore, "holder shares unchanged after reverts");
        assertEq(IBasicVault(_se()).reserveOfToken(address(_receipt())), receiptReserveBefore, "backing unchanged after reverts");
        _assertAllReservesSynced();
    }

    /// @dev Non-integral backing still advertises the full share balance when its payout fits in held receipts.
    function test_maxRedeem_fullBalancePayableAtNonIntegralRate() public {
        uint256 minted = _giveActorReceipts(4);
        uint256 depositAmt = minted - (minted / 4);
        vm.prank(_actor());
        IERC4626(_se()).deposit(depositAmt, _actor());
        vm.prank(_actor());
        assertTrue(_receipt().transfer(_se(), minted / 4), "donate receipts to move the rate off 1:1");
        uint256 balance = IERC20(_se()).balanceOf(_actor());
        uint256 held = _receipt().balanceOf(_se());
        uint256 preview = IERC4626(_se()).previewRedeem(balance);
        assertGt(preview, 0, "full balance pays receipts");
        assertLe(preview, held, "full payout fits");
        assertTrue(preview != balance, "rate is not one receipt per share");
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "payable full balance is the share cap");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), preview, "asset cap follows the share cap");
    }

    /// @dev maxRedeem returns the share balance even when its preview exceeds held receipts.
    function test_maxRedeem_capsWhenHeldReceiptsCannotPayFullBalance() public {
        uint256 minted = _giveActorReceipts(2);
        vm.prank(_actor());
        IERC4626(_se()).deposit(minted / 2, _actor());
        _mintUnderlying(_se(), minted);
        uint256 more = _giveActorReceipts(1);
        vm.prank(_actor());
        IERC4626(_se()).deposit(more, _actor());
        uint256 balance = IERC20(_se()).balanceOf(_actor());
        uint256 held = _receipt().balanceOf(_se());
        uint256 fullPreview = IERC4626(_se()).previewRedeem(balance);
        assertGt(fullPreview, held, "fixture prices the full balance above held receipts");
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), fullPreview, "maxWithdraw follows that balance");
    }

    /// @dev maxRedeem returns the share balance even when its preview rounds to zero.
    function test_maxRedeem_zeroPreviewIsNotAdvertised() public {
        uint256 small = _giveActorReceipts(1);
        vm.prank(_actor());
        IERC4626(_se()).deposit(small, _actor());
        address other = address(0xBEEF);
        uint256 large = _giveActorReceipts(20);
        vm.prank(_actor());
        assertTrue(_receipt().transfer(other, large), "fund a second holder");
        vm.prank(other);
        _receipt().approve(_se(), large);
        vm.prank(other);
        IERC4626(_se()).deposit(large, other);
        uint256 drain = _receipt().balanceOf(_se()) - 1;
        vm.prank(_se());
        assertTrue(_receipt().transfer(address(0xD0A1), drain), "leave one receipt against a large supply");
        uint256 balance = IERC20(_se()).balanceOf(_actor());
        assertEq(IERC4626(_se()).previewRedeem(balance), 0, "small balance rounds to zero receipts");
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), 0, "asset cap follows the zero share cap");
    }

    /// @notice An external EOA cannot bypass D9 through the native SY self-call wrapper.
    function test_RECURRENCE_nativeSY_internalBalanceRejectsEOA() public {
        uint256 receipts = _giveActorReceipts(100);
        vm.prank(_actor());
        uint256 shares = IERC4626(_se()).deposit(receipts, _actor());
        uint256 credit = shares / 4;
        vm.prank(_actor());
        IERC20(_se()).transfer(_se(), credit);
        address recipient = makeAddr("sy-recurrence-recipient");
        uint256 snapshot = vm.snapshotState();
        uint256 expected = IStandardizedYield(_se()).previewRedeem(address(_receipt()), credit);
        assertGt(expected, 0, "funded contract control has a positive payout");
        assertEq(IStandardizedYield(_se()).redeem(recipient, credit, address(_receipt()), 0, true), expected, "contract internal-balance control");
        assertEq(_receipt().balanceOf(recipient), expected, "control pays recipient");
        assertTrue(vm.revertToState(snapshot), "restore funded credit");
        address eoa = makeAddr("sy-recurrence-eoa");
        assertEq(eoa.code.length, 0, "unambiguously code-less caller");
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(_se()).redeem(recipient, credit, address(_receipt()), 0, true);
        assertEq(IERC20(_se()).balanceOf(_se()), credit, "rejected EOA consumes no selfshares");
        assertEq(_receipt().balanceOf(recipient), 0, "rejected EOA receives no assets");
    }

    function _recurrenceFundedLocalBacking() internal returns (uint256 receipts) {
        receipts = _giveActorReceipts(200);
        _mintUnderlying(_se(), receipts / 10);
        vm.prank(_actor());
        IERC4626(_se()).deposit(receipts / 2, _actor());
        _assertAllReservesSynced();
        assertGt(IBasicVault(_se()).reserveOfToken(address(_underlyingToken())), 0, "nonzero local backing fixture");
    }

    function _recurrenceIntakeCannotReuseCredit(bool mintShares) internal {
        uint256 receipts = _recurrenceFundedLocalBacking();
        uint256 local = IBasicVault(_se()).reserveOfToken(address(_underlyingToken()));
        uint256 amount = receipts / 10;
        if (mintShares) {
            uint256 shares = IERC4626(_se()).previewDeposit(amount);
            uint256 expected = IERC4626(_se()).previewMint(shares);
            vm.prank(_actor());
            assertEq(IERC4626(_se()).mint(shares, _actor()), expected, "mint receipt debit");
        } else {
            uint256 expected = IERC4626(_se()).previewDeposit(amount);
            vm.prank(_actor());
            assertEq(IERC4626(_se()).deposit(amount, _actor()), expected, "deposit share credit");
        }
        _assertAllReservesSynced();
        uint256 supply = IERC20(_se()).totalSupply();
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        bytes memory callData = abi.encodeCall(IStandardExchangeIn.exchangeIn, (_receipt(), amount, IERC20(_se()), 0, _actor(), true, block.timestamp));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount, 0));
        caller.execute(_se(), callData);
        assertEq(IERC20(_se()).totalSupply(), supply, "unfunded reuse mints nothing");
        assertEq(IBasicVault(_se()).reserveOfToken(address(_underlyingToken())), local, "local backing survives");
        _assertAllReservesSynced();
    }

    /// @notice Adapter deposit with local backing cannot authorize a later unfunded SE input.
    function test_RECURRENCE_B05_depositThenUnfundedSE_withLocalBacking() public { _recurrenceIntakeCannotReuseCredit(false); }
    /// @notice Adapter mint with local backing cannot authorize a later unfunded SE input.
    function test_RECURRENCE_B05_mintThenUnfundedSE_withLocalBacking() public { _recurrenceIntakeCannotReuseCredit(true); }

    function _recurrenceExitThenAtomicCredit(bool redeemShares) internal {
        uint256 receipts = _recurrenceFundedLocalBacking();
        uint256 local = IBasicVault(_se()).reserveOfToken(address(_underlyingToken()));
        uint256 amount = receipts / 10;
        uint256 beforeReceipt = _receipt().balanceOf(_actor());
        if (redeemShares) {
            uint256 shares = IERC4626(_se()).previewWithdraw(amount);
            uint256 expected = IERC4626(_se()).previewRedeem(shares);
            vm.prank(_actor());
            assertEq(IERC4626(_se()).redeem(shares, _actor(), _actor()), expected, "redeem payout");
            assertEq(_receipt().balanceOf(_actor()) - beforeReceipt, expected, "redeem receipt movement");
        } else {
            uint256 expected = IERC4626(_se()).previewWithdraw(amount);
            vm.prank(_actor());
            assertEq(IERC4626(_se()).withdraw(amount, _actor(), _actor()), expected, "withdraw burn");
            assertEq(_receipt().balanceOf(_actor()) - beforeReceipt, amount, "withdraw receipt movement");
        }
        _assertAllReservesSynced();
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 newCredit = amount / 10;
        uint256 expectedMint = IStandardExchangeIn(_se()).previewExchangeIn(_receipt(), newCredit, IERC20(_se()));
        uint256 beforeShares = IERC20(_se()).balanceOf(_actor());
        vm.prank(_actor());
        _receipt().approve(address(caller), newCredit);
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn, (_receipt(), newCredit, IERC20(_se()), expectedMint, _actor(), true, block.timestamp));
        caller.consumePretransfer(_receipt(), _actor(), _se(), newCredit, data);
        assertEq(IERC20(_se()).balanceOf(_actor()) - beforeShares, expectedMint, "smaller atomic SE input receives quoted shares");
        assertEq(IBasicVault(_se()).reserveOfToken(address(_underlyingToken())), local, "receipt route preserves local backing");
        _assertAllReservesSynced();
    }

    /// @notice A withdraw syncs the book downward before a smaller atomic SE receipt input.
    function test_RECURRENCE_B05_withdrawThenAtomicSE_withLocalBacking() public { _recurrenceExitThenAtomicCredit(false); }
    /// @notice A redeem syncs the book downward before a smaller atomic SE receipt input.
    function test_RECURRENCE_B05_redeemThenAtomicSE_withLocalBacking() public { _recurrenceExitThenAtomicCredit(true); }

    /// @dev Hosts mint underlying to `to`. Default matches the mintable test tokens used by both families.
    function _mintUnderlying(address to, uint256 amount) internal virtual {
        (bool ok, bytes memory reason) = address(_underlyingToken()).call(
            abi.encodeWithSignature("mint(address,uint256)", to, amount)
        );
        require(ok, "underlying mint");
    }
}
