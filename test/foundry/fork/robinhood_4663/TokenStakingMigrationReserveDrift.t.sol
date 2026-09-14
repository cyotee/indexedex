// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from
    "scripts/foundry/anvil_robinhood_main/Phase_08_Stage_07_StakingPrincipalMigration.sol";

/// @notice Regressions against the deployed mainnet contracts at the actual failure blocks.
contract TokenStakingMigrationReserveDrift is Test {
    ITokenStaking constant STAKING = ITokenStaking(0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00);
    address constant OWNER = 0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B;
    address constant DETF = 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7;

    function _regression(uint256 height, uint256 staleInput) internal {
        vm.createSelectFork("robinhood_mainnet_alchemy", height);
        uint256 reserve = STAKING.reserveRemaining();
        vm.prank(OWNER);
        vm.expectRevert(bytes4(keccak256("MaxInRatio()")));
        STAKING.migrateToClaimVault(staleInput, 1, block.timestamp + 1800);
        assertEq(STAKING.reserveRemaining(), reserve, "failed transfer rolled back");

        // Preserve the original pre-drift reserve: replacing its 25% cap with
        // 5% must survive the real intervening reserve decline, not just a requote.
        uint256 checkpoint = vm.snapshotState();
        vm.prank(OWNER);
        (uint256 claim,) = STAKING.migrateToClaimVault(staleInput / 5, 1, block.timestamp + 1800);
        assertGt(claim, 0);
        assertTrue(vm.revertToStateAndDelete(checkpoint));
        uint256 fresh = Migration.nextChunkAmount(STAKING, DETF, type(uint256).max);
        assertLt(fresh, staleInput / 5);
        _quotedMigration(fresh);
    }

    function _quotedMigration(uint256 amount) internal {
        uint256 checkpoint = vm.snapshotState();
        vm.prank(OWNER);
        (uint256 quoted,) = STAKING.migrateToClaimVault(amount, 1, block.timestamp + 1800);
        assertTrue(vm.revertToStateAndDelete(checkpoint));
        uint256 minimum = quoted * 9950 / 10000;
        assertGt(minimum, 0);
        vm.startPrank(OWNER);
        Migration.execute(STAKING, DETF, amount, type(uint256).max, minimum, block.timestamp + 1800);
        vm.stopPrank();
    }

    function test_firstFailedBatch_smallerOriginalQuoteSurvivesReserveDrift() public {
        _regression(62276653, 46902931784577999608355);
    }

    function test_secondFailedBatch_smallerOriginalQuoteSurvivesReserveDrift() public {
        _regression(62291906, 24797617346220397664715);
    }

    function test_remainingMigrationCompletesWithSmallerChunks() public {
        vm.createSelectFork("robinhood_mainnet_alchemy", 62291906);
        uint256 principal = STAKING.totalSupply();
        uint256 initial = STAKING.reserveRemaining();
        uint256 converted;
        uint256 chunks;
        while (STAKING.reserveRemaining() != 0) {
            assertLt(chunks, 512, "bounded complete migration");
            uint256 amount = Migration.nextChunkAmount(STAKING, DETF, type(uint256).max);
            _quotedMigration(amount);
            converted += amount;
            ++chunks;
        }
        Migration.verifyComplete(STAKING, DETF);
        assertEq(converted, initial);
        assertEq(STAKING.totalSupply(), principal);
        emit log_named_uint("Remaining migration chunks", chunks);
    }
}
