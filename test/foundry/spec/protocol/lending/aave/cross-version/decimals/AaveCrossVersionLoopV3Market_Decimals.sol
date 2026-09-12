// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @notice Local V3.6 market money paths on each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopV3Market_Decimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
    address internal v3lp = address(0xB0B);

    function test_v3_reserves_listed() public view {
        assertTrue(v36Pool.getReserveAToken(address(tokenA)) != address(0), "tokenA listed on V3");
        assertTrue(v36Pool.getReserveAToken(address(tokenB)) != address(0), "tokenB listed on V3");
    }

    function test_v3_supply_then_borrow() public {
        _mint(tokenB, v3lp, _uB(1_000));
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), _uB(1_000));
        v36Pool.supply(address(tokenB), _uB(1_000), v3lp, 0);
        vm.stopPrank();

        _mint(tokenA, address(this), _uA(100));
        tokenA.approve(address(v36Pool), _uA(100));
        AaveV36Service.supply(v36Pool, address(tokenA), _uA(100));

        uint256 debtBefore = AaveV36Service.debtOf(v36Pool, address(tokenB), address(this));
        AaveV36Service.borrow(v36Pool, address(tokenB), _uB(100));
        uint256 debtAfter = AaveV36Service.debtOf(v36Pool, address(tokenB), address(this));

        assertGt(debtAfter, debtBefore, "debt increased after borrow");
        assertGe(debtAfter, _uB(100), "debt >= borrowed");
        assertEq(tokenB.balanceOf(address(this)), _uB(100), "received borrowed tokenB");
        assertGt(AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(this)), 0, "supplied tokenA");
    }

    function test_v3_market_deployed() public view {
        assertTrue(address(v36Pool) != address(0), "pool deployed");
        assertTrue(v36AddressesProvider != address(0), "addresses provider deployed");
        assertTrue(v36PoolConfigurator != address(0), "configurator deployed");
        assertTrue(v36Oracle != address(0), "oracle deployed");
        assertTrue(v36ConfigEngine != address(0), "config engine deployed");
        assertEq(address(v36Pool.ADDRESSES_PROVIDER()), v36AddressesProvider, "pool->provider wired");
    }

    function test_v3_and_v4_markets_coexist() public view {
        assertTrue(address(v36Pool) != address(0), "v3 pool up");
        assertTrue(address(v4Hub) != address(0), "v4 hub up");
        assertTrue(address(v4Spoke) != address(0), "v4 spoke up");
        assertTrue(address(tokenA) != address(0) && address(tokenB) != address(0), "tokens up");
    }
}
