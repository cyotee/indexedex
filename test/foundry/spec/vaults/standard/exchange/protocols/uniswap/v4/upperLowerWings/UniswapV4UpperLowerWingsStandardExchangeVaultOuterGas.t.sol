// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";

/// @notice Call-gas plus a documented intrinsic estimate. Not a live chain receipt.
contract UniswapV4UpperLowerWingsStandardExchangeVaultOuterGasTest is Fixture {
    uint256 internal constant TX_CAP = 16_777_216;
    uint256 internal constant ACCEPTANCE = TX_CAP * 90 / 100;

    function test_requiredRoutesFitPortableTransactionCap() public {
        uint256 depositGas = _measure(abi.encodeCall(
            IStandardExchangeIn.exchangeIn, (token0, 1e12, IERC20(address(wings0)), 1e12, address(this), false, block.timestamp)));
        uint256 rebalanceGas = _measure(abi.encodeCall(Rebalance.rebalance, (0, block.timestamp)));
        uint256 quoteGas = _measureView();
        uint256 redeemGas = _measure(abi.encodeCall(
            IStandardExchangeIn.exchangeIn, (IERC20(address(wings0)), 1e9, token0, 0, address(this), false, block.timestamp)));
        emit log_named_uint("deposit estimated outer gas", depositGas);
        emit log_named_uint("quote estimated outer gas", quoteGas);
        emit log_named_uint("partial redeem estimated outer gas", redeemGas);
        emit log_named_uint("rebalance estimated outer gas", rebalanceGas);
        emit log_named_uint("acceptance ceiling", ACCEPTANCE);
        assertLe(depositGas, ACCEPTANCE, "deposit exceeds 90% of EIP-7825 cap");
        assertLe(quoteGas, ACCEPTANCE, "quote exceeds 90% of EIP-7825 cap");
        assertLe(redeemGas, ACCEPTANCE, "redeem exceeds 90% of EIP-7825 cap");
        assertLe(rebalanceGas, ACCEPTANCE, "rebalance exceeds 90% of EIP-7825 cap");
    }

    function _measure(bytes memory callData_) private returns (uint256) {
        uint256 before = gasleft();
        (bool success, bytes memory result) = address(wings0).call(callData_);
        uint256 used = before - gasleft();
        if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return used + 21_000 + callData_.length * 16 + 7_800;
    }
    function _measureView() private view returns (uint256) {
        uint256 before = gasleft();
        wings0.liquidationValue();
        return before - gasleft() + 21_000 + 4 * 16 + 2_600;
    }
}
