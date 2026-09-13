"""Exercise the real staged command builder without running Forge or RPC calls."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

here = Path(__file__).resolve().parent
root = here.parents[2]
source_path = root / 'scripts/foundry/anvil_robinhood_main/deploy_all.sh'
source = source_path.read_text()
record = here / 'staged-local-fee-checks.json'
assert not record.exists(), 'Preserve previous evidence.'
functions = []
for name in ('is_simulate_command', 'is_localhost_rpc', 'forge_script_base', 'run_stage'):
    functions.append(re.search(r'^' + name + r'\(\) \{\n.*?^\}', source, re.M | re.S)[0])
helpers = '\n'.join(functions) + '''
log_info() { :; }
log_success() { :; }
log_error() { :; }
run_forge_cmd() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "$@"; }
run_stage 'test stage' 'Example.s.sol'
'''
cases = []
for name, rpc, command, force_legacy, expected_legacy, broadcast in (
    ('local-staged', 'http://127.0.0.1:18663', 'all', '0', True, '--broadcast'),
    ('local-dry-run', 'http://localhost:18663', 'all', '0', True, ''),
    ('public-default', 'https://example.invalid', 'all', '0', False, '--broadcast'),
    ('explicit-legacy', 'https://example.invalid', 'all', '1', True, '--broadcast'),
    ('funding-quote', 'http://127.0.0.1:18664', 'simulate', '1', False, ''),
    ('stage-funding-quote', 'http://127.0.0.1:18664', 'stagesimulate', '1', False, ''),
):
    env = os.environ.copy()
    env.update(RPC_URL=rpc, COMMAND=command, FORGE_LEGACY=force_legacy,
               FORGE_GAS_PRICE='2000000000', FORGE_VERBOSITY='', SENDER='0x1234',
               BROADCAST_FLAG=broadcast, GAS_ESTIMATE_MULTIPLIER='120', FEE_PRIORITY_WEI='50')
    result = subprocess.run(['bash', '-euo', 'pipefail', '-c', helpers], env=env,
                            text=True, capture_output=True, check=True)
    commands = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(commands) == (2 if broadcast else 1), name
    for cmd in commands:
        assert cmd.count('--legacy') == int(expected_legacy), name
        assert cmd.count('--gas-price') == int(expected_legacy), name
        if expected_legacy:
            assert cmd[cmd.index('--gas-price') + 1] == '2000000000'
        if command in ('simulate', 'stagesimulate'):
            assert cmd[cmd.index('--priority-gas-price') + 1] == '50'
    if broadcast:
        assert commands[1][:len(commands[0])] == commands[0], name
        assert commands[1].count('--broadcast') == 1
    cases.append({'case': name, 'command_count': len(commands), 'legacy': expected_legacy, 'passed': True})
subprocess.run(['bash', '-n', str(source_path)], check=True)
record.write_text(json.dumps({'status': 'PASS', 'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
    'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(), 'cases': cases,
    'scope': 'Actual shell command builders; Forge and RPC were not executed. Local deployment and EIP-1559 funding simulation remain required.'}, indent=2) + '\n')
print(json.dumps({'status': 'PASS', 'cases': len(cases)}))
