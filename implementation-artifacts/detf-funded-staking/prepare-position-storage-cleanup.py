"""Remove proved-unused V3/V4 position storage in an unapplied source patch."""
from pathlib import Path
import difflib, hashlib, json, re

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}

def function_span(text, name, parameters=None):
    matches = list(re.finditer(r'    function ' + re.escape(name) + r'\(([^)]*)\)', text))
    if parameters is not None:
        matches = [m for m in matches if ' '.join(m[1].split()) == parameters]
    assert len(matches) == 1, (name, parameters, len(matches))
    start = matches[0].start()
    opening = text.index('{', matches[0].end())
    depth = 1
    end = opening + 1
    while depth:
        if text[end] == '{': depth += 1
        elif text[end] == '}': depth -= 1
        end += 1
    return start, end

def set_function(text, name, replacement='', parameters=None):
    start, end = function_span(text, name, parameters)
    return text[:start] + replacement + text[end:]

v3 = root / 'contracts/protocols/dexes/uniswap/v3'
v4 = root / 'contracts/protocols/dexes/uniswap/v4'

for base, filename in [(v3, 'UniswapV3VaultRepo.sol'), (v4, 'UniswapV4PositionRepo.sol')]:
    p = base / filename
    before = p.read_text()
    text = before
    for declaration in ['uint160 lastSqrtPriceX96;', 'int24 lastTick;', 'uint32 lastTimestamp;', 'uint128 liquidity;']:
        assert text.count('        ' + declaration + '\n') == 1
        text = text.replace('        ' + declaration + '\n', '')
    while re.search(r'    function _setPoolState\(', text):
        parameters = ' '.join(re.search(r'    function _setPoolState\(([^)]*)\)', text)[1].split())
        text = set_function(text, '_setPoolState', parameters=parameters)
    text = text.replace('        layout_.centerPosition.liquidity = 0;\n', '')
    if base == v3:
        for parameters in ['Storage storage layout_, uint128 liquidity_', 'uint128 liquidity_']:
            text = set_function(text, '_updatePositionLiquidity', parameters=parameters)
    else:
        text = re.sub(r'    bytes32 internal constant (LOWER|UPPER)_WING_SALT = [^;]+;\n', '', text)
        text = re.sub(r'    enum PositionKind \{[^}]+\}\n', '', text)
        text = re.sub(r'        PositionState (lower|upper)WingPosition;\n', '', text)
        text = re.sub(r'        layout_\.(lower|upper)WingPosition\.[^;]+;\n', '', text)
        text = set_function(text, '_position')
        for name in ['_liquidity', '_updateLiquidity']:
            while re.search(r'    function ' + name + r'\(', text):
                parameters = ' '.join(re.search(r'    function ' + name + r'\(([^)]*)\)', text)[1].split())
                text = set_function(text, name, parameters=parameters)
        text = text.replace('Storage storage layout_, PositionKind kind_, ', 'Storage storage layout_, ')
        text = text.replace('PositionKind kind_, ', '')
        text = text.replace('_createPositionIfNeeded(_layout(), kind_, ', '_createPositionIfNeeded(_layout(), ')
        text = text.replace('PositionState storage position_ = _position(layout_, kind_);', 'PositionState storage position_ = layout_.centerPosition;')
        text = text.replace('layout_.centerPosition.created || layout_.lowerWingPosition.created || layout_.upperWingPosition.created', 'layout_.centerPosition.created')
        for name in ['_isPositionCreated', '_positionTicks', '_salt']:
            for parameters in ['Storage storage layout_, PositionKind kind_', 'PositionKind kind_']:
                text = set_function(text, name, parameters=parameters)
    text = re.sub(r'\n{3,}', '\n\n', text)
    changes[str(p.relative_to(root))] = (before, text)

