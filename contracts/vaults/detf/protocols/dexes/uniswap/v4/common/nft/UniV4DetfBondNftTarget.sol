// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    UniV4DetfBondNftCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftCommon.sol";
import {
    UniV4DetfBondNftRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftRepo.sol";
import {
    IUniV4DetfBondNft
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/IUniV4DetfBondNft.sol";

/// @title UniV4DetfBondNftTarget
abstract contract UniV4DetfBondNftTarget is UniV4DetfBondNftCommon, IUniV4DetfBondNft {
    using BetterSafeERC20 for IERC20;

    /// @inheritdoc IUniV4DetfBondNft
    function openBond(
        address recipient,
        uint256 pairPrincipal,
        uint256 pairAmountForLp,
        uint256 detfAmountForLp,
        uint256 effectiveShares,
        uint256 unlockTime,
        int24 pairTickLower,
        int24 pairTickUpper,
        int24 detfTickLower,
        int24 detfTickUpper
    ) external nonReentrant returns (uint256 tokenId) {
        UniV4DetfBondNftRepo._requireOwner(msg.sender);
        if (pairPrincipal == 0 || effectiveShares == 0) revert UniV4DetfBondNftRepo.ZeroAmount();
        if (recipient == address(0)) recipient = tx.origin;

        _updateGlobalRewards();
        UniV4DetfBondNftRepo.Storage storage s = _s();

        // Pull tokens from DETF (already approved or pretransferred).
        if (pairAmountForLp > 0) {
            uint256 bal = s.pairToken.balanceOf(address(this));
            if (bal < pairAmountForLp) {
                s.pairToken.safeTransferFrom(msg.sender, address(this), pairAmountForLp - bal);
            }
        }
        if (detfAmountForLp > 0) {
            uint256 bal = s.detfToken.balanceOf(address(this));
            if (bal < detfAmountForLp) {
                s.detfToken.safeTransferFrom(msg.sender, address(this), detfAmountForLp - bal);
            }
        }

        tokenId = s.nextTokenId++;
        s.ownerOf[tokenId] = recipient;

        // Open pair-side OOR (single-sided pair).
        bool pairIs0 = s.pairIsCurrency0;
        _addSingleSided(
            pairTickLower,
            pairTickUpper,
            pairIs0 ? pairAmountForLp : 0,
            pairIs0 ? 0 : pairAmountForLp,
            UniV4DetfBondNftRepo._saltPair(tokenId)
        );
        // Open DETF-side OOR (single-sided DETF).
        _addSingleSided(
            detfTickLower,
            detfTickUpper,
            pairIs0 ? 0 : detfAmountForLp,
            pairIs0 ? detfAmountForLp : 0,
            UniV4DetfBondNftRepo._saltDetf(tokenId)
        );

        s.positions[tokenId] = UniV4DetfBondNftRepo.BondPosition({
            pairTickLower: pairTickLower,
            pairTickUpper: pairTickUpper,
            detfTickLower: detfTickLower,
            detfTickUpper: detfTickUpper,
            pairPrincipal: pairPrincipal,
            effectiveShares: effectiveShares,
            unlockTime: unlockTime,
            userRewardPerSharePaid: s.rewardPerShares,
            active: true
        });
        s.totalShares += effectiveShares;
        s.lastRewardTokenBalance = s.rewardToken.balanceOf(address(this));
    }

    /// @inheritdoc IUniV4DetfBondNft
    function claimRewards(uint256 tokenId, address recipient) external nonReentrant returns (uint256 rewards) {
        UniV4DetfBondNftRepo.Storage storage s = _s();
        if (tokenId == 0) revert UniV4DetfBondNftRepo.ProtocolBondRestricted(0);
        address owner_ = s.ownerOf[tokenId];
        if (msg.sender != owner_ && msg.sender != s.owner) {
            revert UniV4DetfBondNftRepo.NotBondHolder(owner_, msg.sender);
        }
        if (recipient == address(0)) recipient = owner_;
        rewards = _harvest(tokenId, recipient);
    }

    /// @inheritdoc IUniV4DetfBondNft
    function closeBondMature(uint256 tokenId, address caller)
        external
        nonReentrant
        returns (uint256 pairOut, uint256 detfOut, uint256 rewards)
    {
        UniV4DetfBondNftRepo._requireOwner(msg.sender);
        UniV4DetfBondNftRepo.Storage storage s = _s();
        if (tokenId == 0) revert UniV4DetfBondNftRepo.ProtocolBondRestricted(0);
        UniV4DetfBondNftRepo.BondPosition storage p = s.positions[tokenId];
        if (!p.active) revert UniV4DetfBondNftRepo.ZeroAmount();
        if (block.timestamp < p.unlockTime) revert UniV4DetfBondNftRepo.BondNotMature(p.unlockTime);

        address bondOwner = s.ownerOf[tokenId];
        if (caller != bondOwner && caller != s.owner) {
            revert UniV4DetfBondNftRepo.NotBondHolder(bondOwner, caller);
        }

        rewards = _harvest(tokenId, bondOwner);

        uint256 pairBefore = s.pairToken.balanceOf(address(this));
        uint256 detfBefore = s.detfToken.balanceOf(address(this));
        _removeAllLiquidity(p.pairTickLower, p.pairTickUpper, UniV4DetfBondNftRepo._saltPair(tokenId));
        _removeAllLiquidity(p.detfTickLower, p.detfTickUpper, UniV4DetfBondNftRepo._saltDetf(tokenId));
        pairOut = s.pairToken.balanceOf(address(this)) - pairBefore;
        detfOut = s.detfToken.balanceOf(address(this)) - detfBefore;

        // Send recovered tokens to DETF for orchestration (burn DETF, send pair to user).
        if (pairOut > 0) s.pairToken.safeTransfer(s.owner, pairOut);
        if (detfOut > 0) s.detfToken.safeTransfer(s.owner, detfOut);

        s.totalShares -= p.effectiveShares;
        delete s.positions[tokenId];
        delete s.ownerOf[tokenId];
        s.lastRewardTokenBalance = s.rewardToken.balanceOf(address(this));
    }

    /// @inheritdoc IUniV4DetfBondNft
    function sellBond(uint256 tokenId, address caller)
        external
        nonReentrant
        returns (uint256 pairOut, uint256 detfOut, uint256 rewards, uint256 principalCredited)
    {
        UniV4DetfBondNftRepo._requireOwner(msg.sender);
        UniV4DetfBondNftRepo.Storage storage s = _s();
        if (tokenId == 0) revert UniV4DetfBondNftRepo.ProtocolBondRestricted(0);
        UniV4DetfBondNftRepo.BondPosition storage p = s.positions[tokenId];
        if (!p.active) revert UniV4DetfBondNftRepo.ZeroAmount();

        address bondOwner = s.ownerOf[tokenId];
        if (caller != bondOwner && caller != s.owner) {
            revert UniV4DetfBondNftRepo.NotBondHolder(bondOwner, caller);
        }

        rewards = _harvest(tokenId, bondOwner);

        uint256 pairBefore = s.pairToken.balanceOf(address(this));
        uint256 detfBefore = s.detfToken.balanceOf(address(this));
        _removeAllLiquidity(p.pairTickLower, p.pairTickUpper, UniV4DetfBondNftRepo._saltPair(tokenId));
        _removeAllLiquidity(p.detfTickLower, p.detfTickUpper, UniV4DetfBondNftRepo._saltDetf(tokenId));
        pairOut = s.pairToken.balanceOf(address(this)) - pairBefore;
        detfOut = s.detfToken.balanceOf(address(this)) - detfBefore;

        // Credit protocol id 0 with bond's pair principal / original shares at open.
        principalCredited = p.pairPrincipal;
        _updateGlobalRewards();
        s.protocolPrincipal += principalCredited;
        // effectiveShares weight = principal (1x) for id 0 ledger.
        s.protocolEffectiveShares += principalCredited;
        s.totalShares += principalCredited;
        s.protocolRewardPerSharePaid = s.rewardPerShares;

        // Send withdrawn tokens to DETF owner for rebasing absorb.
        if (pairOut > 0) s.pairToken.safeTransfer(s.owner, pairOut);
        if (detfOut > 0) s.detfToken.safeTransfer(s.owner, detfOut);

        // Remove user bond weight.
        s.totalShares -= p.effectiveShares;
        delete s.positions[tokenId];
        delete s.ownerOf[tokenId];
        s.lastRewardTokenBalance = s.rewardToken.balanceOf(address(this));
    }

    /// @inheritdoc IUniV4DetfBondNft
    function pendingRewards(uint256 tokenId) external view returns (uint256) {
        return _pendingRewards(tokenId);
    }

    function totalShares() external view returns (uint256) {
        return _s().totalShares;
    }

    function protocolPrincipal() external view returns (uint256) {
        return _s().protocolPrincipal;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _s().ownerOf[tokenId];
    }

    function unlockTimeOf(uint256 tokenId) external view returns (uint256) {
        return _s().positions[tokenId].unlockTime;
    }

    function pairPrincipalOf(uint256 tokenId) external view returns (uint256) {
        return _s().positions[tokenId].pairPrincipal;
    }

    function effectiveSharesOf(uint256 tokenId) external view returns (uint256) {
        if (tokenId == 0) return _s().protocolEffectiveShares;
        return _s().positions[tokenId].effectiveShares;
    }

    function owner() external view returns (address) {
        return _s().owner;
    }

    function updateGlobalRewards() external {
        _updateGlobalRewards();
    }
}
