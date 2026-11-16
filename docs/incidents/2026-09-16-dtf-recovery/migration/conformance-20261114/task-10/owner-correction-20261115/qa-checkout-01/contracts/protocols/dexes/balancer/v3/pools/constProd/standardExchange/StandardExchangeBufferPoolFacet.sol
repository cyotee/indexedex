// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {StandardExchangeBufferPoolTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

contract StandardExchangeBufferPoolFacet is StandardExchangeBufferPoolTarget, IFacet {
    /* ----- IStandardExchangeBufferPool storage views ----- */

    function virtualTTA() external view returns (uint256) { return StandardExchangeBufferPoolRepo._virtualTTA(); }
    function hookSharesDelta() external view returns (int256) { return StandardExchangeBufferPoolRepo._hookSharesDelta(); }
    function ttaToken() external view returns (IERC20) { return StandardExchangeBufferPoolRepo._ttaToken(); }
    function shareToken() external view returns (IERC20) { return StandardExchangeBufferPoolRepo._shareToken(); }
    function standardExchangeVault() external view returns (IStandardExchange) {
        return StandardExchangeBufferPoolRepo._standardExchangeVault();
    }
    function rateProvider() external view returns (IRateProvider) { return StandardExchangeBufferPoolRepo._rateProvider(); }
    function ttaIndex() external view returns (uint256) { return StandardExchangeBufferPoolRepo._ttaIndex(); }
    function sharesIndex() external view returns (uint256) { return StandardExchangeBufferPoolRepo._sharesIndex(); }
    function baselineRate() external view returns (uint256) { return StandardExchangeBufferPoolRepo._baselineRate(); }

    /* ----- IFacet ----- */

    function facetName() public pure returns (string memory) { return type(StandardExchangeBufferPoolFacet).name; }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](2);
        ifaces[0] = type(IBalancerV3Pool).interfaceId;
        ifaces[1] = type(IStandardExchangeBufferPool).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](12);
        funcs[0] = IBalancerV3Pool.computeInvariant.selector;
        funcs[1] = IBalancerV3Pool.computeBalance.selector;
        funcs[2] = IBalancerV3Pool.onSwap.selector;
        funcs[3] = this.virtualTTA.selector;
        funcs[4] = this.hookSharesDelta.selector;
        funcs[5] = this.ttaToken.selector;
        funcs[6] = this.shareToken.selector;
        funcs[7] = this.standardExchangeVault.selector;
        funcs[8] = this.rateProvider.selector;
        funcs[9] = this.ttaIndex.selector;
        funcs[10] = this.sharesIndex.selector;
        funcs[11] = this.baselineRate.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName(); i = facetInterfaces(); f = facetFuncs();
    }
}
