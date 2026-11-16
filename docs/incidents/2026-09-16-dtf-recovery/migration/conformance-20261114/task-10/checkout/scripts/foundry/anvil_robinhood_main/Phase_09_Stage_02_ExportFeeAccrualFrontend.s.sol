// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {
    Phase_08_Stage_07_StakingPrincipalMigration as Migration
} from "./Phase_08_Stage_07_StakingPrincipalMigration.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @notice Produces an isolated candidate export; the shell confirms live reads and receipts.
contract Phase_09_Stage_02_ExportFeeAccrualFrontend is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 09 Stage 02: Fee accrual local frontend candidate");
        _loadFeeDetf(true);
        string memory obj = "fee-frontend";
        vm.serializeUint(obj, "chainId", block.chainid);
        vm.serializeBytes32(obj, "configHash", feeConfigHash);
        vm.serializeAddress(obj, "indexedexManager", manager);
        vm.serializeAddress(obj, "protocolDetf", targetDetf);
        vm.serializeAddress(obj, "migrationTarget", address(staking.targetDetf()));
        vm.serializeAddress(obj, "stakingSY", IDETFStandardizedYield(targetDetf).stakingSY());
        vm.serializeAddress(obj, "reserveHook", IUniswapV4Detf(targetDetf).hook());
        vm.serializeAddress(obj, "rebasingClaimToken", IUniswapV4Detf(targetDetf).rebasingClaimToken());
        vm.serializeAddress(obj, "bondNftVault", IUniswapV4Detf(targetDetf).bondNftVault());
        vm.serializeAddress(obj, "liquidityVault", liquidityVault);
        vm.serializeAddress(obj, "custodyVault", custodyVault);
        vm.serializeAddress(obj, "tokenStaking", address(staking));
        vm.serializeAddress(obj, "claimVault", address(staking.claimVault()));
        vm.serializeUint(obj, "phase", uint256(staking.phase()));
        vm.serializeUint(obj, "reserveRemaining", staking.reserveRemaining());
        vm.serializeBool(obj, "isReserveLive", true);
        _writeJson(
            vm.serializeBool(obj, "receiptVerified", false), "phase09_stage02_fee_accrual_frontend_candidate.json"
        );
        _exportSnapshot("phase09_stage02_fee_accrual_staking_state.json", Migration.snapshot(staking));
    }
}
