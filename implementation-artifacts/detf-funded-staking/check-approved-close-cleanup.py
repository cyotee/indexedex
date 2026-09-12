"""Validate compiled ABI/deployment schema and source disposition after a successful build."""
from pathlib import Path
import datetime, hashlib, json, re

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
checks = []
def check(label, passed, **details):
    checks.append({'check': label, 'passed': bool(passed), **details})

for name in ('IUniswapV4Detf', 'UniswapV4DetfQueryFacet', 'UniswapV4DetfExchangeFacet',
             'UniswapV4DetfBondFacet', 'UniswapV4DetfMaintenanceFacet', 'UniswapV4DetfClaimFacet'):
    source_name = 'IUniswapV4Detf' if name == 'IUniswapV4Detf' else name
    path = root / 'out' / (source_name + '.sol') / (name + '.json')
    if not path.exists():
        check(name + ' compiled ABI exists', False, artifact=str(path.relative_to(root)))
        continue
    artifact = json.loads(path.read_text())
    functions = [entry['name'] for entry in artifact['abi'] if entry['type'] == 'function']
    removed = sorted(set(functions) & {'closeRoutes', 'closeRouteMode', 'close', 'mintClaim', 'buyClaim', 'redeemClaim', 'compound'})
    check(name + ' retired API absent', not removed, obsolete=removed,
          artifact=str(path.relative_to(root)))

path = root / 'out/UniswapV4DetfDFPkg.sol/UniswapV4DetfDFPkg.json'
abi = json.loads(path.read_text())['abi']
deploy = next(entry for entry in abi if entry.get('name') == 'deployVault')
fields = [entry['name'] for entry in deploy['inputs'][0]['components']]
check('Canonical PkgArgs omits both mature-close configuration fields',
      not set(fields) & {'closeRoutes', 'closeRouteMode'}, fields=fields)
check('Immutable liquidity policy remains in deployment schema', 'ownerOnlyLiquidity' in fields)

path = root / 'out/IDetfBondNFT.sol/IDetfBondNFT.json'
functions = {entry['name'] for entry in json.loads(path.read_text())['abi'] if entry['type'] == 'function'}
required = {'positionOf', 'previewClaim', 'claimPrincipal', 'claimRewards', 'claimBond', 'createFundedPosition'}
check('Funded principal/vesting/reward claim surface retained', required <= functions,
      missing=sorted(required-functions))

path = root / 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol'
source = path.read_text()
removed_fields = {'detfNftId', 'feeRecipientNftId', 'userBondedLp', 'closeRouteMode', 'closeTable'}
remaining = [name for name in sorted(removed_fields) if re.search(r'\b'+name+r'\b', source)]
check('Five obsolete V4 storage members/accessors removed', not remaining, remaining=remaining,
      source_sha256=hashlib.sha256(source.encode()).hexdigest())

record = {'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'status': 'PASS' if all(row['passed'] for row in checks) else 'FAIL',
          'approval': 'v4-close-cleanup-owner-approval.json',
          'scope': 'Current compiled ABI and source checks; assembled-proxy execution remains separately required.',
          'checks': checks}
(art / 'approved-close-cleanup-surface.json').write_text(json.dumps(record, indent=2)+'\n')
for row in checks:
    print('PASS' if row['passed'] else 'FAIL', row['check'])
raise SystemExit(0 if record['status'] == 'PASS' else 1)
