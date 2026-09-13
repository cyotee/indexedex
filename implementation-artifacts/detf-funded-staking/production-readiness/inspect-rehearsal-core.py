"""Read-only code/selector preflight for reused release core dependencies."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.request
from Crypto.Hash import keccak
from eth_abi import decode, encode

here = Path(__file__).resolve().parent
root = here.parents[2]
sys.path.insert(0, str(here.parent))
from build_provenance import capture

fingerprints = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
                'crane_source_and_config_sha256', 'forge_version')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rpc', required=True, help='Loopback URL or configured RPC alias')
parser.add_argument('--block', default='latest')
parser.add_argument('--deployments', default='deployments/anvil_robinhood_main')
parser.add_argument('--output', required=True)
parser.add_argument('--packages', action='store_true', help='Inspect every package and referenced facet in the current core registry')
parser.add_argument('--require-current', action='store_true', help='Fail on stale runtime/source, selector or authorization mismatches')
args = parser.parse_args()
output = here / args.output
assert not output.exists(), 'Preserve previous preflight; choose a fresh output name'
provenance = capture(root)
url = args.rpc
if not url.startswith(('http://127.0.0.1:', 'http://localhost:')):
    environment = os.environ.copy()
    dotenv = root / '.env'
    if dotenv.exists():
        for line in dotenv.read_text().splitlines():
            match = re.match(r'^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$', line)
            if match:
                value = match[2]
                if len(value) > 1 and value[0] == value[-1] and value[0] in "\"'":
                    value = value[1:-1]
                environment.setdefault(match[1], value)
    match = re.search(r'^' + re.escape(args.rpc) + r'\s*=\s*"([^"]+)"\s*$', (root / 'foundry.toml').read_text(), re.M)
    assert match, 'Use a configured RPC alias or loopback endpoint'
    url = re.sub(r'\$\{([^}]+)\}', lambda m: environment[m[1]], match[1])
block = hex(int(args.block)) if args.block.isdigit() else args.block

class RpcError(RuntimeError):
    def __init__(self, payload):
        self.code = payload.get('code')
        data = payload.get('data')
        self.data = data if isinstance(data, str) and re.fullmatch(r'0x[0-9a-fA-F]*', data) else None
        super().__init__(f'RPC returned error code {self.code}; endpoint omitted')

def rpc(method, params):
    assert method in ('eth_getCode', 'eth_call', 'eth_chainId', 'eth_getBlockByNumber')
    request = urllib.request.Request(url, data=json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode(), headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.load(response)
    except Exception:
        raise RuntimeError(f'RPC request failed: {method}; endpoint omitted') from None
    if 'error' in payload:
        raise RpcError(payload['error'])
    return payload['result']

def call(address, signature, types, values, returns):
    selector = keccak.new(digest_bits=256, data=signature.encode()).digest()[:4]
    data = '0x' + (selector + encode(types, values)).hex()
    return decode(returns, bytes.fromhex(rpc('eth_call', [{'to': address, 'data': data}, block])[2:]))

def code_hash(data):
    return '0x' + keccak.new(digest_bits=256, data=data).hexdigest()

def compare(address, name, library_source=None, ancestors=()):
    identity = (address.lower(), name)
    assert identity not in ancestors, 'Cyclic linked-library comparison requires explicit review'
    code = bytes.fromhex(rpc('eth_getCode', [address, block])[2:])
    artifact_path = root / 'out' / (name + '.sol') / (name + '.json')
    if not artifact_path.is_file():
        alternatives = list((root / 'out').glob('*.sol/' + name + '.json'))
        if len(alternatives) == 1:
            artifact_path = alternatives[0]
    row = {'address': address, 'contract': name, 'runtime_bytes': len(code), 'code_keccak256': code_hash(code), 'present': bool(code)}
    if not artifact_path.is_file():
        row['status'] = 'MISSING_COMPILED_ARTIFACT'
        return row
    artifact = json.loads(artifact_path.read_text())
    template_hex = artifact['deployedBytecode']['object'].removeprefix('0x')
    row['artifact'] = str(artifact_path.relative_to(root))
    row['artifact_sha256'] = hashlib.sha256(artifact_path.read_bytes()).hexdigest()
    metadata = artifact.get('metadata') or json.loads(artifact['rawMetadata'])
    if isinstance(metadata, str):
        metadata = json.loads(metadata)
    row['stale_compiled_sources'] = [source for source, prior in metadata['sources'].items() if not (root / source).is_file() or code_hash((root / source).read_bytes()) != prior['keccak256']]
    if len(template_hex) != len(code) * 2:
        row['status'] = 'CODE_LENGTH_MISMATCH'
        return row
    row['linked_libraries'] = []
    for source, libraries in artifact['deployedBytecode'].get('linkReferences', {}).items():
        for library, references in libraries.items():
            addresses = set()
            for ref in references:
                start, size = ref['start'], ref['length']
                assert size == 20 and 0 <= start <= len(code) - size
                value = code[start:start + size].hex()
                assert int(value, 16), 'Linked library is the zero address'
                addresses.add('0x' + value)
                template_hex = template_hex[:start * 2] + value + template_hex[(start + size) * 2:]
            assert len(addresses) == 1, 'Inconsistent addresses for one linked library'
            linked = compare(addresses.pop(), library, source, ancestors + (identity,))
            linked['link_offsets'] = references
            row['linked_libraries'].append(linked)
    if not re.fullmatch(r'[0-9a-fA-F]*', template_hex):
        row['status'] = 'LINKED_LIBRARY_COMPARISON_REQUIRED'
        return row
    template = bytearray.fromhex(template_hex)
    normalized = bytearray(code)
    if library_source:
        # Solidity libraries replace only their PUSH20 self-address deployment guard.
        assert metadata['settings']['compilationTarget'] == {library_source: name}
        assert re.search(r'\blibrary\s+' + re.escape(name) + r'\b', (root / library_source).read_text())
        assert template[:21] == b'\x73' + bytes(20) and template[21:23] == b'\x30\x14'
        assert code[1:21].hex() == address.lower().removeprefix('0x'), 'Library self-address guard mismatch'
        row['library_self_address'] = address
        normalized[1:21] = bytes(20)
    immutables = []
    for identifier, references in artifact['deployedBytecode'].get('immutableReferences', {}).items():
        for ref in references:
            start, size = ref['start'], ref['length']
            assert 0 <= start <= len(code) - size
            immutables.append({'ast_id': identifier, 'offset': start, 'bytes': size, 'deployed_value': '0x' + code[start:start + size].hex()})
            normalized[start:start + size] = template[start:start + size]
    row['immutable_values'] = immutables
    row['template_code_keccak256'] = code_hash(template)
    row['normalized_code_keccak256'] = code_hash(normalized)
    row['status'] = 'MATCH' if code and normalized == template else 'CODE_MISMATCH'
    if any(item['status'] != 'MATCH' or item.get('stale_compiled_sources') or item['runtime_bytes'] > 24576
           for item in row['linked_libraries']):
        row['status'] = 'LINKED_LIBRARY_MISMATCH'
    if code and normalized != template and len(normalized) == len(template):
        metadata_size = int.from_bytes(template[-2:], 'big')
        if metadata_size == int.from_bytes(normalized[-2:], 'big') and 0 < metadata_size < len(template) - 2:
            boundary = len(template) - metadata_size - 2
            row['executable_prefix_matches'] = normalized[:boundary] == template[:boundary]
            row['metadata_bytes'] = metadata_size
            if row['executable_prefix_matches']:
                row['status'] = 'MATCH_EXECUTABLE_METADATA_DIFFERS'
    return row

deployments = root / args.deployments
def manifest(name):
    return json.loads((deployments / name).read_text())

create3 = manifest('phase02_stage01_create3_factory.json')['create3Factory']
diamond = manifest('phase02_stage02_diamond_package_factory.json')['diamondPackageFactory']
hook = manifest('phase02_stage03_hook_factory.json')
platform = manifest('phase04_stage01_fee_collector_and_manager.json')
rows = [compare(create3, 'Create3Factory'), compare(diamond, 'DiamondPackageCallBackFactory'),
        compare(hook['hookFactory'], 'UniswapV4HookDiamondPackageCallBackFactory'),
        compare(hook['hookFlagsFacet'], 'UniswapV4HookFlagsFacet')]
core_proxies = []
for role in ('create3Factory', 'indexedexManager', 'feeCollector'):
    address = create3 if role == 'create3Factory' else platform[role]
    row = compare(address, 'Create3Factory' if role == 'create3Factory' else 'MinimalDiamondCallBackProxy')
    row['role'] = role
    row['owner'] = call(address, 'owner()', [], [], ['address'])[0]
    facets = call(address, 'facets()', [], [], ['(address,bytes4[])[]'])[0]
    row['facets'] = []
    for target, selectors in facets:
        name = call(target, 'facetName()', [], [], ['string'])[0]
        facet = compare(target, name)
        facet['selectors'] = ['0x' + selector.hex() for selector in selectors]
        declared = call(target, 'facetFuncs()', [], [], ['bytes4[]'])[0]
        facet['installed_selectors_declared'] = set(selectors).issubset(set(declared))
        row['facets'].append(facet)
    core_proxies.append(row)
canonical_override_probe = []
erc20_code = json.loads((root / 'out/ERC20Facet.sol/ERC20Facet.json').read_text())['bytecode']['object']
facet_salt = keccak.new(digest_bits=256, data=encode(['string'], ['ERC20Facet'])).digest()
for signature, types, values, returns in [
    ('deployCanonicalFacetOverride(bytes,bytes32,bytes4)', ['bytes', 'bytes32', 'bytes4'],
     [bytes.fromhex(erc20_code.removeprefix('0x')), facet_salt, bytes.fromhex('01ffc9a7')], ['address']),
    ('deployCanonicalFacetWithArgsOverride(bytes,bytes,bytes32,bytes4)', ['bytes', 'bytes', 'bytes32', 'bytes4'],
     [bytes.fromhex(erc20_code.removeprefix('0x')), b'', facet_salt, bytes.fromhex('01ffc9a7')], ['address']),
    ('setCanonicalPackage(bytes4,address)', ['bytes4', 'address'],
     [bytes.fromhex('01ffc9a7'), call(create3, 'allPackages()', [], [], ['address[]'])[0][0]], ['bool']),
]:
    selector = keccak.new(digest_bits=256, data=signature.encode()).digest()[:4]
    data = '0x' + (selector + encode(types, values)).hex()
    try:
        result = rpc('eth_call', [{'from': '0x000000000000000000000000000000000000baD1', 'to': create3, 'data': data}, block])
        probe = {'signature': signature, 'unauthorized_call_succeeded': True, 'returned_values': decode(returns, bytes.fromhex(result[2:]))}
    except RpcError as error:
        expected = '0x' + (keccak.new(digest_bits=256, data=b'NotOperator(address)').digest()[:4]
            + encode(['address'], ['0x000000000000000000000000000000000000bad1'])).hex()
        probe = {'signature': signature, 'unauthorized_call_succeeded': False,
                 'rpc_error_code': error.code, 'revert_data': error.data,
                 'expected_not_operator': error.data is not None and error.data.lower() == expected}
    probe['method'] = 'eth_call only, arbitrary non-owner/non-operator, existing registered dependency, no transaction and no persisted changes; transport failures are not authorization evidence'
    canonical_override_probe.append(probe)
common = manifest('phase03_stage01_common_facets.json')
for role, address in common.items():
    if not isinstance(address, str) or not re.fullmatch(r'0x[0-9a-fA-F]{40}', address):
        continue
    name = call(address, 'facetName()', [], [], ['string'])[0]
    row = compare(address, name)
    row['role'] = role
    rows.append(row)
packages = []
registered_facets = []
dependent_proxies = []
oracle_binding_matches = False
if args.packages:
    for address in call(create3, 'allFacets()', [], [], ['address[]'])[0]:
        name = call(address, 'facetName()', [], [], ['string'])[0]
        registered_facets.append(compare(address, name))
    oracle = manifest('phase05_stage02_uniswap_v4_twap_oracle.json')
    rows.append(compare(oracle['twapAdapterFactory'], 'UniswapV4TwapAdapterFactory'))
    oracle_proxy = compare(oracle['twapOracle'], 'MinimalDiamondCallBackProxy')
    oracle_proxy['role'] = 'twapOracle'
    oracle_proxy['pool_manager'] = call(oracle['twapOracle'], 'poolManager()', [], [], ['address'])[0]
    oracle_binding_matches = oracle_proxy['pool_manager'].lower() == oracle['poolManager'].lower() == manifest('phase01_stage03_uniswap_v4.json')['poolManager'].lower()
    oracle_proxy['facets'] = []
    for target, selectors in call(oracle['twapOracle'], 'facets()', [], [], ['(address,bytes4[])[]'])[0]:
        name = call(target, 'facetName()', [], [], ['string'])[0]
        facet = compare(target, name)
        declared = call(target, 'facetFuncs()', [], [], ['bytes4[]'])[0]
        facet.update(selectors=['0x' + value.hex() for value in selectors],
                     installed_selectors_declared=set(selectors).issubset(set(declared)))
        oracle_proxy['facets'].append(facet)
    dependent_proxies.append(oracle_proxy)
    core_packages = call(create3, 'allPackages()', [], [], ['address[]'])[0]
    vault_packages = call(platform['indexedexManager'], 'vaultPackages()', [], [], ['address[]'])[0]
    for address in sorted(set(core_packages) | set(vault_packages)):
        name = call(address, 'packageName()', [], [], ['string'])[0]
        package = compare(address, name)
        compiled_package = json.loads((root / package['artifact']).read_text())
        if any(item.get('type') == 'function' and item.get('name') == 'requiredHookFlags'
               for item in compiled_package['abi']):
            package['required_hook_flags'] = call(address, 'requiredHookFlags()', [], [], ['uint160'])[0]
            package['required_hook_flags_hex'] = hex(package['required_hook_flags'])
        package['registered_in'] = ([create3] if address in core_packages else []) + ([platform['indexedexManager']] if address in vault_packages else [])
        package['interfaces'] = ['0x' + value.hex() for value in call(address, 'facetInterfaces()', [], [], ['bytes4[]'])[0]]
        cuts = call(address, 'facetCuts()', [], [], ['(address,uint8,bytes4[])[]'])[0]
        package['cuts'] = []
        seen = {}
        duplicates = []
        for target, action, selectors in cuts:
            if len(selectors) != len(set(selectors)):
                duplicates.extend('0x' + value.hex() for value in selectors if selectors.count(value) > 1)
            facet_name = call(target, 'facetName()', [], [], ['string'])[0]
            # Some packages host the initialization facet in their own runtime.
            # The inherited facetName identifies the abstract mixin, not its bytecode.
            facet = compare(target, name if target.lower() == address.lower() else facet_name)
            facet['declared_facet_name'] = facet_name
            declared = call(target, 'facetFuncs()', [], [], ['bytes4[]'])[0]
            explicit_replacement = False
            if action == 1:
                # The bond package adds ERC721 then explicitly replaces its three
                # transfer routes to settle funded rewards before ownership changes.
                # Those are intentionally omitted from the bond facet's Add list.
                expected = {'23b872dd', '42842e0e', 'b88d4fde'}
                methods = json.loads((root / facet['artifact']).read_text())['methodIdentifiers']
                explicit_replacement = (
                    name in ('DETFNFTVaultDFPkg', 'UniswapV4DetfBondNFTVaultDFPkg')
                    and facet_name in ('DETFNFTVaultFacet', 'UniswapV4DetfBondNFTVaultFacet')
                    and {value.hex() for value in selectors} == expected
                    and expected.issubset(set(methods.values()))
                    and all(value in seen and seen[value].lower() != target.lower() for value in selectors)
                )
                facet['explicit_erc721_transfer_replacement'] = explicit_replacement
                facet['replacement_source'] = 'contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol:facetCuts'
            facet.update(action=action, selectors=['0x' + value.hex() for value in selectors],
                         declared_add_selectors=['0x' + value.hex() for value in declared],
                         installed_selectors_declared=(action == 0 and set(selectors).issubset(set(declared))) or explicit_replacement)
            duplicates.extend('0x' + value.hex() for value in selectors if value in seen and not explicit_replacement)
            seen.update({value: target for value in selectors})
            package['cuts'].append(facet)
        package['duplicate_selectors'] = duplicates
        packages.append(package)
configuration = None
if args.packages:
    manager = platform['indexedexManager']
    expected_owner = '0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b'
    values = {}
    for signature in ('defaultUsageFee()', 'defaultDexSwapFee()', 'defaultSeigniorageIncentivePercentage()',
                      'defaultSeigniorageFeeToSharePercentage()', 'defaultSeigniorageCreatorSharePercentage()'):
        values[signature] = call(manager, signature, [], [], ['uint256'])[0]
    terms = call(manager, 'defaultBondTerms()', [], [], ['(uint256,uint256,uint256,uint256)'])[0]
    values['defaultBondTerms()'] = dict(zip(
        ('minLockDuration', 'maxLockDuration', 'minBonusPercentage', 'maxBonusPercentage'), terms))
    liquid_artifact = root / 'out/IUniswapV4StandardExchangeLiquidReserve.sol/IUniswapV4StandardExchangeLiquidReserve.json'
    identifiers = json.loads(liquid_artifact.read_text())['methodIdentifiers']
    interface_id = 0
    for selector in identifiers.values():
        interface_id ^= int(selector, 16)
    liquid_id = interface_id.to_bytes(4, 'big')
    values['v4LiquidReserveInterface'] = '0x' + liquid_id.hex()
    values['defaultLiquidReservePercentageOfTypeId(bytes4)'] = call(
        manager, 'defaultLiquidReservePercentageOfTypeId(bytes4)', ['bytes4'], [liquid_id], ['uint256'])[0]
    values['feeTo()'] = call(manager, 'feeTo()', [], [], ['address'])[0]
    values['managerIsCoreOperator'] = call(create3, 'isOperator(address)', ['address'], [manager], ['bool'])[0]
    checks = {
        'core_and_platform_owners': all(row['owner'].lower() == expected_owner for row in core_proxies),
        'fee_collector_wiring': values['feeTo()'].lower() == platform['feeCollector'].lower(),
        'usage_fee': values['defaultUsageFee()'] == 5 * 10**16,
        'swap_fee': values['defaultDexSwapFee()'] == 3 * 10**14,
        'seigniorage': values['defaultSeigniorageIncentivePercentage()'] == 5 * 10**16,
        'fee_standing_weight': values['defaultSeigniorageFeeToSharePercentage()'] == 12 * 10**16,
        'creator_standing_weight': values['defaultSeigniorageCreatorSharePercentage()'] == 28 * 10**16,
        'bond_terms': tuple(terms) == (86400, 180 * 86400, 0, 5 * 10**17),
        'v4_liquid_reserve': values['defaultLiquidReservePercentageOfTypeId(bytes4)'] == 2 * 10**17,
        'manager_core_operator': values['managerIsCoreOperator'],
    }
    configuration = {'values': values, 'checks': checks, 'all_match': all(checks.values()),
                     'sources': ['scripts/foundry/anvil_robinhood_main/FixtureEconomics.sol',
                                 'scripts/foundry/anvil_robinhood_main/Phase_04_Stage_01_FeeCollectorAndManager.sol',
                                 'contracts/manager/IndexedexManagerDFPkg.sol']}
header = rpc('eth_getBlockByNumber', [block, False])
hook_deployment = {
    'factory': hook['hookFactory'],
    'proxy_init_hash': '0x' + call(hook['hookFactory'], 'PROXY_INIT_HASH()', [], [], ['bytes32'])[0].hex(),
    'flag_mask': call(hook['hookFactory'], 'FLAG_MASK()', [], [], ['uint160'])[0],
    'max_mining_loop': call(hook['hookFactory'], 'MAX_LOOP()', [], [], ['uint256'])[0],
    'namespace_rule': 'Process package args, calcSalt(processed), then final CREATE2 salt with mineNonce. Architecture deployment registers packages; per-instance processed args and mined nonce belong to the later instance activation.',
}
proxy_creation = json.loads((root / 'out/MinimalDiamondCallBackProxy.sol/MinimalDiamondCallBackProxy.json').read_text())['bytecode']['object']
hook_deployment['proxy_init_hash_matches_artifact'] = hook_deployment['proxy_init_hash'] == code_hash(bytes.fromhex(proxy_creation.removeprefix('0x')))
hook_deployment['package_flags_within_factory_mask'] = all(
    not row['required_hook_flags'] & ~hook_deployment['flag_mask']
    for row in packages if 'required_hook_flags' in row
)
end_provenance = capture(root)
sources_unchanged = all(provenance[key] == end_provenance[key] for key in fingerprints)
result = {'checked_at_utc': datetime.now(timezone.utc).isoformat(), 'rpc_alias_or_loopback': args.rpc,
          'provenance': provenance, 'sources_unchanged': sources_unchanged,
          'chain_id': int(rpc('eth_chainId', []), 16), 'block': int(header['number'], 16), 'block_hash': header['hash'],
          'mode': 'READ_ONLY_NO_BROADCAST', 'dependencies': rows, 'core_proxies': core_proxies,
          'canonical_override_probe': canonical_override_probe,
          'platform_configuration': configuration,
          'hook_deployment': hook_deployment,
          'registered_packages': packages,
          'registered_facets': registered_facets, 'dependent_proxies': dependent_proxies,
          'oracle_binding_matches': oracle_binding_matches,
          'limits': 'Immutable values are recorded separately and masked only at compiler-declared offsets. Linked addresses are substituted only at compiler linkReferences and each linked library is recursively checked against current source/runtime including its exact self-address guard. Package-hosted facets are compared to the containing package runtime. Proxy runtime equality alone does not validate its installed facets or configuration; those are recorded separately.'}
flat = rows + core_proxies + [facet for row in core_proxies for facet in row['facets']] + packages + [facet for row in packages for facet in row['cuts']] + registered_facets + dependent_proxies + [facet for row in dependent_proxies for facet in row['facets']]
result['current_release_checks_passed'] = sources_unchanged and bool(packages) and oracle_binding_matches and configuration is not None and configuration['all_match'] and hook_deployment['proxy_init_hash_matches_artifact'] and hook_deployment['package_flags_within_factory_mask'] and all(
    row['status'] == 'MATCH' and not row.get('stale_compiled_sources') and row['runtime_bytes'] <= 24576
    and row.get('installed_selectors_declared', True) for row in flat
) and all(not row['duplicate_selectors'] for row in packages) and all(
    row.get('expected_not_operator', False) for row in canonical_override_probe
)
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'components': len(flat), 'mismatches': [{k: row.get(k) for k in ('contract', 'address', 'status', 'stale_compiled_sources')} for row in flat if row['status'] != 'MATCH' or row.get('stale_compiled_sources')]}))
if args.require_current:
    assert sources_unchanged, 'Release sources changed during runtime reconciliation'
    assert all(row['status'] == 'MATCH' and not row.get('stale_compiled_sources') and row['runtime_bytes'] <= 24576 for row in flat), 'Current runtime/source mismatch'
    assert all(row.get('installed_selectors_declared', True) for row in flat), 'Undeclared installed selector'
    assert all(not row['duplicate_selectors'] for row in packages), 'Duplicate package selector'
    assert all(row.get('expected_not_operator', False) for row in canonical_override_probe), 'All canonical mutators must reject the unauthorized caller with NotOperator'
    assert configuration is None or configuration['all_match'], 'Actual platform configuration must match the reviewed launch defaults'
    assert hook_deployment['proxy_init_hash_matches_artifact'], 'Hook factory proxy init hash differs from the release artifact'
    assert hook_deployment['package_flags_within_factory_mask'], 'Hook package declares flags outside the factory mask'
    assert not args.packages or oracle_binding_matches, 'TWAP oracle PoolManager must match the verified Phase 01 pin'
