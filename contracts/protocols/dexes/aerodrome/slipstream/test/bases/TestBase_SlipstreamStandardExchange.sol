// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    Slipstream_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol";

/**
 * @title TestBase_SlipstreamStandardExchange
 * @notice Test base for Slipstream Standard Exchange vault testing.
 * @dev Inherits from:
 *      - TestBase_Permit2: Provides permit2 contract
 *      - TestBase_VaultComponents: Provides core vault facets
 *      - IndexedexTest: Provides indexedexManager and create3Factory
 */
contract TestBase_SlipstreamStandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using Slipstream_Component_FactoryService for ICreate3FactoryProxy;

    IFacet slipstreamStandardExchangeInFacet;
    IFacet slipstreamStandardExchangeOutFacet;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();
        slipstreamStandardExchangeInFacet = create3Factory.deploySlipstreamStandardExchangeInFacet();
        slipstreamStandardExchangeOutFacet = create3Factory.deploySlipstreamStandardExchangeOutFacet();
    }
}
