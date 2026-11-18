// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./FullSpreadReleaseFixture.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {INonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as Importer} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";

/// @notice Metadata-only double; all accounting and NFT lifecycle behavior uses the real NPM.
contract MockTokenDescriptorFullSpread {
    function tokenURI(uint256) external pure returns (string memory) { return ""; }
}

/// @notice Real source-NFT fixture shared by full-range conversion and import regressions.
abstract contract FullSpreadReleaseNftFixture is FullSpreadReleaseFixture {
    NonfungiblePositionManager internal npm;

    struct NftDeposit {
        address recipient;
        int24 lower;
        int24 upper;
        uint256 amount0;
        uint256 amount1;
        uint24 fee;
    }

    struct ImportActors {
        address owner;
        address caller;
        address recipient;
    }

    struct ImportReceipt {
        uint256 shares;
        uint256 refund0;
        uint256 refund1;
        uint256 source0;
        uint256 source1;
        uint256 balance0;
        uint256 balance1;
        uint256 supply;
        uint128 liquidity;
    }

    function setUp() public virtual override {
        super.setUp();
        npm = new NonfungiblePositionManager(
            address(uniswapV3Factory), address(1), address(new MockTokenDescriptorFullSpread())
        );
    }

    function _mintNft(NftDeposit memory deposit) internal returns (uint256 id, uint128 liquidity) {
        _fund(token0, address(this), deposit.amount0);
        _fund(token1, address(this), deposit.amount1);
        token0.approve(address(npm), deposit.amount0);
        token1.approve(address(npm), deposit.amount1);
        (id, liquidity,,) = npm.mint(INonfungiblePositionManager.MintParams({
            token0: address(token0), token1: address(token1), fee: deposit.fee,
            tickLower: deposit.lower, tickUpper: deposit.upper,
            amount0Desired: deposit.amount0, amount1Desired: deposit.amount1,
            amount0Min: 0, amount1Min: 0, recipient: deposit.recipient, deadline: block.timestamp
        }));
    }

    function _sourceAmounts(uint256 id) internal returns (uint256 a0, uint256 a1) {
        uint256 snap = vm.snapshotState();
        (,,,,,,,uint128 liquidity,,,,) = npm.positions(id);
        vm.startPrank(IERC721(address(npm)).ownerOf(id));
        if (liquidity != 0) {
            npm.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams(
                id, liquidity, 0, 0, block.timestamp
            ));
        }
        (a0, a1) = npm.collect(INonfungiblePositionManager.CollectParams(
            id, address(this), type(uint128).max, type(uint128).max
        ));
        vm.stopPrank();
        assertTrue(vm.revertToState(snap));
    }

    function _approveNft(uint256 id) internal {
        vm.prank(IERC721(address(npm)).ownerOf(id));
        IERC721(address(npm)).approve(address(vault), id);
    }

    function _decreaseAll(uint256 id) internal {
        (,,,,,,,uint128 liquidity,,,,) = npm.positions(id);
        vm.prank(IERC721(address(npm)).ownerOf(id));
        npm.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams(
            id, liquidity, 0, 0, block.timestamp
        ));
    }

    function _assertBurned(uint256 id) internal {
        vm.expectRevert(bytes4(keccak256("TokenDoesNotExist()")));
        IERC721(address(npm)).ownerOf(id);
    }

    function _importAs(uint256 id, ImportActors memory actors) internal returns (uint256 issued) {
        ImportReceipt memory receipt;
        (receipt.source0, receipt.source1) = _sourceAmounts(id);
        (bool ok, bytes memory data) = address(vault).staticcall(
            abi.encodeCall(Importer.previewImportPosition, (npm, id))
        );
        assertTrue(ok);
        assertEq(data.length, 96, "preview ABI contains net shares and both refunds");
        (receipt.shares, receipt.refund0, receipt.refund1) = abi.decode(data, (uint256, uint256, uint256));
        receipt.balance0 = token0.balanceOf(actors.recipient);
        receipt.balance1 = token1.balanceOf(actors.recipient);
        receipt.supply = vault.totalSupply();
        receipt.liquidity = _liquidity();
        vm.prank(actors.caller);
        issued = Importer(address(vault)).importPosition(
            npm, id, receipt.shares, actors.owner, actors.recipient, block.timestamp
        );
        assertEq(issued, receipt.shares);
        assertEq(token0.balanceOf(actors.recipient) - receipt.balance0, receipt.refund0);
        assertEq(token1.balanceOf(actors.recipient) - receipt.balance1, receipt.refund1);
        uint128 added = _liquidity() - receipt.liquidity;
        uint256 expected = receipt.supply == 0
            ? uint256(added) - 1000
            : uint256(added) * receipt.supply / receipt.liquidity;
        assertEq(issued, expected, "import uses actual liquidity and the pre-add share basis");
        (uint256 used0, uint256 used1) = _mintCost(added);
        assertEq(receipt.source0, used0 + receipt.refund0, "all source token0 principal and fees accounted");
        assertEq(receipt.source1, used1 + receipt.refund1, "all source token1 principal and fees accounted");
        assertEq(vault.balanceOf(address(0)), 1000);
        _assertBurned(id);
    }

    function _nftState(uint256 id) internal view returns (bytes32) {
        (bool success, bytes memory data) = address(npm).staticcall(
            abi.encodeCall(INonfungiblePositionManager.positions, (id))
        );
        assertTrue(success);
        return keccak256(abi.encode(
            data, IERC721(address(npm)).ownerOf(id), IERC721(address(npm)).getApproved(id),
            IERC721(address(npm)).balanceOf(alice), IERC721(address(npm)).balanceOf(address(vault)),
            token0.balanceOf(address(npm)), token1.balanceOf(address(npm)),
            _state(alice), _state(bob), _state(address(this)), _sourcePoolState(id)
        ));
    }

    function _sourcePoolState(uint256 id) private view returns (bytes32) {
        (,,,,,int24 lower,int24 upper,,,,,) = npm.positions(id);
        bytes32 key = keccak256(abi.encodePacked(address(npm), lower, upper));
        (bool positionOk, bytes memory position) = address(pool).staticcall(abi.encodeWithSignature("positions(bytes32)", key));
        (bool lowerOk, bytes memory lowerTick) = address(pool).staticcall(abi.encodeWithSignature("ticks(int24)", lower));
        (bool upperOk, bytes memory upperTick) = address(pool).staticcall(abi.encodeWithSignature("ticks(int24)", upper));
        assertTrue(positionOk && lowerOk && upperOk);
        return keccak256(abi.encode(position, lowerTick, upperTick, pool.feeGrowthGlobal0X128(), pool.feeGrowthGlobal1X128()));
    }
}
