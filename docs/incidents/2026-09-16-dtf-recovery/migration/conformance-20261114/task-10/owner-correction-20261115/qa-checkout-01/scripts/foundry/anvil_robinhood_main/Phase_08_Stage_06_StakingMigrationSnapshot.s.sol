// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from "./Phase_08_Stage_07_StakingPrincipalMigration.sol";

contract Phase_08_Stage_06_StakingMigrationSnapshot is FeeAccrualStageBase {
    function run() external {
        _startFee("Fee accrual: snapshot deposits and remaining rewards");
        _loadFeeDetf(true);
        _exportSnapshot("phase08_stage06_staking_migration_snapshot.json", Migration.snapshot(staking));
    }
}
