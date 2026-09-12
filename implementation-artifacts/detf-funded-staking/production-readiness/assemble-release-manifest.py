"""Assemble immutable evidence references; missing or stale evidence keeps the release on hold.

This performs no builds, deployments, acceptance edits or public actions. Human
acceptance reconciliation remains separate from collecting machine-run evidence.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture, readiness_provenance_matches, unchanged_fork_evidence_matches

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, help='Fresh JSON filename within production-readiness')
parser.add_argument('--require-ready', action='store_true')
args = parser.parse_args()
assert Path(args.output).name == args.output and args.output.endswith('.json')
output = here / args.output
assert not output.exists(), 'Preserve previous manifest; choose a fresh filename.'
provenance = capture(root)
fingerprints = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
                'crane_source_and_config_sha256', 'forge_version')
records = {}
gates = []

def collect(label, relative, accepted=None, current=False, retained_fork=False):
    path = art / relative
    entry = {'path': str(path.relative_to(root)), 'present': path.is_file()}
    records[label] = entry
    if not path.is_file():
        gates.append({'id': label, 'passed': False, 'reason': 'Required evidence has not been produced.'})
        return None
    raw = path.read_bytes()
    entry['sha256'] = hashlib.sha256(raw).hexdigest()
    data = json.loads(raw)
    entry['recorded_status'] = data.get('status')
    mismatches = [key for key in fingerprints if data.get('provenance', {}).get(key) != provenance[key]] if current else []
    accepted_result = bool(accepted(data)) if accepted is not None else True
    if current and mismatches and readiness_provenance_matches(root, provenance, data.get('provenance', {})):
        entry['executed_provenance'] = data['provenance']
        entry['reused_unchanged_execution_source_closures'] = [
            'production-readiness/pr08-script-only-evidence-reuse.json',
            'production-readiness/rehearsal-import-evidence-reuse.json',
        ]
        entry['original_fingerprint_differences'] = mismatches
        mismatches = []
    if current and mismatches and retained_fork and unchanged_fork_evidence_matches(root, provenance, path):
        entry['executed_provenance'] = data['provenance']
        entry['reused_unchanged_execution_source_closures'] = [
            'production-readiness/lifecycle-fork-evidence-reuse.json',
        ]
        entry['original_fingerprint_differences'] = mismatches
        mismatches = []
    gates.append({'id': label, 'passed': accepted_result and not mismatches,
                  'evidence_accepted': accepted_result, 'changed_fingerprints': mismatches})
    return data

def source_inventory_matches(data):
    rows = data['solidity_and_config'] + data['callers_and_orchestration']
    mismatches = []
    for row in rows:
        path = root / row['path']
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
            mismatches.append(row['path'])
    records['sources']['changed_inventory_files'] = mismatches
    return bool(rows) and not mismatches

collect('script_only_evidence_reuse', 'production-readiness/pr08-script-only-evidence-reuse.json',
        lambda d: d['status'] == 'PASS_UNCHANGED_EXECUTION_SOURCE_CLOSURES')
collect('rehearsal_import_evidence_reuse', 'production-readiness/rehearsal-import-evidence-reuse.json',
        lambda d: d['status'] == 'PASS_UNCHANGED_NON_REHEARSAL_SOURCE_CLOSURES')
collect('lifecycle_fork_evidence_reuse', 'production-readiness/lifecycle-fork-evidence-reuse.json',
        lambda d: d['status'] == 'PASS_UNCHANGED_PROVIDER_AND_V3_FORK_DEPENDENCIES'
        and all(unchanged_fork_evidence_matches(root, provenance, root / row['path'])
                for row in d['evidence']), current=True)
collect('owner_baseline', 'production-readiness/owner-passing-baseline.json',
        lambda d: d['status'] == 'OWNER_REPORTED_ALL_TESTS_PASS')
collect('sources', 'production-readiness/release-source-manifest.json', source_inventory_matches, current=True)
collect('dependencies', 'production-readiness/dependency-revisions.json')
collect('dependency_renewal', 'production-readiness/dependency-revisions-renewal.json',
        lambda d: d['status'] == 'PASS_ALL_54_DEPENDENCY_REVISIONS_UNCHANGED'
        and d['dependencies_checked'] == 54 and not d['uninitialized']
        and d['prior_evidence_sha256'] == hashlib.sha256((here / 'dependency-revisions.json').read_bytes()).hexdigest())
sequence_record = json.loads((art / 'current-implementation-queue.json').read_text())['active_sequence_record']
assert Path(sequence_record).name == sequence_record and sequence_record.startswith('current-repository-')
collect('full_sequence', sequence_record,
        lambda d: d['status'] == 'REPOSITORY_CHECKS_PASSED_REHEARSAL_AND_ACCEPTANCE_REMAIN', current=True)
collect('production_and_script_build', 'implementation-full-build.json', lambda d: d['exit_code'] == 0, current=True)
collect('maintained_scripts', 'maintained-script-build-scope.json')
hermetic = collect('hermetic', 'implementation-hermetic-test.json',
                   lambda d: d['validation_passed'] and d['executed_cases'] > 0, current=True)
collect('named_acceptance_tests', 'acceptance-current-run-anchors.json',
        lambda d: {row['criterion'] for row in d['rows']} == {f'A{i}' for i in range(1, 43) if i not in (33, 42)}
        and all(not row['missing_named_tests'] and row['named_test_failures'] == 0
                and row['tests'] and all(test['passed_instances'] > 0 for test in row['tests'])
                for row in d['rows']), current=True)
collect('regressions', 'production-readiness/corrected-candidate-regressions.json',
        lambda d: d['validation_passed'] and d['passed'] == 27 and d['failed'] == d['skipped'] == 0, current=True)
collect('lifecycle_production_regressions', 'production-readiness/lifecycle-production-regressions.json',
        lambda d: d['validation_passed'] and d['passed'] == 7 and d['failed'] == d['skipped'] == 0
        and d['executed_suites'] == {
            'UniswapV4Detf_Cp_Univ3Se_ResidualGas': 3,
            'UniswapV4StandardExchangeOrbitalBufferHook_LiquidityTest': 4,
        }, current=True)
collect('lifecycle_test_additions', 'production-readiness/lifecycle-test-additions.json',
        lambda d: d['status'] == 'PASS_SEVEN_ADDITIONS_NO_REMOVED_TESTS_39_LIFECYCLE_DECLARATIONS_PRESERVED'
        and sum(len(row['added_tests']) for row in d['rows']) == 7
        and all(not row['removed_tests'] and hashlib.sha256((root / row['source']).read_bytes()).hexdigest()
                == row['source_sha256'] for row in d['rows']))
collect('artifacts', 'production-readiness/release-artifact-manifest.json',
        lambda d: d['all_artifacts_current_linked_and_eip170_compliant']
        and all(hashlib.sha256((root / row['artifact']).read_bytes()).hexdigest() == row['artifact_sha256']
                for row in d['components'])
        and hashlib.sha256((root / d['maintained_architecture_artifact']).read_bytes()).hexdigest()
            == d['maintained_architecture_artifact_sha256'], current=True)
collect('v3_forks', 'v3-retained-live-pool-production-readiness-run.json',
        lambda d: d['status'] == 'PASS_ALL_EIGHT_RETAINED_CASES' and d['sources_unchanged'], current=True, retained_fork=True)
collect('provider_forks', 'production-readiness/provider-renewal-core-final/run.json',
        lambda d: d['status'] == 'PASS_ALL_27_PROVIDER_CASES', current=True, retained_fork=True)
runtime = 'current-robinhood-rehearsal-production-readiness-lifecycle-fixed/'
architecture = collect('architecture', runtime + 'architecture-run.json',
        lambda d: d['status'] == 'PASS_REQUIRES_RECEIPT_AND_CODE_RECONCILIATION' and d['core_prediction_matches'], current=True)
collect('receipts', runtime + 'receipt-manifest.json',
        lambda d: d['status'] == 'PASS_LOCAL_RECEIPTS_AND_STRICT_BLOCK_LIMITS'
        and d.get('all_19_catalog_stages_have_receipts') is True
        and len(d.get('required_catalog_stages', [])) == 19, current=True)
collect('lifecycle', runtime + 'lifecycle-run.json',
        lambda d: d['status'] == 'PASS_ALL_39_STRICT_LIFECYCLE_CASES', current=True)
collect('funding', 'current-robinhood-rehearsal-production-readiness-funding/funding-quote.json',
        lambda d: d['status'] == 'PASS_COMPLETE_ISOLATED_EIP1559_FUNDING_QUOTE', current=True)
collect('funding_quote_helpers', 'production-readiness/funding-quote-checks.json',
        lambda d: d['status'] == 'PASS' and len(d['cases']) == 8
        and len(d['catalog_phases_02_through_06_in_exact_order']) == 19
        and all(hashlib.sha256((root / path).read_bytes()).hexdigest() == digest
                for path, digest in d['source_sha256'].items()))
collect('staged_fee_helpers', 'production-readiness/staged-local-fee-checks.json',
        lambda d: d['status'] == 'PASS' and len(d['cases']) == 6 and all(row['passed'] for row in d['cases'])
        and d['source_sha256'] == hashlib.sha256((root / 'scripts/foundry/anvil_robinhood_main/deploy_all.sh').read_bytes()).hexdigest())
collect('core_and_packages', 'production-readiness/corrected-local-core-and-packages.json',
        lambda d: d.get('current_release_checks_passed') is True and d.get('sources_unchanged') is True, current=True)
collect('create3_inputs', 'production-readiness/create3-deployment-inputs.json',
        lambda d: d['status'] == 'PASS_ALL_135_CREATE3_DEPLOYMENT_INPUTS'
        and d['row_count'] == 135 and all(r['prediction_and_input_match'] for r in d['rows']), current=True)
collect('runtime_verifier', 'production-readiness/linked-runtime-verifier-checks.json',
        lambda d: d['status'] == 'PASS_EIGHT_RUNTIME_VERIFIER_CHECKS'
        and d['checker_sha256'] == hashlib.sha256((here / 'inspect-rehearsal-core.py').read_bytes()).hexdigest())
collect('package_cut_verifier', 'production-readiness/package-cut-verifier-checks.json',
        lambda d: d['status'] == 'PASS_NINE_PACKAGE_CUT_VERIFIER_CHECKS'
        and len(d['checks']) == 9 and all(row['passed'] for row in d['checks'])
        and d['checker_sha256'] == hashlib.sha256((here / 'inspect-rehearsal-core.py').read_bytes()).hexdigest())
collect('storage', 'production-readiness/storage-review.json',
        lambda d: d['status'] == 'PASS_ALL_64_FIELD_DISPOSITIONS_AND_CURRENT_RUNTIME_COVERAGE'
        and sum(len(row['fields']) for row in d['rows']) == 64
        and all(hashlib.sha256((root / row['source']).read_bytes()).hexdigest() == row['sha256']
                for row in d['rows']), current=True)
collect('selectors', 'current-funded-selector-manifest.json',
        lambda d: bool(d['rows']) and all(row['compiler_source_check']['matches_current_source']
        and (row['source_kind'] != 'deployable facet or package' or 0 < row['runtime_bytes'] <= 24576)
        for row in d['rows']))
collect('native_se_proxy_evidence', 'current-se-package-inventory.json',
        lambda d: d['issuer_count'] == 25 and not d.get('proxy_suites_missing_current_all_pass_result', ['missing'])
        and all(d.get('proxy_evidence_provenance', {}).get(key) == provenance[key] for key in fingerprints)
        and sum(row.get('current_proxy_runtime_passed') is True for row in d['rows']) == 25)
collect('callers', 'production-readiness/frontend-abi-reconciliation.json', lambda d: d['all_compatible'])
collect('frontend', 'production-readiness/frontend-check.json', lambda d: d['exit_code'] == 0)
collect('frontend_live_scope', 'production-readiness/frontend-live-check-scope.json',
        lambda d: d['status'] == 'CONDITIONAL_UI_BINDING_GATE_NOT_TRIGGERED')
collect('renderer', 'production-readiness/renderer-evidence-reuse.json',
        lambda d: d['status'] == 'PASS_REUSED_IDENTICAL_VISUAL_EVIDENCE', current=True)
collect('security', 'production-readiness/security-findings.json',
        lambda d: bool(d['findings']) and all(row['status'] == 'RESOLVED' for row in d['findings']))
collect('acceptance', 'acceptance-progress.json', lambda d: d['complete'] is True and len(d['rows']) == 42)
collect('packages_and_encodings', 'production-readiness/package-source-manifest.json',
        lambda d: d['status'] == 'PASS_ALL_30_RETAINED_PACKAGE_PAYLOADS_AND_RUNTIME_RECONCILED'
        and len(d['packages']) == 30 and not d['pending']
        and all(hashlib.sha256((root / row['source']).read_bytes()).hexdigest() == row['source_sha256']
                and hashlib.sha256((root / row['artifact']).read_bytes()).hexdigest() == row['artifact_sha256']
                and all(hashlib.sha256((root / factory['path']).read_bytes()).hexdigest() == factory['sha256']
                        for factory in row['factory_sources']) for row in d['packages']), current=True)
collect('deployment_order', 'production-readiness/maintained-release-catalog.json',
        lambda d: d['runtime_status'] == 'PASS_ALL_19_LOCAL_ONCHAIN_STAGES_AND_ISOLATED_EXPORT'
        and all(hashlib.sha256((root / path).read_bytes()).hexdigest() == digest
                for stage in d['stages'] for path, digest in stage['source_sha256'].items()), current=True)
collect('export_token_units', 'production-readiness/native-export-token-preflight.json',
        lambda d: d['status'] == 'PASS_NATIVE_EXPORT_TOKEN_UNITS')
collect('workspace_preservation', 'production-readiness/workspace-preservation-check.json',
        lambda d: not d['missing'] and not d['unexpected_changes'])
ready = all(gate['passed'] for gate in gates)
accepted_gates = {gate['id']: gate['passed'] for gate in gates}
manifest = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'provenance': provenance,
    'status': 'PLAN_PRODUCTION_READINESS_CRITERIA_SATISFIED' if ready else 'HOLD_REQUIRED_EVIDENCE_OPEN',
    'production_readiness': ready, 'public_deployment_authorized': False, 'fund_migration_authorized': False,
    'scope': 'Unified V4 DETF CP/Weighted/Orbital/Curve Quad, funded staking/NFT/SY, retained SE packages. Robinhood architecture rehearsal; customer instance activation is a separate action.',
    'excluded': ['D60 Balancer-hosted DETF functional work', 'D66 unfinished Slipstream', 'Opt-in TokenStaking deployment', 'Public deployment and fund migration'],
    'core_reuse_prohibition': 'Pinned old CREATE3 core lacks canonical-registry authorization. Only the recorded corrected core is eligible; applying a source patch does not repair deployed bytecode.',
    'local_core_prediction': architecture.get('core_prediction') if architecture and accepted_gates['architecture'] else None,
    'full_hermetic_executed_cases': hermetic.get('executed_cases') if hermetic and accepted_gates['hermetic'] else None,
    'evidence': records, 'gates': gates,
    'open_gates': [gate['id'] for gate in gates if not gate['passed']],
    'runbook': str((here / 'PUBLIC_DEPLOYMENT_RUNBOOK.md').relative_to(root)),
    'limitations': 'Internal review is not an independent external audit. Overlapping focused/full test totals are not added. Point-in-time local receipts and funding quotes are not public deployment receipts or future fee guarantees.',
}
with output.open('x') as stream:
    json.dump(manifest, stream, indent=2)
    stream.write('\n')
print(json.dumps({'status': manifest['status'], 'open_gates': manifest['open_gates']}))
raise SystemExit(1 if args.require_ready and not ready else 0)
