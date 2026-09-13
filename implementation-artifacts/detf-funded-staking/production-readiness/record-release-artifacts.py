"""Inventory release package/deployment dependencies from the current compiler cache.

FactoryService creation-code references are followed because vm.getCode-loaded
components need independent source-closure checks. This does not infer deployed
proxy wiring from an ABI or award acceptance from an artifact inventory.
"""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import sys
from Crypto.Hash import keccak

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture

provenance = capture(root)
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
full_build = json.loads((art / 'implementation-full-build.json').read_text())
assert full_build['exit_code'] == 0
for key in keys:
    assert full_build['provenance'][key] == provenance[key], 'Build mismatch: ' + key
cache = json.loads((root / 'cache_forge/solidity-files-cache.json').read_text())
assert cache['paths']['sources'] == 'contracts' and cache['paths']['tests'] == 'test/foundry/spec'
index = {}
for source, entry in cache['files'].items():
    if not source.startswith(('contracts/', 'lib/crane/contracts/')):
        continue
    for name, versions in entry['artifacts'].items():
        for version, profiles in versions.items():
            if 'default' in profiles:
                path = root / cache['paths']['artifacts'] / profiles['default']['path']
                index.setdefault(name, {})[str(path)] = (source, version, path)

def kh(data):
    return '0x' + keccak.new(digest_bits=256, data=data).hexdigest()

def artifact(name):
    matches = index.get(name, {})
    assert len(matches) == 1, f'Expected one current artifact for {name}: {list(matches)}'
    source, version, path = next(iter(matches.values()))
    raw = path.read_bytes()
    return source, version, path, raw, json.loads(raw)

packages = json.loads((here / 'package-source-manifest.json').read_text())['packages']
pending = {row['package']: {'release-package'} for row in packages}
core = ('Create3Factory', 'Create3FactoryDFPkg', 'FacetRegistryFacet', 'DiamondFactoryPackageRegistryFacet',
        'DiamondPackageCallBackFactory', 'UniswapV4HookDiamondPackageCallBackFactory', 'UniswapV4HookFlagsFacet',
        'IndexedexManagerDFPkg', 'FeeCollectorDFPkg', 'FeeCollectorManagerFacet', 'MinimalDiamondCallBackProxy',
        'CallTargetRegistryDFPkg', 'BountyBoardDFPkg', 'StandardExchangeRateProviderDFPkg', 'StandardExchangeRateProviderFacet',
        'UniswapV4MultiPoolTwapOracleDFPkg', 'UniswapV4MultiPoolTwapOracleFacet', 'UniswapV4TwapAdapterFactory')
for name in core:
    pending.setdefault(name, set()).add('deployment-core')
# Validate the maintained catalog's source closure too. Do not infer live
# deployments by scanning every imported helper: some shared files contain
# unused legacy deployment helpers and illustrative creation-code comments.
# Standalone catalog dependencies are explicit above; the local registry and
# oracle inspection separately reconciles the deployed component inventory.
script_path = root / 'out/Script_SimulateArchitecture.s.sol/Script_SimulateArchitecture.json'
script = json.loads(script_path.read_text())
script_metadata = script.get('metadata') or json.loads(script['rawMetadata'])
if isinstance(script_metadata, str):
    script_metadata = json.loads(script_metadata)
for dependency, entry in script_metadata['sources'].items():
    source_path = root / dependency
    assert source_path.is_file() and kh(source_path.read_bytes()) == entry['keccak256'], 'Stale launch source: ' + dependency
for row in packages:
    for factory in row['factories']:
        source = (root / factory).read_text()
        for name in re.findall(r'"[^"\n]*\.sol:([A-Za-z_][A-Za-z0-9_]*)"', source):
            pending.setdefault(name, set()).add(factory)

rows = []
visited = set()
source_hashes = {}
while pending:
    name = sorted(pending)[0]
    discovered_from = pending.pop(name)
    if name in visited:
        continue
    visited.add(name)
    source, version, path, raw, compiled = artifact(name)
    assert '/detf/protocols/dexes/balancer/' not in source and '/slipstream/' not in source.lower(), 'Excluded release component: ' + source
    metadata = compiled.get('metadata') or json.loads(compiled['rawMetadata'])
    if isinstance(metadata, str):
        metadata = json.loads(metadata)
    mismatches = []
    for dependency, entry in metadata['sources'].items():
        dependency_path = root / dependency
        if dependency not in source_hashes:
            source_hashes[dependency] = kh(dependency_path.read_bytes()) if dependency_path.is_file() else None
        if source_hashes[dependency] != entry['keccak256']:
            mismatches.append(dependency)
        if not dependency_path.is_file():
            continue
        text = dependency_path.read_text()
        # Only actual deployment references, not every inherited Target artifact.
        references = re.findall(r'"[^"\n]*\.sol:([A-Za-z_][A-Za-z0-9_]*)"', text)
        references += re.findall(r'type\(([A-Za-z_][A-Za-z0-9_]*)\)\.creationCode', text)
        for referenced in references:
            if referenced not in visited:
                pending.setdefault(referenced, set()).add(dependency)
    creation = compiled['bytecode']['object'].removeprefix('0x')
    runtime = compiled['deployedBytecode']['object'].removeprefix('0x')
    linked = bool(re.fullmatch(r'[a-fA-F0-9]*', creation) and re.fullmatch(r'[a-fA-F0-9]*', runtime))
    row = {
        'contract': name, 'source': source, 'compiler': version,
        'discovered_from': sorted(discovered_from), 'source_sha256': hashlib.sha256((root / source).read_bytes()).hexdigest(),
        'artifact': str(path.relative_to(root)), 'artifact_sha256': hashlib.sha256(raw).hexdigest(),
        'creation_bytes': len(creation) // 2, 'runtime_bytes': len(runtime) // 2,
        'creation_template_keccak256': kh(bytes.fromhex(creation)) if linked else None,
        'runtime_template_keccak256': kh(bytes.fromhex(runtime)) if linked else None,
        'bytecode_fully_linked': linked, 'creation_link_references': compiled['bytecode'].get('linkReferences', {}),
        'runtime_link_references': compiled['deployedBytecode'].get('linkReferences', {}),
        'immutable_references': compiled['deployedBytecode'].get('immutableReferences', {}),
        'constructor_abi': [item for item in compiled['abi'] if item['type'] == 'constructor'],
        'compiler_settings': metadata['settings'],
        'compiler_source_count': len(metadata['sources']), 'stale_compiler_sources': mismatches,
    }
    row['artifact_valid'] = linked and 0 < row['runtime_bytes'] <= 24576 and not mismatches
    rows.append(row)
report = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'provenance': provenance,
    'method': __doc__, 'packages': [row['package'] for row in packages], 'components': rows,
    'all_artifacts_current_linked_and_eip170_compliant': all(row['artifact_valid'] for row in rows),
    'source_closure_union': source_hashes,
    'maintained_architecture_artifact': str(script_path.relative_to(root)),
    'maintained_architecture_artifact_sha256': hashlib.sha256(script_path.read_bytes()).hexdigest(),
    'limitations': 'Template runtime hashes are not deployed immutable values. Actual addresses, constructor args, cuts, configuration and receipt/code comparisons are recorded by the local rehearsal. Excluded Balancer DETFs and unfinished Slipstream are not release components.',
}
(here / 'release-artifact-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'packages': len(packages), 'components': len(rows), 'invalid': [row['contract'] for row in rows if not row['artifact_valid']]}))
assert report['all_artifacts_current_linked_and_eip170_compliant']
