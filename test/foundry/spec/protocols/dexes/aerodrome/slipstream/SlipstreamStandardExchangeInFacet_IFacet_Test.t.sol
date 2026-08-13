// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {Slipstream_Component_FactoryService} from "contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    ICLMintCallback
} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/callback/ICLMintCallback.sol";
import {
    ICLSwapCallback
} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/callback/ICLSwapCallback.sol";
import {SlipstreamStandardExchangeInFacet} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInFacet.sol";

/**
 * @title SlipstreamStandardExchangeInFacet_IFacet_Test
 * @notice Validates SlipstreamStandardExchangeInFacet exposes correct interfaces and selectors
 * @author cyotee doge <doge.cyotee>
 */
contract SlipstreamStandardExchangeInFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using Slipstream_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deploySlipstreamStandardExchangeInFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(SlipstreamStandardExchangeInFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](3);
        controlInterfaces[0] = type(IStandardExchangeIn).interfaceId;
        controlInterfaces[1] = type(ICLMintCallback).interfaceId;
        controlInterfaces[2] = type(ICLSwapCallback).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](4);
        controlFuncs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        controlFuncs[1] = IStandardExchangeIn.exchangeIn.selector;
        controlFuncs[2] = ICLMintCallback.uniswapV3MintCallback.selector;
        controlFuncs[3] = ICLSwapCallback.uniswapV3SwapCallback.selector;
    }
}
