"""Compile an unapplied provider patch in memory, without touching Forge artifacts."""
from pathlib import Path
import argparse, hashlib, json, runpy, subprocess, time

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--provider', choices=['aerodrome', 'rocket', 'erc4626-receipt'], required=True)
parser.add_argument('--kind', choices=['production', 'typecheck'], required=True)
args = parser.parse_args()
changes = runpy.run_path(str(art / ('prepare-' + args.provider + '-projection.py')))['changes']
settings = json.loads((art / 'script-base-main-compiler-input.json').read_text())['settings']
assert settings.get('viaIR', False) is False
assert settings['optimizer']['enabled'] and settings['optimizer']['runs'] == 1

if args.provider == 'erc4626-receipt':
    base = 'contracts/vaults/standard/erc4626/'
    components = ['ERC4626StandardExchangeInFacet', 'ERC4626StandardExchangeDFPkg']
    tests = ['test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol',
             'test/foundry/fork/eth_main/vaults/standard/erc4626/ERC4626StandardExchange_SfrxETH_Fork.t.sol']
    test_prefix = ('test_receiptAccounting', 'testFuzz_receiptAccounting', 'test_sfrxProjection')
    test_contract = ('ERC4626StandardExchange_TransitionQuote', 'ERC4626StandardExchange_SfrxETH_ProjectionFork')
elif args.provider == 'rocket':
    base = 'contracts/protocols/staking/rocket-pool/'
    components = ['RocketPoolRETHStandardExchangeInFacet', 'RocketPoolRETHStandardExchangeDFPkg']
    tests = ['test/foundry/fork/eth_main/vaults/staking/rocket-pool/RocketPoolRETHStandardExchange_Fork.t.sol',
             'test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol']
    test_prefix = 'test_rocketLive'
    test_contract = 'RocketPoolStandardExchangeProjectionFork'
else:
    base = 'contracts/protocols/dexes/aerodrome/v1/'
    components = ['AerodromeStandardExchangeOutQueryFacet', 'AerodromeStandardExchangeDFPkg']
    tests = ['test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol']
    test_prefix = ('test_aeroProjection', 'test_lpAccounting')
    test_contract = 'AerodromeNativeSYTest'

if args.kind == 'production':
    sources = {path: {'content': after} for path, (_, after) in changes.items()
               if path.startswith('contracts/') and '/test/' not in path}
    for name in components:
        path = base + name + '.sol'
        if path not in sources:
            sources[path] = {'content': (root / path).read_text()}
    settings['outputSelection'] = {base + name + '.sol': {name: ['evm.deployedBytecode.object']} for name in components}
    if args.provider == 'aerodrome':
        for family, directory in [('UniswapV2', 'uniswap/v2'), ('CamelotV2', 'camelot/v2')]:
            name = family + 'StandardExchangeQueryFacet'
            path = f'contracts/protocols/dexes/{directory}/{name}.sol'
            sources[path] = {'content': (root / path).read_text()}
            settings['outputSelection'][path] = {name: ['evm.deployedBytecode.object']}
            components.append(name)
    label = args.provider + '-draft'
else:
    sources = {path: {'content': after} for path, (_, after) in changes.items()}
    settings['outputSelection'] = {path: {'*': ['abi']} for path in tests}
    label = args.provider + '-draft-test'

input_path = art / (label + '-compiler-input.json')
output_path = art / (label + '-compiler-output.json')
input_path.write_text(json.dumps({'language': 'Solidity', 'sources': sources, 'settings': settings}))
start = time.monotonic()
with input_path.open() as source, output_path.open('w') as output:
    result = subprocess.run([str(Path.home() / '.svm/0.8.35/solc-0.8.35'), '--standard-json',
                             '--base-path', '.', '--allow-paths', '.'], cwd=root, stdin=source,
                            stdout=output, stderr=subprocess.PIPE, text=True)
compiled = json.loads(output_path.read_text())
errors = [error['formattedMessage'] for error in compiled.get('errors', []) if error['severity'] == 'error']
record = {'status': 'DRAFT_DIAGNOSTIC_ONLY_NOT_RUNTIME_VALIDATION', 'kind': args.kind,
          'seconds': round(time.monotonic() - start, 3), 'exit_code': result.returncode,
          'errors': errors, 'source_freeze_preserved': True,
          'compiler_input_sha256': hashlib.sha256(input_path.read_bytes()).hexdigest(), 'settings': settings}
if args.kind == 'production':
    record['runtime_bytes'] = {name: len(contract['evm']['deployedBytecode']['object']) // 2
                               for contracts in compiled.get('contracts', {}).values() for name, contract in contracts.items()}
    record['all_components_within_eip170'] = len(record['runtime_bytes']) == len(components) and all(
        0 < size <= 24576 for size in record['runtime_bytes'].values())
    record_path = art / (args.provider + '-draft-compile.json')
else:
    record['proposed_cases'] = sorted({entry['name'] for contracts in compiled.get('contracts', {}).values()
                                      for name, contract in contracts.items() if name in ((test_contract,) if isinstance(test_contract, str) else test_contract)
                                      for entry in contract['abi'] if entry.get('name', '').startswith(test_prefix)})
    record['expected_case_count'] = {'rocket': 7, 'aerodrome': 10, 'erc4626-receipt': 11}[args.provider]
    record['all_expected_methods_typechecked'] = len(record['proposed_cases']) == record['expected_case_count']
    record_path = art / (args.provider + '-draft-test-typecheck.json')
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({key: value for key, value in record.items() if key != 'settings'}, indent=2))
if (result.returncode or errors or record.get('all_components_within_eip170') is False
        or record.get('all_expected_methods_typechecked') is False):
    raise SystemExit(1)
