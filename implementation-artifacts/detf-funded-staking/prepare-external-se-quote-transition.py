"""Prepare sequential quotes for an external input exchanged into a buffered asset.

This does not change execution or impose a route allowlist. Apply only after the
active Forge process exits; wire provider selectors/tests and host composition
in the same validation batch before claiming completion.
"""
from pathlib import Path
import datetime, hashlib, json, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
changes = {}

def insert(relative, needle, added):
    p = root / relative
    before = p.read_text()
    assert needle in before, p
    after = before.replace(needle, added + needle, 1)
    changes[p] = (before, after)

p = root / 'contracts/interfaces/IStandardExchangeTransitionQuote.sol'
b = p.read_text()
addition = '''
/// @notice Project a separate caller's standard swap/redemption into the asset
/// selected by quoteState, retaining the buffered holder's own SE inventory.
/// @dev The returned state includes provider fees and liquidity/sleeve changes.
/// This optional quote extension does not alter standard route authorization.
interface IStandardExchangeExternalQuote {
    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 amountOut, uint256 holderAssetsAfter);
}
'''
assert 'interface IStandardExchangeExternalQuote' not in b
changes[p] = (b, b + addition)

for version in (3, 4):
    insert(f'contracts/protocols/dexes/uniswap/v{version}/UniswapV{version}StandardExchangeInQueryTarget.sol',
           '    function quoteShareBalance(', '''    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 amountOut, uint256 holderAssetsAfter)
    {
        InventoryQuote memory q = _decodeInventory(state);
        // The snapshot asset is the output. The separate caller supplies the
        // opposing pool currency; no buffered-holder shares are minted or burned.
        if (tokenIn != (q.token0 ? _token1() : _token0())) {
            revert ITransition.UnsupportedQuoteAsset(tokenIn);
        }
        if (!q.idle) revert ITransition.InvalidQuoteState();
        if (amountIn != 0) {
            amountOut = _inventorySwap(q, amountIn);
            _inventoryRebalance(q);
        }
        return (abi.encode(q), amountOut, _inventoryAssets(q, q.shares));
    }

''')

insert('contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeQuoteTarget.sol',
       '    function quoteShareBalance(', '''    function quoteExternalExchange(bytes calldata state_, address tokenIn_, uint256 amountIn_)
        external view returns (bytes memory nextState_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = _decodeQuote(state_);
        address opposing_ = q.asset == q.pool.token0 ? q.pool.token1 : q.pool.token0;
        if (tokenIn_ == address(q.pool.pool)) {
            // These LP tokens belong to the separate caller. Retain the SE's own
            // LP and fee checkpoints; only the shared pool state changes.
            amountOut_ = _quoteWithdraw(q, amountIn_);
        } else if (tokenIn_ == opposing_) {
            amountOut_ = ConstProdUtils._saleQuote(
                amountIn_, q.pool.opposingReserve, q.pool.knownReserve,
                q.pool.opTokenFeePercent, UNISWAPV2_FEE_DENOMINATOR
            );
            q.knownBalance -= amountOut_;
            q.opposingBalance += amountIn_;
            q.pool.knownReserve = q.knownBalance;
            q.pool.opposingReserve = q.opposingBalance;
        } else revert UnsupportedQuoteAsset(tokenIn_);
        return (abi.encode(q), amountOut_, _quoteAssets(q, q.holderShares));
    }

''')

insert('contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol',
       '    function quoteShareBalance(', '''    function quoteExternalExchange(bytes calldata state_, address tokenIn_, uint256 amountIn_)
        external view returns (bytes memory nextState_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || q.vault != address(protocolVault())) revert InvalidQuoteState();
        if (tokenIn_ != q.vault) revert UnsupportedQuoteAsset(tokenIn_);
        // The external payment is already-issued protocol-vault shares. Receive
        // and redeem just those shares; the buffered holder retains its SE stake.
        (q.vaultState,,,) = IStandardExchangeTransitionQuote(q.vault)
            .quoteTransition(q.vaultState, Operation.ReceiveShares, amountIn_);
        (q.vaultState,, amountOut_,) = IStandardExchangeTransitionQuote(q.vault)
            .quoteTransition(q.vaultState, Operation.RedeemExactIn, amountIn_);
        q.vaultShares = IStandardExchangeTransitionQuote(q.vault).quoteShareBalance(q.vaultState);
        return (abi.encode(q), amountOut_, _quoteHolderAssets(q));
    }

''')

for p, (before, after) in changes.items():
    if '--apply' in sys.argv:
        p.write_text(after)
    else:
        (art / ('pending-external-transition-' + p.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_PROVIDER_WIRING_TESTS_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'purpose': 'Project actual SE pass-through swaps and external protocol-vault/LP redemptions before a reserve swap, without inventing holder share movements or changing execution economics.',
    'remaining_before_validation': [
        'Export the optional selector on the four provider facets and migrate independent selector controls.',
        'Generalize reserve composition to use the new quote for configured custom inputs, preserving existing share-redemption behavior.',
        'Exercise real restored-snapshot execution, including V4 Pons fees, V2 fee-on and ERC4626 protocol shares.',
        'Resolve opaque ERC4626 compatibility independently; this extension alone does not make unsupported underlying transition quotes work.',
        'Project provider-dependent rates and non-native donation wrapping where applicable.',
    ],
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'external-se-quote-transition.json').write_text(json.dumps(record, indent=2)+'\n')
print(record['status'])
