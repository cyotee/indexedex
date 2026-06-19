// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TestBase_AaveV3StataFork} from "./TestBase_AaveV3StataFork.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title AaveV3StataFork_PreviewMatch (Ethereum)
 * @notice Forked mainnet integration tests against production Aave V3 on Ethereum.
 *         Validates preview matches execution and deltas on live StataTokenV2.
 */
contract AaveV3StataFork_PreviewMatch is TestBase_AaveV3StataFork {
    function test_ForkEth_Real_BaseToSE_PreviewMatchesExec() public {
        uint256 amount = 1e18;
        deal(liveUnderlying, address(this), amount);
        IERC20(liveUnderlying).approve(vault, amount);

        uint256 preview = IStandardExchangeIn(vault).previewExchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault)
        );

        uint256 out = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault), 0, address(this), false, block.timestamp + 3600
        );

        assertEq(out, preview, "eth fork: preview must equal exec on production Aave/Stata");
        assertEq(IERC20(vault).balanceOf(address(this)), out);
    }

    function testFuzz_ForkEth_BaseToSE(uint256 amount) public {
        amount = bound(amount, 0.01e18, 5e18);
        deal(liveUnderlying, address(this), amount);
        IERC20(liveUnderlying).approve(vault, amount);

        uint256 preview = IStandardExchangeIn(vault).previewExchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault)
        );
        uint256 out = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault), 0, address(this), false, block.timestamp + 3600
        );
        assertEq(out, preview);
    }
}