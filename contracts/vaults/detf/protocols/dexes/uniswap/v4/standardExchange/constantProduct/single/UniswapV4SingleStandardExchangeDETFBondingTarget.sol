// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as HookRepo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
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
/// @notice Bond with pair/share/SE token. First bond bootstraps at creation rate (permissionless).
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

        if (Repo._layoutStruct().isReserveLive) {
            _realizeExpansionIfNeeded();
        } else {
            _rejectPretransferredFirstBond(pretransferred_, amountIn_);
        }

        uint256 pairAmount_ = _settleToPair(tokenIn_, amountIn_, pretransferred_, deadline_);
        shares_ = _executeBondJoin(pairAmount_);
        _mintBondFreeLegs(pairAmount_, recipient_);
        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        Repo._addUserBondedLp(shares_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _executeBondJoin(uint256 pairAmount_) private returns (uint256 lpOut_) {
        if (!Repo._layoutStruct().isReserveLive) {
            lpOut_ = _firstBondJoin(pairAmount_);
            Repo._setReserveLive();
            emit ReserveLive(0, lpOut_);
        } else {
            lpOut_ = _liveBondJoin(pairAmount_);
        }
    }

    function _mintBondFreeLegs(uint256 pairAmount_, address recipient_) private {
        uint256 pairBoosted_ = Math.mulDiv(pairAmount_, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        MintSplit memory split_ = _splitMintedDetf(_quoteDetfAgainstReserve(pairBoosted_));
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        address bondVault_ = address(Repo._layoutStruct().bondNftVault);
        if (split_.inventoryDetf > 0 && bondVault_ != address(0)) {
            _mintDetf(bondVault_, split_.inventoryDetf);
        }
    }

    function _openBondNft(uint256 lpOut_, uint256 lockDuration_, address recipient_)
        private
        returns (uint256 tokenId_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return 0;
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
            lpOut_,
            _effectiveLockDuration(lockDuration_),
            recipient_
        );
    }

    /// @dev First bond at creation rate: mint join DETF from creationPairPerDetfWad, proportional deposit.
    ///      LP is minted to the bond NFT package (PRD LOCK: user bond LP on bond NFT).
    function _firstBondJoin(uint256 pairAmount_) internal returns (uint256 lpOut_) {
        _requireReserveWired();
        Repo.Storage storage s = Repo._layoutStruct();
        uint8 pairDec_ = _pairDecimals();
        uint256 pairWad_ = _toWad(pairAmount_, pairDec_);
        // detfForJoin = pair / creationRate (WAD) — boosted path not used for join sizing at first bond per PRD creation rate
        uint256 detfForJoin_ = Math.mulDiv(pairWad_, ONE_WAD, s.creationPairPerDetfWad);
        if (detfForJoin_ == 0) revert Repo.FirstBondBelowMinimumLiquidity();

        _mintDetf(address(this), detfForJoin_);
        lpOut_ = _depositProportional(detfForJoin_, pairAmount_, _bondLpHolder());
        if (lpOut_ == 0 || lpOut_ < HookRepo.MINIMUM_LIQUIDITY) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }
    }

    /// @dev Live bond: mint DETF join leg from quote against reserve; proportional deposit to bond NFT.
    function _liveBondJoin(uint256 pairAmount_) internal returns (uint256 lpOut_) {
        uint256 pairBoosted_ = Math.mulDiv(pairAmount_, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        uint256 detfForJoin_ = _quoteDetfAgainstReserve(pairBoosted_);
        if (detfForJoin_ == 0) {
            detfForJoin_ = Math.mulDiv(
                _toWad(pairAmount_, _pairDecimals()),
                ONE_WAD,
                Repo._layoutStruct().creationPairPerDetfWad
            );
        }
        _mintDetf(address(this), detfForJoin_);
        lpOut_ = _depositProportional(detfForJoin_, pairAmount_, _bondLpHolder());
    }

    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        // Physical migrate: bond NFT LP → rebasing claim package before ledger sell (PRD LOCK).
        principalShares_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (principalShares_ > 0 && address(s.rebasingClaimToken) != address(0)) {
            address claim_ = address(s.rebasingClaimToken);
            IERC20 lp_ = IERC20(s.reserveHook);
            uint256 bondBal_ = lp_.balanceOf(address(s.bondNftVault));
            uint256 move_ = principalShares_ < bondBal_ ? principalShares_ : bondBal_;
            if (move_ > 0) {
                s.bondNftVault.transferHeldToken(lp_, claim_, move_);
            }
        }

        if (address(s.rebasingClaimToken) == address(0)) {
            principalShares_ = DETFBondLifecycleLib._sellPositionToDetfNft(
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
            );
        } else {
            // Sell → protocol NFT principal ledger + mint rebasing claim (economic).
            (principalShares_,) = DETFBondLifecycleLib._sellPositionToRebasingClaim(
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
                s.rebasingClaimToken,
                tokenId_,
                msg.sender,
                recipient_
            );
        }
        // Move principal from userBonded accounting → protocol (LP now on claim package).
        Repo._subUserBondedLp(principalShares_);
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
        _requireReserveLive();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();

        // burnShares returns external principal LP units (minted 1:1 at sale).
        uint256 principalLp_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (principalLp_ == 0) revert Repo.ZeroAmount();

        uint256 protocolLp_ = _protocolLp();
        uint256 lpOut_ = principalLp_ < protocolLp_ ? principalLp_ : protocolLp_;
        if (lpOut_ == 0) revert Repo.EmptyProtocolLp();
        _pullProtocolLp(lpOut_);

        // Pair-only direct; share / SE token via pair → SE exchangeIn (pull, not pretransfer).
        if (address(tokenOut_) == address(s.pairToken)) {
            amountOut_ = _withdrawSinglePair(lpOut_, recipient_);
        } else if (
            address(tokenOut_) == address(s.standardExchangeVaultShare) || _isAllowlistedTokenIn(tokenOut_)
        ) {
            uint256 pairOut_ = _withdrawSinglePair(lpOut_, address(this));
            amountOut_ = _nestedExchangeInPush(
                IStandardExchangeIn(address(s.standardExchangeVault)),
                s.pairToken, pairOut_, tokenOut_, minOut_, recipient_, deadline_
            );
        } else {
            revert Repo.InvalidRoute(IERC20(address(s.rebasingClaimToken)), tokenOut_);
        }

        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
        // Outer money route: refund N/A; full hold-set sync after pair/SE exit (L-DETF-END-ORDER).
        _syncAllExpectedHoldReserves();
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
        try bondVault_.initializeDETFNFT() returns (uint256 id_) {
            detfNftId_ = id_;
        } catch {
            detfNftId_ = 0;
        }
        uint256 feeRecipientNftId_;
        address feeTo_ = address(s.feeOracle.feeTo());
        if (feeTo_ != address(0)) {
            uint256 lock_;
            try s.feeOracle.bondTermsOfVault(detf_) returns (BondTerms memory terms_) {
                lock_ = terms_.minLockDuration == 0 ? 1 : terms_.minLockDuration;
            } catch {
                lock_ = 1;
            }
            try bondVault_.createPosition(1, lock_, feeTo_) returns (uint256 id_) {
                feeRecipientNftId_ = id_;
            } catch {
                feeRecipientNftId_ = 0;
            }
        }
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
                IDetf(detf_), s.bondNftVault, s.pairToken, s.detfNftId, detf_
            )
        );
        Repo._setClaim(claimToken_);
        emit ReserveClaimWired(s.reserveHook, address(claimToken_));
        return address(claimToken_);
    }
}
