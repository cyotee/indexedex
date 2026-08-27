// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {
    NonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

contract MockTokenDescriptor {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

contract UniswapV3StandardExchange_Import_Test is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    NonfungiblePositionManager internal npm;
    address internal alice = makeAddr("alice");

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 5_000_000);
        vault = _deployVault(pool);

        address descriptor = address(new MockTokenDescriptor());
        // WETH arg unused for ERC20-only mints in these tests.
        npm = new NonfungiblePositionManager(address(uniswapV3Factory), address(1), descriptor);
    }

    function _mintNpmPosition(address recipient, int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1)
        internal
        returns (uint256 tokenId, uint128 liquidity)
    {
        address token0 = pool.token0();
        address token1 = pool.token1();
        ERC20PermitMintableStub(token0).mint(address(this), amount0);
        ERC20PermitMintableStub(token1).mint(address(this), amount1);
        IERC20(token0).approve(address(npm), amount0);
        IERC20(token1).approve(address(npm), amount1);

        (tokenId, liquidity,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE_MEDIUM,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: recipient,
                deadline: block.timestamp + 1
            })
        );
    }

    function test_import_happyPath_principalOnly_leavesEmptyNft() public {
        int24 spacing = pool.tickSpacing();
        int24 lower = -spacing * 10;
        int24 upper = spacing * 10;
        (uint256 tokenId, uint128 liq) = _mintNpmPosition(alice, lower, upper, 50 ether, 50 ether);
        assertGt(liq, 0);

        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));

        uint256 preview = importer.previewImportPosition(INonfungiblePositionManager(address(npm)), tokenId);

        vm.startPrank(alice);
        IERC721(address(npm)).approve(address(vault), tokenId);
        uint256 shares = importer.importPosition(
            INonfungiblePositionManager(address(npm)),
            tokenId,
            0,
            alice,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(preview, shares, "P-IMP-01");
        assertGt(shares, 0);
        assertEq(IERC20(address(vault)).balanceOf(alice), shares);
        // Empty NFT retained by vault.
        assertEq(IERC721(address(npm)).ownerOf(tokenId), address(vault));
        (,,,,,,, uint128 remainingLiq,,,,) = npm.positions(tokenId);
        assertEq(remainingLiq, 0, "nft empty");

        // Post-import center-only zap works.
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(alice, 10 ether);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), 10 ether);
        uint256 more =
            vault.exchangeIn(IERC20(token0), 10 ether, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(more, 0);
    }

    function test_import_withFees_compoundsCenter() public {
        int24 spacing = pool.tickSpacing();
        int24 lower = -spacing * 20;
        int24 upper = spacing * 20;
        (uint256 tokenId,) = _mintNpmPosition(alice, lower, upper, 80 ether, 80 ether);

        // Accrue fees on the NFT position via external swaps.
        _externalSwapExactIn(pool, true, 30_000 ether);
        _externalSwapExactIn(pool, false, 30_000 ether);

        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        uint256 preview = importer.previewImportPosition(INonfungiblePositionManager(address(npm)), tokenId);

        vm.startPrank(alice);
        IERC721(address(npm)).approve(address(vault), tokenId);
        uint256 shares = importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1
        );
        vm.stopPrank();

        assertApproxEqRel(preview, shares, 0.02e18, "P-IMP-02");
        assertGt(shares, 0);
    }

    function test_import_secondImport_reverts() public {
        int24 spacing = pool.tickSpacing();
        (uint256 tokenId1,) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);
        (uint256 tokenId2,) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);

        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));

        vm.startPrank(alice);
        IERC721(address(npm)).approve(address(vault), tokenId1);
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId1, 0, alice, alice, block.timestamp + 1
        );

        IERC721(address(npm)).approve(address(vault), tokenId2);
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId2, 0, alice, alice, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_import_wrongPool_reverts() public {
        // Different fee pool with same tokens.
        IUniswapV3Pool other = _createPoolOneToOne(address(tokenA), address(tokenB), 500);
        _seedExternalLiquidity(other, 1_000_000);

        // Mint NFT on other fee tier against npm (same factory).
        address token0 = other.token0();
        address token1 = other.token1();
        ERC20PermitMintableStub(token0).mint(address(this), 20 ether);
        ERC20PermitMintableStub(token1).mint(address(this), 20 ether);
        IERC20(token0).approve(address(npm), 20 ether);
        IERC20(token1).approve(address(npm), 20 ether);
        int24 spacing = other.tickSpacing();
        (uint256 tokenId,,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: 500,
                tickLower: -spacing * 10,
                tickUpper: spacing * 10,
                amount0Desired: 20 ether,
                amount1Desired: 20 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp + 1
            })
        );

        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        vm.startPrank(alice);
        IERC721(address(npm)).approve(address(vault), tokenId);
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_import_withoutApproval_reverts() public {
        int24 spacing = pool.tickSpacing();
        (uint256 tokenId,) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        vm.prank(alice);
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1
        );
    }

    function test_import_zeroLiquidity_reverts() public {
        // Create NFT then fully decrease to leave zero liquidity.
        int24 spacing = pool.tickSpacing();
        (uint256 tokenId, uint128 liq) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);
        vm.startPrank(alice);
        npm.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liq,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp + 1
            })
        );
        npm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: alice,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        IERC721(address(npm)).approve(address(vault), tokenId);
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1
        );
        vm.stopPrank();
    }
}
