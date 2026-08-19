// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IVault} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol';
import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IDetfSelfNftInventoryPolicy} from 'contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol';

import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {DETFBondLifecycleLib} from 'contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol';
import {
    ComposedStableCommonDetfCommon,
    IComposedStableBalancerPoolToken
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol';

contract ComposedStableCommonDetfBondingFacet is
    ComposedStableCommonDetfCommon,
    ReentrancyLockModifiers,
    IComposedStableCommonDetfBonding,
    IFacet
{
    using BetterSafeERC20 for IERC20;

    function _creditBondShares(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        uint256 grossShares_,
        uint256 lockDuration_,
        address recipient_
    ) internal returns (uint256 tokenId_, uint256 userShares_) {
        if (grossShares_ == 0) {
            revert ZeroAmount();
        }
        userShares_ = grossShares_;
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            IDetfSelfNftInventoryPolicy(address(ComposedStableCommonDetfRepo._bondNftVault(layoutStruct_))),
            userShares_,
            lockDuration_,
            recipient_
        );
    }

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        uint256 routeCount = ComposedStableCommonDetfRepo._routeCount(layoutStruct);
        address[] memory working = new address[](routeCount);
        uint256 uniqueCount;

        for (uint256 i = 0; i < routeCount; i++) {
            address candidate = address(ComposedStableCommonDetfRepo._routeAt(layoutStruct, i).baseToken);
            bool seen;
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (working[j] == candidate) {
                    seen = true;
                    break;
                }
            }

            if (!seen) {
                working[uniqueCount] = candidate;
                uniqueCount++;
            }
        }

        tokens_ = new address[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            tokens_[i] = working[i];
        }
    }

    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        uint256 routeCount = ComposedStableCommonDetfRepo._routeCount(layoutStruct);
        for (uint256 i = 0; i < routeCount; i++) {
            if (address(ComposedStableCommonDetfRepo._routeAt(layoutStruct, i).baseToken) == address(token)) {
                return true;
            }
        }
    }

    function _collectBondInput(IERC20 tokenIn_, uint256 amountIn_) internal returns (uint256 actualIn_) {
        actualIn_ = _secureTokenTransfer(tokenIn_, amountIn_, false);
    }

    function _executeBondRoute(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 deadline_
    ) internal returns (uint256 grossShares_, uint256 joinDetf_) {
        RoutedPoolSelection memory selection = _selectRoutingPath(tokenIn_);
        ComposedStableCommonDetfRepo.RouteConfig storage route = ComposedStableCommonDetfRepo._routeAt(layoutStruct_, selection.routeIndex);
        uint256 actualIn = _collectBondInput(tokenIn_, amountIn_);
        uint256 poolBptOut = _executeRoutedEntryToPoolBptShared(route, selection, tokenIn_, actualIn, deadline_);
        joinDetf_ = _quoteBondJoinDetf(poolBptOut, selection.depositToStablePool);
        if (joinDetf_ > 0) {
            _mintDetf(address(this), joinDetf_);
            grossShares_ += _joinReserveDetfOnly(joinDetf_);
        }
        grossShares_ += _depositIntoReservePoolShared(layoutStruct_, selection, poolBptOut, deadline_);
    }

    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)
        external
        nonReentrant
        returns (uint256 tokenId, uint256 shares)
    {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        if (amountIn == 0) {
            revert ZeroAmount();
        }

        _requireReservePoolInitialized();
        _ensureReservedBondNftsWired();

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (
            address(tokenIn) == address(this)
                || address(tokenIn) == address(ComposedStableCommonDetfRepo._detfToken(layoutStruct))
        ) {
            revert BondTokenNotSupported(tokenIn);
        }
        if (!this.isAcceptedBondToken(tokenIn)) {
            revert BondTokenNotSupported(tokenIn);
        }

        address recipient_ = recipient == address(0) ? msg.sender : recipient;
        (uint256 grossShares, uint256 joinDetf_) = _executeBondRoute(layoutStruct, tokenIn, amountIn, deadline);
        MintSplit memory split_ = _splitBondAmount(joinDetf_);
        if (split_.userDetfOut > 0) {
            _mintDetf(recipient_, split_.userDetfOut);
        }
        (tokenId, shares) = _creditBondShares(layoutStruct, grossShares, lockDuration, recipient_);
        // D2 after O change, then L1+D4 pot mint so ids 1–2 take this bond at the new weights.
        _topUpFeeCreatorShares();
        if (split_.inventoryDetfOut > 0) {
            _mintDetf(address(ComposedStableCommonDetfRepo._bondNftVault(layoutStruct)), split_.inventoryDetfOut);
        }
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
        external
        nonReentrant
        returns (uint256 claimMinted_)
    {
        _requireMature(tokenId);
        _requireNotStandingRewardNft(tokenId);
        _requireReservePoolInitialized();

        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IRebasingClaimToken claimToken_ = ComposedStableCommonDetfRepo._rebasingDetfToken(layoutStruct);
        if (address(claimToken_) == address(0)) {
            revert InvalidToken(IERC20(address(0)));
        }

        _updateExpansionMintOnRewards();

        IDETFNFTVault bondVault_ = ComposedStableCommonDetfRepo._bondNftVault(layoutStruct);
        uint256 protocolBefore_ = _protocolOriginalShares();
        uint256 assets_ = bondVault_.originalSharesOf(tokenId);
        (uint256 principalShares,) = bondVault_.sellPositionToDetfNft(tokenId, msg.sender, recipient);
        if (principalShares == 0 && assets_ == 0) {
            revert ZeroAmount();
        }
        if (assets_ == 0) {
            assets_ = principalShares;
        }

        claimMinted_ = claimToken_.mintFromNFTSale(assets_, protocolBefore_, recipient);
        if (claimMinted_ < minClaimOut) {
            revert InvalidRoute(address(claimToken_), address(0));
        }

        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function protocolBondOriginalShares() external view returns (uint256) {
        return _protocolOriginalShares();
    }

    function buyClaim(
        uint256 detfAmount,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 claimMinted_) {
        _requireReservePoolInitialized();
        _ensureReservedBondNftsWired();
        _requireActive(deadline, detfAmount);

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IRebasingClaimToken claimToken_ = ComposedStableCommonDetfRepo._rebasingDetfToken(layoutStruct);
        if (address(claimToken_) == address(0)) {
            revert InvalidToken(IERC20(address(0)));
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        _secureTokenTransfer(ComposedStableCommonDetfRepo._detfToken(layoutStruct), detfAmount, pretransferred);
        uint256 bptIn_ = _singleSidedJoinDetf(detfAmount);
        if (bptIn_ == 0) revert ZeroAmount();

        // Mint against live protocol originalShares before the ledger credit (buyClaim order).
        claimMinted_ = claimToken_.mintFromNFTSale(bptIn_, recipient);
        layoutStruct.bondNftVault.addToDETFNFT(layoutStruct.bondNftVault.detfNFTId(), bptIn_);
        if (claimMinted_ < minClaimOut) {
            revert InvalidRoute(address(claimToken_), address(0));
        }

        _topUpFeeCreatorShares();
        _updateExpansionMintOnRewards();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted_) {
        if (detfAmount == 0) return 0;
        if (address(ComposedStableCommonDetfRepo._rebasingDetfToken()) == address(0)) return 0;
        uint256 bptIn_ = _previewJoinDetfOnly(detfAmount);
        claimMinted_ = _previewClaimMinted(bptIn_, _protocolOriginalShares());
    }

    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amountsOut_) {
        _requireMature(tokenId);
        _requireNotStandingRewardNft(tokenId);
        _requireActive(deadline, 1);
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (minAmountsOut.length != RESERVE_TOKEN_COUNT) {
            revert InvalidRoute(address(0), address(0));
        }
        if (minAmountsOut[layoutStruct.detfIndex] != 0) {
            revert InvalidRoute(address(ComposedStableCommonDetfRepo._detfToken(layoutStruct)), address(0));
        }

        _updateExpansionMintOnRewards();

        IDETFNFTVault bondVault_ = ComposedStableCommonDetfRepo._bondNftVault(layoutStruct);
        uint256 orig_ = bondVault_.originalSharesOf(tokenId);
        if (orig_ == 0) revert ZeroAmount();
        uint256 totalOrig_ = bondVault_.totalOriginalShares();
        uint256 bptBal_ = IERC20(address(layoutStruct.reservePool)).balanceOf(address(this));
        uint256 lpOut_ = totalOrig_ == 0 ? orig_ : orig_ * bptBal_ / totalOrig_;
        if (lpOut_ == 0) revert ZeroAmount();

        bondVault_.retireMaturePosition(tokenId, recipient);

        (uint256 detfOut_, uint256 stableBptOut_, uint256 commonBptOut_) = _exitReserveProportional(lpOut_);
        if (detfOut_ > 0) {
            _burnDetf(address(this), detfOut_);
        }
        if (stableBptOut_ < minAmountsOut[layoutStruct.stablePoolBptIndex]) {
            revert InvalidRoute(address(layoutStruct.stablePoolBpt), address(0));
        }
        if (commonBptOut_ < minAmountsOut[layoutStruct.commonPoolBptIndex]) {
            revert InvalidRoute(address(layoutStruct.commonPoolBpt), address(0));
        }
        if (stableBptOut_ > 0) {
            layoutStruct.stablePoolBpt.safeTransfer(recipient, stableBptOut_);
        }
        if (commonBptOut_ > 0) {
            layoutStruct.commonPoolBpt.safeTransfer(recipient, commonBptOut_);
        }

        amountsOut_ = new uint256[](RESERVE_TOKEN_COUNT);
        amountsOut_[layoutStruct.stablePoolBptIndex] = stableBptOut_;
        amountsOut_[layoutStruct.commonPoolBptIndex] = commonBptOut_;

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        amountsOut_ = new uint256[](RESERVE_TOKEN_COUNT);
        IDETFNFTVault bondVault_ = ComposedStableCommonDetfRepo._bondNftVault(layoutStruct);
        uint256 orig_ = bondVault_.originalSharesOf(tokenId);
        if (orig_ == 0) return amountsOut_;
        uint256 totalOrig_ = bondVault_.totalOriginalShares();
        uint256 bptBal_ = IERC20(address(layoutStruct.reservePool)).balanceOf(address(this));
        uint256 lpOut_ = totalOrig_ == 0 ? orig_ : orig_ * bptBal_ / totalOrig_;
        (, uint256 stableOut_, uint256 commonOut_) = _previewProportionalExit(lpOut_);
        amountsOut_[layoutStruct.stablePoolBptIndex] = stableOut_;
        amountsOut_[layoutStruct.commonPoolBptIndex] = commonOut_;
    }

    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut_) {
        amountOut_ = _redeemClaimForDetf(claimAmount, tokenOut, minOut, recipient, deadline);
    }

    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut_) {
        if (claimAmount == 0) return 0;
        if (address(tokenOut) != address(ComposedStableCommonDetfRepo._detfToken())) return 0;
        uint256 bptOut_ = _previewClaimBptOut(claimAmount);
        amountOut_ = _previewProportionalDetf(bptOut_);
    }

    /// @dev D15: claim → DETF. Pending on id 0 first; leftover pending compounded; shortfall from LP.
    function _redeemClaimForDetf(
        uint256 claimAmount_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        _requireReservePoolInitialized();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        if (address(tokenOut_) != address(s.detfToken)) {
            revert InvalidRoute(address(s.rebasingDetfToken), address(tokenOut_));
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
            (uint256 detfFromLp_, uint256 stableBpt_, uint256 commonBpt_) = _exitReserveProportional(bptOut_);
            uint256 shortfall_ = owed_ - harvested_;
            uint256 fromLp_ = detfFromLp_ < shortfall_ ? detfFromLp_ : shortfall_;
            amountOut_ = harvested_ + fromLp_;
            uint256 leftoverDetf_ = detfFromLp_ - fromLp_;
            if (leftoverDetf_ > 0) {
                uint256 bptBack_ = _joinReserveDetfOnly(leftoverDetf_);
                if (bptBack_ > 0) {
                    s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
                }
            }
            if (stableBpt_ > 0 || commonBpt_ > 0) {
                _redepositNonDetfLegs(stableBpt_, commonBpt_);
            }
        }

        if (amountOut_ < minOut_) {
            revert InvalidRoute(address(s.detfToken), address(tokenOut_));
        }
        if (amountOut_ > 0) {
            s.detfToken.safeTransfer(recipient_, amountOut_);
        }
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    function _redepositNonDetfLegs(uint256 stableBpt_, uint256 commonBpt_) internal {
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        uint256[] memory amountsIn_ = new uint256[](RESERVE_TOKEN_COUNT);
        IVault bal_ = IComposedStableBalancerPoolToken(address(s.reservePool)).getVault();
        if (stableBpt_ > 0) {
            amountsIn_[s.stablePoolBptIndex] = stableBpt_;
            s.stablePoolBpt.safeTransfer(address(bal_), stableBpt_);
        }
        if (commonBpt_ > 0) {
            amountsIn_[s.commonPoolBptIndex] = commonBpt_;
            s.commonPoolBpt.safeTransfer(address(bal_), commonBpt_);
        }
        uint256 bptBack_ = s.balancerV3Router.prepayAddLiquidityUnbalanced(address(s.reservePool), amountsIn_, 0, '');
        if (bptBack_ > 0) {
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
        }
    }

    function _burnClaimConvertToAssets(uint256 claimAmount_) private returns (uint256 bptOut_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IRebasingClaimToken claimToken_ = ComposedStableCommonDetfRepo._rebasingDetfToken(layoutStruct);
        if (address(claimToken_) == address(0)) {
            revert InvalidToken(IERC20(address(0)));
        }

        address burnOwner_ = msg.sender;
        bool pretransferred_ = false;
        if (msg.sender == address(claimToken_)) {
            burnOwner_ = address(claimToken_);
            pretransferred_ = true;
        }

        uint256 totalSharesBefore_ = claimToken_.totalShares();
        uint256 sharesBurned_ = claimToken_.burnShares(claimAmount_, burnOwner_, pretransferred_);
        if (sharesBurned_ == 0) revert ZeroAmount();
        uint256 totalAssets_ = _protocolOriginalShares();
        uint256 totalShares_ = totalSharesBefore_ == 0 ? sharesBurned_ : totalSharesBefore_;
        bptOut_ = (sharesBurned_ * totalAssets_) / totalShares_;
        if (bptOut_ == 0) revert ZeroAmount();

        uint256 userPile_ = _userPileReserved();
        uint256 bal_ = IERC20(address(layoutStruct.reservePool)).balanceOf(address(this));
        uint256 physicalAvail_ = bal_ > userPile_ ? bal_ - userPile_ : 0;
        if (physicalAvail_ < bptOut_) {
            revert ComposedStableCommonDetfRepo.InsufficientReserveBpt(bptOut_, physicalAvail_);
        }
        layoutStruct.bondNftVault.removeFromDETFNFT(layoutStruct.bondNftVault.detfNFTId(), bptOut_);
    }

    function facetName() external pure returns (string memory name_) {
        return type(ComposedStableCommonDetfBondingFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IComposedStableCommonDetfBonding).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = _facetFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(ComposedStableCommonDetfBondingFacet).name;

        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IComposedStableCommonDetfBonding).interfaceId;

        functions_ = _facetFuncs();
    }

    function _facetFuncs() private pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](11);
        funcs_[0] = IComposedStableCommonDetfBonding.acceptedBondTokens.selector;
        funcs_[1] = IComposedStableCommonDetfBonding.isAcceptedBondToken.selector;
        funcs_[2] = IComposedStableCommonDetfBonding.bond.selector;
        funcs_[3] = IComposedStableCommonDetfBonding.sellPositionToDetfNft.selector;
        funcs_[4] = IComposedStableCommonDetfBonding.buyClaim.selector;
        funcs_[5] = IComposedStableCommonDetfBonding.previewBuyClaim.selector;
        funcs_[6] = IComposedStableCommonDetfBonding.closeBondMature.selector;
        funcs_[7] = IComposedStableCommonDetfBonding.previewCloseBondMature.selector;
        funcs_[8] = IComposedStableCommonDetfBonding.redeemClaim.selector;
        funcs_[9] = IComposedStableCommonDetfBonding.previewRedeemClaim.selector;
        funcs_[10] = IComposedStableCommonDetfBonding.protocolBondOriginalShares.selector;
    }
}