// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Residual inventory policy: multi-hop routes leave no intermediate tokens on the vault
///         (dust is swept to feeTo, never stranded on the proxy).
contract DualLiquidityLinkedCrossVersionUniswapVault_Residual is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal actor = makeAddr("residualActor");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
        _assertNoIntermediateInventory();
    }

    function test_residual_afterCommonDeposit_clean() public {
        address feeTo = _feeTo();
        uint256 feeCommonBefore = commonToken.balanceOf(feeTo);

        _depositCommon(actor, LEG_SEED);
        _assertNoIntermediateInventory();

        // Dust may have been swept to feeTo (optional growth).
        assertGe(commonToken.balanceOf(feeTo) + tokenA.balanceOf(feeTo) + tokenB.balanceOf(feeTo), feeCommonBefore);
    }

    function test_residual_afterLinkedDeposit_clean() public {
        _fund(tokenA, actor, LEG_SEED);
        vm.startPrank(actor);
        tokenA.approve(linkedVault, LEG_SEED);
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, LEG_SEED, shareToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        _assertNoIntermediateInventory();
    }

    function test_residual_afterSwap_clean() public {
        _fund(tokenA, actor, 500e18);
        vm.startPrank(actor);
        tokenA.approve(linkedVault, 500e18);
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, 500e18, tokenB, 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        _assertNoIntermediateInventory();
    }

    function test_residual_afterConvenienceRedeem_cleanOrSwept() public {
        uint256 minted = _depositCommon(actor, LEG_SEED);
        vm.startPrank(actor);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 3, commonToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        // Redeposit may best-effort fail; residual intermediates must still not rest on vault
        // after sweep (failed redeposit leaves tokens on Balancer vault, not on diamond).
        _assertNoIntermediateInventory();
    }

    function test_residual_afterBptRedeem_clean() public {
        uint256 minted = _depositCommon(actor, LEG_SEED);
        address pool = _reservePool();
        vm.startPrank(actor);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 2, IERC20(pool), 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        _assertNoIntermediateInventory();
    }
}
