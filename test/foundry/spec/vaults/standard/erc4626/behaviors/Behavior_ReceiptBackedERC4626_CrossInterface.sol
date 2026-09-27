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
}
