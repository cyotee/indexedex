// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from "./Phase_08_Stage_07_StakingPrincipalMigration.sol";

contract Phase_08_Stage_07_StakingPrincipalMigration is FeeAccrualStageBase {
    function run() external {
        _startFee("Fee accrual: migrate combined principal/rewards in bounded chunks");
        _loadFeeDetf(true);
        require(deployer == stakingOwner, "Migration: signer must be staking owner");
        uint256 maximum = vm.parseJsonUint(feeConfig, ".migration.maxChunkInput");
        uint256 slippage = vm.parseJsonUint(feeConfig, ".migration.slippageBps");
        uint256 ttl = vm.parseJsonUint(feeConfig, ".migration.deadlineSeconds");
        uint256 maxChunks = vm.parseJsonUint(feeConfig, ".migration.maxChunks");
        require(maximum > 0 && slippage < 10000 && ttl > 0 && maxChunks > 0, "Migration: invalid limits");
        string memory chunks;
        uint256 count;
        while (staking.reserveRemaining() != 0 && count < maxChunks) {
            string memory chunk = _migrateChunk(maximum, slippage, ttl, count);
            chunks = count == 0 ? chunk : string.concat(chunks, ",", chunk);
            ++count;
        }
        require(count > 0, "Migration: nothing to convert");
        _writeJson(string.concat('{"configHash":"', vm.toString(feeConfigHash),
            '","receiptVerified":false,"chunks":[', chunks, "]}"),
            "phase08_stage07_staking_principal_migration.json");
        _exportSnapshot("phase08_stage07_staking_migration_state.json", Migration.snapshot(staking));
    }

    function _migrateChunk(uint256 maximum, uint256 slippage, uint256 ttl, uint256 index)
        private returns (string memory)
    {
        uint256 amount = Migration.nextChunkAmount(staking, targetDetf, maximum);
        uint256 deadline = block.timestamp + ttl;
        // Quote the complete real path, including the staking contract's stored claim package.
        // Roll back only this quote's simulation; retain previously recorded broadcast calls.
        uint256 checkpoint = vm.snapshotState();
        vm.startPrank(stakingOwner);
        Migration.Result memory quote = Migration.execute(staking, targetDetf, amount, maximum, 1, deadline);
        vm.stopPrank();
        require(vm.revertToStateAndDelete(checkpoint), "Migration: quote rollback failed");
        uint256 minimum = quote.claimOut * (10000 - slippage) / 10000;
        require(minimum > 0, "Migration: rounded zero minimum");
        _broadcast();
        Migration.Result memory result = Migration.execute(staking, targetDetf, amount, maximum, minimum, deadline);
        vm.stopBroadcast();
        string memory obj = string.concat("migration-chunk-", vm.toString(index));
        vm.serializeUint(obj, "amountIn", amount);
        vm.serializeUint(obj, "minClaimOut", minimum);
        vm.serializeUint(obj, "deadline", deadline);
        vm.serializeUint(obj, "claimOut", result.claimOut);
        vm.serializeUint(obj, "sharesOut", result.sharesOut);
        vm.serializeUint(obj, "beforeRemaining", result.beforeState.remaining);
        return vm.serializeUint(obj, "afterRemaining", result.afterState.remaining);
    }
}
