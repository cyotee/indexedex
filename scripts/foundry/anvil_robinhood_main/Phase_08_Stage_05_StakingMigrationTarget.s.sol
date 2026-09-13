// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TokenStakingMigrationAdapter as Adapter
} from "contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol";
import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";

contract Phase_08_Stage_05_StakingMigrationTarget is FeeAccrualStageBase {
    function run() external {
        _startFee("Fee accrual: verify and set existing staking target");
        _loadFeeDetf(true);
        require(deployer == stakingOwner, "Migration: signer must be staking owner");
        address endpoint = address(staking.targetDetf());
        if (endpoint == address(0) || endpoint == targetDetf) {
            require(uint256(staking.phase()) == 0, "Migration: adapter requires Staking phase");
            _broadcast();
            // Explicit owner-approved monolithic adapter exception; existing DETF and SY are reused.
            endpoint = address(
                new Adapter(
                    address(staking),
                    IERC20(dtf),
                    IERC20(targetDetf),
                    IDetfClaimPurchase(targetDetf).rebasingClaimToken()
                )
            );
            staking.setTargetDetf(IDetfClaimPurchase(endpoint));
            vm.stopBroadcast();
        }
        require(address(staking.targetDetf()) == endpoint, "Migration: target mismatch");
        _loadFeeDetf(true);
        _exportProduct("phase08_stage05_staking_migration_adapter.json", "migrationAdapter", endpoint);
    }
}
