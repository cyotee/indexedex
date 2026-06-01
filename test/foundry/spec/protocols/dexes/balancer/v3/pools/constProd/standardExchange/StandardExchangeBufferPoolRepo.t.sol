// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

contract StandardExchangeBufferPoolRepoHarness {
    function init(
        IERC20 tta,
        IERC20 shares,
        IStandardExchange seVault,
        IRateProvider rp,
        uint256 ttaIdx,
        uint256 sharesIdx,
        address expectedFactory_
    ) external {
        StandardExchangeBufferPoolRepo._initialize(tta, shares, seVault, rp, ttaIdx, sharesIdx, expectedFactory_);
    }
    function setVirtualTTA(uint256 v) external { StandardExchangeBufferPoolRepo._setVirtualTTA(v); }
    function getVirtualTTA() external view returns (uint256) { return StandardExchangeBufferPoolRepo._virtualTTA(); }
    function setHookSharesDelta(int256 v) external { StandardExchangeBufferPoolRepo._setHookSharesDelta(v); }
    function getHookSharesDelta() external view returns (int256) { return StandardExchangeBufferPoolRepo._hookSharesDelta(); }
    function getTTA() external view returns (IERC20) { return StandardExchangeBufferPoolRepo._ttaToken(); }
    function getShares() external view returns (IERC20) { return StandardExchangeBufferPoolRepo._shareToken(); }
    function getSeVault() external view returns (IStandardExchange) { return StandardExchangeBufferPoolRepo._standardExchangeVault(); }
    function getRP() external view returns (IRateProvider) { return StandardExchangeBufferPoolRepo._rateProvider(); }
    function getTtaIdx() external view returns (uint256) { return StandardExchangeBufferPoolRepo._ttaIndex(); }
    function getSharesIdx() external view returns (uint256) { return StandardExchangeBufferPoolRepo._sharesIndex(); }
    function getExpectedFactory() external view returns (address) { return StandardExchangeBufferPoolRepo._expectedFactory(); }
}

contract StandardExchangeBufferPoolRepoTest is Test {
    StandardExchangeBufferPoolRepoHarness harness;
    function setUp() public { harness = new StandardExchangeBufferPoolRepoHarness(); }

    function test_initialize_setsAllImmutables() public {
        harness.init(IERC20(address(0x1)), IERC20(address(0x2)), IStandardExchange(address(0x3)), IRateProvider(address(0x4)), 0, 1, address(0x5));
        assertEq(address(harness.getTTA()), address(0x1));
        assertEq(address(harness.getShares()), address(0x2));
        assertEq(address(harness.getSeVault()), address(0x3));
        assertEq(address(harness.getRP()), address(0x4));
        assertEq(harness.getTtaIdx(), 0);
        assertEq(harness.getSharesIdx(), 1);
        assertEq(harness.getExpectedFactory(), address(0x5));
    }

    function test_virtualTTA_roundTrip() public {
        harness.setVirtualTTA(42e18);
        assertEq(harness.getVirtualTTA(), 42e18);
    }

    function test_hookSharesDelta_canBeNegative() public {
        harness.setHookSharesDelta(-100);
        assertEq(harness.getHookSharesDelta(), -100);
        harness.setHookSharesDelta(int256(7e18));
        assertEq(harness.getHookSharesDelta(), int256(7e18));
    }
}
