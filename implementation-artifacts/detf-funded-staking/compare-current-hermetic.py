"""Attribute a completed default run to exact baseline identities and release scope.

Matching an old failure is evidence of an existing failure, not permission to
leave an in-scope requirement failing. Consolidated/renamed tests are explicitly
unmatched unless a separate coverage migration record accounts for them.
"""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

artifacts = Path(__file__).resolve().parent
completion_path = artifacts / 'implementation-hermetic-test.json'
deferral_path = artifacts / 'hermetic-pre-provider-deferral.json'
current_build = json.loads((artifacts / 'implementation-full-build.json').read_text())
build_source = current_build['provenance']['source_and_config_sha256']
if deferral_path.exists():
    deferral = json.loads(deferral_path.read_text())
    if deferral.get('active') and build_source == deferral.get('source_and_config_sha256'):
        print('No post-provider full hermetic result to compare; deferred execution is not validation.', flush=True)
        raise SystemExit(75)
completion = json.loads(completion_path.read_text())
assert 'exit_code' in completion, 'Current full suite has not completed'
assert current_build['exit_code'] == 0, 'Full build must have succeeded.'
assert completion['provenance']['source_and_config_sha256'] == build_source, 'Test result does not match the latest full build.'
baseline = json.loads((artifacts / 'baseline-hermetic-failure-index.json').read_text())
assert baseline['status'] == 'completed'

def reported_test(line):
    match = re.search(r'\] ((?:test|invariant|setUp|afterInvariant)\S+)\s', line)
    return match[1] if match else None

# The preserved historical parser used null for setup/invariant identities.
# Recover their actual names from its unchanged evidence lines so two distinct
# invariants cannot be conflated when attributing a current failure.
baseline_failures = []
for original in baseline['failures']:
    row = dict(original)
    row['test'] = reported_test(row['reported_failure'])
    baseline_failures.append(row)
log = artifacts / 'implementation-hermetic-test.log'
log_digest = hashlib.sha256()
current = None
failures = []
passed = []
suites = 0
footer = False
# Large default-suite logs need neither a complete byte copy nor a second
# decoded copy in memory. Hash all bytes, but never recount the failure footer.
with log.open('rb') as stream:
    for raw_line in stream:
        log_digest.update(raw_line)
        if footer:
            continue
        line = raw_line.decode(errors='replace').rstrip('\r\n')
        if line.startswith('Failing tests:'):
            footer = True
            continue
        header = re.match(r'Ran \d+ tests? for (.*\.sol):(.+)', line)
        if header:
            current = {'source': header[1], 'contract': header[2]}
        if current and line.startswith(('[PASS]', '[FAIL')):
            row = {**current, 'test': reported_test(line), 'reported_result': line}
            (passed if line.startswith('[PASS]') else failures).append(row)
        elif line.startswith('Suite result:'):
            suites += 1
            current = None

def identity(row):
    # Unknown result formats only match the exact complete evidence line.
    test = row['test'] or row.get('reported_failure', row.get('reported_result'))
    return row['source'], row['contract'], test

def scope(source):
    if 'slipstream' in source.lower():
        return 'D66_DEFERRED_PRESERVE_EXISTING'
    if '/vaults/detf/protocols/dexes/balancer/' in source:
        return 'D60_BALANCER_DETF_EXCLUDED'
    if '/vaults/detf/common/claimToken/' in source and Path(source).name in {
        'SingleSEFundedStaking.t.sol', 'MixedBufferFundedStaking.t.sol',
        'MixedBufferFundedDecimalBooks.t.sol', 'MultiWeightedFundedStaking.t.sol',
        'ComposedStableFundedStaking.t.sol',
    }:
        return 'D60_BALANCER_DETF_EXCLUDED'
    if '/vaults/detf/' in source:
        return 'IN_SCOPE_DETF'
    return 'SHARED_OR_UNRELATED_REQUIRES_ATTRIBUTION'

