// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {
    SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @title ISingleStandardExchangeDETFBonding
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

    function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
        external
        returns (uint256 claimMinted);

    function acceptedBondTokens() external view returns (address[] memory);

    function buyClaim(
        uint256 detfAmount,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimMinted);

    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted);

    function closeBondMature(
        uint256 tokenId,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewCloseBondMature(uint256 tokenId, IERC20 tokenOut) external view returns (uint256 amountOut);

    /// @notice Redeem rebasing claim for vaultShare or an SE-declared token via protocol reserve BPT unwind.
    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut);

    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 amountOut);

    function protocolBondOriginalShares() external view returns (uint256);
}

/// @title SingleStandardExchangeDETFBondingTarget
/// @notice Vault-share first-bond; sell → claim; mature close; claim redeem to burn allowlist.
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
        _requireNotDisabled();
        _requireActive(deadline_, amountIn_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(tokenIn_) == address(this)) {
            revert SingleStandardExchangeDETFRepo.InvalidRoute(address(tokenIn_), address(this));
        }

        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (!s.isReserveLive) {
            _rejectPretransferredFirstBond(pretransferred_, amountIn_);
        }
        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);

        uint256 vaultShares_;
        if (address(tokenIn_) == address(s.standardExchangeVaultShare)) {
            vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        } else if (_isAllowlistedTokenIn(tokenIn_)) {
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            vaultShares_ = _nestedExchangeInPush(
                IStandardExchangeIn(address(s.standardExchangeVault)),
                tokenIn_,
                pulled_,
                s.standardExchangeVaultShare,
                0,
                address(this),
                deadline_
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
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function sellPositionToDetfNft(uint256 tokenId_, uint256 minClaimOut_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 claimMinted_)
    {
        _requireMature(tokenId_);
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert SingleStandardExchangeDETFRepo.ClaimTokenNotConfigured();
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _updateExpansionMintOnRewards();

        uint256 protocolBefore_ = _protocolOriginalShares();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        DETFBondLifecycleLib._sellPositionToDetfNft(s.bondNftVault, tokenId_, msg.sender, recipient_);
        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(assets_, protocolBefore_, recipient_);
        if (claimMinted_ < minClaimOut_) {
            revert SingleStandardExchangeDETFRepo.InvalidRoute(address(s.rebasingClaimToken), address(0));
        }

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        address[] memory seTokens_ = IBasicVault(address(s.standardExchangeVault)).vaultTokens();
        tokens_ = new address[](seTokens_.length + 1);
        tokens_[0] = address(s.standardExchangeVaultShare);
        uint256 n_ = 1;
        for (uint256 i; i < seTokens_.length; ++i) {
            address t_ = seTokens_[i];
            if (t_ == address(this) || t_ == address(s.standardExchangeVaultShare)) continue;
            tokens_[n_++] = t_;
        }
        assembly {
            mstore(tokens_, n_)
        }
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function protocolBondOriginalShares() external view returns (uint256) {
        return _protocolOriginalShares();
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function buyClaim(
        uint256 detfAmount_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 claimMinted_) {
        _requireNotDisabled();
        _requireReserveLive();
        _requireActive(deadline_, detfAmount_);
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert SingleStandardExchangeDETFRepo.ClaimTokenNotConfigured();
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _pullToken(IERC20(address(this)), detfAmount_, pretransferred_);
        uint256 bptIn_ = _singleSidedJoinDetf(detfAmount_);
        if (bptIn_ == 0) revert SingleStandardExchangeDETFRepo.ZeroAmount();

        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(bptIn_, recipient_);
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptIn_);
        if (claimMinted_ < minClaimOut_) {
            revert SingleStandardExchangeDETFRepo.InvalidRoute(address(s.rebasingClaimToken), address(0));
        }

        _updateExpansionMintOnRewards();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function previewBuyClaim(uint256 detfAmount_) external view returns (uint256 claimMinted_) {
        if (detfAmount_ == 0) return 0;
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 bptIn_ = _previewJoinDetfOnly(detfAmount_);
        claimMinted_ = _previewClaimMinted(bptIn_, _protocolOriginalShares());
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function closeBondMature(
        uint256 tokenId_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireMature(tokenId_);
        _requireActive(deadline_, 1);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        _updateExpansionMintOnRewards();

        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (assets_ == 0) revert SingleStandardExchangeDETFRepo.ZeroAmount();
        uint256 protocol_ = _protocolOriginalShares();
        uint256 bal_ = s.reserveBpt.balanceOf(address(this));
        if (bal_ < protocol_ + assets_) {
            revert SingleStandardExchangeDETFRepo.InsufficientReserveBpt(protocol_ + assets_, bal_);
        }

        if (!_isPrimaryBurnTokenOut(tokenOut_)) {
            revert SingleStandardExchangeDETFRepo.InvalidRoute(address(0), address(tokenOut_));
        }

        DETFBondLifecycleLib._sellPositionToDetfNft(s.bondNftVault, tokenId_, msg.sender, recipient_);
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), assets_);

        amountOut_ = _exitRedepositSettle(assets_, tokenOut_, minOut_, recipient_, deadline_);

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function previewCloseBondMature(uint256 tokenId_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (assets_ == 0) return 0;
        if (!_isPrimaryBurnTokenOut(tokenOut_)) return 0;
        amountOut_ = _previewBptUnwind(assets_, tokenOut_);
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function redeemClaim(
        uint256 claimAmount_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireReserveLive();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        if (!_isPrimaryBurnTokenOut(tokenOut_)) {
            revert SingleStandardExchangeDETFRepo.InvalidRoute(address(0), address(tokenOut_));
        }

        uint256 bptOut_ = _burnClaimConvertToAssets(claimAmount_);
        amountOut_ = _exitRedepositSettle(bptOut_, tokenOut_, minOut_, recipient_, deadline_);
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function previewRedeemClaim(uint256 claimAmount_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        if (claimAmount_ == 0) return 0;
        if (!_isPrimaryBurnTokenOut(tokenOut_)) return 0;
        uint256 bptOut_ = _previewClaimBptOut(claimAmount_);
        amountOut_ = _previewBptUnwind(bptOut_, tokenOut_);
    }

    /// @inheritdoc ISingleStandardExchangeDETFBonding
    function claimLiquidity(uint256 lpAmount_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 amountOut_)
    {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (
            msg.sender != address(this) && msg.sender != address(s.bondNftVault)
                && msg.sender != address(s.rebasingClaimToken)
        ) {
            revert SingleStandardExchangeDETFRepo.NotAuthorized(msg.sender);
        }
        if (lpAmount_ == 0) revert SingleStandardExchangeDETFRepo.ZeroAmount();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        IERC20 tokenOut_ = s.rateTarget;
        if (address(tokenOut_) == address(0) || !_isPrimaryBurnTokenOut(tokenOut_)) {
            tokenOut_ = s.standardExchangeVaultShare;
        }

        uint256 userPile_ = _userPileReserved();
        uint256 bal_ = s.reserveBpt.balanceOf(address(this));
        uint256 physicalAvail_ = bal_ > userPile_ ? bal_ - userPile_ : 0;
        if (physicalAvail_ < lpAmount_) {
            revert SingleStandardExchangeDETFRepo.InsufficientReserveBpt(lpAmount_, physicalAvail_);
        }
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), lpAmount_);
        amountOut_ = _exitRedepositSettle(lpAmount_, tokenOut_, 0, recipient_, block.timestamp);
        _syncAllExpectedHoldReserves();
    }

    function _burnClaimConvertToAssets(uint256 claimAmount_) private returns (uint256 bptOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert SingleStandardExchangeDETFRepo.ClaimTokenNotConfigured();
        }
        uint256 totalSharesBefore_ = s.rebasingClaimToken.totalShares();
        uint256 sharesBurned_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (sharesBurned_ == 0) revert SingleStandardExchangeDETFRepo.ZeroAmount();
        uint256 totalAssets_ = _protocolOriginalShares();
        uint256 totalShares_ = totalSharesBefore_ == 0 ? sharesBurned_ : totalSharesBefore_;
        bptOut_ = (sharesBurned_ * totalAssets_) / totalShares_;
        if (bptOut_ == 0) revert SingleStandardExchangeDETFRepo.ZeroAmount();

        uint256 userPile_ = _userPileReserved();
        uint256 bal_ = s.reserveBpt.balanceOf(address(this));
        uint256 physicalAvail_ = bal_ > userPile_ ? bal_ - userPile_ : 0;
        if (physicalAvail_ < bptOut_) {
            revert SingleStandardExchangeDETFRepo.InsufficientReserveBpt(bptOut_, physicalAvail_);
        }
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), bptOut_);
    }

    function _previewClaimBptOut(uint256 claimAmount_) private view returns (uint256 bptOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 shares_ = s.rebasingClaimToken.convertToShares(claimAmount_);
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 totalAssets_ = _protocolOriginalShares();
        if (shares_ == 0 || totalShares_ == 0) return 0;
        bptOut_ = (shares_ * totalAssets_) / totalShares_;
    }

    function _previewClaimMinted(uint256 assets_, uint256 totalAssets_) private view returns (uint256) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 sharesOut_ = totalAssets_ == 0 ? assets_ : (assets_ * totalShares_) / totalAssets_;
        return s.rebasingClaimToken.convertToClaim(sharesOut_);
    }

    function _previewJoinDetfOnly(uint256 detfAmount_) private view returns (uint256 bptOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || detfAmount_ == 0) return 0;
        IVault bal_ = _reserveVault();
        (,, uint256[] memory balances_,) = bal_.getPoolTokenInfo(s.reservePool);
        uint256 detfBal_ = balances_[s.detfIndex];
        if (detfBal_ == 0) return 0;
        bptOut_ = (detfAmount_ * bptSupply_) / detfBal_;
    }

    function _exitRedepositSettle(
        uint256 bptIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        (uint256 detfLeg_, uint256 vaultSharesOut_) = _exitReserveProportional(bptIn_);
        if (detfLeg_ > 0) {
            uint256 dust_ = vaultSharesOut_ / 1000;
            if (dust_ == 0 && vaultSharesOut_ > 1) dust_ = 1;
            if (dust_ >= vaultSharesOut_ && vaultSharesOut_ > 0) dust_ = vaultSharesOut_ - 1;
            uint256 bptBack_;
            if (dust_ > 0) {
                bptBack_ = _joinReserveBothLegs(detfLeg_, dust_);
                vaultSharesOut_ -= dust_;
            } else {
                bptBack_ = _singleSidedJoinDetf(detfLeg_);
            }
            if (bptBack_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
            }
        }
        if (address(tokenOut_) == address(s.standardExchangeVaultShare)) {
            if (vaultSharesOut_ < minOut_) {
                revert SingleStandardExchangeDETFRepo.InvalidRoute(
                    address(s.standardExchangeVaultShare), address(tokenOut_)
                );
            }
            if (vaultSharesOut_ > 0) tokenOut_.safeTransfer(recipient_, vaultSharesOut_);
            return vaultSharesOut_;
        }
        amountOut_ = _nestedExchangeInPush(
            IStandardExchangeIn(address(s.standardExchangeVault)),
            s.standardExchangeVaultShare,
            vaultSharesOut_,
            tokenOut_,
            minOut_,
            recipient_,
            deadline_
        );
        if (amountOut_ < minOut_) {
            revert SingleStandardExchangeDETFRepo.InvalidRoute(
                address(s.standardExchangeVaultShare), address(tokenOut_)
            );
        }
    }

}
