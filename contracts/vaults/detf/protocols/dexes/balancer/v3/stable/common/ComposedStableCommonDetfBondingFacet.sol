// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IComposedStableCommonDetfBondNFTVault} from 'contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';

import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {DETFUsageFeeLib} from 'contracts/vaults/detf/common/core/DETFUsageFeeLib.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfCommon} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol';

contract ComposedStableCommonDetfBondingFacet is
    ComposedStableCommonDetfCommon,
    ReentrancyLockModifiers,
    IComposedStableCommonDetfBonding,
    IFacet
{
    function _usageFeePercentage(ComposedStableCommonDetfRepo.Storage storage layoutStruct_) internal view returns (uint256 fee_) {
        if (address(ComposedStableCommonDetfRepo._feeOracle(layoutStruct_)) == address(0)) {
            return 0;
        }

        fee_ = ComposedStableCommonDetfRepo._feeOracle(layoutStruct_).usageFeeOfVault(address(this));
    }

    function _splitBondShares(ComposedStableCommonDetfRepo.Storage storage layoutStruct_, uint256 grossShares_)
        internal
        view
        returns (uint256 userShares_, uint256 feeShares_)
    {
        return DETFUsageFeeLib._splitUsageFee(grossShares_, _usageFeePercentage(layoutStruct_));
    }

    function _creditBondShares(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        uint256 grossShares_,
        uint256 lockDuration_,
        address recipient_
    ) internal returns (uint256 tokenId_, uint256 userShares_) {
        uint256 feeShares;
        (userShares_, feeShares) = _splitBondShares(layoutStruct_, grossShares_);
        if (userShares_ == 0) {
            revert ZeroAmount();
        }

        IComposedStableCommonDetfBondNFTVault bondVault =
            IComposedStableCommonDetfBondNFTVault(address(ComposedStableCommonDetfRepo._bondNftVault(layoutStruct_)));

        if (feeShares > 0) {
            bondVault.addToFeeRecipientNFT(bondVault.feeRecipientNFTId(), feeShares);
        }

        tokenId_ = bondVault.createPosition(userShares_, lockDuration_, recipient_);
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
    ) internal returns (uint256 grossShares_) {
        RoutedPoolSelection memory selection = _selectRoutingPath(tokenIn_);
        ComposedStableCommonDetfRepo.RouteConfig storage route = ComposedStableCommonDetfRepo._routeAt(layoutStruct_, selection.routeIndex);
        uint256 actualIn = _collectBondInput(tokenIn_, amountIn_);
        uint256 poolBptOut = _executeRoutedEntryToPoolBptShared(route, selection, tokenIn_, actualIn, deadline_);
        grossShares_ = _depositIntoReservePoolShared(layoutStruct_, selection, poolBptOut, deadline_);
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

        uint256 grossShares = _executeBondRoute(layoutStruct, tokenIn, amountIn, deadline);
        (tokenId, shares) = _creditBondShares(
            layoutStruct,
            grossShares,
            lockDuration,
            recipient == address(0) ? msg.sender : recipient
        );
        // Lazy protocol seigniorage compound (best-effort; never fails user bond).
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
        external
        nonReentrant
        returns (uint256 claimMinted_)
    {
        _requireMature(tokenId);
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
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut_) {
        _requireMature(tokenId);
        _requireActive(deadline, 1);
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (!_isFamilyBurnToken(tokenOut)) {
            revert InvalidRoute(address(0), address(tokenOut));
        }

        _updateExpansionMintOnRewards();

        IDETFNFTVault bondVault_ = ComposedStableCommonDetfRepo._bondNftVault(layoutStruct);
        uint256 assets_ = bondVault_.originalSharesOf(tokenId);
        if (assets_ == 0) revert ZeroAmount();

        uint256 protocol_ = _protocolOriginalShares();
        uint256 bal_ = IERC20(address(layoutStruct.reservePool)).balanceOf(address(this));
        if (bal_ < protocol_ + assets_) {
            revert ComposedStableCommonDetfRepo.InsufficientReserveBpt(protocol_ + assets_, bal_);
        }

        bondVault_.sellPositionToDetfNft(tokenId, msg.sender, recipient);
        bondVault_.removeFromDETFNFT(bondVault_.detfNFTId(), assets_);

        amountOut_ = _exitRedepositSettle(assets_, tokenOut, minOut, recipient, deadline);

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function previewCloseBondMature(uint256 tokenId, IERC20 tokenOut) external view returns (uint256 amountOut_) {
        IDETFNFTVault bondVault_ = ComposedStableCommonDetfRepo._bondNftVault();
        uint256 assets_ = bondVault_.originalSharesOf(tokenId);
        if (assets_ == 0) return 0;
        amountOut_ = _previewExitSettle(assets_, tokenOut);
    }

    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut_) {
        _requireReservePoolInitialized();
        _requireActive(deadline, claimAmount);
        if (recipient == address(0)) {
            recipient = msg.sender;
        }
        if (!_isFamilyBurnToken(tokenOut)) {
            revert InvalidRoute(address(0), address(tokenOut));
        }

        uint256 bptOut_ = _burnClaimConvertToAssets(claimAmount);
        amountOut_ = _exitRedepositSettle(bptOut_, tokenOut, minOut, recipient, deadline);
        _syncAllExpectedHoldReserves();
    }

    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut_) {
        if (claimAmount == 0) return 0;
        uint256 bptOut_ = _previewClaimBptOut(claimAmount);
        amountOut_ = _previewExitSettle(bptOut_, tokenOut);
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