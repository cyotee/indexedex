"""Prepare retained V2/Camelot LP-denominated quote routes without editing Solidity."""
from pathlib import Path
import difflib, hashlib, json

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}

for family, directory in [('UniswapV2', 'uniswap/v2'), ('CamelotV2', 'camelot/v2')]:
    path = f'contracts/protocols/dexes/{directory}/{family}StandardExchangeQuoteTarget.sol'
    before = (root / path).read_text()
    text = before
    def replace(old, new):
        global text
        assert text.count(old) == 1, (family, old[:100])
        text = text.replace(old, new)

    replace('''        _loadIndexSourceReserves(q.pool, IERC20(asset_));
        if (asset_ != q.pool.token0 && asset_ != q.pool.token1) revert UnsupportedQuoteAsset(asset_);
        _loadStrategyVault(q.vault, IERC20(asset_));''', '''        bool lpAsset_ = asset_ == address(q.pool.pool);
        // LP-denominated claims still checkpoint the two pool legs in token0 order.
        _loadIndexSourceReserves(q.pool, lpAsset_ ? IERC20(address(0)) : IERC20(asset_));
        if (!lpAsset_ && asset_ != q.pool.token0 && asset_ != q.pool.token1) revert UnsupportedQuoteAsset(asset_);
        address known_ = lpAsset_ ? q.pool.token0 : asset_;
        _loadStrategyVault(q.vault, IERC20(known_));''')
    replace('''        q.knownBalance = IERC20(asset_).balanceOf(address(q.pool.pool));
        q.opposingBalance = IERC20(asset_ == q.pool.token0 ? q.pool.token1 : q.pool.token0).balanceOf(address(q.pool.pool));''', '''        q.knownBalance = IERC20(known_).balanceOf(address(q.pool.pool));
        q.opposingBalance = IERC20(known_ == q.pool.token0 ? q.pool.token1 : q.pool.token0).balanceOf(address(q.pool.pool));''')
    replace('''        amountIn_ = amount_;
        if (operation_ == Operation.DepositExactIn) {
            if (q.actualLp != q.vault.vaultLpReserve) revert InvalidQuoteState();
            uint256 lp_ = _quoteDeposit(q, amount_);
            amountOut_ = BetterMath._convertToSharesDown(
                lp_, q.vault.vaultLpReserve, q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );''', '''        amountIn_ = amount_;
        bool lpAsset_ = q.asset == address(q.pool.pool);
        if (operation_ == Operation.DepositExactIn) {
            if (!lpAsset_ && q.actualLp != q.vault.vaultLpReserve) revert InvalidQuoteState();
''' + ('''            if (lpAsset_ && q.vault.vaultTotalShares == 0 && q.actualLp > q.vault.vaultLpReserve) revert InvalidQuoteState();
''' if family == 'CamelotV2' else '') + '''            uint256 lp_ = lpAsset_ ? amount_ : _quoteDeposit(q, amount_);
            amountOut_ = BetterMath._convertToSharesDown(
                lp_, lpAsset_ ? q.actualLp : q.vault.vaultLpReserve,
                q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );''')
    replace('''                lp_ = ConstProdUtils._quoteZapOutToTargetWithFee(''', '''                lp_ = lpAsset_ ? amount_ : ConstProdUtils._quoteZapOutToTargetWithFee(''')
    replace('''            amountOut_ = _quoteWithdraw(q, lp_);''', '''            amountOut_ = lpAsset_ ? lp_ : _quoteWithdraw(q, lp_);''')
    if family == 'UniswapV2':
        replace('''                amountIn_, q.vault.vaultLpReserve, q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );''', '''                amountIn_, q.actualLp, q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );''')
    replace('''            bool flipped = tokenIn_ != q.asset;
            if (flipped) _flipQuoteAsset(q);''', '''            address accounting_ = q.asset;
            if (q.asset == address(q.pool.pool)) q.asset = q.pool.token0;
            bool flipped = tokenIn_ != q.asset;
            if (flipped) _flipQuoteAsset(q);''')
    replace('''            sharesOut_ = minted;
            if (flipped) _flipQuoteAsset(q);''', '''            sharesOut_ = minted;
            if (flipped) _flipQuoteAsset(q);
            q.asset = accounting_;''')
    replace('''        address opposing_ = q.asset == q.pool.token0 ? q.pool.token1 : q.pool.token0;
        if (tokenIn_ == address(q.pool.pool)) {''', '''        address opposing_ = q.asset == q.pool.token0 ? q.pool.token1 : q.pool.token0;
        if (q.asset == address(q.pool.pool)) {
            if (tokenIn_ != q.pool.token0 && tokenIn_ != q.pool.token1) revert UnsupportedQuoteAsset(tokenIn_);
            q.asset = q.pool.token0;
            bool flipped = tokenIn_ != q.asset;
            if (flipped) _flipQuoteAsset(q);
            amountOut_ = _quoteDeposit(q, amountIn_);
            if (flipped) _flipQuoteAsset(q);
            q.asset = address(q.pool.pool);
            // The live pass-through returns newly minted LP to its caller and
            // rejects any change to the SE's held LP, including pool fee LP.
            if (q.actualLp != q.vault.vaultLpReserve) revert InvalidQuoteState();
        } else if (tokenIn_ == address(q.pool.pool)) {''')
    if family == 'UniswapV2':
        replace('''            amountOut_ = _quoteWithdraw(q, amountIn_);
        } else if''', '''            amountOut_ = _quoteWithdraw(q, amountIn_);
            if (q.actualLp != q.vault.vaultLpReserve) revert InvalidQuoteState();
        } else if''')
    replace('''        return ''' + family + '''Utils._quoteWithdraw''', '''        if (q.asset == address(q.pool.pool)) return lp_;
        return ''' + family + '''Utils._quoteWithdraw''')
    changes[path] = (before, text)

path = 'test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol'
before = (root / path).read_text()
text = before.replace('abstract contract ConstantProductNativeSYBehavior is Test {',
                      'abstract contract ConstantProductNativeSYBehavior is TransitionQuoteAssertions {')
text = text.replace('ConstantProductNativeSYBehavior, TransitionQuoteAssertions {', 'ConstantProductNativeSYBehavior {')
marker = '    function test_nativeLPMetadataAndCompleteSelectors() public view {'
assert text.count(marker) == 1
text = text.replace(marker, (art / 'pending-cp-lp-accounting-tests.sol.txt').read_text() + '\n' + marker)
changes[path] = (before, text)

patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
    fromfile='a/' + path, tofile='b/' + path)) for path, (before, after) in changes.items())
(art / 'cp-lp-accounting.patch').write_text(patch)
(art / 'cp-lp-accounting-prepared.json').write_text(json.dumps({
    'status': 'PREPARED_NOT_APPLIED',
    'reason': 'Existing standard LP payment and redemption routes must remain usable as composed accounting assets.',
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()],
    'validation': 'Pending compiled production-proxy sequences and full-state comparisons; no execution proof from source review.',
    'application': 'Included by prepare-aerodrome-projection.py to consolidate the shared fixture edit; do not apply both patches.',
}, indent=2) + '\n')
print('Prepared V2/Camelot LP accounting and shared proxy checks; no Solidity changed.')
