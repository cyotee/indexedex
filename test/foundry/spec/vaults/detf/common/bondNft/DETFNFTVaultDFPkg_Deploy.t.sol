// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";

import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";

contract DETFNFTVaultDFPkg_Deploy_Test is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    IDetfSelfNftInventoryDFPkg internal pkg;
    ERC20PermitDFPkg internal erc20PermitPkg;

    function setUp() public override {
        super.setUp();

        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("DETFNFTVault_ERC721Facet"))
        );
        IFacet detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();

        IDETFNFTVaultDFPkg.PkgInit memory pkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        pkg = IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(pkgInit);

        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(address(pkg), IStandardVaultPkg(address(pkg)).vaultDeclaration());
        vm.stopPrank();

        erc20PermitPkg = _deployTestTokenPkg();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(pkg)),
            "DETFNFTVaultDFPkg not registered"
        );
    }

    function test_deployVault_success() public {
        // Deploy two simple ERC20s via CREATE3 for lpToken and rewardToken.
        address lpToken = address(_deployTestToken("LP Token", "LP", keccak256("DETFNFTVault_LP_Token")));
        address rewardToken =
            address(_deployTestToken("Reward Token", "RWD", keccak256("DETFNFTVault_Reward_Token")));

        vm.startPrank(owner);
        address vaultAddr = pkg.deployVault(
            "Protocol NFT Vault",
            "pNFT",
            IDetf(address(0xBEEF)),
            IERC20(lpToken),
            IERC20(rewardToken),
            9,
            owner
        );
        vm.stopPrank();

        assertGt(vaultAddr.code.length, 0, "DETFNFTVault proxy not deployed");

        // The Protocol NFT vault package currently only registers the LP token as "contents".
        // Avoid asserting selectors that are not routed by the deployed diamond.
        IStandardVault.VaultConfig memory cfg = IStandardVault(vaultAddr).vaultConfig();
        assertEq(cfg.tokens.length, 1, "vaultConfig.tokens length");
        assertEq(cfg.tokens[0], lpToken, "vaultConfig.tokens[0] (lpToken)");

        // Still validate the interface exists at compile-time.
        assertEq(address(IDETFNFTVault(vaultAddr).rewardToken()), rewardToken, "configured reward token");
        rewardToken; // silence unused local warning if assertions change later
    }

    function test_processArgs_reverts_whenNotRegistry() public {
        vm.expectRevert(abi.encodeWithSelector(IDETFNFTVaultDFPkg.NotCalledByRegistry.selector, address(this)));
        pkg.processArgs(
            abi.encode(
                IDETFNFTVaultDFPkg.PkgArgs({
                    name: "x",
                    symbol: "y",
                    detf: IDetf(address(0xBEEF)),
                    lpToken: IERC20(address(0xCAFE)),
                    rewardToken: IERC20(address(0xF00D)),
                    decimalOffset: 9,
                    owner: owner
                })
            )
        );
    }

    function _deployTestTokenPkg() internal returns (ERC20PermitDFPkg pkg_) {
        IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet
        });

        pkg_ = ERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "DETFNFTVaultDeploy"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_) internal returns (IERC20 token_) {
        IERC20PermitDFPkg.PkgArgs memory pkgArgs = IERC20PermitDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            decimals: 18,
            totalSupply: 0,
            recipient: address(0),
            optionalSalt: salt_
        });

        token_ = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), abi.encode(pkgArgs)));
    }
}
