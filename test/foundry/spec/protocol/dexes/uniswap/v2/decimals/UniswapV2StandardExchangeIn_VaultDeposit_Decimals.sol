// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_Decimals.sol";

/**
 * @title UniswapV2StandardExchangeIn_VaultDeposit_Decimals
 * @notice Route 4 LP→vaultShare deposit on combo decimals. vaultShare stays 18.
 */
abstract contract UniswapV2StandardExchangeIn_VaultDeposit_Decimals is TestBase_UniswapV2StandardExchange_Decimals {
    function test_Route4VaultDeposit_execVsPreview_balanced() public {
        _test_execVsPreview(PoolConfig.Balanced);
    }

    function test_Route4VaultDeposit_execVsPreview_unbalanced() public {
        _test_execVsPreview(PoolConfig.Unbalanced);
    }

    function test_Route4VaultDeposit_execVsPreview_extreme() public {
        _test_execVsPreview(PoolConfig.Extreme);
    }

    function _test_execVsPreview(PoolConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IUniswapV2Pair pair = _getPool(config);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");

        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Execution should match preview");
        assertEq(vault.balanceOf(recipient), preview, "Recipient should receive preview shares");
    }

    /// @notice R4: convert against pre-deposit reserve; preview ≡ execute.
    function test_R4_previewEqualsExecute_route4() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        address recipient = makeAddr("r4PreviewRecipient");

        lpToken.approve(address(vault), lpAmount);
        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertEq(sharesOut, preview, "R4: preview == execute against pre-deposit reserve");
        assertEq(vault.balanceOf(recipient), sharesOut, "R4 recipient shares");
    }
}
