// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    AddLiquidityKind,
    RemoveLiquidityKind,
    AddLiquidityParams,
    RemoveLiquidityParams
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {StandardExchangeBufferHookTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol";

/// @dev Records Vault interactions in observation order.
contract MockBalancerV3Vault {
    enum Sel { SEND_TO, SETTLE, ADD_LIQUIDITY, REMOVE_LIQUIDITY }

    Sel[] public observed;
    bytes[] public payloads;
    uint256 public scriptedSettleReturn;

    function setScriptedSettleReturn(uint256 v) external { scriptedSettleReturn = v; }

    function sendTo(IERC20 token, address to, uint256 amount) external {
        observed.push(Sel.SEND_TO);
        payloads.push(abi.encode(token, to, amount));
    }

    function settle(IERC20 token, uint256 amountHint) external returns (uint256) {
        observed.push(Sel.SETTLE);
        payloads.push(abi.encode(token, amountHint));
        return scriptedSettleReturn;
    }

    function addLiquidity(AddLiquidityParams memory p)
        external
        returns (uint256[] memory, uint256, bytes memory)
    {
        observed.push(Sel.ADD_LIQUIDITY);
        payloads.push(abi.encode(p));
        return (p.maxAmountsIn, 0, "");
    }

    function removeLiquidity(RemoveLiquidityParams memory p)
        external
        returns (uint256, uint256[] memory, bytes memory)
    {
        observed.push(Sel.REMOVE_LIQUIDITY);
        payloads.push(abi.encode(p));
        return (0, p.minAmountsOut, "");
    }

    function observedCount() external view returns (uint256) { return observed.length; }

    /// @dev Stubs the static-swap-fee getter the hook reads in `onBeforeSwap`. Returns 0 by default
    /// (no fee applied) so unit tests can compute exact CP math without fee adjustments. Override via
    /// `setStaticSwapFee` if a non-zero fee is needed.
    uint256 public scriptedStaticSwapFee;
    function setStaticSwapFee(uint256 v) external { scriptedStaticSwapFee = v; }
    function getStaticSwapFeePercentage(address) external view returns (uint256) { return scriptedStaticSwapFee; }
}

/// @dev Mock that implements IStandardExchange with scripted return values.
contract MockStandardExchange is IStandardExchange {
    uint256 public scriptedPreview;
    uint256 public scriptedAmountOut;
    uint256 public scriptedAmountIn;

    function setPreview(uint256 v) external { scriptedPreview = v; }
    function setAmountOut(uint256 v) external { scriptedAmountOut = v; }
    function setAmountIn(uint256 v) external { scriptedAmountIn = v; }

    // IStandardExchangeIn
    function previewExchangeIn(IERC20, uint256, IERC20) external pure returns (uint256) { return 0; }
    function exchangeIn(IERC20, uint256, IERC20, uint256, address, bool, uint256) external view returns (uint256) {
        return scriptedAmountIn;
    }

    // IStandardExchangeOut
    function previewExchangeOut(IERC20, IERC20, uint256) external view returns (uint256) {
        return scriptedPreview;
    }
    function exchangeOut(IERC20, uint256, IERC20, uint256, address, bool, uint256) external view returns (uint256) {
        return scriptedAmountOut;
    }
}

contract StaticRateProvider is IRateProvider {
    uint256 immutable R;
    constructor(uint256 r) { R = r; }
    function getRate() external view returns (uint256) { return R; }
}

/// @dev Concrete harness that wires the abstract hook target to mock infrastructure.
contract HookHarness is StandardExchangeBufferHookTarget {
    address public immutable VAULT;
    address public immutable FACTORY;

    constructor(address v, address f, IERC20 tta, IERC20 sh, IStandardExchange sev, IRateProvider rp) {
        VAULT = v;
        FACTORY = f;
        Repo._initialize(tta, sh, sev, rp, 0, 1, f);
    }

    function _balancerV3Vault() internal view override returns (address) { return VAULT; }
    function _expectedFactory() internal view override returns (address) { return FACTORY; }

    function setVirtualTTA(uint256 v) external { Repo._setVirtualTTA(v); }
    function setHookSharesDelta(int256 v) external { Repo._setHookSharesDelta(v); }
    function virtualTTA() external view returns (uint256) { return Repo._virtualTTA(); }
    function hookSharesDelta() external view returns (int256) { return Repo._hookSharesDelta(); }
}
