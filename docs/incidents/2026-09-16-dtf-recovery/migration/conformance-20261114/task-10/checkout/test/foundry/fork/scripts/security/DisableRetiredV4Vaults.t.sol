// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {Script_DisableRetiredV4Vaults} from "scripts/foundry/security/Script_DisableRetiredV4Vaults.s.sol";

/// @notice Rehearse containment against the actual deployed registry; nothing is broadcast.
contract DisableRetiredV4VaultsForkTest is Test, Script_DisableRetiredV4Vaults {
    function setUp() public {
        vm.createSelectFork(vm.envOr("ROBINHOOD_MAINNET_RPC_URL", string("https://rpc.mainnet.chain.robinhood.com")));
        // Local fork only: use Forge's default broadcaster as the registry owner.
        _transferRegistryOwnership(msg.sender);
    }

    /// @notice Cover config, both signing branches, containment, replay, and rejection guards.
    /// @dev Keep environment mutations in one test: process environment is shared across tests.
    function test_standardSignerConfigurationAndContainment() public {
        address registryOwner = IMultiStepOwnable(REGISTRY).owner();
        IVaultRegistryDisableManager manager = IVaultRegistryDisableManager(REGISTRY);
        // Exercise every write independently of which flags are already set at the fork tip.
        vm.startPrank(registryOwner);
        manager.setPackageDisabled(RETIRED_PACKAGE, false);
        manager.setVaultAddressDisabled(SEPARATE_VAULT, false);
        manager.setVaultAddressDisabled(FROZEN_VAULT, false);
        vm.stopPrank();

        _configuredRun(registryOwner, 0);
        IVaultRegistryDisableQuery query = IVaultRegistryDisableQuery(REGISTRY);
        assertTrue(query.isPackageDisabled(RETIRED_PACKAGE));
        assertTrue(query.isVaultAddressDisabled(SEPARATE_VAULT));
        assertTrue(query.isVaultAddressDisabled(FROZEN_VAULT));
        address[5] memory vaults = _packageVaults();
        for (uint256 i; i < vaults.length; ++i) {
            assertTrue(query.isDisabled(vaults[i]));
        }
        assertTrue(query.isDisabled(SEPARATE_VAULT));
        assertTrue(query.isDisabled(FROZEN_VAULT));

        vm.recordLogs();
        _configuredRun(registryOwner, 0);
        assertEq(vm.getRecordedLogs().length, 0, "replay must not write disable flags");

        vm.expectRevert(bytes("APEX-010: not registry owner"));
        _configuredRun(makeAddr("notRegistryOwner"), 0);

        vm.chainId(1);
        vm.expectRevert(bytes("APEX-010: wrong chain"));
        _configuredRun(registryOwner, 0);
        vm.expectRevert(bytes("APEX-010: wrong chain"));
        this.verify();
        vm.chainId(4663);

        uint256 key = 0xA11CE;
        vm.expectRevert(bytes("APEX-010: signer mismatch"));
        _configuredRun(registryOwner, key);

        address signer = vm.addr(key);
        _transferRegistryOwnership(signer);
        vm.prank(signer);
        manager.setPackageDisabled(RETIRED_PACKAGE, false);
        _configuredRun(signer, key);
        verify();
    }

    function _configuredRun(address sender, uint256 key) internal {
        string memory previousDeployer = vm.envOr("DEPLOYER_ADDRESS", string(""));
        string memory previousKey = vm.envOr("PRIVATE_KEY", string(""));
        vm.setEnv("DEPLOYER_ADDRESS", vm.toString(sender));
        vm.setEnv("PRIVATE_KEY", vm.toString(key));
        this.run();
        vm.setEnv("DEPLOYER_ADDRESS", previousDeployer);
        vm.setEnv("PRIVATE_KEY", previousKey);
    }

    function _transferRegistryOwnership(address nextOwner) internal {
        IMultiStepOwnable ownership = IMultiStepOwnable(REGISTRY);
        address currentOwner = ownership.owner();
        vm.prank(currentOwner);
        ownership.initiateOwnershipTransfer(nextOwner);
        vm.warp(block.timestamp + ownership.getOwnershipTransferBuffer());
        vm.prank(currentOwner);
        ownership.confirmOwnershipTransfer(nextOwner);
        vm.prank(nextOwner);
        ownership.acceptOwnershipTransfer();
    }
}
