// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {ProtocolDETFIntegrationBase} from "test/foundry/spec/vaults/protocol/ProtocolDETF_IntegrationBase.t.sol";

contract RICHIRPermissions_Negative_Test is ProtocolDETFIntegrationBase {
    function test_mintFromNFTSale_revertsForNonOwner() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        richir.mintFromNFTSale(1, attacker);
    }

    function test_mintFromNFTSale_revertsForZeroAmount_evenForOwner() public {
        vm.prank(address(detf));
        vm.expectRevert(IProtocolDETFErrors.ZeroAmount.selector);
        richir.mintFromNFTSale(0, detfAlice);
    }
}
