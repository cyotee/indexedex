"""Comparable warmed policy-fixture measurements, before and after candidate ordering."""
from pathlib import Path
import json, os, re, shutil, subprocess, sys

art = Path(__file__).resolve().parent
root = art.parents[1]
label = sys.argv[1]
assert label in ('before', 'after')
environment = os.environ.copy()
environment['DETF_MATCH_CONTRACT'] = '^UniswapV4Detf_(Weighted|Quad)_Alignment_RedeemD15$'
environment['DETF_MATCH_TEST'] = '^test_D15_'
result = subprocess.run([sys.executable, str(art / 'run-focused-suite.py')], cwd=root, env=environment)
for suffix in ('run.json', 'build.log', 'test.log'):
    shutil.copy2(art / ('funded-suite-' + suffix), art / ('policy-fixture-' + label + '-' + suffix))
run = json.loads((art / ('policy-fixture-' + label + '-run.json')).read_text())
contract = ''
cases = []
for line in (art / ('policy-fixture-' + label + '-test.log')).read_text().splitlines():
    if line.startswith('Ran ') and '.t.sol:' in line:
        contract = line.rsplit(':', 1)[-1]
    match = re.match(r'\[PASS\] (\w+)\(\) \(gas: (\d+)\)', line)
    if match:
        cases.append({'contract': contract, 'test': match[1], 'gas': int(match[2])})
record = {
    'label': label, 'exit_code': result.returncode, 'build': run.get('build'), 'test': run.get('test'),
    'provenance': run['provenance'], 'cases': cases,
    'method': 'Identical contract/test selection, Foundry profile, fuzz settings and machine. Warm seeded cache, no cleaning and no concurrent Forge. Production source must remain unchanged between measurements; only the existing fixture candidate ordering changes.',
}
(art / ('policy-fixture-' + label + '.json')).write_text(json.dumps(record, indent=2) + '\n')
raise SystemExit(result.returncode)
