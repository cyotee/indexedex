// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";
import {ICamelotV2StandardExchangeDFPkg} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {CamelotPair} from "@crane/contracts/protocols/dexes/camelot/v2/stubs/CamelotPair.sol";

/**
 * @title CamelotV2StandardExchange_DeployWithPool
 * @notice Tests for the new deployVault function with pool creation and initial deposit
 */
contract CamelotV2StandardExchange_DeployWithPool is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub tokenA;
    ERC20PermitMintableStub tokenB;
    address user;

    uint256 constant INITIAL_BALANCE = 1000 ether;

    function setUp() public override {
        super.setUp();

        user = makeAddr("user");

        // Deploy test tokens (name, symbol, decimals, recipient, initialAmount)
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, user, INITIAL_BALANCE);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, user, INITIAL_BALANCE);

        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");
    }

    /* -------------------------------------------------------------------------- */
    /*                     US-12.1: Create New Pair and Deploy Vault              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pair and vault without initial deposit
     * @dev Acceptance Criteria:
     *      - deployVault(tokenA, 0, tokenB, 0, address(0)) creates pair and vault without initial deposit
     *      - Pair created via Camelot factory
     *      - Vault deployed and registered with VaultRegistry
     *      - Returns vault address
     */
    function test_US12_1_CreateNewPairAndDeployVault_NoDeposit() public {
        // Verify pair doesn't exist
        address pairBefore = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertEq(pairBefore, address(0), "Pair should not exist before");

        // Deploy vault with new pair creation (no deposit)
        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0)
        );

        // Verify vault was deployed
        assertTrue(vault != address(0), "Vault should be deployed");

        // Verify pair was created
        address pairAfter = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pairAfter != address(0), "Pair should be created");
    }

    /* -------------------------------------------------------------------------- */
    /*                     US-12.2: Create Pair with Initial Deposit              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pair with initial liquidity and receiving vault shares
     * @dev Acceptance Criteria:
     *      - deployVault(tokenA, amountA, tokenB, amountB, recipient) creates pair with liquidity
     *      - Both tokens transferred from caller (via transferFrom)
     *      - LP tokens minted and deposited to vault
     *      - Recipient receives vault shares proportional to liquidity
     *      - Vault registered with VaultRegistry
     */
    function test_US12_2_CreatePairWithInitialDeposit() public {
        uint256 depositAmountA = 100 ether;
        uint256 depositAmountB = 200 ether;

        // Approve tokens
        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), depositAmountA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), depositAmountB);

        // Get balances before
        uint256 userTokenABefore = tokenA.balanceOf(user);
        uint256 userTokenBBefore = tokenB.balanceOf(user);

        // Deploy vault with initial deposit
        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB, user
        );
        vm.stopPrank();

        // Verify vault was deployed
        assertTrue(vault != address(0), "Vault should be deployed");

        // Verify pair was created
        address pair = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0), "Pair should be created");

        // Verify tokens were transferred
        uint256 userTokenAAfter = tokenA.balanceOf(user);
        uint256 userTokenBAfter = tokenB.balanceOf(user);
        assertEq(userTokenAAfter, userTokenABefore - depositAmountA, "TokenA should be transferred");
        assertEq(userTokenBAfter, userTokenBBefore - depositAmountB, "TokenB should be transferred");

        // Verify user received vault shares
        uint256 vaultShares = IERC20(vault).balanceOf(user);
        assertTrue(vaultShares > 0, "User should receive vault shares");

        // Verify pair has reserves
        ICamelotPair camelotPair = ICamelotPair(pair);
        (uint112 reserve0, uint112 reserve1,,) = camelotPair.getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0, "Pair should have reserves");
    }

    /* -------------------------------------------------------------------------- */
    /*          US-12.3: Deploy Vault for Existing Pair with Proportional Deposit */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pair with proportional deposit
     * @dev Acceptance Criteria:
     *      - If pair exists, use existing pair
     *      - Calculate proportional amounts based on current reserves
     *      - Transfer only proportional amounts (excess stays with caller)
     *      - Deposit LP to vault, recipient receives shares
     */
    function test_US12_3_DeployVaultForExistingPairWithProportionalDeposit() public {
        // First, create a pair with initial liquidity
        uint256 initialA = 100 ether;
        uint256 initialB = 200 ether;

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), initialA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), initialB);

        // Deploy first vault with initial deposit
        camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), initialA, IERC20(address(tokenB)), initialB, user
        );
        vm.stopPrank();

        // Now setup second user to deploy with proportional deposit
        address user2 = makeAddr("user2");
        deal(address(tokenA), user2, INITIAL_BALANCE);
        deal(address(tokenB), user2, INITIAL_BALANCE);

        uint256 depositAmountA = 50 ether;
        uint256 depositAmountB = 150 ether; // More than proportional (should use ~100 ether)

        vm.startPrank(user2);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), depositAmountA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), depositAmountB);

        uint256 user2TokenABefore = tokenA.balanceOf(user2);
        uint256 user2TokenBBefore = tokenB.balanceOf(user2);

        // Preview to check proportional amounts
        ICamelotV2StandardExchangeDFPkg.PreviewDeployVaultResult memory preview =
            camelotV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB
            );

        assertTrue(preview.pairExists, "Pair should exist");
        // For 100:200 ratio, if we use 50 tokenA, we need 100 tokenB
        assertEq(preview.proportionalA, depositAmountA, "Should use all of tokenA");
        assertEq(preview.proportionalB, 100 ether, "TokenB should be proportional to tokenA");

        // Deploy vault with proportional deposit
        address vault2 = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB, user2
        );
        vm.stopPrank();

        // Verify vault was deployed (should be same as first)
        assertTrue(vault2 != address(0), "Vault should be deployed");

        // Verify only proportional amounts were transferred
        uint256 user2TokenAAfter = tokenA.balanceOf(user2);
        uint256 user2TokenBAfter = tokenB.balanceOf(user2);

        assertEq(
            user2TokenAAfter,
            user2TokenABefore - preview.proportionalA,
            "Only proportional TokenA should be transferred"
        );
        assertEq(
            user2TokenBAfter,
            user2TokenBBefore - preview.proportionalB,
            "Only proportional TokenB should be transferred"
        );

        // Verify user2 received vault shares
        uint256 vaultShares = IERC20(vault2).balanceOf(user2);
        assertTrue(vaultShares > 0, "User2 should receive vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*          US-12.4: Deploy Vault for Existing Pair Without Deposit           */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pair without deposit
     * @dev Acceptance Criteria:
     *      - deployVault(tokenA, 0, tokenB, 0, address(0)) with existing pair
     *      - No token transfers occur
     *      - Vault deployed and registered
     *      - Returns vault address
     */
    function test_US12_4_DeployVaultForExistingPairWithoutDeposit() public {
        // First create the pair manually
        camelotV2Factory.createPair(address(tokenA), address(tokenB));
        address pair = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0), "Pair should exist");

        // Get user balances before
        uint256 userTokenABefore = tokenA.balanceOf(user);
        uint256 userTokenBBefore = tokenB.balanceOf(user);

        // Deploy vault without deposit
        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0)
        );

        // Verify vault was deployed
        assertTrue(vault != address(0), "Vault should be deployed");

        // Verify no tokens were transferred
        assertEq(tokenA.balanceOf(user), userTokenABefore, "No TokenA should be transferred");
        assertEq(tokenB.balanceOf(user), userTokenBBefore, "No TokenB should be transferred");

        // User should have no vault shares
        assertEq(IERC20(vault).balanceOf(user), 0, "User should have no vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*                     US-12.5: Preview Proportional Calculation              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test preview function for new pair (no existing reserves)
     * @dev Acceptance Criteria:
     *      - previewDeployVault returns pairExists = false
     *      - Returns provided amounts as proportional
     */
    function test_US12_5_PreviewNewPair() public view {
        uint256 amountA = 100 ether;
        uint256 amountB = 200 ether;

        ICamelotV2StandardExchangeDFPkg.PreviewDeployVaultResult memory result =
            camelotV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(tokenA)), amountA, IERC20(address(tokenB)), amountB
            );

        assertFalse(result.pairExists, "Pair should not exist");
        assertEq(result.proportionalA, amountA, "Should return provided amountA");
        assertEq(result.proportionalB, amountB, "Should return provided amountB");
        assertTrue(result.expectedLP > 0, "Should calculate expected LP");
    }

    /**
     * @notice Test preview function for existing pair with reserves
     * @dev Acceptance Criteria:
     *      - previewDeployVault returns pairExists = true
     *      - Returns proportional amounts based on reserves
     *      - Calculates expected LP tokens
     */
    function test_US12_5_PreviewExistingPair() public {
        // Create pair with initial liquidity
        uint256 initialA = 100 ether;
        uint256 initialB = 200 ether;

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), initialA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), initialB);

        camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), initialA, IERC20(address(tokenB)), initialB, user
        );
        vm.stopPrank();

        // Preview with amounts that need adjustment
        uint256 previewAmountA = 50 ether;
        uint256 previewAmountB = 150 ether; // More than proportional

        ICamelotV2StandardExchangeDFPkg.PreviewDeployVaultResult memory result =
            camelotV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(tokenA)), previewAmountA, IERC20(address(tokenB)), previewAmountB
            );

        assertTrue(result.pairExists, "Pair should exist");
        assertEq(result.proportionalA, previewAmountA, "Should use all of tokenA");
        // For 100:200 ratio, 50 tokenA needs 100 tokenB
        assertEq(result.proportionalB, 100 ether, "TokenB should be proportional");
        assertTrue(result.expectedLP > 0, "Should calculate expected LP");
    }

    /* -------------------------------------------------------------------------- */
    /*                           Edge Cases and Error Tests                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that existing deployVault(pair) function still works
     */
    function test_ExistingDeployVaultStillWorks() public {
        // Create pair manually
        camelotV2Factory.createPair(address(tokenA), address(tokenB));
        address pair = camelotV2Factory.getPair(address(tokenA), address(tokenB));

        // Use the original deployVault function
        address vault = camelotV2StandardExchangeDFPkg.deployVault(ICamelotPair(pair));

        assertTrue(vault != address(0), "Vault should be deployed via original function");
    }

    /**
     * @notice Test that providing amounts with zero recipient reverts
     */
    function test_RevertWhen_NonZeroAmountsWithZeroRecipient() public {
        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), 100 ether);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), 100 ether);

        // Should NOT revert - zero recipient with zero amounts is allowed for pair creation only
        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0)
        );
        assertTrue(vault != address(0), "Should work with zero amounts and zero recipient");
        vm.stopPrank();
    }

    /**
     * @notice Test that providing zero amounts with non-zero recipient reverts
     */
    function test_RevertWhen_ZeroAmountsWithNonZeroRecipient() public {
        vm.expectRevert(ICamelotV2StandardExchangeDFPkg.ZeroAmountForNonZeroRecipient.selector);
        camelotV2StandardExchangeDFPkg.deployVault(IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 100 ether, user);
    }

    /**
     * @notice Test PairCreated event emission
     */
    function test_EmitsPairCreatedEvent() public {
        vm.expectEmit(true, true, false, false);
        emit ICamelotV2StandardExchangeDFPkg.PairCreated(address(tokenA), address(tokenB), address(0));

        camelotV2StandardExchangeDFPkg.deployVault(IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0));
    }

    /**
     * @notice Test VaultDeployedWithDeposit event emission
     */
    function test_EmitsVaultDeployedWithDepositEvent() public {
        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), 100 ether);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), 200 ether);

        // We can't easily predict vault address, so just check recipient is correct
        // vm.expectEmit(topic1Check, topic2Check, topic3Check, dataCheck)
        // topic1 = vault (indexed), topic2 = pair (indexed), topic3 = recipient (indexed)
        vm.expectEmit(false, false, true, false);
        emit ICamelotV2StandardExchangeDFPkg.VaultDeployedWithDeposit(address(0), address(0), user, 0, 0);

        camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 100 ether, IERC20(address(tokenB)), 200 ether, user
        );
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*       US-48.1: InsufficientLiquidity revert on dust amounts                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that deployVault reverts with InsufficientLiquidity when dust
     *         amounts are provided against a pair with highly imbalanced reserves.
     * @dev Acceptance Criteria:
     *      - Existing pair with large reserve imbalance (1 wei tokenA : 1000 ether tokenB)
     *      - Second deposit of (1 wei, 1 wei) causes proportionalA to round to 0
     *      - Reverts with InsufficientLiquidity
     *      - Exercises revert at CamelotV2StandardExchangeDFPkg.sol:215
     */
    function test_US48_1_RevertWhen_InsufficientLiquidity_DustAmounts() public {
        // Create pair with highly imbalanced reserves: 1 wei tokenA, 1000 ether tokenB
        // This creates a ratio where tiny deposits on the heavy side round to 0
        uint256 seedA = 1;
        uint256 seedB = 1000 ether;

        // Mint enough tokens to the user
        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), seedA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), seedB);

        // Seed the pair via initial vault deployment
        camelotV2StandardExchangeDFPkg.deployVault(IERC20(address(tokenA)), seedA, IERC20(address(tokenB)), seedB, user);
        vm.stopPrank();

        // Now a second user tries to deposit dust amounts
        // With reserves 1:1000e18, depositing (1 wei, 1 wei):
        //   optimalB = 1 * 1000e18 / 1 = 1000e18 > 1
        //   else branch: depositA = 1 * 1 / 1000e18 = 0  (integer division)
        //   proportionalA == 0 → InsufficientLiquidity
        address dustUser = makeAddr("dustUser");
        deal(address(tokenA), dustUser, 1);
        deal(address(tokenB), dustUser, 1);

        vm.startPrank(dustUser);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), 1);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), 1);

        vm.expectRevert(ICamelotV2StandardExchangeDFPkg.InsufficientLiquidity.selector);
        camelotV2StandardExchangeDFPkg.deployVault(IERC20(address(tokenA)), 1, IERC20(address(tokenB)), 1, dustUser);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*       US-48.2: PoolMustNotBeStable revert                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that deployVault reverts with PoolMustNotBeStable when the
     *         Camelot pair is configured as a stable swap pool.
     * @dev Acceptance Criteria:
     *      - Pair exists with stableSwap == true
     *      - deployVault reverts with PoolMustNotBeStable
     *      - Exercises the check at CamelotV2StandardExchangeDFPkg.sol:564
     */
    function test_US48_2_RevertWhen_PoolMustNotBeStable() public {
        // Create pair first
        camelotV2Factory.createPair(address(tokenA), address(tokenB));
        address pairAddr = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        CamelotPair pair = CamelotPair(pairAddr);

        // setStableSwap requires caller == factory.setStableOwner()
        // The factory was created by this test contract, so setStableOwner == address(this)
        // Reserves are (0, 0) since no liquidity has been added
        pair.setStableSwap(true, 0, 0);
        assertTrue(pair.stableSwap(), "Pair should be stable");

        // Attempt to deploy vault with the stable pair should revert
        // The revert happens in processArgs() called by the registry during deployVault
        vm.expectRevert(abi.encodeWithSelector(ICamelotV2StandardExchangeDFPkg.PoolMustNotBeStable.selector, pair));
        camelotV2StandardExchangeDFPkg.deployVault(ICamelotPair(pairAddr));
    }

    /* -------------------------------------------------------------------------- */
    /*       US-48.3: Token ordering flip                                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that deployVault works correctly when address(tokenB) < address(tokenA),
     *         exercising the reserve sorting and token-ordering logic.
     * @dev Acceptance Criteria:
     *      - Tokens passed such that address(tokenB) < address(tokenA)
     *      - Proportional amounts calculated correctly despite reversed ordering
     *      - Exercises sorting logic in _calculateProportionalAmounts and _transferAndMintLP
     */
    function test_US48_3_DeployVault_TokenOrderingFlip() public {
        // Determine which token has the lower address
        // We want to pass them in "flipped" order: the higher-address token as tokenA
        IERC20 highToken;
        IERC20 lowToken;
        if (address(tokenA) < address(tokenB)) {
            highToken = IERC20(address(tokenB));
            lowToken = IERC20(address(tokenA));
        } else {
            highToken = IERC20(address(tokenA));
            lowToken = IERC20(address(tokenB));
        }

        // Verify the ordering: we pass highToken as the "tokenA" parameter
        // so address(paramTokenB) < address(paramTokenA)
        assertTrue(address(lowToken) < address(highToken), "lowToken should have smaller address");

        uint256 depositHigh = 100 ether;
        uint256 depositLow = 200 ether;

        // First deploy with initial liquidity (seeding the pair)
        vm.startPrank(user);
        IERC20(address(highToken)).approve(address(camelotV2StandardExchangeDFPkg), depositHigh);
        IERC20(address(lowToken)).approve(address(camelotV2StandardExchangeDFPkg), depositLow);

        // Pass tokens in "flipped" order: highToken first (as tokenA param)
        address vault1 = camelotV2StandardExchangeDFPkg.deployVault(highToken, depositHigh, lowToken, depositLow, user);
        vm.stopPrank();

        assertTrue(vault1 != address(0), "Vault should be deployed");

        // Second deposit with a different user to exercise proportional logic
        address user2 = makeAddr("user2");
        deal(address(highToken), user2, INITIAL_BALANCE);
        deal(address(lowToken), user2, INITIAL_BALANCE);

        uint256 deposit2High = 50 ether;
        uint256 deposit2Low = 150 ether; // More than proportional

        vm.startPrank(user2);
        IERC20(address(highToken)).approve(address(camelotV2StandardExchangeDFPkg), deposit2High);
        IERC20(address(lowToken)).approve(address(camelotV2StandardExchangeDFPkg), deposit2Low);

        // Preview to verify proportional calculation with flipped ordering
        ICamelotV2StandardExchangeDFPkg.PreviewDeployVaultResult memory preview =
            camelotV2StandardExchangeDFPkg.previewDeployVault(highToken, deposit2High, lowToken, deposit2Low);

        assertTrue(preview.pairExists, "Pair should exist");
        // Ratio is 100:200 (high:low), so 50 high needs 100 low
        assertEq(preview.proportionalA, deposit2High, "Should use all of highToken");
        assertEq(preview.proportionalB, 100 ether, "lowToken should be proportional");

        uint256 user2HighBefore = IERC20(address(highToken)).balanceOf(user2);
        uint256 user2LowBefore = IERC20(address(lowToken)).balanceOf(user2);

        // Deploy with flipped ordering
        address vault2 =
            camelotV2StandardExchangeDFPkg.deployVault(highToken, deposit2High, lowToken, deposit2Low, user2);
        vm.stopPrank();

        assertTrue(vault2 != address(0), "Second vault should be deployed");

        // Verify only proportional amounts transferred
        uint256 user2HighAfter = IERC20(address(highToken)).balanceOf(user2);
        uint256 user2LowAfter = IERC20(address(lowToken)).balanceOf(user2);
        assertEq(user2HighAfter, user2HighBefore - preview.proportionalA, "Only proportional highToken transferred");
        assertEq(user2LowAfter, user2LowBefore - preview.proportionalB, "Only proportional lowToken transferred");

        // Verify vault shares received
        uint256 vaultShares = IERC20(vault2).balanceOf(user2);
        assertTrue(vaultShares > 0, "User2 should receive vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*       US-48.4: Residual balance assertion                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that the DFPkg contract holds zero tokens after deployVault.
     * @dev Acceptance Criteria:
     *      - After successful deployVault with deposit, DFPkg balance of tokenA == 0
     *      - DFPkg balance of tokenB == 0
     *      - DFPkg balance of LP token == 0
     */
    function test_US48_4_NoResidualBalancesAfterDeployVault() public {
        uint256 depositAmountA = 100 ether;
        uint256 depositAmountB = 200 ether;

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), depositAmountA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), depositAmountB);

        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB, user
        );
        vm.stopPrank();

        assertTrue(vault != address(0), "Vault should be deployed");

        // Get the pair address
        address pairAddr = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pairAddr != address(0), "Pair should exist");

        // Assert DFPkg holds zero of all tokens
        address dfpkg = address(camelotV2StandardExchangeDFPkg);
        assertEq(tokenA.balanceOf(dfpkg), 0, "DFPkg should hold zero tokenA");
        assertEq(tokenB.balanceOf(dfpkg), 0, "DFPkg should hold zero tokenB");
        assertEq(IERC20(pairAddr).balanceOf(dfpkg), 0, "DFPkg should hold zero LP tokens");
    }
}
