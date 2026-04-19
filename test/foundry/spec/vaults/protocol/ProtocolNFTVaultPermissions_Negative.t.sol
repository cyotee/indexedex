// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ProtocolNFTVaultCommon} from "contracts/vaults/protocol/ProtocolNFTVaultCommon.sol";
import {ProtocolDETFIntegrationBase} from "test/foundry/spec/vaults/protocol/ProtocolDETF_IntegrationBase.t.sol";

contract ProtocolNFTVaultPermissions_Negative_Test is ProtocolDETFIntegrationBase {
    function test_createPosition_revertsForNonOwner() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        protocolNFTVault.createPosition(1, 30 days, attacker);
    }

    function test_initializeProtocolNFT_revertsForNonOwner() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        protocolNFTVault.initializeProtocolNFT();
    }

    function test_addToProtocolNFT_revertsForNonOwner() public {
        address attacker = makeAddr("attacker");
        uint256 protocolId = protocolNFTVault.protocolNFTId();

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        protocolNFTVault.addToProtocolNFT(protocolId, 1);
    }

    function test_sellPositionToProtocol_revertsForNonOwner() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        protocolNFTVault.sellPositionToProtocol(2, attacker, attacker);
    }

    function test_markProtocolNFTSold_revertsForNonOwner() public {
        address attacker = makeAddr("attacker");
        uint256 protocolId = protocolNFTVault.protocolNFTId();

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        protocolNFTVault.markProtocolNFTSold(protocolId);
    }

    function test_createPosition_revertsForZeroShares_evenForOwner() public {
        vm.prank(address(detf));
        vm.expectRevert(ProtocolNFTVaultCommon.BaseSharesZero.selector);
        protocolNFTVault.createPosition(0, 30 days, detfAlice);
    }

    /* ---------------------------------------------------------------------- */
    /*                   reallocateProtocolRewards Authorization              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that reallocateProtocolRewards reverts when called by an unauthorized address.
     * @dev The function should only be callable by feeOracle.feeTo() (the FeeCollector) or the Protocol DETF.
     */
    function test_reallocateProtocolRewards_revertsForUnauthorizedCaller() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.NotAuthorized.selector, attacker));
        protocolNFTVault.reallocateProtocolRewards(attacker);
    }

    /**
     * @notice Test that reallocateProtocolRewards reverts even when called by the feeOracle itself.
     * @dev Only feeOracle.feeTo() (FeeCollector) or the Protocol DETF is authorized.
     *      The oracle contract itself should NOT be authorized.
     */
    function test_reallocateProtocolRewards_revertsForFeeOracle() public {
        // indexedexManager is the feeOracle in test setup
        address oracleAddress = address(indexedexManager);

        vm.prank(oracleAddress);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.NotAuthorized.selector, oracleAddress));
        protocolNFTVault.reallocateProtocolRewards(detfAlice);
    }

    /**
     * @notice Test that reallocateProtocolRewards reverts when called by owner.
     * @dev Owner is not the FeeCollector or the Protocol DETF, so should be unauthorized.
     */
    function test_reallocateProtocolRewards_revertsForOwner() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.NotAuthorized.selector, owner));
        protocolNFTVault.reallocateProtocolRewards(owner);
    }

    /**
     * @notice Test that reallocateProtocolRewards succeeds when called by feeTo (FeeCollector).
     * @dev This is the authorized caller per the interface documentation.
     */
    function test_reallocateProtocolRewards_succeedsForFeeTo() public {
        // Get the feeTo address (FeeCollector) from the oracle
        address feeToAddress = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());

        // Call from the FeeCollector - should NOT revert
        vm.prank(feeToAddress);
        uint256 amount = protocolNFTVault.reallocateProtocolRewards(detfAlice);

        // Amount may be 0 if no rewards accumulated, but call should succeed
        // The important thing is that it doesn't revert with NotAuthorized
        assertGe(amount, 0, "Amount should be >= 0");
    }

    /**
     * @notice Test that reallocateProtocolRewards succeeds when called by the Protocol DETF.
     * @dev captureSeigniorage() relies on this authorization path to compound only the protocol NFT's CHIR share.
     */
    function test_reallocateProtocolRewards_succeedsForProtocolDetf() public {
        vm.prank(address(detf));
        uint256 amount = protocolNFTVault.reallocateProtocolRewards(detfAlice);

        assertGe(amount, 0, "Amount should be >= 0");
    }
}
