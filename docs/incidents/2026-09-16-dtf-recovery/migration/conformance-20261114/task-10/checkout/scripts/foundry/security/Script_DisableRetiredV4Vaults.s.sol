// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {DeploymentBase} from "scripts/foundry/anvil_robinhood_main/DeploymentBase.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";

/// @notice Owner-only containment of APEX-2026-010 on Robinhood mainnet.
/// @dev No live transactions are sent unless Forge is invoked with --broadcast.
contract Script_DisableRetiredV4Vaults is DeploymentBase {
    address internal constant REGISTRY = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
    address internal constant RETIRED_PACKAGE = 0x72b0243E3806eab5E30412cc93682f98f0d20eaE;
    address internal constant SEPARATE_PACKAGE = 0x0172902b0596a7c3F67dBb91542A93A4E15cFD34;
    address internal constant SEPARATE_VAULT = 0x64e0f5A5Cf0F579EFF0981A4fEDEA77964B74531;
    address internal constant FROZEN_VAULT = 0x999DaE02D22E5FEe1c4508430D5196d31d631009;

    /// @notice Collect missing disables using the standard deployer and signer configuration.
    function run() public {
        _loadConfig();
        require(block.chainid == 4663, "APEX-010: wrong chain");
        address sender = deployer;
        require(sender != address(0) && sender == IMultiStepOwnable(REGISTRY).owner(), "APEX-010: not registry owner");
        require(privateKey == 0 || vm.addr(privateKey) == sender, "APEX-010: signer mismatch");

        IVaultRegistryDisableQuery query = IVaultRegistryDisableQuery(REGISTRY);
        address[5] memory vaults = _packageVaults();
        for (uint256 i; i < vaults.length; ++i) {
            require(query.packageOfVault(vaults[i]) == RETIRED_PACKAGE, "APEX-010: unexpected vault package");
        }
        require(query.packageOfVault(SEPARATE_VAULT) == SEPARATE_PACKAGE, "APEX-010: unexpected separate package");

        console2.log("Registry", REGISTRY);
        console2.log("Registry owner / broadcaster", sender);
        IVaultRegistryDisableManager manager = IVaultRegistryDisableManager(REGISTRY);
        _broadcast();
        if (!query.isPackageDisabled(RETIRED_PACKAGE)) {
            require(manager.setPackageDisabled(RETIRED_PACKAGE, true), "APEX-010: package disable failed");
        }
        if (!query.isVaultAddressDisabled(SEPARATE_VAULT)) {
            require(manager.setVaultAddressDisabled(SEPARATE_VAULT, true), "APEX-010: vault disable failed");
        }
        if (!query.isVaultAddressDisabled(FROZEN_VAULT)) {
            require(manager.setVaultAddressDisabled(FROZEN_VAULT, true), "APEX-010: frozen vault disable failed");
        }
        vm.stopBroadcast();
        verify();
    }

    /// @notice Check containment in the selected RPC state without broadcasting.
    function verify() public view {
        require(block.chainid == 4663, "APEX-010: wrong chain");
        IVaultRegistryDisableQuery query = IVaultRegistryDisableQuery(REGISTRY);
        require(query.isPackageDisabled(RETIRED_PACKAGE), "APEX-010: package still enabled");
        require(query.isVaultAddressDisabled(SEPARATE_VAULT), "APEX-010: separate vault still enabled");
        require(query.isVaultAddressDisabled(FROZEN_VAULT), "APEX-010: frozen vault still enabled");
        address[5] memory vaults = _packageVaults();
        for (uint256 i; i < vaults.length; ++i) {
            require(query.isDisabled(vaults[i]), "APEX-010: package vault still enabled");
            console2.log("Disabled vault", vaults[i]);
        }
        require(query.isDisabled(SEPARATE_VAULT), "APEX-010: separate vault not contained");
        require(query.isDisabled(FROZEN_VAULT), "APEX-010: frozen vault not contained");
        console2.log("Disabled vault", SEPARATE_VAULT);
        console2.log("Disabled vault", FROZEN_VAULT);
        console2.log("All seven audited vaults disabled in the selected state");
    }

    function _packageVaults() internal pure returns (address[5] memory) {
        return [
            0x201d31a56c58a3489beC218c7A899d59A07A35f0,
            0xb7D4Bb379D361AD442CddEE53eA71a33957826A7,
            0x3E33871A8740b294A48347BFFD8A5004E1578c0D,
            0xabC9C5B5c8118a15A440Ac59a1C74A718E65681C,
            0x17B5f1045Edf3b6215d0C38eB9FF50649d887D10
        ];
    }
}
