"""Apply only after the active Forge invocation finishes; reuse funded test bodies."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
output = artifacts / 'mixed-decimal-security-consolidation.json'
assert not output.exists(), 'Already applied; preserve original source provenance.'
testdir = Path('test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer')
basedir = Path('contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer')
base = 'TestBase_MixedBufferMultiVaultStableDetf'
decimal = base + '_Decimals'
adv = base + '_Adversarial'
rows = []
staged = {}


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def write(path, text, **extra):
    full = root / path
    old = full.read_text()
    staged[path] = text
    rows.append({'source': str(path), 'before_sha256': digest(old), 'after_sha256': digest(text),
                 'before_lines': len(old.splitlines()), 'after_lines': len(text.splitlines()), **extra})


def tests(text):
    return re.findall(r'function (test_\w+)\(', text)


def adapter(destination, canonical_path, canonical_class, setup_class):
    old_tests = tests((root / destination).read_text())
    shared_tests = tests((root / canonical_path).read_text())
    name = destination.stem
    imports = {
        canonical_class: canonical_path,
        base: basedir / (base + '.sol'),
        decimal: basedir / (decimal + '.sol'),
    }
    if setup_class not in imports:
        imports[setup_class] = testdir / 'adversarial' / (setup_class + '.sol')
    text = '// SPDX-License-Identifier: BSL-1.1\npragma solidity ^0.8.0;\n\n'
    text += 'import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";\n'
    text += ''.join(f'import {{{cls}}} from "{path}";\n' for cls, path in imports.items())
    text += f'''
/// @notice Canonical funded security behavior over real native-decimal token books.
abstract contract {name} is {canonical_class}, {decimal} {{
    function setUp() public override({setup_class}, {base}) {{
        {setup_class}.setUp();
    }}

    function _fixtureBufferToken() internal view override({base}, {decimal}) returns (IERC20) {{
        return {decimal}._fixtureBufferToken();
    }}

    function _initializeMixedFixtureLegs() internal override({base}, {decimal}) {{
        {decimal}._initializeMixedFixtureLegs();
    }}

    function _deployExtraDaiSeVault(uint8 idx) internal override({base}, {decimal}) {{
        {decimal}._deployExtraDaiSeVault(idx);
    }}
}}
'''
    mapping = []
    p0 = {r['old_test']: r['funded_test'] for r in json.loads(
        (artifacts / 'mixed-funded-p0-migration.json').read_text())['cases']}
    for old in old_tests:
        target = old if old in shared_tests else p0.get(old)
        if old == 'test_reentrancy_mintSharePath_nestedHitsIsLocked':
            target = 'test_reentrancy_mintBufferPath_nestedHitsIsLocked'
        if target is None and old.startswith('test_N'):
            prefix = old.split('_', 2)[1]
            matches = [t for t in shared_tests if t.split('_', 2)[1] == prefix]
            assert len(matches) == 1, (old, matches)
            target = matches[0]
        assert target in shared_tests, (old, target)
        mapping.append({'old_test': old, 'funded_test': target,
                        'disposition': 'Same security concern on funded routes. Token callbacks come from a hostile underlying in a registered real SE; the former minted mock SE is removed.'})
    write(destination, text, canonical_source=str(canonical_path), old_tests=old_tests,
          shared_tests=shared_tests, mapping=mapping)


# Keep the existing no-argument hostile token intact for its other callers.
hostile_path = Path('contracts/test/adversarial/HostileReentrantShare.sol')
hostile = (root / hostile_path).read_text()
hostile += '''
/// @notice The same transfer callback probe with an immutable native token precision.
contract HostileReentrantShareDecimals is HostileReentrantShare {
    uint8 private immutable nativeDecimals;

    constructor(uint8 decimals_) { nativeDecimals = decimals_; }

    function decimals() public view override returns (uint8) { return nativeDecimals; }
}
'''
write(hostile_path, hostile)

adv_path = testdir / 'adversarial' / (adv + '.sol')
text = (root / adv_path).read_text()
text = text.replace('import {HostileReentrantShare}', 'import {HostileReentrantShare, HostileReentrantShareDecimals}')
text = text.replace('import {IERC20} from', 'import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";\nimport {IERC20} from', 1)
text = text.replace('hostileBuffer = new HostileReentrantShare();',
                    'hostileBuffer = new HostileReentrantShareDecimals(IERC20Metadata(address(_fixtureBufferToken())).decimals());')
text = text.replace('address(dai)', 'address(_fixtureBufferToken())').replace('dai.approve(', '_fixtureBufferToken().approve(')
write(adv_path, text, note='Registered real Aerodrome SE retained; hostile underlying and ordinary legs use the selected native precision.')

donation_path = testdir / 'MixedBufferMultiVaultStableDetf_ReserveDonation.t.sol'
text = (root / donation_path).read_text()
assert 'function setUp() public override' in text
write(donation_path, text.replace('function setUp() public override', 'function setUp() public virtual override', 1))

# Assertions must observe the actual selected book, including unsupported raw-leg inputs.
price_path = testdir / 'MixedBufferMultiVaultStableDetf_PriceShift.t.sol'
text = (root / price_path).read_text()
write(price_path, text.replace('dai.balanceOf(', '_fixtureBufferToken().balanceOf('))
routes_path = testdir / 'MixedBufferMultiVaultStableDetf_Routes.t.sol'
text = (root / routes_path).read_text()
text = text.replace('address(usdc)', 'legTokenB[0]')
text = text.replace('// usdc is not buffer for this DETF (buffer=dai) and not a vault share',
                    '// The other raw SE leg is neither this DETF buffer nor an accepted vault share.')
text = text.replace('// mint usdc to bob first', '// Fund the actual other raw leg before exercising the unsupported route.')
write(routes_path, text)

# The retained LP-only bond regression calls its canonical private funding helper.
# Its obsolete decimal copy has no remaining callers after behavior consolidation.
decimal_path = basedir / (decimal + '.sol')
text = (root / decimal_path).read_text()
start = text.index('    function _fundReserveBpt(')
end = text.index('    function _from18(', start)
text = text[:start] + text[end:]
for symbol in ('IVault', 'IStakedDETF', 'FundedPrimaryRouteAssertions'):
    text = re.sub(r'^import \{' + symbol + r'\} from [^\n]+\n', '', text, flags=re.MULTILINE)
text = text.replace(base + ', FundedPrimaryRouteAssertions', base)
write(decimal_path, text, note='Remove the unused duplicate external-LP funding helper; retain the actual LP-purchase test and canonical real Router funding.')

adapter(testdir / 'decimals' / 'MixedBufferMultiVaultStableDetf_ReserveDonation_Decimals.sol',
        donation_path, 'MixedBufferMultiVaultStableDetf_ReserveDonation', 'MixedBufferMultiVaultStableDetf_ReserveDonation')
adapter(testdir / 'decimals' / 'MixedBufferMultiVaultStableDetf_Reentrancy_Decimals.sol',
        testdir / 'MixedBufferMultiVaultStableDetf_Reentrancy.t.sol',
        'MixedBufferMultiVaultStableDetf_Reentrancy_Test', 'MixedBufferMultiVaultStableDetf_Reentrancy_Test')
adapter(testdir / 'decimals' / 'adversarial' / (adv + '_Decimals.sol'), adv_path, adv, adv)
for category in ('P0', 'A0'):
    canonical_class = 'Adversarial_MixedBuffer_' + category + '_Test'
    adapter(testdir / 'decimals' / 'adversarial' / ('Adversarial_MixedBuffer_' + category + '_Decimals.sol'),
            testdir / 'adversarial' / ('Adversarial_MixedBuffer_' + category + '.t.sol'), canonical_class, adv)

for path in (root / testdir / 'decimals').rglob('*_B_*.t.sol'):
    text = path.read_text()
    old = 'vaultShare / detfToken / claim / Bond NFT stay 18.'
    if old in text:
        write(path.relative_to(root), text.replace(old, 'SE shares retain native precision; DETF and funded staking receipts use 9 decimals.'))

for path, text in staged.items():
    (root / path).write_text(text)

output.write_text(json.dumps({'status': 'applied; build and native security validation pending', 'rows': rows,
    'scope': 'Preserve actual native-book wrappers and security cases; share funded behavior. No LP-only purchase/discovery retirement.'}, indent=2) + '\n')
print('Applied', len(rows), 'source changes. Validation remains pending.')
