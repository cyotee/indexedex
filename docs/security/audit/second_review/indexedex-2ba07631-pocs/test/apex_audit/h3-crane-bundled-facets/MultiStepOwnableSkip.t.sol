// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

/// Crane MultiStepOwnable: acceptOwnershipTransfer never checks pendingOwnerConfirmed or bufferPeriodEnd.
contract MultiStepOwnableSkipTest is IndexedexTest {
    function test_managerOwnershipTransferSkipsConfirmAndBuffer() public {
        IMultiStepOwnable m = IMultiStepOwnable(address(indexedexManager));
        address newOwner = makeAddr("newOwner");
        uint256 buf = m.getOwnershipTransferBuffer();
        emit log_named_uint("configured buffer (s)", buf);
        assertGt(buf, 0);

        vm.prank(owner);
        m.initiateOwnershipTransfer(newOwner);
        // Same block: no confirmOwnershipTransfer, buffer not elapsed.
        vm.prank(newOwner);
        m.acceptOwnershipTransfer();
        assertEq(m.owner(), newOwner, "ownership moved instantly");
    }
}
