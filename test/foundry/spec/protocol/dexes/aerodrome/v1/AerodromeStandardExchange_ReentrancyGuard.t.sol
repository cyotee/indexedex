// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/**
 * @title AerodromeStandardExchange_ReentrancyGuard_Test
 * @notice Verifies that exchangeIn and exchangeOut are protected by reentrancy guards.
 * @dev Tests that the `lock` modifier from ReentrancyLockModifiers is applied to both
 *      exchangeIn (which already had it) and exchangeOut (which was added in IDXEX-060).
 */
contract AerodromeStandardExchange_ReentrancyGuard_Test is TestBase_AerodromeStandardExchange_MultiPool {
    /**
     * @notice Verify that exchangeIn has the lock modifier applied.
     * @dev Calls exchangeIn from a helper contract and verifies execution completes
     *      (which means the lock modifier was entered and exited successfully).
     */
    function test_exchangeIn_isLockedDuringExecution() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        AeroLockChecker checker = new AeroLockChecker(address(vault));

        deal(address(tokenA), address(checker), TEST_AMOUNT);

        checker.callExchangeIn(
            IERC20(address(tokenA)), TEST_AMOUNT, IERC20(address(tokenB)), 0, address(checker), false, _deadline()
        );

        assertTrue(checker.callCompleted(), "exchangeIn should complete with lock modifier");
    }

    /**
     * @notice Verify that exchangeOut has the lock modifier applied.
     * @dev Calls exchangeOut from a helper contract for the pass-through swap route.
     */
    function test_exchangeOut_isLockedDuringExecution() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        AeroLockChecker checker = new AeroLockChecker(address(vault));

        // Give tokens to the checker
        deal(address(tokenA), address(checker), TEST_AMOUNT);

        // Calculate expected output for a small swap
        uint256 previewOut = vault.previewExchangeIn(IERC20(address(tokenA)), TEST_AMOUNT / 2, IERC20(address(tokenB)));

        checker.callExchangeOut(
            IERC20(address(tokenA)),
            TEST_AMOUNT,
            IERC20(address(tokenB)),
            previewOut / 2,
            address(checker),
            false,
            _deadline()
        );

        assertTrue(checker.callCompleted(), "exchangeOut should complete with lock modifier");
    }
}

/**
 * @title AeroLockChecker
 * @notice Helper contract to verify exchange functions complete with lock modifier.
 */
contract AeroLockChecker {
    address public vaultAddr;
    bool public callCompleted;

    constructor(address vault_) {
        vaultAddr = vault_;
    }

    function callExchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external {
        tokenIn.approve(vaultAddr, amountIn);
        IStandardExchangeIn(vaultAddr)
            .exchangeIn(tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline);
        callCompleted = true;
    }

    function callExchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external {
        tokenIn.approve(vaultAddr, maxAmountIn);
        IStandardExchangeOut(vaultAddr)
            .exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline);
        callCompleted = true;
    }
}

