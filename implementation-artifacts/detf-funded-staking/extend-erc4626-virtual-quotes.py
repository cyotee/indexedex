"""Project canonical ERC4626 virtual-balance vaults without requiring a vault extension."""
from pathlib import Path
import json,datetime,hashlib
root=Path.cwd();p=root/'contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol';b=p.read_text();s=b.replace('import {IERC20}', 'import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";\nimport {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";\nimport {IERC20}',1)
s=s.replace('        bytes vaultState;','        bytes vaultState;\n        bool nativeQuote;',1)
s=s.replace('        (q.vaultState,) = IStandardExchangeTransitionQuote(q.vault).quoteState(asset_, address(this));','''        try IStandardExchangeTransitionQuote(q.vault).quoteState(asset_, address(this))
            returns (bytes memory nested, uint256) {
            q.vaultState = nested;
            q.nativeQuote = true;
        } catch {
            q.vaultState = abi.encode(_virtualSnapshot(IERC4626(q.vault)));
        }''',1)
s=s.replace('''            (q.vaultState,, vaultAdded_,) = IStandardExchangeTransitionQuote(q.vault)
                .quoteTransition(q.vaultState, Operation.DepositExactIn, amount_);''','''            (, vaultAdded_) = _vaultTransition(q, Operation.DepositExactIn, amount_);''')
s=s.replace('''                (, uint256 needed_,,) = IStandardExchangeTransitionQuote(q.vault)
                    .quoteTransition(q.vaultState, Operation.WithdrawExactOut, amount_);''','''                QuoteState memory copy = abi.decode(abi.encode(q), (QuoteState));
                (uint256 needed_,) = _vaultTransition(copy, Operation.WithdrawExactOut, amount_);''')
s=s.replace('''            (q.vaultState,, amountOut_,) = IStandardExchangeTransitionQuote(q.vault)
                .quoteTransition(q.vaultState, Operation.RedeemExactIn, vaultOut_);''','''            (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, vaultOut_);''')
s=s.replace('IStandardExchangeTransitionQuote(q.vault).quoteShareBalance(q.vaultState)','_vaultShareBalance(q)')
s=s.replace('IStandardExchangeTransitionQuote(q.vault).quoteAssets(q.vaultState, vaultClaim_)','_vaultAssets(q, vaultClaim_)')
s=s.replace('''        (q.vaultState,,,) = IStandardExchangeTransitionQuote(q.vault)
            .quoteTransition(q.vaultState, Operation.ReceiveShares, amountIn_);
        (q.vaultState,, amountOut_,) = IStandardExchangeTransitionQuote(q.vault)
            .quoteTransition(q.vaultState, Operation.RedeemExactIn, amountIn_);''','''        _vaultTransition(q, Operation.ReceiveShares, amountIn_);
        (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, amountIn_);''')
addition='''
    /// @dev Canonical ERC4626 virtual balances. Effective supply includes the
    /// performance-fee shares already included in the vault's conversion views.
    /// No protocol storage is changed by this optional projection capability.
    struct VirtualVault {
        uint256 assets;
        uint256 supply;
        uint256 virtualShares;
        uint256 heldShares;
        uint256 pendingHeldFee;
    }

    function _virtualSnapshot(IERC4626 vault) private view returns (VirtualVault memory v) {
        v.assets = vault.totalAssets();
        uint8 shareDecimals = IERC20Metadata(address(vault)).decimals();
        uint8 assetDecimals = IERC20Metadata(vault.asset()).decimals();
        if (shareDecimals < assetDecimals || shareDecimals - assetDecimals > 77) revert InvalidQuoteState();
        v.virtualShares = 10 ** (shareDecimals - assetDecimals);
        // For (assets + 1)/(supply + virtual shares), this exact denominator
        // probe recovers effective supply without losing sub-share precision.
        uint256 scaledSupply = vault.convertToShares(v.assets + 1);
        uint256 issued = vault.totalSupply();
        if (scaledSupply < issued + v.virtualShares) revert InvalidQuoteState();
        v.supply = scaledSupply - v.virtualShares;
        v.heldShares = vault.balanceOf(address(this));
        if (vault.convertToAssets(scaledSupply) != v.assets + 1) revert InvalidQuoteState();
        uint256 probe = 10 ** assetDecimals;
        if (vault.previewDeposit(probe) != Math.mulDiv(probe, scaledSupply, v.assets + 1)
            || vault.previewRedeem(v.heldShares) != _virtualAssets(v, v.heldShares)) revert InvalidQuoteState();
        if (v.supply > issued) {
            (bool ok, bytes memory data) = address(vault).staticcall(abi.encodeWithSignature("feeRecipient()"));
            if (ok && data.length == 32 && abi.decode(data, (address)) == address(this)) {
                v.pendingHeldFee = v.supply - issued;
            }
        }
    }

    function _virtualAssets(VirtualVault memory v, uint256 shares) private pure returns (uint256) {
        return Math.mulDiv(shares, v.assets + 1, v.supply + v.virtualShares);
    }

    function _vaultAssets(QuoteState memory q, uint256 shares) private view returns (uint256) {
        if (q.nativeQuote) return IStandardExchangeTransitionQuote(q.vault).quoteAssets(q.vaultState, shares);
        return _virtualAssets(abi.decode(q.vaultState, (VirtualVault)), shares);
    }

    function _vaultShareBalance(QuoteState memory q) private view returns (uint256) {
        if (q.nativeQuote) return IStandardExchangeTransitionQuote(q.vault).quoteShareBalance(q.vaultState);
        return abi.decode(q.vaultState, (VirtualVault)).heldShares;
    }

    function _vaultTransition(QuoteState memory q, Operation operation, uint256 amount)
        private view returns (uint256 amountIn, uint256 amountOut)
    {
        if (q.nativeQuote) {
            (q.vaultState, amountIn, amountOut,) = IStandardExchangeTransitionQuote(q.vault)
                .quoteTransition(q.vaultState, operation, amount);
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
                amountOut = Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + 1);
                v.assets += amount;
                v.supply += amountOut;
                v.heldShares += amountOut;
            } else {
                if (operation == Operation.WithdrawExactOut) {
                    amountIn = Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + 1, Math.Rounding.Ceil);
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
'''
assert '    function quoteTotalSupply(' in s;s=s.replace('    function quoteTotalSupply(',addition+'\n    function quoteTotalSupply(',1)
p.write_text(s)
art=root/'implementation-artifacts/detf-funded-staking';(art/'erc4626-virtual-state-projection.json').write_text(json.dumps({'status':'APPLIED_VALIDATION_PENDING','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'path':str(p.relative_to(root)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest(),'scope':'Optional exact virtual-balance projection for canonical ERC4626 providers; preserve native provider transition implementations when available. Execution acceptance is unchanged. Validate real Crane vault and MetaMorpho provider with accrued fees; arbitrary noncanonical models still require their own exact transition capability.'},indent=2)+'\n');print('applied ERC4626 virtual-state projection')
