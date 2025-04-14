// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IERC4626PermitDFPkg} from "@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol";

/// @title Script_14_DeployERC4626PermitVaults
/// @notice Deploys ERC4626 vaults for each test token (TTA, TTB, TTC) using ERC4626PermitDFPkg
/// @dev Run: forge script scripts/foundry/anvil_base_main/Script_14_DeployERC4626PermitVaults.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender <DEV_ADDRESS>
contract Script_14_DeployERC4626PermitVaults is DeploymentBase {
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    // Shared facets
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;

    // Test tokens
    IERC20Metadata private ttA;
    IERC20Metadata private ttB;
    IERC20Metadata private ttC;

    // Package + deployed vaults
    IERC4626PermitDFPkg private erc4626PermitDFPkg;
    address private erc4626VaultTTA;
    address private erc4626VaultTTB;
    address private erc4626VaultTTC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 14: Deploy ERC4626 Permit Vaults");

        vm.startBroadcast();

        _deployPkg();
        _deployVaults();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory =
            IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));

        erc20Facet = IFacet(_readAddress("02_shared_facets.json", "erc20Facet"));
        erc2612Facet = IFacet(_readAddress("02_shared_facets.json", "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress("02_shared_facets.json", "erc5267Facet"));
        erc4626Facet = IFacet(_readAddress("02_shared_facets.json", "erc4626Facet"));

        ttA = IERC20Metadata(_readAddress("05_test_tokens.json", "testTokenA"));
        ttB = IERC20Metadata(_readAddress("05_test_tokens.json", "testTokenB"));
        ttC = IERC20Metadata(_readAddress("05_test_tokens.json", "testTokenC"));

        require(address(create3Factory) != address(0), "Create3Factory not found");
        require(address(diamondPackageFactory) != address(0), "DiamondPackageFactory not found");
        require(address(ttA) != address(0), "TTA not found");
        require(address(ttB) != address(0), "TTB not found");
        require(address(ttC) != address(0), "TTC not found");
    }

    function _deployPkg() internal {
        erc4626PermitDFPkg =
            create3Factory.deployERC4626PermitDFPkg(erc20Facet, erc5267Facet, erc2612Facet, erc4626Facet);
        require(address(erc4626PermitDFPkg) != address(0), "ERC4626PermitDFPkg deploy failed");
    }

    function _deployVaults() internal {
        erc4626VaultTTA = _deployVaultFor(ttA);
        erc4626VaultTTB = _deployVaultFor(ttB);
        erc4626VaultTTC = _deployVaultFor(ttC);
    }

    function _deployVaultFor(IERC20Metadata reserveAsset) internal returns (address deployed) {
        IERC4626PermitDFPkg.PkgArgs memory args = IERC4626PermitDFPkg.PkgArgs({
            reserveAsset: reserveAsset,
            optionalDecimalOffset: 10,
            optionalSalt: bytes32(0),
            optionalInitialDeposit: 0,
            depositor: address(0),
            recipient: address(0)
        });

        deployed = diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc4626PermitDFPkg)), abi.encode(args));
        require(deployed != address(0), "ERC4626 vault deploy failed");
    }

    function _exportJson() internal {
        string memory json;
        // IMPORTANT: keep this file flat (no nested objects) for DeploymentBase._readAddress
        json = vm.serializeAddress("", "erc4626PermitDFPkg", address(erc4626PermitDFPkg));
        json = vm.serializeAddress("", "erc4626VaultTTA", erc4626VaultTTA);
        json = vm.serializeAddress("", "erc4626VaultTTB", erc4626VaultTTB);
        json = vm.serializeAddress("", "erc4626VaultTTC", erc4626VaultTTC);
        _writeJson(json, "14_erc4626_permit_vaults.json");
    }

    function _logResults() internal view {
        _logAddress("ERC4626PermitDFPkg:", address(erc4626PermitDFPkg));
        _logAddress("ERC4626 Vault (TTA):", erc4626VaultTTA);
        _logAddress("ERC4626 Vault (TTB):", erc4626VaultTTB);
        _logAddress("ERC4626 Vault (TTC):", erc4626VaultTTC);
        _logComplete("Stage 14");
    }
}
