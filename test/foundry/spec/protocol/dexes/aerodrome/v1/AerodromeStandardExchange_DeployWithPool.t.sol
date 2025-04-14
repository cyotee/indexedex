// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";

/**
 * @title AerodromeStandardExchange_DeployWithPool Tests
 * @notice Tests for the new deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient) function
 */
contract AerodromeStandardExchange_DeployWithPool_Test is TestBase_AerodromeStandardExchange {
    ERC20PermitMintableStub testTokenA;
    ERC20PermitMintableStub testTokenB;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public virtual override {
        super.setUp();

        // Create fresh test tokens that don't have a pool yet
        testTokenA = new ERC20PermitMintableStub("Test Token A", "TTA", 18, alice, 1000 ether);
        testTokenB = new ERC20PermitMintableStub("Test Token B", "TTB", 18, alice, 1000 ether);
        vm.label(address(testTokenA), "testTokenA");
        vm.label(address(testTokenB), "testTokenB");

        // Approve package to spend alice's tokens
        vm.startPrank(alice);
        testTokenA.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                          US-11.1: Create New Pool                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pool and vault without initial deposit
     * @dev US-11.1: deployVault(tokenA, 0, tokenB, 0, address(0)) creates pool and vault without initial deposit
     */
    function test_US11_1_CreateNewPoolAndVaultWithoutDeposit() public {
        // Verify pool doesn't exist
        address poolBefore = aerodromePoolFactory.getPool(address(testTokenA), address(testTokenB), false);
        assertEq(poolBefore, address(0), "Pool should not exist before");

        // Deploy vault
        vm.prank(alice);
        address vault = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 0, IERC20(address(testTokenB)), 0, address(0)
        );

        // Verify pool was created
        address poolAfter = aerodromePoolFactory.getPool(address(testTokenA), address(testTokenB), false);
        assertTrue(poolAfter != address(0), "Pool should exist after");

        // Verify pool is volatile (not stable)
        IPool pool = IPool(poolAfter);
        assertFalse(pool.stable(), "Pool should be volatile");

        // Verify vault was deployed
        assertTrue(vault != address(0), "Vault should be deployed");

        // Verify no vault shares were minted (no deposit)
        assertEq(IERC20(vault).balanceOf(alice), 0, "Alice should have no vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*                    US-11.2: Create Pool with Initial Deposit               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pool with initial liquidity
     * @dev US-11.2: deployVault with amounts creates pool with liquidity, recipient receives vault shares
     */
    function test_US11_2_CreatePoolWithInitialDeposit() public {
        uint256 amountA = 100 ether;
        uint256 amountB = 200 ether;

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Deploy vault with initial deposit
        vm.prank(alice);
        address vault = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)),
            amountA,
            IERC20(address(testTokenB)),
            amountB,
            bob // recipient
        );

        // Verify pool was created with liquidity
        address poolAddr = aerodromePoolFactory.getPool(address(testTokenA), address(testTokenB), false);
        assertTrue(poolAddr != address(0), "Pool should exist");

        IPool pool = IPool(poolAddr);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0, "Pool should have reserves");

        // Verify tokens were transferred from alice
        assertEq(testTokenA.balanceOf(alice), aliceTokenABefore - amountA, "TokenA should be transferred");
        assertEq(testTokenB.balanceOf(alice), aliceTokenBBefore - amountB, "TokenB should be transferred");

        // Verify bob (recipient) received vault shares
        uint256 bobShares = IERC20(vault).balanceOf(bob);
        assertTrue(bobShares > 0, "Bob should have vault shares");

        // Verify alice didn't receive shares (she's the depositor, bob is the recipient)
        assertEq(IERC20(vault).balanceOf(alice), 0, "Alice should have no vault shares");
    }

    /**
     * @notice Test that recipient is required when amounts are provided
     * @dev Should revert with RecipientRequiredForDeposit when recipient is address(0)
     */
    function test_US11_2_RevertWhenRecipientZeroWithDeposit() public {
        vm.prank(alice);
        vm.expectRevert(IAerodromeStandardExchangeDFPkg.RecipientRequiredForDeposit.selector);
        aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)),
            100 ether,
            IERC20(address(testTokenB)),
            200 ether,
            address(0) // invalid recipient for deposit
        );
    }

    /* -------------------------------------------------------------------------- */
    /*              US-11.3: Existing Pool with Proportional Deposit              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pool with proportional deposit
     * @dev US-11.3: If pool exists, calculate proportional amounts
     */
    function test_US11_3_ExistingPoolWithProportionalDeposit() public {
        // First create pool with some liquidity
        vm.startPrank(alice);
        address vault1 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 100 ether, alice
        );
        vm.stopPrank();

        // Mint more tokens to alice for second deposit (use deal since mint requires owner)
        deal(address(testTokenA), alice, 1000 ether);
        deal(address(testTokenB), alice, 1000 ether);

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Try to deposit with non-proportional amounts (should use proportional subset)
        vm.prank(alice);
        address vault2 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)),
            50 ether, // Want to deposit 50
            IERC20(address(testTokenB)),
            200 ether, // Want to deposit 200, but proportional is 50
            bob
        );

        // Vault should be the same as first (same pool)
        assertEq(vault1, vault2, "Should be same vault for same pool");

        // Verify proportional amounts were used (excess stays with caller)
        // If pool has 1:1 ratio, only 50 of each should be transferred
        uint256 aliceTokenAAfter = testTokenA.balanceOf(alice);
        uint256 aliceTokenBAfter = testTokenB.balanceOf(alice);

        // Token A should be fully used (50)
        assertEq(aliceTokenABefore - aliceTokenAAfter, 50 ether, "Should use all provided tokenA");
        // Token B should only use proportional amount (50), excess stays with alice
        assertEq(aliceTokenBBefore - aliceTokenBAfter, 50 ether, "Should only use proportional tokenB");
    }

    /* -------------------------------------------------------------------------- */
    /*               US-11.4: Existing Pool Without Deposit                       */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pool without deposit
     * @dev US-11.4: deployVault(tokenA, 0, tokenB, 0, address(0)) for existing pool
     */
    function test_US11_4_ExistingPoolWithoutDeposit() public {
        // First create pool with initial liquidity
        vm.prank(alice);
        address vault1 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 100 ether, alice
        );

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Deploy vault for existing pool without deposit
        vm.prank(bob);
        address vault2 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 0, IERC20(address(testTokenB)), 0, address(0)
        );

        // Should return same vault
        assertEq(vault1, vault2, "Should be same vault for same pool");

        // No tokens should be transferred
        assertEq(testTokenA.balanceOf(alice), aliceTokenABefore, "No tokenA transfer");
        assertEq(testTokenB.balanceOf(alice), aliceTokenBBefore, "No tokenB transfer");
    }

    /* -------------------------------------------------------------------------- */
    /*                      US-11.5: Preview Proportional                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test preview for new pool (no existing pool)
     * @dev US-11.5: previewDeployVault returns poolExists=false for new pool
     */
    function test_US11_5_PreviewNewPool() public view {
        IAerodromeStandardExchangeDFPkg.DeployWithPoolResult memory result =
            aerodromeStandardExchangeDFPkg.previewDeployVault(
                IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 200 ether
            );

        assertFalse(result.poolExists, "Pool should not exist");
        assertEq(result.proportionalA, 100 ether, "Should use full amountA");
        assertEq(result.proportionalB, 200 ether, "Should use full amountB");
        // expectedLP should be approximately sqrt(100 * 200) - 1000 (minimum liquidity)
        assertTrue(result.expectedLP > 0, "Expected LP should be positive");
    }

    /**
     * @notice Test preview for existing pool
     * @dev US-11.5: previewDeployVault calculates proportional amounts for existing pool
     */
    function test_US11_5_PreviewExistingPool() public {
        // Create pool first with 1:1 ratio
        vm.prank(alice);
        aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 100 ether, alice
        );

        // Preview with non-proportional amounts
        IAerodromeStandardExchangeDFPkg.DeployWithPoolResult memory result =
            aerodromeStandardExchangeDFPkg.previewDeployVault(
                IERC20(address(testTokenA)),
                50 ether,
                IERC20(address(testTokenB)),
                200 ether // Extra B won't be used
            );

        assertTrue(result.poolExists, "Pool should exist");
        assertEq(result.proportionalA, 50 ether, "Should use full amountA");
        assertEq(result.proportionalB, 50 ether, "Should use proportional amountB");
        assertTrue(result.expectedLP > 0, "Expected LP should be positive");
    }

    /* -------------------------------------------------------------------------- */
    /*          D-03: Double deployVault with Deposit (safeApprove path)          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test calling deployVault with deposit twice on the same pool.
     * @dev Exercises the LP approval path on a repeated call. Verifies that
     *      safeApprove doesn't revert on the second call (which it would if
     *      the first call left residual allowance on tokens with USDT-style
     *      approval semantics). The forceApprove(vault, 0) cleanup in the
     *      DFPkg should prevent this.
     */
    function test_DoubleDeployVaultWithDeposit_SamePool() public {
        uint256 amountA = 100 ether;
        uint256 amountB = 100 ether;

        // --- First deploy with deposit ---
        vm.prank(alice);
        address vault1 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), amountA, IERC20(address(testTokenB)), amountB, alice
        );

        uint256 aliceShares1 = IERC20(vault1).balanceOf(alice);
        assertTrue(aliceShares1 > 0, "Alice should have shares after first deposit");

        // Verify pool was created
        address poolAddr = aerodromePoolFactory.getPool(address(testTokenA), address(testTokenB), false);
        assertTrue(poolAddr != address(0), "Pool should exist after first deploy");

        // Mint more tokens to alice for second deposit
        deal(address(testTokenA), alice, 1000 ether);
        deal(address(testTokenB), alice, 1000 ether);

        // Re-approve for second deposit
        vm.startPrank(alice);
        testTokenA.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();

        // --- Second deploy with deposit (same pool) ---
        // This is the critical test: safeApprove must not revert
        vm.prank(alice);
        address vault2 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), amountA, IERC20(address(testTokenB)), amountB, bob
        );

        // Vault address should be the same (same pool = same vault)
        assertEq(vault1, vault2, "Second deploy should return same vault");

        // Verify exact token transfers for second deposit
        // We used `deal(..., 1000 ether)` before re-funding alice, so her balance before the second deposit
        // is 1000 ether; after depositing `amountA`/`amountB` it should be (1000 - amount)
        assertEq(testTokenA.balanceOf(alice), 1000 ether - amountA, "Should use all provided tokenA on second deposit");
        assertEq(testTokenB.balanceOf(alice), 1000 ether - amountB, "Should use all provided tokenB on second deposit");

        // Both deposits should have produced shares
        uint256 aliceSharesFinal = IERC20(vault1).balanceOf(alice);
        uint256 bobShares = IERC20(vault1).balanceOf(bob);
        assertEq(aliceSharesFinal, aliceShares1, "Alice shares unchanged (not the recipient)");
        assertTrue(bobShares > 0, "Bob should have shares after second deposit");

        // Verify pool reserves reflect both deposits in a token-order aware way
        IPool pool = IPool(poolAddr);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        address token0 = pool.token0();
        // Expected totals are two deposits of each token; compare inline to avoid stack issues
        if (token0 == address(testTokenA)) {
            assertTrue(reserve0 >= amountA * 2, "Reserve0 should reflect both deposits (tokenA)");
            assertTrue(reserve1 >= amountB * 2, "Reserve1 should reflect both deposits (tokenB)");
        } else {
            // token0 == testTokenB
            assertTrue(reserve0 >= amountB * 2, "Reserve0 should reflect both deposits (tokenB)");
            assertTrue(reserve1 >= amountA * 2, "Reserve1 should reflect both deposits (tokenA)");
        }
    }

    /**
     * @notice Variant: asymmetric amounts to exercise proportional deposit on second call
     * @dev First deposit uses asymmetric ratio (100 A : 200 B). Second call attempts a
     *      non-proportional deposit (50 A : 200 B) which should be reduced to the
     *      proportional subset (50 A : 100 B) — exercising `_proportionalDeposit`.
     */
    function test_DoubleDeployVaultWithDeposit_SamePool_Asymmetric() public {
        uint256 amountA1 = 100 ether;
        uint256 amountB1 = 200 ether; // asymmetric initial ratio 1:2

        // --- First deploy with asymmetric initial deposit ---
        vm.prank(alice);
        address vault1 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), amountA1, IERC20(address(testTokenB)), amountB1, alice
        );

        uint256 aliceShares1 = IERC20(vault1).balanceOf(alice);
        assertTrue(aliceShares1 > 0, "Alice should have shares after first asymmetric deposit");

        // Verify pool was created
        address poolAddr = aerodromePoolFactory.getPool(address(testTokenA), address(testTokenB), false);
        assertTrue(poolAddr != address(0), "Pool should exist after first deploy");

        // Mint more tokens to alice for second deposit
        deal(address(testTokenA), alice, 1000 ether);
        deal(address(testTokenB), alice, 1000 ether);

        // Record balances before second (attempted non-proportional) deposit
        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Re-approve for second deposit
        vm.startPrank(alice);
        testTokenA.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();

        // --- Second deploy with non-proportional requested amounts ---
        // Request 50 A : 200 B, but proportional deposit for pool ratio 1:2 is 50 A : 100 B
        vm.prank(alice);
        address vault2 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 50 ether, IERC20(address(testTokenB)), 200 ether, bob
        );

        // Vault address should be the same (same pool = same vault)
        assertEq(vault1, vault2, "Should be same vault for same pool");

        // Verify proportional amounts were used (excess stays with caller)
        uint256 aliceTokenAAfter = testTokenA.balanceOf(alice);
        uint256 aliceTokenBAfter = testTokenB.balanceOf(alice);

        // Token A should be fully used (50)
        assertEq(aliceTokenABefore - aliceTokenAAfter, 50 ether, "Should use all provided tokenA on second deposit");
        // Token B should only use proportional amount (100), excess stays with alice
        assertEq(
            aliceTokenBBefore - aliceTokenBAfter, 100 ether, "Should only use proportional tokenB on second deposit"
        );

        // Both deposits should have produced shares
        uint256 aliceSharesFinal = IERC20(vault1).balanceOf(alice);
        uint256 bobShares = IERC20(vault1).balanceOf(bob);
        assertEq(aliceSharesFinal, aliceShares1, "Alice shares unchanged (first deposit recipient)");
        assertTrue(bobShares > 0, "Bob should have shares after second deposit");

        // Verify pool reserves reflect both deposits (note token0 == testTokenB)
        IPool pool = IPool(poolAddr);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        // reserve0 is tokenB: should be amountB1 + proportional B (100)
        assertTrue(reserve0 >= amountB1 + 100 ether, "Reserve0 should reflect both deposits (tokenB)");
        // reserve1 is tokenA: should be amountA1 + proportional A (50)
        assertTrue(reserve1 >= amountA1 + 50 ether, "Reserve1 should reflect both deposits (tokenA)");
    }

    /**
     * @notice Test that the LP allowance is fully cleared between deposits.
     * @dev After each deployVault-with-deposit call, the DFPkg should have
     *      zero LP allowance remaining on the vault.
     */
    function test_DoubleDeployVaultWithDeposit_AllowanceCleared() public {
        // First deploy with deposit
        vm.prank(alice);
        address vault = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 100 ether, alice
        );

        // Check LP allowance from DFPkg to vault is zero
        address poolAddr = aerodromePoolFactory.getPool(address(testTokenA), address(testTokenB), false);
        uint256 allowanceAfterFirst = IERC20(poolAddr).allowance(address(aerodromeStandardExchangeDFPkg), vault);
        assertEq(allowanceAfterFirst, 0, "LP allowance should be zero after first deposit");

        // Mint more tokens and re-approve
        deal(address(testTokenA), alice, 1000 ether);
        deal(address(testTokenB), alice, 1000 ether);
        vm.startPrank(alice);
        testTokenA.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();

        // Second deploy with deposit
        vm.prank(alice);
        aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 50 ether, IERC20(address(testTokenB)), 50 ether, bob
        );

        // Check LP allowance is still zero after second deposit
        uint256 allowanceAfterSecond = IERC20(poolAddr).allowance(address(aerodromeStandardExchangeDFPkg), vault);
        assertEq(allowanceAfterSecond, 0, "LP allowance should be zero after second deposit");
    }

    /* -------------------------------------------------------------------------- */
    /*                      Existing deployVault(pool) Works                      */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Verify existing deployVault(pool) function still works
     */
    function test_ExistingDeployVaultPoolStillWorks() public {
        // Use existing pool from test base
        address vault = aerodromeStandardExchangeDFPkg.deployVault(aeroBalancedPool);
        assertTrue(vault != address(0), "Vault should be deployed");
    }
}
