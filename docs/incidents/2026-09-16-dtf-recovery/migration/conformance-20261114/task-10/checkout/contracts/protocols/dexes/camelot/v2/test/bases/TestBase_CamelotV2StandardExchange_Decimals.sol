// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_CamelotV2StandardExchange} from
    "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title TestBase_CamelotV2StandardExchange_Decimals
 * @notice Combo-decimal helpers. Gold TestBase does not construct pair tokens.
 *         pairToken = tokenA. vaultShare stays 18.
 * @dev After Camelot pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 */
abstract contract TestBase_CamelotV2StandardExchange_Decimals is TestBase_CamelotV2StandardExchange {
    /// @notice Dust floor for LP slices. Gold uses 1e15; 6-dec geometric LP can be ~1e9.
    uint256 internal constant MIN_TEST_AMOUNT = 1e3;

    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }

    /// @dev Raw units of an arbitrary pool token (use after pair sort). Not for LP or vaultShare.
    function _uToken(address token, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(MintableERC20Decimals(token).decimals()));
    }
}
