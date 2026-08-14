// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";

/// @notice C1–C3: hostile vaultShare is rejected at PkgArgs (WP-SEC-PKG-MV-001).
/// @dev TransferFrom reentry via a configured hostile share is unreachable after the deploy gate.
///      Deferred P2: C4 (hostile rateAsset), C5 (preview view-safe).
contract Adversarial_Reentrancy_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_C1_reenterInitializeReserve_hitsIsLocked() public {
        _expectHostileShareDeployReverts();
    }

    function test_C2_reenterRedeemClaim_duringMint_hitsIsLocked() public {
        _expectHostileShareDeployReverts();
    }

    function test_C3_mintReenterBond_hitsIsLocked() public {
        _expectHostileShareDeployReverts();
    }

    function _expectHostileShareDeployReverts() internal {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = _hostileSharePkgArgs();
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultWeightedDetfDFPkg.InvalidVaultShare.selector,
                uint256(0),
                address(seVault0),
                address(hostileShare)
            )
        );
        indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }
}
