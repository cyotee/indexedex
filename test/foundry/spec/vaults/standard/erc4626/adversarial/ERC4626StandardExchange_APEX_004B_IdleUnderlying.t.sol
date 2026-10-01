// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/**
 * @title ERC4626StandardExchange_APEX_004B_IdleUnderlying
 * @notice APEX-2026-004B (R8.1 / R8.2) on the registry-deployed generic ERC-4626 SE.
 *
 * @dev R8.1 — a donated/idle underlying transferred straight to the SE is NOT credited to an
 *      in-flight `exchangeIn` caller. Because the wrap route prices on the durable booked backing
 *      (`_receiptBacking` = held receipts + `reserveOfToken(underlying)`) and `_investCreditedUnderlying`
 *      only sweeps the booked reserve, the resting donation is excluded from the caller's quote and
 *      from the caller's invested delta; the end-route `_syncAllExpectedHoldReserves` then books the
 *      donation as holder-owned reserve (D12). The attacker receives only the quote of its own input
 *      and no refund. A later honest route sweeps the booked donation into protocol-vault receipts,
 *      sharing it across every holder.
 *
 *      RED (vulnerable version): a balance-delta pull (`balanceAfter - balanceBefore`) or a backing
 *      figure sourced from `balanceOf(underlying)` would have credited the resting donation to the
 *      in-flight caller, letting the attacker mint shares against holder-owned idle cash (and, on
 *      exact-out, be refunded the surplus). This suite would have failed there: attacker shares would
 *      exceed the quote of its own input and `_booked()` would not equal the donation.
 *
 * @dev R8.2 — pretransfer authorization across the three underlying money routes. An EOA caller is
 *      rejected `EOAPretransferNotAllowed()` (0xb18c67ea) on the two InTarget routes (the EOA check in
 *      `_securePull` fires before the credit check). On the OutTarget exact-out route, when the resting
 *      credit is already booked, the credit precheck in `_pullExactOutInput` fires FIRST and reverts
 *      `TransferDeltaInsufficient(used, 0)` (0x0b7f868c) before `_securePull`'s EOA check — the asserted
 *      asymmetry. A contract caller consuming only unbooked resting credit succeeds and takes nothing
 *      from holder inventory; claiming over the resting credit reverts `TransferDeltaInsufficient(claimed, available)`.
 *
 *      Selectors re-derived from the declaring source with `cast sig`:
 *        - ISecurePullErrors.EOAPretransferNotAllowed()                 = 0xb18c67ea
 *        - ISecurePullErrors.TransferDeltaInsufficient(uint256,uint256) = 0x0b7f868c
 *      (contracts/interfaces/ISecurePullErrors.sol)
 */
