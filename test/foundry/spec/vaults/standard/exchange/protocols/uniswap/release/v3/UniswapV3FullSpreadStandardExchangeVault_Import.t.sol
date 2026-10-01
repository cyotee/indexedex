// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {StandardExchangeConstantProduct as CP} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {TransferredTestInput, IStandardExchangeIn} from "../TransferredTestInput.sol";

import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
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
    IUniswapV3FullSpreadStandardExchangeVaultPositionImport
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {
    TestBase_UniswapV3FullSpreadStandardExchangeVault
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

contract MockTokenDescriptorFullSpread {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

contract UniswapV3FullSpreadStandardExchangeVault_Import_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault {
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

        address descriptor = address(new MockTokenDescriptorFullSpread());
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

    function testFuzz_importedPositionCannotBecomeUnfundedCredit(bool side) public {
        int24 spacing = pool.tickSpacing();
        (uint256 id,) = _mintNpmPosition(address(this), -20 * spacing, 20 * spacing, 1000 ether, 1000 ether);
        IERC721(address(npm)).approve(address(vault), id);
        IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault)).importPosition(
            INonfungiblePositionManager(address(npm)), id, 0, address(this), address(this), block.timestamp);
        _externalSwapExactIn(pool, side, 30000 ether);
        IERC20 input = IERC20(side ? pool.token0() : pool.token1());
        uint256 supply = vault.totalSupply();
        address actor = makeAddr("unfundedImportActor");
        bytes memory callData = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input, 1 ether, IERC20(address(vault)), 0, actor, true, block.timestamp));
        vm.startPrank(actor);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(input, 1 ether, IERC20(address(vault)), 0, actor, true, block.timestamp);
        vm.stopPrank();
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        atomic.execute(address(vault), callData);
        assertEq(vault.totalSupply(), supply); assertEq(vault.balanceOf(actor), 0); assertEq(input.balanceOf(actor), 0);
        ERC20PermitMintableStub(address(input)).mint(actor, 1 ether);
        vm.startPrank(actor);
        input.approve(address(atomic), 1 ether);
        uint256 minted = abi.decode(
            atomic.consumePretransfer(
                input,
                actor,
                address(vault),
                1 ether,
                abi.encodeCall(
                    IStandardExchangeIn.exchangeIn,
                    (input, uint256(1 ether), IERC20(address(vault)), uint256(0), address(atomic), true, block.timestamp)
                )
            ),
            (uint256)
        );
        vm.stopPrank();
        assertGt(minted, 0);
    }

    function test_import_happyPath_principalOnly_leavesEmptyNft() public {
        int24 spacing = pool.tickSpacing();
        int24 lower = -spacing * 10;
        int24 upper = spacing * 10;
        (uint256 tokenId, uint128 liq) = _mintNpmPosition(alice, lower, upper, 50 ether, 50 ether);
        assertGt(liq, 0);

        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer =
            IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));

        uint256 preview = importer.previewImportPosition(INonfungiblePositionManager(address(npm)), tokenId);
        assertEq(preview, _collectedRaw(tokenId) - 1e15, "independent collected-assets floor");

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
        _assertEmptyImportedPosition(tokenId, shares, lower, upper);
        // Post-import single-token deposit works.
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(alice, 10 ether);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), 10 ether);
        uint256 more =
            vault.exchangeIn(IERC20(token0), 10 ether, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(more, 0);
    }

    function _assertEmptyImportedPosition(uint256 tokenId, uint256 shares, int24 lower, int24 upper) internal view {
        // Empty NFT retained by vault.
        assertEq(IERC721(address(npm)).ownerOf(tokenId), address(vault));
        (,,,,,,, uint128 remainingLiq,,,uint128 owed0,uint128 owed1) = npm.positions(tokenId);
        assertEq(owed0, 0); assertEq(owed1, 0);
        assertEq(IERC721(address(npm)).getApproved(tokenId), address(0));
        assertEq(vault.totalSupply(), shares + 1e15);
        assertEq(vault.balanceOf(address(0xdEaD)), 1e15);
        assertEq(remainingLiq, 0, "nft empty");

        (uint128 fullLiquidity,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), TickMath.minUsableTick(pool.tickSpacing()), TickMath.maxUsableTick(pool.tickSpacing()))));
        (uint128 narrowLiquidity,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), lower, upper)));
        assertGt(fullLiquidity, 0, "import converted to maximum usable range"); assertEq(narrowLiquidity, 0, "no retained narrow backing");
    }

    function test_import_withFees_compoundsCenter() public {
        int24 spacing = pool.tickSpacing();
        int24 lower = -spacing * 20;
        int24 upper = spacing * 20;
        (uint256 tokenId,) = _mintNpmPosition(alice, lower, upper, 80 ether, 80 ether);

        // Accrue fees on the NFT position via external swaps.
        _externalSwapExactIn(pool, true, 30_000 ether);
        _externalSwapExactIn(pool, false, 30_000 ether);

        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer =
            IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));
        uint256 preview = importer.previewImportPosition(INonfungiblePositionManager(address(npm)), tokenId);
        assertEq(preview, _collectedRaw(tokenId) - 1e15, "independent collected-assets floor");

        vm.startPrank(alice);
        IERC721(address(npm)).approve(address(vault), tokenId);
        uint256 shares = importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(preview, shares, "principal plus all earned fees, counted once");
        assertGt(shares, 0);
    }

    function test_import_approvedVaultDoesNotAuthorizeAnUnrelatedCaller() public {
        int24 spacing = pool.tickSpacing();
        (uint256 tokenId,) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);
        vm.prank(alice); IERC721(address(npm)).approve(address(vault), tokenId);
        vm.expectRevert(UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.UniswapV3ExchangeImport_UnauthorizedOwner.selector);
        IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault)).importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, address(this), block.timestamp + 1
        );
        assertEq(IERC721(address(npm)).ownerOf(tokenId), alice); assertEq(IERC20(address(vault)).totalSupply(), 0);
    }

    function test_import_oneSidedPositionCannotActivateVault() public {
        int24 spacing = pool.tickSpacing();
        (uint256 tokenId,) = _mintNpmPosition(alice, spacing * 5, spacing * 10, 20 ether, 0);
        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer = IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));
        // R2.4: one-sided position quotes 0 shares -> UniswapV3Exchange_ZeroAmount() 0xdcceb6eb
        // (from _quoteImportShares/_exitNftAndSleeve). Design guessed InvalidImportedPool; the
        // real path is ZeroAmount. Bare expectRevert() masked the difference.
        vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_ZeroAmount()"));
        importer.previewImportPosition(INonfungiblePositionManager(address(npm)), tokenId);
        vm.startPrank(alice); IERC721(address(npm)).approve(address(vault), tokenId);
        vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_ZeroAmount()"));
        importer.importPosition(INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1); vm.stopPrank();
        assertEq(IERC721(address(npm)).ownerOf(tokenId), alice); assertEq(IERC20(address(vault)).totalSupply(), 0);
    }

    function test_import_secondImport_reverts() public {
        int24 spacing = pool.tickSpacing();
        (uint256 tokenId1,) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);
        (uint256 tokenId2,) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);

        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer =
            IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));

        vm.startPrank(alice);
        IERC721(address(npm)).approve(address(vault), tokenId1);
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId1, 0, alice, alice, block.timestamp + 1
        );

        IERC721(address(npm)).approve(address(vault), tokenId2);
        // R2.4: vault already active after the first import -> UniswapV3ExchangeImport_Unavailable()
        // 0x40dc1b67 (totalSupply != 0 guard). Bare form masked it.
        vm.expectRevert(abi.encodeWithSignature("UniswapV3ExchangeImport_Unavailable()"));
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

        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer =
            IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));
        vm.startPrank(alice);
        IERC721(address(npm)).approve(address(vault), tokenId);
        // R2.4: NFT from a different fee tier fails _requireMatchingPool ->
        // UniswapV3ExchangeImport_InvalidImportedPool() 0x401fca3e.
        vm.expectRevert(abi.encodeWithSignature("UniswapV3ExchangeImport_InvalidImportedPool()"));
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_import_withoutApproval_reverts() public {
        int24 spacing = pool.tickSpacing();
        (uint256 tokenId,) = _mintNpmPosition(alice, -spacing * 5, spacing * 5, 20 ether, 20 ether);
        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer =
            IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));
        vm.prank(alice);
        // The NPM uses the upstream NotOwnerNorApproved custom error.
        vm.expectRevert(abi.encodeWithSignature("NotOwnerNorApproved()"));
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
        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer =
            IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));
        // R2.4: a fully-decreased position has liquidity == 0 ->
        // UniswapV3ExchangeImport_ZeroLiquidity() 0xb9c5b907.
        vm.expectRevert(abi.encodeWithSignature("UniswapV3ExchangeImport_ZeroLiquidity()"));
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, alice, alice, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_import_emptyNft_originalOwnerCannotCollect() public {
        (uint256 id,) = _mintNpmPosition(alice, -600, 600, 50 ether, 50 ether);
        vm.startPrank(alice); IERC721(address(npm)).approve(address(vault),id);
        IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault)).importPosition(
            INonfungiblePositionManager(address(npm)),id,0,alice,alice,block.timestamp);
        vm.stopPrank();
        (,,,,,,,uint128 liquidity,,,uint128 owed0,uint128 owed1)=npm.positions(id);
        assertEq(liquidity,0); assertEq(owed0,0); assertEq(owed1,0);
        assertEq(IERC721(address(npm)).ownerOf(id),address(vault)); assertEq(IERC721(address(npm)).getApproved(id),address(0));
        uint256 b0=IERC20(pool.token0()).balanceOf(address(vault)); uint256 b1=IERC20(pool.token1()).balanceOf(address(vault));
        vm.prank(alice); vm.expectRevert(bytes("Not approved"));
        npm.collect(INonfungiblePositionManager.CollectParams(id,alice,type(uint128).max,type(uint128).max));
        assertEq(IERC20(pool.token0()).balanceOf(address(vault)),b0); assertEq(IERC20(pool.token1()).balanceOf(address(vault)),b1);
    }
    function _collectedRaw(uint256 id) private returns (uint256 raw) {
        uint256 snap=vm.snapshotState();
        (,,,,,,,uint128 liquidity,,,,)=npm.positions(id);
        vm.startPrank(IERC721(address(npm)).ownerOf(id));
        npm.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams(id,liquidity,0,0,block.timestamp));
        (uint256 a,uint256 b)=npm.collect(INonfungiblePositionManager.CollectParams(id,alice,type(uint128).max,type(uint128).max));
        vm.stopPrank();raw=FixedPointMathLib.mulSqrt(a,b);assertTrue(vm.revertToState(snap));
    }
    function test_A0_importBelowFloor_previewAndExecutionRollback() public {
        (uint256 id,uint128 liquidity)=_mintNpmPosition(alice,-600,600,1000,1000);
        uint256 snap=vm.snapshotState();
        vm.startPrank(alice);
        npm.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams(id,liquidity,0,0,block.timestamp));
        (uint256 a,uint256 b)=npm.collect(INonfungiblePositionManager.CollectParams(id,alice,type(uint128).max,type(uint128).max));
        vm.stopPrank(); assertTrue(vm.revertToState(snap));
        bytes memory expected=abi.encodeWithSelector(CP.InsufficientMinimumLiquidity.selector,FixedPointMathLib.mulSqrt(a,b),1e15);
        IUniswapV3FullSpreadStandardExchangeVaultPositionImport importer=IUniswapV3FullSpreadStandardExchangeVaultPositionImport(address(vault));
        vm.expectRevert(expected); importer.previewImportPosition(INonfungiblePositionManager(address(npm)),id);
        vm.startPrank(alice); IERC721(address(npm)).approve(address(vault),id);
        vm.expectRevert(expected); importer.importPosition(INonfungiblePositionManager(address(npm)),id,0,alice,alice,block.timestamp);vm.stopPrank();
        assertEq(IERC721(address(npm)).ownerOf(id),alice);
        (,,,,,,,uint128 afterLiquidity,,,,)=npm.positions(id); assertEq(afterLiquidity,liquidity);
        assertEq(vault.totalSupply(),0); assertEq(IERC20(pool.token0()).balanceOf(address(vault)),0); assertEq(IERC20(pool.token1()).balanceOf(address(vault)),0);
    }
}
