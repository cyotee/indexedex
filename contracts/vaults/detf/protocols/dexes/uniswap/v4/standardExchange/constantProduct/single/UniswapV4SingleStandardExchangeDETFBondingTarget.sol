// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETF_FEE_TO_BOND_NFT_ID} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {DETFChildTokenMetadata} from "contracts/vaults/detf/common/DETFChildTokenMetadata.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as HookRepo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @title UniswapV4SingleStandardExchangeDETFBondingTarget
/// @notice Bond with pair/share/SE token. First bond bootstraps at opening (permissionless).
/// @dev Live bonds: no synthetic gate; realize expansion then reward update.
abstract contract UniswapV4SingleStandardExchangeDETFBondingTarget is
    UniswapV4SingleStandardExchangeDETFCommon,
    IUniswapV4SingleStandardExchangeDETF
{
    using BetterSafeERC20 for IERC20;

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

        Repo.Storage storage s = Repo._layoutStruct();
        if (s.isReserveLive) {
            _realizeExpansionIfNeeded();
        } else {
            _rejectPretransferredFirstBond(pretransferred_, amountIn_);
            _requireReserveWired();
        }

        uint256 pairAmount_ = _settleToPair(tokenIn_, amountIn_, pretransferred_, deadline_);
        // D24 unboosted join `G`. Empty book uses openingPairPerDetfWad. L1 free U=G then D3+D4 pot.
        uint256 detfForPool_ = _quoteBondJoinDetf(pairAmount_);
        if (detfForPool_ == 0) revert Repo.FirstBondBelowMinimumLiquidity();
        MintSplit memory split_ = _splitBondDetf(detfForPool_);

        _mintDetf(address(this), detfForPool_);
        shares_ = _depositProportional(detfForPool_, pairAmount_, _bondLpHolder());
        if (!s.isReserveLive) {
            if (shares_ == 0 || shares_ < HookRepo.MINIMUM_LIQUIDITY) {
                revert Repo.FirstBondBelowMinimumLiquidity();
            }
        }

        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);

        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        Repo._addUserBondedLp(shares_);

        if (!s.isReserveLive) {
            Repo._setReserveLive();
            emit ReserveLive(tokenId_, shares_);
        }

        // D2 after createPosition, before pot mint, so ids 1–2 take this bond's pot at the new weights.
        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0 && address(s.bondNftVault) != address(0)) {
            _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        }
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _openBondNft(uint256 lpOut_, uint256 lockDuration_, address recipient_)
        private
        returns (uint256 tokenId_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || lpOut_ == 0) return 0;
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
            lpOut_,
            _effectiveLockDuration(lockDuration_),
            recipient_
        );
    }

    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        _requireMature(tokenId_);
        _requireNotStandingRewardNft(tokenId_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        // D10: transfer originalShares to id 0. Physical LP stays on the NFT vault (D13).
        if (address(s.rebasingClaimToken) == address(0)) {
            principalShares_ = DETFBondLifecycleLib._sellPositionToDetfNft(
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
            );
        } else {
            (principalShares_,) = DETFBondLifecycleLib._sellPositionToRebasingClaim(
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
                s.rebasingClaimToken,
                tokenId_,
                msg.sender,
                recipient_
            );
        }
        Repo._subUserBondedLp(principalShares_);
        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETF
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

        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        if (address(tokenOut_) != address(this)) {
            revert Repo.InvalidRoute(IERC20(address(s.rebasingClaimToken)), tokenOut_);
        }

        uint256 lpOut_ = _burnClaimConvertToAssets(claimAmount_);
        uint256 owed_ = _previewProportionalDetf(lpOut_);
        uint256 harvested_ = s.bondNftVault.reallocateDetfNftRewards(address(this));

        if (harvested_ >= owed_) {
            amountOut_ = owed_;
            uint256 leftover_ = harvested_ - owed_;
            if (leftover_ > 0) {
                uint256 lpBack_ = _depositSingleDetf(leftover_, _bondLpHolder());
                if (lpBack_ > 0) {
                    s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpBack_);
                }
            }
            if (lpOut_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpOut_);
            }
        } else {
            _pullNftLp(lpOut_);
            (uint256 detfFromLp_, uint256 pairOut_) = _withdrawProportional(lpOut_);
            uint256 shortfall_ = owed_ - harvested_;
            uint256 fromLp_ = detfFromLp_ < shortfall_ ? detfFromLp_ : shortfall_;
            amountOut_ = harvested_ + fromLp_;
            uint256 leftoverDetf_ = detfFromLp_ - fromLp_;
            uint256 lpBack_;
            if (leftoverDetf_ > 0 && pairOut_ > 0) {
                lpBack_ = _depositProportional(leftoverDetf_, pairOut_, _bondLpHolder());
            } else if (leftoverDetf_ > 0) {
                lpBack_ = _depositSingleDetf(leftoverDetf_, _bondLpHolder());
            } else if (pairOut_ > 0) {
                lpBack_ = _depositSinglePair(pairOut_, _bondLpHolder());
            }
            if (lpBack_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpBack_);
            }
        }

        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
        if (amountOut_ > 0) {
            IERC20(address(this)).safeTransfer(recipient_, amountOut_);
        }
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    function previewRedeemClaim(uint256 claimAmount_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        if (claimAmount_ == 0) return 0;
        if (address(tokenOut_) != address(this)) return 0;
        uint256 lpOut_ = _previewClaimLpOut(claimAmount_);
        amountOut_ = _previewProportionalDetf(lpOut_);
    }

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
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _pullToken(IERC20(address(this)), detfAmount_, pretransferred_);
        uint256 lpIn_ = _depositSingleDetf(detfAmount_, _bondLpHolder());
        if (lpIn_ == 0) revert Repo.ZeroAmount();

        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(lpIn_, recipient_);
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpIn_);
        if (claimMinted_ < minClaimOut_) {
            revert Repo.InvalidRoute(IERC20(address(s.rebasingClaimToken)), IERC20(address(0)));
        }

        _topUpFeeCreatorShares();
        _realizeExpansionIfNeeded();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function previewBuyClaim(uint256 detfAmount_) external view returns (uint256 claimMinted_) {
        if (detfAmount_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 lpIn_ = IHook(s.reserveHook).previewDepositSingle(address(this), detfAmount_);
        claimMinted_ = _previewClaimMinted(lpIn_, _protocolOriginalShares());
    }

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

        Repo.Storage storage s = Repo._layoutStruct();
        if (minAmountsOut_.length != 2) {
            revert Repo.InvalidRoute(IERC20(address(0)), IERC20(address(0)));
        }
        if (minAmountsOut_[0] != 0) {
            revert Repo.InvalidRoute(IERC20(address(this)), IERC20(address(0)));
        }

        _realizeExpansionIfNeeded();

        uint256 lpOut_ = s.bondNftVault.convertToAssets(s.bondNftVault.originalSharesOf(tokenId_));
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId_);
        s.bondNftVault.retireMaturePosition(tokenId_, recipient_);
        Repo._subUserBondedLp(orig_);

        _pullNftLp(lpOut_);
        (uint256 detfOut_, uint256 pairOut_) = _withdrawProportional(lpOut_);
        if (detfOut_ > 0) {
            _burnDetf(address(this), detfOut_);
        }
        if (pairOut_ < minAmountsOut_[1]) {
            revert Repo.InvalidRoute(s.pairToken, IERC20(address(0)));
        }
        if (pairOut_ > 0) {
            s.pairToken.safeTransfer(recipient_, pairOut_);
        }

        amountsOut_ = new uint256[](2);
        amountsOut_[1] = pairOut_;

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function previewCloseBondMature(uint256 tokenId_)
        external
        view
        returns (uint256[] memory amountsOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        amountsOut_ = new uint256[](2);
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (assets_ == 0) return amountsOut_;
        uint256 lpOut_ = s.bondNftVault.convertToAssets(assets_);
        (, uint256 pairOut_) = _previewProportional(lpOut_);
        amountsOut_[1] = pairOut_;
    }

    function _burnClaimConvertToAssets(uint256 claimAmount_) private returns (uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 totalSharesBefore_ = s.rebasingClaimToken.totalShares();
        uint256 sharesBurned_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (sharesBurned_ == 0) revert Repo.ZeroAmount();
        uint256 totalAssets_ = _protocolOriginalShares();
        uint256 totalShares_ = totalSharesBefore_ == 0 ? sharesBurned_ : totalSharesBefore_;
        lpOut_ = (sharesBurned_ * totalAssets_) / totalShares_;
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), lpOut_);
    }

    function _previewClaimLpOut(uint256 claimAmount_) private view returns (uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 shares_ = s.rebasingClaimToken.convertToShares(claimAmount_);
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 totalAssets_ = _protocolOriginalShares();
        if (shares_ == 0 || totalShares_ == 0) return 0;
        lpOut_ = (shares_ * totalAssets_) / totalShares_;
    }

    function _previewClaimMinted(uint256 assets_, uint256 totalAssets_) private view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 sharesOut_ = totalAssets_ == 0 ? assets_ : (assets_ * totalShares_) / totalAssets_;
        return s.rebasingClaimToken.convertToClaim(sharesOut_);
    }

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETF
    function claimLiquidity(uint256 lpAmount_, address recipient_)
        external
        nonReentrant
        returns (uint256 pairOut_)
    {
        // _claimLiquidity ends with _syncAllExpectedHoldReserves (pair leave diamond).
        return _claimLiquidity(lpAmount_, recipient_);
    }

    /// @notice Realize expansion then harvest free DETF for the bond holder.
    /// @dev Holder must be `msg.sender`. Harvest is invoked on the NFT vault; the vault
    ///      authorizes the DETF owner for owner-initiated harvests only for protocol id —
    ///      so user harvest is expected via the NFT surface. This path realizes debt first,
    ///      then attempts NFT claim (works when NFT allows DETF-or-holder; otherwise use NFT).
    function claimRewards(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 rewards_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _realizeExpansionIfNeeded();
        // L-REW-1: owner-only; non-owner reverts (no soft-success).
        address holder_ = s.bondNftVault.ownerOf(tokenId_);
        if (msg.sender != holder_) {
            revert Repo.NotAuthorized(msg.sender);
        }
        // L-REW-2/3: no try/catch soft-fail; return 0 only when allowed and zero rewards.
        rewards_ = s.bondNftVault.claimRewards(tokenId_, recipient_);
        _tryCompoundProtocolRewards();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Info surface (interface)                       */
    /* ---------------------------------------------------------------------- */

    function isReserveLive() external view returns (bool) {
        return Repo._layoutStruct().isReserveLive;
    }

    function standardExchangeVault() external view returns (address) {
        return address(Repo._layoutStruct().standardExchangeVault);
    }

    function standardExchangeVaultShare() external view returns (address) {
        return address(Repo._layoutStruct().standardExchangeVaultShare);
    }

    function pairToken() external view returns (address) {
        return address(Repo._layoutStruct().pairToken);
    }

    function reserveHook() external view returns (address) {
        return Repo._layoutStruct().reserveHook;
    }

    function reservePool() external view returns (address) {
        return Repo._layoutStruct().reserveHook;
    }

    function syntheticPrice() external view returns (uint256) {
        return _syntheticPrice();
    }

    function pendingExpansionDetf() external view returns (uint256) {
        return _previewPendingExpansionMint();
    }

    function mintThreshold() external view returns (uint256) {
        return Repo._layoutStruct().mintThreshold;
    }

    function burnThreshold() external view returns (uint256) {
        return Repo._layoutStruct().burnThreshold;
    }

    function thresholdMode() external view returns (ThresholdMode) {
        return Repo._layoutStruct().thresholdMode;
    }

    function isMintingAllowed() external view returns (bool) {
        return _isMintingAllowed();
    }

    function isBurningAllowed() external view returns (bool) {
        return _isBurningAllowed();
    }

    function bondNftVault() external view returns (address) {
        return address(Repo._layoutStruct().bondNftVault);
    }

    function rebasingClaimToken() external view returns (address) {
        return address(Repo._layoutStruct().rebasingClaimToken);
    }

    function feeRecipientNftId() external view returns (uint256) {
        return Repo._layoutStruct().feeRecipientNftId;
    }

    function creationPairPerDetfWad() external view returns (uint256) {
        return Repo._layoutStruct().creationPairPerDetfWad;
    }

    function openingPairPerDetfWad() external view returns (uint256) {
        return Repo._layoutStruct().openingPairPerDetfWad;
    }

    function lastExpansionTimestamp() external view returns (uint256) {
        return Repo._layoutStruct().lastExpansionTimestamp;
    }

    function expansionEpochLength() external view returns (uint256) {
        return Repo._layoutStruct().expansionEpochLength;
    }

    function expansionClosureRatePerYearWad() external view returns (uint256) {
        return Repo._layoutStruct().expansionClosureRatePerYearWad;
    }

    function expansionMaxCatchUpEpochs() external view returns (uint256) {
        return Repo._layoutStruct().expansionMaxCatchUpEpochs;
    }

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        Repo.Storage storage s = Repo._layoutStruct();
        tokens_ = new address[](2);
        tokens_[0] = address(s.pairToken);
        tokens_[1] = address(s.standardExchangeVaultShare);
    }

    function protocolLp() external view returns (uint256) {
        return _protocolLp();
    }

    function userBondedLp() external view returns (uint256) {
        return Repo._layoutStruct().userBondedLp;
    }

    function compoundProtocolRewards() external nonReentrant returns (uint256 detfIn, uint256 lpOut) {
        return _tryCompoundProtocolRewards();
    }

    function isReserveHookFinalized() public view returns (bool) {
        address hook_ = Repo._layoutStruct().reserveHook;
        if (hook_ == address(0)) return false;
        try IUniswapV4HookStagedPairInit(hook_).isInitializationFinalized() returns (bool done_) {
            return done_;
        } catch {
            return true;
        }
    }

    function isReserveWired() public view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        return address(s.bondNftVault) != address(0) && address(s.rebasingClaimToken) != address(0);
    }

    function completeReserveBondNft() public returns (address bondNftVault) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.reserveHook == address(0) || !isReserveHookFinalized()) {
            revert Repo.ReserveHookNotFinalized();
        }
        if (address(s.bondNftVault) != address(0)) revert Repo.ReserveBondNftAlreadyWired();

        address detf_ = address(this);
        IDETFNFTVault bondVault_ = IDETFNFTVault(
            IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg).deployVault(
                DETFChildTokenMetadata.resolveBondName(s.bondName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveBondSymbol(s.bondSymbol, ERC20Repo._symbol()),
                IDetf(detf_),
                IERC20(s.reserveHook),
                IERC20(detf_),
                0,
                detf_
            )
        );
        uint256 detfNftId_;
        address feeTo_ = address(s.feeOracle.feeTo());
        address creator_ = s.creator;
        try bondVault_.initializeReservedBondNfts(feeTo_, creator_) returns (uint256 id_) {
            detfNftId_ = id_;
        } catch {
            try bondVault_.initializeDETFNFT() returns (uint256 id2_) {
                detfNftId_ = id2_;
            } catch {
                detfNftId_ = 0;
            }
        }
        uint256 feeRecipientNftId_ = DETF_FEE_TO_BOND_NFT_ID;
        Repo._setBondNft(bondVault_, detfNftId_, feeRecipientNftId_);
        emit ReserveBondNftWired(s.reserveHook, address(bondVault_), detfNftId_, feeRecipientNftId_);
        return address(bondVault_);
    }

    function completeReserveClaim() public returns (address rebasingClaimToken) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) revert Repo.ReserveBondNftNotWired();
        if (address(s.rebasingClaimToken) != address(0)) revert Repo.ReserveClaimAlreadyWired();

        address detf_ = address(this);
        IRebasingClaimToken claimToken_ = IRebasingClaimToken(
            IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg).deployToken(
                IDetf(detf_),
                s.bondNftVault,
                s.pairToken,
                s.detfNftId,
                detf_,
                DETFChildTokenMetadata.resolveClaimName(s.claimName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveClaimSymbol(s.claimSymbol, ERC20Repo._symbol())
            )
        );
        Repo._setClaim(claimToken_);
        emit ReserveClaimWired(s.reserveHook, address(claimToken_));
        return address(claimToken_);
    }

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETF
    function previewClaimLiquidity(uint256 lpAmount_) public view returns (uint256 pairOut_) {
        if (lpAmount_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.reserveHook == address(0) || address(s.pairToken) == address(0)) return 0;
        return IHook(s.reserveHook).previewWithdrawSingle(lpAmount_, address(s.pairToken));
    }
}
