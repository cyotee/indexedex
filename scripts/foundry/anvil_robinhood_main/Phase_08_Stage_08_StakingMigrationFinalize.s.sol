// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from "./Phase_08_Stage_07_StakingPrincipalMigration.sol";

contract Phase_08_Stage_08_StakingMigrationFinalize is FeeAccrualStageBase {
    function run() external {
        _startFee("Fee accrual: verify fully migrated staking");
        _loadFeeDetf(true);
        _exportSnapshot("phase08_stage08_staking_migration_finalize.json", Migration.verifyComplete(staking, targetDetf));
    }
}
