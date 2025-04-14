// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";

import {
    ProtocolDETFBaseCustomFixtureHelpers,
    ProtocolDETFEthereumCustomFixtureHelpers
} from "./ProtocolDETF_CustomFixtureHelpers.t.sol";

contract ProtocolDETFChirBurnDebugBaseTest is ProtocolDETFBaseCustomFixtureHelpers {
    function test_debug_rich_to_chir_can_cross_burn_threshold() public {
        IProtocolDETF mintEnabledDetf = _deployMintEnabledDetf();

        _assertMintEnabled(mintEnabledDetf);
        _runRichToChirSweep("base", mintEnabledDetf);
    }

    function _runRichToChirSweep(string memory label_, IProtocolDETF detf_) internal {
        uint256 burnThreshold = detf_.burnThreshold();

        console.log(label_);
        console.log("initial syntheticPrice", detf_.syntheticPrice());
        console.log("burnThreshold", burnThreshold);

        uint256[] memory steps = new uint256[](7);
        steps[0] = 10_000e18;
        steps[1] = 50_000e18;
        steps[2] = 100_000e18;
        steps[3] = 250_000e18;
        steps[4] = 500_000e18;
        steps[5] = 1_000_000e18;
        steps[6] = 5_000_000e18;

        for (uint256 i = 0; i < steps.length; ++i) {
            uint256 richAmount = steps[i];
            vm.startPrank(owner);
            rich.transfer(detfBob, richAmount);
            vm.stopPrank();

            vm.startPrank(detfBob);
            rich.approve(address(detf_), richAmount);
            IStandardExchangeIn(address(detf_)).exchangeIn(
                rich,
                richAmount,
                IERC20(address(detf_)),
                0,
                detfBob,
                false,
                block.timestamp + 1 hours
            );
            vm.stopPrank();

            console.log("richIn", richAmount);
            console.log("syntheticPrice", detf_.syntheticPrice());
        }

        assertGt(detf_.syntheticPrice(), burnThreshold, "rich to chir sweep should cross the lower deadband bound");
    }
}

contract ProtocolDETFChirBurnDebugEthereumTest is ProtocolDETFEthereumCustomFixtureHelpers {
    function test_debug_rich_to_chir_can_cross_burn_threshold() public {
        _driveEthereumToMintEnabled(detf);
        _runRichToChirSweep("ethereum", detf);
    }

    function _runRichToChirSweep(string memory label_, IProtocolDETF detf_) internal {
        uint256 burnThreshold = detf_.burnThreshold();

        console.log(label_);
        console.log("initial syntheticPrice", detf_.syntheticPrice());
        console.log("burnThreshold", burnThreshold);

        uint256[] memory steps = new uint256[](7);
        steps[0] = 10_000e18;
        steps[1] = 50_000e18;
        steps[2] = 100_000e18;
        steps[3] = 250_000e18;
        steps[4] = 500_000e18;
        steps[5] = 1_000_000e18;
        steps[6] = 5_000_000e18;

        for (uint256 i = 0; i < steps.length; ++i) {
            uint256 richAmount = steps[i];
            vm.startPrank(owner);
            rich.transfer(detfBob, richAmount);
            vm.stopPrank();

            vm.startPrank(detfBob);
            rich.approve(address(detf_), richAmount);
            IStandardExchangeIn(address(detf_)).exchangeIn(
                rich,
                richAmount,
                IERC20(address(detf_)),
                0,
                detfBob,
                false,
                block.timestamp + 1 hours
            );
            vm.stopPrank();

            console.log("richIn", richAmount);
            console.log("syntheticPrice", detf_.syntheticPrice());
        }

        assertGt(detf_.syntheticPrice(), burnThreshold, "rich to chir sweep should cross the lower deadband bound");
    }
}