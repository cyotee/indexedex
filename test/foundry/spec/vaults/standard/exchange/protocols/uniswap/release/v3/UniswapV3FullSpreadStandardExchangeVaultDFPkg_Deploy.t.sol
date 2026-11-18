// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";
import {UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";
import {UniswapV3FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as Family} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as FeeIdentity} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";

/// @notice V3-OWN-03/04: real registry deployment and versioned component identities.
contract UniswapV3FullSpreadStandardExchangeVaultDFPkg_Deploy_Test is FullSpreadReleaseFixture {
    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces, address[] memory facets) =
            UniswapV3FullSpreadStandardExchangeVaultDFPkg(address(uniswapV3StandardExchangeDFPkg)).packageMetadata();
        assertEq(name_, "UniswapV3FullSpreadStandardExchangeVaultDFPkg.v4Accounting.v2");
        assertEq(interfaces.length, 14);
        assertEq(interfaces[9], type(IBasicVault).interfaceId);
        assertEq(interfaces[10], type(IStandardExchangeBundleIn).interfaceId);
        assertEq(interfaces[11], type(IStandardExchangeBundleOut).interfaceId);
        assertEq(interfaces[12], type(Family).interfaceId);
        assertEq(interfaces[13], type(IStandardExchangeStateQuote).interfaceId);
        address[14] memory expected = [address(erc20Facet), address(erc5267Facet), address(erc2612Facet),
            address(multiAssetBasicVaultFacet), address(multiAssetStandardVaultFacet),
            address(uniswapV3StandardExchangeInFacet), address(uniswapV3StandardExchangeInQueryFacet),
            address(uniswapV3StandardExchangeOutFacet), address(uniswapV3StandardExchangeOutQueryFacet),
            address(uniswapV3StandardExchangePositionImportFacet), address(uniswapV3StandardExchangeLiquidReserveFacet),
            address(uniswapV3StandardExchangeInMultiFacet), address(uniswapV3StandardExchangeInMultiQueryFacet),
            address(uniswapV3StandardExchangeOutMultiFacet)];
        assertEq(facets.length, expected.length);
        for (uint256 i; i < expected.length; ++i) assertEq(facets[i], expected[i]);
    }

    function test_deployVault_registersAndInitializesPool() public view {
        assertTrue(indexedexManager.isVault(address(vault)));
        address[] memory tokens = vault.vaultTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], address(token0));
        assertEq(tokens[1], address(token1));
        assertEq(IERC20Metadata(address(vault)).symbol(), "UV3X");
        IStandardVault.VaultConfig memory config = IStandardVault(address(vault)).vaultConfig();
        assertEq(config.tokens.length, 2);
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeIn).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeOut).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeBundleIn).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeBundleOut).interfaceId));
        assertFalse(IERC165(address(vault)).supportsInterface(type(FeeIdentity).interfaceId));
    }

    function test_deployVault_revertsWhenPoolFactoryMismatch() public {
        UniswapV3Factory other = new UniswapV3Factory();
        IUniswapV3Pool foreign = IUniswapV3Pool(other.createPool(address(token0), address(token1), FEE_MEDIUM));
        foreign.initialize(uint160(1 << 96));
        vm.expectRevert(abi.encodeWithSelector(IUniswapV3FullSpreadStandardExchangeVaultDFPkg.InvalidPoolFactory.selector,
            address(other), address(uniswapV3Factory)));
        uniswapV3StandardExchangeDFPkg.deployVault(foreign);
    }

    function test_componentSalts_areAbiEncodedNamesOnFactoryPath() public {
        address inDelegate = Components.deployUniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("create3(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultInFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInFacet");
            code = bytes.concat(code, abi.encode(inDelegate));
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultInFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.v4Accounting.v2"));
            bytes memory code = ArtifactCreationCode.creationCode(create3Factory, "UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultInQueryFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultOutFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.sol:UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultPositionImportFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultReserveFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultReserveFacet.sol:UniswapV3FullSpreadStandardExchangeVaultReserveFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultReserveFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultBundleFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultBundleFacet.sol:UniswapV3FullSpreadStandardExchangeVaultBundleFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultBundleFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet.sol:UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet.v4Accounting.v1"));
            bytes memory code = ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet.sol:UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", code, salt));
            Components.deployUniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet(create3Factory);
        }
        assertEq(Components.deployUniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate(create3Factory),
            address(uniswapV3StandardExchangeOutFacet), "constructorless exact-out facet is the compatibility target");
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

        bytes32 salt = keccak256(abi.encode("UniswapV3FullSpreadStandardExchangeVaultDFPkg.v4Accounting.v2"));
        vm.expectCall(address(indexedexManager), abi.encodeWithSignature("deployPkg(bytes,bytes,bytes32)",
            ArtifactCreationCode.creationCode("UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV3FullSpreadStandardExchangeVaultDFPkg"),
            abi.encode(pkgInit), salt));
        vm.prank(owner);
        IUniswapV3FullSpreadStandardExchangeVaultDFPkg deployed = Components.deployUniswapV3FullSpreadStandardExchangeVaultDFPkg(indexedexManager, pkgInit);
        assertEq(address(deployed), address(uniswapV3StandardExchangeDFPkg), "identical registry init resolves same new package");
    }
}