for base in [v3, v4]:
    for p in sorted(base.glob('*.sol')):
        if p.name in ['UniswapV3VaultRepo.sol', 'UniswapV4PositionRepo.sol']: continue
        before = p.read_text()
        text = before
        if base == v3:
            if p.name == 'UniswapV3StandardExchangePositionImportTarget.sol':
                # Internal scratch state only; ImportedPosition retains the external NFT ABI layout.
                for declaration in ['uint160 sqrtPriceX96;', 'uint128 remintLiquidity;', 'uint256 amount0Used;', 'uint256 amount1Used;']:
                    assert text.count('        ' + declaration + '\n') == 1
                    text = text.replace('        ' + declaration + '\n', '')
            if '    function _updateManagedPositionLiquidities(' in text:
                text = set_function(text, '_updateManagedPositionLiquidities')
            text = re.sub(r'^\s*_updateManagedPositionLiquidities\(\);\n', '', text, flags=re.M)
        else:
            if p.name == 'UniswapV4StandardExchangeCommon.sol':
                text = text.replace('Multi arrays must be exactly the two PoolKey currencies, unique, strictly ascending.',
                    'Multi arrays follow PoolKey order with native ETH represented by WETH.\n     *      The WETH face need not sort before currency1; exact identity/order rejects duplicates.')
                start, end = function_span(text, '_isDualPoolCurrencies')
                body = text[start:end]
                redundant = '        if (tokens[0] >= tokens[1]) {\n            return false;\n        }\n'
                assert redundant in body
                text = text[:start] + body.replace(redundant, redundant.replace('>=', '==')) + text[end:]
                text = set_function(text, '_currentLiquidity', parameters='')
                text = set_function(text, '_positionAmounts', parameters='')
                text = set_function(text, '_refreshStoredLiquidity')
                text = text.replace(''' && !UniswapV4PositionRepo._isImportedPosition()
            && _currentLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing) == 0
            && _currentLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing) == 0''',
                    ' && !UniswapV4PositionRepo._isImportedPosition()')
                text = set_function(text, '_quoteManagedWithdrawal', '''    function _quoteManagedWithdrawal(uint256 sharesBurned, uint256 totalShares)
        internal view returns (uint256 amount0, uint256 amount1)
    {
        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        return _quotePositionWithdrawal(sqrtPriceX96, tick, sharesBurned, totalShares);
    }''')
                text = set_function(text, '_freeBalancesForShareMath', '''    function _freeBalancesForShareMath() internal view returns (uint256 free0, uint256 free1) {
        (free0, free1) = _freeBalances();
        (uint256 fee0, uint256 fee1) = _collectablePositionFees();
        free0 += fee0;
        free1 += fee1;
    }''')
                start, end = function_span(text, '_collectManagedFeesIfIdle')
                body = text[start:end]
                body = body.replace('        for (uint256 i; i < 3; ++i) {\n', '')
                body = body.replace('            UniswapV4PositionRepo.PositionKind kind = UniswapV4PositionRepo.PositionKind(i);\n', '')
                body = body.replace('if (fee0 == 0 && fee1 == 0) continue;', 'if (fee0 == 0 && fee1 == 0) return;')
                assert body.endswith('        }\n    }')
                body = body[:-len('        }\n    }')] + '    }'
                lines = body.splitlines()
                for i in range(2, len(lines) - 1):
                    if lines[i].startswith('            '): lines[i] = lines[i][4:]
                text = text[:start] + '\n'.join(lines) + text[end:]
                text = re.sub(r'        (int24|uint128|uint256) (lowerWing|upperWing)\w+;\n', '', text)
                text = re.sub(r'^\s*managedTicks\.(lowerWing|upperWing)\w+ = [^;]+;\n', '', text, flags=re.M)
                text = re.sub(r'^\s*budgets\.(lowerWing|upperWing)\w+ = [^;]+;\n', '', text, flags=re.M)
                text = re.sub(r'        \(managedTicks\.(lowerWing|upperWing)\w+,[^;]+;\n', '', text)
                text = text.replace('One full-range center. Wings unused (zero-width placeholders).', 'One full-range center; live pool state is authoritative.')
            text = re.sub(r'^\s*_refreshStoredLiquidity\(\);\n', '', text, flags=re.M)
            text = re.sub(r'^\s*_burnPositionLiquidity\(UniswapV4PositionRepo.PositionKind\.(LowerWing|UpperWing),[^;]+;\n', '', text, flags=re.M)
            text = re.sub(r'            if \(kind != UniswapV4PositionRepo.PositionKind.Center\) \{\n                return(?: \(0, 0, 0\))?;\n            \}\n', '', text)
            text = re.sub(r'UniswapV4PositionRepo.PositionKind kind,\s*', '', text)
            text = text.replace('UniswapV4PositionRepo.PositionKind kind', '')
            text = re.sub(r'UniswapV4PositionRepo.PositionKind.Center,\s*', '', text)
            text = text.replace('UniswapV4PositionRepo.PositionKind.Center', '')
            text = text.replace('(kind)', '()')
            assert not re.search(r'\bkind\b|PositionKind|lowerWing|upperWing', text), p.name
        if text != before:
            text = re.sub(r'\n{3,}', '\n\n', text)
            changes[str(p.relative_to(root))] = (before, text)

patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
    fromfile='a/' + path, tofile='b/' + path)) for path, (before, after) in changes.items())
(art / 'position-storage-cleanup.patch').write_text(patch)
(art / 'position-storage-cleanup-prepared.json').write_text(json.dumps({
    'status': 'PREPARED_NOT_APPLIED',
    'authority': 'Owner-required unused storage/dead-code cleanup, plan section 8.1 and approved V3/V4 full-range deployment. Shared-source search confirms no dependency from excluded or deferred products.',
    'removed': ['V3/V4 unread lastSqrtPriceX96/lastTick/lastTimestamp', 'V3/V4 write-only cached liquidity and refresh calls', 'V4 never-created wing positions, salts, enum routing and redundant fee/burn traversals', 'V4 zero-only wing plan members', 'Four obsolete V3 import scratch fields; external position ABI decode structure preserved'],
    'preserved': ['Maximum usable full-range center', 'Actual live pool/position-manager liquidity and fee math', 'Imported-position custody and authorization', 'Sleeve and locked-pool operation', 'Existing proxy tests, including independent absent-wing assertions', 'No Slipstream or Balancer DETF edits; no live upgrades'],
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()],
    'validation': 'Pending independent draft compilation, existing full-range/import/fee/lock tests and final release build.',
}, indent=2) + '\n')
print('Prepared position cleanup across', len(changes), 'sources; no Solidity changed.')
