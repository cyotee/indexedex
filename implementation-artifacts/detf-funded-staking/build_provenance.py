"""Record reproducible source/config/tool provenance without reading secret environment values."""
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import platform
import re
import subprocess


def capture(checkout: Path) -> dict:
    paths = subprocess.check_output(
        ['git', 'ls-files', '-co', '--exclude-standard', '--', 'contracts', 'test', 'scripts'],
        cwd=checkout, text=True,
    ).splitlines()
    source_paths = {p for p in paths if p.endswith('.sol')}
    source_paths.update(['foundry.toml', 'remappings.txt'])
    digest = hashlib.sha256()
    count = 0
    for relative in sorted(source_paths):
        source = checkout / relative
        if not source.is_file():
            continue
        digest.update(relative.encode() + b'\0' + hashlib.sha256(source.read_bytes()).digest())
        count += 1
    dependency = checkout / 'lib/crane'
    dependency_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=dependency, text=True).strip()
    dependency_diff = subprocess.check_output(
        ['git', '-c', 'diff.ignoreSubmodules=all', 'diff', '--no-ext-diff', '--binary', '--ignore-submodules=all', 'HEAD', '--', 'contracts', 'foundry.toml'],
        cwd=dependency,
    )
    dependency_digest = hashlib.sha256()
    dependency_paths = set(dependency.rglob('*.sol'))
    dependency_paths.update(path for path in (dependency / 'foundry.toml', dependency / 'remappings.txt') if path.is_file())
    dependency_count = 0
    for path in sorted(dependency_paths):
        if not path.is_file() or any(part in ('out', 'cache_forge', 'node_modules', '.git') for part in path.relative_to(dependency).parts):
            continue
        relative = str(path.relative_to(dependency))
        dependency_digest.update(relative.encode() + b'\0' + hashlib.sha256(path.read_bytes()).digest())
        dependency_count += 1
    return {
        'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
        'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=checkout, text=True).strip(),
        'source_and_config_sha256': digest.hexdigest(),
        'source_and_config_files': count,
        'source_scope': 'All tracked and untracked local Solidity under contracts/test/scripts plus Foundry config; source fingerprint is not a claim that all files were compiled by a focused run.',
        'crane_head': dependency_head,
        'crane_tracked_contract_and_config_diff_sha256': hashlib.sha256(dependency_diff).hexdigest(),
        'crane_source_and_config_sha256': dependency_digest.hexdigest(),
        'crane_source_and_config_files': dependency_count,
        'dependency_scope': 'Crane Solidity tree, including untracked Solidity and nested vendored libraries/tests, plus Crane Foundry config. Final compiler metadata separately verifies every imported source closure.',
        'forge_version': subprocess.check_output(['forge', '--version'], cwd=checkout, text=True).strip(),
        'machine': platform.platform(),
        'architecture': platform.machine(),
        'logical_cpus': os.cpu_count(),
        'cache': 'Existing seeded out/cache_forge; no clean. Independent baseline is archived; current validation uses one Forge process at a time.',
    }


