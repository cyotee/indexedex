// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {
    UniV4DetfRebasingClaimCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimCommon.sol";
import {
    UniV4DetfRebasingClaimRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimRepo.sol";
import {
    IUniV4DetfRebasingClaim
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/IUniV4DetfRebasingClaim.sol";

/// @title UniV4DetfRebasingClaimTarget
/// @notice Deposit / redeem / absorb / donate entrypoints for the rebasing claim package.
abstract contract UniV4DetfRebasingClaimTarget is UniV4DetfRebasingClaimCommon, IUniV4DetfRebasingClaim {
    using BetterSafeERC20 for IERC20;

    /// @inheritdoc IUniV4DetfRebasingClaim
    function deposit(IERC20 tokenIn, uint256 amountIn, uint256 minRebasingOut, address recipient)
        external
        nonReentrant
        returns (uint256 rebasingTokensMinted)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) recipient = msg.sender;

        address pair = address(_pairToken());
        address detf = address(_detfToken());
        if (address(tokenIn) != pair && address(tokenIn) != detf) revert UnsupportedToken(address(tokenIn));

        uint256 pre = _zapOutToPair();
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        _depositBalancesIntoWings();
        uint256 post = _zapOutToPair();
        rebasingTokensMinted = _mintFromContribution(pre, post, recipient);
        if (rebasingTokensMinted < minRebasingOut) {
            revert SlippageExceeded(minRebasingOut, rebasingTokensMinted);
        }
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function redeem(uint256 rebasingAmount, uint256 minPairOut, address recipient)
        external
        nonReentrant
        returns (uint256 pairOut)
    {
        if (rebasingAmount == 0) revert ZeroAmount();
        if (recipient == address(0)) recipient = msg.sender;

        uint256 obligation = _obligationPair(rebasingAmount);
        ERC20Repo._burn(msg.sender, rebasingAmount);
        pairOut = _executeRedeemLadder(obligation, recipient);
        if (pairOut < minPairOut) revert SlippageExceeded(minPairOut, pairOut);
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function previewDeposit(IERC20 tokenIn, uint256 amountIn) external view returns (uint256 rebasingTokensMinted) {
        if (amountIn == 0) return 0;
        address pair = address(_pairToken());
        address detf = address(_detfToken());
        if (address(tokenIn) != pair && address(tokenIn) != detf) return 0;

        // Approximate: contribution ≈ amountIn valued as pair (DETF via swap quote).
        uint256 pre = _zapOutToPair();
        uint256 contribution;
        if (address(tokenIn) == pair) {
            contribution = amountIn;
        } else {
            bool detfIs0 = !UniV4DetfRebasingClaimRepo._layout().pairIsCurrency0;
            contribution = _quoteSwapIn(amountIn, detfIs0);
        }
        uint256 post = pre + contribution;
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0 || pre == 0) return contribution;
        return Math.mulDiv(contribution, supply, pre);
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function previewRedeem(uint256 rebasingAmount) external view returns (uint256 pairOut) {
        return _obligationPair(rebasingAmount);
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function zapOutToPair() external view returns (uint256) {
        return _zapOutToPair();
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function absorbBondProceeds(uint256 pairAmount, uint256 detfAmount, address rebasingRecipient)
        external
        nonReentrant
        returns (uint256 rebasingTokensMinted)
    {
        UniV4DetfRebasingClaimRepo._requireOwner(msg.sender);
        if (rebasingRecipient == address(0)) revert ZeroAmount();

        uint256 pre = _zapOutToPair();
        // Tokens already transferred or pulled by owner; pull remaining allowance if needed.
        if (pairAmount > 0) {
            IERC20 pair = _pairToken();
            uint256 bal = pair.balanceOf(address(this));
            if (bal < pairAmount) {
                pair.safeTransferFrom(msg.sender, address(this), pairAmount - bal);
            }
        }
        if (detfAmount > 0) {
            IERC20 detf = _detfToken();
            uint256 bal = detf.balanceOf(address(this));
            if (bal < detfAmount) {
                detf.safeTransferFrom(msg.sender, address(this), detfAmount - bal);
            }
        }
        _depositBalancesIntoWings();
        uint256 post = _zapOutToPair();
        rebasingTokensMinted = _mintFromContribution(pre, post, rebasingRecipient);
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function donateDetf(uint256 detfAmount) external nonReentrant {
        UniV4DetfRebasingClaimRepo._requireOwner(msg.sender);
        if (detfAmount == 0) return;
        IERC20 detf = _detfToken();
        uint256 bal = detf.balanceOf(address(this));
        if (bal < detfAmount) {
            detf.safeTransferFrom(msg.sender, address(this), detfAmount - bal);
        }
        // Deposit into wings; mint 0 rebasing tokens (pure donation).
        _depositBalancesIntoWings();
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function pairToken() external view returns (IERC20) {
        return _pairToken();
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function detfToken() external view returns (IERC20) {
        return _detfToken();
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function listingPoolKey() external view returns (PoolKey memory) {
        return _poolKey();
    }

    /// @inheritdoc IUniV4DetfRebasingClaim
    function owner() external view returns (address) {
        return UniV4DetfRebasingClaimRepo._layout().owner;
    }
}
