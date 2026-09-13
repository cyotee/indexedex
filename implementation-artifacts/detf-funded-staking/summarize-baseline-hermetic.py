"""Index exact baseline failures without treating partial logs as a completed run."""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

baseline = Path('/private/tmp/indexedex-detf-funded-staking-20260906/implementation-artifacts/detf-funded-staking')
log = baseline / 'baseline-hermetic-retry-test.log'
completion = baseline / 'baseline-hermetic-retry-test.json'
data = log.read_bytes()
current = None
failures = []
passes = 0
suites = 0
for line in data.decode(errors='replace').splitlines():
    match = re.match(r'Ran \d+ tests? for (.*\.sol):(.+)', line)
    if match:
        current = {'source': match[1], 'contract': match[2]}
    if line.startswith('[PASS]'):
        passes += 1
    elif line.startswith('[FAIL') and current:
        test = re.search(r'\] (test\S+)\s', line)
        failures.append({**current, 'test': test[1] if test else None, 'reported_failure': line})
    elif line.startswith('Suite result:'):
        suites += 1
        current = None

result = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
    'status': 'completed' if completion.exists() else 'partial; process completion not recorded',
    'baseline_log': str(log),
    'log_snapshot_sha256': hashlib.sha256(data).hexdigest(),
    'log_snapshot_bytes': len(data),
    'completed_suite_lines': suites,
    'passing_test_lines': passes,
    'failing_test_lines': len(failures),
    'scope': 'Unchanged baseline, default profile, exactly five documented misplaced network-source exclusions. This is diagnostic and is not an unfiltered default-suite pass.',
    'failure_count_by_source': dict(Counter(row['source'] for row in failures).most_common()),
    'failures': failures,
}
output = Path(__file__).resolve().parent / 'baseline-hermetic-failure-index.json'
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: result[key] for key in ('status', 'completed_suite_lines', 'passing_test_lines', 'failing_test_lines')}, indent=2))
print('Most failing sources:', json.dumps(list(result['failure_count_by_source'].items())[:6]))
