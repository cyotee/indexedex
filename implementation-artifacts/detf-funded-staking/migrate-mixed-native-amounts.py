"""Use native payment units for real decimal fixtures; keep WAD thresholds/prices."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
output = artifacts / 'mixed-native-amount-migration.json'
assert not output.exists(), 'Already applied.'
testdir = Path('test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer')
base = Path('contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol')
rows = []


def write(path, text):
    full = root / path
    old = full.read_text()
    full.write_text(text)
    rows.append({'source': str(path), 'before_sha256': hashlib.sha256(old.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(text.encode()).hexdigest()})


text = (root / base).read_text()
text = text.replace('import {IERC20} from', 'import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";\nimport {IERC20} from', 1)
needle = '    function _fundBuffer(address to, uint256 amount) internal {'
assert needle in text
text = text.replace(needle, '''    /// @dev Test payment amounts use the selected buffer's native units; WAD prices stay WAD.
    function _fixtureAmount(uint256 wad_) internal view returns (uint256) {
        uint8 decimals_ = IERC20Metadata(address(_fixtureBufferToken())).decimals();
        return decimals_ >= 18 ? wad_ * 10 ** (decimals_ - 18) : wad_ / 10 ** (18 - decimals_);
    }

''' + needle, 1)
text = text.replace('_bootstrapFirstBond(instance_, user, BOOTSTRAP_BUFFER, BOOTSTRAP_SHARE_FUND)',
                    '_bootstrapFirstBond(instance_, user, _fixtureAmount(BOOTSTRAP_BUFFER), _fixtureAmount(BOOTSTRAP_SHARE_FUND))')
write(base, text)

groups = ['Deploy','Bootstrap','Mint','Burn','NLegs','Guards','Routes','RateProviders',
          'Pricing','PriceShift','Nested','NestedPush','ReserveDonation','Reentrancy']
paths = [testdir / ('MixedBufferMultiVaultStableDetf_' + group + '.t.sol') for group in groups]
paths += [testdir / 'adversarial' / name for name in [
    'TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol',
    'Adversarial_MixedBuffer_P0.t.sol', 'Adversarial_MixedBuffer_A0.t.sol']]
for path in paths:
    lines = (root / path).read_text().splitlines(keepends=True)
    converted = []
    for line in lines:
        # These are dimensionless price/threshold expressions or raw reserve-skew trades.
        # Skew trades retain their size relative to the deliberately deep underlying pool.
        if (line.lstrip().startswith('//') or any(marker in line for marker in (
            '_deployDetfN(', '_buildPkgArgs(', 'mintThreshold', 'burnThreshold',
            'mintTh_', 'burnTh_', 'syntheticPrice(), 1e18', '_shiftUnderlyingPrice('))):
            converted.append(line)
            continue
        # Unsupported LP/junk probes retain their own token units; the exact-output probe
        # requests native DETF units, independent of the input buffer's precision.
        if 'route_.donate(lp_' in line or 'route_.donate(IERC20(address(junk_))' in line:
            converted.append(line)
            continue
        if 'previewExchangeOut(address,address,uint256)' in line:
            converted.append(line.replace('uint256(1e18)', 'uint256(1e9)'))
            continue
        line = re.sub(r'(?<![\w.])([\d_]+e18)\b', r'_fixtureAmount(\1)', line)
        line = re.sub(r'\bBOOTSTRAP_BUFFER\b', '_fixtureAmount(BOOTSTRAP_BUFFER)', line)
        converted.append(line)
    write(path, ''.join(converted))

# Arm the expectation immediately before the exchange, after metadata lookups.
path = testdir / 'MixedBufferMultiVaultStableDetf_NestedPush.t.sol'
text = (root / path).read_text()
old = '''        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        liveExchangeIn.exchangeIn(
            IERC20(liveInfo.bufferToken()), 0, IERC20(liveDetf), 0, bob, false, block.timestamp + 1 hours
'''
new = '''        IERC20 buffer_ = IERC20(liveInfo.bufferToken());
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        liveExchangeIn.exchangeIn(
            buffer_, 0, IERC20(liveDetf), 0, bob, false, block.timestamp + 1 hours
'''
assert old in text
write(path, text.replace(old, new, 1))
output.write_text(json.dumps({'status': 'applied; validation pending', 'rows': rows,
    'failure_evidence': 'mixed-native-nested-full-trace-test.log',
    'cause': 'A six-decimal first payment of 1000e18 normalized to 1e33 and overflowed the StableMath iteration. The eight-book funded lifecycle already passed with actual native payments.',
    'preserved': 'WAD price thresholds, actual underlying reserve-skew magnitudes, all assertions, raw nine-decimal DETF amounts and full production deployments.'}, indent=2) + '\n')
print('Updated', len(rows), 'fixture/payment sources; validation pending.')
