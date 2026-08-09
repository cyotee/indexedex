// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    UniswapV4SingleStandardExchangeDETFExchangeInTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFExchangeInTarget.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFRepo.sol";
import {
    IUniV4DetfBondNft
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/IUniV4DetfBondNft.sol";
import {
    IUniV4DetfRebasingClaim
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/IUniV4DetfRebasingClaim.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";

interface IUniswapV4SingleStandardExchangeDETFBonding {
    function openBond(
        uint256 pairAmountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId);

    function closeBond(uint256 tokenId, address recipient) external returns (uint256 pairOut);

    function sellBond(uint256 tokenId, address recipient) external returns (uint256 rebasingTokens);

    function claimRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);

    function acceptedBondTokens() external view returns (IERC20[] memory);
}

/// @title UniswapV4SingleStandardExchangeDETFBondingTarget
abstract contract UniswapV4SingleStandardExchangeDETFBondingTarget is
    UniswapV4SingleStandardExchangeDETFExchangeInTarget,
    IUniswapV4SingleStandardExchangeDETFBonding
{
    using BetterSafeERC20 for IERC20;

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETFBonding
    function openBond(
        uint256 pairAmountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 tokenId) {
        _requireActive(deadline, pairAmountIn);
        _requireLive();
        _pokeListingOracle();
        _tryNaturalExpansion();

        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (!_isMintingAllowed()) {
            revert UniswapV4SingleStandardExchangeDETFRepo.MintingNotAllowed(_syntheticPrice(), s.mintThreshold);
        }
        if (recipient == address(0)) recipient = msg.sender;

        uint256 effectiveLock = _effectiveLockDuration(lockDuration);
        uint256 pairPulled = _pullToken(s.pairToken, pairAmountIn, pretransferred);

        // Quote DETF from pair notional + mint split.
        MintSplit memory split_ = _splitMintedDetf(_quoteGrossDetfFromPairNotional(pairPulled));

        // Fee + inventory routing; user net DETF held for DETF wing.
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        _routeInventoryDetf(split_.inventoryDetf);
        _mintDetf(address(this), split_.userDetf); // hold for DETF OOR

        // Exchange pair into Backing SE inventory (pair stays for bond OOR — plan: pull pair for bond LP).
        // Product: pair goes into pair OOR; also need inventory growth? Primary mint exchanges pair→share.
        // Bond open: pair for pair wing; DETF for DETF wing. Inventory: optional — plan says pull pairToken from user.
        // Do NOT exchange pair into SE on bond open (pair is LP collateral).

        uint256 bonus = _bonusMultiplier(effectiveLock);
        uint256 effectiveShares = DETFBondNFTMathLib._calcEffectiveShares(pairPulled, bonus);

        (int24 pairLower, int24 pairUpper, int24 detfLower, int24 detfUpper) = _deriveBondOorTicks();

        // Approve bond NFT to pull pair + DETF.
        s.pairToken.forceApprove(s.bondNft, pairPulled);
        IERC20(address(this)).forceApprove(s.bondNft, split_.userDetf);

        tokenId = IUniV4DetfBondNft(s.bondNft).openBond(
            recipient,
            pairPulled,
            pairPulled,
            split_.userDetf,
            effectiveShares,
            block.timestamp + effectiveLock,
            pairLower,
            pairUpper,
            detfLower,
            detfUpper
        );

        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETFBonding
    function closeBond(uint256 tokenId, address recipient) external nonReentrant returns (uint256 pairOut) {
        _requireLive();
        _pokeListingOracle();
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (recipient == address(0)) recipient = msg.sender;

        (uint256 pairAmt, uint256 detfAmt,) =
            IUniV4DetfBondNft(s.bondNft).closeBondMature(tokenId, msg.sender);

        // Burn all DETF recovered.
        if (detfAmt > 0) _burnDetf(address(this), detfAmt);
        // Send all pair to user.
        pairOut = pairAmt + s.pairToken.balanceOf(address(this));
        // pairAmt already transferred to DETF in closeBondMature
        uint256 pairBal = s.pairToken.balanceOf(address(this));
        if (pairBal > 0) {
            s.pairToken.safeTransfer(recipient, pairBal);
            pairOut = pairBal;
        }

        _tryNaturalExpansion();
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETFBonding
    function sellBond(uint256 tokenId, address recipient) external nonReentrant returns (uint256 rebasingTokens) {
        _requireLive();
        _pokeListingOracle();
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (recipient == address(0)) recipient = msg.sender;

        (uint256 pairOut, uint256 detfOut,,) = IUniV4DetfBondNft(s.bondNft).sellBond(tokenId, msg.sender);

        // sellBond transfers pair+DETF to this DETF; deposit into rebasing wings for user.
        if (pairOut > 0) s.pairToken.forceApprove(s.rebasingClaimToken, pairOut);
        if (detfOut > 0) IERC20(address(this)).forceApprove(s.rebasingClaimToken, detfOut);
        rebasingTokens =
            IUniV4DetfRebasingClaim(s.rebasingClaimToken).absorbBondProceeds(pairOut, detfOut, recipient);
        _tryNaturalExpansion();
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETFBonding
    function claimRewards(uint256 tokenId, address recipient) external nonReentrant returns (uint256 rewards) {
        if (recipient == address(0)) recipient = msg.sender;
        // L-REW-1: owner-only.
        address holder_ = IUniV4DetfBondNft(_s().bondNft).ownerOf(tokenId);
        if (msg.sender != holder_) {
            revert UniswapV4SingleStandardExchangeDETFRepo.NotAuthorized(msg.sender);
        }
        // L-REW-2/3: execute; return 0 only when allowed and zero rewards.
        rewards = IUniV4DetfBondNft(_s().bondNft).claimRewards(tokenId, recipient);
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IUniswapV4SingleStandardExchangeDETFBonding
    function acceptedBondTokens() external view returns (IERC20[] memory tokens_) {
        tokens_ = new IERC20[](1);
        tokens_[0] = _s().pairToken;
    }
}
