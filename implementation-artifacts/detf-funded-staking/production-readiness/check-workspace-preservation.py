"""Compare every captured task-start file; permit only explicitly reviewed edits.

New files are inventoried separately. This never changes or restores source.
"""
from datetime import datetime, timezone
import argparse
import hashlib
import json
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True)
args = parser.parse_args()
assert Path(args.output).name == args.output and args.output.endswith('.json')
output = here / args.output
assert not output.exists(), 'Preserve earlier workspace evidence.'
baseline = json.loads((here / 'owner-passing-baseline.json').read_text())
allowed = {
    'contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md': 'P6 documentation',
    'contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_VALIDATION_REPORT.md': 'P6 documentation',
    'contracts/vaults/detf/DETF_PRODUCTION_READINESS_REMAINING_IMPLEMENTATION_PLAN.md': 'P0-P6 tracker',
    'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol': 'PR-01/02 final payout and self-leg dust',
    'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol': 'PR-09 zero-LP residual termination',
    'contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol': 'PR-10 full precision NAV',
    'scripts/foundry/anvil_robinhood_main/Phase_06_Stage_09_BalancerStableBufferHookPkg.sol': 'PR-08 required facet wiring',
    'scripts/foundry/anvil_robinhood_main/Phase_09_Stage_01_ExportFrontend.s.sol': 'PR-05 isolated exports',
    'scripts/foundry/anvil_robinhood_main/README.md': 'PR-05/06/07 operator instructions',
    'scripts/foundry/anvil_robinhood_main/Script_SimulateArchitecture.s.sol': 'PR-06 complete catalog simulation',
    'scripts/foundry/anvil_robinhood_main/deploy_all.sh': 'PR-06/07 quote path/fee mode and preserved fork cache',
    'test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol': 'Missing named import and LC-01 funded Quad growth prerequisite',
    'test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol': 'PR-01 fallback boundary regressions',
    'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Burn_H6.t.sol': 'PR-01/02 direct dust/payable regressions',
    'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Liquidity.t.sol': 'PR-10 direct and bounded NAV regressions',
}
missing, changed = [], []
for row in baseline['files']:
    path = root / row['path']
    if not path.is_file():
        missing.append(row['path'])
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != row['sha256']:
        changed.append({'path': row['path'], 'before_sha256': row['sha256'],
                        'current_sha256': digest, 'reviewed_disposition': allowed.get(row['path'])})
unexpected = [row['path'] for row in changed if row['reviewed_disposition'] is None]
record = {'checked_at_utc': datetime.now(timezone.utc).isoformat(),
          'baseline': 'owner-passing-baseline.json', 'task_start_files_checked': len(baseline['files']),
          'missing': missing, 'changed': changed, 'unexpected_changes': unexpected,
          'status': 'PASS_TASK_START_FILES_PRESERVED' if not missing and not unexpected else 'REVIEW_REQUIRED',
          'scope': __doc__, 'reviewed_allowlist': allowed,
          'crane_patch_evidence': 'production-and-launch-fixes.json'}
output.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({key: record[key] for key in ('status', 'task_start_files_checked', 'missing', 'unexpected_changes')}))
raise SystemExit(0 if not missing and not unexpected else 1)
