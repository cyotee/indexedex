// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Crane IERC20 imported below
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {PoolFactoryMock} from "contracts/test/balancer/v3/PoolFactoryMock.sol";
import {
    CastingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_Prepay_Test
 * @notice Tests for the Prepay facet functions.
 * @dev Prepay functions handle liquidity operations where tokens are pre-transferred to the router.
 *      This is used when another contract needs to add/remove liquidity as part of a larger operation.
 *
 *      IMPORTANT: Prepay functions require the Balancer vault to be in an "unlocked" state,
 *      which means they must be called from within a vault.unlock() callback context.
 *      Direct calls from EOAs will revert with NotCurrentStandardExchangeToken.
 */
contract BalancerV3StandardExchangeRouter_Prepay_Test is TestBase_BalancerV3StandardExchangeRouter {
    using CastingHelpers for address[];

    uint256 internal constant LIQUIDITY_AMOUNT = 100e18;

    // Cast router to prepay interface
    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;

    function setUp() public override {
        super.setUp();
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*                           View Function Tests                          */
    /* ---------------------------------------------------------------------- */

    function test_isPrepaid_returnsTrue() public view {
        assertTrue(prepayRouter.isPrepaid(), "isPrepaid should return true");
    }

    function test_currentStandardExchange_initiallyZero() public view {
        // Initially no standard exchange is set
        address currentSE = address(prepayRouter.currentStandardExchange());
        // The current standard exchange should be address(0) when not in a swap context
        assertEq(currentSE, address(0), "currentStandardExchange should be zero initially");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Access Control Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_prepayAddLiquidityUnbalanced_directCall_reverts() public {
        // Get pool tokens in sorted order
        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(daiUsdcPool);

        // Prepare amounts
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        // Mint tokens to alice
        dai.mint(alice, LIQUIDITY_AMOUNT);
        usdc.mint(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        // Pre-transfer tokens to the router
        dai.transfer(address(seRouter), LIQUIDITY_AMOUNT);
        usdc.transfer(address(seRouter), LIQUIDITY_AMOUNT);

        // Direct call should revert because vault is not unlocked
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector, alice, address(0)
            )
        );
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "");

        vm.stopPrank();
    }

    function test_prepayRemoveLiquidityProportional_directCall_reverts() public {
        // Get BPT for alice first by adding liquidity via prepay
        uint256 bptAmount = _addLiquidityForAddress(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 1;
        minAmountsOut[1] = 1;

        // Direct call should revert because vault is not unlocked
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector, alice, address(0)
            )
        );
        prepayRouter.prepayRemoveLiquidityProportional(daiUsdcPool, bptAmount, minAmountsOut, "");

        vm.stopPrank();
    }

    function test_prepayRemoveLiquiditySingleTokenExactIn_directCall_reverts() public {
        // Get BPT for alice first
        uint256 bptAmount = _addLiquidityForAddress(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        // Direct call should revert because vault is not unlocked
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector, alice, address(0)
            )
        );
        prepayRouter.prepayRemoveLiquiditySingleTokenExactIn(daiUsdcPool, bptAmount, IERC20(address(dai)), 1, "");

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*             Prepay via Vault Unlock Context Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_prepayAddLiquidityUnbalanced_viaUnlock_success() public {
        // Mint tokens to test contract (this contract will be the callback target)
        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);

        // Pre-transfer tokens to the VAULT (not the router!)
        // The prepay pattern expects tokens to already be in the vault's balance
        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256 bptBalBefore = IERC20(daiUsdcPool).balanceOf(address(this));

        // Prepare amounts
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        // Call prepay via vault.unlock() - this puts vault in unlocked state
        bytes memory result = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));

        uint256 bptReceived = abi.decode(result, (uint256));
        uint256 bptBalAfter = IERC20(daiUsdcPool).balanceOf(address(this));

        // Verify BPT was received
        assertGt(bptReceived, 0, "Should receive BPT");
        assertEq(bptBalAfter - bptBalBefore, bptReceived, "BPT balance mismatch");
    }

    function test_prepayRemoveLiquidityProportional_viaUnlock_success() public {
        // First add liquidity to get BPT
        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);
        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        bytes memory addResult = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));
        uint256 bptAmount = abi.decode(addResult, (uint256));

        // Approve the router to spend BPT (vault burns BPT via router)
        IERC20(daiUsdcPool).approve(address(seRouter), bptAmount);

        // Now remove liquidity - BPT is burned from sender
        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(daiUsdcPool);
        uint256 token0BalBefore = tokens[0].balanceOf(address(this));
        uint256 token1BalBefore = tokens[1].balanceOf(address(this));

        bytes memory removeResult =
            vault.unlock(abi.encodeCall(this.removeLiquidityProportionalCallback, (daiUsdcPool, bptAmount)));
        uint256[] memory amountsOut = abi.decode(removeResult, (uint256[]));

        uint256 token0BalAfter = tokens[0].balanceOf(address(this));
        uint256 token1BalAfter = tokens[1].balanceOf(address(this));

        // Verify tokens were received
        assertGt(amountsOut[0], 0, "Should receive token0");
        assertGt(amountsOut[1], 0, "Should receive token1");
        assertEq(token0BalAfter - token0BalBefore, amountsOut[0], "Token0 balance mismatch");
        assertEq(token1BalAfter - token1BalBefore, amountsOut[1], "Token1 balance mismatch");
    }

    function test_prepayRemoveLiquiditySingleTokenExactIn_viaUnlock_success() public {
        // First add liquidity to get BPT
        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);
        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        bytes memory addResult = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));
        uint256 bptAmount = abi.decode(addResult, (uint256));

        // Approve the router to spend BPT (vault burns BPT via router)
        IERC20(daiUsdcPool).approve(address(seRouter), bptAmount);

        // Now remove liquidity to single token
        uint256 daiBalBefore = dai.balanceOf(address(this));

        bytes memory removeResult = vault.unlock(
            abi.encodeCall(this.removeLiquiditySingleTokenCallback, (daiUsdcPool, bptAmount, address(dai)))
        );
        uint256 amountOut = abi.decode(removeResult, (uint256));

        uint256 daiBalAfter = dai.balanceOf(address(this));

        // Verify DAI was received
        assertGt(amountOut, 0, "Should receive DAI");
        assertEq(daiBalAfter - daiBalBefore, amountOut, "DAI balance mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Prepay Initialize Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_prepayInitialize_viaUnlock_success() public {
        // Create a new uninitialized pool
        address newPool = _createUninitializedPool();

        // Mint tokens to this contract
        dai.mint(address(this), LIQUIDITY_AMOUNT);
        usdc.mint(address(this), LIQUIDITY_AMOUNT);

        // Pre-transfer tokens to the vault
        dai.transfer(address(vault), LIQUIDITY_AMOUNT);
        usdc.transfer(address(vault), LIQUIDITY_AMOUNT);

        uint256 bptBalBefore = IERC20(newPool).balanceOf(address(this));

        // Get sorted tokens for the pool
        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(newPool);

        // Prepare amounts (same order as tokens)
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        // Call prepayInitialize via vault.unlock()
        bytes memory result = vault.unlock(abi.encodeCall(this.initializeCallback, (newPool, tokens, amounts)));

        uint256 bptReceived = abi.decode(result, (uint256));
        uint256 bptBalAfter = IERC20(newPool).balanceOf(address(this));

        // Verify BPT was received
        assertGt(bptReceived, 0, "Should receive BPT");
        assertEq(bptBalAfter - bptBalBefore, bptReceived, "BPT balance mismatch");
    }

    function test_prepayInitialize_directCall_reverts() public {
        // Create a new uninitialized pool
        address newPool = _createUninitializedPool();

        // Mint tokens to alice
        dai.mint(alice, LIQUIDITY_AMOUNT);
        usdc.mint(alice, LIQUIDITY_AMOUNT);

        vm.startPrank(alice);

        // Pre-transfer tokens to the router (won't matter, should revert before)
        dai.transfer(address(seRouter), LIQUIDITY_AMOUNT);
        usdc.transfer(address(seRouter), LIQUIDITY_AMOUNT);

        // Get sorted tokens for the pool
        IERC20[] memory tokens = IVault(address(vault)).getPoolTokens(newPool);

        // Prepare amounts
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQUIDITY_AMOUNT;
        amounts[1] = LIQUIDITY_AMOUNT;

        // Direct call should revert because vault is not unlocked
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector, alice, address(0)
            )
        );
        prepayRouter.prepayInitialize(newPool, tokens, amounts, 1, "");

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Callback Functions                             */
    /* ---------------------------------------------------------------------- */

    // These are called by vault.unlock() and run in the unlocked context

    function initializeCallback(address pool, IERC20[] memory tokens, uint256[] memory amounts)
        external
        returns (uint256 bptAmountOut)
    {
        return prepayRouter.prepayInitialize(
            pool,
            tokens,
            amounts,
            1, // minBptAmountOut
            ""
        );
    }

    function addLiquidityCallback(address pool, uint256[] memory amounts) external returns (uint256 bptAmountOut) {
        return prepayRouter.prepayAddLiquidityUnbalanced(
            pool,
            amounts,
            1, // minBptAmountOut
            ""
        );
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
        return prepayRouter.prepayRemoveLiquiditySingleTokenExactIn(
            pool,
            bptAmount,
            IERC20(tokenOut),
            1, // minAmountOut
            ""
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Adds liquidity to pool for a given address using prepay pattern.
     *      This helper is used to get BPT for testing remove liquidity functions.
     */
    function _addLiquidityForAddress(address recipient, uint256 amount) internal returns (uint256 bptAmount) {
        // Mint tokens to this contract
        dai.mint(address(this), amount);
        usdc.mint(address(this), amount);

        // Transfer to vault
        dai.transfer(address(vault), amount);
        usdc.transfer(address(vault), amount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        // Add liquidity via vault.unlock - BPT goes to this contract
        bytes memory result = vault.unlock(abi.encodeCall(this.addLiquidityCallback, (daiUsdcPool, amounts)));
        bptAmount = abi.decode(result, (uint256));

        // Transfer BPT to recipient
        IERC20(daiUsdcPool).transfer(recipient, bptAmount);
    }

    /**
     * @dev Creates a new uninitialized pool for testing prepayInitialize.
     */
    function _createUninitializedPool() internal returns (address newPool) {
        string memory name = "Test-Init Pool";
        string memory symbol = "TEST-INIT";

        newPool = PoolFactoryMock(testPoolFactory).createPool(name, symbol);
        vm.label(newPool, "testInitPool");

        // Register with sorted tokens (but don't initialize)
        address[] memory poolTokens = new address[](2);
        if (address(dai) < address(usdc)) {
            poolTokens[0] = address(dai);
            poolTokens[1] = address(usdc);
        } else {
            poolTokens[0] = address(usdc);
            poolTokens[1] = address(dai);
        }

        PoolFactoryMock(testPoolFactory)
            .registerTestPool(
                newPool,
                vault.buildTokenConfig(poolTokens.asIERC20()),
                testPoolHooksContract,
                address(this) // pool creator
            );

        // Approve pool BPT for all users
        approveForPool(IERC20(newPool));
    }
}
