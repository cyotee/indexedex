"""Renew reviewed payload/storage/catalog records only after actual validation.

This does not award plan or acceptance checkboxes. It rejects source changes to
reviewed layouts/payloads and requires fresh production/runtime evidence.
"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import sys

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture, unchanged_fork_evidence_matches

provenance = capture(root)
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
runtime = 'current-robinhood-rehearsal-production-readiness-lifecycle-fixed/'
now = datetime.now(timezone.utc).isoformat()

def read(relative, current=False):
    data = json.loads((art / relative).read_text())
    if current:
        assert all(data['provenance'][key] == provenance[key] for key in keys), relative
    return data

def sha(relative):
    return hashlib.sha256((root / relative).read_bytes()).hexdigest()

build = read('implementation-full-build.json', True)
hermetic = read('implementation-hermetic-test.json', True)
regressions = read('production-readiness/corrected-candidate-regressions.json', True)
new_regressions = read('production-readiness/lifecycle-production-regressions.json', True)
life = read(runtime + 'lifecycle-run.json', True)
receipts = read(runtime + 'receipt-manifest.json', True)
funding = read('current-robinhood-rehearsal-production-readiness-funding/funding-quote.json', True)
core = read('production-readiness/corrected-local-core-and-packages.json', True)
inputs = read('production-readiness/create3-deployment-inputs.json', True)
artifacts = read('production-readiness/release-artifact-manifest.json', True)
anchors = read('acceptance-current-run-anchors.json', True)
assert build['exit_code'] == 0 and hermetic['validation_passed'] and hermetic['executed_cases'] > 0
assert regressions['validation_passed'] and regressions['passed'] == 27
assert new_regressions['validation_passed'] and new_regressions['passed'] == 7
assert life['status'] == 'PASS_ALL_39_STRICT_LIFECYCLE_CASES' and life['passed'] == 39
assert life['failed'] == life['skipped'] == 0
assert receipts['status'] == 'PASS_LOCAL_RECEIPTS_AND_STRICT_BLOCK_LIMITS'
assert receipts['all_19_catalog_stages_have_receipts'] and len(receipts['required_catalog_stages']) == 19
assert funding['status'] == 'PASS_COMPLETE_ISOLATED_EIP1559_FUNDING_QUOTE'
assert core['current_release_checks_passed'] and core['sources_unchanged']
assert core['rpc_alias_or_loopback'] == 'http://127.0.0.1:18665'
assert inputs['status'] == 'PASS_ALL_135_CREATE3_DEPLOYMENT_INPUTS'
assert artifacts['all_artifacts_current_linked_and_eip170_compliant']
assert len(anchors['rows']) == 40 and all(not row['missing_named_tests'] and not row['named_test_failures']
    and row['tests'] and all(test['passed_instances'] > 0 for test in row['tests']) for row in anchors['rows'])
for relative in ('production-readiness/provider-renewal-core-final/run.json',
                 'v3-retained-live-pool-production-readiness-run.json'):
    assert unchanged_fork_evidence_matches(root, provenance, art / relative), relative

storage = read('production-readiness/storage-review.json')
assert sum(len(row['fields']) for row in storage['rows']) == 64
assert all(sha(row['source']) == row['sha256'] for row in storage['rows'])
storage.update(reviewed_at_utc=now, provenance=provenance,
    status='PASS_ALL_64_FIELD_DISPOSITIONS_AND_CURRENT_RUNTIME_COVERAGE',
    renewal='All reviewed layout source hashes unchanged. PR-09/10 add no state or initializer writes; current full tests, named anchors and strict lifecycle renew runtime coverage.')
storage['evidence'] = sorted(set(storage['evidence'] + [runtime + 'lifecycle-run.json',
    'production-readiness/lifecycle-production-regressions.json']))

packages = read('production-readiness/package-source-manifest.json')
components = {row['contract']: row for row in artifacts['components']}
deployed = {row['contract']: row for row in core['registered_packages']}
assert len(packages['packages']) == 30
for row in packages['packages']:
    assert sha(row['source']) == row['source_sha256'], row['package']
    assert all(sha(factory['path']) == factory['sha256'] for factory in row['factory_sources'])
    component = components[row['package']]
    assert sha(component['artifact']) == component['artifact_sha256']
    compiled = json.loads((root / component['artifact']).read_text())
    assert row['constructor_abi'] == [entry for entry in compiled['abi'] if entry['type'] == 'constructor']
    for entry in row['deployment_functions_abi']:
        assert entry in compiled['abi'], (row['package'], entry.get('name'))
    row['artifact_sha256'] = component['artifact_sha256']
    row['current_runtime_evidence'] = ['implementation-hermetic-test.json', 'current-se-package-inventory.json',
        'production-readiness/release-artifact-manifest.json', 'production-readiness/lifecycle-fork-evidence-reuse.json']
    row['local_package'] = None
    row['local_constructor_and_salt_evidence'] = []
    if row['package'] in deployed:
        live = deployed[row['package']]
        assert live['status'] == 'MATCH' and not live['stale_compiled_sources']
        row['local_package'] = {key: live[key] for key in ('address', 'code_keccak256', 'runtime_bytes', 'registered_in', 'interfaces')}
        row['local_package']['cuts_evidence'] = 'production-readiness/corrected-local-core-and-packages.json'
        row['local_constructor_and_salt_evidence'] = [
            {key: entry[key] for key in ('transaction_hash', 'salt', 'address')}
            for entry in inputs['rows'] if entry['address'].lower() == live['address'].lower()]
        assert row['local_constructor_and_salt_evidence'], row['package']
packages.update(generated_at_utc=now, provenance=provenance, pending=[],
    status='PASS_ALL_30_RETAINED_PACKAGE_PAYLOADS_AND_RUNTIME_RECONCILED')

catalog = read('production-readiness/maintained-release-catalog.json')
assert sha(catalog['catalog']) == catalog['catalog_sha256']
assert all(sha(path) == digest for stage in catalog['stages'] for path, digest in stage['source_sha256'].items())
catalog.update(recorded_at_utc=now, provenance=provenance,
    runtime_status='PASS_ALL_19_LOCAL_ONCHAIN_STAGES_AND_ISOLATED_EXPORT',
    local_receipts=runtime + 'receipt-manifest.json',
    local_runtime='production-readiness/corrected-local-core-and-packages.json',
    local_creation_inputs='production-readiness/create3-deployment-inputs.json')

# Archive before replacing review records; never convert an old run into a pass.
archive = here / 'before-final-review-renewal'
assert not archive.exists(), 'Review previous renewal before running again.'
archive.mkdir()
for name, data in (('storage-review.json', storage), ('package-source-manifest.json', packages),
                   ('maintained-release-catalog.json', catalog)):
    shutil.copy2(here / name, archive / name)
    (here / name).write_text(json.dumps(data, indent=2) + '\n')
print('PASS: unchanged reviewed layouts/payloads renewed against current complete tests and actual local release. Acceptance remains separate.')