def hermetic_environment(checkout: Path):
    """Use the default project and prevent dotenv from restoring RPC secrets."""
    environment = os.environ.copy()
    environment['FOUNDRY_PROFILE'] = 'default'
    for key in ('FOUNDRY_TEST', 'FOUNDRY_SCRIPT', 'DETF_MATCH_TEST', 'DETF_MATCH_CONTRACT'):
        environment.pop(key, None)
    config = (checkout / 'foundry.toml').read_text()
    section = re.search(r'\[rpc_endpoints\]([\s\S]*?)(?=\n\[|\Z)', config)
    keys = set(re.findall(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}', section[1] if section else ''))
    keys.update(key for key in environment if key.endswith(('RPC_URL', 'RPC_KEY', 'ALCHEMY_KEY', 'INFURA_KEY')))
    keys.update(('ALCHEMY_KEY', 'INFURA_KEY'))
    # These configure Forge's test fork itself. An empty value is still a
    # configured URL and is interpreted as the current directory's IPC path.
    # The repository has no .env/.env.local restoring either direct setting.
    for key in ('ETH_RPC_URL', 'FOUNDRY_ETH_RPC_URL', 'FOUNDRY_FORK_URL', 'DAPP_TEST_RPC_URL'):
        environment.pop(key, None)
        keys.discard(key)
    for key in keys:
        environment[key] = ''
    return environment, sorted(keys)


def readiness_provenance_matches(checkout: Path, current: dict, recorded: dict) -> bool:
    """Accept exact provenance, or the explicitly verified launch-only PR-08 delta.

    Original execution records remain unchanged. A changed contract, test,
    dependency, tool or other script cannot use this narrow evidence bridge.
    """
    keys = ('source_and_config_sha256', 'crane_head',
            'crane_tracked_contract_and_config_diff_sha256',
            'crane_source_and_config_sha256', 'forge_version')
    if all(current.get(key) == recorded.get(key) for key in keys):
        return True
    # A missing named import in the local-only lifecycle harness does not alter
    # any production, hermetic, provider-fork, or deployment source closure.
    # Its own failed compilation is never reusable as successful evidence.
    import json
    harness_path = checkout / 'implementation-artifacts/detf-funded-staking/production-readiness/rehearsal-import-evidence-reuse.json'
    if harness_path.is_file():
        harness = json.loads(harness_path.read_text())
        expected_harness = 'test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol'
        changes = harness.get('changed_sources', [])
        if (harness.get('status') == 'PASS_UNCHANGED_NON_REHEARSAL_SOURCE_CLOSURES'
                and all(current.get(k) == harness['provenance'].get(k) for k in keys)
                and harness['prior_provenance']['source_and_config_sha256'] != current['source_and_config_sha256']
                and len(changes) == 1 and changes[0]['path'] == expected_harness
                and hashlib.sha256((checkout / expected_harness).read_bytes()).hexdigest() == changes[0]['current_sha256']
                and harness.get('reverse_import_closure') == [expected_harness]
                and all(harness.get(k) == 0 for k in ('production_contract_changes', 'hermetic_test_changes', 'script_changes', 'dependency_changes', 'compiler_configuration_changes'))):
            return readiness_provenance_matches(checkout, harness['prior_provenance'], recorded)
    path = checkout / 'implementation-artifacts/detf-funded-staking/production-readiness/pr08-script-only-evidence-reuse.json'
    if not path.is_file():
        return False
    import json
    bridge = json.loads(path.read_text())
    if bridge.get('status') != 'PASS_UNCHANGED_EXECUTION_SOURCE_CLOSURES':
        return False
    if not all(current.get(key) == bridge['provenance'].get(key)
               and recorded.get(key) == bridge['prior_provenance'].get(key) for key in keys):
        return False
    expected = 'scripts/foundry/anvil_robinhood_main/Phase_06_Stage_09_BalancerStableBufferHookPkg.sol'
    changed = bridge.get('changed_sources', [])
    if len(changed) != 1 or changed[0]['path'] != expected:
        return False
    if hashlib.sha256((checkout / expected).read_bytes()).hexdigest() != changed[0]['current_sha256']:
        return False
    if any(bridge.get(key) != 0 for key in ('production_contract_changes', 'test_changes',
                                           'dependency_changes', 'compiler_configuration_changes')):
        return False
    return set(bridge.get('reverse_import_closure', [])) == {
        expected,
        'scripts/foundry/anvil_robinhood_main/Phase_06_Stage_09_BalancerStableBufferHookPkg.s.sol',
        'scripts/foundry/anvil_robinhood_main/Script_SimulateArchitecture.s.sol',
    }


def unchanged_fork_evidence_matches(checkout: Path, current: dict, evidence_path: Path) -> bool:
    """Reuse only the explicitly reviewed provider/V3 records, never a full run.

    PR-09/10 change DETF/Orbital production code, so the global provenance
    exception above must not accept their predecessor. These SE fork records
    have a separate, archived compiler-source closure and source-delta review.
    """
    import json
    allowed = {
        'implementation-artifacts/detf-funded-staking/production-readiness/provider-renewal-core-final/run.json',
        'implementation-artifacts/detf-funded-staking/v3-retained-live-pool-production-readiness-run.json',
    }
    try:
        relative = str(evidence_path.resolve().relative_to(checkout.resolve()))
        if relative not in allowed:
            return False
        proof_path = checkout / 'implementation-artifacts/detf-funded-staking/production-readiness/lifecycle-fork-evidence-reuse.json'
        proof = json.loads(proof_path.read_text())
        if proof.get('status') != 'PASS_UNCHANGED_PROVIDER_AND_V3_FORK_DEPENDENCIES':
            return False
        keys = ('source_and_config_sha256', 'crane_head',
                'crane_tracked_contract_and_config_diff_sha256',
                'crane_source_and_config_sha256', 'forge_version')
        if not all(current.get(k) == proof['provenance'].get(k) for k in keys):
            return False
        row = next(r for r in proof['evidence'] if r['path'] == relative)
        if hashlib.sha256(evidence_path.read_bytes()).hexdigest() != row['sha256']:
            return False
        if len(proof['fork_suites']) != 6 or not proof['source_closure']:
            return False
        for suite in proof['fork_suites']:
            if hashlib.sha256((checkout / suite['metadata_path']).read_bytes()).hexdigest() != suite['metadata_sha256']:
                return False
        return all(hashlib.sha256((checkout / path).read_bytes()).hexdigest() == entry['sha256']
                   for path, entry in proof['source_closure'].items())
    except (OSError, KeyError, ValueError, StopIteration):
        return False
