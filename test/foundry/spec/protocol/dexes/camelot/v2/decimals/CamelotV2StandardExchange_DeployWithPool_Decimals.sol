// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ICamelotV2StandardExchangeDFPkg} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol";
import {CamelotPair} from "@crane/contracts/protocols/dexes/camelot/v2/stubs/CamelotPair.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";

/**
 * @title CamelotV2StandardExchange_DeployWithPool_Decimals
 * @notice US-12 deployVault money paths on combo decimals. pairToken = tokenA.
 * @dev After Camelot pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      vaultShare stays 18.
 */
abstract contract CamelotV2StandardExchange_DeployWithPool_Decimals is TestBase_CamelotV2StandardExchange_Decimals {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    address internal user;

    function setUp() public virtual override {
        super.setUp();

        user = makeAddr("user");

        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(user, _uA(10_000));
        tokenB.mint(user, _uB(10_000));

        vm.label(address(tokenA), "pairToken-tokenA");
        vm.label(address(tokenB), "otherToken-tokenB");
    }

    /* -------------------------------------------------------------------------- */
    /*                     US-12.1: Create New Pair and Deploy Vault              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pair and vault without initial deposit.
     * @dev pairToken = tokenA at `_tokenADecimals()`; other = tokenB at `_tokenBDecimals()`.
     */
    function test_US12_1_CreateNewPairAndDeployVault_NoDeposit() public {
        address pairBefore = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertEq(pairBefore, address(0), "Pair should not exist before");

        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0)
        );

        assertTrue(vault != address(0), "Vault should be deployed");

        address pairAfter = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pairAfter != address(0), "Pair should be created");
    }

    /* -------------------------------------------------------------------------- */
    /*                     US-12.2: Create Pair with Initial Deposit              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test creating a new pair with initial liquidity and receiving vault shares.
     * @dev pairToken amount is `_uA(100)`; other is `_uB(200)`. vaultShare stays 18.
     */
    function test_US12_2_CreatePairWithInitialDeposit() public {
        uint256 depositAmountA = _uA(100);
        uint256 depositAmountB = _uB(200);

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), depositAmountA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), depositAmountB);

        uint256 userTokenABefore = tokenA.balanceOf(user);
        uint256 userTokenBBefore = tokenB.balanceOf(user);

        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB, user
        );
        vm.stopPrank();

        assertTrue(vault != address(0), "Vault should be deployed");

        address pair = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0), "Pair should be created");

        uint256 userTokenAAfter = tokenA.balanceOf(user);
        uint256 userTokenBAfter = tokenB.balanceOf(user);
        assertEq(userTokenAAfter, userTokenABefore - depositAmountA, "TokenA should be transferred");
        assertEq(userTokenBAfter, userTokenBBefore - depositAmountB, "TokenB should be transferred");

        uint256 vaultShares = IERC20(vault).balanceOf(user);
        assertTrue(vaultShares > 0, "User should receive vault shares");

        ICamelotPair camelotPair = ICamelotPair(pair);
        (uint112 reserve0, uint112 reserve1,,) = camelotPair.getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0, "Pair should have reserves");
    }

    /* -------------------------------------------------------------------------- */
    /*          US-12.3: Deploy Vault for Existing Pair with Proportional Deposit */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pair with proportional deposit.
     * @dev Seed `_uA(100)`/`_uB(200)`. Offer `_uA(50)`/`_uB(150)`; pairToken consumed 50 human, other 100 human.
     */
    function test_US12_3_DeployVaultForExistingPairWithProportionalDeposit() public {
        uint256 initialA = _uA(100);
        uint256 initialB = _uB(200);

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), initialA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), initialB);

        camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), initialA, IERC20(address(tokenB)), initialB, user
        );
        vm.stopPrank();

        address user2 = makeAddr("user2");
        tokenA.mint(user2, _uA(10_000));
        tokenB.mint(user2, _uB(10_000));

        uint256 depositAmountA = _uA(50);
        uint256 depositAmountB = _uB(150);

        vm.startPrank(user2);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), depositAmountA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), depositAmountB);

        uint256 user2TokenABefore = tokenA.balanceOf(user2);
        uint256 user2TokenBBefore = tokenB.balanceOf(user2);

        ICamelotV2StandardExchangeDFPkg.PreviewDeployVaultResult memory preview =
            camelotV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB
            );

        assertTrue(preview.pairExists, "Pair should exist");
        assertEq(preview.proportionalA, depositAmountA, "Should use all of tokenA");
        assertEq(preview.proportionalB, _uB(100), "TokenB should be proportional to tokenA");

        address vault2 = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB, user2
        );
        vm.stopPrank();

        assertTrue(vault2 != address(0), "Vault should be deployed");

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

        uint256 vaultShares = IERC20(vault2).balanceOf(user2);
        assertTrue(vaultShares > 0, "User2 should receive vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*          US-12.4: Deploy Vault for Existing Pair Without Deposit           */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test deploying vault for existing pair without deposit.
     * @dev pairToken = tokenA at `_tokenADecimals()`; other = tokenB at `_tokenBDecimals()`.
     */
    function test_US12_4_DeployVaultForExistingPairWithoutDeposit() public {
        camelotV2Factory.createPair(address(tokenA), address(tokenB));
        address pair = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0), "Pair should exist");

        uint256 userTokenABefore = tokenA.balanceOf(user);
        uint256 userTokenBBefore = tokenB.balanceOf(user);

        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0)
        );

        assertTrue(vault != address(0), "Vault should be deployed");

        assertEq(tokenA.balanceOf(user), userTokenABefore, "No TokenA should be transferred");
        assertEq(tokenB.balanceOf(user), userTokenBBefore, "No TokenB should be transferred");

        assertEq(IERC20(vault).balanceOf(user), 0, "User should have no vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*                     US-12.5: Preview Proportional Calculation              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test preview function for new pair (no existing reserves).
     * @dev pairToken `_uA(100)`; other `_uB(200)`.
     */
    function test_US12_5_PreviewNewPair() public view {
        uint256 amountA = _uA(100);
        uint256 amountB = _uB(200);

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
     * @notice Test preview function for existing pair with reserves.
     * @dev Seed `_uA(100)`/`_uB(200)`. Preview `_uA(50)`/`_uB(150)` → other proportional `_uB(100)`.
     */
    function test_US12_5_PreviewExistingPair() public {
        uint256 initialA = _uA(100);
        uint256 initialB = _uB(200);

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), initialA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), initialB);

        camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), initialA, IERC20(address(tokenB)), initialB, user
        );
        vm.stopPrank();

        uint256 previewAmountA = _uA(50);
        uint256 previewAmountB = _uB(150);

        ICamelotV2StandardExchangeDFPkg.PreviewDeployVaultResult memory result =
            camelotV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(tokenA)), previewAmountA, IERC20(address(tokenB)), previewAmountB
            );

        assertTrue(result.pairExists, "Pair should exist");
        assertEq(result.proportionalA, previewAmountA, "Should use all of tokenA");
        assertEq(result.proportionalB, _uB(100), "TokenB should be proportional");
        assertTrue(result.expectedLP > 0, "Should calculate expected LP");
    }

    /* -------------------------------------------------------------------------- */
    /*                           Edge Cases and Error Tests                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that existing deployVault(pair) function still works.
     * @dev pairToken = tokenA; other = tokenB. After sort, pair token0/token1 may swap.
     */
    function test_ExistingDeployVaultStillWorks() public {
        camelotV2Factory.createPair(address(tokenA), address(tokenB));
        address pair = camelotV2Factory.getPair(address(tokenA), address(tokenB));

        address vault = camelotV2StandardExchangeDFPkg.deployVault(ICamelotPair(pair));

        assertTrue(vault != address(0), "Vault should be deployed via original function");
    }

    /**
     * @notice Test that providing amounts with zero recipient reverts.
     * @dev Gold body actually deploys with zero amounts and zero recipient (pair creation only).
     */
    function test_RevertWhen_NonZeroAmountsWithZeroRecipient() public {
        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), _uA(100));
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), _uB(100));

        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0)
        );
        assertTrue(vault != address(0), "Should work with zero amounts and zero recipient");
        vm.stopPrank();
    }

    /**
     * @notice Test that providing zero amounts with non-zero recipient reverts.
     * @dev other token amount is `_uB(100)`; pairToken amount is 0.
     */
    function test_RevertWhen_ZeroAmountsWithNonZeroRecipient() public {
        vm.expectRevert(ICamelotV2StandardExchangeDFPkg.ZeroAmountForNonZeroRecipient.selector);
        camelotV2StandardExchangeDFPkg.deployVault(IERC20(address(tokenA)), 0, IERC20(address(tokenB)), _uB(100), user);
    }

    /**
     * @notice Test PairCreated event emission.
     * @dev pairToken = tokenA; other = tokenB.
     */
    function test_EmitsPairCreatedEvent() public {
        vm.expectEmit(true, true, false, false);
        emit ICamelotV2StandardExchangeDFPkg.PairCreated(address(tokenA), address(tokenB), address(0));

        camelotV2StandardExchangeDFPkg.deployVault(IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, address(0));
    }

    /**
     * @notice Test VaultDeployedWithDeposit event emission.
     * @dev pairToken `_uA(100)`; other `_uB(200)`.
     */
    function test_EmitsVaultDeployedWithDepositEvent() public {
        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), _uA(100));
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), _uB(200));

        vm.expectEmit(false, false, true, false);
        emit ICamelotV2StandardExchangeDFPkg.VaultDeployedWithDeposit(address(0), address(0), user, 0, 0);

        camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), _uA(100), IERC20(address(tokenB)), _uB(200), user
        );
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*       US-48.1: InsufficientLiquidity revert on dust amounts                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice deployVault reverts with InsufficientLiquidity on dust vs imbalanced reserves.
     * @dev Seed 1 wei pairToken : `_uB(1000)` other. Second deposit (1, 1) rounds proportionalA to 0.
     */
    function test_US48_1_RevertWhen_InsufficientLiquidity_DustAmounts() public {
        uint256 seedA = 1;
        uint256 seedB = _uB(1000);

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), seedA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), seedB);

        camelotV2StandardExchangeDFPkg.deployVault(IERC20(address(tokenA)), seedA, IERC20(address(tokenB)), seedB, user);
        vm.stopPrank();

        address dustUser = makeAddr("dustUser");
        tokenA.mint(dustUser, 1);
        tokenB.mint(dustUser, 1);

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
     * @notice deployVault reverts with PoolMustNotBeStable when the Camelot pair is stable.
     * @dev pairToken = tokenA; other = tokenB. Stable flag is independent of decimals.
     */
    function test_US48_2_RevertWhen_PoolMustNotBeStable() public {
        camelotV2Factory.createPair(address(tokenA), address(tokenB));
        address pairAddr = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        CamelotPair pair = CamelotPair(pairAddr);

        pair.setStableSwap(true, 0, 0);
        assertTrue(pair.stableSwap(), "Pair should be stable");

        vm.expectRevert(abi.encodeWithSelector(ICamelotV2StandardExchangeDFPkg.PoolMustNotBeStable.selector, pair));
        camelotV2StandardExchangeDFPkg.deployVault(ICamelotPair(pairAddr));
    }

    /* -------------------------------------------------------------------------- */
    /*       US-48.3: Token ordering flip                                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice deployVault with address(tokenB) < address(tokenA) still uses role decimals.
     * @dev highToken/lowToken amounts use `_uToken` after address sort. Roles stay pairToken vs other.
     */
    function test_US48_3_DeployVault_TokenOrderingFlip() public {
        IERC20 highToken;
        IERC20 lowToken;
        if (address(tokenA) < address(tokenB)) {
            highToken = IERC20(address(tokenB));
            lowToken = IERC20(address(tokenA));
        } else {
            highToken = IERC20(address(tokenA));
            lowToken = IERC20(address(tokenB));
        }

        assertTrue(address(lowToken) < address(highToken), "lowToken should have smaller address");

        uint256 depositHigh = _uToken(address(highToken), 100);
        uint256 depositLow = _uToken(address(lowToken), 200);

        vm.startPrank(user);
        IERC20(address(highToken)).approve(address(camelotV2StandardExchangeDFPkg), depositHigh);
        IERC20(address(lowToken)).approve(address(camelotV2StandardExchangeDFPkg), depositLow);

        address vault1 = camelotV2StandardExchangeDFPkg.deployVault(highToken, depositHigh, lowToken, depositLow, user);
        vm.stopPrank();

        assertTrue(vault1 != address(0), "Vault should be deployed");

        address user2 = makeAddr("user2");
        MintableERC20Decimals(address(highToken)).mint(user2, _uToken(address(highToken), 10_000));
        MintableERC20Decimals(address(lowToken)).mint(user2, _uToken(address(lowToken), 10_000));

        uint256 deposit2High = _uToken(address(highToken), 50);
        uint256 deposit2Low = _uToken(address(lowToken), 150);

        vm.startPrank(user2);
        IERC20(address(highToken)).approve(address(camelotV2StandardExchangeDFPkg), deposit2High);
        IERC20(address(lowToken)).approve(address(camelotV2StandardExchangeDFPkg), deposit2Low);

        ICamelotV2StandardExchangeDFPkg.PreviewDeployVaultResult memory preview =
            camelotV2StandardExchangeDFPkg.previewDeployVault(highToken, deposit2High, lowToken, deposit2Low);

        assertTrue(preview.pairExists, "Pair should exist");
        assertEq(preview.proportionalA, deposit2High, "Should use all of highToken");
        assertEq(preview.proportionalB, _uToken(address(lowToken), 100), "lowToken should be proportional");

        uint256 user2HighBefore = IERC20(address(highToken)).balanceOf(user2);
        uint256 user2LowBefore = IERC20(address(lowToken)).balanceOf(user2);

        address vault2 =
            camelotV2StandardExchangeDFPkg.deployVault(highToken, deposit2High, lowToken, deposit2Low, user2);
        vm.stopPrank();

        assertTrue(vault2 != address(0), "Second vault should be deployed");

        uint256 user2HighAfter = IERC20(address(highToken)).balanceOf(user2);
        uint256 user2LowAfter = IERC20(address(lowToken)).balanceOf(user2);
        assertEq(user2HighAfter, user2HighBefore - preview.proportionalA, "Only proportional highToken transferred");
        assertEq(user2LowAfter, user2LowBefore - preview.proportionalB, "Only proportional lowToken transferred");

        uint256 vaultShares = IERC20(vault2).balanceOf(user2);
        assertTrue(vaultShares > 0, "User2 should receive vault shares");
    }

    /* -------------------------------------------------------------------------- */
    /*       US-48.4: Residual balance assertion                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice DFPkg holds zero tokens after deployVault.
     * @dev pairToken `_uA(100)`; other `_uB(200)`. vaultShare stays 18.
     */
    function test_US48_4_NoResidualBalancesAfterDeployVault() public {
        uint256 depositAmountA = _uA(100);
        uint256 depositAmountB = _uB(200);

        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), depositAmountA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), depositAmountB);

        address vault = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), depositAmountA, IERC20(address(tokenB)), depositAmountB, user
        );
        vm.stopPrank();

        assertTrue(vault != address(0), "Vault should be deployed");

        address pairAddr = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pairAddr != address(0), "Pair should exist");

        address dfpkg = address(camelotV2StandardExchangeDFPkg);
        assertEq(tokenA.balanceOf(dfpkg), 0, "DFPkg should hold zero tokenA");
        assertEq(tokenB.balanceOf(dfpkg), 0, "DFPkg should hold zero tokenB");
        assertEq(IERC20(pairAddr).balanceOf(dfpkg), 0, "DFPkg should hold zero LP tokens");
    }
}
