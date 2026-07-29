// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IWeETH} from "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IWeETH.sol";
import {IEtherFiLiquidityPool} from
    "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IEtherFiLiquidityPool.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {
    IEtherFiWeETHRebalance
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {
    IEtherFiWithdrawRequestNFT
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWithdrawRequestNFT.sol";
import {
    EtherFiWeETHStandardExchangeCommon
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol";
import {
    EtherFiWeETHStandardExchangeRepo
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeRepo.sol";

/**
 * @title EtherFiWeETHRebalanceTarget
 * @notice Claim+wrap, stake excess liquid, queue deficit toward oracle liquid target.
 * @dev Implements IERC721Receiver so WithdrawRequestNFT safeMint to the vault succeeds.
 */
contract EtherFiWeETHRebalanceTarget is
    EtherFiWeETHStandardExchangeCommon,
    ReentrancyLockModifiers,
    IEtherFiWeETHRebalance
{
    using SafeERC20 for IERC20;

    receive() external payable {}

    /// @notice Accept WithdrawRequestNFT (and any ERC-721) mints/transfers to the vault.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

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
        uint256[] memory ids = EtherFiWeETHStandardExchangeRepo._requestIds();
        address nft = withdrawRequestNFT();
        if (nft == address(0)) return;

        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (!EtherFiWeETHStandardExchangeRepo._isTrackedRequest(id)) continue;
            try IEtherFiWithdrawRequestNFT(nft).isFinalized(id) returns (bool fin) {
                if (!fin) continue;
            } catch {
                continue;
            }
            uint256 beforeEth = address(this).balance;
            try IEtherFiWithdrawRequestNFT(nft).claimWithdraw(id) {
                uint256 got = address(this).balance - beforeEth;
                EtherFiWeETHStandardExchangeRepo._clearRequest(id);
                if (got > 0) {
                    IWETH(payable(weth())).deposit{value: got}();
                }
            } catch {
                // already claimed or not claimable
            }
        }
    }

    function _stakeExcess(uint256 wethAmount) internal {
        if (wethAmount == 0) return;
        _stakeWethToWeEth(wethAmount);
    }

    function _queueDeficit(uint256 ethDeficit) internal {
        if (ethDeficit == 0) return;
        address pool = liquidityPool();
        address we_ = weETH();
        address e_ = eETH();
        if (pool == address(0)) return;

        uint256 remaining = ethDeficit;
        uint256 n;
        while (remaining > 0 && n < MAX_QUEUE_REQUESTS_PER_REBALANCE) {
            uint256 chunk = remaining > MAX_EETH_WITHDRAWAL ? MAX_EETH_WITHDRAWAL : remaining;
            if (chunk < MIN_EETH_WITHDRAWAL) break;

            // Prefer weETH inventory: unwrap then requestWithdraw eETH amount
            uint256 weNeeded = IWeETH(we_).getWeETHByeETH(chunk);
            uint256 weBal = IERC20(we_).balanceOf(address(this));
            if (weBal < weNeeded) {
                if (weBal == 0) break;
                weNeeded = weBal;
                chunk = IWeETH(we_).getEETHByWeETH(weNeeded);
                if (chunk < MIN_EETH_WITHDRAWAL) break;
            }

            uint256 eOut = IWeETH(we_).unwrap(weNeeded);
            IERC20(e_).forceApprove(pool, eOut);
            uint256 requestId = IEtherFiLiquidityPool(pool).requestWithdraw(address(this), eOut);
            EtherFiWeETHStandardExchangeRepo._trackRequest(requestId, eOut);
            remaining = remaining > eOut ? remaining - eOut : 0;
            unchecked {
                ++n;
            }
        }
    }
}
