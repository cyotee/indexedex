// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @notice Local V4 market money paths on each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopV4Market_Decimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
    using AaveV4Service for ISpoke;

    address internal lp = address(0xA11CE);

    function test_v4_market_tokens_listed() public view {
        assertEq(v4Hub.getAssetId(address(tokenA)), v4AssetIdA, "tokenA assetId");
        assertEq(v4Hub.getAssetId(address(tokenB)), v4AssetIdB, "tokenB assetId");
        assertEq(v4Spoke.getReserveId(address(v4Hub), v4AssetIdA), v4ReserveIdA, "tokenA reserveId");
        assertEq(v4Spoke.getReserveId(address(v4Hub), v4AssetIdB), v4ReserveIdB, "tokenB reserveId");
    }

    function test_v4_supply_increases_suppliedOf() public {
        _mint(tokenA, address(this), _uA(100));
        tokenA.approve(address(v4Spoke), _uA(100));
        uint256 before = v4Spoke.suppliedOf(v4ReserveIdA, address(this));
        AaveV4Service.supply(v4Spoke, v4ReserveIdA, _uA(100));
        assertGt(v4Spoke.suppliedOf(v4ReserveIdA, address(this)), before, "supplied increased");
    }

    function test_v4_supply_collateral_then_borrow() public {
        _mint(tokenB, lp, _uB(1_000));
        vm.startPrank(lp);
        tokenB.approve(address(v4Spoke), _uB(1_000));
        v4Spoke.supply(v4ReserveIdB, _uB(1_000), lp);
        vm.stopPrank();

        _mint(tokenA, address(this), _uA(100));
        tokenA.approve(address(v4Spoke), _uA(100));
        AaveV4Service.supply(v4Spoke, v4ReserveIdA, _uA(100));
        v4Spoke.setUsingAsCollateral(v4ReserveIdA, true, address(this));

        uint256 debtBefore = v4Spoke.debtOf(v4ReserveIdB, address(this));
        AaveV4Service.borrow(v4Spoke, v4ReserveIdB, _uB(100));
        uint256 debtAfter = v4Spoke.debtOf(v4ReserveIdB, address(this));

        assertGt(debtAfter, debtBefore, "debt increased after borrow");
        assertGe(debtAfter - debtBefore, _uB(100), "debt >= borrowed");
        assertEq(tokenB.balanceOf(address(this)), _uB(100), "received borrowed tokenB");
    }
}
