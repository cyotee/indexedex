// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

contract UniswapV4StandardExchangeDFPkg_Deploy_Test is TestBase_UniswapV4StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;

    function setUp() public override {
        super.setUp();

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 1 ether);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 1 ether);
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces, address[] memory facets) =
            UniswapV4StandardExchangeDFPkg(address(uniswapV4StandardExchangeDFPkg)).packageMetadata();

        assertEq(name_, type(UniswapV4StandardExchangeDFPkg).name, "package name");
        assertEq(interfaces.length, 10, "interface count");
        assertEq(facets.length, 10, "facet count");

        assertEq(facets[0], address(erc20Facet), "erc20 facet");
        assertEq(facets[1], address(erc5267Facet), "erc5267 facet");
        assertEq(facets[2], address(erc2612Facet), "erc2612 facet");
        assertEq(facets[3], address(multiAssetBasicVaultFacet), "basic vault facet");
        assertEq(facets[4], address(multiAssetStandardVaultFacet), "standard vault facet");
        assertEq(facets[5], address(uniswapV4StandardExchangeInFacet), "exchange in facet");
        assertEq(facets[6], address(uniswapV4StandardExchangeInQueryFacet), "exchange in query facet");
        assertEq(facets[7], address(uniswapV4StandardExchangePositionImportFacet), "position import facet");
        assertEq(facets[8], address(uniswapV4StandardExchangeOutFacet), "exchange out facet");
        assertEq(facets[9], address(uniswapV4StandardExchangeLiquidReserveFacet), "liquid reserve facet");
    }

    function test_deployVault_registersVaultAndInitializesConfig() public {
        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));

        address vault = uniswapV4StandardExchangeDFPkg.deployVault(poolKey, 60);

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
        assertEq(config.vaultTypes.length, 10, "vault types count");
        assertEq(config.contentsId, indexedexManager.calcContentsId(expectedTokens), "contents id");

        assertEq(IERC20Metadata(vault).symbol(), "UV4X", "symbol");

        address[] memory token0Vaults = indexedexManager.vaultsOfToken(expectedTokens[0]);
        address[] memory token1Vaults = indexedexManager.vaultsOfToken(expectedTokens[1]);
        assertEq(token0Vaults.length, 1, "token0 registry count");
        assertEq(token1Vaults.length, 1, "token1 registry count");
        assertEq(token0Vaults[0], vault, "token0 registered vault");
        assertEq(token1Vaults[0], vault, "token1 registered vault");
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
}
