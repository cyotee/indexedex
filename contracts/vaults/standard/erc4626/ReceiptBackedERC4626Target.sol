// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC4626Events} from "@crane/contracts/interfaces/IERC4626Events.sol";
import {IERC4626Errors} from "@crane/contracts/tokens/ERC4626/IERC4626Errors.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ERC165Repo} from "@crane/contracts/introspection/ERC165/ERC165Repo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    ReceiptBackedERC4626AccountingLib
} from "contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol";

/**
 * @title ReceiptBackedERC4626Target
 * @notice Shared IERC4626 adapter for generic ERC-4626 SE and Aave V3 Stata.
 * @dev Dispatch uses the proxy ERC-165 markers, never the external receipt's interfaces.
 */
contract ReceiptBackedERC4626Target is ReentrancyLockModifiers, IERC4626Events, IERC4626Errors {
    using BetterSafeERC20 for IERC20;

    error UnsupportedAccountingFamily();
    error ZeroAmount();
    error InvalidReceiver();

    function asset() public view virtual returns (address) {
        _requireFamily();
        return address(ERC4626Repo._reserveAsset());
    }

    function totalAssets() public view virtual returns (uint256) {
        _requireFamily();
        return _totalReceiptBacking();
    }

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        _requireFamily();
        return ReceiptBackedERC4626AccountingLib.sharesFromReceiptUnits(
            assets, _totalReceiptBacking(), ERC20Repo._totalSupply()
        );
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        _requireFamily();
        return ReceiptBackedERC4626AccountingLib.receiptUnitsFromShares(
            shares, _totalReceiptBacking(), ERC20Repo._totalSupply()
        );
    }

    function maxDeposit(address) public view virtual returns (uint256) {
        _requireFamily();
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        _requireFamily();
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        _requireFamily();
        uint256 ownerAssets = convertToAssets(ERC20Repo._balanceOf(owner));
        uint256 receipts = IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this));
        return ownerAssets < receipts ? ownerAssets : receipts;
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        uint256 capAssets = maxWithdraw(owner);
        if (capAssets == 0) return 0;
        uint256 capShares = convertToShares(capAssets);
        uint256 bal = ERC20Repo._balanceOf(owner);
        return capShares < bal ? capShares : bal;
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        _requireFamily();
        return ReceiptBackedERC4626AccountingLib.receiptUnitsForMint(
            shares, _totalReceiptBacking(), ERC20Repo._totalSupply()
        );
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        _requireFamily();
        return ReceiptBackedERC4626AccountingLib.sharesForWithdraw(
            assets, _totalReceiptBacking(), ERC20Repo._totalSupply()
        );
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) public virtual nonReentrant returns (uint256 shares) {
        _requireFamily();
        _requireNonZero(assets);
        _requireReceiver(receiver);
        uint256 backingBefore = _totalReceiptBacking();
        _pullReceipts(assets);
        shares = ReceiptBackedERC4626AccountingLib.sharesFromReceiptUnits(
            assets, backingBefore, ERC20Repo._totalSupply()
        );
        ERC20Repo._mint(receiver, shares);
        _syncAllExpectedHoldReserves();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual nonReentrant returns (uint256 assets) {
        _requireFamily();
        _requireNonZero(shares);
        _requireReceiver(receiver);
        uint256 backingBefore = _totalReceiptBacking();
        assets = ReceiptBackedERC4626AccountingLib.receiptUnitsForMint(
            shares, backingBefore, ERC20Repo._totalSupply()
        );
        _pullReceipts(assets);
        ERC20Repo._mint(receiver, shares);
        _syncAllExpectedHoldReserves();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 shares)
    {
        _requireFamily();
        _requireNonZero(assets);
        _requireReceiver(receiver);
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
        shares = previewWithdraw(assets);
        _spendOwnerShares(owner, shares);
        IERC20(address(ERC4626Repo._reserveAsset())).safeTransfer(receiver, assets);
        _syncAllExpectedHoldReserves();
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        _requireFamily();
        _requireNonZero(shares);
        _requireReceiver(receiver);
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }
        assets = previewRedeem(shares);
        _spendOwnerShares(owner, shares);
        IERC20(address(ERC4626Repo._reserveAsset())).safeTransfer(receiver, assets);
        _syncAllExpectedHoldReserves();
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _requireFamily() internal view {
        bool generic = ERC165Repo._supportsInterface(type(IERC4626StandardExchange).interfaceId);
        bool stata = ERC165Repo._supportsInterface(type(IAaveV3StataStandardVault).interfaceId);
        if (generic == stata) revert UnsupportedAccountingFamily();
    }

    function _isStata() internal view returns (bool) {
        return ERC165Repo._supportsInterface(type(IAaveV3StataStandardVault).interfaceId);
    }

    function _totalReceiptBacking() internal view returns (uint256) {
        IERC4626 receipt = IERC4626(address(ERC4626Repo._reserveAsset()));
        return ReceiptBackedERC4626AccountingLib.backingReceiptUnits(receipt, address(this), _isStata());
    }

    function _pullReceipts(uint256 assets) internal {
        IERC20 receipt = IERC20(address(ERC4626Repo._reserveAsset()));
        uint256 before = receipt.balanceOf(address(this));
        receipt.safeTransferFrom(msg.sender, address(this), assets);
        uint256 delta = receipt.balanceOf(address(this)) - before;
        if (delta != assets) revert ISecurePullErrors.TransferDeltaInsufficient(assets, delta);
    }

    function _spendOwnerShares(address owner, uint256 shares) internal {
        if (msg.sender != owner) {
            ERC20Repo._spendAllowance(owner, msg.sender, shares);
        }
        ERC20Repo._burn(owner, shares);
    }

    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _requireReceiver(address receiver) internal view {
        if (receiver == address(0) || receiver == address(this)) revert InvalidReceiver();
    }
}
