// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {
    MixedBufferMultiVaultStableDetfCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";

/// @title IMixedBufferMultiVaultStableDetfBonding
interface IMixedBufferMultiVaultStableDetfBonding {
    /// @notice Permissionless multi-asset first bond: pull buffer+shares, peg-seed DETF, init pool, bond BPT, go live.
    /// @dev Primary outcome is bond NFT with BPT principal; free DETF is seigniorage side effect (P1).
    function bootstrapFirstBond(
        uint256 bufferAmount,
        uint256[] calldata vaultShareAmounts,
        uint256 lockDuration,
        address recipient,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 bptPrincipal, uint256 freeDetfToUser);

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

    /// @notice Close a mature user bond (D25+L2). `minAmountsOut` is family reserve order; DETF slot must be 0.
    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);

    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);

    /// @notice Redeem rebasing claim for DETF only (D15).
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

    /// @notice Bond NFT only. Settle `token` and single-sided join BPT to the Bond NFT. No DETF mint. No expansion.
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline)
        external
        returns (uint256 lpOut);

    function previewJoinDonatedCapital(IERC20 token, uint256 amount)
        external
        view
        returns (uint256 lpOut);

    /// @notice Bond NFT only. D2 top-up after donate credits id 0.
    function notifyReserveDonated() external;

    /// @notice Forwards to Bond NFT donate with `minLpOut = 0`. Pretransfer destination is the NFT.
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;
}

