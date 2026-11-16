// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {StandardExchangeBufferPool_FactoryService as Single} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_FactoryService.sol";
import {MultiPairStandardExchangeBufferPool_FactoryService as MultiPair} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPool_FactoryService.sol";
import {MixedLegWeightedBufferPool_FactoryService as MixedLeg} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPool_FactoryService.sol";
import {CommonBufferMultiVaultWeightedPool_FactoryService as CommonWeighted} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPool_FactoryService.sol";
import {CommonBufferMultiVaultStablePool_FactoryService as CommonStable} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePool_FactoryService.sol";
import {MixedBufferMultiVaultStablePool_FactoryService as MixedStable} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_FactoryService.sol";

contract BalancerSeTransitionFactoryLinkingTest is IndexedexTest {
    function test_allSixFactories_linkAndReuseTransitionQuoteFacet() public {
        address expected_ = address(Single.deployTransitionQuoteFacet(create3Factory));
        assertGt(expected_.code.length, 0, "linked facet deployed");
        assertLe(expected_.code.length, 24_576, "deployable runtime");
        assertEq(address(MultiPair.deployTransitionQuoteFacet(create3Factory)), expected_);
        assertEq(address(MixedLeg.deployTransitionQuoteFacet(create3Factory)), expected_);
        assertEq(address(CommonWeighted.deployTransitionQuoteFacet(create3Factory)), expected_);
        assertEq(address(CommonStable.deployTransitionQuoteFacet(create3Factory)), expected_);
        assertEq(address(MixedStable.deployTransitionQuoteFacet(create3Factory)), expected_);
    }
}
