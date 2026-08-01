// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Clamping
 * @notice Reusable behavior contract exercising the clamping / exhaustion revert paths of the
 *         Standard Exchange Buffer Pool.
 *
 * @dev Two side-exhaustion conditions are tested:
 *      1. Shares side exhausted  - hookSharesDelta is driven to an extreme positive value via
 *         vm.store so that the pool's "available shares" clamps to zero, causing the pool to revert
 *         with PoolSharesSideExhausted when a TTA→shares swap is attempted.
 *      2. TTA side exhausted - virtualTTA is forced to zero via vm.store, causing the pool to
 *         revert with PoolTTASideExhausted when a shares→TTA swap is attempted.
 *
 *      Slot offsets in the Storage struct (base = keccak256("...standardExchange")):
 *        offset 0  ttaToken
 *        offset 1  shareToken
 *        offset 2  standardExchangeVault
 *        offset 3  rateProvider
 *        offset 4  ttaIndex
 *        offset 5  sharesIndex
 *        offset 6  expectedFactory
 *        offset 7  virtualTTA        ← VIRTUAL_TTA_OFFSET
 *        offset 8  hookSharesDelta   ← HOOK_SHARES_DELTA_OFFSET
 *        offset 9  pendingPreSeatS
 *
 *      The probing helper _verifySlotOffset() is used to assert that the hard-coded offsets
 *      are correct before any state-mutation write.  If the struct layout changes this check
 *      will revert with a clear message rather than silently writing to the wrong slot.
 */
abstract contract Behavior_StandardExchangeBufferPool_Clamping is Test {

    /* ---------------------------------------------------------------------- */
    /*                         Abstract Hook                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Implementors return the live test fixture so behavior functions
    ///         can access all public state (bv3Vault, bufferPool, tta, shares, …).
    function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool);

    /* ---------------------------------------------------------------------- */
    /*                             Constants                                    */
    /* ---------------------------------------------------------------------- */

    bytes32 internal constant POOL_REPO_SLOT =
        keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange");

    /// @dev Slot offset of `virtualTTA` within the Storage struct.
    uint256 internal constant VIRTUAL_TTA_OFFSET = 7;
    /// @dev Slot offset of `hookSharesDelta` within the Storage struct.
    uint256 internal constant HOOK_SHARES_DELTA_OFFSET = 8;

    /* ---------------------------------------------------------------------- */
    /*                         Behavior Assertions                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Force hookSharesDelta to an astronomically large value so that the pool's
     *         computed "available shares" clamps to zero, then assert that attempting a
     *         TTA→shares swap reverts with PoolSharesSideExhausted.
     *
     * @dev The pool derives available shares as:
     *          available = actualShares - hookSharesDelta   (conceptually)
     *      Setting hookSharesDelta >> actualShares makes available clamp to zero.
     */
    function behavior_clamping_revertsWhenSharesSideExhausted() public {
        TestBase_StandardExchangeBufferPool tb = _base();
        address pool = tb.bufferPool();

        // Verify the slot offset matches before writing to it.
        _verifySlotOffset(pool, HOOK_SHARES_DELTA_OFFSET, false /*isVirtualTTA*/);

        // Write a hookSharesDelta that is effectively infinite (type(int256).max as uint256).
        bytes32 exhaustedDelta = bytes32(uint256(type(int256).max));
        vm.store(pool, bytes32(uint256(POOL_REPO_SLOT) + HOOK_SHARES_DELTA_OFFSET), exhaustedDelta);

        // Cache alice address before vm.expectRevert so getAlice() is not the consumed call.
        address alice_ = tb.getAlice();

        // Ensure alice has TTA to attempt the swap.
        tb.mintTTA(alice_, 1e18);

        // The swap must revert - either with the typed error selector or an outer revert from the
        // Balancer V3 RouterMock wrapping the inner revert.
        vm.expectRevert();
        tb.swapTTAforShares(alice_, 1e18);
    }

    /**
     * @notice Force virtualTTA to zero so that the pool's TTA side is fully exhausted, then
     *         assert that attempting a shares→TTA swap reverts with PoolTTASideExhausted.
     */
    function behavior_clamping_revertsWhenTTASideExhausted() public {
        TestBase_StandardExchangeBufferPool tb = _base();
        address pool = tb.bufferPool();

        // Verify the slot offset matches before writing to it.
        _verifySlotOffset(pool, VIRTUAL_TTA_OFFSET, true /*isVirtualTTA*/);

        // Set virtualTTA to zero.
        vm.store(pool, bytes32(uint256(POOL_REPO_SLOT) + VIRTUAL_TTA_OFFSET), bytes32(uint256(0)));

        // Cache alice address before vm.expectRevert so getAlice() is not the consumed call.
        address alice_ = tb.getAlice();

        // Ensure alice has shares to attempt the swap.
        tb.mintShares(alice_, 1e18);

        // The swap must revert.
        vm.expectRevert();
        tb.swapSharesForTTA(alice_, 1e18);
    }

    /* ---------------------------------------------------------------------- */
    /*                            Internal Helpers                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Probes slot `offset` relative to POOL_REPO_SLOT by writing a marker, reading back
     *      via the public view function, then restoring the original value.  Reverts if the
     *      read-back does not equal the marker, indicating the hard-coded offset is wrong.
     *
     * @param pool        Address of the buffer pool diamond.
     * @param offset      Candidate slot offset to verify.
     * @param isVirtualTTA  If true, reads via virtualTTA(); if false, reads via hookSharesDelta().
     */
    function _verifySlotOffset(address pool, uint256 offset, bool isVirtualTTA) internal {
        bytes32 slotKey = bytes32(uint256(POOL_REPO_SLOT) + offset);

        // Derive a marker that is distinguishable and positive even when cast to int256.
        uint256 marker = uint256(keccak256(abi.encode("clamping_slot_probe", offset, isVirtualTTA))) >> 1;

        bytes32 saved = vm.load(pool, slotKey);
        vm.store(pool, slotKey, bytes32(marker));

        uint256 readBack = isVirtualTTA
            ? IStandardExchangeBufferPool(pool).virtualTTA()
            : uint256(IStandardExchangeBufferPool(pool).hookSharesDelta());

        // Restore before any revert so the pool state is clean.
        vm.store(pool, slotKey, saved);

        require(
            readBack == marker,
            isVirtualTTA
                ? "Behavior_Clamping: virtualTTA slot offset mismatch - check Storage struct layout"
                : "Behavior_Clamping: hookSharesDelta slot offset mismatch - check Storage struct layout"
        );
    }
}
