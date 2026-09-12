// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {ERC4626StandardExchangeCommon} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol";

abstract contract ERC4626StandardExchangeQuoteTarget is ERC4626StandardExchangeCommon, IStandardExchangeTransitionQuote {
    struct QuoteState {
        address exchange;
        address vault;
        address asset;
        address holder;
        uint256 holderShares;
        uint256 supply;
        uint256 vaultShares;
        bytes vaultState;
        bool nativeQuote;
        // Native nested snapshots track all issued shares. This separate gap
        // preserves actual wrapper custody through receipt transfers without
        // pretending those transfers mint or redeem underlying vault shares.
        uint256 nativeExcludedShares;
    }

    function quoteState(address asset_, address holder_)
        external view returns (bytes memory state_, uint256 holderAssets_)
    {
        if (asset_ != _underlying() && asset_ != address(protocolVault())) revert UnsupportedQuoteAsset(asset_);
        QuoteState memory q;
        q.exchange = address(this);
        q.vault = address(protocolVault());
        q.asset = asset_;
        q.holder = holder_;
        q.holderShares = IERC20(address(this)).balanceOf(holder_);
        q.supply = ERC20Repo._totalSupply();
        q.vaultShares = IERC20(q.vault).balanceOf(address(this));
        // IERC4626 execution is authoritative here. A nested SE can expose
        // separate deposit routes with different fees from IERC4626.deposit.
        (VirtualVault memory virtualState, bool canonical) = _virtualSnapshot(IERC4626(q.vault));
        if (!canonical) (virtualState, canonical) = _ratioSnapshot(IERC4626(q.vault));
        if (canonical) q.vaultState = abi.encode(virtualState);
        else {
            try IStandardExchangeTransitionQuote(q.vault).quoteState(_underlying(), address(this))
                returns (bytes memory nested, uint256) {
                q.vaultState = nested;
                q.nativeQuote = true;
                _normalizeNativeSnapshot(q);
            } catch { revert InvalidQuoteState(); }
        }
        holderAssets_ = _quoteHolderAssets(q);
        state_ = abi.encode(q);
    }

    function quoteTransition(bytes calldata state_, Operation operation_, uint256 amount_)
        external view returns (bytes memory nextState_, uint256 amountIn_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || q.vault != address(protocolVault())) revert InvalidQuoteState();
        if (operation_ == Operation.ReceiveShares) {
            q.holderShares += amount_;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            return (abi.encode(q), amount_, amount_, _quoteHolderAssets(q));
        }
        if (operation_ == Operation.DepositExactIn) {
            amountIn_ = amount_;
            uint256 vaultAdded_;
            (, vaultAdded_) = _vaultTransition(
                q, q.asset == q.vault ? Operation.ReceiveShares : Operation.DepositExactIn, amount_
            );
            amountOut_ = q.supply == 0 || q.vaultShares == 0
                ? vaultAdded_ : Math.mulDiv(vaultAdded_, q.supply, q.vaultShares);
            q.vaultShares = _vaultShareBalance(q);
            q.supply += amountOut_;
            q.holderShares += amountOut_;
            address feeTo_ = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
            if (feeTo_ != address(0)) {
                uint256 fee_ = Math.mulDiv(
                    amountOut_, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this)), 1e18
                );
                q.supply += fee_;
                if (q.holder == feeTo_) q.holderShares += fee_;
            }
        } else {
            amountIn_ = amount_;
            if (operation_ == Operation.WithdrawExactOut) {
                uint256 needed_ = amount_;
                if (q.asset != q.vault) {
                    QuoteState memory copy = abi.decode(abi.encode(q), (QuoteState));
                    (needed_,) = _vaultTransition(copy, Operation.WithdrawExactOut, amount_);
                }
                amountIn_ = q.supply == 0 || q.vaultShares == 0
                    ? needed_ : Math.mulDiv(needed_, q.supply, q.vaultShares, Math.Rounding.Ceil);
            }
            if (amountIn_ > q.holderShares) revert InsufficientQuoteShares(amountIn_, q.holderShares);
            uint256 vaultOut_ = q.asset == q.vault && operation_ == Operation.WithdrawExactOut
                ? amount_ : (q.supply == 0 ? 0 : Math.mulDiv(amountIn_, q.vaultShares, q.supply));
            if (q.asset == q.vault) {
                _sendVaultShares(q, vaultOut_);
                amountOut_ = vaultOut_;
            } else (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, vaultOut_);
            q.holderShares -= amountIn_;
            q.supply -= amountIn_;
            q.vaultShares = _vaultShareBalance(q);
        }
        holderAssetsAfter_ = _quoteHolderAssets(q);
        nextState_ = abi.encode(q);
    }

    function _quoteHolderAssets(QuoteState memory q) private view returns (uint256 amount_) {
        if (q.holderShares == 0 || q.supply == 0) return 0;
        uint256 vaultClaim_ = Math.mulDiv(q.holderShares, q.vaultShares, q.supply);
        if (vaultClaim_ == 0) return 0;
        return q.asset == q.vault ? vaultClaim_ : _vaultAssets(q, vaultClaim_);
    }

    function quoteAssets(bytes calldata state_, uint256 shares_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || q.vault != address(protocolVault())) revert InvalidQuoteState();
        q.holderShares = shares_;
        return _quoteHolderAssets(q);
    }

    function quoteExternalDeposit(bytes calldata state_, address tokenIn_, uint256 amountIn_)
        external view returns (bytes memory nextState_, uint256 sharesOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || q.vault != address(protocolVault())) revert InvalidQuoteState();
        uint256 added;
        if (tokenIn_ == q.vault) {
            (, added) = _vaultTransition(q, Operation.ReceiveShares, amountIn_);
        } else if (tokenIn_ == _underlying()) {
            (, added) = _vaultTransition(q, Operation.DepositExactIn, amountIn_);
        } else revert UnsupportedQuoteAsset(tokenIn_);
        sharesOut_ = q.supply == 0 || q.vaultShares == 0
            ? added : Math.mulDiv(added, q.supply, q.vaultShares);
        q.vaultShares = _vaultShareBalance(q);
        q.supply += sharesOut_;
        address feeTo = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeTo != address(0)) {
            uint256 fee = Math.mulDiv(sharesOut_, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this)), 1e18);
            q.supply += fee;
            if (q.holder == feeTo) q.holderShares += fee;
        }
        return (abi.encode(q), sharesOut_, _quoteHolderAssets(q));
    }

    function quoteExternalExchange(bytes calldata state_, address tokenIn_, uint256 amountIn_)
        external view returns (bytes memory nextState_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || q.vault != address(protocolVault())) revert InvalidQuoteState();
        if (q.asset == q.vault && tokenIn_ == _underlying()) {
            // The underlying deposit pays protocol receipts to the external
            // recipient, leaving the wrapper's existing receipt reserve intact.
            (, amountOut_) = _vaultTransition(q, Operation.DepositExactIn, amountIn_);
            _sendVaultShares(q, amountOut_);
        } else if (q.asset == _underlying() && tokenIn_ == q.vault) {
            // Redeem only the external payment, preserving buffered SE custody.
            _vaultTransition(q, Operation.ReceiveShares, amountIn_);
            (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, amountIn_);
        } else revert UnsupportedQuoteAsset(tokenIn_);
        q.vaultShares = _vaultShareBalance(q);
        return (abi.encode(q), amountOut_, _quoteHolderAssets(q));
    }


    /// @dev Canonical ERC4626 virtual balances. Effective supply includes the
    /// performance-fee shares already included in the vault's conversion views.
    /// No protocol storage is changed by this optional projection capability.
    struct VirtualVault {
        uint256 assets;
        uint256 supply;
        uint256 virtualShares;
        uint256 virtualAssets;
        uint256 heldShares;
        uint256 pendingHeldFee;
    }

    function _virtualSnapshot(IERC4626 vault) private view returns (VirtualVault memory v, bool canonical) {
        v.assets = vault.totalAssets();
        v.virtualAssets = 1;
        uint8 shareDecimals = IERC20Metadata(address(vault)).decimals();
        uint8 assetDecimals = IERC20Metadata(vault.asset()).decimals();
        if (shareDecimals < assetDecimals || shareDecimals - assetDecimals > 77) return (v, false);
        v.virtualShares = 10 ** (shareDecimals - assetDecimals);
        // For (assets + 1)/(supply + virtual shares), this exact denominator
        // probe recovers effective supply without losing sub-share precision.
        uint256 scaledSupply = vault.convertToShares(v.assets + 1);
        uint256 issued = vault.totalSupply();
        if (scaledSupply < issued + v.virtualShares) {
            // Existing Crane packages can retain 18 metadata decimals while
            // configuring a zero arithmetic offset for a 6/9-decimal receipt.
            // Recognize the exact issued+1 denominator, not a guessed fee pot.
            if (scaledSupply != issued + 1) return (v, false);
            v.virtualShares = 1;
        }
        v.supply = scaledSupply - v.virtualShares;
        v.heldShares = vault.balanceOf(address(this));
        if (vault.convertToAssets(scaledSupply) != v.assets + 1) return (v, false);
        uint256 probe = 10 ** assetDecimals;
        if (vault.previewDeposit(probe) != Math.mulDiv(probe, scaledSupply, v.assets + 1)
            || vault.previewRedeem(v.heldShares) != _virtualAssets(v, v.heldShares)) return (v, false);
        if (v.supply > issued) {
            (bool ok, bytes memory data) = address(vault).staticcall(abi.encodeWithSignature("feeRecipient()"));
            if (ok && data.length == 32 && abi.decode(data, (address)) == address(this)) {
                v.pendingHeldFee = v.supply - issued;
            }
        }
        canonical = true;
    }

    /// @dev Solmate-style proportional vaults, including the retained sfrxETH
    /// integration, have no virtual offsets. Check their actual conversion and
    /// directional previews before using that distinct balance model.
    function _ratioSnapshot(IERC4626 vault) private view returns (VirtualVault memory v, bool canonical) {
        v.assets = vault.totalAssets();
        v.supply = vault.totalSupply();
        v.heldShares = vault.balanceOf(address(this));
        if (v.assets == 0 || v.supply == 0) return (v, false);
        if (vault.convertToShares(v.assets) != v.supply || vault.convertToAssets(v.supply) != v.assets) return (v, false);
        uint256 probe = 10 ** IERC20Metadata(vault.asset()).decimals();
        canonical = vault.previewDeposit(probe) == Math.mulDiv(probe, v.supply, v.assets)
            && vault.previewWithdraw(probe) == Math.mulDiv(probe, v.supply, v.assets, Math.Rounding.Ceil)
            && vault.previewRedeem(v.heldShares) == _virtualAssets(v, v.heldShares);
    }

    function _virtualAssets(VirtualVault memory v, uint256 shares) private pure returns (uint256) {
        return Math.mulDiv(shares, v.assets + v.virtualAssets, v.supply + v.virtualShares);
    }

    function _vaultAssets(QuoteState memory q, uint256 shares) private view returns (uint256) {
        if (q.nativeQuote) return IStandardExchangeTransitionQuote(q.vault).quoteAssets(q.vaultState, shares);
        return _virtualAssets(abi.decode(q.vaultState, (VirtualVault)), shares);
    }

    function _vaultShareBalance(QuoteState memory q) private view returns (uint256) {
        if (q.nativeQuote) return IStandardExchangeTransitionQuote(q.vault).quoteTotalSupply(q.vaultState)
            - q.nativeExcludedShares;
        return abi.decode(q.vaultState, (VirtualVault)).heldShares;
    }

    function _vaultTransition(QuoteState memory q, Operation operation, uint256 amount)
        private view returns (uint256 amountIn, uint256 amountOut)
    {
        if (q.nativeQuote) {
            if (operation == Operation.ReceiveShares) {
                if (amount > q.nativeExcludedShares) revert InvalidQuoteState();
                q.nativeExcludedShares -= amount;
                return (amount, amount);
            }
            (q.vaultState, amountIn, amountOut,) = IStandardExchangeTransitionQuote(q.vault)
                .quoteTransition(q.vaultState, operation, amount);
            _normalizeNativeSnapshot(q);
            return (amountIn, amountOut);
        }
        VirtualVault memory v = abi.decode(q.vaultState, (VirtualVault));
        amountIn = amount;
        if (operation == Operation.ReceiveShares) {
            v.heldShares += amount;
            amountOut = amount;
        } else {
            v.heldShares += v.pendingHeldFee;
            v.pendingHeldFee = 0;
            if (operation == Operation.DepositExactIn) {
                amountOut = Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + v.virtualAssets);
                v.assets += amount;
                v.supply += amountOut;
                v.heldShares += amountOut;
            } else {
                if (operation == Operation.WithdrawExactOut) {
                    amountIn = Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + v.virtualAssets, Math.Rounding.Ceil);
                    amountOut = amount;
                } else amountOut = _virtualAssets(v, amount);
                if (amountIn > v.heldShares) revert InsufficientQuoteShares(amountIn, v.heldShares);
                v.assets -= amountOut;
                v.supply -= amountIn;
                v.heldShares -= amountIn;
            }
        }
        if (v.heldShares > v.supply) revert InvalidQuoteState();
        q.vaultState = abi.encode(v);
    }

    function _normalizeNativeSnapshot(QuoteState memory q) private view {
        IStandardExchangeTransitionQuote nested = IStandardExchangeTransitionQuote(q.vault);
        uint256 missing = nested.quoteTotalSupply(q.vaultState) - nested.quoteShareBalance(q.vaultState);
        if (missing == 0) return;
        q.nativeExcludedShares += missing;
        (q.vaultState,,,) = nested.quoteTransition(q.vaultState, Operation.ReceiveShares, missing);
    }

    function _sendVaultShares(QuoteState memory q, uint256 amount) private view {
        uint256 held = _vaultShareBalance(q);
        if (amount > held) revert InsufficientQuoteShares(amount, held);
        if (q.nativeQuote) q.nativeExcludedShares += amount;
        else {
            VirtualVault memory v = abi.decode(q.vaultState, (VirtualVault));
            v.heldShares -= amount;
            q.vaultState = abi.encode(v);
        }
    }

    function quoteTotalSupply(bytes calldata state_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || q.vault != address(protocolVault())) revert InvalidQuoteState();
        return q.supply;
    }

    function quoteShareBalance(bytes calldata state_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || q.vault != address(protocolVault())) revert InvalidQuoteState();
        return q.holderShares;
    }
}