old = {identity(row): row for row in baseline_failures}
now = {identity(row): row for row in failures}
green = {identity(row): row for row in passed}
for row in failures:
    previous = old.get(identity(row))
    row['scope'] = scope(row['source'])
    row['baseline_identity_already_failed'] = previous is not None
    if previous:
        row['baseline_failure'] = previous['reported_failure']

resolved = [dict(source=k[0], contract=k[1], test=k[2]) for k in old if k in green]
unmatched = [dict(source=k[0], contract=k[1], test=k[2]) for k in old if k not in now and k not in green]
report = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
    'status': 'completed current default run; attribution is not a completion waiver',
    'completion': completion,
    'log_sha256': log_digest.hexdigest(),
    'suites': suites,
    'passed': len(passed),
    'failed': len(failures),
    'failure_scope_counts': dict(Counter(row['scope'] for row in failures)),
    'previously_failing_exact_identities': sum(row['baseline_identity_already_failed'] for row in failures),
    'historical_null_identities_normalized': sum(original['test'] is None and normalized['test'] is not None
        for original, normalized in zip(baseline['failures'], baseline_failures)),
    'unparsed_current_result_identities': [row for row in failures + passed if row['test'] is None],
    'baseline_failures_now_pass': resolved,
    'baseline_failures_unmatched': unmatched,
    'failures': failures,
    'notes': [
        'Baseline excludes five documented misplaced network sources; the current run moves/deduplicates those sources into the fork tree and has no test filters.',
        'Gas/reason text can change without changing test identity. Both lines are retained for comparison.',
        'Historical null setup/invariant names are recovered from the unchanged baseline result lines; the preserved baseline index is not rewritten.',
        'Unmatched baseline failures may have been consolidated, renamed, or retired; they are not counted as fixed.',
        'All in-scope failures still require resolution, including failures that also occurred in the baseline.',
    ],
}
(artifacts / 'current-hermetic-baseline-attribution.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({key: report[key] for key in ['status', 'suites', 'passed', 'failed', 'failure_scope_counts', 'previously_failing_exact_identities']}, indent=2))

# Resolve the maintained review anchors against this completed run, including
# inherited tests whose concrete suite lives in a different source file. This
# supplements the acceptance matrix; passing anchors do not prove every clause.
anchors = json.loads((artifacts / 'acceptance-test-anchors.json').read_text())
anchor_rows = []
for criterion in anchors['rows']:
    names = sorted({test['function'] for test in criterion['tests']} | set(criterion['prepared_tests']))
    tests = []
    for name in names:
        successes = [row for row in passed if row['test'] and row['test'].split('(', 1)[0] == name]
        errors = [row for row in failures if row['test'] and row['test'].split('(', 1)[0] == name]
        tests.append({'function': name, 'passed_instances': len(successes), 'failed_instances': len(errors),
                      'executions': [{key: row[key] for key in ['source', 'contract', 'test', 'reported_result']}
                                     for row in successes + errors]})
    missing = [test['function'] for test in tests if not test['executions']]
    anchor_rows.append({'criterion': criterion['criterion'], 'missing_named_tests': missing,
                        'named_test_failures': sum(test['failed_instances'] for test in tests), 'tests': tests})
anchor_report = {
    'status': 'Completed-run named-test evidence only; no acceptance criterion automatically closed.',
    'provenance': completion['provenance'], 'log_sha256': report['log_sha256'],
    'rows': anchor_rows, 'separate_evidence': anchors['separate_evidence'],
    'limitations': ['Named anchors are review entry points, not exhaustive subclause or family coverage.',
                    'Setup failures can prevent named methods from executing; missing methods are never counted as passing.',
                    'Deployment rehearsal, provider integration, complete source/storage manifests and scope attribution remain separate gates.'],
}
(artifacts / 'acceptance-current-run-anchors.json').write_text(json.dumps(anchor_report, indent=2) + '\n')
print(json.dumps({'acceptance_anchor_criteria': len(anchor_rows),
                  'criteria_with_missing_named_tests': [row['criterion'] for row in anchor_rows if row['missing_named_tests']],
                  'criteria_with_named_test_failures': [row['criterion'] for row in anchor_rows if row['named_test_failures']]}, indent=2))
