// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

interface IUniswapV4FullSpreadPonsFamilyHookRegistration {
    struct LaunchInfo {
        bool registered;
        bool memecoinIsCurrency0;
        address memecoin;
        address quoteToken;
        address creator;
        address buybackCreatorRecipient;
        address protocolFeeRecipient;
        uint16 creatorTaxBps;
        uint16 protocolFeeShareBps;
        uint16 buybackBurnBps;
        uint16 hookFeeBps;
        uint16 maxInternalPriceImpactBps;
        bool buybackEnabled;
    }

    function poolManager() external view returns (IPoolManager);
    function launches(bytes32 poolId) external view returns (LaunchInfo memory);
}

// tag::UniswapV4FullSpreadPonsFamilyHookFeeService[]
/// @notice Decodes the fixed singleton's per-launch terms, never its mutable defaults.
library UniswapV4FullSpreadPonsFamilyHookFeeService {
    using PoolIdLibrary for PoolKey;

    function _terms(IPoolManager manager_, PoolKey memory key_)
        internal view returns (bool valid_, uint16 hookFeeBps_, uint16 creatorTaxBps_)
    {
        if (key_.fee != 0 || address(key_.hooks).code.length == 0) return (false, 0, 0);
        (bool ok, bytes memory data) = address(key_.hooks).staticcall(
            abi.encodeCall(IUniswapV4FullSpreadPonsFamilyHookRegistration.poolManager, ())
        );
        if (!ok || data.length != 32 || abi.decode(data, (address)) != address(manager_)) return (false, 0, 0);
        (ok, data) = address(key_.hooks).staticcall(
            abi.encodeCall(IUniswapV4FullSpreadPonsFamilyHookRegistration.launches, (PoolId.unwrap(key_.toId())))
        );
        if (!ok || data.length != 13 * 32) return (false, 0, 0);
        IUniswapV4FullSpreadPonsFamilyHookRegistration.LaunchInfo memory info =
            abi.decode(data, (IUniswapV4FullSpreadPonsFamilyHookRegistration.LaunchInfo));
        valid_ = info.registered && info.memecoin != address(0)
            && info.memecoin == Currency.unwrap(info.memecoinIsCurrency0 ? key_.currency0 : key_.currency1)
            && info.quoteToken == Currency.unwrap(info.memecoinIsCurrency0 ? key_.currency1 : key_.currency0)
            && info.hookFeeBps <= 1_000 && uint256(info.hookFeeBps) + info.creatorTaxBps <= 2_000;
        return (valid_, info.hookFeeBps, info.creatorTaxBps);
    }

    function _charge(uint256 amount_, uint16 hookFeeBps_, uint16 creatorTaxBps_) internal pure returns (uint256) {
        return Math.mulDiv(amount_, hookFeeBps_, 10_000) + Math.mulDiv(amount_, creatorTaxBps_, 10_000);
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookFeeService[]
