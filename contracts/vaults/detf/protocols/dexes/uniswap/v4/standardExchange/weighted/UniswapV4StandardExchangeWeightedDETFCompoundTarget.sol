// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    UniswapV4StandardExchangeWeightedDETFCommon,
    IWeightedDetfCompoundSelf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFCommon.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

/// @title UniswapV4StandardExchangeWeightedDETFCompoundTarget
/// @notice Claim + compound + expansion external surfaces (Option 1e size split).
abstract contract UniswapV4StandardExchangeWeightedDETFCompoundTarget is UniswapV4StandardExchangeWeightedDETFCommon {
    using BetterSafeERC20 for IERC20;

    /// @dev External self-call entrypoints (must live on Compound Facet for diamond `this.` routes).
    function tryCompoundProtocolRewardsExternal() external returns (uint256 detfIn_, uint256 lpOut_) {
        if (msg.sender != address(this)) revert NotSelf();
        return _tryCompoundProtocolRewardsInner();
    }

    function compoundProtocolRewardsAtomic() external returns (uint256 detfIn_, uint256 lpOut_) {
        if (msg.sender != address(this)) revert NotSelf();
        return _compoundProtocolRewardsAtomic();
    }

    /// @dev External self-call for redeposit (fresh stack + try/catch from close path).
    function redepositDetfExternal(uint256 amountNative_, uint256[] calldata pairDust_) external {
        if (msg.sender != address(this)) revert NotSelf();
        uint256[] memory dust_ = pairDust_;
        _redepositDetfSelfLegWithPairDust(amountNative_, dust_);
    }

    function swapDetfToCapitalExternal(uint256 detfAmt_, address capital_)
        external
        returns (uint256 out_)
    {
        if (msg.sender != address(this)) revert NotSelf();
        out_ = _weightedExactIn(address(this), capital_, detfAmt_, address(this));
    }

    function claimRewards(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 rewards_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        // Realize on fresh stack to avoid n-leg FD StackOverflow after deep bond paths.
        try IWeightedDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}
        // L-REW-1: owner-only; non-owner reverts (no soft-success).
        address holder_ = s.bondNftVault.ownerOf(tokenId_);
        if (msg.sender != holder_) {
            revert Repo.NotAuthorized(msg.sender);
        }
        // L-REW-2/3: execute claim; return 0 only when allowed and no rewards.
        rewards_ = s.bondNftVault.claimRewards(tokenId_, recipient_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @dev External self-call entry for expansion realize (stack reset).
    function realizeExpansionExternal() external {
        if (msg.sender != address(this)) revert NotSelf();
        _realizeExpansionIfNeeded();
    }

    /* ---------------------------------------------------------------------- */
    /*                                Claim                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Direct claim deposit. Reverts if not single-asset eligible (unlike compound skip).
    /// @dev D18 when tokenIn is DETF: join provided DETF, 4626 onto id 0, no new DETF mint.
    function depositClaim(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 claimOut_) {
        _requireReserveLive();
        _requireNotDisabled();
        _requireActive(deadline_, amountIn_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        _requireSingleAssetEligible();

        address holder_ = _bondLpHolder();
        uint256 lpMinted_;
        if (address(tokenIn_) == address(this)) {
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            lpMinted_ = _depositSingle(address(this), pulled_, holder_);
        } else {
            PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
            address pair_ = address(s.pairTokens[r_.fundedProductIndex]);
            lpMinted_ = _depositSingle(pair_, r_.pairNotionalNative, holder_);
        }
        if (lpMinted_ == 0) revert Repo.ZeroAmount();

        uint256 protocolBefore_ = s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpMinted_);
        claimOut_ = s.rebasingClaimToken.mintFromNFTSale(lpMinted_, protocolBefore_, recipient_);
        if (claimOut_ < minClaimOut_) revert Repo.SlippageExceeded(minClaimOut_, claimOut_);
        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

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
        if (address(tokenOut_) != address(this)) {
            revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
        }

        Repo.Storage storage s = Repo._layoutStruct();
        uint256 lpOut_ = _burnClaimConvertToAssets(claimAmount_);
        uint256 owed_ = _previewProportionalDetf(lpOut_);
        uint256 harvested_ = s.bondNftVault.reallocateDetfNftRewards(address(this));

        if (harvested_ >= owed_) {
            amountOut_ = owed_;
            uint256 leftover_ = harvested_ - owed_;
            if (leftover_ > 0) {
                uint256 lpBack_ = _redepositDetfSelfLeg(leftover_);
                if (lpBack_ > 0) {
                    s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpBack_);
                }
            }
            if (lpOut_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpOut_);
            }
        } else {
            _pullBondLp(lpOut_);
            uint256[] memory binding_ = _exitProportional(lpOut_, address(this));
            (uint256 detfFromLp_, uint256[] memory pairAmts_) = _unpackBinding(binding_);
            uint256 shortfall_ = owed_ - harvested_;
            uint256 fromLp_ = detfFromLp_ < shortfall_ ? detfFromLp_ : shortfall_;
            amountOut_ = harvested_ + fromLp_;
            uint256 leftoverDetf_ = detfFromLp_ - fromLp_;
            uint256 lpBack_;
            if (leftoverDetf_ > 0) {
                lpBack_ += _redepositDetfSelfLegWithPairDust(leftoverDetf_, pairAmts_);
            } else {
                lpBack_ += _joinPairsOnly(pairAmts_);
            }
            if (lpBack_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpBack_);
            }
        }

        if (amountOut_ < minOut_) revert Repo.SlippageExceeded(minOut_, amountOut_);
        if (amountOut_ > 0) {
            IERC20(address(this)).safeTransfer(recipient_, amountOut_);
        }
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    function _burnClaimConvertToAssets(uint256 claimAmount_) private returns (uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        uint256 totalSharesBefore_ = s.rebasingClaimToken.totalShares();
        uint256 sharesBurned_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (sharesBurned_ == 0) revert Repo.ZeroAmount();
        uint256 totalAssets_ = s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
        uint256 totalShares_ = totalSharesBefore_ == 0 ? sharesBurned_ : totalSharesBefore_;
        lpOut_ = (sharesBurned_ * totalAssets_) / totalShares_;
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), lpOut_);
    }

    function _previewProportionalDetf(uint256 lpIn_) internal view returns (uint256 detfOut_) {
        if (lpIn_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        try IHook(s.reserveHook).previewExitProportional(lpIn_) returns (uint256[] memory amts_) {
            if (amts_.length == s.n) return amts_[s.detfBindingIndex];
        } catch {}
    }

    function _joinPairsOnly(uint256[] memory pairAmts_) internal returns (uint256 lpOut_) {
        uint256 sum_;
        for (uint256 i; i < pairAmts_.length; ++i) {
            sum_ += pairAmts_[i];
        }
        if (sum_ == 0) return 0;
        uint256[] memory binding_ = _packBinding(pairAmts_, 0);
        lpOut_ = _joinUnbalanced(binding_, _bondLpHolder());
    }

    function claimLiquidity(uint256 lpAmount_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 amountOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        address bond_ = address(s.bondNftVault);
        address claim_ = address(s.rebasingClaimToken);
        if (msg.sender != bond_ && msg.sender != claim_ && msg.sender != address(this)) {
            revert Repo.NotAuthorized(msg.sender);
        }
        if (lpAmount_ == 0) revert Repo.ZeroAmount();
        _pullBondLp(lpAmount_);
        uint256[] memory binding_ = _exitProportional(lpAmount_, address(this));
        (uint256 aDetf_, uint256[] memory pairAmts_) = _unpackBinding(binding_);
        _redepositDetfSelfLeg(aDetf_);
        // Default claimLiquidity payout: first pair token (no whole-DETF rateAsset).
        address pay_ = address(s.pairTokens[0]);
        amountOut_ = _consolidateToPair(pay_, pairAmts_);
        if (amountOut_ > 0) {
            IERC20(pay_).safeTransfer(recipient_ == address(0) ? msg.sender : recipient_, amountOut_);
        }
    }

    function compoundProtocolRewards()
        public
        virtual
        nonReentrant
        returns (uint256 detfIn_, uint256 lpOut_)
    {
        return _tryCompoundProtocolRewards();
    }
}
