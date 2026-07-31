// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {
    SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @title SingleStandardExchangeDETFBondingTarget
/// @notice Bond with SE vault shares (or allowlisted assets). First bond bootstraps the reserve.
interface ISingleStandardExchangeDETFBonding {
    function bond(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

    function sellPositionToDetfNft(uint256 tokenId, address recipient)
        external
        returns (uint256 principalShares);
}

abstract contract SingleStandardExchangeDETFBondingTarget is
    SingleStandardExchangeDETFCommon,
    ISingleStandardExchangeDETFBonding
{
    using BetterSafeERC20 for IERC20;

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function bond(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        _requireActive(deadline_, amountIn_);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);

        uint256 vaultShares_;
        if (address(tokenIn_) == address(s.standardExchangeVaultShare)) {
            vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        } else if (_isAllowlistedTokenIn(tokenIn_)) {
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            tokenIn_.safeTransfer(address(s.standardExchangeVault), pulled_);
            vaultShares_ = s.standardExchangeVault.exchangeIn(
                tokenIn_, pulled_, s.standardExchangeVaultShare, 0, address(this), true, deadline_
            );
        } else {
            revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, IERC20(address(this)));
        }

        // Quote DETF self-leg for pairing with vault shares (bootstrap or proportional).
        uint256 detfForPool_ = _quoteDetfOutForVaultShares(vaultShares_);
        MintSplit memory split_ = _splitMintedDetf(detfForPool_);

        // Mint DETF for pool join + user/fee/protocol slices.
        // Pool join uses full gross (weight-matched); user receives userDetf as free DETF;
        // fee and protocol slices minted separately. Peer DETFs join vault shares and mint DETF to users;
        // first-bond requires both legs — mint gross DETF to this, join (gross, vaultShares), then
        // the BPT is the bond principal; user DETF from split is additional mint to user.
        //
        // Simpler bootstrap model matching PRD "mint DETF self-leg into pool + join shares":
        // mint detfForPool_ to this, join both, BPT → bond NFT; also mint fee/protocol/user free DETF.
        _mintDetf(address(this), detfForPool_);
        uint256 bptOut_ = _joinReserveBothLegs(detfForPool_, vaultShares_);

        // User free DETF (share of seigniorage split of the same gross).
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);

        // Bond principal = BPT amount; BPT remains on this DETF (peer Protocol NFT pattern).
        // createPosition records share units and unlock; DETF is NFT vault owner.
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptOut_, effectiveLock_, recipient_
        );
        shares_ = bptOut_;

        if (!s.isReserveLive) {
            SingleStandardExchangeDETFRepo._setReserveLive();
        }

        // Lazy protocol compound after reward-affecting bond / inventory mint (best-effort).
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        principalShares_ = DETFBondLifecycleLib._sellPositionToDetfNft(
            s.bondNftVault, tokenId_, msg.sender, recipient_
        );
        // Sell moves principal onto detf NFT; attempt compound of any pending protocol rewards.
        _tryCompoundProtocolRewards();
    }
}