/// @title MixedBufferMultiVaultStableDetfBondingTarget
/// @notice bootstrapFirstBond → live; ongoing bond buffer/share/BPT; mature sell → claim; close/redeem → buffer.
abstract contract MixedBufferMultiVaultStableDetfBondingTarget is
    MixedBufferMultiVaultStableDetfCommon,
    IMixedBufferMultiVaultStableDetfBonding
{
    using BetterSafeERC20 for IERC20;

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function bootstrapFirstBond(
        uint256 bufferAmount_,
        uint256[] calldata vaultShareAmounts_,
        uint256 lockDuration_,
        address recipient_,
        uint256 deadline_
    )
        public
        virtual
        nonReentrant
        returns (uint256 tokenId_, uint256 bptPrincipal_, uint256 freeDetfToUser_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (s.isReserveLive) revert MixedBufferMultiVaultStableDetfRepo.AlreadyLive();
        if (IERC20(s.reservePool).totalSupply() != 0) {
            revert MixedBufferMultiVaultStableDetfRepo.AlreadyLive();
        }
        if (block.timestamp > deadline_) {
            revert MixedBufferMultiVaultStableDetfRepo.DeadlineExpired(deadline_);
        }
        if (bufferAmount_ == 0) revert MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts();
        if (vaultShareAmounts_.length != s.vaultCount) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts();
        }
        for (uint256 i; i < s.vaultCount; ++i) {
            if (vaultShareAmounts_[i] == 0) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts();
            }
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);

        // Pull all non-DETF legs.
        _pullToken(s.bufferToken, bufferAmount_, false);
        uint256[] memory amounts_ = new uint256[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            amounts_[i] = _pullToken(s.vaultShares[i], vaultShareAmounts_[i], false);
        }

        // Family first-bond G: peg seed DETF self-leg (unboosted). L1+D4 pot after D2.
        uint256 detfForPool_ = _pegSeedDetfAmount(bufferAmount_, amounts_);
        MintSplit memory split_ = _splitBondDetf(detfForPool_);
        _mintDetf(address(this), detfForPool_);

        bptPrincipal_ = _initializeReserve(detfForPool_, bufferAmount_, amounts_);

        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        freeDetfToUser_ = split_.userDetf;

        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptPrincipal_, effectiveLock_, recipient_
        );
        _custodyBptOnNft(bptPrincipal_);

        MixedBufferMultiVaultStableDetfRepo._setReserveLive();
        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
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
        if (address(tokenIn_) == address(this)) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(this));
        }

        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive) {
            revert MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized();
        }

        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);
        uint256 bptPrincipal_;
        MintSplit memory split_;

        if (address(tokenIn_) == address(s.reserveBpt)) {
            bptPrincipal_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        } else if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(tokenIn_)) {
            uint256 bufferIn_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            uint256 detfForPool_ = _quoteBondJoinDetf(s.bufferIndex, bufferIn_);
            split_ = _splitBondDetf(detfForPool_);
            _mintDetf(address(this), detfForPool_);
            bptPrincipal_ = _joinReserveBufferAndDetf(bufferIn_, detfForPool_);
            if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        } else {
            (bool found_, uint256 legIndex_) = MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(tokenIn_);
            if (!found_) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(this));
            }
            uint256 vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            uint256 detfForPool_ = _quoteBondJoinDetf(s.shareIndexes[legIndex_], vaultShares_);
            split_ = _splitBondDetf(detfForPool_);
            _mintDetf(address(this), detfForPool_);
            bptPrincipal_ = _joinReserveShareAndDetf(legIndex_, vaultShares_, detfForPool_);
            if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        }

        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptPrincipal_, effectiveLock_, recipient_
        );
        shares_ = bptPrincipal_;
        _custodyBptOnNft(bptPrincipal_);
        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function sellPositionToDetfNft(uint256 tokenId_, uint256 minClaimOut_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 claimMinted_)
    {
        _requireMature(tokenId_);
        _requireNotStandingRewardNft(tokenId_);
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MixedBufferMultiVaultStableDetfRepo.ClaimTokenNotConfigured();
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _updateExpansionMintOnRewards();

        uint256 protocolBefore_ = _protocolOriginalShares();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        DETFBondLifecycleLib._sellPositionToDetfNft(s.bondNftVault, tokenId_, msg.sender, recipient_);
        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(assets_, protocolBefore_, recipient_);
        if (claimMinted_ < minClaimOut_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(s.rebasingClaimToken), address(0));
        }

        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        // buffer + N vault shares + reserve BPT
        tokens_ = new address[](uint256(s.vaultCount) + 2);
        tokens_[0] = address(s.bufferToken);
        for (uint256 i; i < s.vaultCount; ++i) {
            tokens_[i + 1] = address(s.vaultShares[i]);
        }
        tokens_[uint256(s.vaultCount) + 1] = address(s.reserveBpt);
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function protocolBondOriginalShares() external view returns (uint256) {
        return _protocolOriginalShares();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function buyClaim(
        uint256 detfAmount_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 claimMinted_) {
        _requireReserveLive();
        _requireActive(deadline_, detfAmount_);
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MixedBufferMultiVaultStableDetfRepo.ClaimTokenNotConfigured();
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _pullToken(IERC20(address(this)), detfAmount_, pretransferred_);
        uint256 bptIn_ = _singleSidedJoinDetf(detfAmount_);
        if (bptIn_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();

        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(bptIn_, recipient_);
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptIn_);
        if (claimMinted_ < minClaimOut_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(s.rebasingClaimToken), address(0));
        }

        _topUpFeeCreatorShares();
        _updateExpansionMintOnRewards();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function previewBuyClaim(uint256 detfAmount_) external view returns (uint256 claimMinted_) {
        if (detfAmount_ == 0) return 0;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 bptIn_ = _previewJoinDetfOnly(detfAmount_);
        claimMinted_ = _previewClaimMinted(bptIn_, _protocolOriginalShares());
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function joinDonatedCapital(IERC20 token_, uint256 amount_, uint256 deadline_)
        external
        nonReentrant
        returns (uint256 lpOut_)
    {
        _requireBondNft();
        _requireNotDisabled();
        _requireReserveLive();
        _requireActive(deadline_, amount_);
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(token_) == s.reservePool || address(token_) == address(s.reserveBpt)) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(token_), address(this));
        }
        if (address(token_) == address(this)) {
            uint256 pulled_ = _pullToken(token_, amount_, false);
            lpOut_ = _joinReserveDetfOnly(pulled_);
        } else if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(token_)) {
            uint256 pulled_ = _pullToken(token_, amount_, false);
            lpOut_ = _joinDonatedBuffer(pulled_, deadline_);
        } else {
            (bool found_, uint256 legIndex_) =
                MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(token_);
            if (!found_) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(token_), address(this));
            }
            uint256 vaultShares_ = _pullToken(token_, amount_, false);
            lpOut_ = _joinReserveVaultShareOnly(legIndex_, vaultShares_);
        }
        _sendJoinBptToNft(lpOut_);
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function previewJoinDonatedCapital(IERC20 token_, uint256 amount_)
        external
        view
        returns (uint256 lpOut_)
    {
        return _previewJoinDonatedCapital(token_, amount_);
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function notifyReserveDonated() external {
        _requireBondNft();
        _topUpFeeCreatorShares();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function donate(IERC20 token_, uint256 amount_, bool pretransferred_) external {
        _requireNotDisabled();
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        address nft_ = address(s.bondNftVault);
        if (nft_ == address(0)) revert MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized();
        IDetfNftReserveDonation(nft_).donate(
            msg.sender, token_, amount_, 0, pretransferred_, block.timestamp + 1
        );
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function closeBondMature(
        uint256 tokenId_,
        uint256[] calldata minAmountsOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256[] memory amountsOut_) {
        _requireMature(tokenId_);
        _requireNotStandingRewardNft(tokenId_);
        _requireActive(deadline_, 1);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = _reserveTokenCount();
        if (minAmountsOut_.length != n_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(0), address(0));
        }
        if (minAmountsOut_[s.detfIndex] != 0) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(this), address(0));
        }
        _updateExpansionMintOnRewards();

        uint256 lpOut_ = s.bondNftVault.convertToAssets(s.bondNftVault.originalSharesOf(tokenId_));
        if (lpOut_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
        s.bondNftVault.retireMaturePosition(tokenId_, recipient_);

        (uint256 detfOut_, uint256 bufferOut_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(lpOut_);
        if (detfOut_ > 0) {
            uint256 bptRejoin_ = _joinReserveDetfUntilDust(detfOut_);
            if (bptRejoin_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
            DETFBondLifecycleLib._addReservePoolBptToDetfNft(
                IERC20(s.reservePool),
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
                s.bondNftVault.detfNFTId(),
                bptRejoin_
            );
            _topUpFeeCreatorShares();
        }
        amountsOut_ = new uint256[](n_);
        if (bufferOut_ < minAmountsOut_[s.bufferIndex]) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(s.bufferToken), address(0));
        }
        if (bufferOut_ > 0) s.bufferToken.safeTransfer(recipient_, bufferOut_);
        amountsOut_[s.bufferIndex] = bufferOut_;
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 idx_ = s.shareIndexes[i];
            if (vaultSharesOut_[i] < minAmountsOut_[idx_]) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(s.vaultShares[i]), address(0));
            }
            if (vaultSharesOut_[i] > 0) {
                s.vaultShares[i].safeTransfer(recipient_, vaultSharesOut_[i]);
            }
            amountsOut_[idx_] = vaultSharesOut_[i];
        }

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function previewCloseBondMature(uint256 tokenId_)
        external
        view
        returns (uint256[] memory amountsOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (assets_ == 0) return new uint256[](_reserveTokenCount());
        uint256 lpOut_ = s.bondNftVault.convertToAssets(assets_);
        return _previewProportionalExit(lpOut_);
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function redeemClaim(
        uint256 claimAmount_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        amountOut_ = _redeemClaimForDetf(claimAmount_, tokenOut_, minOut_, recipient_, deadline_);
    }

    /// @dev D15: claim → DETF. Pending on id 0 first; leftover pending compounded; shortfall from LP.
    function _redeemClaimForDetf(
        uint256 claimAmount_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        _requireReserveLive();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _updateExpansionMintOnRewards();

        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(tokenOut_) != address(this)) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(s.rebasingClaimToken), address(tokenOut_));
        }

        uint256 bptOut_ = _burnClaimConvertToAssets(claimAmount_);
        uint256 owed_ = _previewProportionalDetf(bptOut_);
        uint256 harvested_ = s.bondNftVault.reallocateDetfNftRewards(address(this));

        if (harvested_ >= owed_) {
            amountOut_ = owed_;
            uint256 leftover_ = harvested_ - owed_;
            if (leftover_ > 0) {
                uint256 bptBack_ = _joinReserveDetfOnly(leftover_);
                if (bptBack_ > 0) {
                    s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
                }
            }
            if (bptOut_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptOut_);
            }
        } else {
            (uint256 detfFromLp_, uint256 bufOut_, uint256[] memory vaultSharesOut_) =
                _exitReserveProportional(bptOut_);
            uint256 shortfall_ = owed_ - harvested_;
            uint256 fromLp_ = detfFromLp_ < shortfall_ ? detfFromLp_ : shortfall_;
            amountOut_ = harvested_ + fromLp_;
            uint256 leftoverDetf_ = detfFromLp_ - fromLp_;
            _rejoinClaimNonDetf(leftoverDetf_, bufOut_, vaultSharesOut_, deadline_);
        }

        if (amountOut_ < minOut_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(this), address(tokenOut_));
        }
        if (amountOut_ > 0) {
            IERC20(address(this)).safeTransfer(recipient_, amountOut_);
        }
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function previewRedeemClaim(uint256 claimAmount_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        if (claimAmount_ == 0) return 0;
        if (address(tokenOut_) != address(this)) return 0;
        uint256 bptOut_ = _previewClaimBptOut(claimAmount_);
        amountOut_ = _previewProportionalDetf(bptOut_);
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function claimLiquidity(uint256 lpAmount_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 amountOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (
            msg.sender != address(this) && msg.sender != address(s.bondNftVault)
                && msg.sender != address(s.rebasingClaimToken)
        ) {
            revert MixedBufferMultiVaultStableDetfRepo.NotAuthorized(msg.sender);
        }
        if (lpAmount_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        amountOut_ = _exitRedepositSettleBuffer(lpAmount_, 0, recipient_, block.timestamp);
        _syncAllExpectedHoldReserves();
    }

    function _burnClaimConvertToAssets(uint256 claimAmount_) private returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MixedBufferMultiVaultStableDetfRepo.ClaimTokenNotConfigured();
        }
        uint256 totalSharesBefore_ = s.rebasingClaimToken.totalShares();
        uint256 sharesBurned_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (sharesBurned_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
        uint256 totalAssets_ = _protocolOriginalShares();
        uint256 totalShares_ = totalSharesBefore_ == 0 ? sharesBurned_ : totalSharesBefore_;
        bptOut_ = (sharesBurned_ * totalAssets_) / totalShares_;
        if (bptOut_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();

        uint256 userPile_ = _userPileReserved();
        uint256 bal_ = s.reserveBpt.balanceOf(address(s.bondNftVault));
        uint256 physicalAvail_ = bal_ > userPile_ ? bal_ - userPile_ : 0;
        if (physicalAvail_ < bptOut_) {
            revert MixedBufferMultiVaultStableDetfRepo.InsufficientReserveBpt(bptOut_, physicalAvail_);
        }
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), bptOut_);
    }

    function _previewClaimBptOut(uint256 claimAmount_) private view returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 shares_ = s.rebasingClaimToken.convertToShares(claimAmount_);
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 totalAssets_ = _protocolOriginalShares();
        if (shares_ == 0 || totalShares_ == 0) return 0;
        bptOut_ = (shares_ * totalAssets_) / totalShares_;
    }

    function _previewClaimMinted(uint256 assets_, uint256 totalAssets_) private view returns (uint256) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 sharesOut_ = totalAssets_ == 0 ? assets_ : (assets_ * totalShares_) / totalAssets_;
        return s.rebasingClaimToken.convertToClaim(sharesOut_);
    }

    function _previewJoinDetfOnly(uint256 detfAmount_) private view returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || detfAmount_ == 0) return 0;
        IVault bal_ = _reserveVault();
        (,, uint256[] memory balances_,) = bal_.getPoolTokenInfo(s.reservePool);
        uint256 detfBal_ = balances_[s.detfIndex];
        if (detfBal_ == 0) return 0;
        bptOut_ = (detfAmount_ * bptSupply_) / detfBal_;
    }

    function _exitRedepositSettleBuffer(
        uint256 bptIn_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        (uint256 detfLeg_, uint256 buf_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptIn_);
        if (detfLeg_ > 0) {
            uint256 bptBack_ = _singleSidedJoinDetf(detfLeg_);
            if (bptBack_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
            }
        }
        amountOut_ = buf_;
        for (uint256 i; i < s.vaultCount; ++i) {
            amountOut_ += _exchangeShareLegToBuffer(i, vaultSharesOut_[i], deadline_);
        }
        if (amountOut_ < minOut_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(
                address(s.reserveBpt), address(s.bufferToken)
            );
        }
        if (amountOut_ > 0) s.bufferToken.safeTransfer(recipient_, amountOut_);
    }

    /// @dev D15 redeposit of non-DETF after LP unwind. Zap buffer → vault-share 0 so MixedBuffer
    ///      hook reconcile is not asked to settle physical buffer on this join.
    function _rejoinClaimNonDetf(
        uint256 leftoverDetf_,
        uint256 bufOut_,
        uint256[] memory vaultSharesOut_,
        uint256 deadline_
    ) private {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 rejoinBuf_ = bufOut_;
        if (rejoinBuf_ > 0 && s.vaultCount > 0) {
            vaultSharesOut_[0] += _nestedExchangeInPush(
                s.underlyingVaults[0],
                s.bufferToken,
                rejoinBuf_,
                s.vaultShares[0],
                0,
                address(this),
                deadline_
            );
            rejoinBuf_ = 0;
        }
        bool anyRejoin_ = leftoverDetf_ > 0 || rejoinBuf_ > 0;
        for (uint256 i; i < vaultSharesOut_.length; ++i) {
            if (vaultSharesOut_[i] > 0) anyRejoin_ = true;
        }
        if (!anyRejoin_) return;
        uint256 bptBack_ = _joinReserveLegs(leftoverDetf_, rejoinBuf_, vaultSharesOut_);
        if (bptBack_ > 0) {
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
        }
    }

    function _exchangeShareLegToBuffer(uint256 legIndex_, uint256 shareAmt_, uint256 deadline_)
        private
        returns (uint256 bufferOut_)
    {
        if (shareAmt_ == 0) return 0;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        IERC20 share_ = s.vaultShares[legIndex_];
        share_.safeTransfer(address(s.underlyingVaults[legIndex_]), shareAmt_);
        bufferOut_ = s.underlyingVaults[legIndex_].exchangeIn(
            share_, shareAmt_, s.bufferToken, 0, address(this), true, deadline_
        );
    }
}
