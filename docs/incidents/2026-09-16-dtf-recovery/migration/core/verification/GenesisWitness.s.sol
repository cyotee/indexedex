// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice Independent defect witness using genuine registry-deployed proxies.
/// @dev Exit zero confirms the counterexample, not acceptance of the implementation.
contract GenesisWitness is TestBase_UniswapV4DetfMigration {
    function run() external {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(pairA);
        tokens[1] = IERC20(pairB);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 1 ether;
        (address[] memory requiredTokens, uint256[] memory requiredAmounts) =
            migration.previewFirstBondPayments(tokens[0], amounts[0]);
        uint256 requiredOther;
        for (uint256 i; i < requiredTokens.length; ++i) {
            if (requiredTokens[i] == pairB) requiredOther = requiredAmounts[i];
        }
        migration.donateMigrationCapital(tokens, amounts, 0, 0, block.timestamp);

        Migration.GenesisLeg[] memory legs = new Migration.GenesisLeg[](2);
        legs[0] = Migration.GenesisLeg(tokens[0], amounts[0], 1);
        legs[1] = Migration.GenesisLeg(tokens[1], amounts[1], 1);
        vm.prank(migrationOwner);
        (uint256 selfMinted, uint256 lpOut) =
            allocation.bootstrapMigrationReserve(legs, 0, 1, block.timestamp);

        require(requiredOther > amounts[1], "counterexample must underfund other leg");
        require(migration.isReserveLive() && lpOut > 0, "real full book must become live");
        require(IERC20(detf).totalSupply() == selfMinted, "only actual genesis supply");
        require(receipt.totalSupply() == 0, "no counterfeit participant");
        console2.log("GENESIS_PARENT", detf);
        console2.log("GENESIS_SELF_MINTED", selfMinted);
        console2.log("GENESIS_OTHER_PAID", amounts[1]);
        console2.log("GENESIS_OTHER_REQUIRED", requiredOther);
        console2.log("GENESIS_CHILD_LP", IERC20(migration.hook()).balanceOf(address(bonds)));
    }
}

/// @dev The test fixture is an ordinary local harness, not the ephemeral script
/// address. Every subject it constructs still uses the real factory/registry.
contract GenesisWitnessRunner is Script {
    function run() external {
        GenesisWitness witness = new GenesisWitness();
        vm.allowCheatcodes(address(witness));
        witness.setUp();
        witness.run();
    }
}
