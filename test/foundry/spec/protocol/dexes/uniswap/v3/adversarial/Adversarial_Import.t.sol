// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {
    NonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

contract MockTokenDescriptor2 {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

contract Adversarial_Import_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    NonfungiblePositionManager internal npm;

    function setUp() public override {
        super.setUp();
        npm = new NonfungiblePositionManager(address(uniswapV3Factory), address(1), address(new MockTokenDescriptor2()));
    }

    function _mintNft(address to) internal returns (uint256 tokenId, uint128 liq) {
        address token0 = pool.token0();
        address token1 = pool.token1();
        int24 spacing = pool.tickSpacing();
        ERC20PermitMintableStub(token0).mint(address(this), 30 ether);
        ERC20PermitMintableStub(token1).mint(address(this), 30 ether);
        IERC20(token0).approve(address(npm), 30 ether);
        IERC20(token1).approve(address(npm), 30 ether);
        (tokenId, liq,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE_MEDIUM,
                tickLower: -spacing * 8,
                tickUpper: spacing * 8,
                amount0Desired: 30 ether,
                amount1Desired: 30 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: to,
                deadline: block.timestamp + 1
            })
        );
    }

    function test_D2_importWithoutApproval_reverts() public {
        (uint256 tokenId,) = _mintNft(attacker);
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        vm.prank(attacker);
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, attacker, attacker, block.timestamp + 1
        );
        assertEq(IERC721(address(npm)).ownerOf(tokenId), attacker);
    }

    function test_D4_secondImport_reverts() public {
        (uint256 a,) = _mintNft(attacker);
        (uint256 b,) = _mintNft(attacker);
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        vm.startPrank(attacker);
        IERC721(address(npm)).approve(address(vault), a);
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), a, 0, attacker, attacker, block.timestamp + 1
        );
        IERC721(address(npm)).approve(address(vault), b);
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), b, 0, attacker, attacker, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_H2_zeroLiquidityImport_reverts() public {
        (uint256 tokenId, uint128 liq) = _mintNft(attacker);
        vm.startPrank(attacker);
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
                recipient: attacker,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        IERC721(address(npm)).approve(address(vault), tokenId);
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, attacker, attacker, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_H3_emptyNft_cannotSecondImport() public {
        (uint256 tokenId,) = _mintNft(attacker);
        IUniswapV3StandardExchangePositionImport importer =
            IUniswapV3StandardExchangePositionImport(address(vault));
        vm.startPrank(attacker);
        IERC721(address(npm)).approve(address(vault), tokenId);
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, attacker, attacker, block.timestamp + 1
        );
        // Empty NFT is on vault; re-import same id blocked by live vault.
        vm.expectRevert();
        importer.importPosition(
            INonfungiblePositionManager(address(npm)), tokenId, 0, address(vault), attacker, block.timestamp + 1
        );
        vm.stopPrank();
    }
}
