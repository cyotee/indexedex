// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ERC165Repo} from "@crane/contracts/introspection/ERC165/ERC165Repo.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {ReceiptBackedERC4626Target} from "contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol";

contract ReceiptBackedDispatchHarness is ReceiptBackedERC4626Target {
    function setGeneric() external {
        ERC165Repo._registerInterface(type(IERC4626StandardExchange).interfaceId);
    }

    function setStata() external {
        ERC165Repo._registerInterface(type(IAaveV3StataStandardVault).interfaceId);
    }
}

/// @dev Non-SUT unit host for D45 both/neither marker errors.
contract ReceiptBackedERC4626_Dispatch_Test is Test {
    ReceiptBackedDispatchHarness internal harness;

    function setUp() public {
        harness = new ReceiptBackedDispatchHarness();
    }

    function test_APEX005_neitherMarkerRevertsUnsupportedFamily() public {
        vm.expectRevert(ReceiptBackedERC4626Target.UnsupportedAccountingFamily.selector);
        harness.asset();
    }

    function test_APEX005_bothMarkersRevertUnsupportedFamily() public {
        harness.setGeneric();
        harness.setStata();
        vm.expectRevert(ReceiptBackedERC4626Target.UnsupportedAccountingFamily.selector);
        harness.asset();
    }

    function test_APEX005_genericMarkerAllowsDispatch() public {
        harness.setGeneric();
        assertEq(harness.asset(), address(0));
    }

    function test_APEX005_stataMarkerAllowsDispatch() public {
        harness.setStata();
        assertEq(harness.asset(), address(0));
    }
}
