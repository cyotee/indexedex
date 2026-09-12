"""Share immutable fixture deployments; apply only after the current test process exits."""
from pathlib import Path
import hashlib
import json
import difflib

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
record = artifacts / 'mixed-native-infrastructure-consolidation.json'
assert not record.exists(), 'Already applied; preserve provenance.'
base_path = Path('contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol')
decimal_path = base_path.with_name('TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol')
base = (root / base_path).read_text()
before = base
base = base.replace('uint8 internal fixtureBufferDecimals = 18;',
    'uint8 internal fixtureBufferDecimals = 18;\n    bool private mixedInfrastructureReady;')
start = base.index('    function setUp() public virtual override {')
finish = base.index('    /// @dev Decimal fixtures customize', start)
old_setup = base[start:finish]
infra_end = old_setup.index('        _initializeMixedFixtureLegs();')
infra = old_setup[len('    function setUp() public virtual override {\n'):infra_end]
book = old_setup[infra_end:old_setup.rfind('    }')]
new_setup = '''    function setUp() public virtual override {
        _initializeMixedInfrastructure();
''' + book + '''    }

    /// @dev Deploy actual protocols, manager and packages once per isolated test. Decimal
    /// matrices snapshot this common infrastructure, then deploy a fresh token/SE/DETF book
    /// for every assertion. All touched balances and protocol state roll back between books.
    function _initializeMixedInfrastructure() internal {
        if (mixedInfrastructureReady) return;
''' + infra + '''        mixedInfrastructureReady = true;
    }

'''
base = base[:start] + new_setup + base[finish:]
decimal_before = (root / decimal_path).read_text()
decimal = decimal_before.replace(
    '/// @dev Each assertion runs against eight fresh real package/protocol deployments.',
    '/// @dev Each assertion runs against eight fresh token/SE/DETF books on shared real infrastructure.')
anchor = 'function _runAllNativeBooks(function() internal setup_, function() internal assertion_) internal {'
assert decimal.count(anchor) == 1
decimal = decimal.replace(anchor, anchor + '\n        _initializeMixedInfrastructure();')
rows = []
for path, initial, final in ((base_path, before, base), (decimal_path, decimal_before, decimal)):
    assert initial != final
    rows.append({'path': str(path), 'before_sha256': hashlib.sha256(initial.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(final.encode()).hexdigest(),
                 'diff': ''.join(difflib.unified_diff(initial.splitlines(True), final.splitlines(True), fromfile=str(path), tofile=str(path)))})
for path, source in ((base_path, base), (decimal_path, decimal)):
    (root / path).write_text(source)
record.write_text(json.dumps({'status': 'applied; full native matrix validation pending', 'rows': rows,
    'preserved': 'All eight books, every original assertion, per-book state snapshot/rollback and actual registry/protocol/token deployments. No mocks or lowered fuzz settings.',
    'consolidated': 'Common manager, protocol and package deployment once per native matrix test instead of eight times; book-specific setUp still executes each time.'}, indent=2) + '\n')
print('Shared native matrix infrastructure without changing assertions; validation pending.')
