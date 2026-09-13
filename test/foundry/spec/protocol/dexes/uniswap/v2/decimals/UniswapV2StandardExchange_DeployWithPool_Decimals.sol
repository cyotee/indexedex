// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/IUniswapV2StandardExchangeDFPkg.sol";
import {
    TestBase_UniswapV2StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_Decimals.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title UniswapV2StandardExchange_DeployWithPool_Decimals
 * @notice US-13 deployVault money paths on combo decimals. pairToken = testTokenA.
 * @dev After Uniswap pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 */
abstract contract UniswapV2StandardExchange_DeployWithPool_Decimals is TestBase_UniswapV2StandardExchange_Decimals {
    MintableERC20Decimals internal testTokenA;
    MintableERC20Decimals internal testTokenB;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public virtual override {
        super.setUp();

        testTokenA = new MintableERC20Decimals("Test Token A", "TTA", _tokenADecimals());
        testTokenB = new MintableERC20Decimals("Test Token B", "TTB", _tokenBDecimals());
        vm.label(address(testTokenA), "pairToken-testTokenA");
        vm.label(address(testTokenB), "otherToken-testTokenB");

        testTokenA.mint(alice, _uA(1000));
        testTokenB.mint(alice, _uB(1000));

        vm.startPrank(alice);
        testTokenA.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @notice US-13.1: deployVault(tokenA, 0, tokenB, 0, address(0)) creates pair and vault without deposit.
     * @dev pairToken = testTokenA at `_tokenADecimals()`; other = testTokenB at `_tokenBDecimals()`.
     */
    function test_US13_1_CreateNewPairAndVaultWithoutDeposit() public {
        address pairBefore = uniswapV2Factory.getPair(address(testTokenA), address(testTokenB));
        assertEq(pairBefore, address(0), "Pair should not exist before");

        vm.prank(alice);
        address vault = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 0, IERC20(address(testTokenB)), 0, address(0)
        );

        address pairAfter = uniswapV2Factory.getPair(address(testTokenA), address(testTokenB));
        assertTrue(pairAfter != address(0), "Pair should exist after");
        assertTrue(vault != address(0), "Vault should be deployed");
        assertEq(IERC20(vault).balanceOf(alice), 0, "Alice should have no vault shares");
    }

    /**
     * @notice US-13.2: deployVault with amounts creates pair liquidity; recipient gets vaultShare (18-dec).
     * @dev pairToken amount is `_uA(100)`; other is `_uB(200)`.
     */
    function test_US13_2_CreatePairWithInitialDeposit() public {
        uint256 amountA = _uA(100);
        uint256 amountB = _uB(200);

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        vm.prank(alice);
        address vault = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), amountA, IERC20(address(testTokenB)), amountB, bob
        );

        address pairAddr = uniswapV2Factory.getPair(address(testTokenA), address(testTokenB));
        assertTrue(pairAddr != address(0), "Pair should exist");

        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0, "Pair should have reserves");

        assertEq(testTokenA.balanceOf(alice), aliceTokenABefore - amountA, "pairToken should be transferred");
        assertEq(testTokenB.balanceOf(alice), aliceTokenBBefore - amountB, "other token should be transferred");

        uint256 bobShares = IERC20(vault).balanceOf(bob);
        assertTrue(bobShares > 0, "Bob should have vault shares");
        assertEq(IERC20(vault).balanceOf(alice), 0, "Alice should have no vault shares");
    }

    /**
     * @notice Recipient is required when amounts are provided.
     * @dev pairToken `_uA(100)` + other `_uB(200)` with recipient 0 reverts.
     */
    function test_US13_2_RevertWhenRecipientZeroWithDeposit() public {
        vm.prank(alice);
        vm.expectRevert(IUniswapV2StandardExchangeDFPkg.RecipientRequiredForDeposit.selector);
        uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(200), address(0)
        );
    }

    /**
     * @notice US-13.3: existing pair uses proportional raw amounts (1:1 human seed).
     * @dev Seed `_uA(100)`/`_uB(100)`. Offer `_uA(50)`/`_uB(200)`; both legs consume 50 human.
     */
    function test_US13_3_ExistingPairWithProportionalDeposit() public {
        vm.startPrank(alice);
        address vault1 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(100), alice
        );
        vm.stopPrank();

        testTokenA.mint(alice, _uA(1000));
        testTokenB.mint(alice, _uB(1000));

        vm.startPrank(alice);
        testTokenA.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        testTokenB.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        vm.stopPrank();

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        vm.prank(alice);
        address vault2 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), _uA(50), IERC20(address(testTokenB)), _uB(200), bob
        );

        assertEq(vault1, vault2, "Should be same vault for same pair");

        uint256 aliceTokenAAfter = testTokenA.balanceOf(alice);
        uint256 aliceTokenBAfter = testTokenB.balanceOf(alice);

        assertEq(aliceTokenABefore - aliceTokenAAfter, _uA(50), "Should use all provided pairToken");
        assertEq(aliceTokenBBefore - aliceTokenBAfter, _uB(50), "Should only use proportional other token");
    }

    /**
     * @notice US-13.4: deployVault(tokenA, 0, tokenB, 0, address(0)) for existing pair.
     */
    function test_US13_4_ExistingPairWithoutDeposit() public {
        vm.prank(alice);
        address vault1 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(100), alice
        );

        uint256 aliceTokenABefore = testTokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = testTokenB.balanceOf(alice);

        vm.prank(bob);
        address vault2 = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), 0, IERC20(address(testTokenB)), 0, address(0)
        );

        assertEq(vault1, vault2, "Should be same vault for same pair");
        assertEq(testTokenA.balanceOf(alice), aliceTokenABefore, "No pairToken transfer");
        assertEq(testTokenB.balanceOf(alice), aliceTokenBBefore, "No other token transfer");
    }

    /**
     * @notice US-13.5: previewDeployVault returns pairExists=false for new pair.
     * @dev Full `_uA(100)` / `_uB(200)` used.
     */
    function test_US13_5_PreviewNewPair() public view {
        IUniswapV2StandardExchangeDFPkg.DeployWithPoolResult memory result =
            uniswapV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(200)
            );

        assertFalse(result.pairExists, "Pair should not exist");
        assertEq(result.proportionalA, _uA(100), "Should use full pairToken amount");
        assertEq(result.proportionalB, _uB(200), "Should use full other amount");
        assertTrue(result.expectedLP > 0, "Expected LP should be positive");
    }

    /**
     * @notice US-13.5: previewDeployVault calculates proportional amounts for existing pair.
     */
    function test_US13_5_PreviewExistingPair() public {
        vm.prank(alice);
        uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(testTokenA)), _uA(100), IERC20(address(testTokenB)), _uB(100), alice
        );

        IUniswapV2StandardExchangeDFPkg.DeployWithPoolResult memory result =
            uniswapV2StandardExchangeDFPkg.previewDeployVault(
                IERC20(address(testTokenA)), _uA(50), IERC20(address(testTokenB)), _uB(200)
            );

        assertTrue(result.pairExists, "Pair should exist");
        assertEq(result.proportionalA, _uA(50), "Should use full pairToken amount");
        assertEq(result.proportionalB, _uB(50), "Should use proportional other amount");
        assertTrue(result.expectedLP > 0, "Expected LP should be positive");
    }

    /**
     * @notice Existing deployVault(pair) still works for the combo pair.
     */
    function test_ExistingDeployVaultPairStillWorks() public {
        address pairAddr = uniswapV2Factory.createPair(address(testTokenA), address(testTokenB));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);

        address vault = uniswapV2StandardExchangeDFPkg.deployVault(pair);
        assertTrue(vault != address(0), "Vault should be deployed");
    }
}
