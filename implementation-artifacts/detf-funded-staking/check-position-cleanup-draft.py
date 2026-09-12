"""Check position-cleanup sources in memory, without touching Forge's build inputs."""
from pathlib import Path
import argparse, hashlib, json, re, runpy, subprocess, time

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--kind', choices=['production', 'typecheck', 'test-codegen'], required=True)
args = parser.parse_args()
changes = runpy.run_path(str(art / 'prepare-position-storage-cleanup.py'))['changes']
fixture_changes = runpy.run_path(str(art / 'prepare-position-fixture-migrations.py'))['changes']
assert not changes.keys() & fixture_changes.keys()
changes.update(fixture_changes)
sources = {path: {'content': after} for path, (_, after) in changes.items()}
settings = json.loads((art / 'script-base-main-compiler-input.json').read_text())['settings']
assert not settings.get('viaIR', False)
outputs = {}
for version in ['v3', 'v4']:
    base = root / ('contracts/protocols/dexes/uniswap/' + version)
    for path in base.glob('Uniswap*StandardExchange*.sol'):
        if not path.stem.endswith(('Facet', 'DFPkg', 'Delegate')): continue
        relative = str(path.relative_to(root))
        sources.setdefault(relative, {'content': path.read_text()})
        if args.kind == 'production': outputs[relative] = {path.stem: ['evm.deployedBytecode.object']}
    if args.kind in ['typecheck', 'test-codegen']:
        for path in (root / ('test/foundry/spec/protocol/dexes/uniswap/' + version)).rglob('*.t.sol'):
            if not re.search(r'(FullRangeBook|Import|FeeCompound|Routes|Previews|DFPkg_Deploy|MultiJoinExit|TwapPoke|Sleeve|LocalLiquidBuffer|NativeEthWrap|Univ4SeNestedCaller|Adversarial_)', path.name): continue
            relative = str(path.relative_to(root))
            sources.setdefault(relative, {'content': path.read_text()})
            if args.kind == 'typecheck':
                outputs[relative] = {'*': ['abi']}
            elif re.search(r'(Routes|Previews|FeeCompound|MultiJoinExit|LocalLiquidBuffer|NativeEthWrap|Univ4SeNestedCaller|Adversarial_)', path.name):
                if '/decimals/' not in relative or '_P6_R18.t.sol' in relative:
                    outputs[relative] = {'*': ['abi', 'evm.bytecode.object']}
settings['outputSelection'] = outputs
label = 'position-cleanup-draft-' + args.kind
input_path = art / (label + '-compiler-input.json')
output_path = art / (label + '-compiler-output.json')
input_path.write_text(json.dumps({'language': 'Solidity', 'sources': sources, 'settings': settings}))
start = time.monotonic()
with input_path.open() as source, output_path.open('w') as output:
    result = subprocess.run([str(Path.home() / '.svm/0.8.35/solc-0.8.35'), '--standard-json',
        '--base-path', '.', '--allow-paths', '.'], cwd=root, stdin=source, stdout=output, stderr=subprocess.PIPE, text=True)
compiled = json.loads(output_path.read_text())
errors = [e['formattedMessage'] for e in compiled.get('errors', []) if e['severity'] == 'error']
record = {'status': 'DRAFT_DIAGNOSTIC_ONLY_NOT_RUNTIME_VALIDATION', 'kind': args.kind,
    'seconds': round(time.monotonic() - start, 3), 'exit_code': result.returncode, 'errors': errors,
    'source_freeze_preserved': True, 'compiler_input_sha256': hashlib.sha256(input_path.read_bytes()).hexdigest()}
if args.kind == 'production':
    record['runtime_bytes'] = {name: len(c['evm']['deployedBytecode']['object']) // 2
        for contracts in compiled.get('contracts', {}).values() for name, c in contracts.items()}
    record['components_fit_eip170'] = len(record['runtime_bytes']) == len(outputs) and all(
        0 < size <= 24576 for size in record['runtime_bytes'].values())
else:
    record['test_contracts'] = {path: {name: sum(e.get('type') == 'function' and e.get('name', '').startswith(('test', 'invariant'))
        for e in c['abi']) for name, c in contracts.items()} for path, contracts in compiled.get('contracts', {}).items()}
record['pass'] = result.returncode == 0 and not errors and record.get('components_fit_eip170', True)
(art / (label + '.json')).write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
if not record['pass']: raise SystemExit(1)
