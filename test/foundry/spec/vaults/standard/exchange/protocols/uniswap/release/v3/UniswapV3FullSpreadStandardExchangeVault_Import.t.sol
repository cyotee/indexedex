// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseNftFixture} from "./harness/FullSpreadReleaseNftFixture.sol";
import {UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller as LockedCaller} from "./harness/UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager as Npm} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as Family} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as Importer, UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget as ImportTarget} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";

/// @notice V3-OWN-01 and V3-ACC-02/03/07/10/11: source proceeds are a proportional deposit.
contract UniswapV3FullSpreadStandardExchangeVault_Import_Test is FullSpreadReleaseNftFixture {
    function testFuzz_importedPositionCannotBecomeUnfundedCredit(bool side) public {
        uint256 id = _nft(1000 ether);
        _approveNft(id);
        _importAs(id, ImportActors(alice, alice, alice));
        _externalSwapExactIn(pool, side, 30_000 ether);
        IERC20 input = side ? token0 : token1;
        uint256 supply = vault.totalSupply();
        vm.prank(bob);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(input, 1 ether, IERC20(address(vault)), 1, bob, true, block.timestamp);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input, uint256(1 ether), IERC20(address(vault)), uint256(1), bob, true, block.timestamp));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        wallet.execute(address(vault), data);
        assertEq(vault.totalSupply(), supply);
        assertEq(vault.balanceOf(bob), 0);
        _fund(input, address(this), 1 ether);
        input.approve(address(wallet), 1 ether);
        (uint256 quote,) = vault.previewExchangeIn(input, 1 ether, IERC20(address(vault)));
        (uint256 minted,) = abi.decode(wallet.consumePretransfer(input, address(this), address(vault), 1 ether, data), (uint256, uint256));
        assertGt(minted, 0);
        assertEq(minted, quote);
        assertEq(vault.balanceOf(bob), minted);
    }
    function test_import_happyPath_principalOnly_burnsEmptyNft() public {
        uint256 id = _nft(50 ether);
        _approveNft(id);
        uint256 shares = _importAs(id, ImportActors(alice, alice, alice));
        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalSupply(), shares + 1000);
        assertEq(vault.totalSupply(), uint256(_liquidity()));
        (uint256 more,) = _mintOne(token0, 10 ether, alice);
        assertGt(more, 0);
    }
    function test_import_withFees_creditsSourcePrincipalAndFees() public {
        uint256 id = _nft(80 ether);
        _externalSwapExactIn(pool, true, 30_000 ether);
        _externalSwapExactIn(pool, false, 30_000 ether);
        (uint256 a0, uint256 a1) = _sourceAmounts(id);
        (,,,,,int24 lower,int24 upper,uint128 liquidity,,,,) = npm.positions(id);
        (uint160 price,,,,,,) = pool.slot0();
        (uint256 p0, uint256 p1) = LiquidityAmounts.getAmountsForLiquidity(price,
            TickMath.getSqrtRatioAtTick(lower), TickMath.getSqrtRatioAtTick(upper), liquidity);
        assertGt((a0 - p0) + (a1 - p1), 0, "source NFT earned fees");
        _approveNft(id);
        _importAs(id, ImportActors(alice, alice, alice));
        assertEq(token0.balanceOf(address(vault)), 0, "source fees are deposit input, not shared booked fees");
        assertEq(token1.balanceOf(address(vault)), 0);
    }
    function test_import_approvedVaultDoesNotAuthorizeAnUnrelatedCaller() public {
        uint256 id = _nft(20 ether);
        _approveNft(id);
        bytes32 beforeState = _nftState(id);
        vm.prank(bob);
        vm.expectRevert(ImportTarget.UniswapV3ExchangeImport_UnauthorizedOwner.selector);
        Importer(address(vault)).importPosition(npm, id, 0, alice, bob, block.timestamp);
        assertEq(_nftState(id), beforeState);
    }
    function test_import_oneSidedPosition_failsGenesisWithoutLosingNft() public {
        (uint256 id,) = _mintNft(NftDeposit(alice, 300, 600, 20 ether, 0, FEE_MEDIUM));
        _approveNft(id);
        (uint256 quote,,) = Importer(address(vault)).previewImportPosition(npm, id);
        assertEq(quote, 0);
        bytes32 beforeState = _nftState(id);
        vm.prank(alice);
        vm.expectRevert(Family.MinLiquidityNotMet.selector);
        Importer(address(vault)).importPosition(npm, id, 0, alice, alice, block.timestamp);
        assertEq(_nftState(id), beforeState);
    }
    function test_import_secondImport_succeedsWithoutResettingSupply() public {
        uint256 first = _nft(20 ether);
        _approveNft(first);
        uint256 firstShares = _importAs(first, ImportActors(alice, alice, alice));
        uint256 second = _nft(30 ether);
        _approveNft(second);
        uint256 supply = vault.totalSupply();
        uint256 secondShares = _importAs(second, ImportActors(alice, alice, bob));
        assertGt(secondShares, 0);
        assertEq(vault.totalSupply(), supply + secondShares);
        assertEq(vault.balanceOf(alice), firstShares);
        assertEq(vault.balanceOf(bob), secondShares);
        assertEq(vault.balanceOf(address(0)), 1000);
    }
    function test_import_wrongPool_reverts() public {
        IUniswapV3Pool other = _createPoolOneToOne(address(token0), address(token1), 500);
        _seedExternalLiquidity(other, 50_000_000e18);
        (uint256 id,) = _mintNft(NftDeposit(alice, -100, 100, 20 ether, 20 ether, 500));
        _approveNft(id);
        vm.prank(alice);
        vm.expectRevert(ImportTarget.UniswapV3ExchangeImport_InvalidImportedPool.selector);
        Importer(address(vault)).importPosition(npm, id, 0, alice, alice, block.timestamp);
        assertEq(IERC721(address(npm)).ownerOf(id), alice);
        assertEq(vault.totalSupply(), 0);
    }
    function test_import_withoutApproval_reverts() public {
        uint256 id = _nft(20 ether);
        bytes32 beforeState = _nftState(id);
        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("NotOwnerNorApproved()")));
        Importer(address(vault)).importPosition(npm, id, 0, alice, alice, block.timestamp);
        assertEq(_nftState(id), beforeState);
    }
    function test_import_zeroLiquidityWithoutOwed_failsGenesis() public {
        uint256 id = _nft(20 ether);
        _decreaseAll(id);
        vm.prank(alice);
        npm.collect(Npm.CollectParams(id, alice, type(uint128).max, type(uint128).max));
        _approveNft(id);
        bytes32 beforeState = _nftState(id);
        vm.prank(alice);
        vm.expectRevert(Family.MinLiquidityNotMet.selector);
        Importer(address(vault)).importPosition(npm, id, 0, alice, alice, block.timestamp);
        assertEq(_nftState(id), beforeState, "failure follows collection, not a zero-liquidity guard");
    }
    function test_import_burnedNft_originalOwnerCannotCollect() public {
        uint256 id = _nft(50 ether);
        _approveNft(id);
        _importAs(id, ImportActors(alice, alice, alice));
        bytes32 beforeState = _state(alice);
        vm.prank(alice);
        vm.expectRevert(bytes("Not approved"));
        npm.collect(Npm.CollectParams(id, alice, type(uint128).max, type(uint128).max));
        assertEq(_state(alice), beforeState);
    }
    function test_A0_importBelowFloor_previewZero_andCompleteExecutionRollback() public {
        uint256 id = _nft(1000);
        _approveNft(id);
        (uint256 quote,,) = Importer(address(vault)).previewImportPosition(npm, id);
        assertEq(quote, 0);
        bytes32 beforeState = _nftState(id);
        vm.prank(alice);
        vm.expectRevert(Family.MinLiquidityNotMet.selector);
        Importer(address(vault)).importPosition(npm, id, 0, alice, alice, block.timestamp);
        assertEq(_nftState(id), beforeState, "NFT owner/approval/source position, custody, pool and supply roll back");
    }
    function test_import_laterOwedOnlyNft_collectsAndBurns() public {
        uint256 incumbent = _join(100 ether, 100 ether);
        uint256 id = _nft(20 ether);
        _decreaseAll(id);
        (,,,,,,,uint128 liquidity,,,uint128 owed0,uint128 owed1) = npm.positions(id);
        assertEq(liquidity, 0);
        assertGt(uint256(owed0) + owed1, 0);
        _approveNft(id);
        uint256 supply = vault.totalSupply();
        uint256 issued = _importAs(id, ImportActors(alice, alice, alice));
        assertGt(issued, 0);
        assertEq(vault.totalSupply(), supply + issued);
        assertEq(vault.balanceOf(address(this)), incumbent);
    }
    function test_import_owedOnlyNft_canSupplyGenesis() public {
        uint256 id = _nft(20 ether);
        _decreaseAll(id);
        _approveNft(id);
        uint256 issued = _importAs(id, ImportActors(alice, alice, alice));
        assertEq(vault.totalSupply(), issued + 1000);
    }
    function test_import_destinationFeesStayBookedOutsideIncomingAssets() public {
        _join(100 ether, 100 ether);
        _externalSwapExactIn(pool, true, 30_000 ether);
        _externalSwapExactIn(pool, false, 30_000 ether);
        (uint256 destination0, uint256 destination1) = _fees();
        assertGt(destination0 + destination1, 0);
        uint256 id = _nft(20 ether);
        _approveNft(id);
        _importAs(id, ImportActors(alice, alice, alice));
        assertEq(token0.balanceOf(address(vault)), destination0);
        assertEq(token1.balanceOf(address(vault)), destination1);
        _assertReserves();
    }
    function testFuzz_import_refundsGoToRecipient_whenOwnerAndCallerDiffer(bool reverse) public {
        (uint256 id,) = _mintNft(NftDeposit(alice, reverse ? int24(-1200) : int24(-600),
            reverse ? int24(600) : int24(1200), 40 ether, 40 ether, FEE_MEDIUM));
        _approveNft(id);
        vm.prank(alice);
        IERC721(address(npm)).setApprovalForAll(bob, true);
        address recipient = makeAddr("distinct import recipient");
        (, uint256 refund0, uint256 refund1) = Importer(address(vault)).previewImportPosition(npm, id);
        assertGt(refund0 + refund1, 0);
        uint256 issued = _importAs(id, ImportActors(alice, bob, recipient));
        assertEq(vault.balanceOf(recipient), issued);
        assertEq(token0.balanceOf(alice) + token1.balanceOf(alice), 0);
        assertEq(token0.balanceOf(bob) + token1.balanceOf(bob), 0);
    }
    function test_import_unmetMinimum_rollsBackNftBurnAndCollection() public {
        _join(100 ether, 100 ether);
        uint256 id = _nft(20 ether);
        _approveNft(id);
        (uint256 quote,,) = Importer(address(vault)).previewImportPosition(npm, id);
        bytes32 beforeState = _nftState(id);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quote + 1, quote));
        Importer(address(vault)).importPosition(npm, id, quote + 1, alice, alice, block.timestamp);
        assertEq(_nftState(id), beforeState);
    }
    function test_import_deadlinePrecedesDisable() public {
        uint256 id = _nft(20 ether);
        _approveNft(id);
        _disable(true);
        vm.warp(1000);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 1, 1000));
        Importer(address(vault)).importPosition(npm, id, 0, alice, alice, 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault)));
        Importer(address(vault)).importPosition(npm, id, 0, alice, alice, block.timestamp);
    }
    function test_import_lockedExecutionReverts_previewRemainsAvailable() public {
        uint256 id = _nft(20 ether);
        _approveNft(id);
        LockedCaller locked = new LockedCaller(pool);
        _fund(token0, address(locked), 1 ether);
        vm.prank(alice);
        IERC721(address(npm)).setApprovalForAll(address(locked), true);
        bytes memory result = locked.run(address(vault), abi.encodeCall(Importer.previewImportPosition, (npm, id)));
        assertEq(result.length, 96);
        (uint256 quote,,) = abi.decode(result, (uint256, uint256, uint256));
        assertGt(quote, 0);
        bytes32 beforeState = _nftState(id);
        vm.expectRevert(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        locked.run(address(vault), abi.encodeCall(Importer.importPosition,
            (npm, id, uint256(0), alice, alice, block.timestamp)));
        assertEq(_nftState(id), beforeState);
    }
    function test_import_laterOneSidedPositionRefundsWithoutMinting() public {
        _join(100 ether, 100 ether);
        (uint256 id,) = _mintNft(NftDeposit(alice, 300, 600, 20 ether, 0, FEE_MEDIUM));
        _approveNft(id);
        (uint256 source0, uint256 source1) = _sourceAmounts(id);
        assertGt(source0, 0);
        assertEq(source1, 0);
        (uint256 quote, uint256 refund0, uint256 refund1) = Importer(address(vault)).previewImportPosition(npm, id);
        assertEq(quote, 0);
        assertEq(refund0, source0);
        assertEq(refund1, 0);
        bytes32 beforeState = _nftState(id);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        Importer(address(vault)).importPosition(npm, id, 1, alice, bob, block.timestamp);
        assertEq(_nftState(id), beforeState);
        uint256 supply = vault.totalSupply();
        uint128 liquidity = _liquidity();
        uint256 before0 = token0.balanceOf(bob);
        vm.prank(alice);
        uint256 issued = Importer(address(vault)).importPosition(npm, id, 0, alice, bob, block.timestamp);
        assertEq(issued, 0);
        assertEq(token0.balanceOf(bob) - before0, source0);
        assertEq(vault.totalSupply(), supply);
        assertEq(_liquidity(), liquidity);
        _assertBurned(id);
    }

    function test_import_laterEmptyNftIsCollectedAndBurned() public {
        _join(100 ether, 100 ether);
        uint256 id = _nft(20 ether);
        _decreaseAll(id);
        vm.prank(alice);
        npm.collect(Npm.CollectParams(id, alice, type(uint128).max, type(uint128).max));
        _approveNft(id);
        uint256 supply = vault.totalSupply();
        uint128 liquidity = _liquidity();
        (uint256 quote, uint256 refund0, uint256 refund1) = Importer(address(vault)).previewImportPosition(npm, id);
        assertEq(quote + refund0 + refund1, 0);
        vm.prank(alice);
        assertEq(Importer(address(vault)).importPosition(npm, id, 0, alice, bob, block.timestamp), 0);
        assertEq(vault.totalSupply(), supply);
        assertEq(_liquidity(), liquidity);
        _assertBurned(id);
    }

    function test_importPreviewIncludesCapacityReleasedBySourceNft() public {
        (int24 lower, int24 upper) = _ticks();
        uint256 amount = uint256(pool.maxLiquidityPerTick()) * 3 / 5;
        (uint256 id,) = _mintNft(NftDeposit(alice, lower, upper, amount, amount, FEE_MEDIUM));
        _approveNft(id);
        (uint128 occupied,,,,,,,) = pool.ticks(lower);
        uint256 capacityBeforeBurn = pool.maxLiquidityPerTick() - occupied;
        (uint256 quote,,) = Importer(address(vault)).previewImportPosition(npm, id);
        assertGt(quote, capacityBeforeBurn, "preview reuses capacity released by the source NFT");
        uint256 issued = _importAs(id, ImportActors(alice, alice, bob));
        assertEq(issued, quote);
        assertEq(vault.balanceOf(bob), quote);
    }

    function _nft(uint256 amount) private returns (uint256 id) {
        (id,) = _mintNft(NftDeposit(alice, -600, 600, amount, amount, FEE_MEDIUM));
    }
}
