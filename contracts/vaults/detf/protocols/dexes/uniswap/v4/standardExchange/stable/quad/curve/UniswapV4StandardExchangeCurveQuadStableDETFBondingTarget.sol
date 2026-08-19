// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFCommon,
    IQuadDetfCompoundSelf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFCommon.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/// @title UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget
/// @notice First bond (all three + capitalToken + refund), later single-pair joinUnbalanced,
///         mature-only sell/close.
abstract contract UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget is
    UniswapV4StandardExchangeCurveQuadStableDETFCommon
{
    using BetterSafeERC20 for IERC20;

    function bond(
        IERC20[] calldata tokenIns_,
        uint256[] calldata amountsIn_,
        address capitalToken_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _requireNotDisabled();
        if (block.timestamp > deadline_) revert Repo.DeadlineExpired(deadline_);
        if (tokenIns_.length != amountsIn_.length) revert Repo.ZeroAmount();

        if (Repo._layoutStruct().isReserveLive) {
            try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}
            if (tokenIns_.length != 1) revert Repo.LaterBondSinglePairOnly();
            return _bondSingle(
                tokenIns_[0],
                amountsIn_[0],
                capitalToken_,
                lockDuration_,
                recipient_,
                pretransferred_,
                deadline_
            );
        }
        return _firstBond(
            tokenIns_, amountsIn_, capitalToken_, lockDuration_, recipient_, pretransferred_, deadline_
        );
    }

    function bond(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _requireNotDisabled();
        _requireActive(deadline_, amountIn_);
        if (!Repo._layoutStruct().isReserveLive) {
            revert Repo.FirstBondRequiresAllExternalPairs();
        }
        try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}
        return _bondSingle(
            tokenIn_, amountIn_, address(0), lockDuration_, recipient_, pretransferred_, deadline_
        );
    }

    function _firstBond(
        IERC20[] calldata tokenIns_,
        uint256[] calldata amountsIn_,
        address capitalToken_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        _requireReserveWired();
        Repo.Storage storage s = Repo._layoutStruct();
        if (!Repo._isPairToken(capitalToken_)) revert Repo.InvalidCapitalToken();
        _rejectPretransferredFirstBond(pretransferred_, amountsIn_);

        uint256[] memory pairNatives_ = new uint256[](s.m);
        for (uint256 k; k < tokenIns_.length; ++k) {
            if (amountsIn_[k] == 0) continue;
            PairLegRating memory r_ =
                _settleToPairLeg(tokenIns_[k], amountsIn_[k], pretransferred_, deadline_);
            pairNatives_[r_.fundedProductIndex] += r_.pairNotionalNative;
        }
        for (uint8 i; i < s.m; ++i) {
            if (pairNatives_[i] == 0) revert Repo.FirstBondRequiresAllExternalPairs();
        }

        uint256 detfForJoin_ = type(uint256).max;
        for (uint8 i; i < s.m; ++i) {
            uint256 detfFrom_ = Math.mulDiv(
                _toWad(pairNatives_[i], _decimalsOf(address(s.pairTokens[i]))),
                ONE_WAD,
                s.creationPairPerDetfWad[i]
            );
            if (detfFrom_ < detfForJoin_) detfForJoin_ = detfFrom_;
        }
        if (detfForJoin_ == 0 || detfForJoin_ == type(uint256).max) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }

        uint256[] memory usedPairs_ = new uint256[](s.m);
        for (uint8 i; i < s.m; ++i) {
            uint8 dec_ = _decimalsOf(address(s.pairTokens[i]));
            uint256 neededWad_ = Math.mulDiv(detfForJoin_, s.creationPairPerDetfWad[i], ONE_WAD);
            uint256 neededNative_ = _fromWadFloor(neededWad_, dec_);
            if (neededNative_ > pairNatives_[i]) neededNative_ = pairNatives_[i];
            usedPairs_[i] = neededNative_;
            uint256 excess_ = pairNatives_[i] - neededNative_;
            if (excess_ > 0) {
                s.pairTokens[i].safeTransfer(msg.sender, excess_);
            }
        }

        _mintDetf(address(this), detfForJoin_);
        uint256[] memory binding_ = _packBinding(usedPairs_, detfForJoin_);
        (shares_,) = _joinProportional(binding_, _bondLpHolder());
        if (shares_ == 0 || shares_ < HOOK_MINIMUM_LIQUIDITY) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }
        if (!IHook(s.reserveHook).isFullBook()) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }

        MintSplit memory split_ = _splitBondDetf(detfForJoin_);
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);

        Repo._setReserveLive();
        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        Repo._setCapitalToken(tokenId_, capitalToken_);
        Repo._addUserBondedLp(shares_);
        emit IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveLive(tokenId_, shares_);

        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _bondSingle(
        IERC20 tokenIn_,
        uint256 amountIn_,
        address capitalToken_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
        address fundedPair_ = address(Repo._layoutStruct().pairTokens[r_.fundedProductIndex]);
        if (capitalToken_ != address(0) && capitalToken_ != fundedPair_) {
            revert Repo.InvalidCapitalToken();
        }
        uint256 detfForJoin_ = _quoteBondJoinDetf(r_.fundedProductIndex, r_.pairNotionalNative);
        if (detfForJoin_ == 0) revert Repo.ZeroAmount();
        MintSplit memory split_ = _splitBondDetf(detfForJoin_);

        Repo.Storage storage s2 = Repo._layoutStruct();
        uint256[] memory pairAmts_ = new uint256[](s2.m);
        pairAmts_[r_.fundedProductIndex] = r_.pairNotionalNative;
        _mintDetf(address(this), detfForJoin_);
        uint256[] memory binding_ = _packBinding(pairAmts_, detfForJoin_);
        shares_ = _joinUnbalanced(binding_, _bondLpHolder());
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);

        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        Repo._setCapitalToken(tokenId_, fundedPair_);
        Repo._addUserBondedLp(shares_);
        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0) _mintDetf(address(s2.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _openBondNft(uint256 lpOut_, uint256 lockDuration_, address recipient_)
        private
        returns (uint256 tokenId_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return 0;
        uint256 lock_ = _effectiveLockDuration(lockDuration_);
        uint256 orig_ = _originalSharesForBondLp(lpOut_);
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), orig_, lock_, recipient_
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

        try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}

        uint256 protocolBefore_ = _protocolOriginalShares();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        principalShares_ = DETFBondLifecycleLib._sellPositionToDetfNft(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
        );
        if (address(s.rebasingClaimToken) != address(0) && assets_ > 0) {
            s.rebasingClaimToken.mintFromNFTSale(assets_, protocolBefore_, recipient_);
        }
        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(principalShares_);
        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
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
        if (minAmountsOut_.length != s.n) {
            revert Repo.InvalidRoute(IERC20(address(0)), IERC20(address(0)));
        }
        if (minAmountsOut_[s.detfBindingIndex] != 0) {
            revert Repo.InvalidRoute(IERC20(address(this)), IERC20(address(0)));
        }

        try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}

        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId_);
        uint256 lpOut_ = s.bondNftVault.convertToAssets(orig_);
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        s.bondNftVault.retireMaturePosition(tokenId_, recipient_);

        _pullBondLp(lpOut_);
        uint256[] memory withdrawn_ = _exitProportional(lpOut_, address(this));
        uint256 detfOut_ = withdrawn_[s.detfBindingIndex];
        if (detfOut_ > 0) _burnDetf(address(this), detfOut_);

        amountsOut_ = new uint256[](s.n);
        for (uint8 i; i < s.n; ++i) {
            if (i == s.detfBindingIndex) continue;
            uint256 amt_ = withdrawn_[i];
            if (amt_ < minAmountsOut_[i]) {
                revert Repo.InvalidRoute(IERC20(_tokenAtBinding(i)), IERC20(address(0)));
            }
            amountsOut_[i] = amt_;
            if (amt_ > 0) IERC20(_tokenAtBinding(i)).safeTransfer(recipient_, amt_);
        }

        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(lpOut_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function previewCloseBondMature(uint256 tokenId_)
        external
        view
        returns (uint256[] memory amountsOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        amountsOut_ = new uint256[](s.n);
        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (orig_ == 0) return amountsOut_;
        uint256 lpOut_ = s.bondNftVault.convertToAssets(orig_);
        if (lpOut_ == 0) return amountsOut_;
        try IHook(s.reserveHook).previewExitProportional(lpOut_) returns (uint256[] memory withdrawn_) {
            if (withdrawn_.length != s.n) return amountsOut_;
            for (uint8 i; i < s.n; ++i) {
                if (i == s.detfBindingIndex) continue;
                amountsOut_[i] = withdrawn_[i];
            }
        } catch {}
    }

    function completeReserveBondNft() public returns (address bondNftVault) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.reserveHook == address(0)) revert Repo.ReserveHookNotFinalized();
        try IUniswapV4HookStagedPairInit(s.reserveHook).isInitializationFinalized() returns (bool done_) {
            if (!done_) revert Repo.ReserveHookNotFinalized();
        } catch {
            // unmatched selector after finalize = finalized
        }
        if (address(s.bondNftVault) != address(0)) revert Repo.ReserveBondNftAlreadyWired();

        address detf_ = address(this);
        IDETFNFTVault bondVault_ = IDETFNFTVault(
            IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg).deployVault(
                string(abi.encodePacked(ERC20Repo._name(), " Bond")),
                string(abi.encodePacked(ERC20Repo._symbol(), "-BOND")),
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
        uint256 feeRecipientNftId_ = 1;
        Repo._setBondNft(bondVault_, detfNftId_, feeRecipientNftId_);
        emit IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveBondNftWired(
            s.reserveHook, address(bondVault_), detfNftId_, feeRecipientNftId_
        );
        return address(bondVault_);
    }

    function completeReserveClaim() public returns (address rebasingClaimToken) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) revert Repo.ReserveBondNftNotWired();
        if (address(s.rebasingClaimToken) != address(0)) revert Repo.ReserveClaimAlreadyWired();

        address detf_ = address(this);
        IRebasingClaimToken claimToken_ = IRebasingClaimToken(
            IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg).deployToken(
                IDetf(detf_), s.bondNftVault, s.pairTokens[0], s.detfNftId, detf_
            )
        );
        Repo._setClaim(claimToken_);
        emit IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveClaimWired(
            s.reserveHook, address(claimToken_)
        );
        return address(claimToken_);
    }
}
