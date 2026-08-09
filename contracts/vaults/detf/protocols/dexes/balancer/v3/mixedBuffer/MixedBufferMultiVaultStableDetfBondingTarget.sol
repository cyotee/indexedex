// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {
    MixedBufferMultiVaultStableDetfCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

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

    function sellPositionToDetfNft(uint256 tokenId, address recipient)
        external
        returns (uint256 principalShares);

    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 rebasingClaimMinted);

    function acceptedBondTokens() external view returns (address[] memory);

    /// @notice Redeem rebasing claim for bufferToken only via protocol reserve BPT unwind.
    function redeemClaim(
        uint256 claimAmount,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);
}

/// @title MixedBufferMultiVaultStableDetfBondingTarget
/// @notice bootstrapFirstBond → live; ongoing bond buffer/share/BPT; sell → claim; redeem → buffer.
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

        // §3.4 peg seed DETF self-leg into pool only.
        uint256 detfForPool_ = _pegSeedDetfAmount(bufferAmount_, amounts_);
        MintSplit memory split_ = _splitMintedDetf(detfForPool_);
        _mintDetf(address(this), detfForPool_);

        bptPrincipal_ = _initializeReserve(detfForPool_, bufferAmount_, amounts_);

        // Free seigniorage DETF (P1) — side effect; primary outcome is bond NFT.
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        freeDetfToUser_ = split_.userDetf;

        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptPrincipal_, effectiveLock_, recipient_
        );

        MixedBufferMultiVaultStableDetfRepo._setReserveLive();
        // Lazy protocol compound after live + inventory mint (best-effort; typically no-op pre-pending).
        _tryCompoundProtocolRewards();
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

        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive) {
            revert MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized();
        }

        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);
        uint256 bptPrincipal_;

        if (address(tokenIn_) == address(s.reserveBpt)) {
            bptPrincipal_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        } else if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(tokenIn_)) {
            // P4: unbalanced buffer join → BPT principal.
            // Join buffer + DETF self so StableMath invariant grows (buffer-only physical
            // add can shrink math-invariant until virtualBuffer hook updates mid-join).
            uint256 bufferIn_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            uint256 detfForPool_ = _quoteDetfOutForBuffer(bufferIn_);
            if (detfForPool_ == 0) detfForPool_ = bufferIn_;
            _mintDetf(address(this), detfForPool_);
            bptPrincipal_ = _joinReserveBufferAndDetf(bufferIn_, detfForPool_);
        } else {
            (bool found_, uint256 legIndex_) = MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(tokenIn_);
            if (!found_) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(this));
            }
            uint256 vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            uint256 detfForPool_ = _quoteDetfOutForVaultShares(legIndex_, vaultShares_);
            MintSplit memory split_ = _splitMintedDetf(detfForPool_);
            _mintDetf(address(this), detfForPool_);
            bptPrincipal_ = _joinReserveShareAndDetf(legIndex_, vaultShares_, detfForPool_);
            if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
            if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
            if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        }

        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptPrincipal_, effectiveLock_, recipient_
        );
        shares_ = bptPrincipal_;
        // Lazy protocol compound after reward-affecting bond / inventory mint (best-effort).
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        principalShares_ = DETFBondLifecycleLib._sellPositionToDetfNft(
            s.bondNftVault, tokenId_, msg.sender, recipient_
        );
        // Sell moves principal onto detf NFT; attempt compound of any pending protocol rewards.
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfBonding
    function sellNFT(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 rebasingClaimMinted_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MixedBufferMultiVaultStableDetfRepo.ClaimTokenNotConfigured();
        }
        (, rebasingClaimMinted_) = DETFBondLifecycleLib._sellPositionToRebasingClaim(
            s.bondNftVault, s.rebasingClaimToken, tokenId_, msg.sender, recipient_
        );
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
    function redeemClaim(uint256 claimAmount_, uint256 minOut_, address recipient_, uint256 deadline_)
        public
        virtual
        nonReentrant
        returns (uint256 amountOut_)
    {
        _requireReserveLive();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MixedBufferMultiVaultStableDetfRepo.ClaimTokenNotConfigured();
        }

        uint256 bptIn_ = _burnClaimForBpt(claimAmount_);
        amountOut_ = _unwindBptToBuffer(bptIn_, deadline_);
        if (amountOut_ < minOut_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(
                address(s.reserveBpt), address(s.bufferToken)
            );
        }
        s.bufferToken.safeTransfer(recipient_, amountOut_);
    }

    function _burnClaimForBpt(uint256 claimAmount_) private returns (uint256 bptIn_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 principalBpt_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (principalBpt_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
        uint256 detfBpt_ = s.reserveBpt.balanceOf(address(this));
        bptIn_ = principalBpt_ < detfBpt_ ? principalBpt_ : detfBpt_;
        if (bptIn_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
    }

    function _unwindBptToBuffer(uint256 bptIn_, uint256 deadline_) private returns (uint256 bufferOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        (uint256 detfLeg_, uint256 buf_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptIn_);
        if (detfLeg_ > 0) {
            _burnDetf(address(this), detfLeg_);
        }
        bufferOut_ = buf_;
        for (uint256 i; i < s.vaultCount; ++i) {
            bufferOut_ += _exchangeShareLegToBuffer(i, vaultSharesOut_[i], deadline_);
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
        // Nested SE must pull in-call (pretransferred=false) so L-GAPS-9 delta is observed.
        // transfer-then-pretransfer=true is free-inventory from the nested vault's perspective.
        share_.forceApprove(address(s.underlyingVaults[legIndex_]), shareAmt_);
        bufferOut_ = s.underlyingVaults[legIndex_].exchangeIn(
            share_, shareAmt_, s.bufferToken, 0, address(this), false, deadline_
        );
    }
}
