// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";

import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {UniswapV3FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {
    TestBase_UniswapV3FullSpreadStandardExchangeVault
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultDFPkg_Deploy_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces, address[] memory facets) =
            UniswapV3FullSpreadStandardExchangeVaultDFPkg(address(uniswapV3StandardExchangeDFPkg)).packageMetadata();

        assertEq(name_, type(UniswapV3FullSpreadStandardExchangeVaultDFPkg).name, "package name");
        assertEq(interfaces.length, 15, "interface count");
        assertEq(facets.length, 15, "facet count");
        assertEq(facets[0], address(erc20Facet), "erc20");
        assertEq(facets[5], address(uniswapV3StandardExchangeInFacet), "in");
        assertEq(facets[6], address(uniswapV3StandardExchangeInQueryFacet), "in query");
        assertEq(facets[7], address(uniswapV3StandardExchangeOutFacet), "out");
        assertEq(facets[8], address(uniswapV3StandardExchangeOutQueryFacet), "out query");
        assertEq(facets[9], address(uniswapV3StandardExchangePositionImportFacet), "import");
        assertEq(facets[10], address(uniswapV3StandardExchangeLiquidReserveFacet), "liquid reserve");
        assertEq(facets[11], address(uniswapV3StandardExchangeInMultiFacet), "in multi");
        assertEq(facets[12], address(uniswapV3StandardExchangeInMultiQueryFacet), "in multi query");
        assertEq(facets[13], address(uniswapV3StandardExchangeOutMultiFacet), "out multi");
        assertEq(facets[14], address(uniswapV3StandardExchangeOutMultiQueryFacet), "out multi query");
    }

    function test_deployVault_registersAndInitializesPool() public {
        IUniswapV3Pool pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        address vault = address(_deployVault(pool));

        assertTrue(vault != address(0), "vault deployed");
        assertTrue(indexedexManager.isVault(vault), "registered");

        address[] memory vaultTokens = IBasicVault(vault).vaultTokens();
        assertEq(vaultTokens.length, 2);
        assertEq(vaultTokens[0], pool.token0());
        assertEq(vaultTokens[1], pool.token1());

        assertEq(IERC20Metadata(vault).symbol(), "UV3X");

        // Storage reads via staticcall into vault context for pool binding would require a view facet;
        // assert init via successful registry + token wiring above and factory-mismatch below.
        IStandardVault.VaultConfig memory config = IStandardVault(vault).vaultConfig();
        assertEq(config.tokens.length, 2);
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeIn).interfaceId), "erc165 in");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeOut).interfaceId), "erc165 out");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeInMulti).interfaceId), "erc165 in multi");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeOutMulti).interfaceId), "erc165 out multi");
        assertTrue(
            IERC165(vault).supportsInterface(type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId),
            "erc165 liquid reserve"
        );
        assertTrue(
            IERC165(vault).supportsInterface(type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId),
            "erc165 liquid reserve"
        );
    }

    function test_deployVault_revertsWhenPoolFactoryMismatch() public {
        // Pool from a different factory.
        UniswapV3Factory otherFactory = new UniswapV3Factory();
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        IUniswapV3Pool roguePool = IUniswapV3Pool(otherFactory.createPool(t0, t1, FEE_MEDIUM));
        roguePool.initialize(uint160(uint256(1) << 96));

        vm.expectRevert(abi.encodeWithSignature("InvalidPoolFactory(address,address)", address(otherFactory), address(uniswapV3Factory)));
        uniswapV3StandardExchangeDFPkg.deployVault(roguePool);
    }

    function test_componentSalts_areAbiEncodedNamesOnFactoryPath() public {
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("create3(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        }
        address inDelegate = UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("create3(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate(create3Factory);
        }
        address outDelegate = UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate(create3Factory);
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultInFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", bytes.concat(ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInFacet"), abi.encode(inDelegate)), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultInFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultInQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInQueryFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultOutFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", bytes.concat(ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutFacet"), abi.encode(outDelegate)), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultOutFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.sol:UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultPositionImportFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet.sol:UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInMultiFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultInMultiFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInMultiFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInMultiFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultInMultiFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet"), salt));
            UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet(create3Factory);
        }
    }

    function test_packageSalt_isAbiEncodedNameOnRegistryPath() public {
        IUniswapV3FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV3StandardExchangeInFacet = uniswapV3StandardExchangeInFacet;
        pkgInit.uniswapV3StandardExchangeInQueryFacet = uniswapV3StandardExchangeInQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutFacet = uniswapV3StandardExchangeOutFacet;
        pkgInit.uniswapV3StandardExchangeOutQueryFacet = uniswapV3StandardExchangeOutQueryFacet;
        pkgInit.uniswapV3StandardExchangePositionImportFacet = uniswapV3StandardExchangePositionImportFacet;
        pkgInit.uniswapV3StandardExchangeLiquidReserveFacet = uniswapV3StandardExchangeLiquidReserveFacet;
        pkgInit = UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.attachUniswapV3FullSpreadStandardExchangeVaultMultiFacets(
            pkgInit,
            uniswapV3StandardExchangeInMultiFacet,
            uniswapV3StandardExchangeInMultiQueryFacet,
            uniswapV3StandardExchangeOutMultiFacet,
            uniswapV3StandardExchangeOutMultiQueryFacet
        );
        pkgInit.vaultFeeOracleQuery = indexedexManager;
        pkgInit.vaultRegistryDeployment = indexedexManager;
        pkgInit.permit2 = permit2;
        pkgInit.uniswapV3Factory = uniswapV3Factory;

        bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultDFPkg"));
        assertTrue(salt != keccak256(bytes("UniswapV3FullSpreadStandardExchangeVaultDFPkg")));
        vm.expectCall(address(indexedexManager), abi.encodeWithSignature("deployPkg(bytes,bytes,bytes32)",
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV3FullSpreadStandardExchangeVaultDFPkg"), abi.encode(pkgInit), salt));
        vm.prank(owner);
        UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV3FullSpreadStandardExchangeVaultDFPkg(indexedexManager, pkgInit);
    }
}
