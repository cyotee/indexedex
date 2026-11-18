// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Phase_08_Stage_01_MigrationExecution} from
    "scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {IUniswapV4DetfMigrationWeightedPricingV3 as PricingV3,
    IUniswapV4DetfMigrationWeightedPricingAllocationV3 as AllocationV3} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";

/// @notice The native caller's typed contract for a current pricing-book submission.
interface IMigrationNativePricingStage {
    function setPricingV3(AllocationV3 proxy_, Pricing.InputsV3 calldata next_) external returns (bytes32 bookId_);
}

/// @notice The actual native stage submits complete observed V3 operands through the owner's real proxy.
contract MigrationNativeScriptTest is TestBase_UniswapV4DetfMigration {
    function test_nativeStageSetsCurrentBookWithoutRepricingLoadedCredit() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("native-script-original"));
        bytes memory configured_ = abi.encode(migration.independentAllocation(address(this)));
        uint256 supply_ = IERC20(detf).totalSupply();
        Pricing.InputsV3 memory next_ = _manualInputs();
        next_.swapFeeWad = 1e16;
        Phase_08_Stage_01_MigrationExecution stage_ = new Phase_08_Stage_01_MigrationExecution();
        string memory previousSender_ = vm.envOr("SENDER", string(""));
        vm.setEnv("SENDER", vm.toString(migrationOwner));
        bytes32 nextId_ = IMigrationNativePricingStage(address(stage_)).setPricingV3(AllocationV3(detf), next_);
        vm.setEnv("SENDER", previousSender_);

        Pricing.BookV3 memory stored_ = PricingV3(detf).migrationWeightedPricingV3();
        assertNotEq(nextId_, pricingId, "new manual inputs replace the current book");
        assertEq(stored_.id, nextId_);
        assertEq(stored_.version, 3);
        assertEq(abi.encode(stored_.inputs), abi.encode(next_), "complete current operands reach the proxy");
        assertEq(abi.encode(migration.independentAllocation(address(this))), configured_, "loaded credit is unchanged");
        assertEq(IERC20(detf).totalSupply(), supply_, "pricing submission issues nothing");
    }
}
