// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {TestBase_AaveCrossVersionLoopV4Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";

/**
 * @title AaveCrossVersionLoopV4Market_Test
 * @notice Proves the portable local V4 market stands up with our own test tokens listed, and that
 *         AaveV4Service supply/borrow/read wrappers work against it. Foundation for the V3 market +
 *         deterministic profitable-loop tests.
 */
contract AaveCrossVersionLoopV4Market_Test is TestBase_AaveCrossVersionLoopV4Market {
    using AaveV4Service for ISpoke;

    address internal lp = address(0xA11CE);

    function test_v4_market_tokens_listed() public view {
        assertEq(v4Hub.getAssetId(address(tokenA)), v4AssetIdA, "tokenA assetId");
        assertEq(v4Hub.getAssetId(address(tokenB)), v4AssetIdB, "tokenB assetId");
        assertEq(v4Spoke.getReserveId(address(v4Hub), v4AssetIdA), v4ReserveIdA, "tokenA reserveId");
        assertEq(v4Spoke.getReserveId(address(v4Hub), v4AssetIdB), v4ReserveIdB, "tokenB reserveId");
    }

    function test_v4_supply_increases_suppliedOf() public {
        _mint(tokenA, address(this), 100e18);
        tokenA.approve(address(v4Spoke), 100e18);
        uint256 before = v4Spoke.suppliedOf(v4ReserveIdA, address(this));
        AaveV4Service.supply(v4Spoke, v4ReserveIdA, 100e18);
        assertGt(v4Spoke.suppliedOf(v4ReserveIdA, address(this)), before, "supplied increased");
    }

    function test_v4_supply_collateral_then_borrow() public {
        // LP seeds tokenB borrow liquidity.
        _mint(tokenB, lp, 1_000e6);
        vm.startPrank(lp);
        tokenB.approve(address(v4Spoke), 1_000e6);
        v4Spoke.supply(v4ReserveIdB, 1_000e6, lp);
        vm.stopPrank();

        // This contract supplies tokenA as collateral and borrows tokenB.
        _mint(tokenA, address(this), 100e18);
        tokenA.approve(address(v4Spoke), 100e18);
        AaveV4Service.supply(v4Spoke, v4ReserveIdA, 100e18);
        v4Spoke.setUsingAsCollateral(v4ReserveIdA, true, address(this));

        uint256 debtBefore = v4Spoke.debtOf(v4ReserveIdB, address(this));
        AaveV4Service.borrow(v4Spoke, v4ReserveIdB, 100e6);
        uint256 debtAfter = v4Spoke.debtOf(v4ReserveIdB, address(this));

        assertGt(debtAfter, debtBefore, "debt increased after borrow");
        assertGe(debtAfter - debtBefore, 100e6, "debt >= borrowed");
        assertEq(tokenB.balanceOf(address(this)), 100e6, "received borrowed tokenB");
    }
}
