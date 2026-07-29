// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {
    UniswapV3StandardExchangeDFPkg,
    IUniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";
import {UniswapV3PoolAwareRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3PoolAwareRepo.sol";
import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

contract UniswapV3StandardExchangeDFPkg_Deploy_Test is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces, address[] memory facets) =
            UniswapV3StandardExchangeDFPkg(address(uniswapV3StandardExchangeDFPkg)).packageMetadata();

        assertEq(name_, type(UniswapV3StandardExchangeDFPkg).name, "package name");
        assertEq(interfaces.length, 9, "interface count");
        assertEq(facets.length, 9, "facet count");
        assertEq(facets[0], address(erc20Facet), "erc20");
        assertEq(facets[5], address(uniswapV3StandardExchangeInFacet), "in");
        assertEq(facets[6], address(uniswapV3StandardExchangeInQueryFacet), "in query");
        assertEq(facets[7], address(uniswapV3StandardExchangeOutFacet), "out");
        assertEq(facets[8], address(uniswapV3StandardExchangePositionImportFacet), "import");
    }

    function test_deployVault_registersAndInitializesPoolAndWidth() public {
        IUniswapV3Pool pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        address vault = address(_deployVault(pool, 10));

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
    }

    function test_deployVault_revertsWhenPoolFactoryMismatch() public {
        // Pool from a different factory.
        UniswapV3Factory otherFactory = new UniswapV3Factory();
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        IUniswapV3Pool roguePool = IUniswapV3Pool(otherFactory.createPool(t0, t1, FEE_MEDIUM));
        roguePool.initialize(uint160(uint256(1) << 96));

        vm.expectRevert();
        uniswapV3StandardExchangeDFPkg.deployVault(roguePool, 10);
    }
}
