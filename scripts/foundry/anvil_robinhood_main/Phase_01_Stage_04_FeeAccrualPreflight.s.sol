// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from "./Phase_08_Stage_07_StakingPrincipalMigration.sol";
import {Phase_01_Stage_04_FeeAccrualPreflight as Preflight} from "./Phase_01_Stage_04_FeeAccrualPreflight.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {IPonsV2LaunchFactory} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

/// @notice Read-only preflight; never deploys/replaces a core contract or staking instance.
contract Phase_01_Stage_04_FeeAccrualPreflight is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 01 Stage 04: Existing fee accrual infrastructure");
        Preflight.verifyCore(manager, _configAddress(".feeCollector"), _configAddress(".create3Factory"), staking, dtf);
        Preflight.verifyPool(IPonsV2LaunchFactory(ROBINHOOD_MAIN.PONS_V2_LAUNCH_FACTORY), IPoolManager(_configAddress(".poolManager")), _basePoolKey());
        _exportSnapshot("phase01_stage04_fee_accrual_preflight.json", Migration.snapshot(staking));
    }
}
