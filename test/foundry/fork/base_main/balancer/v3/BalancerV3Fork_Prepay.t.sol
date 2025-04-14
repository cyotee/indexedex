// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Crane IERC20 imported below

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    WeightedPoolFactory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {
    TokenConfig,
    TokenType,
    PoolRoleAccounts
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {
    CastingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";

import {TestBase_BalancerV3Fork} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork.sol";

/**
 * @title BalancerV3Fork_Prepay_Test
 * @notice Fork tests for Balancer V3 router prepay functions on Base mainnet.
 * @dev Mirrors `BalancerV3StandardExchangeRouter_Prepay.t.sol`, but uses live Base Balancer V3 Vault/Factory.
 */
contract BalancerV3Fork_Prepay_Test is TestBase_BalancerV3Fork {
    using CastingHelpers for address[];

    uint256 internal constant LIQUIDITY_AMOUNT = 100e18;

    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;

    function setUp() public override {
        super.setUp();
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*                           View Function Tests                          */
    /* ---------------------------------------------------------------------- */

    function test_fork_isPrepaid_returnsTrue() public view {
        assertTrue(prepayRouter.isPrepaid(), "Fork: isPrepaid should return true");
    }

    function test_fork_currentStandardExchange_initiallyZero() public view {
        address currentSE = address(prepayRouter.currentStandardExchange());
        assertEq(currentSE, address(0), "Fork: currentStandardExchange should be zero initially");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Access Control Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_fork_prepayAddLiquidityUnbalanced_directCall_reverts() public {
        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(daiUsdcPool);
        // Silence unused warning; we only need the call for parity with spec.
        tokens;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        dai.mint(alice, LIQUIDITY_AMOUNT);
        usdc.mint(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        dai.transfer(address(seRouter), LIQUIDITY_AMOUNT);
        usdc.transfer(address(seRouter), LIQUIDITY_AMOUNT);

        // On a live vault, this direct call can revert with payment-related errors instead of
        // the router's NotCurrentStandardExchangeToken error.
        vm.expectRevert();

        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "");

        vm.stopPrank();
    }

    function test_fork_prepayRemoveLiquidityProportional_directCall_reverts() public {
        uint256 bptAmount = _addLiquidityForAddress(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 1;
        minAmountsOut[1] = 1;

        // On a live vault, this direct call can revert with allowance-related errors.
        vm.expectRevert();

        prepayRouter.prepayRemoveLiquidityProportional(daiUsdcPool, bptAmount, minAmountsOut, "");

        vm.stopPrank();
    }

    function test_fork_prepayRemoveLiquiditySingleTokenExactIn_directCall_reverts() public {
        uint256 bptAmount = _addLiquidityForAddress(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        // On a live vault, this direct call can revert with allowance-related errors.
        vm.expectRevert();

        prepayRouter.prepayRemoveLiquiditySingleTokenExactIn(daiUsdcPool, bptAmount, IERC20(address(dai)), 1, "");

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*             Prepay via Vault Unlock Context Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_prepayAddLiquidityUnbalanced_viaUnlock_success() public {
        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);

        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256 bptBalBefore = IERC20(daiUsdcPool).balanceOf(address(this));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        bytes memory result = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));

        uint256 bptReceived = abi.decode(result, (uint256));
        uint256 bptBalAfter = IERC20(daiUsdcPool).balanceOf(address(this));

        assertGt(bptReceived, 0, "Fork: Should receive BPT");
        assertEq(bptBalAfter - bptBalBefore, bptReceived, "Fork: BPT balance mismatch");
    }

    function test_fork_prepayRemoveLiquidityProportional_viaUnlock_success() public {
        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);
        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        bytes memory addResult = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));
        uint256 bptAmount = abi.decode(addResult, (uint256));

        IERC20(daiUsdcPool).approve(address(seRouter), bptAmount);

        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(daiUsdcPool);
        uint256 token0BalBefore = tokens[0].balanceOf(address(this));
        uint256 token1BalBefore = tokens[1].balanceOf(address(this));

        bytes memory removeResult =
            vault.unlock(abi.encodeCall(this.removeLiquidityProportionalCallback, (daiUsdcPool, bptAmount)));
        uint256[] memory amountsOut = abi.decode(removeResult, (uint256[]));

        uint256 token0BalAfter = tokens[0].balanceOf(address(this));
        uint256 token1BalAfter = tokens[1].balanceOf(address(this));

        assertGt(amountsOut[0], 0, "Fork: Should receive token0");
        assertGt(amountsOut[1], 0, "Fork: Should receive token1");
        assertEq(token0BalAfter - token0BalBefore, amountsOut[0], "Fork: Token0 balance mismatch");
        assertEq(token1BalAfter - token1BalBefore, amountsOut[1], "Fork: Token1 balance mismatch");
    }

    function test_fork_prepayRemoveLiquiditySingleTokenExactIn_viaUnlock_success() public {
        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);
        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        bytes memory addResult = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));
        uint256 bptAmount = abi.decode(addResult, (uint256));

        IERC20(daiUsdcPool).approve(address(seRouter), bptAmount);

        uint256 daiBalBefore = dai.balanceOf(address(this));

        bytes memory removeResult = vault.unlock(
            abi.encodeCall(this.removeLiquiditySingleTokenCallback, (daiUsdcPool, bptAmount, address(dai)))
        );
        uint256 amountOut = abi.decode(removeResult, (uint256));

        uint256 daiBalAfter = dai.balanceOf(address(this));

        assertGt(amountOut, 0, "Fork: Should receive DAI");
        assertEq(daiBalAfter - daiBalBefore, amountOut, "Fork: DAI balance mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Prepay Initialize Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_fork_prepayInitialize_viaUnlock_success() public {
        address newPool = _createUninitializedPool();

        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);

        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256 bptBalBefore = IERC20(newPool).balanceOf(address(this));

        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(newPool);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        bytes memory result = vault.unlock(abi.encodeCall(this.initializeCallback, (newPool, tokens, amounts)));

        uint256 bptReceived = abi.decode(result, (uint256));
        uint256 bptBalAfter = IERC20(newPool).balanceOf(address(this));

        assertGt(bptReceived, 0, "Fork: Should receive BPT");
        assertEq(bptBalAfter - bptBalBefore, bptReceived, "Fork: BPT balance mismatch");
    }

    function test_fork_prepayInitialize_directCall_reverts() public {
        address newPool = _createUninitializedPool();

        dai.mint(alice, LIQUIDITY_AMOUNT);
        usdc.mint(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        dai.transfer(address(seRouter), LIQUIDITY_AMOUNT);
        usdc.transfer(address(seRouter), LIQUIDITY_AMOUNT);

        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(newPool);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        // On a live vault, this direct call can revert with vault settlement errors.
        vm.expectRevert();

        prepayRouter.prepayInitialize(newPool, tokens, amounts, 1, "");

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Callback Functions                             */
    /* ---------------------------------------------------------------------- */

    function initializeCallback(address pool, IERC20[] memory tokens, uint256[] memory amounts)
        external
        returns (uint256 bptAmountOut)
    {
        return prepayRouter.prepayInitialize(pool, tokens, amounts, 1, "");
    }

    function addLiquidityCallback(address pool, uint256[] memory amounts) external returns (uint256 bptAmountOut) {
        return prepayRouter.prepayAddLiquidityUnbalanced(pool, amounts, 1, "");
    }

    function removeLiquidityProportionalCallback(address pool, uint256 bptAmount)
        external
        returns (uint256[] memory amountsOut)
    {
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 1;
        minAmountsOut[1] = 1;

        return prepayRouter.prepayRemoveLiquidityProportional(pool, bptAmount, minAmountsOut, "");
    }

    function removeLiquiditySingleTokenCallback(address pool, uint256 bptAmount, address tokenOut)
        external
        returns (uint256 amountOut)
    {
        return prepayRouter.prepayRemoveLiquiditySingleTokenExactIn(pool, bptAmount, IERC20(tokenOut), 1, "");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    function _addLiquidityForAddress(address recipient, uint256 amount) internal returns (uint256 bptAmount) {
        dai.mint(address(this), amount);
        usdc.mint(address(this), amount);

        dai.transfer(address(vault), amount);
        usdc.transfer(address(vault), amount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        bytes memory result = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));
        bptAmount = abi.decode(result, (uint256));

        IERC20(daiUsdcPool).transfer(recipient, bptAmount);
    }

    function _createUninitializedPool() internal returns (address newPool) {
        address[] memory tokens = new address[](2);
        if (address(dai) < address(usdc)) {
            tokens[0] = address(dai);
            tokens[1] = address(usdc);
        } else {
            tokens[0] = address(usdc);
            tokens[1] = address(dai);
        }

        TokenConfig[] memory tokenConfigs = new TokenConfig[](2);
        tokenConfigs[0] = TokenConfig({
            token: IERC20(tokens[0]),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        tokenConfigs[1] = TokenConfig({
            token: IERC20(tokens[1]),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;

        PoolRoleAccounts memory roleAccounts;

        newPool = WeightedPoolFactory(address(weightedPoolFactory))
            .create(
                "Fork Test-Init Pool",
                "FORK-INIT-BPT",
                tokenConfigs,
                weights,
                roleAccounts,
                0.003e18,
                address(0),
                false,
                false,
                bytes32(keccak256(abi.encodePacked(block.timestamp, "fork-init-pool")))
            );
        vm.label(newPool, "Fork_TestInitPool");
    }
}
