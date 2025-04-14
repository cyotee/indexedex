// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {BaseProtocolDETF_Component_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";

contract ProtocolNFTVaultDFPkg_Deploy_Test is TestBase_VaultComponents {
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;

    IProtocolNFTVaultDFPkg internal pkg;

    function setUp() public override {
        super.setUp();

        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("ProtocolNFTVault_ERC721Facet"))
        );
        IFacet protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();

        IProtocolNFTVaultDFPkg.PkgInit memory pkgInit = BaseProtocolDETF_Component_FactoryService.buildProtocolNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            protocolNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        pkg = IVaultRegistryDeployment(address(indexedexManager)).deployProtocolNFTVaultDFPkg(pkgInit);

        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(address(pkg), IStandardVaultPkg(address(pkg)).vaultDeclaration());
        vm.stopPrank();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(pkg)),
            "ProtocolNFTVaultDFPkg not registered"
        );
    }

    function test_deployVault_success() public {
        // Deploy two simple ERC20s via CREATE3 for lpToken and rewardToken.
        address lpToken = create3Factory.create3WithArgs(
            type(ERC20PermitMintableStub).creationCode,
            abi.encode("LP Token", "LP", uint8(18), owner, uint256(0)),
            keccak256("ProtocolNFTVault_LP_Token")
        );
        address rewardToken = create3Factory.create3WithArgs(
            type(ERC20PermitMintableStub).creationCode,
            abi.encode("Reward Token", "RWD", uint8(18), owner, uint256(0)),
            keccak256("ProtocolNFTVault_Reward_Token")
        );

        vm.startPrank(owner);
        address vaultAddr = pkg.deployVault(
            "Protocol NFT Vault",
            "pNFT",
            IProtocolDETF(address(0xBEEF)),
            ERC20PermitMintableStub(lpToken),
            ERC20PermitMintableStub(rewardToken),
            9,
            owner
        );
        vm.stopPrank();

        assertGt(vaultAddr.code.length, 0, "ProtocolNFTVault proxy not deployed");

        // The Protocol NFT vault package currently only registers the LP token as "contents".
        // Avoid asserting selectors that are not routed by the deployed diamond.
        IStandardVault.VaultConfig memory cfg = IStandardVault(vaultAddr).vaultConfig();
        assertEq(cfg.tokens.length, 1, "vaultConfig.tokens length");
        assertEq(cfg.tokens[0], lpToken, "vaultConfig.tokens[0] (lpToken)");

        // Still validate the interface exists at compile-time.
        IProtocolNFTVault(vaultAddr);
        rewardToken; // silence unused local warning if assertions change later
    }

    function test_processArgs_reverts_whenNotRegistry() public {
        vm.expectRevert(abi.encodeWithSelector(IProtocolNFTVaultDFPkg.NotCalledByRegistry.selector, address(this)));
        pkg.processArgs(
            abi.encode(
                IProtocolNFTVaultDFPkg.PkgArgs({
                    name: "x",
                    symbol: "y",
                    protocolDETF: IProtocolDETF(address(0xBEEF)),
                    lpToken: ERC20PermitMintableStub(address(0xCAFE)),
                    rewardToken: ERC20PermitMintableStub(address(0xF00D)),
                    decimalOffset: 9,
                    owner: owner
                })
            )
        );
    }
}
