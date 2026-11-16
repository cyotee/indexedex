// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Creation} from "@crane/contracts/utils/Creation.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/IFeeCollectorDFPkg.sol";
import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";


import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

/**
 * @title FeeCollectorProxy_Selectors_Test
 * @notice Tests that all IFeeCollectorManager selectors route correctly through the proxy
 */
contract FeeCollectorProxy_Selectors_Test is IndexedexTest {
    /// @notice The name-only package identity preserves all initial constructor bindings on reuse.
    function test_create3NameSalt_constructorBindingsAndReuse() public {
        IFeeCollectorDFPkg first = FeeCollectorFactoryService.deployFeeCollectorDFPkg(
            create3Factory, diamondCutFacet, multiStepOwnableFacet, feeCollectorSingleTokenPushFacet, feeCollectorManagerFacet);
        assertEq(address(first), Creation._create3AddressFromOf(address(create3Factory), abi.encode("FeeCollectorDFPkg")._hash()));
        address[] memory facets = first.facetAddresses();
        assertEq(facets[0], address(diamondCutFacet));
        assertEq(facets[1], address(multiStepOwnableFacet));
        assertEq(facets[2], address(feeCollectorSingleTokenPushFacet));
        assertEq(facets[3], address(feeCollectorManagerFacet));
        IFacet alternate = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet"),
            abi.encode("FeeCollectorProxy_Selectors.alternateManager")._hash());
        IFeeCollectorDFPkg again = FeeCollectorFactoryService.deployFeeCollectorDFPkg(
            create3Factory, diamondCutFacet, multiStepOwnableFacet, feeCollectorSingleTokenPushFacet, alternate);
        assertEq(address(again), address(first));
        assertEq(again.facetAddresses(), facets);
        assertEq(again.facetCuts()[3].facetAddress, address(feeCollectorManagerFacet));
    }

    using BetterEfficientHashLib for bytes;
    function setUp() public override {
        super.setUp();
    }

    function _mockBalanceOf(address token) internal {
        vm.mockCall(token, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(uint256(0)));
    }

    /* ---------------------------------------------------------------------- */
    /*                         syncReserve(IERC20)                            */
    /* ---------------------------------------------------------------------- */

    function test_syncReserve_callableViaProxy() public {
        address token = makeAddr("token");
        _mockBalanceOf(token);
        bool success = IFeeCollectorManager(address(feeCollector)).syncReserve(IERC20(token));
        assertTrue(success, "syncReserve should succeed via proxy");
    }

    /* ---------------------------------------------------------------------- */
    /*                        syncReserves(IERC20[])                          */
    /* ---------------------------------------------------------------------- */

    function test_syncReserves_callableViaProxy() public {
        address token0 = makeAddr("token0");
        address token1 = makeAddr("token1");
        _mockBalanceOf(token0);
        _mockBalanceOf(token1);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(token0);
        tokens[1] = IERC20(token1);
        bool success = IFeeCollectorManager(address(feeCollector)).syncReserves(tokens);
        assertTrue(success, "syncReserves should succeed via proxy");
    }

    function test_syncReserves_emptyArray() public {
        IERC20[] memory tokens = new IERC20[](0);
        bool success = IFeeCollectorManager(address(feeCollector)).syncReserves(tokens);
        assertTrue(success, "syncReserves with empty array should succeed");
    }

    /* ---------------------------------------------------------------------- */
    /*                   pullFee(IERC20,uint256,address)                      */
    /* ---------------------------------------------------------------------- */

    function test_pullFee_callableViaProxy() public {
        address token = makeAddr("token");
        address recipient = makeAddr("recipient");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.prank(owner);
        bool success = IFeeCollectorManager(address(feeCollector)).pullFee(IERC20(token), 0, recipient);
        assertTrue(success, "pullFee should succeed via proxy");
    }

    /* ---------------------------------------------------------------------- */
    /*                      ERC165 Interface Compliance                       */
    /* ---------------------------------------------------------------------- */

    function test_interfaceId_IFeeCollectorManager() public pure {
        bytes4 expected = IFeeCollectorManager.syncReserve.selector ^ IFeeCollectorManager.syncReserves.selector
            ^ IFeeCollectorManager.pullFee.selector ^ IFeeCollectorManager.redeemReserveLiquidity.selector;
        assertEq(
            type(IFeeCollectorManager).interfaceId,
            expected,
            "IFeeCollectorManager interfaceId should be XOR of all selectors"
        );
    }
}
