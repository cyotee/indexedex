"""Match the router's second proportional rounding after the active Forge run exits."""
from pathlib import Path
import hashlib
import json
import difflib

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
record = artifacts / 'aerodrome-compound-router-rounding.json'
assert not record.exists(), 'Already applied; preserve provenance.'
path = Path('contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol')
before = (root / path).read_text()
start = before.index('    function _previewApplyProportionalDeposit(')
end = before.index('    function _previewApplyZapSingleSided(', start)
function = before[start:end]
anchor = '        lpFromProportional = ConstProdUtils._depositQuote('
assert function.count(anchor) == 1
function = function.replace(anchor, '''        // Execution passes the precomputed proportional amounts to Router.addLiquidity,
        // which applies its own proportional floor again before transferring either token.
        (uint256 amount0_, uint256 amount1_) = _proportionalDeposit(
            poolState.reserve0, poolState.reserve1, amounts.proportional0, amounts.proportional1
        );

''' + anchor)
function = function.replace('            amounts.proportional0,\n            amounts.proportional1,',
    '            amount0_,\n            amount1_,')
function = function.replace('poolState.reserve0 += amounts.proportional0;', 'poolState.reserve0 += amount0_;')
function = function.replace('poolState.reserve1 += amounts.proportional1;', 'poolState.reserve1 += amount1_;')
after = before[:start] + function + before[end:]
assert after != before
(root / path).write_text(after)
record.write_text(json.dumps({'status': 'applied; regression validation pending', 'path': str(path),
    'before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
    'trace_evidence': {'case': 'Adversarial_MixedBuffer_P0_Test.test_B1_reserveFallback_mintBurn_boundsSafety',
        'requested_amount1': 8841219542414946, 'router_transferred_amount1': 8841219542414945,
        'preview_input': 106541199074757214666, 'execution_required_input': 106541199074757214667},
    'diff': ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path), tofile=str(path))),
    'preserved': 'Actual execution, fee fractions, deposit/zap equations and exact-output slippage bounds. Preview alone now accounts for the router transfer floors.'}, indent=2) + '\n')
print('Aligned compound preview with actual router transfer rounding; validation pending.')
