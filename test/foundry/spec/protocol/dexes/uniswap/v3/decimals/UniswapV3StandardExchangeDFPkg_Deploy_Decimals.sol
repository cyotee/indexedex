// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
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
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";
import {
    TestBase_UniswapV3StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_Decimals.sol";

/// @notice DFPkg deploy with pairToken = tokenA. After sort, vaultTokens follow token0/token1.
abstract contract UniswapV3StandardExchangeDFPkg_Deploy_Decimals is TestBase_UniswapV3StandardExchange_Decimals {
    function setUp() public virtual override {
        super.setUp();
        _deployPairTokens();
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces, address[] memory facets) =
            UniswapV3StandardExchangeDFPkg(address(uniswapV3StandardExchangeDFPkg)).packageMetadata();

        assertEq(name_, type(UniswapV3StandardExchangeDFPkg).name, "package name");
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
        IUniswapV3Pool pool_ = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        address vault_ = address(_deployVault(pool_));

        assertTrue(vault_ != address(0), "vault deployed");
        assertTrue(indexedexManager.isVault(vault_), "registered");

        address[] memory vaultTokens = IBasicVault(vault_).vaultTokens();
        assertEq(vaultTokens.length, 2);
        assertEq(vaultTokens[0], pool_.token0());
        assertEq(vaultTokens[1], pool_.token1());

        assertEq(IERC20Metadata(vault_).symbol(), "UV3X");

        IStandardVault.VaultConfig memory config = IStandardVault(vault_).vaultConfig();
        assertEq(config.tokens.length, 2);
        assertTrue(IERC165(vault_).supportsInterface(type(IStandardExchangeIn).interfaceId), "erc165 in");
        assertTrue(IERC165(vault_).supportsInterface(type(IStandardExchangeOut).interfaceId), "erc165 out");
        assertTrue(IERC165(vault_).supportsInterface(type(IStandardExchangeInMulti).interfaceId), "erc165 in multi");
        assertTrue(IERC165(vault_).supportsInterface(type(IStandardExchangeOutMulti).interfaceId), "erc165 out multi");
        assertTrue(
            IERC165(vault_).supportsInterface(type(IUniswapV3StandardExchangeLiquidReserve).interfaceId),
            "erc165 liquid reserve"
        );
    }

    function test_deployVault_revertsWhenPoolFactoryMismatch() public {
        UniswapV3Factory otherFactory = new UniswapV3Factory();
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        IUniswapV3Pool roguePool = IUniswapV3Pool(otherFactory.createPool(t0, t1, FEE_MEDIUM));
        roguePool.initialize(uint160(uint256(1) << 96));

        vm.expectRevert();
        uniswapV3StandardExchangeDFPkg.deployVault(roguePool);
    }
}
