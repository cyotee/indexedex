// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Token<->token swap aggregation through leg vaults (no share mint/burn, no vault-level fee).
contract DualLiquidityLinkedCrossVersionUniswapVault_Swaps is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal trader = makeAddr("trader");
    uint256 internal constant SWAP_AMOUNT = 100e18;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
    }

    function test_swap_commonToTokenA_previewMatchesExecution() public {
        _fund(commonToken, trader, SWAP_AMOUNT);
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, SWAP_AMOUNT, tokenA);

        vm.startPrank(trader);
        commonToken.approve(linkedVault, SWAP_AMOUNT);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, SWAP_AMOUNT, tokenA, 0, trader, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(out, 0, "common->tokenA yields output");
        assertEq(out, preview, "preview == execution");
        assertEq(tokenA.balanceOf(trader), out, "trader receives output");
        assertEq(IERC20(linkedVault).balanceOf(trader), 0, "swap mints no vault shares");
    }

    function test_swap_tokenAToCommon_previewMatchesExecution() public {
        _fund(tokenA, trader, SWAP_AMOUNT);
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, SWAP_AMOUNT, commonToken);

        vm.startPrank(trader);
        tokenA.approve(linkedVault, SWAP_AMOUNT);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, SWAP_AMOUNT, commonToken, 0, trader, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(out, 0);
        assertEq(out, preview);
    }

    function test_swap_tokenAToTokenB_previewMatchesExecution() public {
        _fund(tokenA, trader, SWAP_AMOUNT);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, SWAP_AMOUNT, tokenB);

        vm.startPrank(trader);
        tokenA.approve(linkedVault, SWAP_AMOUNT);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, SWAP_AMOUNT, tokenB, 0, trader, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(out, 0, "tokenA->tokenB yields output");
        assertEq(out, preview, "preview == execution");
    }

    function test_swap_tokenBToTokenA_previewMatchesExecution() public {
        _fund(tokenB, trader, SWAP_AMOUNT);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenB, SWAP_AMOUNT, tokenA);

        vm.startPrank(trader);
        tokenB.approve(linkedVault, SWAP_AMOUNT);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, SWAP_AMOUNT, tokenA, 0, trader, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(out, 0);
        assertEq(out, preview);
    }

    function test_swap_tokenAToTokenA_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute.selector, tokenA, tokenA
            )
        );
        IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, 1e18, tokenA);
    }
}
