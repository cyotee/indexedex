// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {
    UniV4DetfBondNftRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftRepo.sol";

/// @title UniV4DetfBondNftCommon
/// @notice Dual OOR liquidity + reward ledger helpers for bond NFT package.
abstract contract UniV4DetfBondNftCommon is IUnlockCallback, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;

    uint256 internal constant ONE_WAD = 1e18;

    enum Operation {
        AddLiquidity,
        RemoveLiquidity
    }

    struct OperationParams {
        Operation op;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bytes32 salt;
    }

    error InvalidCallbackCaller(address caller);

    function _s() internal pure returns (UniV4DetfBondNftRepo.Storage storage) {
        return UniV4DetfBondNftRepo._layout();
    }

    function _poolManager() internal view returns (IPoolManager) {
        return _s().poolManager;
    }

    function _poolKey() internal view returns (PoolKey memory) {
        return _s().poolKey;
    }

    function _updateGlobalRewards() internal {
        UniV4DetfBondNftRepo.Storage storage s = _s();
        uint256 bal = s.rewardToken.balanceOf(address(this));
        if (bal > s.lastRewardTokenBalance && s.totalShares > 0) {
            uint256 delta = bal - s.lastRewardTokenBalance;
            s.rewardPerShares += Math.mulDiv(delta, ONE_WAD, s.totalShares);
        }
        s.lastRewardTokenBalance = bal;
    }

    function _pendingRewards(uint256 tokenId) internal view returns (uint256) {
        UniV4DetfBondNftRepo.Storage storage s = _s();
        uint256 paid;
        uint256 shares;
        if (tokenId == 0) {
            paid = s.protocolRewardPerSharePaid;
            shares = s.protocolEffectiveShares;
        } else {
            UniV4DetfBondNftRepo.BondPosition storage p = s.positions[tokenId];
            if (!p.active) return 0;
            paid = p.userRewardPerSharePaid;
            shares = p.effectiveShares;
        }
        if (shares == 0) return 0;
        uint256 rps = s.rewardPerShares;
        // Include unaccounted balance for view.
        uint256 bal = s.rewardToken.balanceOf(address(this));
        if (bal > s.lastRewardTokenBalance && s.totalShares > 0) {
            rps += Math.mulDiv(bal - s.lastRewardTokenBalance, ONE_WAD, s.totalShares);
        }
        if (rps <= paid) return 0;
        return Math.mulDiv(shares, rps - paid, ONE_WAD);
    }

    function _harvest(uint256 tokenId, address recipient) internal returns (uint256 rewards) {
        _updateGlobalRewards();
        UniV4DetfBondNftRepo.Storage storage s = _s();
        rewards = _pendingRewards(tokenId);
        if (tokenId == 0) {
            s.protocolRewardPerSharePaid = s.rewardPerShares;
        } else {
            s.positions[tokenId].userRewardPerSharePaid = s.rewardPerShares;
        }
        if (rewards > 0) {
            s.rewardToken.safeTransfer(recipient, rewards);
            s.lastRewardTokenBalance = s.rewardToken.balanceOf(address(this));
        }
    }

    /* ----------------------------- unlock ops ----------------------------- */

    function _executeUnlock(OperationParams memory params) internal {
        _poolManager().unlock(abi.encode(params));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(_poolManager())) revert InvalidCallbackCaller(msg.sender);
        OperationParams memory params = abi.decode(data, (OperationParams));
        BalanceDelta delta;
        if (params.op == Operation.AddLiquidity) {
            (delta,) = _poolManager().modifyLiquidity(
                _poolKey(),
                ModifyLiquidityParams({
                    tickLower: params.tickLower,
                    tickUpper: params.tickUpper,
                    liquidityDelta: int256(uint256(params.liquidity)),
                    salt: params.salt
                }),
                bytes("")
            );
        } else {
            (delta,) = _poolManager().modifyLiquidity(
                _poolKey(),
                ModifyLiquidityParams({
                    tickLower: params.tickLower,
                    tickUpper: params.tickUpper,
                    liquidityDelta: -int256(uint256(params.liquidity)),
                    salt: params.salt
                }),
                bytes("")
            );
        }
        _settleDelta(delta);
        return abi.encode(delta);
    }

    function _settleDelta(BalanceDelta delta) internal {
        PoolKey memory key = _poolKey();
        int128 a0 = delta.amount0();
        int128 a1 = delta.amount1();
        if (a0 < 0) _settle(key.currency0, uint128(-a0));
        else if (a0 > 0) _poolManager().take(key.currency0, address(this), uint128(a0));
        if (a1 < 0) _settle(key.currency1, uint128(-a1));
        else if (a1 > 0) _poolManager().take(key.currency1, address(this), uint128(a1));
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager().sync(currency);
        currency.transfer(address(_poolManager()), amount);
        _poolManager().settle();
    }

    function _addSingleSided(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        bytes32 salt
    ) internal {
        (uint160 sqrtP, int24 tick,,) = StateLibrary.getSlot0(_poolManager(), _s().poolId);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            amount0,
            amount1
        );
        if (liq == 0) return;
        // silence unused tick
        tick;
        _executeUnlock(
            OperationParams({
                op: Operation.AddLiquidity, tickLower: tickLower, tickUpper: tickUpper, liquidity: liq, salt: salt
            })
        );
    }

    function _removeAllLiquidity(int24 tickLower, int24 tickUpper, bytes32 salt) internal {
        (uint128 liq,,) = StateLibrary.getPositionInfo(
            _poolManager(), _s().poolId, address(this), tickLower, tickUpper, salt
        );
        if (liq == 0) return;
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity, tickLower: tickLower, tickUpper: tickUpper, liquidity: liq, salt: salt
            })
        );
    }
}
