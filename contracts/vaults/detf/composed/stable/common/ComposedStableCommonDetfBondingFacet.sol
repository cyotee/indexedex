// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IComposedStableCommonDetfBondNFTVault} from 'contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol';

import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {DETFUsageFeeLib} from 'contracts/vaults/detf/core/DETFUsageFeeLib.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfCommon} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfCommon.sol';

contract ComposedStableCommonDetfBondingFacet is ComposedStableCommonDetfCommon, IComposedStableCommonDetfBonding, IFacet {
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
    }

    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 rebasingClaimMinted_) {
        _requireReservePoolInitialized();

        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IRebasingClaimToken richir = ComposedStableCommonDetfRepo._rebasingDetfToken(layoutStruct);
        if (address(richir) == address(0)) {
            revert InvalidToken(IERC20(address(0)));
        }

        (uint256 principalShares,) = ComposedStableCommonDetfRepo._bondNftVault(layoutStruct).sellPositionToDetfNft(
            tokenId, msg.sender, recipient
        );
        if (principalShares == 0) {
            revert ZeroAmount();
        }

        rebasingClaimMinted_ = richir.mintFromNFTSale(principalShares, recipient);
        // Lazy compound after protocol principal absorbs sold bond (best-effort).
        _tryCompoundProtocolRewards();
    }

    function facetName() external pure returns (string memory name_) {
        return type(ComposedStableCommonDetfBondingFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IComposedStableCommonDetfBonding).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = IComposedStableCommonDetfBonding.acceptedBondTokens.selector;
        funcs_[1] = IComposedStableCommonDetfBonding.isAcceptedBondToken.selector;
        funcs_[2] = IComposedStableCommonDetfBonding.bond.selector;
        funcs_[3] = IComposedStableCommonDetfBonding.sellNFT.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(ComposedStableCommonDetfBondingFacet).name;

        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IComposedStableCommonDetfBonding).interfaceId;

        functions_ = new bytes4[](4);
        functions_[0] = IComposedStableCommonDetfBonding.acceptedBondTokens.selector;
        functions_[1] = IComposedStableCommonDetfBonding.isAcceptedBondToken.selector;
        functions_[2] = IComposedStableCommonDetfBonding.bond.selector;
        functions_[3] = IComposedStableCommonDetfBonding.sellNFT.selector;
    }
}