contract ERC4626StandardExchange_APEX_004B_IdleUnderlying is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;

    address internal alice = address(0xA11CE); // honest first minter / holder
    address internal attacker = address(0xBAD);
    address internal honest2 = address(0xB0B); // later honest sweeper
    address internal donor = address(0xD0);
    address internal eoa = address(0xE0A); // bytecode-less pretransfer caller

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);

        // Zero BOTH the global default and the per-vault usage fee for exact math
        // (mirrors TestBase_AaveV3StataStandardExchange_Decimals._setTestUsageFee).
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0);
        vm.stopPrank();
        assertEq(indexedexManager.usageFeeOfVault(se), 0, "usage fee zeroed for exact math");

        address[4] memory actors = [alice, attacker, honest2, donor];
        for (uint256 i; i < actors.length; ++i) {
            underlying.mint(actors[i], 1_000 ether);
            vm.startPrank(actors[i]);
            underlying.approve(se, type(uint256).max);
            underlying.approve(address(protocolVault), type(uint256).max);
            IERC20(address(protocolVault)).approve(se, type(uint256).max);
            vm.stopPrank();
        }
    }

    /* --------------------------------- helpers -------------------------------- */

    function _wrap(address who, uint256 amount) internal returns (uint256 shares) {
        vm.prank(who);
        shares = seIn.exchangeIn(IERC20(address(underlying)), amount, IERC20(se), 0, who, false, block.timestamp);
    }

    function _bookedUnderlying() internal view returns (uint256) {
        return IBasicVault(se).reserveOfToken(address(underlying));
    }

    function _seUnderlyingBal() internal view returns (uint256) {
        return underlying.balanceOf(se);
    }

    function _receipts() internal view returns (uint256) {
        return IERC20(address(protocolVault)).balanceOf(se);
    }

    function _underlyingEntitlement(uint256 seShares) internal view returns (uint256) {
        return seIn.previewExchangeIn(IERC20(se), seShares, IERC20(address(underlying)));
    }

    /* ------------------------------------ R8.1 ------------------------------------ */

    /// @dev R8.1: a resting donated underlying is excluded from the in-flight caller's quote and
    ///      invested delta; it books as holder-owned reserve and is swept to all holders later.
    function test_R8_1_donationNotCreditedToInflightCaller_restsThenSweepsToHolders() public {
        // First minter establishes a non-empty vault (1:1: no yield simulated on SimpleYield).
        uint256 aliceShares = _wrap(alice, 100 ether);
        assertEq(aliceShares, 100 ether, "first minter 1:1");
        assertEq(_bookedUnderlying(), 0, "all of alice's input invested");
        assertEq(_receipts(), 100 ether, "100 receipts held");
        uint256 aliceBaseEntitlement = _underlyingEntitlement(aliceShares);
        assertEq(aliceBaseEntitlement, 100 ether, "pre-donation entitlement");

        // Donation: underlying pushed straight to the SE (unbooked, idle).
        vm.prank(donor);
        underlying.transfer(se, 50 ether);
        assertEq(_seUnderlyingBal(), 50 ether, "donation rests on the SE");
        assertEq(_bookedUnderlying(), 0, "donation is not yet booked reserve");

        // Attacker wraps its own 10 while the donation rests.
        uint256 attackerBalBefore = underlying.balanceOf(attacker);
        uint256 quoteOfOwnInput =
            seIn.previewExchangeIn(IERC20(address(underlying)), 10 ether, IERC20(se));
        uint256 attackerShares = _wrap(attacker, 10 ether);

        // The attacker gets ONLY the quote of its own input; no donation captured, no refund.
        assertEq(attackerShares, quoteOfOwnInput, "attacker gets exactly its own quote");
        assertEq(attackerShares, 10 ether, "10 input -> 10 shares at 1:1; donation excluded");
        assertEq(
            underlying.balanceOf(attacker), attackerBalBefore - 10 ether,
            "exact-in spends exactly the input: no refund of the donation"
        );

        // The donation now rests as holder-owned booked reserve (D12).
        assertEq(_bookedUnderlying(), 50 ether, "donation booked as holder reserve after end-sync");
        assertEq(_seUnderlyingBal(), 50 ether, "donation still resting (not yet swept)");
        assertEq(protocolVault.totalAssets(), 110 ether, "only alice+attacker inputs invested");

        // A later honest route sweeps the booked donation into receipts for ALL holders.
        uint256 receiptsBeforeSweep = _receipts();
        _wrap(honest2, 5 ether);
        assertEq(_bookedUnderlying(), 0, "honest route swept the booked donation");
        assertEq(_receipts(), receiptsBeforeSweep + 50 ether + 5 ether, "donation + honest input now receipts");

        // Every prior holder shares the donation pro-rata; alice's entitlement strictly increased.
        assertGt(_underlyingEntitlement(aliceShares), aliceBaseEntitlement, "donation shared to alice");
    }

    /// @dev Control: a donation BEFORE the first mint accrues to the first minter and is never refunded.
    function test_R8_1_control_preHolderDonation_accruesToFirstMinter_neverRefunded() public {
        uint256 donorBalBefore = underlying.balanceOf(donor);
        vm.prank(donor);
        underlying.transfer(se, 30 ether); // pre-mint donation
        assertEq(_seUnderlyingBal(), 30 ether, "donation resting before any mint");

        uint256 aliceShares = _wrap(alice, 100 ether);
        assertEq(aliceShares, 100 ether, "first minter mints on its own input only");

        // The pre-mint donation is booked and, alice being the only holder, accrues wholly to her.
        assertEq(_bookedUnderlying(), 30 ether, "pre-mint donation booked as reserve");
        assertApproxEqAbs(
            _underlyingEntitlement(aliceShares), 130 ether, 2,
            "first minter's entitlement absorbs the pre-mint donation"
        );
        // The donor is never refunded.
        assertEq(underlying.balanceOf(donor), donorBalBefore - 30 ether, "donation never returned to donor");
    }

    /* ------------------------------------ R8.2 ------------------------------------ */

    /// @dev R8.2: InTarget wrap (underlying -> SE) rejects an EOA pretransfer claim: EOA check first.
    function test_R8_2_eoaPretransfer_inTargetWrap_reverts_EOA() public {
        _wrap(alice, 100 ether);
        vm.prank(donor);
        underlying.transfer(se, 20 ether); // resting credit present, still EOA is rejected

        vm.prank(eoa);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector));
        seIn.exchangeIn(IERC20(address(underlying)), 10 ether, IERC20(se), 0, eoa, true, block.timestamp);
    }

    /// @dev R8.2: InTarget pass-through (underlying -> protocolVault) rejects an EOA pretransfer claim.
    function test_R8_2_eoaPretransfer_inTargetPassthrough_reverts_EOA() public {
        _wrap(alice, 100 ether);
        vm.prank(donor);
        underlying.transfer(se, 20 ether);

        vm.prank(eoa);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector));
        seIn.exchangeIn(
            IERC20(address(underlying)), 10 ether, IERC20(address(protocolVault)), 0, eoa, true, block.timestamp
        );
    }

    /// @dev R8.2 asymmetry: OutTarget exact-out (underlying -> SE) checks credit BEFORE the EOA check,
    ///      so with the resting credit already booked it reverts TransferDeltaInsufficient(used, 0),
    ///      never EOAPretransferNotAllowed.
    function test_R8_2_eoaPretransfer_outTargetExactOut_booked_reverts_TransferDelta() public {
        _wrap(alice, 100 ether);
        vm.prank(donor);
        underlying.transfer(se, 50 ether); // resting donation

        // A subsequent honest route end-syncs the resting donation into booked reserve without
        // sweeping it (booking happened AFTER the sweep snapshot), leaving balance == reserve.
        _wrap(honest2, 1 ether);
        assertEq(_bookedUnderlying(), _seUnderlyingBal(), "donation booked: available credit is now 0");
        assertGt(_bookedUnderlying(), 0, "reserve is booked");

        // used = amountIn the exact-out route would require.
        uint256 used = seOut.previewExchangeOut(IERC20(address(underlying)), IERC20(se), 5 ether);
        assertGt(used, 0, "non-trivial required input");

        vm.prank(eoa);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used, 0)
        );
        seOut.exchangeOut(
            IERC20(address(underlying)), type(uint256).max, IERC20(se), 5 ether, eoa, true, block.timestamp
        );
    }

    /// @dev R8.2: a contract caller consuming only unbooked resting credit succeeds and takes nothing
    ///      from holder inventory; the leftover resting credit books to holders.
    function test_R8_2_contractCaller_consumesUnbookedRestingCredit_succeeds_noHolderInventory() public {
        uint256 aliceShares = _wrap(alice, 100 ether);
        uint256 aliceEntitlementBefore = _underlyingEntitlement(aliceShares);
        uint256 receiptsBefore = _receipts();

        // Unbooked resting credit (U = 20).
        vm.prank(donor);
        underlying.transfer(se, 20 ether);
        assertEq(_bookedUnderlying(), 0, "resting credit is unbooked");

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(underlying)), 15 ether, IERC20(se), 0, address(0xF00D), true, block.timestamp)
        );
        // amount == 0 -> the caller pushes nothing; it consumes the pre-existing resting credit.
        caller.execute(se, data);

        assertEq(IERC20(se).balanceOf(address(0xF00D)), 15 ether, "recipient minted from resting credit");
        // Holder inventory untouched: alice keeps her shares and her entitlement does not fall.
        assertEq(IERC20(se).balanceOf(alice), aliceShares, "alice's shares untouched");
        assertGe(_underlyingEntitlement(aliceShares), aliceEntitlementBefore, "alice not diluted by the claim");
        assertGe(_receipts(), receiptsBefore, "SE receipts not reduced by the claim");
        // The uninvested 5 of the resting credit is booked for holders.
        assertEq(_bookedUnderlying(), 5 ether, "leftover resting credit booked to holders");
    }

    /// @dev R8.2: claiming over the resting credit reverts TransferDeltaInsufficient(claimed, available).
    function test_R8_2_contractCaller_overRestingCredit_reverts_TransferDelta() public {
        _wrap(alice, 100 ether);
        vm.prank(donor);
        underlying.transfer(se, 20 ether); // U = 20

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(underlying)), 25 ether, IERC20(se), 0, address(caller), true, block.timestamp)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 25 ether, 20 ether)
        );
        caller.execute(se, data);
    }
}
