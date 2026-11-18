// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {INonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "./TestBase_UniswapV3FullSpreadAccounting.sol";

/// @dev Metadata-only dependency; all NFT ownership, liquidity, fees and burns use the real NPM.
contract V3AccountingPositionDescriptor {
    function tokenURI(uint256) external pure returns (string memory) {
        return "data:application/json,{}";
    }
}

abstract contract TestBase_UniswapV3FullSpreadAccountingNFT is TestBase_UniswapV3FullSpreadAccounting {
    NonfungiblePositionManager internal npm;

    function setUp() public virtual override {
        super.setUp();
        npm = new NonfungiblePositionManager(
            address(uniswapV3Factory), address(1), address(new V3AccountingPositionDescriptor())
        );
        token0.approve(address(npm), type(uint256).max);
        token1.approve(address(npm), type(uint256).max);
    }

    function _mintPosition(address holder_, uint256 amount0_, uint256 amount1_, int24 lower_, int24 upper_)
        internal returns (uint256 tokenId_, uint128 liquidity_)
    {
        (tokenId_, liquidity_,,) = npm.mint(INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            fee: pool.fee(),
            tickLower: lower_,
            tickUpper: upper_,
            amount0Desired: amount0_,
            amount1Desired: amount1_,
            amount0Min: 0,
            amount1Min: 0,
            recipient: holder_,
            deadline: block.timestamp
        }));
    }
}
