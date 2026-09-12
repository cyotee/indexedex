"""Prepare optional external SE mint projection for composed custom input routes.

The projected buffered holder keeps its own shares. User shares are newly issued
to a separate recipient, and fee shares still reach their configured recipient.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
changes = []

def stage(relative, transform):
    path = root / relative
    before = path.read_text()
    after = transform(before)
    assert before != after, relative
    changes.append((path, before, after))

def extend_interface(source):
    anchor = 'interface IStandardExchangeExternalQuote {\n'
    assert anchor in source
    assert 'function quoteExternalDeposit' not in source
    return source.replace(anchor, anchor + '''    /// @notice Project a separate recipient minting SE shares from an accepted
    /// input. The snapshot asset remains the accounting/output asset; input may
    /// be the other pool currency or the protocol's own receipt/LP token.
    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 sharesOut, uint256 holderAssetsAfter);

''', 1)

stage('contracts/interfaces/IStandardExchangeTransitionQuote.sol', extend_interface)

def position_provider(source):
    anchor = '    function quoteExternalExchange('
    assert anchor in source
    assert 'function quoteExternalDeposit' not in source
    return source.replace(anchor, '''    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 sharesOut, uint256 holderAssetsAfter)
    {
        InventoryQuote memory q = _decodeInventory(state);
        if (tokenIn != _token0() && tokenIn != _token1()) revert ITransition.UnsupportedQuoteAsset(tokenIn);
        bool accountingToken0 = q.token0;
        q.token0 = tokenIn == _token0();
        if (amountIn != 0) {
            sharesOut = _inventoryDeposit(q, amountIn);
            // The mint recipient is separate from the buffered holder.
            q.shares -= sharesOut;
            if (q.idle) _inventoryRebalance(q);
        }
        q.token0 = accountingToken0;
        return (abi.encode(q), sharesOut, _inventoryAssets(q, q.shares));
    }

''' + anchor, 1)

for version in ['v3', 'v4']:
    stage(f'contracts/protocols/dexes/uniswap/{version}/Uniswap{version.upper()}StandardExchangeInQueryTarget.sol', position_provider)

def erc4626_provider(source):
    anchor = '    function quoteExternalExchange('
    assert anchor in source
    return source.replace(anchor, '''    function quoteExternalDeposit(bytes calldata state_, address tokenIn_, uint256 amountIn_)
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

''' + anchor, 1)

stage('contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol', erc4626_provider)

def v2_provider(source):
    anchor = '    function quoteExternalExchange('
    assert anchor in source
    return source.replace(anchor, '''    function quoteExternalDeposit(bytes calldata state_, address tokenIn_, uint256 amountIn_)
        external view returns (bytes memory nextState_, uint256 sharesOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = _decodeQuote(state_);
        if (tokenIn_ == address(q.pool.pool)) {
            _calcVaultFee(q.pool, q.vault);
            if (q.holder == address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo())) q.holderShares += q.vault.feeShares;
            sharesOut_ = BetterMath._convertToSharesDown(
                amountIn_, q.vault.vaultLpReserve, q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );
            q.vault.vaultTotalShares += sharesOut_;
            q.actualLp += amountIn_;
            q.vault.vaultLpReserve = q.actualLp;
            q.vault.knownTokenLastOwnedSourceReserve = BetterMath._mulDiv(q.actualLp, q.pool.knownReserve, q.pool.totalSupply);
            q.vault.opTokenLastOwnedSourceReserve = BetterMath._mulDiv(q.actualLp, q.pool.opposingReserve, q.pool.totalSupply);
            q.vault.feeShares = 0;
        } else {
            if (tokenIn_ != q.pool.token0 && tokenIn_ != q.pool.token1) revert UnsupportedQuoteAsset(tokenIn_);
            bool flipped = tokenIn_ != q.asset;
            if (flipped) _flipQuoteAsset(q);
            (bytes memory projected,, uint256 minted,) = IStandardExchangeTransitionQuote(address(this)).quoteTransition(
                abi.encode(q), Operation.DepositExactIn, amountIn_
            );
            q = abi.decode(projected, (QuoteState));
            q.holderShares -= minted;
            sharesOut_ = minted;
            if (flipped) _flipQuoteAsset(q);
        }
        return (abi.encode(q), sharesOut_, _quoteAssets(q, q.holderShares));
    }

    function _flipQuoteAsset(QuoteState memory q) private pure {
        q.asset = q.asset == q.pool.token0 ? q.pool.token1 : q.pool.token0;
        (q.knownBalance, q.opposingBalance) = (q.opposingBalance, q.knownBalance);
        (q.pool.knownReserve, q.pool.opposingReserve) = (q.pool.opposingReserve, q.pool.knownReserve);
        (q.pool.knownfeePercent, q.pool.opTokenFeePercent) = (q.pool.opTokenFeePercent, q.pool.knownfeePercent);
        (q.vault.knownTokenLastOwnedSourceReserve, q.vault.opTokenLastOwnedSourceReserve) =
            (q.vault.opTokenLastOwnedSourceReserve, q.vault.knownTokenLastOwnedSourceReserve);
    }

''' + anchor, 1)

stage('contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeQuoteTarget.sol', v2_provider)

def append_selector(source):
    assert '.quoteExternalDeposit.selector' not in source
    # Restrict array edits to the actual function/control selector list.
    marker = re.search(r'(funcs|controlFuncs) = new bytes4\[\]\((\d+)\);', source)
    assert marker
    name, length = marker[1], int(marker[2])
    source = source[:marker.start()] + marker[0].replace(f'({length})', f'({length + 1})') + source[marker.end():]
    last = re.search(rf'        {name}\[{length - 1}\] = [^;]+;', source)
    assert last
    return source[:last.end()] + f'\n        {name}[{length}] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;' + source[last.end():]

for relative in [
    'contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInFacet.sol',
    'contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryFacet.sol',
    'contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol',
    'contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol',
    'test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryFacet_IFacet_Test.t.sol',
    'test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet_IFacet_Test.t.sol',
]:
    stage(relative, append_selector)

if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    for path, before, after in changes:
        assert path.read_text() == before
        path.write_text(after)
report = {
    'status': 'applied; validation pending' if args.apply else 'prepared, not applied while Solidity compiles',
    'scope': 'Optional provider projection only. Four providers preserve current deposit formulas and holder inventory; fee shares remain correctly attributed. No execution route authorization change.',
    'next': 'Wire projected external mint state into actual host donation/bond previews and validate external deposits with real providers before considering this capability complete.',
    'files': [{'path': str(path.relative_to(root)), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, before, after in changes],
}
(artifacts / 'external-se-deposit-projection.patch').write_text(''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))) for path, before, after in changes))
(artifacts / 'external-se-deposit-projection.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'status': report['status'], 'prepared_files': len(changes), 'next': report['next']}, indent=2))
