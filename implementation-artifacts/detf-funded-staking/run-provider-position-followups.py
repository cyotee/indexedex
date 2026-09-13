"""Run prepared follow-ups serially; stop on an actual build/test failure.

This is focused validation, not a replacement for the complete default build,
hermetic run, or strict local Robinhood deployment and lifecycle rehearsal.
"""
from pathlib import Path
import argparse, json, re, subprocess, time
from build_provenance import capture

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
assert (art / 'prepared-release-followups-applied.json').exists(), 'Apply the checked drafts first.'
record_path = art / ('provider-position-' + args.label + '-sequence.json')
assert not record_path.exists(), 'Preserve previous execution evidence; choose another label.'
steps = [(provider, ['run-camelot-provider-checks.py', '--provider', provider, '--label', args.label])
         for provider in ['uniswap-v2', 'camelot', 'aerodrome', 'erc4626']]
steps += [('positions', ['run-position-cleanup-checks.py', '--label', args.label]),
          ('rocket-v3', ['run-etherfi-live-projection-fork.py', '--provider', 'rocket', '--label', args.label]),
          ('rocket-v4', ['run-etherfi-live-projection-fork.py', '--provider', 'rocket',
                         '--rocket-block', '25934585', '--label', args.label]),
          ('sfrxeth', ['run-etherfi-live-projection-fork.py', '--provider', 'sfrxeth', '--label', args.label])]
record = {'status': 'RUNNING', 'provenance': capture(root), 'steps': [],
          'remaining_after_success': 'Matching complete default build/hermetic run and baseline attribution; strict current-package local Robinhood rehearsal; final acceptance reconciliation.'}
record_path.write_text(json.dumps(record, indent=2) + '\n')
for name, arguments in steps:
    command = ['python3', str(art / arguments[0])] + arguments[1:]
    print('Starting', name, flush=True)
    started = time.monotonic()
    result = subprocess.run(command, cwd=root)
    unchanged = capture(root)['source_and_config_sha256'] == record['provenance']['source_and_config_sha256']
    record['steps'].append({'name': name, 'command': command, 'exit_code': result.returncode,
                            'seconds': round(time.monotonic() - started, 3), 'sources_unchanged': unchanged})
    if result.returncode or not unchanged:
        record['status'] = 'STOPPED_REQUIRED_FIX_OR_SOURCE_RECONCILIATION'
        record_path.write_text(json.dumps(record, indent=2) + '\n')
        raise SystemExit(result.returncode or 1)
    record_path.write_text(json.dumps(record, indent=2) + '\n')
record['status'] = 'FOCUSED_CHECKS_PASSED_COMPLETE_RELEASE_VALIDATION_STILL_REQUIRED'
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(record['status'], flush=True)
