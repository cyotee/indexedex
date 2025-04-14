// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV2StandardExchange
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";

/**
 * @title UniswapV2StandardExchange_DeployWithPool Tests
 * @notice Tests for the new deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient) function
 */
contract UniswapV2StandardExchange_DeployWithPool_Test is TestBase_UniswapV2StandardExchange {
    ERC20PermitMintableStub testTokenA;
    ERC20PermitMintableStub testTokenB;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public virtual override {
        super.setUp();

        // Create fresh test tokens that don't have a pair yet
        testTokenA = new ERC20PermitMintableStub("Test Token A", "TTA", 18, alice, 1000 ether);
        testTokenB = new ERC20PermitMintableStub("Test Token B", "TTB", 18, alice, 1000 ether);
        vm.label(address(testTokenA), "testTokenA");
        vm.label(address(testTokenB), "testTokenB");

        // Approve package to spend alice's tokens
        vm.startPrank(alice);
        testTokenA.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                          US-13.1: Create New Pair                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pair and vault without initial deposit
     * @dev US-13.1: deployVault(tokenA, 0, tokenB, 0, address(0)) creates pair and vault without initial deposit
     */
    function test_US13_1_CreateNewPairAndVaultWithoutDeposit() public {
        // Verify pair doesn't exist
        address pairBefore = uniswapV2Factory.getPair(address(testTokenA), address(testTokenB));
        assertEq(pairBefore, address(0), "Pair should not exist before");

        // Deploy vault
        vm.prank(alice);
        address vault = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 0, IERC20(address(testTokenB)), 0, address(0)
        );

        // Verify pair was created
        address pairAfter = uniswapV2Factory.getPair(address(testTokenA), address(testTokenB));
        assertTrue(pairAfter != address(0), "Pair should exist after");

        // Verify vault was deployed
        assertTrue(vault != address(0), "Vault should be deployed");

        // Verify no vault shares were minted (no deposit)
        assertEq(IERC20(vault).balanceOf(alice), 0, "Alice should have no vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*                    US-13.2: Create Pair with Initial Deposit               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pair with initial liquidity
     * @dev US-13.2: deployVault with amounts creates pair with liquidity, recipient receives vault shares
     */
    function test_US13_2_CreatePairWithInitialDeposit() public {
        uint256 amountA = 100 ether;
        uint256 amountB = 200 ether;

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Deploy vault with initial deposit
        vm.prank(alice);
        address vault = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)),
            amountA,
            IERC20(address(testTokenB)),
            amountB,
            bob // recipient
        );

        // Verify pair was created with liquidity
        address pairAddr = uniswapV2Factory.getPair(address(testTokenA), address(testTokenB));
        assertTrue(pairAddr != address(0), "Pair should exist");

        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0, "Pair should have reserves");

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
    function test_US13_2_RevertWhenRecipientZeroWithDeposit() public {
        vm.prank(alice);
        vm.expectRevert(IUniswapV2StandardExchangeDFPkg.RecipientRequiredForDeposit.selector);
        uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)),
            100 ether,
            IERC20(address(testTokenB)),
            200 ether,
            address(0) // invalid recipient for deposit
        );
    }

    /* -------------------------------------------------------------------------- */
    /*              US-13.3: Existing Pair with Proportional Deposit              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pair with proportional deposit
     * @dev US-13.3: If pair exists, calculate proportional amounts
     */
    function test_US13_3_ExistingPairWithProportionalDeposit() public {
        // First create pair with some liquidity
        vm.startPrank(alice);
        address vault1 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 100 ether, alice
        );
        vm.stopPrank();

        // Mint more tokens to alice for second deposit (use deal since mint requires owner)
        deal(address(testTokenA), alice, 1000 ether);
        deal(address(testTokenB), alice, 1000 ether);

        // Re-approve after deal
        vm.startPrank(alice);
        testTokenA.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Try to deposit with non-proportional amounts (should use proportional subset)
        vm.prank(alice);
        address vault2 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)),
            50 ether, // Want to deposit 50
            IERC20(address(testTokenB)),
            200 ether, // Want to deposit 200, but proportional is 50
            bob
        );

        // Vault should be the same as first (same pair)
        assertEq(vault1, vault2, "Should be same vault for same pair");

        // Verify proportional amounts were used (excess stays with caller)
        // If pair has 1:1 ratio, only 50 of each should be transferred
        uint256 aliceTokenAAfter = testTokenA.balanceOf(alice);
        uint256 aliceTokenBAfter = testTokenB.balanceOf(alice);

        // Token A should be fully used (50)
        assertEq(aliceTokenABefore - aliceTokenAAfter, 50 ether, "Should use all provided tokenA");
        // Token B should only use proportional amount (50), excess stays with alice
        assertEq(aliceTokenBBefore - aliceTokenBAfter, 50 ether, "Should only use proportional tokenB");
    }

    /* -------------------------------------------------------------------------- */
    /*               US-13.4: Existing Pair Without Deposit                       */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pair without deposit
     * @dev US-13.4: deployVault(tokenA, 0, tokenB, 0, address(0)) for existing pair
     */
    function test_US13_4_ExistingPairWithoutDeposit() public {
        // First create pair with initial liquidity
        vm.prank(alice);
        address vault1 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 100 ether, alice
        );

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        // Deploy vault for existing pair without deposit
        vm.prank(bob);
        address vault2 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 0, IERC20(address(testTokenB)), 0, address(0)
        );

        // Should return same vault
        assertEq(vault1, vault2, "Should be same vault for same pair");

        // No tokens should be transferred
        assertEq(testTokenA.balanceOf(alice), aliceTokenABefore, "No tokenA transfer");
        assertEq(testTokenB.balanceOf(alice), aliceTokenBBefore, "No tokenB transfer");
    }

    /* -------------------------------------------------------------------------- */
    /*                      US-13.5: Preview Proportional                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test preview for new pair (no existing pair)
     * @dev US-13.5: previewDeployVault returns pairExists=false for new pair
     */
    function test_US13_5_PreviewNewPair() public view {
        IUniswapV2StandardExchangeDFPkg.DeployWithPoolResult memory result =
            uniswapV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 200 ether
            );

        assertFalse(result.pairExists, "Pair should not exist");
        assertEq(result.proportionalA, 100 ether, "Should use full amountA");
        assertEq(result.proportionalB, 200 ether, "Should use full amountB");
        // expectedLP should be approximately sqrt(100 * 200) - 1000 (minimum liquidity)
        assertTrue(result.expectedLP > 0, "Expected LP should be positive");
    }

    /**
     * @notice Test preview for existing pair
     * @dev US-13.5: previewDeployVault calculates proportional amounts for existing pair
     */
    function test_US13_5_PreviewExistingPair() public {
        // Create pair first with 1:1 ratio
        vm.prank(alice);
        uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 100 ether, IERC20(address(testTokenB)), 100 ether, alice
        );

        // Preview with non-proportional amounts
        IUniswapV2StandardExchangeDFPkg.DeployWithPoolResult memory result =
            uniswapV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(testTokenA)),
                50 ether,
                IERC20(address(testTokenB)),
                200 ether // Extra B won't be used
            );

        assertTrue(result.pairExists, "Pair should exist");
        assertEq(result.proportionalA, 50 ether, "Should use full amountA");
        assertEq(result.proportionalB, 50 ether, "Should use proportional amountB");
        assertTrue(result.expectedLP > 0, "Expected LP should be positive");
    }

    /* -------------------------------------------------------------------------- */
    /*                      Existing deployVault(pair) Works                      */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Verify existing deployVault(pair) function still works
     */
    function test_ExistingDeployVaultPairStillWorks() public {
        // First create a pair via the factory
        address pairAddr = uniswapV2Factory.createPair(address(testTokenA), address(testTokenB));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);

        // Use existing deployVault(pair) function
        address vault = uniswapV2StandardExchangeDFPkg.deployVault(pair);
        assertTrue(vault != address(0), "Vault should be deployed");
    }
}
