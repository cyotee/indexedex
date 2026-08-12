// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_AaveV3StataFork} from "./TestBase_AaveV3StataFork.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title AaveV3StataFork_PreviewMatch
 * @notice Forked mainnet integration tests against production Aave V3.6 + StataTokenV2.
 *         Validates that previewExchangeIn/Out exactly matches the value returned by
 *         exchangeIn/exchangeOut AND the actual tokens received by the recipient (balance delta).
 *
 *         Runs on Base mainnet fork (production code/state).
 *         Includes fuzz variants for robustness.
 */
contract AaveV3StataFork_PreviewMatch is TestBase_AaveV3StataFork {
    /// @dev Live Stata maxDeposit can be 0 when reserve is paused/frozen or supply cap is full.
    function _liveStataDepositRoomOk(uint256 amount) internal view returns (bool) {
        return IERC4626(liveStata).maxDeposit(vault) >= amount;
    }

    function test_Fork_Real_BaseToSE_PreviewMatchesExec() public {
        uint256 amount = 1e18;
        if (!_liveStataDepositRoomOk(amount)) return;
        deal(liveUnderlying, address(this), amount);
        IERC20(liveUnderlying).approve(vault, amount);

        uint256 preview = IStandardExchangeIn(vault).previewExchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault)
        );

        uint256 out = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault), 0, address(this), false, block.timestamp + 3600
        );

        assertEq(out, preview, "fork: previewExchangeIn must equal returned from exchangeIn (live stata)");
        assertEq(IERC20(vault).balanceOf(address(this)), out, "fork: recipient delta must match preview/returned");
        assertGt(out, 0);
    }

    function test_Fork_Real_SEToStata_PreviewMatchesExec() public {
        uint256 dep = 2e18;
        if (!_liveStataDepositRoomOk(dep)) return;
        deal(liveUnderlying, address(this), dep);
        IERC20(liveUnderlying).approve(vault, dep);

        uint256 seReceived = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), dep, IERC20(vault), 0, address(this), false, block.timestamp + 3600
        );

        uint256 sharesToBurn = seReceived / 2;
        if (sharesToBurn == 0) return;

        uint256 previewIn = IStandardExchangeOut(vault).previewExchangeOut(
            IERC20(vault), IERC20(liveStata), sharesToBurn
        );

        uint256 stataBefore = IERC20(liveStata).balanceOf(address(this));
        uint256 amtIn = IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), sharesToBurn, IERC20(liveStata), sharesToBurn, address(this), false, block.timestamp + 3600
        );

        assertEq(amtIn, previewIn, "fork: previewExchangeOut must equal returned amtIn for SE->stata live");
        uint256 received = IERC20(liveStata).balanceOf(address(this)) - stataBefore;
        assertGt(received, 0);
    }

    function test_Fork_Real_SEToBase_PreviewMatchesExec() public {
        uint256 dep = 1.5e18;
        if (!_liveStataDepositRoomOk(dep)) return;
        deal(liveUnderlying, address(this), dep);
        IERC20(liveUnderlying).approve(vault, dep);

        uint256 seReceived = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), dep, IERC20(vault), 0, address(this), false, block.timestamp + 3600
        );

        uint256 sharesToBurn = seReceived / 3;
        if (sharesToBurn == 0) return;

        uint256 previewIn = IStandardExchangeOut(vault).previewExchangeOut(
            IERC20(vault), IERC20(liveUnderlying), sharesToBurn
        );

        uint256 amtIn = IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), sharesToBurn, IERC20(liveUnderlying), sharesToBurn, address(this), false, block.timestamp + 3600
        );

        assertEq(amtIn, previewIn, "fork: preview must equal exec for SE->base on live stata");
    }

    /* --------------------------- Fuzz on fork (production) --------------------------- */

    function testFuzz_Fork_BaseToSE(uint256 amount) public {
        // When live stata supply cap is full / paused, maxDeposit is 0 — do not vm.assume
        // (would exhaust fuzz rejects). Skip the run cleanly.
        uint256 maxDep = IERC4626(liveStata).maxDeposit(vault);
        if (maxDep < 0.01e18) return;
        amount = bound(amount, 0.01e18, maxDep < 10e18 ? maxDep : 10e18);
        deal(liveUnderlying, address(this), amount);
        IERC20(liveUnderlying).approve(vault, amount);

        uint256 preview = IStandardExchangeIn(vault).previewExchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault)
        );
        uint256 out = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault), 0, address(this), false, block.timestamp + 3600
        );
        assertEq(out, preview);
        assertEq(IERC20(vault).balanceOf(address(this)), out);
    }

    function testFuzz_Fork_SEToStata(uint256 dep, uint256 burnPct) public {
        uint256 maxDep = IERC4626(liveStata).maxDeposit(vault);
        if (maxDep < 0.1e18) return;
        dep = bound(dep, 0.1e18, maxDep < 5e18 ? maxDep : 5e18);
        burnPct = bound(burnPct, 1, 80);

        deal(liveUnderlying, address(this), dep);
        IERC20(liveUnderlying).approve(vault, dep);

        uint256 seGot = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), dep, IERC20(vault), 0, address(this), false, block.timestamp + 3600
        );

        uint256 sharesToBurn = (seGot * burnPct) / 100;
        if (sharesToBurn == 0) return;

        uint256 previewIn = IStandardExchangeOut(vault).previewExchangeOut(
            IERC20(vault), IERC20(liveStata), sharesToBurn
        );

        uint256 amtIn = IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), sharesToBurn, IERC20(liveStata), sharesToBurn, address(this), false, block.timestamp + 3600
        );
        assertEq(amtIn, previewIn);
    }

    function testFuzz_Fork_FeeAndPre(uint256 amount, uint256 feeWad) public {
        uint256 maxDep = IERC4626(liveStata).maxDeposit(vault);
        if (maxDep < 0.1e18) return;
        amount = bound(amount, 0.1e18, maxDep < 3e18 ? maxDep : 3e18);
        feeWad = bound(feeWad, 0, 0.05e18); // 0-5%

        deal(liveUnderlying, address(this), amount);
        IERC20(liveUnderlying).approve(vault, amount);

        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, vault),
            abi.encode(feeWad)
        );

        uint256 preview = IStandardExchangeIn(vault).previewExchangeIn(IERC20(liveUnderlying), amount, IERC20(vault));

        address user = address(0xBEEF1234);
        uint256 balBefore = IERC20(vault).balanceOf(user);
        uint256 out = IStandardExchangeIn(vault).exchangeIn(
            IERC20(liveUnderlying), amount, IERC20(vault), 0, user, false, block.timestamp + 3600
        );
        uint256 received = IERC20(vault).balanceOf(user) - balBefore;

        assertEq(out, preview);
        assertEq(received, preview);

        // reset
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, vault),
            abi.encode(0)
        );
    }
}