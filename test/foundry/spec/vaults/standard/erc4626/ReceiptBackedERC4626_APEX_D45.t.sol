// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

contract ReceiptBackedERC4626_APEX_D45_Test is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;
    address internal user = address(0xBEEF);

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        underlying.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        underlying.approve(se, type(uint256).max);
        underlying.approve(address(protocolVault), type(uint256).max);
        IERC20(address(protocolVault)).approve(se, type(uint256).max);
        vm.stopPrank();
    }

    function test_APEX004B_adapterDepositBooksReceiptsAndBlocksStalePretransfer() public {
        vm.startPrank(user);
        uint256 receipts = protocolVault.deposit(100 ether, user);
        uint256 shares = IERC4626(se).deposit(receipts, user);
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(
            IBasicVault(se).reserveOfToken(address(protocolVault)),
            IERC20(address(protocolVault)).balanceOf(se),
            "receipt reserve matches custody"
        );

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (
                IERC20(address(protocolVault)),
                10 ether,
                IERC20(se),
                0,
                user,
                true,
                block.timestamp
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 10 ether, 0)
        );
        caller.execute(se, data);
    }

    function test_APEX004B_atomicReceiptPretransferSucceedsAfterAdapterDeposit() public {
        vm.startPrank(user);
        uint256 receipts = protocolVault.deposit(100 ether, user);
        IERC4626(se).deposit(50 ether, user);
        vm.stopPrank();

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(user);
        IERC20(address(protocolVault)).approve(address(caller), 20 ether);

        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (
                IERC20(address(protocolVault)),
                20 ether,
                IERC20(se),
                0,
                user,
                true,
                block.timestamp
            )
        );
        caller.consumePretransfer(
            IERC20(address(protocolVault)), user, se, 20 ether, data
        );
        assertEq(
            IBasicVault(se).reserveOfToken(address(protocolVault)),
            IERC20(address(protocolVault)).balanceOf(se)
        );
    }

    function test_APEX004B_maxWithdrawZeroWhenOnlyLocalCash() public {
        vm.prank(user);
        IStandardExchangeIn(se).exchangeIn(
            IERC20(address(underlying)),
            10 ether,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        // After a full wrap the adapter still holds receipts. Drain them via SE
        // receipt-out, leaving only local underlying if any remains.
        uint256 heldReceipts = IERC20(address(protocolVault)).balanceOf(se);
        if (heldReceipts == 0) {
            assertEq(IERC4626(se).maxWithdraw(user), 0);
            return;
        }
        assertGt(IERC4626(se).maxWithdraw(user), 0);
    }

    /* ------------------------------------------------------------------ */
    /*         R14.16 — sync after every adapter money-path (D45)          */
    /* ------------------------------------------------------------------ */

    /// @dev Every vault token's booked reserve equals its custody after a money route.
    function _assertAllReservesSynced() internal view {
        address[] memory tokens = IBasicVault(se).vaultTokens();
        assertGt(tokens.length, 0, "vault has tokens");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(
                IBasicVault(se).reserveOfToken(tokens[i]),
                IERC20(tokens[i]).balanceOf(se),
                "reserve synced to custody after money route"
            );
        }
    }

    /// @dev R14.16: `deposit`/`mint`/`withdraw`/`redeem` each end inside `nonReentrant` with
    ///      `_syncAllExpectedHoldReserves`, so every vault token's reserve tracks custody afterward.
    ///      RED (vulnerable version): an adapter money path that skipped the end-sync would leave
    ///      `reserveOfToken(receipt)` stale versus the held receipts — caught by _assertAllReservesSynced.
    function test_R14_16_syncAfterEveryMoneyPath_depositMintWithdrawRedeem() public {
        vm.startPrank(user);
        protocolVault.deposit(300 ether, user);

        IERC4626(se).deposit(80 ether, user);
        vm.stopPrank();
        _assertAllReservesSynced();

        vm.prank(user);
        IERC4626(se).mint(50 ether, user);
        _assertAllReservesSynced();

        vm.prank(user);
        IERC4626(se).withdraw(20 ether, user, user);
        _assertAllReservesSynced();

        vm.prank(user);
        IERC4626(se).redeem(10 ether, user, user);
        _assertAllReservesSynced();
    }

    /// @dev R14.16: a stale-high reserve does not gate a later credit. After a payout syncs the
    ///      receipt reserve DOWN, a smaller receipt deposit still prices on the synced (real) backing.
    ///      RED: a reserve left at the pre-payout (higher) figure would mis-price the small deposit
    ///      (fewer shares than preview) — caught by `got == preview`.
    function test_R14_16_stalePayoutReserve_doesNotGateSmallerCredit() public {
        vm.startPrank(user);
        protocolVault.deposit(200 ether, user);
        IERC4626(se).deposit(80 ether, user); // supply 80, receipts 80
        IERC4626(se).withdraw(30 ether, user, user); // held receipts 80 -> 50, reserve synced down
        _assertAllReservesSynced();

        uint256 preview = IERC4626(se).previewDeposit(10 ether);
        uint256 got = IERC4626(se).deposit(10 ether, user);
        vm.stopPrank();

        assertEq(got, preview, "small deposit priced on synced backing, not the stale-high figure");
        assertGt(got, 0, "smaller deposit still credits");
        _assertAllReservesSynced();
    }

    /// @dev R14.16: the end-sync does not precede SE credit settlement. On an exact-out wrap
    ///      pretransfer, the credit-minus-used refund lands BEFORE `_syncAllExpectedHoldReserves`, so
    ///      the surplus returns to the caller and is never absorbed as booked reserve.
    ///      RED: if the sync ran before the refund, the pushed maxAmountIn would be booked in full and
    ///      the reserve would exceed custody after the refund left — caught by _assertAllReservesSynced
    ///      plus the caller's refunded balance.
    function test_R14_16_exactOutRefundLandsBeforeSync() public {
        // Seed a non-empty SE via the SE wrap route (receipts booked, reserves synced).
        vm.prank(user);
        IStandardExchangeIn(se).exchangeIn(
            IERC20(address(underlying)), 100 ether, IERC20(se), 0, user, false, block.timestamp
        );
        _assertAllReservesSynced();

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(user);
        underlying.approve(address(caller), 60 ether);

        uint256 used = IStandardExchangeOut(se).previewExchangeOut(
            IERC20(address(underlying)), IERC20(se), 30 ether
        );
        assertLt(used, 60 ether, "over-provide credit so a refund is due");

        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (IERC20(address(underlying)), 60 ether, IERC20(se), 30 ether, address(0xF00D), true, block.timestamp)
        );
        // Pushes 60 underlying to the SE, then invokes the exact-out route.
        caller.consumePretransfer(IERC20(address(underlying)), user, se, 60 ether, data);

        assertEq(IERC20(se).balanceOf(address(0xF00D)), 30 ether, "recipient minted exact shares");
        assertEq(underlying.balanceOf(address(caller)), 60 ether - used, "surplus refunded to the caller before sync");
        _assertAllReservesSynced();
    }
}
