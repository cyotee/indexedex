// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_ModeC
} from "scripts/foundry/research/uniswapV2Se/ResearchFixture_ModeC.sol";
import {
    ResearchModeCCloser
} from "scripts/foundry/research/uniswapV2Se/ResearchModeCCloser.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";

/**
 * @notice One-step Mode C diagnostic: Uni trade then try Balancer swap + closer.
 */
contract Script_ModeC_Diag is Script {
    function run() external {
        ResearchFixture_ModeC f = new ResearchFixture_ModeC();
        f.bootstrapModeC();
        f.initTelemetry("modeC_diag", true);
        f.configureCloser();
        _afterBoot(f);
    }

    function _afterBoot(ResearchFixture_ModeC f) internal {
        console2.log("spot0", f.uniSpotUsdcPerWeth());
        f.swapUniExactIn(address(f.tokenWeth()), address(f.tokenUsdc()), f.TRADE_WETH());
        console2.log("spot1", f.uniSpotUsdcPerWeth());
        _tryManualSwap(f);
        (uint256 p, uint256 fills) = f.closeBalancerArbs();
        console2.log("close profit", p);
        console2.log("close fills", fills);
    }

    function _tryManualSwap(ResearchFixture_ModeC f) internal {
        ResearchModeCCloser.Env memory e = f.closer().env();
        address pool = f.matrixPools(0);
        address pair = address(f.matrixPairToken(0));
        uint256 pairIn = 1e18;

        console2.log("pool0", pool);
        console2.log("pair0", pair);

        if (pair == e.weth) {
            vm.deal(e.agent, pairIn);
            vm.prank(e.agent);
            (bool ok,) = e.weth.call{value: pairIn}(abi.encodeWithSignature("deposit()"));
            require(ok, "weth");
        } else {
            (bool ok,) = pair.call(abi.encodeWithSignature("mint(address,uint256)", e.agent, pairIn));
            require(ok, "mint");
        }

        uint256 sh0 = IERC20(e.shares).balanceOf(e.agent);
        vm.startPrank(e.agent);
        IERC20(pair).approve(e.permit2, type(uint256).max);
        (bool p2ok,) = e.permit2.call(
            abi.encodeWithSignature(
                "approve(address,address,uint160,uint48)",
                pair,
                e.balRouter,
                type(uint160).max,
                type(uint48).max
            )
        );
        console2.log("permit2 ok", p2ok);
        try IRouter(e.balRouter).swapSingleTokenExactIn(
            pool,
            IERC20(pair),
            IERC20(e.shares),
            pairIn,
            0,
            block.timestamp + 1 hours,
            false,
            bytes("")
        ) returns (uint256 amountOut) {
            console2.log("swap ok out", amountOut);
        } catch Error(string memory reason) {
            console2.log("swap revert:");
            console2.log(reason);
        } catch (bytes memory low) {
            console2.log("swap bytes len", low.length);
            console2.logBytes(low);
        }
        vm.stopPrank();
        console2.log("shares delta", IERC20(e.shares).balanceOf(e.agent) - sh0);
    }
}
