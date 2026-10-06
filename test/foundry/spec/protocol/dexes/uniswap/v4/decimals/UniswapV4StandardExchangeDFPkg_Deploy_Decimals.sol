// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {UniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";

/**
 * @title UniswapV4StandardExchangeDFPkg_Deploy_Decimals
 * @notice Gold DFPkg deploy money-paths on combo decimals. pairToken = tokenA. vaultShare stays 18.
 */
abstract contract UniswapV4StandardExchangeDFPkg_Deploy_Decimals is UniswapV4SeDecimalsHelpers {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;

    function setUp() public virtual override {
        super.setUp();
        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(address(this), _uA(1));
        tokenB.mint(address(this), _uB(1));
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces, address[] memory facets) =
            UniswapV4StandardExchangeDFPkg(address(uniswapV4StandardExchangeDFPkg)).packageMetadata();

        assertEq(name_, type(UniswapV4StandardExchangeDFPkg).name, "package name");
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
        assertEq(IERC20Metadata(vault).decimals(), 18, "vaultShare stays 18");

        address[] memory token0Vaults = indexedexManager.vaultsOfToken(expectedTokens[0]);
        address[] memory token1Vaults = indexedexManager.vaultsOfToken(expectedTokens[1]);
        assertEq(token0Vaults.length, 1, "token0 registry count");
        assertEq(token1Vaults.length, 1, "token1 registry count");
        assertEq(token0Vaults[0], vault, "token0 registered vault");
        assertEq(token1Vaults[0], vault, "token1 registered vault");
    }

    /// @notice Native ETH PoolKey maps to a WETH vault face. pairToken = tokenA at combo decimals.
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
        assertEq(IERC20Metadata(vault).decimals(), 18, "vaultShare stays 18");
    }
}
