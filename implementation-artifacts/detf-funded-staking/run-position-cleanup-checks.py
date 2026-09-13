"""Build current V3/V4 components and run retained full-range/route/import suites."""
from pathlib import Path
import argparse, json, os, re, shutil, subprocess, time
from build_provenance import capture, hermetic_environment

art = Path(__file__).resolve().parent
root = art.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
parser.add_argument('--runtime-migrations', action='store_true',
    help='Retest all concrete suites affected by the retained runtime fixture migration.')
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.label)
record_path = art / ('position-cleanup-' + args.label + '-run.json')
assert not record_path.exists(), 'Choose a new label to preserve prior evidence.'
cache = art / 'position-cleanup-validation-cache'
cache.mkdir(exist_ok=True)
if not (cache / 'solidity-files-cache.json').exists():
    shutil.copy2(root / 'cache_forge/solidity-files-cache.json', cache / 'solidity-files-cache.json')
environment, emptied = hermetic_environment(root)
environment.update(FOUNDRY_CACHE_PATH=str(cache), FOUNDRY_SCRIPT='contracts/vaults/detf/common/core',
    FOUNDRY_TEST='test/foundry/spec/protocol/dexes/uniswap')
base = 'contracts/protocols/dexes/uniswap'
components = sorted(str(path.relative_to(root)) for version in ['v3', 'v4']
    for path in (root / base / version).glob('Uniswap*StandardExchange*.sol')
    if path.stem.endswith(('Facet', 'DFPkg', 'Delegate')))
pattern = r'^(UniswapV[34]StandardExchange|Adversarial_)'
if args.runtime_migrations:
    pattern = r'^(UniswapV[34]StandardExchange_FullRangeBook|UniswapV4StandardExchange_TwapPoke|UniswapV3StandardExchangeOutQueryFacet_IFacet_Test|Adversarial_Accounting|Adversarial_UniswapV4SE_E6ImpA0)'
draft = json.loads((art / 'position-cleanup-draft-typecheck-compiler-output.json').read_text())
expected = {}
for path, contracts in draft['contracts'].items():
    for name, contract in contracts.items():
        if not re.match(pattern, name): continue
        count = sum(entry.get('type') == 'function' and entry.get('name', '').startswith(('test', 'invariant'))
                    for entry in contract['abi'])
        if count: expected[path + ':' + name] = count
assert expected, 'Preserve the prepared concrete suite inventory.'
if args.runtime_migrations:
    expected['test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchangeOutQueryFacet_IFacet_Test.t.sol:UniswapV3StandardExchangeOutQueryFacet_IFacet_Test'] = 5
record = {'provenance': capture(root), 'scope': 'All retained concrete instances of the named V3/V4 suites, including decimal matrices. No new test profiles, fuzz reductions, or deferred Slipstream selection.',
    'explicitly_empty_rpc_environment_keys': emptied, 'expected_retained_suites': expected}
commands = [('build', ['forge', 'build', '--offline', '--contracts', base] + components),
            ('test', ['forge', 'test', '--offline', '--contracts', base, '--match-contract', pattern, '-vvv'])]
for phase, command in commands:
    log = art / ('position-cleanup-' + args.label + '-' + phase + '.log')
    start = time.monotonic()
    with log.open('w') as output:
        result = subprocess.run(command, cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT)
    lines = log.read_text(errors='replace').split('\nFailing tests:', 1)[0].splitlines()
    record[phase] = {'command': command, 'exit_code': result.returncode, 'seconds': round(time.monotonic() - start, 3)}
    if phase == 'build' and result.returncode == 0:
        sizes = {}
        for component in components:
            path = Path(component)
            artifact = json.loads((root / 'out' / path.name / (path.stem + '.json')).read_text())
            sizes[path.stem] = len(artifact['deployedBytecode']['object'].removeprefix('0x')) // 2
        record[phase]['runtime_bytes'] = sizes
        record[phase]['components_fit_eip170'] = len(sizes) == 26 and all(0 < size <= 24576 for size in sizes.values())
    if phase == 'test':
        results = [line for line in lines if line.startswith(('[PASS]', '[FAIL'))]
        record[phase]['passed'] = sum(line.startswith('[PASS]') for line in results)
        record[phase]['failed'] = sum(line.startswith('[FAIL') for line in results)
        record[phase]['suites'] = [line for line in lines if re.match(r'Ran \d+ tests? for ', line)]
        required = ['UniswapV3StandardExchange_FullRangeBook_Test', 'UniswapV3StandardExchange_Import_Test',
            'UniswapV3StandardExchange_FeeCompound_Test', 'UniswapV4StandardExchangeRoutes_Test',
            'UniswapV4StandardExchange_FullRangeBook', 'UniswapV4StandardExchange_TwapPoke']
        if args.runtime_migrations:
            required = ['UniswapV3StandardExchange_FullRangeBook_Test',
                'UniswapV4StandardExchange_FullRangeBook',
                'UniswapV3StandardExchangeOutQueryFacet_IFacet_Test']
        record[phase]['missing_base_suites'] = [name for name in required if not any(
            line.endswith(':' + name) for line in record[phase]['suites'])]
        executed = {}
        for line in record[phase]['suites']:
            match = re.match(r'Ran (\d+) tests? for (.+)', line)
            executed[match[2]] = int(match[1])
        record[phase]['missing_or_incomplete_retained_suites'] = {
            suite: {'expected': count, 'reported': executed.get(suite, 0)}
            for suite, count in expected.items() if executed.get(suite, 0) < count}
        record[phase]['validation_passed'] = result.returncode == 0 and len(results) >= sum(expected.values()) and not record[phase]['missing_base_suites'] and not record[phase]['missing_or_incomplete_retained_suites']
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    print(phase, json.dumps({key: value for key, value in record[phase].items() if key not in ('command', 'runtime_bytes', 'suites')}), flush=True)
    for line in lines:
        if line.startswith(('Compiling ', 'Solc ', 'No files changed', '[FAIL', 'Error', 'Ran ')): print(line, flush=True)
    if result.returncode: raise SystemExit(result.returncode)
    if phase == 'build' and not record[phase]['components_fit_eip170']: raise SystemExit('All components must fit EIP-170.')
    if phase == 'test' and not record[phase]['validation_passed']: raise SystemExit('Retained position suites did not all execute and pass.')
