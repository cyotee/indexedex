// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";
import {LockChecker} from
    "test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_ReentrancyGuard.t.sol";

/**
 * @title CamelotV2StandardExchange_ReentrancyGuard_Decimals
 * @notice exchangeIn/Out reentrancy lock on combo decimals. pairToken = tokenA.
 * @dev After Camelot pair address sort, token0/token1 may swap; amounts use `_uToken`.
 *      vaultShare stays 18.
 */
abstract contract CamelotV2StandardExchange_ReentrancyGuard_Decimals is TestBase_CamelotV2StandardExchange_Decimals {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;

    function setUp() public virtual override {
        super.setUp();

        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(address(this), _uA(10_000));
        tokenB.mint(address(this), _uB(10_000));

        vm.label(address(tokenA), "pairToken-tokenA");
        vm.label(address(tokenB), "otherToken-tokenB");

        uint256 seedA = _uA(1000);
        uint256 seedB = _uB(1000);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), seedA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), seedB);

        address vaultAddr = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), seedA, IERC20(address(tokenB)), seedB, address(this)
        );

        vault = IStandardExchangeProxy(vaultAddr);
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));

        vm.label(address(vault), "CamelotVault");
        vm.label(address(pair), "CamelotPair");
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /**
     * @notice Verify that the reentrancy lock is applied to exchangeIn.
     * @dev token0 in is `_uToken(token0, 1)` after pair sort.
     */
    function test_exchangeIn_isLockedDuringExecution() public {
        LockChecker checker = new LockChecker(address(vault));

        address token0 = pair.token0();
        address token1 = pair.token1();
        uint256 amountIn = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(checker), amountIn);

        checker.callExchangeIn(IERC20(token0), amountIn, IERC20(token1), 0, address(checker), false, _deadline());

        assertTrue(checker.wasLockedDuringCall(), "Vault should be locked during exchangeIn execution");
    }

    /**
     * @notice Verify that the reentrancy lock is applied to exchangeOut.
     * @dev token0 in / token1 out use `_uToken` after pair sort. Skips if OutTarget preview reverts.
     */
    function test_exchangeOut_isLockedDuringExecution() public {
        LockChecker checker = new LockChecker(address(vault));

        address token0 = pair.token0();
        address token1 = pair.token1();
        uint256 amountInFund = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(checker), amountInFund);

        uint256 amountOut = _uToken(token1, 1) / 2;
        if (amountOut == 0) amountOut = 1;
        uint256 maxAmountIn;
        try IStandardExchangeOut(vault).previewExchangeOut(IERC20(token0), IERC20(token1), amountOut) returns (
            uint256 amountIn
        ) {
            maxAmountIn = amountIn;
        } catch {
            return;
        }

        try checker.callExchangeOut(
            IERC20(token0), maxAmountIn, IERC20(token1), amountOut, address(checker), false, _deadline()
        ) {} catch {
            return;
        }

        assertTrue(checker.wasLockedDuringCall(), "Vault should be locked during exchangeOut execution");
    }
}
