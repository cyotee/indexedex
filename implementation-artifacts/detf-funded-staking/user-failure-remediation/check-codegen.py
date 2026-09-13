"""Compile the remediation's production surfaces and representative inherited tests.

This diagnostic leaves out/ and cache_forge/ untouched. It is not a build/test
substitute: the owner-run complete forge build must precede runtime validation.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
parser.add_argument('--v3-only', action='store_true', help='Recheck only V3 after an isolated V3 correction.')
args = parser.parse_args()
assert args.label.replace('-', '').isalnum()
art = Path(__file__).resolve().parent
root = art.parents[2]
record_path = art / (args.label + '-codegen.json')
assert not record_path.exists(), 'Use a fresh label to preserve compiler diagnostics.'

orbital = 'contracts/hooks/uniswap/v4/standardExchange/orbital/'
v3 = 'contracts/protocols/dexes/uniswap/v3/'
balancer = 'contracts/protocols/dexes/balancer/v3/pools/weighted/'
test_v4 = 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/'
test_balancer = 'test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/'
targets = [
    orbital + 'UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol',
    *[orbital + 'facets/UniswapV4StandardExchangeOrbitalBufferHook' + name + 'Facet.sol'
      for name in ('Deposit', 'DepositQuery', 'DepositZap', 'DepositFlexible', 'Se', 'Withdraw')],
    *[v3 + 'UniswapV3StandardExchange' + name + 'Facet.sol'
      for name in ('Out', 'OutQuery', 'InQuery')],
    balancer + 'mixedLegBuffer/MixedLegWeightedBufferPoolHookFacet.sol',
    balancer + 'multiPairBuffer/MultiPairStandardExchangeHookFacet.sol',
    test_balancer + 'mixedLegBuffer/decimals/MixedLegWeightedBufferPool_B_ALL6.t.sol',
    test_balancer + 'multiPairBuffer/decimals/MultiPairStandardExchangeBufferPool_B_ALL6.t.sol',
    test_balancer + 'commonBufferMultiVault/decimals/CommonBufferMultiVault_RoutingAndWalk_B_ALL6.t.sol',
    test_v4 + 'prod-se/UniswapV4Detf_Cp_Univ3Se_Policy.t.sol',
    test_v4 + 'prod-se/UniswapV4Detf_Cp_Univ4Se.t.sol',
    test_v4 + 'prod-se/decimals/UniswapV4Detf_Weighted_MorphoMix_Policy_B_ALL6.t.sol',
    test_v4 + 'prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18.t.sol',
    test_v4 + 'decimals/UniswapV4Detf_Weighted_ProductLaw_B_ALL6.t.sol',
    test_v4 + 'prod-se/UniswapV4Detf_Orbital_Univ4Se_ProductLaw.t.sol',
]
if args.v3_only:
    targets = [p for p in targets if p.startswith(v3)]
sources = {str(p.relative_to(art / 'before')) for p in (art / 'before').rglob('*.sol')} | set(targets)
source_hashes = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in sources}
settings = json.loads((art.parent / 'script-base-main-compiler-input.json').read_text())['settings']
assert settings['viaIR'] is False and settings['optimizer'] == {'enabled': True, 'runs': 1}
settings['outputSelection'] = {p: {'*': ['abi', 'evm.deployedBytecode.object']} for p in targets}
compiler_input = {
    'language': 'Solidity',
    'sources': {p: {'content': (root / p).read_text()} for p in sorted(sources)},
    'settings': settings,
}
input_path = art / (args.label + '-compiler-input.json')
output_path = art / (args.label + '-compiler-output.json')
input_path.write_text(json.dumps(compiler_input))
started = time.monotonic()
with input_path.open() as src, output_path.open('w') as dst:
    result = subprocess.run(
        [str(Path.home() / '.svm/0.8.35/solc-0.8.35'), '--standard-json', '--base-path', '.', '--allow-paths', '.'],
        cwd=root, stdin=src, stdout=dst, stderr=subprocess.PIPE, text=True,
    )
compiled = json.loads(output_path.read_text())
errors = [e['formattedMessage'] for e in compiled.get('errors', []) if e['severity'] == 'error']
contracts = {
    path + ':' + name: {
        'runtime_bytes': len(data.get('evm', {}).get('deployedBytecode', {}).get('object', '')) // 2,
        'test_methods': sum(e.get('type') == 'function' and e.get('name', '').startswith('test') for e in data['abi']),
    }
    for path, rows in compiled.get('contracts', {}).items() for name, data in rows.items()
}
passed = not errors and result.returncode == 0 and len(contracts) == len(targets)
passed = passed and all(c['runtime_bytes'] > 0 for c in contracts.values())
record = {
    'status': 'CODEGEN_ONLY_NOT_RUNTIME_VALIDATION',
    'passed': passed, 'exit_code': result.returncode,
    'seconds': round(time.monotonic() - started, 3), 'errors': errors,
    'contracts': contracts, 'source_sha256': source_hashes,
    'sources_unchanged': all(hashlib.sha256((root / p).read_bytes()).hexdigest() == h for p, h in source_hashes.items()),
    'compiler_input_sha256': hashlib.sha256(input_path.read_bytes()).hexdigest(),
}
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2), flush=True)
raise SystemExit(0 if passed and record['sources_unchanged'] else 1)
