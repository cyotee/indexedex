// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";

import {RebasingAwareERC4626Facet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Facet.sol";
import {RebasingAwareStandardExchangeFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeFacet.sol";
import {RebasingAwareStandardYieldFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldFacet.sol";
import {RebasingAwareVaultMetadataFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataFacet.sol";
import {RebasingAwareStandardExchangeQuoteFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeQuoteFacet.sol";
import {RebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626DFPkg.sol";

abstract contract TestBase_RebasingAwareERC4626 is IndexedexTest {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IFacet erc20Facet;
    IFacet rebasingAwareErc4626Facet;
    IFacet standardExchangeFacet;
    IFacet standardYieldFacet;
    IFacet vaultMetadataFacet;
    IFacet transitionQuoteFacet;
    IRebasingAwareERC4626DFPkg pkg;
    IERC4626 vault;
    ERC20PermitMintableStub asset;

    address alice;
    address bob;
    address attacker;
    address receiver;

    uint8 constant DEFAULT_OFFSET = 10;

    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");
        receiver = makeAddr("receiver");

        erc20Facet = create3Factory.deployERC20Facet();
        rebasingAwareErc4626Facet = create3Factory.deployRebasingAwareERC4626Facet();
        standardExchangeFacet = create3Factory.deployRebasingAwareStandardExchangeFacet();
        standardYieldFacet = create3Factory.deployRebasingAwareStandardYieldFacet();
        vaultMetadataFacet = create3Factory.deployRebasingAwareVaultMetadataFacet();
        transitionQuoteFacet = create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();

        vm.prank(owner);
        pkg = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
            indexedexManager, _pkgInit()
        );

        asset = new ERC20PermitMintableStub("Asset", "AST", 18, address(this), 0);
        vault = pkg.deployVault(IERC20Metadata(address(asset)));
        vm.label(address(vault), "RebasingAwareVault");

        asset.mint(alice, 1_000_000e18);
        asset.mint(bob, 1_000_000e18);
        asset.mint(attacker, 1_000_000e18);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(attacker);
        asset.approve(address(vault), type(uint256).max);
    }

    function _pkgInit() internal view returns (IRebasingAwareERC4626DFPkg.PkgInit memory) {
        return IRebasingAwareERC4626DFPkg.PkgInit({
            erc20Facet: erc20Facet,
            rebasingAwareErc4626Facet: rebasingAwareErc4626Facet,
            diamondFactory: diamondPackageFactory,
            standardExchangeFacet: standardExchangeFacet,
            standardYieldFacet: standardYieldFacet,
            vaultMetadataFacet: vaultMetadataFacet,
            transitionQuoteFacet: transitionQuoteFacet,
            vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
        });
    }

    function _deployVault(IERC20Metadata asset_, uint8 offset)
        internal
        returns (IERC4626 vault_)
    {
        vault_ = pkg.deployVault(asset_, offset, bytes32(0));
    }

    function _virtualShares(uint8 offset) internal pure returns (uint256) {
        return 10 ** offset;
    }
}
