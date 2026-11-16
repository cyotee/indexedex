// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationDeploymentGasResumedQA} from "scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";

/// @notice Genuine registry, loader and funded bond measurements. Signed cold receipts are separate evidence.
contract MigrationOperationGasTest is MigrationDeploymentGasResumedQA {
    /// @notice Exercises 1/8/16/32/64 complete selected records and originals per recipient.
    function test_completeRecordAndOriginalArrayGasMatrix() public {
        TestBase_UniswapV4DetfMigration.setUp();
        _fundAndCapture();
        _operationSamples();
    }
}
