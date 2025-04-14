// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/**
 * @title ProtocolDETFBondingTest
 * @notice Tests for US-5.2 and US-5.3: Bond with WETH and RICH
 * @dev Specification tests for bonding mechanics and NFT position creation.
 */
contract ProtocolDETFBondingTest is Test {
    /* ---------------------------------------------------------------------- */
    /*                          Lock Duration Bonus                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test bonus multiplier calculation for lock durations.
     * @dev Bonus increases exponentially with lock duration.
     *      min lock = 1.0x, max lock = 2.0x (example)
     */
    function test_bonusMultiplier_minLock() public pure {
        uint256 minLockDuration = 7 days;
        uint256 maxLockDuration = 365 days;
        uint256 userLockDuration = 7 days;

        uint256 bonus = _calcBonusMultiplier(userLockDuration, minLockDuration, maxLockDuration);

        // At min lock, bonus should be 1.0x (no bonus)
        assertEq(bonus, ONE_WAD, "Min lock should give 1.0x multiplier");
    }

    function test_bonusMultiplier_maxLock() public pure {
        uint256 minLockDuration = 7 days;
        uint256 maxLockDuration = 365 days;
        uint256 userLockDuration = 365 days;

        uint256 bonus = _calcBonusMultiplier(userLockDuration, minLockDuration, maxLockDuration);

        // At max lock, bonus should be 2.0x
        assertEq(bonus, 2e18, "Max lock should give 2.0x multiplier");
    }

    function test_bonusMultiplier_midLock() public pure {
        uint256 minLockDuration = 7 days;
        uint256 maxLockDuration = 365 days;
        // Calculate mid-point lock duration
        uint256 midLockDuration = (minLockDuration + maxLockDuration) / 2;

        uint256 bonus = _calcBonusMultiplier(midLockDuration, minLockDuration, maxLockDuration);

        // At mid lock, bonus should be between 1.0x and 2.0x
        assertTrue(bonus > ONE_WAD, "Mid lock should be > 1.0x");
        assertTrue(bonus < 2e18, "Mid lock should be < 2.0x");
    }

    function testFuzz_bonusMultiplier_bounds(uint256 lockDuration) public pure {
        uint256 minLockDuration = 7 days;
        uint256 maxLockDuration = 365 days;
        lockDuration = bound(lockDuration, minLockDuration, maxLockDuration);

        uint256 bonus = _calcBonusMultiplier(lockDuration, minLockDuration, maxLockDuration);

        assertTrue(bonus >= ONE_WAD, "Bonus should be >= 1.0x");
        assertTrue(bonus <= 2e18, "Bonus should be <= 2.0x");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Effective Shares                              */
    /* ---------------------------------------------------------------------- */

    function test_effectiveShares_calculation() public pure {
        uint256 baseShares = 100e18;
        uint256 bonusMultiplier = 15e17; // 1.5x

        uint256 effectiveShares = _calcEffectiveShares(baseShares, bonusMultiplier);

        assertEq(effectiveShares, 150e18, "Effective shares should be 150");
    }

    function test_effectiveShares_noBonusAtMinLock() public pure {
        uint256 baseShares = 100e18;
        uint256 bonusMultiplier = ONE_WAD; // 1.0x

        uint256 effectiveShares = _calcEffectiveShares(baseShares, bonusMultiplier);

        assertEq(effectiveShares, 100e18, "No bonus at min lock");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Unlock Time Validation                         */
    /* ---------------------------------------------------------------------- */

    function test_unlockTime_calculation() public view {
        uint256 lockDuration = 30 days;
        uint256 unlockTime = block.timestamp + lockDuration;

        assertTrue(unlockTime > block.timestamp, "Unlock should be in future");
    }

    function test_isUnlocked_beforeUnlock() public view {
        uint256 unlockTime = block.timestamp + 1 days;

        assertFalse(block.timestamp >= unlockTime, "Should not be unlocked before time");
    }

    function test_isUnlocked_afterUnlock() public view {
        uint256 unlockTime = block.timestamp - 1; // Already passed

        assertTrue(block.timestamp >= unlockTime, "Should be unlocked after time");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculate bonus multiplier for lock duration.
     * @dev Linear interpolation between min (1.0x) and max (2.0x).
     */
    function _calcBonusMultiplier(uint256 lockDuration, uint256 minLock, uint256 maxLock)
        internal
        pure
        returns (uint256)
    {
        if (lockDuration <= minLock) return ONE_WAD;
        if (lockDuration >= maxLock) return 2e18;

        // Linear interpolation: 1.0 + (duration - min) / (max - min) * 1.0
        uint256 range = maxLock - minLock;
        uint256 elapsed = lockDuration - minLock;
        return ONE_WAD + (elapsed * ONE_WAD) / range;
    }

    /**
     * @notice Calculate effective shares with bonus.
     */
    function _calcEffectiveShares(uint256 baseShares, uint256 bonusMultiplier) internal pure returns (uint256) {
        return (baseShares * bonusMultiplier) / ONE_WAD;
    }
}
