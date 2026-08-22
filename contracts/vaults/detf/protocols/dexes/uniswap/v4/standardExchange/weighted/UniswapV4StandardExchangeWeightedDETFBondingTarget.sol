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
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {DETFChildTokenMetadata} from "contracts/vaults/detf/common/DETFChildTokenMetadata.sol";
import {
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
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

/// @title UniswapV4StandardExchangeWeightedDETFBondingTarget
/// @notice First bond (all externals + capitalToken + refund), later single-external bonds,
///         mature-only sell/close, claim deposit/redeem, compound.
/// @dev Option 1e: sibling of Exchange Targets under Common (not Bonding→In→Out tower).
abstract contract UniswapV4StandardExchangeWeightedDETFBondingTarget is UniswapV4StandardExchangeWeightedDETFCommon {
    using BetterSafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                                Bond                                    */
    /* ---------------------------------------------------------------------- */

    /// @notice Multi-leg bond surface.
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
            try IWeightedDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}
            if (tokenIns_.length != 1) revert Repo.LaterBondSingleExternalOnly();
            return _bondSingle(
                tokenIns_[0], amountsIn_[0], lockDuration_, recipient_, pretransferred_, deadline_
            );
        }
        // First bond: all m externals required.
        return _firstBond(
            tokenIns_, amountsIn_, capitalToken_, lockDuration_, recipient_, pretransferred_, deadline_
        );
    }

    /// @notice Single-token convenience bond.
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
        try IWeightedDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}
        return _bondSingle(tokenIn_, amountIn_, lockDuration_, recipient_, pretransferred_, deadline_);
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

        // Settle each input to product-order pair notionals.
        uint256[] memory pairNatives_ = new uint256[](s.m);
        for (uint256 k; k < tokenIns_.length; ++k) {
            if (amountsIn_[k] == 0) continue;
            PairLegRating memory r_ =
                _settleToPairLeg(tokenIns_[k], amountsIn_[k], pretransferred_, deadline_);
            pairNatives_[r_.fundedProductIndex] += r_.pairNotionalNative;
        }
        // Require all externals funded.
        for (uint8 i; i < s.m; ++i) {
            if (pairNatives_[i] == 0) revert Repo.FirstBondRequiresAllExternalPairs();
        }

        // Size join DETF from min opening-rate DETF across legs; refund excess pair capital.
        uint256 detfForJoin_ = type(uint256).max;
        for (uint8 i; i < s.m; ++i) {
            uint256 detfFrom_ = Math.mulDiv(
                _toWad(pairNatives_[i], _decimalsOf(address(s.pairTokens[i]))),
                ONE_WAD,
                s.openingPairPerDetfWad[i]
            );
            if (detfFrom_ < detfForJoin_) detfForJoin_ = detfFrom_;
        }
        if (detfForJoin_ == 0 || detfForJoin_ == type(uint256).max) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }

        // Clamp pair amounts used; refund excess to caller.
        uint256[] memory usedPairs_ = new uint256[](s.m);
        for (uint8 i; i < s.m; ++i) {
            uint8 dec_ = _decimalsOf(address(s.pairTokens[i]));
            uint256 neededWad_ = Math.mulDiv(detfForJoin_, s.openingPairPerDetfWad[i], ONE_WAD);
            uint256 neededNative_ = _fromWadFloor(neededWad_, dec_);
            if (neededNative_ > pairNatives_[i]) neededNative_ = pairNatives_[i];
            usedPairs_[i] = neededNative_;
            uint256 excess_ = pairNatives_[i] - neededNative_;
            if (excess_ > 0) {
                s.pairTokens[i].safeTransfer(msg.sender, excess_);
            }
        }

        // D16/D24: opening-rate G, no D8 bonus. L1+D4 pot after D2.
        _mintDetf(address(this), detfForJoin_);
        uint256[] memory binding_ = _packBinding(usedPairs_, detfForJoin_);
        (shares_,) = _joinProportional(binding_, _bondLpHolder());
        if (shares_ == 0 || shares_ < HOOK_MINIMUM_LIQUIDITY) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }
        if (!IHook(s.reserveHook).isFullBook()) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }

        Repo._setReserveLive();
        MintSplit memory split_ = _splitBondDetf(detfForJoin_);
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);

        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        Repo._setCapitalToken(tokenId_, capitalToken_);
        Repo._addUserBondedLp(shares_);
        _topUpFeeCreatorShares();
        _creditBondPot(split_.inventoryDetf);
        emit IUniswapV4StandardExchangeWeightedDETF.ReserveLive(tokenId_, shares_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _bondSingle(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        // Live: no synthetic mint gate; exactly one external. D24 unboosted G.
        PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
        uint256 g_ = _quoteUnboostedBondJoin(r_);
        MintSplit memory split_ = _splitBondDetf(g_);
        shares_ = _liveBondJoinSingle(r_, g_);
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);

        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        address cap_ = address(Repo._layoutStruct().pairTokens[r_.fundedProductIndex]);
        Repo._setCapitalToken(tokenId_, cap_);
        Repo._addUserBondedLp(shares_);
        _topUpFeeCreatorShares();
        _creditBondPot(split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _quoteUnboostedBondJoin(PairLegRating memory r_) internal view returns (uint256 detfForJoin_) {
        detfForJoin_ = _quoteDetfAgainstReserve(r_.fundedProductIndex, r_.pairNotionalNative);
        if (detfForJoin_ == 0) {
            Repo.Storage storage s = Repo._layoutStruct();
            detfForJoin_ = Math.mulDiv(
                _toWad(r_.pairNotionalNative, _decimalsOf(address(s.pairTokens[r_.fundedProductIndex]))),
                ONE_WAD,
                s.creationPairPerDetfWad[r_.fundedProductIndex]
            );
        }
    }

    function _liveBondJoinSingle(PairLegRating memory r_, uint256 detfForJoin_)
        internal
        returns (uint256 lpOut_)
    {
        address pair_ = address(Repo._layoutStruct().pairTokens[r_.fundedProductIndex]);
        address holder_ = _bondLpHolder();

        if (_isSingleAssetEligible()) {
            uint256 lpPair_ = _depositSingle(pair_, r_.pairNotionalNative, holder_);
            _mintDetf(address(this), detfForJoin_);
            uint256 lpDetf_ = detfForJoin_ > 0 ? _depositSingle(address(this), detfForJoin_, holder_) : 0;
            lpOut_ = lpPair_ + lpDetf_;
        } else {
            Repo.Storage storage s2 = Repo._layoutStruct();
            uint256[] memory pairAmts_ = new uint256[](s2.m);
            pairAmts_[r_.fundedProductIndex] = r_.pairNotionalNative;
            _mintDetf(address(this), detfForJoin_);
            uint256[] memory binding_ = _packBinding(pairAmts_, detfForJoin_);
            lpOut_ = _joinUnbalanced(binding_, holder_);
        }
    }

    function _openBondNft(uint256 lpOut_, uint256 lockDuration_, address recipient_)
        private
        returns (uint256 tokenId_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return 0;
        uint256 lock_ = _effectiveLockDuration(lockDuration_);
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
            lpOut_,
            lock_,
            recipient_
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Mature-only sell / close                       */
    /* ---------------------------------------------------------------------- */

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

        try IWeightedDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}

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
        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(principalShares_);
        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function joinDonatedCapital(IERC20 token_, uint256 amount_, uint256 deadline_)
        external
        nonReentrant
        returns (uint256 lpOut_)
    {
        _requireBondNft();
        _requireNotDisabled();
        _requireReserveLive();
        _requireActive(deadline_, amount_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(token_) == s.reserveHook) {
            revert Repo.InvalidRoute(token_, IERC20(address(this)));
        }
        if (address(token_) == address(this)) {
            uint256 pulled_ = _pullToken(token_, amount_, false);
            lpOut_ = _depositSingle(address(this), pulled_, _bondLpHolder());
        } else {
            PairLegRating memory r_ = _settleToPairLeg(token_, amount_, false, deadline_);
            address pair_ = address(s.pairTokens[r_.fundedProductIndex]);
            lpOut_ = _depositSingle(pair_, r_.pairNotionalNative, _bondLpHolder());
        }
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        _syncAllExpectedHoldReserves();
    }

    function previewJoinDonatedCapital(IERC20 token_, uint256 amount_)
        external
        view
        returns (uint256 lpOut_)
    {
        return _previewJoinDonatedCapital(token_, amount_);
    }

    function notifyReserveDonated() external {
        _requireBondNft();
        _topUpFeeCreatorShares();
    }

    function donate(IERC20 token_, uint256 amount_, bool pretransferred_) external {
        _requireNotDisabled();
        Repo.Storage storage s = Repo._layoutStruct();
        address nft_ = address(s.bondNftVault);
        if (nft_ == address(0)) revert Repo.ReserveBondNftNotWired();
        IDetfNftReserveDonation(nft_).donate(
            msg.sender, token_, amount_, 0, pretransferred_, block.timestamp + 1
        );
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
        if (minAmountsOut_.length != s.n) revert Repo.InvalidRoute(IERC20(address(0)), IERC20(address(0)));
        if (minAmountsOut_[s.detfBindingIndex] != 0) {
            revert Repo.InvalidRoute(IERC20(address(this)), IERC20(address(0)));
        }

        try IWeightedDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}

        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId_);
        uint256 lp_ = s.bondNftVault.convertToAssets(orig_);
        if (lp_ == 0) revert Repo.ZeroAmount();
        _pullBondLp(lp_);
        s.bondNftVault.retireMaturePosition(tokenId_, recipient_);

        uint256[] memory residual_ = _exitProportional(lp_, address(this));
        amountsOut_ = new uint256[](s.n);
        uint256 detfOut_ = residual_[s.detfBindingIndex];
        if (detfOut_ > 0) {
            uint256 lpRejoin_ = _depositSingleDetfUntilDust(detfOut_, _bondLpHolder());
            if (lpRejoin_ == 0) revert Repo.ZeroAmount();
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpRejoin_);
            _topUpFeeCreatorShares();
        }
        for (uint8 i; i < s.n; ++i) {
            if (i == s.detfBindingIndex) continue;
            uint256 amt_ = residual_[i];
            if (amt_ < minAmountsOut_[i]) {
                revert Repo.SlippageExceeded(minAmountsOut_[i], amt_);
            }
            amountsOut_[i] = amt_;
            if (amt_ > 0) {
                IERC20(_tokenAtBinding(i)).safeTransfer(recipient_, amt_);
            }
        }

        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(lp_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
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
                DETFChildTokenMetadata.resolveBondName(s.bondName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveBondSymbol(s.bondSymbol, ERC20Repo._symbol()),
                IDetf(detf_),
                IERC20(s.reserveHook),
                IERC20(detf_),
                0,
                detf_
            )
        );
        address feeTo_ = address(s.feeOracle.feeTo());
        uint256 detfNftId_;
        try bondVault_.initializeReservedBondNfts(feeTo_, s.creator) returns (uint256 id_) {
            detfNftId_ = id_;
        } catch {
            try bondVault_.initializeDETFNFT() returns (uint256 id2_) {
                detfNftId_ = id2_;
            } catch {
                detfNftId_ = 0;
            }
        }
        Repo._setBondNft(bondVault_, detfNftId_, DETF_FEE_TO_BOND_NFT_ID);
        emit IUniswapV4StandardExchangeWeightedDETF.ReserveBondNftWired(
            s.reserveHook, address(bondVault_), detfNftId_, DETF_FEE_TO_BOND_NFT_ID
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
                IDetf(detf_),
                s.bondNftVault,
                s.pairTokens[0],
                s.detfNftId,
                detf_,
                DETFChildTokenMetadata.resolveClaimName(s.claimName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveClaimSymbol(s.claimSymbol, ERC20Repo._symbol())
            )
        );
        Repo._setClaim(claimToken_);
        emit IUniswapV4StandardExchangeWeightedDETF.ReserveClaimWired(s.reserveHook, address(claimToken_));
        return address(claimToken_);
    }
}
