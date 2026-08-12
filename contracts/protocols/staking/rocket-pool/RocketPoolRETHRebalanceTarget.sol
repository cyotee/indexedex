// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IRETH} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRETH.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {
    IRocketPoolRETHRebalance
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {
    RocketPoolRETHStandardExchangeCommon
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol";

/**
 * @title RocketPoolRETHRebalanceTarget
 * @notice Permissionless stake excess / burn deficit toward oracle liquid target.
 * @dev No queue bookkeeping. Capacity/collateral dry → no-op (never reverts solely on dry).
 */
contract RocketPoolRETHRebalanceTarget is
    RocketPoolRETHStandardExchangeCommon,
    ReentrancyLockModifiers,
    IRocketPoolRETHRebalance
{
    receive() external payable {}

    function rebalance() external nonReentrant {
        uint256 target = _targetLiquidEth();
        uint256 liquid = liquidReserveEth();
        uint256 band = (target * REBALANCE_BAND_WAD) / ONE_WAD;

        if (liquid > target + band) {
            // Soft stake excess toward target (capacity-capped, no-op if 0)
            _stakeWethToRethSoft(liquid - target);
        } else if (liquid + band < target) {
            // Burn rETH to refill sleeve toward target (collateral-capped)
            _burnDeficit(target - liquid);
        }
    }

    function _burnDeficit(uint256 ethDeficit) internal {
        if (ethDeficit == 0) return;
        address reth_ = rETH();
        uint256 rethNeeded = _rethForEthUp(ethDeficit);
        uint256 rethBal = IERC20(reth_).balanceOf(address(this));
        if (rethBal == 0) return;
        if (rethNeeded > rethBal) rethNeeded = rethBal;

        uint256 ethBefore = address(this).balance;
        try IRETH(reth_).burn(rethNeeded) {
            uint256 ethGot = address(this).balance - ethBefore;
            if (ethGot > 0) {
                IWETH(payable(weth())).deposit{value: ethGot}();
            }
        } catch {
            // collateral dry: no-op
        }
    }
}
