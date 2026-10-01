// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol";

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {UniswapV4FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {
    TestBase_UniswapV4FullSpreadStandardExchangeVault
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV4FullSpreadStandardExchangeVaultDFPkg_Deploy_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;

    function setUp() public override {
        super.setUp();

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 1 ether);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 1 ether);
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces, address[] memory facets) =
            UniswapV4FullSpreadStandardExchangeVaultDFPkg(address(uniswapV4StandardExchangeDFPkg)).packageMetadata();

        assertEq(name_, type(UniswapV4FullSpreadStandardExchangeVaultDFPkg).name, "package name");
        assertEq(interfaces.length, 15, "interface count");
        assertEq(facets.length, 15, "facet count");

        assertEq(facets[0], address(erc20Facet), "erc20 facet");
        assertEq(facets[1], address(erc5267Facet), "erc5267 facet");
        assertEq(facets[2], address(erc2612Facet), "erc2612 facet");
        assertEq(facets[3], address(multiAssetBasicVaultFacet), "basic vault facet");
        assertEq(facets[4], address(multiAssetStandardVaultFacet), "standard vault facet");
        assertEq(facets[5], address(uniswapV4StandardExchangeInFacet), "exchange in facet");
        assertEq(facets[6], address(uniswapV4StandardExchangeInQueryFacet), "exchange in query facet");
        assertEq(facets[7], address(uniswapV4StandardExchangePositionImportFacet), "position import facet");
        assertEq(facets[8], address(uniswapV4StandardExchangeOutFacet), "exchange out facet");
        assertEq(facets[9], address(uniswapV4StandardExchangeOutQueryFacet), "exchange out query facet");
        assertEq(facets[10], address(uniswapV4StandardExchangeLiquidReserveFacet), "liquid reserve facet");
        assertEq(facets[11], address(uniswapV4StandardExchangeInMultiFacet), "exchange in multi facet");
        assertEq(facets[12], address(uniswapV4StandardExchangeInMultiQueryFacet), "exchange in multi query facet");
        assertEq(facets[13], address(uniswapV4StandardExchangeOutMultiFacet), "exchange out multi facet");
        assertEq(facets[14], address(uniswapV4StandardExchangeOutMultiQueryFacet), "exchange out multi query facet");
    }

    function test_deployVault_registersVaultAndInitializesConfig() public {
        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));

        address vault = uniswapV4StandardExchangeDFPkg.deployVault(poolKey);

        assertTrue(vault != address(0), "vault deployed");
        assertTrue(indexedexManager.isVault(vault), "vault registered");

        address[] memory vaultsOfPkg = indexedexManager.vaultsOfPackage(address(uniswapV4StandardExchangeDFPkg));
        assertEq(vaultsOfPkg.length, 1, "package vault count");
        assertEq(vaultsOfPkg[0], vault, "package vault address");

        address[] memory expectedTokens = new address[](2);
        expectedTokens[0] = Currency.unwrap(poolKey.currency0);
        expectedTokens[1] = Currency.unwrap(poolKey.currency1);

        address[] memory vaultTokens = IBasicVault(vault).vaultTokens();
        assertEq(vaultTokens.length, 2, "vault token count");
        assertEq(vaultTokens[0], expectedTokens[0], "vault token0");
        assertEq(vaultTokens[1], expectedTokens[1], "vault token1");

        IStandardVault.VaultConfig memory config = IStandardVault(vault).vaultConfig();
        assertEq(config.tokens.length, 2, "config token count");
        assertEq(config.tokens[0], expectedTokens[0], "config token0");
        assertEq(config.tokens[1], expectedTokens[1], "config token1");
        assertEq(config.vaultTypes.length, 15, "vault types count");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeIn).interfaceId), "erc165 in");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeOut).interfaceId), "erc165 out");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeInMulti).interfaceId), "erc165 in multi");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeOutMulti).interfaceId), "erc165 out multi");
        assertEq(config.contentsId, indexedexManager.calcContentsId(expectedTokens), "contents id");

        assertEq(IERC20Metadata(vault).symbol(), "UV4X", "symbol");

        address[] memory token0Vaults = indexedexManager.vaultsOfToken(expectedTokens[0]);
        address[] memory token1Vaults = indexedexManager.vaultsOfToken(expectedTokens[1]);
        assertEq(token0Vaults.length, 1, "token0 registry count");
        assertEq(token1Vaults.length, 1, "token1 registry count");
        assertEq(token0Vaults[0], vault, "token0 registered vault");
        assertEq(token1Vaults[0], vault, "token1 registered vault");
    }

    /// @notice Native ETH PoolKey maps to a WETH vault face so DETF / registry stay ERC-20.
    function test_deployVault_nativeEthCurrency0_registersVault() public {
        PoolKey memory poolKey = _buildPoolKey(address(0), address(tokenA));

        address vault = uniswapV4StandardExchangeDFPkg.deployVault(poolKey);

        assertTrue(vault != address(0), "vault deployed");
        assertTrue(indexedexManager.isVault(vault), "vault registered");

        address[] memory vaultTokens = IBasicVault(vault).vaultTokens();
        assertEq(vaultTokens.length, 2, "vault token count");
        assertEq(vaultTokens[0], address(weth), "WETH face for native ETH");
        assertEq(vaultTokens[1], address(tokenA), "pairToken");

        address[] memory wethVaults = indexedexManager.vaultsOfToken(address(weth));
        address[] memory pairVaults = indexedexManager.vaultsOfToken(address(tokenA));
        assertEq(wethVaults.length, 1, "WETH registry count");
        assertEq(wethVaults[0], vault, "WETH registered vault");
        assertEq(pairVaults.length, 1, "pairToken registry count");
        assertEq(pairVaults[0], vault, "pairToken registered vault");
        assertEq(IERC20Metadata(vault).symbol(), "UV4X", "symbol");
        assertEq(IERC20Metadata(vault).name(), "UniV4 Vault of (WETH / TKNA)", "name");
    }

    function _buildPoolKey(address token0Candidate, address token1Candidate)
        internal
        pure
        returns (PoolKey memory poolKey)
    {
        (address token0, address token1) = token0Candidate < token1Candidate
            ? (token0Candidate, token1Candidate)
            : (token1Candidate, token0Candidate);

        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function test_componentSalts_areAbiEncodedNamesOnFactoryPath() public {
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("create3(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol:UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        }
        address inDelegate = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate(create3Factory);
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("create3(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate(create3Factory);
        }
        address outDelegate = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate(create3Factory);
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultInFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultInFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", bytes.concat(ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInFacet"), abi.encode(inDelegate)), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultInFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultInQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultInQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInQueryFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultInQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultOutFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", bytes.concat(ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutFacet"), abi.encode(outDelegate)), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultOutFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultOutQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet.sol:UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultPositionImportFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet.sol:UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultInMultiFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultInMultiFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInMultiFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInMultiFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultInMultiFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultOutMultiFacet(create3Factory);
        }
        {
            bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet"));
            assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet")), "raw-name hash is not the salt");
            vm.expectCall(address(create3Factory), abi.encodeWithSignature("deployFacet(bytes,bytes32)", ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet.sol:UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet"), salt));
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet(create3Factory);
        }
    }

    function test_packageSalt_isAbiEncodedNameOnRegistryPath() public {
        IUniswapV4FullSpreadStandardExchangeVaultDFPkg.PkgInit memory pkgInit =
            UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.buildArgsUniswapV4FullSpreadStandardExchangeVaultPkgInit(_univ4SePkgInitCore());
        pkgInit = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.attachTwapOracle(pkgInit, twapOracle);
        pkgInit = UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.attachUniswapV4FullSpreadStandardExchangeVaultMultiFacets(
            pkgInit,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
        bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadStandardExchangeVaultDFPkg"));
        assertTrue(salt != keccak256(bytes("UniswapV4FullSpreadStandardExchangeVaultDFPkg")));
        vm.expectCall(address(indexedexManager), abi.encodeWithSignature("deployPkg(bytes,bytes,bytes32)",
            ArtifactCreationCode.creationCode("UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadStandardExchangeVaultDFPkg"), abi.encode(pkgInit), salt));
        vm.prank(owner);
        UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(indexedexManager, pkgInit);
    }
}
