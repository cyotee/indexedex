"""Check the real shell quote helpers without running Forge or sending RPC calls."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import tempfile

here = Path(__file__).resolve().parent
root = here.parents[2]
shell = root / 'scripts/foundry/anvil_robinhood_main/deploy_all.sh'
simulation = root / 'scripts/foundry/anvil_robinhood_main/Script_SimulateArchitecture.s.sol'
catalog = root / 'scripts/shell/lib/rh_4663_stages.sh'
record_path = here / 'funding-quote-checks.json'
assert not record_path.exists(), 'Preserve prior evidence.'
source = shell.read_text()
functions = []
for name in ('strip_json_scalar', 'wei_to_eth', 'log_eip1559_fees',
             'wei_to_gwei', 'sum_dry_run_gas_limits', 'quote_simulate_funding'):
    match = re.search(r'^' + name + r'\(\) \{\n.*?^\}', source, re.M | re.S)
    assert match, name
    functions.append(match[0])
# Replace only logging and the external fee read, retaining actual quote/path/math code.
helpers = '\n'.join(functions) + '''
log_header() { printf '%s\\n' "$*"; }
log_info() { printf '%s\\n' "$*"; }
log_error() { printf '%s\\n' "$*" >&2; }
fetch_eip1559_fees() { FEE_BASE_WEI=100; FEE_PRIORITY_WEI=50; FEE_GAS_PRICE_WEI=150; }
'''
rows = []
with tempfile.TemporaryDirectory(prefix='indexedex-quote-check-') as directory:
    base = Path(directory)
    for label, override in (('absolute', str(base / 'isolated')),
                            ('relative', 'relative-broadcast'), ('default', None)):
        path = base / (override or 'broadcast') / 'Script_SimulateArchitecture.s.sol/4663/dry-run/run-latest.json'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({'transactions': [
            {'transaction': {'gas': '0x1d'}}, {'transaction': {'gas': '31'}}]}))
        env = os.environ.copy()
        env.update(REPO_ROOT=directory, CHAIN_ID='4663', RPC_URL='unused-local-test',
                   FOUNDRY_FORK_RPC_ALIAS='test-only-fees', FUND_ETH_BUFFER_BPS='2500')
        env.pop('FOUNDRY_BROADCAST', None)
        if override is not None:
            env['FOUNDRY_BROADCAST'] = override
        result = subprocess.run(['bash', '-euo', 'pipefail', '-c', helpers + '\nquote_simulate_funding'],
                                env=env, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        assert 'Simulated txs=2 gas_limit_sum=60' in result.stdout
        assert '(9000 wei)' in result.stdout and '(11250 wei)' in result.stdout
        rows.append({'case': label, 'exit_code': result.returncode, 'gas_limit_sum': 60,
                     'cost_wei': 9000, 'buffered_wei': 11250})
    for label, payload in (
        ('missing-file', None), ('empty', {'transactions': []}),
        ('missing-gas', {'transactions': [{'transaction': {}}]}),
        ('zero-gas', {'transactions': [{'transaction': {'gas': '0x0'}}]}),
        ('negative-gas', {'transactions': [{'transaction': {'gas': -1}}]}),
    ):
        path = base / 'invalid/Script_SimulateArchitecture.s.sol/4663/dry-run/run-latest.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        if payload is not None:
            path.write_text(json.dumps(payload))
        env['FOUNDRY_BROADCAST'] = str(base / 'invalid')
        result = subprocess.run(['bash', '-euo', 'pipefail', '-c', helpers + '\nquote_simulate_funding'],
                                env=env, text=True, capture_output=True)
        assert result.returncode != 0, label
        assert 'Recommended fund amount' not in result.stdout, label
        rows.append({'case': label, 'exit_code': result.returncode,
                     'incomplete_quote_rejected': True})
stages = subprocess.check_output(['bash', '-c', 'source "$1"; rh_catalog_rows', 'bash', str(catalog)], text=True)
required = []
for row in stages.splitlines():
    phase, stage = row.split()
    if 2 <= int(phase) <= 6:
        matches = list(simulation.parent.glob(f'Phase_{phase}_Stage_{stage}_*.sol'))
        matches = [p for p in matches if not p.name.endswith('.s.sol')]
        assert len(matches) == 1
        required.append(matches[0].stem)
actual = re.findall(r'(Phase_\d+_Stage_\d+_\w+)\.execute\(', simulation.read_text())
assert required == actual, {'required': required, 'actual': actual}
syntax = subprocess.run(['bash', '-n', str(shell)], capture_output=True)
assert syntax.returncode == 0
record = {'status': 'PASS', 'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'source_sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in (shell, simulation, catalog)},
          'cases': rows, 'catalog_phases_02_through_06_in_exact_order': required,
          'bash_syntax_exit_code': syntax.returncode,
          'scope': 'Actual quote helper path and arithmetic plus actual catalog membership; fee RPC stubbed only for deterministic arithmetic. Full current local simulation remains required.'}
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'status': 'PASS', 'quote_cases': len(rows), 'catalog_stages': len(required)}))
