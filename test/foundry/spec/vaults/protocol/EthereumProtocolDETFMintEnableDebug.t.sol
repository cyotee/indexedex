// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ProtocolDETFIntegrationBase} from "./EthereumProtocolDETF_IntegrationBase.t.sol";

contract EthereumProtocolDETFMintEnableDebugTest is ProtocolDETFIntegrationBase {
    function test_debug_weth_to_rich_effect_on_synthetic_price() public {
        uint256[] memory steps = new uint256[](12);
        steps[0] = 10_000e18;
        steps[1] = 50_000e18;
        steps[2] = 100_000e18;
        steps[3] = 250_000e18;
        steps[4] = 500_000e18;
        steps[5] = 1_000_000e18;
        steps[6] = 100_000e18;
        steps[7] = 100_000e18;
        steps[8] = 100_000e18;
        steps[9] = 200_000e18;
        steps[10] = 200_000e18;
        steps[11] = 3_300_000e18;

        _mintWeth(detfAlice, 10_000_000e18);

        console.log("initial syntheticPrice", detf.syntheticPrice());
        console.log("burnThreshold", detf.burnThreshold());
        console.log("mintThreshold", detf.mintThreshold());

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), type(uint256).max);
        for (uint256 i = 0; i < steps.length; ++i) {
            uint256 amountIn = steps[i];
            uint256 richOut = IStandardExchangeIn(address(detf)).exchangeIn(
                IERC20(address(weth9)),
                amountIn,
                rich,
                0,
                detfAlice,
                false,
                block.timestamp + 1 hours
            );
            console.log("wethIn", amountIn);
            console.log("richOut", richOut);
            console.log("syntheticPrice", detf.syntheticPrice());
        }
        vm.stopPrank();
    }
}