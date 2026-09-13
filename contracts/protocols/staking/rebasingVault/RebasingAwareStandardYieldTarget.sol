// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareERC4626Repo} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Repo.sol";
import {RebasingAwareERC4626Common} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

contract RebasingAwareStandardYieldTarget is ReentrancyLockModifiers {
    function deposit(address receiver, address tokenIn, uint256 amountTokenToDeposit, uint256 minSharesOut)
        external
        payable
        nonReentrant
        returns (uint256 amountSharesOut)
    {
        if (msg.value != 0) revert IRebasingAwareERC4626.NativeValueNotSupported();
        if (amountTokenToDeposit == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        address asset_ = address(RebasingAwareERC4626Repo._asset());
        if (tokenIn != asset_) {
            revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(this));
        }
        amountSharesOut =
            RebasingAwareERC4626Common.executeDeposit(amountTokenToDeposit, receiver, minSharesOut, true);
    }

    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut,
        bool burnFromInternalBalance
    ) external nonReentrant returns (uint256 amountTokenOut) {
        if (amountSharesToRedeem == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        address asset_ = address(RebasingAwareERC4626Repo._asset());
        if (tokenOut != asset_) {
            revert IStandardExchangeErrors.InvalidRoute(address(this), tokenOut);
        }
        RebasingAwareERC4626Common.ShareSource source = burnFromInternalBalance
            ? RebasingAwareERC4626Common.ShareSource.PublicBalanceExactBurn
            : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
        address owner = burnFromInternalBalance ? address(this) : msg.sender;
        amountTokenOut = RebasingAwareERC4626Common.executeRedeem(
            amountSharesToRedeem, receiver, owner, minTokenOut, source, true
        );
    }

    function exchangeRate() external view returns (uint256) {
        return RebasingAwareERC4626Common.exchangeRate();
    }

    function yieldToken() external view returns (address) {
        return address(RebasingAwareERC4626Repo._asset());
    }

    function assetInfo()
        external
        view
        returns (IStandardizedYield.AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (
            IStandardizedYield.AssetType.TOKEN,
            address(RebasingAwareERC4626Repo._asset()),
            RebasingAwareERC4626Repo._assetDecimals()
        );
    }

    function getTokensIn() public view returns (address[] memory res) {
        res = new address[](1);
        res[0] = address(RebasingAwareERC4626Repo._asset());
    }

    function getTokensOut() public view returns (address[] memory res) {
        res = new address[](1);
        res[0] = address(RebasingAwareERC4626Repo._asset());
    }

    function isValidTokenIn(address token) public view returns (bool) {
        return token == address(RebasingAwareERC4626Repo._asset());
    }

    function isValidTokenOut(address token) public view returns (bool) {
        return token == address(RebasingAwareERC4626Repo._asset());
    }

    function previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        external
        view
        returns (uint256 amountSharesOut)
    {
        if (amountTokenToDeposit == 0) return 0;
        if (!isValidTokenIn(tokenIn)) {
            revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(this));
        }
        return RebasingAwareERC4626Common.previewDeposit(amountTokenToDeposit);
    }

    function previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        external
        view
        returns (uint256 amountTokenOut)
    {
        if (amountSharesToRedeem == 0) return 0;
        if (!isValidTokenOut(tokenOut)) {
            revert IStandardExchangeErrors.InvalidRoute(address(this), tokenOut);
        }
        return RebasingAwareERC4626Common.previewRedeem(amountSharesToRedeem);
    }

    function getRewardTokens() external pure returns (address[] memory) {
        return new address[](0);
    }

    function accruedRewards(address) external pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function rewardIndexesCurrent() external pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function rewardIndexesStored() external pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function claimRewards(address user) external returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
        emit IStandardizedYield.ClaimRewards(user, new address[](0), amounts);
    }
}
