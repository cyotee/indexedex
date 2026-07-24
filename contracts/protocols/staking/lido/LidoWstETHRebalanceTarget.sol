// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IWstETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IWstETH.sol";
import {IStETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IStETH.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {ILidoWstETHRebalance} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {ILidoWithdrawalQueue} from "contracts/protocols/staking/lido/interfaces/ILidoWithdrawalQueue.sol";
import {LidoWstETHStandardExchangeCommon} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol";
import {LidoWstETHStandardExchangeRepo} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeRepo.sol";

/**
 * @title LidoWstETHRebalanceTarget
 * @notice Claim+wrap, stake excess liquid, queue deficit toward oracle liquid target.
 */
contract LidoWstETHRebalanceTarget is LidoWstETHStandardExchangeCommon, ReentrancyLockModifiers, ILidoWstETHRebalance {
    using SafeERC20 for IERC20;

    receive() external payable {}

    function rebalance() external nonReentrant {
        _claimAndWrap();
        uint256 target = _targetLiquidEth();
        uint256 liquid = liquidReserveEth();
        uint256 band = (target * REBALANCE_BAND_WAD) / ONE_WAD;

        if (liquid > target + band) {
            _stakeExcess(liquid - target);
        } else if (liquid + band < target) {
            _queueDeficit(target - liquid);
        }
    }

    function _claimAndWrap() internal {
        uint256[] memory ids = LidoWstETHStandardExchangeRepo._requestIds();
        ILidoWithdrawalQueue queue = ILidoWithdrawalQueue(withdrawalQueue());
        if (address(queue) == address(0)) return;

        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (!LidoWstETHStandardExchangeRepo._isTrackedRequest(id)) continue;
            if (!queue.isFinalized(id) || queue.isClaimed(id)) continue;
            uint256 beforeEth = address(this).balance;
            queue.claimWithdrawal(id);
            uint256 got = address(this).balance - beforeEth;
            LidoWstETHStandardExchangeRepo._clearRequest(id);
            if (got > 0) {
                IWETH(payable(weth())).deposit{value: got}();
            }
        }
    }

    function _stakeExcess(uint256 wethAmount) internal {
        if (wethAmount == 0) return;
        address weth_ = weth();
        address st_ = stETH();
        address wst_ = wstETH();

        IWETH(payable(weth_)).withdraw(wethAmount);
        uint256 shares = IStETH(st_).submit{value: wethAmount}(address(0));
        uint256 stBal = IERC20(st_).balanceOf(address(this));
        if (stBal == 0 && shares > 0) {
            // no-op; hermetic may mint face
        }
        stBal = IERC20(st_).balanceOf(address(this));
        if (stBal == 0) return;
        IERC20(st_).forceApprove(wst_, stBal);
        IWstETH(wst_).wrap(stBal);
    }

    function _queueDeficit(uint256 ethDeficit) internal {
        if (ethDeficit == 0) return;
        ILidoWithdrawalQueue queue = ILidoWithdrawalQueue(withdrawalQueue());
        if (address(queue) == address(0) || queue.isPaused()) return;

        address wst_ = wstETH();
        uint256 remaining = ethDeficit;
        uint256 n;
        while (remaining > 0 && n < MAX_QUEUE_REQUESTS_PER_REBALANCE) {
            uint256 chunk = remaining > MAX_STETH_WITHDRAWAL ? MAX_STETH_WITHDRAWAL : remaining;
            if (chunk < MIN_STETH_WITHDRAWAL) break;

            uint256 wstNeeded = IWstETH(wst_).getWstETHByStETH(chunk);
            uint256 wstBal = IERC20(wst_).balanceOf(address(this));
            if (wstBal < wstNeeded) {
                if (wstBal == 0) break;
                wstNeeded = wstBal;
                chunk = IWstETH(wst_).getStETHByWstETH(wstNeeded);
                if (chunk < MIN_STETH_WITHDRAWAL) break;
            }

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = wstNeeded;
            IERC20(wst_).forceApprove(address(queue), wstNeeded);
            uint256[] memory ids = queue.requestWithdrawalsWstETH(amounts, address(this));
            LidoWstETHStandardExchangeRepo._trackRequest(ids[0], chunk);
            remaining -= chunk;
            unchecked {
                ++n;
            }
        }
    }
}
