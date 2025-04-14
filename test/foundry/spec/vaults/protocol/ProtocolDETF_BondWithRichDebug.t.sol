// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {ProtocolDETFIntegrationBase as BaseIntegration} from "./ProtocolDETF_IntegrationBase.t.sol";
import {ProtocolDETFIntegrationBase as EthereumIntegration} from "./EthereumProtocolDETF_IntegrationBase.t.sol";

contract ProtocolDETFBondWithRichDebugBaseTest is BaseIntegration {
    function test_debug_bond_with_rich_effect_on_synthetic_price() public {
        _runBondSweep("base");
    }

    function _runBondSweep(string memory label_) internal {
        uint256[] memory steps = new uint256[](5);
        steps[0] = 10_000e18;
        steps[1] = 50_000e18;
        steps[2] = 100_000e18;
        steps[3] = 250_000e18;
        steps[4] = 500_000e18;

        console.log(label_);
        console.log("initial syntheticPrice", detf.syntheticPrice());

        vm.startPrank(detfAlice);
        rich.approve(address(detf), type(uint256).max);
        for (uint256 i = 0; i < steps.length; ++i) {
            IBaseProtocolDETFBonding(address(detf)).bondWithRich(
                steps[i],
                30 days,
                detfAlice,
                block.timestamp + 1 hours
            );
            console.log("richBonded", steps[i]);
            console.log("syntheticPrice", detf.syntheticPrice());
        }
        vm.stopPrank();
    }
}

contract ProtocolDETFBondWithRichDebugEthereumTest is EthereumIntegration {
    function test_debug_bond_with_rich_effect_on_synthetic_price() public {
        _runBondSweep("ethereum");
    }

    function _runBondSweep(string memory label_) internal {
        uint256[] memory steps = new uint256[](5);
        steps[0] = 10_000e18;
        steps[1] = 50_000e18;
        steps[2] = 100_000e18;
        steps[3] = 250_000e18;
        steps[4] = 500_000e18;

        console.log(label_);
        console.log("initial syntheticPrice", detf.syntheticPrice());

        vm.startPrank(detfAlice);
        rich.approve(address(detf), type(uint256).max);
        for (uint256 i = 0; i < steps.length; ++i) {
            IBaseProtocolDETFBonding(address(detf)).bondWithRich(
                steps[i],
                30 days,
                detfAlice,
                block.timestamp + 1 hours
            );
            console.log("richBonded", steps[i]);
            console.log("syntheticPrice", detf.syntheticPrice());
        }
        vm.stopPrank();
    }
}