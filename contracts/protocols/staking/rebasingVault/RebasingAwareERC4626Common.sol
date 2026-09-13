// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626Events} from "@crane/contracts/interfaces/IERC4626Events.sol";
import {IERC4626Errors} from "@crane/contracts/interfaces/IERC4626Errors.sol";
import {IERC20Errors} from "@crane/contracts/tokens/ERC20/IERC20Errors.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareERC4626Repo} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Repo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

/**
 * @title RebasingAwareERC4626Common
 * @notice One conversion and settlement core for ERC4626, SE, and SY.
 */
library RebasingAwareERC4626Common {
    using BetterSafeERC20 for IERC20;

    uint256 internal constant QUOTE_STATE_VERSION = 1;
    uint256 internal constant QUOTE_STATE_BYTES = 288;
    uint8 internal constant MIN_OFFSET = 10;
    uint8 internal constant MAX_OFFSET = 18;
    uint256 internal constant MAX_DECIMALS_SUM = 77;
    uint256 internal constant WAD = 1e18;

    enum ShareSource {
        CallerOrApprovedOwner,
        PublicBalanceRefundExcess,
        PublicBalanceExactBurn
    }

    struct Book {
        IERC20 asset;
        uint256 assets;
        uint256 supply;
        uint256 virtualShares;
        uint8 decimalOffset;
    }

    function requireUnlocked() internal view {
        ReentrancyLockRepo._onlyUnlocked();
    }

    function virtualSharesOf(uint8 offset_) internal pure returns (uint256) {
        return 10 ** offset_;
    }

    function liveBook() internal view returns (Book memory book) {
        book.asset = RebasingAwareERC4626Repo._asset();
        book.assets = book.asset.balanceOf(address(this));
        book.supply = ERC20Repo._totalSupply();
        book.decimalOffset = RebasingAwareERC4626Repo._decimalOffset();
        book.virtualShares = virtualSharesOf(book.decimalOffset);
        assertDomain(book);
    }

    function assertDomain(Book memory book) internal pure {
        if (book.assets == type(uint256).max) {
            revert IRebasingAwareERC4626.NumericDomainExceeded();
        }
        if (book.supply > type(uint256).max - book.virtualShares) {
            revert IRebasingAwareERC4626.NumericDomainExceeded();
        }
    }

    function inboundDisabled() internal view returns (bool) {
        address registry_ = RebasingAwareERC4626Repo._vaultRegistry();
        if (registry_ == address(0)) return false;
        return IVaultRegistryDisableQuery(registry_).isDisabled(address(this));
    }

    function requireInboundEnabled() internal view {
        if (inboundDisabled()) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function requireDeadline(uint256 deadline_) internal view {
        if (block.timestamp > deadline_) {
            revert IStandardExchangeErrors.DeadlineExceeded(deadline_, block.timestamp);
        }
    }

    function requireReceiver(address receiver, bool assetOutput) internal view {
        if (receiver == address(0) || (assetOutput && receiver == address(this))) {
            revert IRebasingAwareERC4626.InvalidReceiver(receiver);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Full-precision conversion                      */
    /* ---------------------------------------------------------------------- */

    function mulDivFloor(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        if (d == 0) revert IRebasingAwareERC4626.NumericDomainExceeded();
        (uint256 prod1,) = Math.mul512(x, y);
        if (prod1 >= d) revert IRebasingAwareERC4626.NumericDomainExceeded();
        return Math.mulDiv(x, y, d);
    }

    function mulDivCeil(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        uint256 q = mulDivFloor(x, y, d);
        uint256 rem = mulmod(x, y, d);
        if (rem == 0) return q;
        if (q == type(uint256).max) revert IRebasingAwareERC4626.NumericDomainExceeded();
        return q + 1;
    }

    function mulDivFloorSat(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        if (d == 0) return type(uint256).max;
        (uint256 prod1,) = Math.mul512(x, y);
        if (prod1 >= d) return type(uint256).max;
        return Math.mulDiv(x, y, d);
    }

    function mulDivCeilSat(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        if (d == 0) return type(uint256).max;
        (uint256 prod1,) = Math.mul512(x, y);
        if (prod1 >= d) return type(uint256).max;
        uint256 q = Math.mulDiv(x, y, d);
        if (mulmod(x, y, d) == 0) return q;
        if (q == type(uint256).max) return type(uint256).max;
        return q + 1;
    }

    function sharesForDeposit(uint256 assets, Book memory book) internal pure returns (uint256) {
        return mulDivFloor(assets, book.supply + book.virtualShares, book.assets + 1);
    }

    function assetsForMint(uint256 shares, Book memory book) internal pure returns (uint256) {
        return mulDivCeil(shares, book.assets + 1, book.supply + book.virtualShares);
    }

    function assetsForRedeem(uint256 shares, Book memory book) internal pure returns (uint256) {
        return mulDivFloor(shares, book.assets + 1, book.supply + book.virtualShares);
    }

    function sharesForWithdraw(uint256 assets, Book memory book) internal pure returns (uint256) {
        return mulDivCeil(assets, book.supply + book.virtualShares, book.assets + 1);
    }

    function holderValue(uint256 holderShares, Book memory book) internal pure returns (uint256) {
        if (holderShares == 0) return 0;
        return mulDivFloor(holderShares, book.assets + 1, book.supply + book.virtualShares);
    }

    function wadRate(Book memory book) internal pure returns (uint256 rate) {
        rate = mulDivFloor(WAD, book.assets + 1, book.supply + book.virtualShares);
        if (rate == 0) revert IRebasingAwareERC4626.SYExchangeRateUnderflow();
    }

    /* ---------------------------------------------------------------------- */
    /*                                   Views                                */
    /* ---------------------------------------------------------------------- */

    function convertToShares(uint256 assets) internal view returns (uint256) {
        requireUnlocked();
        if (assets == 0) return 0;
        return sharesForDeposit(assets, liveBook());
    }

    function convertToAssets(uint256 shares) internal view returns (uint256) {
        requireUnlocked();
        if (shares == 0) return 0;
        return assetsForRedeem(shares, liveBook());
    }

    function previewDeposit(uint256 assets) internal view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) internal view returns (uint256) {
        requireUnlocked();
        if (shares == 0) return 0;
        return assetsForMint(shares, liveBook());
    }

    function previewRedeem(uint256 shares) internal view returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) internal view returns (uint256) {
        requireUnlocked();
        if (assets == 0) return 0;
        return sharesForWithdraw(assets, liveBook());
    }

    function maxDepositFromBook(Book memory book) internal pure returns (uint256) {
        if (book.assets == 0 && book.supply > 0) return 0;
        uint256 remShares = type(uint256).max - book.virtualShares - book.supply;
        uint256 fromShares = mulDivCeilSat(remShares + 1, book.assets + 1, book.supply + book.virtualShares);
        if (fromShares == 0) return 0;
        if (fromShares != type(uint256).max) fromShares -= 1;
        if (book.assets >= type(uint256).max - 1) return 0;
        uint256 fromAssets = type(uint256).max - 1 - book.assets;
        return fromShares < fromAssets ? fromShares : fromAssets;
    }

    function maxMintFromBook(Book memory book) internal pure returns (uint256) {
        if (book.assets == 0 && book.supply > 0) return 0;
        uint256 remShares = type(uint256).max - book.virtualShares - book.supply;
        if (book.assets >= type(uint256).max - 1) return 0;
        uint256 fromAssets = mulDivFloorSat(
            type(uint256).max - 1 - book.assets, book.supply + book.virtualShares, book.assets + 1
        );
        return remShares < fromAssets ? remShares : fromAssets;
    }

    function maxDeposit(address) internal view returns (uint256) {
        requireUnlocked();
        if (inboundDisabled()) return 0;
        return maxDepositFromBook(liveBook());
    }

    function maxMint(address) internal view returns (uint256) {
        requireUnlocked();
        if (inboundDisabled()) return 0;
        return maxMintFromBook(liveBook());
    }

    function maxWithdraw(address owner) internal view returns (uint256) {
        requireUnlocked();
        uint256 shares = ERC20Repo._balanceOf(owner);
        if (shares == 0) return 0;
        return assetsForRedeem(shares, liveBook());
    }

    function maxRedeem(address owner) internal view returns (uint256) {
        return ERC20Repo._balanceOf(owner);
    }

    function exchangeRate() internal view returns (uint256) {
        requireUnlocked();
        return wadRate(liveBook());
    }

    function totalAssets() internal view returns (uint256) {
        requireUnlocked();
        return RebasingAwareERC4626Repo._asset().balanceOf(address(this));
    }

    /* ---------------------------------------------------------------------- */
    /*                                Settlement                              */
    /* ---------------------------------------------------------------------- */

    function _movement(uint256 before_, uint256 after_)
        private
        pure
        returns (uint256 debit, uint256 credit)
    {
        if (after_ >= before_) credit = after_ - before_;
        else debit = before_ - after_;
    }

    function pullAssets(IERC20 asset, address payer, uint256 expected) internal {
        uint256 supplyBefore = asset.totalSupply();
        uint256 payerBefore = asset.balanceOf(payer);
        uint256 vaultBefore = asset.balanceOf(address(this));
        asset.safeTransferFrom(payer, address(this), expected);
        uint256 supplyAfter = asset.totalSupply();
        if (supplyAfter != supplyBefore) {
            revert IRebasingAwareERC4626.AssetSupplyChangedDuringTransfer(supplyBefore, supplyAfter);
        }
        (uint256 payerDebit,) = _movement(payerBefore, asset.balanceOf(payer));
        (, uint256 vaultCredit) = _movement(vaultBefore, asset.balanceOf(address(this)));
        if (payerDebit != expected || vaultCredit != expected) {
            revert IRebasingAwareERC4626.AssetTransferMismatch(expected, payerDebit, vaultCredit);
        }
    }

    function payAssets(IERC20 asset, address receiver, uint256 expected) internal {
        if (receiver == address(0) || receiver == address(this)) {
            revert IRebasingAwareERC4626.InvalidReceiver(receiver);
        }
        uint256 supplyBefore = asset.totalSupply();
        uint256 vaultBefore = asset.balanceOf(address(this));
        uint256 receiverBefore = asset.balanceOf(receiver);
        asset.safeTransfer(receiver, expected);
        uint256 supplyAfter = asset.totalSupply();
        if (supplyAfter != supplyBefore) {
            revert IRebasingAwareERC4626.AssetSupplyChangedDuringTransfer(supplyBefore, supplyAfter);
        }
        (uint256 vaultDebit,) = _movement(vaultBefore, asset.balanceOf(address(this)));
        (, uint256 receiverCredit) = _movement(receiverBefore, asset.balanceOf(receiver));
        if (vaultDebit != expected || receiverCredit != expected) {
            revert IRebasingAwareERC4626.AssetTransferMismatch(expected, vaultDebit, receiverCredit);
        }
    }

    function takeShares(address owner, uint256 amount, ShareSource source) internal {
        if (source == ShareSource.CallerOrApprovedOwner) {
            uint256 bal = ERC20Repo._balanceOf(owner);
            if (bal < amount) {
                revert IERC20Errors.ERC20InsufficientBalance(owner, bal, amount);
            }
            if (msg.sender != owner) {
                ERC20Repo._spendAllowance(owner, msg.sender, amount);
            }
            ERC20Repo._burn(owner, amount);
            return;
        }
        uint256 prepaid = ERC20Repo._balanceOf(address(this));
        if (amount > prepaid) {
            revert IRebasingAwareERC4626.InsufficientPretransferredShares(amount, prepaid);
        }
        ERC20Repo._burn(address(this), amount);
        if (source == ShareSource.PublicBalanceRefundExcess) {
            uint256 refund = prepaid - amount;
            if (refund > 0) {
                ERC20Repo._transfer(address(this), msg.sender, refund);
            }
        }
    }

    function assertEntryCapacity(Book memory book, uint256 assetsIn, uint256 sharesMinted) internal pure {
        if (assetsIn > type(uint256).max - 1 - book.assets) {
            revert IRebasingAwareERC4626.NumericDomainExceeded();
        }
        if (sharesMinted > type(uint256).max - book.virtualShares - book.supply) {
            revert IRebasingAwareERC4626.NumericDomainExceeded();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                               Money routes                             */
    /* ---------------------------------------------------------------------- */

    function executeDeposit(uint256 assets, address receiver, uint256 minShares, bool emitSy)
        internal
        returns (uint256 shares)
    {
        if (assets == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        requireReceiver(receiver, false);
        requireInboundEnabled();
        Book memory book = liveBook();
        if (book.assets == 0 && book.supply > 0) {
            revert IRebasingAwareERC4626.ZeroReserveWithOutstandingShares();
        }
        uint256 capacity = maxDepositFromBook(book);
        if (assets > capacity) {
            revert IERC4626Errors.ERC4626ExceededMaxDeposit(receiver, assets, capacity);
        }
        shares = sharesForDeposit(assets, book);
        if (shares == 0) revert IRebasingAwareERC4626.ZeroOperationOutput();
        if (shares < minShares) {
            revert IStandardExchangeErrors.MinAmountNotMet(minShares, shares);
        }
        assertEntryCapacity(book, assets, shares);
        pullAssets(book.asset, msg.sender, assets);
        ERC20Repo._mint(receiver, shares);
        emit IERC4626Events.Deposit(msg.sender, receiver, assets, shares);
        if (emitSy) {
            emit IStandardizedYield.Deposit(msg.sender, receiver, address(book.asset), assets, shares);
        }
    }

    function executeMint(uint256 shares, address receiver, uint256 maxAssets, bool emitSy)
        internal
        returns (uint256 assets)
    {
        if (shares == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        requireReceiver(receiver, false);
        requireInboundEnabled();
        Book memory book = liveBook();
        if (book.assets == 0 && book.supply > 0) {
            revert IRebasingAwareERC4626.ZeroReserveWithOutstandingShares();
        }
        uint256 capacity = maxMintFromBook(book);
        if (shares > capacity) {
            revert IERC4626Errors.ERC4626ExceededMaxMint(receiver, shares, capacity);
        }
        assets = assetsForMint(shares, book);
        if (assets == 0) revert IRebasingAwareERC4626.ZeroOperationOutput();
        if (assets > maxAssets) {
            revert IStandardExchangeErrors.MaxAmountExceeded(maxAssets, assets);
        }
        assertEntryCapacity(book, assets, shares);
        pullAssets(book.asset, msg.sender, assets);
        ERC20Repo._mint(receiver, shares);
        emit IERC4626Events.Deposit(msg.sender, receiver, assets, shares);
        if (emitSy) {
            emit IStandardizedYield.Deposit(msg.sender, receiver, address(book.asset), assets, shares);
        }
    }

    function executeRedeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssets,
        ShareSource source,
        bool emitSy
    ) internal returns (uint256 assets) {
        if (shares == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        if (receiver == address(0) || receiver == address(this)) {
            revert IRebasingAwareERC4626.InvalidReceiver(receiver);
        }
        Book memory book = liveBook();
        assets = assetsForRedeem(shares, book);
        if (assets == 0) revert IRebasingAwareERC4626.ZeroOperationOutput();
        if (assets > book.assets) revert IRebasingAwareERC4626.NumericDomainExceeded();
        if (assets < minAssets) {
            revert IStandardExchangeErrors.MinAmountNotMet(minAssets, assets);
        }
        if (source == ShareSource.CallerOrApprovedOwner && shares > ERC20Repo._balanceOf(owner)) {
            revert IERC4626Errors.ERC4626ExceededMaxRedeem(owner, shares, ERC20Repo._balanceOf(owner));
        }
        takeShares(owner, shares, source);
        payAssets(book.asset, receiver, assets);
        emit IERC4626Events.Withdraw(msg.sender, receiver, owner, assets, shares);
        if (emitSy) {
            emit IStandardizedYield.Redeem(msg.sender, receiver, address(book.asset), shares, assets);
        }
    }

    function executeWithdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxShares,
        ShareSource source,
        bool emitSy
    ) internal returns (uint256 shares) {
        if (assets == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        if (receiver == address(0) || receiver == address(this)) {
            revert IRebasingAwareERC4626.InvalidReceiver(receiver);
        }
        Book memory book = liveBook();
        if (assets > book.assets) revert IRebasingAwareERC4626.NumericDomainExceeded();
        shares = sharesForWithdraw(assets, book);
        if (shares == 0) revert IRebasingAwareERC4626.ZeroOperationOutput();
        if (shares > maxShares) {
            revert IStandardExchangeErrors.MaxAmountExceeded(maxShares, shares);
        }
        if (source == ShareSource.CallerOrApprovedOwner) {
            uint256 owned = ERC20Repo._balanceOf(owner);
            uint256 maxW = assetsForRedeem(owned, book);
            if (assets > maxW) {
                revert IERC4626Errors.ERC4626ExceededMaxWithdraw(owner, assets, maxW);
            }
        }
        takeShares(owner, shares, source);
        payAssets(book.asset, receiver, assets);
        emit IERC4626Events.Withdraw(msg.sender, receiver, owner, assets, shares);
        if (emitSy) {
            emit IStandardizedYield.Redeem(msg.sender, receiver, address(book.asset), shares, assets);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              Quote helpers                             */
    /* ---------------------------------------------------------------------- */

    function decodeQuoteState(bytes memory state)
        internal
        view
        returns (IRebasingAwareERC4626.QuoteState memory q)
    {
        if (state.length != QUOTE_STATE_BYTES) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
        _requireAddressWord(state, 64);
        _requireAddressWord(state, 96);
        _requireAddressWord(state, 128);
        _requireUint8Word(state, 256);
        q = abi.decode(state, (IRebasingAwareERC4626.QuoteState));
        IERC20 asset = RebasingAwareERC4626Repo._asset();
        uint8 offset = RebasingAwareERC4626Repo._decimalOffset();
        if (
            q.version != QUOTE_STATE_VERSION || q.chainId != block.chainid || q.exchange != address(this)
                || q.asset != address(asset) || q.decimalOffset != offset
        ) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
        Book memory book = Book({
            asset: asset,
            assets: q.assets,
            supply: q.supply,
            virtualShares: virtualSharesOf(offset),
            decimalOffset: offset
        });
        assertDomain(book);
        if (q.holderShares > q.supply) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
    }

    function snapshotQuoteState(address asset, address holder)
        internal
        view
        returns (bytes memory state, uint256 holderAssets)
    {
        requireUnlocked();
        IERC20 configured = RebasingAwareERC4626Repo._asset();
        if (asset != address(configured)) {
            revert IStandardExchangeTransitionQuote.UnsupportedQuoteAsset(asset);
        }
        Book memory book = liveBook();
        IRebasingAwareERC4626.QuoteState memory q = IRebasingAwareERC4626.QuoteState({
            version: QUOTE_STATE_VERSION,
            chainId: block.chainid,
            exchange: address(this),
            asset: address(configured),
            holder: holder,
            assets: book.assets,
            supply: book.supply,
            holderShares: ERC20Repo._balanceOf(holder),
            decimalOffset: book.decimalOffset
        });
        holderAssets = holderValue(q.holderShares, book);
        state = abi.encode(q);
    }

    function bookFromQuote(IRebasingAwareERC4626.QuoteState memory q)
        internal
        pure
        returns (Book memory book)
    {
        book.assets = q.assets;
        book.supply = q.supply;
        book.decimalOffset = q.decimalOffset;
        book.virtualShares = virtualSharesOf(q.decimalOffset);
    }

    function _requireAddressWord(bytes memory state, uint256 offset) private pure {
        bytes32 word;
        assembly ("memory-safe") {
            word := mload(add(add(state, 32), offset))
        }
        if (uint256(word) >> 160 != 0) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
    }

    function _requireUint8Word(bytes memory state, uint256 offset) private pure {
        bytes32 word;
        assembly ("memory-safe") {
            word := mload(add(add(state, 32), offset))
        }
        if (uint256(word) >> 8 != 0) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
    }
}
