// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC4626Events} from "@crane/contracts/interfaces/IERC4626Events.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    MorphoBlueStandardExchangeCommon
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol";

/**
 * @title MorphoBlueERC4626Target
 * @notice IERC4626 money paths and views that use live Morpho NAV. Does not inherit Crane `ERC4626Target`
 *         because convert/preview/max there are non-virtual and quote `_lastTotalAssets` (idle only).
 */
contract MorphoBlueERC4626Target is MorphoBlueStandardExchangeCommon, ReentrancyLockModifiers, IERC4626Events {
    function asset() public view virtual returns (address) {
        return address(ERC4626Repo._reserveAsset());
    }

    function totalAssets() public view virtual returns (uint256) {
        return _liveNav();
    }

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return _sharesFromAssetsDown(assets, _liveNav(), ERC20Repo._totalSupply());
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return _assetsFromSharesDown(shares, _liveNav(), ERC20Repo._totalSupply());
    }

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        uint256 ownerAssets_ = convertToAssets(ERC20Repo._balanceOf(owner));
        uint256 cash_ = _availableCash();
        return ownerAssets_ < cash_ ? ownerAssets_ : cash_;
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        uint256 capAssets_ = maxWithdraw(owner);
        uint256 capShares_ = _sharesFromAssetsDown(capAssets_, _liveNav(), ERC20Repo._totalSupply());
        uint256 bal_ = ERC20Repo._balanceOf(owner);
        return capShares_ < bal_ ? capShares_ : bal_;
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return _previewWrapExactIn(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return _previewWrapExactOut(shares);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return _previewUnwrapExactOut(assets);
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _previewUnwrapExactIn(shares);
    }

    function deposit(uint256 assets, address receiver) public virtual nonReentrant returns (uint256 shares) {
        _requireNonZero(assets);
        _requireRecipient(receiver);
        shares = _execWrapExactIn(assets, receiver, false, 0);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual nonReentrant returns (uint256 assets) {
        _requireNonZero(shares);
        _requireRecipient(receiver);
        assets = _execWrapExactOut(shares, type(uint256).max, receiver, false);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 shares)
    {
        _requireNonZero(assets);
        _requireRecipient(receiver);
        shares = _execUnwrapExactOut(owner, assets, type(uint256).max, receiver, false);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        _requireNonZero(shares);
        _requireRecipient(receiver);
        assets = _execUnwrapExactIn(owner, shares, receiver, false, 0);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
