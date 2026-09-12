"""Apply after the decimal security migration and after the active Forge run exits."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
assert (artifacts / 'mixed-decimal-security-consolidation.json').exists(), 'Apply the mapped security migration first.'
output = artifacts / 'mixed-native-matrix-consolidation.json'
assert not output.exists(), 'Already applied; do not overwrite original coverage mapping.'
testdir = Path('test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer')
basepath = Path('contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol')
staged = {}
removed = []
rows = []


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def read(path):
    return staged.get(path, (root / path).read_text() if (root / path).exists() else '')


def write(path, text):
    staged[path] = text


text = read(basepath)
old = '''    function _pairDecimals() internal view virtual returns (uint8);
    function _rateDecimals() internal view virtual returns (uint8);
    function _restDecimals() internal view virtual returns (uint8) { return 18; }
'''
assert old in text
replacement = '''    uint8[3] private selectedNativeBook = [uint8(18), 18, 18];

    event NativeDecimalBook(uint8 pairDecimals, uint8 rateDecimals, uint8 restDecimals);

    function _pairDecimals() internal view virtual returns (uint8) { return selectedNativeBook[0]; }
    function _rateDecimals() internal view virtual returns (uint8) { return selectedNativeBook[1]; }
    function _restDecimals() internal view virtual returns (uint8) { return selectedNativeBook[2]; }

    /// @dev Each assertion runs against eight fresh real package/protocol deployments.
    /// Snapshot restoration isolates the books without duplicating compiled test contracts.
    function _runAllNativeBooks(function() internal setup_, function() internal assertion_) internal {
        uint8[3][8] memory books_ = [
            [uint8(6), 6, 6], [uint8(9), 9, 9], [uint8(6), 9, 18], [uint8(6), 18, 18],
            [uint8(9), 6, 18], [uint8(9), 18, 18], [uint8(18), 6, 18], [uint8(18), 9, 18]
        ];
        for (uint256 i_; i_ < books_.length; ++i_) {
            uint256 snapshot_ = vm.snapshotState();
            selectedNativeBook = books_[i_];
            emit NativeDecimalBook(books_[i_][0], books_[i_][1], books_[i_][2]);
            setup_();
            assertion_();
            assertTrue(vm.revertToState(snapshot_));
        }
    }
'''
write(basepath, text.replace(old, replacement, 1))

groups = [
    ('MixedBufferMultiVaultStableDetf_' + name, testdir)
    for name in ('Deploy', 'Bootstrap', 'Mint', 'Burn', 'NLegs', 'Guards', 'Routes',
                 'RateProviders', 'Pricing', 'PriceShift', 'Nested', 'NestedPush',
                 'ReserveDonation', 'Reentrancy')
] + [('Adversarial_MixedBuffer_' + name, testdir / 'adversarial') for name in ('P0', 'A0')]

for stem, canonical_dir in groups:
    canonical = canonical_dir / (stem + '.t.sol')
    decimal_dir = testdir / 'decimals' / ('adversarial' if 'Adversarial_' in stem else '')
    adapter = decimal_dir / (stem + '_Decimals.sol')
    matrix = decimal_dir / (stem + '_NativeMatrix.t.sol')
    source = read(canonical)
    headers = re.findall(r'function (test_\w+)\(([^)]*)\)([^\{]+)\{', source)
    assert headers and all(not args and 'public' in modifiers and 'returns' not in modifiers
                           for _, args, modifiers in headers), canonical
    names = [name for name, _, _ in headers]
    def overridable(match):
        name, args, modifiers = match.groups()
        modifiers = re.sub(r'\b(view|pure)\b\s*', '', modifiers)
        if 'virtual' not in modifiers:
            modifiers = modifiers.replace('public', 'public virtual', 1)
        return f'function {name}({args}){modifiers}' + '{'
    write(canonical, re.sub(r'function (test_\w+)\(([^)]*)\)([^\{]+)\{', overridable, source))
    adapter_text = read(adapter)
    adapter_text = adapter_text.replace('function setUp() public override', 'function setUp() public virtual override')
    write(adapter, adapter_text)
    matrix_text = f'''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{{stem}_Decimals}} from "{adapter}";

/// @notice Each named regression runs independently across all eight native decimal books.
contract {stem}_NativeMatrix is {stem}_Decimals {{
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {{}}

'''
    for name in names:
        matrix_text += f'''    function {name}() public override {{
        _runAllNativeBooks(super.setUp, super.{name});
    }}

'''
    matrix_text += '}\n'
    write(matrix, matrix_text)
    wrappers = sorted((root / decimal_dir).glob(stem + '_B_*.t.sol'))
    assert len(wrappers) == 8, (stem, len(wrappers))
    wrapper_rows = []
    for wrapper in wrappers:
        path = wrapper.relative_to(root)
        old_source = wrapper.read_text()
        precision = [int(re.search(r'function _' + role + r'Decimals\(\)[\s\S]*?return (\d+);', old_source)[1])
                     for role in ('pair', 'rate', 'rest')]
        wrapper_rows.append({'source': str(path), 'sha256': sha(old_source), 'book': precision,
                             'replacement_source': str(matrix), 'replacement_tests': names})
        removed.append(path)
    assert {tuple(row['book']) for row in wrapper_rows} == {
        (6,6,6),(9,9,9),(6,9,18),(6,18,18),(9,6,18),(9,18,18),(18,6,18),(18,9,18)}
    rows.append({'canonical_source': str(canonical), 'native_matrix': str(matrix), 'tests': names,
                 'native_assertion_runs': len(names) * 8, 'replaced_wrappers': wrapper_rows})

suite = Path('test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol')
text = read(suite)
for path in removed:
    text = re.sub(r'^import [^\n]*' + re.escape(str(path)) + r'[^\n]*\n', '', text, flags=re.MULTILINE)
for row in rows:
    text += '\nimport "' + row['native_matrix'] + '";\n'
write(suite, text)

changes = []
for path, text in staged.items():
    full = root / path
    changes.append({'source': str(path), 'before_sha256': sha(full.read_text()) if full.exists() else None,
                    'after_sha256': sha(text)})
for path, text in staged.items():
    (root / path).write_text(text)
for path in removed:
    (root / path).unlink()
output.write_text(json.dumps({
    'status': 'applied; build/runtime validation pending', 'groups': len(rows),
    'old_native_test_contracts': len(removed), 'new_native_test_contracts': len(rows),
    'native_assertion_runs': sum(row['native_assertion_runs'] for row in rows),
    'rows': rows, 'source_changes': changes,
    'limits': 'No fuzz or invariant settings changed. LP-only bond/discovery wrappers remain pending. Test names now each execute eight real books; lower test counts do not imply fewer native assertions. Compilation/runtime improvement must be measured.'
}, indent=2) + '\n')
print('Consolidated', len(removed), 'native wrappers into', len(rows), 'matrices; validation pending.')
