"""Check changed integrations against the completed full default build.

No source-root/profile changes, cache deletion or reduced fuzz settings. This
selection precedes, and does not replace, the complete default hermetic run.
"""
from pathlib import Path
import json
import re
import subprocess
import time
from build_provenance import capture, hermetic_environment

art = Path(__file__).resolve().parent
root = art.parent.parent
build = json.loads((art / 'implementation-full-build.json').read_text())
assert build['exit_code'] == 0, 'Wait for the successful full default build.'
provenance = capture(root)
assert provenance['source_and_config_sha256'] == build['provenance']['source_and_config_sha256'], 'Source changed after full build.'
environment, emptied = hermetic_environment(root)
names = [
    'test_lidoBufferUsesApprovedPaymentsForFallbackAndFundedBond',
    'test_customBondQuoteIncludesWrappingBeforeIssuance',
    'test_customDonationQuoteIncludesWrappingBeforeReserveJoin',
    'test_seShareFallbackComposesActualRedemptionAndSwap',
    'test_customProtocolShareFallbackComposesActualConversionAndSwap',
    'test_reentrancy_mint_hitsIsLocked',
    'test_orbitalStage_replayRegisteredPackageAndDeployableFacets',
    'test_stataCurrentFacetCannotReuseOccupiedLegacyNamespace',
]
command = ['forge', 'test', '--offline', '--match-test', '(' + '|'.join(names) + ')', '-vvv']
record = {'command': command, 'provenance': provenance,
          'prior_full_build': 'implementation-full-build.json',
          'scope': 'Changed nested payments, four-family custom quotes/custody, migrated reentrancy controls, Stata salt and main Orbital launch stage. Full hermetic remains separate.',
          'explicitly_empty_rpc_environment_keys': emptied}
start = time.monotonic()
with (art / 'post-build-followups.log').open('w') as output:
    process = subprocess.Popen(command, cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT)
    record['pid'] = process.pid
    (art / 'post-build-followups-start.json').write_text(json.dumps(record, indent=2) + '\n')
    code = process.wait()
lines = (art / 'post-build-followups.log').read_text().split('\nFailing tests:', 1)[0].splitlines()
results = [line for line in lines if line.startswith(('[PASS]', '[FAIL'))]
missing = [name for name in names if not any(re.search(r'\b' + re.escape(name) + r'\b', line) for line in results)]
record.update(exit_code=code, seconds=round(time.monotonic() - start, 3),
              executed_cases=len(results), missing_required_regressions=missing,
              validation_passed=code == 0 and bool(results) and not missing)
(art / 'post-build-followups.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'exit_code': code, 'seconds': record['seconds']}), flush=True)
for line in lines:
    if line.startswith(('Ran ', '[FAIL')):
        print(line, flush=True)
if not record['validation_passed'] and code == 0:
    print('Required regression execution missing: ' + ', '.join(missing), flush=True)
    code = 1
raise SystemExit(code)
