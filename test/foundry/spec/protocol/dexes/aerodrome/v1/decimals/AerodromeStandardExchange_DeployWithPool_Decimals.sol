// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";

import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_AerodromeStandardExchange_Decimals
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_Decimals.sol";

/**
 * @title AerodromeStandardExchange_DeployWithPool Tests
 * @notice Tests for the new deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient) function
 */
abstract contract AerodromeStandardExchange_DeployWithPool_Decimals is TestBase_AerodromeStandardExchange_Decimals {
    MintableERC20Decimals testTokenA;
    MintableERC20Decimals testTokenB;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public virtual override {
        super.setUp();

        // Create fresh test tokens that don't have a pool yet
        testTokenA = new MintableERC20Decimals("Test Token A", "TTA", _tokenADecimals());
        testTokenA.mint(alice, _uA(1000));
        testTokenB = new MintableERC20Decimals("Test Token B", "TTB", _tokenBDecimals());
        testTokenB.mint(alice, _uB(1000));
        vm.label(address(testTokenA), "pairToken-testTokenA");
        vm.label(address(testTokenB), "otherToken-testTokenB");

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
        uint256 amountA = _uA(100);
        uint256 amountB = _uB(200);

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
            _uA(100),
            IERC20(address(testTokenB)),
            _uB(200),
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
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(100), alice
        );
        vm.stopPrank();

        // Mint more tokens to alice for second deposit (use deal since mint requires owner)
        testTokenA.mint(alice, _uA(1000));
        testTokenB.mint(alice, _uB(1000));

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Try to deposit with non-proportional amounts (should use proportional subset)
        vm.prank(alice);
        address vault2 = aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)),
            _uA(50), // Want to deposit 50 human pairToken
            IERC20(address(testTokenB)),
            _uB(200), // Want to deposit 200 human other, proportional 50
            bob
        );

        // Vault should be the same as first (same pool)
        assertEq(vault1, vault2, "Should be same vault for same pool");

        // Verify proportional amounts were used (excess stays with caller)
        // If pool has 1:1 ratio, only 50 of each should be transferred
        uint256 aliceTokenAAfter = testTokenA.balanceOf(alice);
        uint256 aliceTokenBAfter = testTokenB.balanceOf(alice);

        // Token A should be fully used (50)
        assertEq(aliceTokenABefore - aliceTokenAAfter, _uA(50), "Should use all provided tokenA");
        // Token B should only use proportional amount (50), excess stays with alice
        assertEq(aliceTokenBBefore - aliceTokenBAfter, _uB(50), "Should only use proportional tokenB");
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
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(100), alice
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
                IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(200)
            );

        assertFalse(result.poolExists, "Pool should not exist");
        assertEq(result.proportionalA, _uA(100), "Should use full amountA");
        assertEq(result.proportionalB, _uB(200), "Should use full amountB");
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
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(100), alice
        );

        // Preview with non-proportional amounts
        IAerodromeStandardExchangeDFPkg.DeployWithPoolResult memory result =
            aerodromeStandardExchangeDFPkg.previewDeployVault(
                IERC20(address(testTokenA)),
                _uA(50),
                IERC20(address(testTokenB)),
                _uB(200) // Extra B won't be used
            );

        assertTrue(result.poolExists, "Pool should exist");
        assertEq(result.proportionalA, _uA(50), "Should use full amountA");
        assertEq(result.proportionalB, _uB(50), "Should use proportional amountB");
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
        uint256 amountA = _uA(100);
        uint256 amountB = _uB(100);

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
        testTokenA.mint(alice, _uA(1000));
        testTokenB.mint(alice, _uB(1000));

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

        // Mint adds to leftover from first deposit; consume `amountA`/`amountB` from that balance.
        assertEq(testTokenA.balanceOf(alice), _uA(1000) + _uA(1000) - amountA - amountA, "Should use all provided tokenA on second deposit");
        assertEq(testTokenB.balanceOf(alice), _uB(1000) + _uB(1000) - amountB - amountB, "Should use all provided tokenB on second deposit");

        // Both deposits should have produced shares
        uint256 aliceSharesFinal = IERC20(vault1).balanceOf(alice);
        uint256 bobShares = IERC20(vault1).balanceOf(bob);
        assertEq(aliceSharesFinal, aliceShares1, "Alice shares unchanged (not the recipient)");
        assertTrue(bobShares > 0, "Bob should have shares after second deposit");

        // Verify pool reserves reflect both deposits in a token-order aware way
        _assertReservesAtLeast(poolAddr, amountA * 2, amountB * 2);
    }

    /**
     * @notice Variant: asymmetric amounts to exercise proportional deposit on second call
     * @dev First deposit uses asymmetric ratio (100 A : 200 B). Second call attempts a
     *      non-proportional deposit (50 A : 200 B) which should be reduced to the
     *      proportional subset (50 A : 100 B) - exercising `_proportionalDeposit`.
     */
    function test_DoubleDeployVaultWithDeposit_SamePool_Asymmetric() public {
        uint256 amountA1 = _uA(100);
        uint256 amountB1 = _uB(200); // asymmetric initial ratio 1:2

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
        testTokenA.mint(alice, _uA(1000));
        testTokenB.mint(alice, _uB(1000));

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
            IERC20(address(testTokenA)), _uA(50), IERC20(address(testTokenB)), _uB(200), bob
        );

        // Vault address should be the same (same pool = same vault)
        assertEq(vault1, vault2, "Should be same vault for same pool");

        // Verify proportional amounts were used (excess stays with caller)
        uint256 aliceTokenAAfter = testTokenA.balanceOf(alice);
        uint256 aliceTokenBAfter = testTokenB.balanceOf(alice);

        // Token A should be fully used (50)
        assertEq(aliceTokenABefore - aliceTokenAAfter, _uA(50), "Should use all provided tokenA on second deposit");
        // Token B should only use proportional amount (100), excess stays with alice
        assertEq(
            aliceTokenBBefore - aliceTokenBAfter, _uB(100), "Should only use proportional tokenB on second deposit"
        );

        // Both deposits should have produced shares
        uint256 aliceSharesFinal = IERC20(vault1).balanceOf(alice);
        uint256 bobShares = IERC20(vault1).balanceOf(bob);
        assertEq(aliceSharesFinal, aliceShares1, "Alice shares unchanged (first deposit recipient)");
        assertTrue(bobShares > 0, "Bob should have shares after second deposit");

        _assertReservesAtLeastSum(poolAddr, amountA1, _uA(50), amountB1, _uB(100));
    }

    function _assertReservesAtLeast(address poolAddr, uint256 amtA, uint256 amtB) internal view {
        IPool pool = IPool(poolAddr);
        (uint256 r0, uint256 r1,) = pool.getReserves();
        if (pool.token0() == address(testTokenA)) {
            assertTrue(r0 >= amtA, "Reserve0 pairToken");
            assertTrue(r1 >= amtB, "Reserve1 other");
        } else {
            assertTrue(r0 >= amtB, "Reserve0 other");
            assertTrue(r1 >= amtA, "Reserve1 pairToken");
        }
    }

    function _assertReservesAtLeastSum(address poolAddr, uint256 a1, uint256 a2, uint256 b1, uint256 b2)
        internal
        view
    {
        _assertReservesAtLeast(poolAddr, a1 + a2, b1 + b2);
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
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(100), alice
        );

        // Check LP allowance from DFPkg to vault is zero
        address poolAddr = aerodromePoolFactory.getPool(address(testTokenA), address(testTokenB), false);
        uint256 allowanceAfterFirst = IERC20(poolAddr).allowance(address(aerodromeStandardExchangeDFPkg), vault);
        assertEq(allowanceAfterFirst, 0, "LP allowance should be zero after first deposit");

        // Mint more tokens and re-approve
        testTokenA.mint(alice, _uA(1000));
        testTokenB.mint(alice, _uB(1000));
        vm.startPrank(alice);
        testTokenA.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(aerodromeStandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();

        // Second deploy with deposit
        vm.prank(alice);
        aerodromeStandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), _uA(50), IERC20(address(testTokenB)), _uB(50), bob
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
