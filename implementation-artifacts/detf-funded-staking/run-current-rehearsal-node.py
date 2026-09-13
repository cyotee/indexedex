"""Run an isolated, pinned, local-only Robinhood fork for current package validation."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import socket
import subprocess

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--label', help='Fresh evidence suffix; existing runs are never overwritten')
parser.add_argument('--port', type=int, default=18663, help='Loopback-only port; use a separate fresh port for a funding-quote fork')
args = parser.parse_args()
if args.label and not re.fullmatch(r'[a-z0-9][a-z0-9-]*', args.label):
    parser.error('--label must contain only lowercase letters, digits and hyphens')
if not 1024 <= args.port <= 65535:
    parser.error('--port must be between 1024 and 65535')
runtime = Path(__file__).resolve().parent / (
    'current-robinhood-rehearsal' + (f'-{args.label}' if args.label else '')
)
# Check every evidence path before starting or rewriting any record.
for name in ('node.json', 'anvil.log', 'anvil-state.json'):
    if (runtime / name).exists():
        parser.error(f'Preserving existing {runtime / name}; choose a fresh --label')
runtime.mkdir(exist_ok=True)
host, port = '127.0.0.1', args.port
probe = socket.socket()
assert probe.connect_ex((host, port)) != 0, 'Existing local server is preserved; do not replace it'
probe.close()
environment = os.environ.copy()
# Read simple dotenv values without evaluating shell code or printing credentials.
dotenv = root / '.env'
if dotenv.exists():
    for line in dotenv.read_text().splitlines():
        match = re.match(r'^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$', line)
        if match:
            value = match[2]
            if len(value) > 1 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            environment.setdefault(match[1], value)
alias = 'robinhood_mainnet_alchemy'
template = re.search(r'^' + re.escape(alias) + r'\s*=\s*"([^"]+)"\s*$', (root / 'foundry.toml').read_text(), re.M)[1]
url = re.sub(r'\$\{([^}]+)\}', lambda m: environment[m[1]], template)
assert url.startswith('https://robinhood-mainnet.g.alchemy.com/'), 'Unexpected fork endpoint'
fork_block = int('0x3584c59', 16)
command = [
    'anvil', '--host', host, '--port', str(port), '--chain-id', '4663',
    '--hardfork', 'prague', '--code-size-limit', '24576', '--gas-limit', '32000000',
    '--fork-url', url, '--fork-block-number', str(fork_block),
    '--compute-units-per-second', '330', '--fork-retry-backoff', '1000',
    '--cache-path', str(runtime / 'rpc-cache'), '--dump-state', str(runtime / 'anvil-state.json'),
    '--disable-min-priority-fee', '--quiet',
]
record = {
    'started_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'rpc': f'http://{host}:{port}', 'upstream_alias': alias, 'fork_block': fork_block,
    'chain_id': 4663, 'code_size_limit': 24576, 'block_gas_limit': 32000000,
    'status': 'starting; readiness must be verified separately',
    'scope': 'Isolated local fork; remote chain read-only. Existing saved rehearsal state and manifests preserved.',
}
log_path = runtime / 'anvil.log'
fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as log:
    with (runtime / 'node.json').open('x') as node_record:
        node_record.write(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record), flush=True)
    result = subprocess.run(command, cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT)
record['status'] = 'exited'
record['exit_code'] = result.returncode
(runtime / 'node.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'node_exit_code': result.returncode}), flush=True)
