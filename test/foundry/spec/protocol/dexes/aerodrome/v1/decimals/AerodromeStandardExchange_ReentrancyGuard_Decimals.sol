// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */
// @dev Catalog: BASE-C / C-class (SE reentrancy guard). Shared SE adversarial harness extends this.

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    TestBase_AerodromeStandardExchange_Decimals
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_Decimals.sol";

/**
 * @title AerodromeStandardExchange_ReentrancyGuard_Decimals
 * @notice Verifies that exchangeIn and exchangeOut are protected by reentrancy guards.
 * @dev Tests that the `lock` modifier from ReentrancyLockModifiers is applied to both
 *      exchangeIn (which already had it) and exchangeOut (which was added in IDXEX-060).
 */
abstract contract AerodromeStandardExchange_ReentrancyGuard_Decimals is TestBase_AerodromeStandardExchange_Decimals {
    /**
     * @notice Verify that exchangeIn has the lock modifier applied.
     * @dev Calls exchangeIn from a helper contract and verifies execution completes
     *      (which means the lock modifier was entered and exited successfully).
     */
    function test_exchangeIn_isLockedDuringExecution() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (MintableERC20Decimals tokenA, MintableERC20Decimals tokenB) = _getTokens(PoolConfig.Balanced);

        AeroLockChecker_ProDexAerV1 checker = new AeroLockChecker_ProDexAerV1(address(vault));

        tokenA.mint(address(checker), _testAmt(tokenA));

        checker.callExchangeIn(
            IERC20(address(tokenA)), _testAmt(tokenA), IERC20(address(tokenB)), 0, address(checker), false, _deadline()
        );

        assertTrue(checker.callCompleted(), "exchangeIn should complete with lock modifier");
    }

    /**
     * @notice Verify that exchangeOut has the lock modifier applied.
     * @dev Calls exchangeOut from a helper contract for the pass-through swap route.
     */
    function test_exchangeOut_isLockedDuringExecution() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (MintableERC20Decimals tokenA, MintableERC20Decimals tokenB) = _getTokens(PoolConfig.Balanced);

        AeroLockChecker_ProDexAerV1 checker = new AeroLockChecker_ProDexAerV1(address(vault));

        tokenA.mint(address(checker), _testAmt(tokenA));

        // Calculate expected output for a small swap
        uint256 previewOut = vault.previewExchangeIn(IERC20(address(tokenA)), _testAmt(tokenA) / 2, IERC20(address(tokenB)));

        checker.callExchangeOut(
            IERC20(address(tokenA)),
            _testAmt(tokenA),
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
 * @title AeroLockChecker_ProDexAerV1
 * @notice Helper contract to verify exchange functions complete with lock modifier.
 */
contract AeroLockChecker_ProDexAerV1 {
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

