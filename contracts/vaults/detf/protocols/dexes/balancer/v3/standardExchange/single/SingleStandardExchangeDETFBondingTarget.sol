// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {SingleStandardExchangeDETFCommon} from "./SingleStandardExchangeDETFCommon.sol";
import {SingleStandardExchangeDETFRepo as Repo} from "./SingleStandardExchangeDETFRepo.sol";

/// @notice Only duration-specific purchase and authorized reserve donation routes remain outside SE.
interface ISingleStandardExchangeDETFBonding {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 duration, address recipient, bool prepaid, uint256 deadline)
        external returns (uint256 tokenId, uint256 protocolLpAdded);
    function previewBond(IERC20 tokenIn, uint256 amountIn, uint256 duration)
        external view returns (uint256 principal, uint256 liquidityDetf, uint256 rewardPot);
    function acceptedBondTokens() external view returns (address[] memory);
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline) external returns (uint256);
    function previewJoinDonatedCapital(IERC20 token, uint256 amount) external view returns (uint256);
    function notifyReserveDonated() external;
    function donate(IERC20 token, uint256 amount, bool prepaid) external;
}

abstract contract SingleStandardExchangeDETFBondingTarget is SingleStandardExchangeDETFCommon {
    using BetterSafeERC20 for IERC20;

    function bond(IERC20 in_, uint256 amount_, uint256 duration_, address to_, bool prepaid_, uint256 deadline_)
        public virtual nonReentrant returns (uint256 id_, uint256 lp_)
    {
        _requireNotDisabled();
        _requireActive(deadline_, amount_);
        if (!Repo._layoutStruct().isReserveLive) _rejectPretransferredFirstBond(prepaid_, amount_);
        if (to_ == address(0)) to_ = msg.sender;
        _updateExpansionMintOnRewards();
        uint256 lock_ = _effectiveLockDuration(duration_);
        uint256 shares_ = _receiveVaultShares(in_, amount_, prepaid_, deadline_);
        (id_, lp_) = _purchaseBond(shares_, lock_, to_);
        _syncAllExpectedHoldReserves();
    }

    function _purchaseBond(uint256 shares_, uint256 duration_, address to_) internal returns (uint256 id_, uint256 lp_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 liquidity_ = _quoteBondJoinDetf(shares_);
        MintSplit memory split_ = _splitBondDetf(_quoteBondPurchase(shares_, duration_), liquidity_);
        _mintDetf(address(this), liquidity_);
        lp_ = _joinReserveBothLegs(liquidity_, shares_);
        _custodyBptOnNft(lp_);
        if (!s_.isReserveLive) Repo._setReserveLive();
        _mintDetf(address(this), split_.userDetf);
        IERC20(address(this)).forceApprove(address(s_.bondNftVault), split_.userDetf);
        id_ = IDetfBondNFT(address(s_.bondNftVault)).createFundedPosition(split_.userDetf, duration_, to_);
        IERC20(address(this)).forceApprove(address(s_.bondNftVault), 0);
        _fundStakingRewards(split_.inventoryDetf);
    }

    function previewBond(IERC20 in_, uint256 amount_, uint256 duration_)
        external view returns (uint256 principal_, uint256 liquidity_, uint256 pot_)
    {
        uint256 shares_ = _previewVaultSharesIn(in_, amount_);
        liquidity_ = _quoteBondJoinDetf(shares_);
        MintSplit memory split_ = _splitBondDetf(_quoteBondPurchase(shares_, _effectiveLockDuration(duration_)), liquidity_);
        return (split_.userDetf, liquidity_, split_.inventoryDetf);
    }

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        address[] memory underlying_ = IBasicVault(address(s_.standardExchangeVault)).vaultTokens();
        tokens_ = new address[](underlying_.length + 1);
        tokens_[0] = address(s_.standardExchangeVaultShare);
        uint256 count_ = 1;
        for (uint256 i_; i_ < underlying_.length; ++i_) {
            address token_ = underlying_[i_];
            if (token_ == address(this) || token_ == address(s_.rebasingClaimToken)) continue;
            bool seen_;
            for (uint256 j_; j_ < count_; ++j_) if (tokens_[j_] == token_) seen_ = true;
            if (!seen_) tokens_[count_++] = token_;
        }
        assembly { mstore(tokens_, count_) }
    }

    function joinDonatedCapital(IERC20 token_, uint256 amount_, uint256 deadline_)
        external nonReentrant returns (uint256 lp_)
    {
        _requireBondNft();
        _requireNotDisabled();
        _requireReserveLive();
        _requireActive(deadline_, amount_);
        lp_ = address(token_) == address(this)
            ? _joinReserveDetfOnly(_pullToken(token_, amount_, false))
            : _joinReserveVaultSharesOnly(_receiveVaultShares(token_, amount_, false, deadline_));
        _sendJoinBptToNft(lp_);
        _syncAllExpectedHoldReserves();
    }



    function notifyReserveDonated() external { _requireBondNft(); }

    function donate(IERC20 token_, uint256 amount_, bool prepaid_) external {
        _requireNotDisabled();
        IDetfNftReserveDonation(address(Repo._layoutStruct().bondNftVault)).donate(
            msg.sender, token_, amount_, 0, prepaid_, block.timestamp
        );
    }
}
