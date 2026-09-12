#!/usr/bin/env python3
"""Local-only identity and receipt checks for the existing Phase/Stage runner."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.parse
import urllib.request

CORE = {
    'create3Factory': '0xd7786b10bc8bc97dc7651cab7b97086c8b227882',
    'diamondPackageFactory': '0x976949ab55830fa4794bf40c88ea7d7567931003',
    'hookFactory': '0x8bb5fcc67e8cca44dc41dd08a5e2b2b392c22945',
    'indexedexManager': '0x09682b00d873d913ada0bb69b4d4c9631810d0bc',
    'feeCollector': '0x20af9a1e21a59a411cd3b0c40e70af9084770b2e',
    'tokenStaking': '0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00',
    'dtf': '0xee5576fa1bcaa380e591d01245f406f3f384eb01',
    'weth': '0x0bd7d308f8e1639fab988df18a8011f41eacad73',
}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def local_url(value):
    u = urllib.parse.urlsplit(value)
    require(u.scheme in ('http', 'https') and u.hostname in ('127.0.0.1', 'localhost', '::1')
            and u.port is not None and not u.username and not u.password,
            'Fee accrual requires an explicit loopback Anvil RPC')
    return value

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        raise ValueError('Anvil RPC redirects are forbidden')


def rpc(url, method, params=None):
    request = urllib.request.Request(url, json.dumps({
        'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params or []
    }).encode(), {'Content-Type': 'application/json'})
    with urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect()).open(request, timeout=60) as response:
        data = json.load(response)
    require('error' not in data, f'{method} failed: {data.get("error", {}).get("message", "RPC error")}')
    return data['result']

def call(url, address, signature):
    data = subprocess.check_output(['cast', 'calldata', signature], text=True).strip()
    return rpc(url, 'eth_call', [{'to': address, 'data': data}, 'latest'])

def write_json(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.replace(path)

def identity(url, config, raw):
    require(config.get('version') == 1 and config.get('chainId') == 4663, 'Wrong config version/chain')
    require(int(rpc(url, 'eth_chainId'), 16) == 4663, 'Wrong RPC chain')
    node = rpc(url, 'anvil_nodeInfo')
    require(node['environment']['chainId'] == 4663, 'Wrong Anvil chain')
    metadata = rpc(url, 'anvil_metadata')
    fork = metadata.get('forkedNetwork') or {}
    require(fork.get('forkBlockNumber') == config['forkBlockNumber'], 'Fork block mismatch')
    block = rpc(url, 'eth_getBlockByNumber', [hex(config['forkBlockNumber']), False])
    require(block['hash'].lower() == config['forkBlockHash'].lower(), 'Fork hash mismatch')
    fingerprints = {}
    for key, expected in CORE.items():
        require(config[key].lower() == expected, f'Reuse-only address mismatch: {key}')
        code = rpc(url, 'eth_getCode', [expected, 'latest'])
        require(code != '0x', f'Missing existing contract: {key}')
        fingerprints[key] = hashlib.sha256(bytes.fromhex(code[2:])).hexdigest()
    require(call(url, config['indexedexManager'], 'owner()')[-40:].lower() == config['managerOwner'][2:].lower(), 'Manager owner mismatch')
    require(call(url, config['tokenStaking'], 'owner()')[-40:].lower() == config['stakingOwner'][2:].lower(), 'Staking owner mismatch')
    require(call(url, config['indexedexManager'], 'feeTo()')[-40:].lower() == config['feeCollector'][2:].lower(), 'Fee collector mismatch')
    require(config['weights'] == {'detf': 60, 'weth': 20, 'dtf': 20}, 'Expected owner-selected 60/20/20 weights')
    source_root = Path(__file__).resolve().parents[3]
    digest = hashlib.sha256()
    sources = sorted((source_root / 'scripts/foundry/anvil_robinhood_main').glob('*.sol'))
    sources += [Path(__file__).resolve(), Path(__file__).with_name('rh_4663_stages.sh'),
                source_root / 'scripts/foundry/anvil_robinhood_main/deploy_all.sh']
    for source in sources:
        digest.update(str(source.relative_to(source_root)).encode())
        digest.update(source.read_bytes())
    return {'scriptSourceSha256': digest.hexdigest(), 'instanceId': metadata['instanceId'], 'configSha256': hashlib.sha256(raw).hexdigest(),
            'forkBlockNumber': config['forkBlockNumber'], 'forkBlockHash': config['forkBlockHash'],
            'coreCodeSha256': fingerprints}

def require_complete(value, path='config'):
    require(value is not None, f'Unresolved deployment decision: {path}')
    if isinstance(value, dict):
        for key, item in value.items():
            require_complete(item, f'{path}.{key}')
    elif isinstance(value, list):
        for index, item in enumerate(value):
            require_complete(item, f'{path}[{index}]')


def quote_uint(value):
    """Forge JSON encodes large uint256 values as decimal strings; never coerce floats/bools."""
    require(type(value) is int or (isinstance(value, str) and value.isascii() and value.isdecimal()),
            'Invalid integer in migration quote')
    result = int(value)
    require(0 <= result < 2**256, 'Migration quote integer out of range')
    return result


def verify_migration_events(events, quotes, target, before_remaining, live_remaining):
    """Reconcile each ordered chunk with its quote and the preceding confirmed debit."""
    require(events and len(events) == len(quotes), 'Migration event/quote count mismatch')
    totals = {'amountIn': 0, 'detfOut': 0, 'claimOut': 0, 'sharesOut': 0, 'chunks': len(events)}
    remaining = before_remaining
    for event, raw_quote in zip(events, quotes):
        quote = {key: quote_uint(raw_quote[key]) for key in
                 ('amountIn', 'minClaimOut', 'beforeRemaining', 'afterRemaining')}
        require(event['topics'][1][-40:].lower() == target[2:].lower(), 'Migration event targets another DETF')
        data = bytes.fromhex(event['data'][2:])
        require(len(data) == 160, 'Unexpected migration event ABI')
        amount, detf_out, claim_out, shares_out, after = [int.from_bytes(data[i:i+32], 'big') for i in range(0, 160, 32)]
        require(amount == quote['amountIn'] and amount > 0, 'Migration input differs from simulation')
        require(detf_out > 0 and claim_out >= quote['minClaimOut'] > 0 and shares_out > 0, 'Migration output below limits')
        require(quote['beforeRemaining'] == remaining and after == remaining - amount == quote['afterRemaining'],
                'Migration reserve delta mismatch')
        remaining = after
        for key, value in zip(('amountIn', 'detfOut', 'claimOut', 'sharesOut'), (amount, detf_out, claim_out, shares_out)):
            totals[key] += value
    require(remaining == live_remaining, 'Migration final reserve differs from live balance')
    return totals


def main():
    mode = sys.argv[1]
    url = local_url(os.environ['RPC_URL'])
    raw = Path(os.environ['FEE_ACCRUAL_CONFIG']).read_bytes()
    config = json.loads(raw)
    if mode == 'ready':
        require_complete(config)
        for key, address in config['packages'].items():
            require(rpc(url, 'eth_getCode', [address, 'latest']) != '0x', f'Deploy prerequisite package through its existing stage: {key}')
    output = Path(os.environ['OUT_DIR_OVERRIDE']).resolve()
    require('.scratch' in output.parts, 'Fee accrual outputs must be isolated under .scratch')
    output.mkdir(parents=True, exist_ok=True)
    journal_path = output / 'fee-accrual-journal.json'
    current = identity(url, config, raw)
    if journal_path.exists():
        journal = json.loads(journal_path.read_text())
        require(journal['identity'] == current, 'Anvil/config/core changed; use a new run directory')
    else:
        journal = {'identity': current, 'stages': [], 'initialReserve': int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16),
                   'initialPrincipal': int(call(url, config['tokenStaking'], 'totalSupply()'), 16)}
    if mode in ('preflight', 'ready'):
        write_json(journal_path, journal)
        print('Verified local Anvil identity, existing core, owners and fee collector')
    elif mode == 'receipts':
        stage, path = sys.argv[2:4]
        broadcast = json.loads(Path(path).read_text())
        transactions = broadcast.get('transactions', [])
        require(transactions, 'No broadcast transactions; cannot certify a money/deployment stage')
        confirmed = []
        live_receipts = []
        for tx in transactions:
            tx_hash = tx.get('hash')
            require(tx_hash, 'Unsubmitted transaction in broadcast record')
            receipt = rpc(url, 'eth_getTransactionReceipt', [tx_hash])
            require(receipt and int(receipt['status'], 16) == 1, 'Missing or failed receipt')
            live_tx = rpc(url, 'eth_getTransactionByHash', [tx_hash])
            require(live_tx is not None, 'Missing broadcast transaction')
            expected_tx = tx.get('transaction', {})
            for field in ('from', 'to', 'input'):
                expected_value = expected_tx.get(field)
                if expected_value is not None:
                    require(str(live_tx.get(field, '')).lower() == str(expected_value).lower(), f'Broadcast {field} mismatch')
            live_receipts.append(receipt)
            receipt_block = rpc(url, 'eth_getBlockByNumber', [receipt['blockNumber'], False])
            require(receipt_block['hash'] == receipt['blockHash'], 'Receipt is not on the current fork')
            confirmed.append({'transactionHash': tx_hash, 'blockHash': receipt['blockHash'], 'blockNumber': receipt['blockNumber']})
        record = {'stage': stage, 'receipts': confirmed,
            'reserveRemaining': int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16),
            'phase': int(call(url, config['tokenStaking'], 'phase()'), 16)}
        previous_hashes = {r['transactionHash'] for item in journal['stages'] for r in item['receipts']}
        require(not any(r['transactionHash'] in previous_hashes for r in confirmed), 'Receipt already journaled; no duplicate debit')
        if stage == '08-07':
            topic = subprocess.check_output(['cast', 'keccak', 'MigratedToClaimVault(address,uint256,uint256,uint256,uint256,uint256)'], text=True).strip()
            events = [log for receipt in live_receipts for log in receipt['logs']
                      if log['address'].lower() == config['tokenStaking'].lower() and log['topics'][0] == topic]
            quote = json.loads((output / 'phase08_stage07_staking_principal_migration.json').read_text())
            target = '0x' + call(url, config['tokenStaking'], 'targetDetf()')[-40:]
            previous_remaining = journal['stages'][-1]['reserveRemaining'] if journal['stages'] else journal['initialReserve']
            record['migration'] = verify_migration_events(events, quote.get('chunks', [quote]), target,
                                                         previous_remaining, record['reserveRemaining'])
            principal = int(call(url, config['tokenStaking'], 'totalSupply()'), 16)
            require(principal == journal['initialPrincipal'], 'Principal weights changed during migration')
        journal['stages'].append(record)
        write_json(journal_path, journal)
        print(f'Confirmed {len(confirmed)} transaction receipts for {stage}')
    elif mode == 'stage-complete':
        records = [item for item in journal['stages'] if item['stage'] == sys.argv[2]]
        require(records, 'Stage has no confirmed journal entry')
        for entry in records:
            for saved in entry['receipts']:
                receipt = rpc(url, 'eth_getTransactionReceipt', [saved['transactionHash']])
                require(receipt and int(receipt['status'], 16) == 1 and receipt['blockHash'] == saved['blockHash'], 'Stage receipt no longer matches')
        print('Confirmed prior stage receipts')
    elif mode == 'begin-migration':
        remaining = int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16)
        principal = int(call(url, config['tokenStaking'], 'totalSupply()'), 16)
        if not journal.get('migrationStarted'):
            require(not any('migration' in item for item in journal['stages']), 'Migration journal needs reconciliation')
            require(int(call(url, config['tokenStaking'], 'phase()'), 16) == 0, 'Cannot adopt an unjournaled migration')
            journal['initialReserve'] = remaining
            journal['initialPrincipal'] = principal
            journal['migrationStarted'] = True
            write_json(journal_path, journal)
        converted = sum(item.get('migration', {}).get('amountIn', 0) for item in journal['stages'])
        require(remaining + converted == journal['initialReserve'], 'Migration reserve changed outside recorded chunks')
        require(principal == journal['initialPrincipal'], 'Migration allocation weights changed')
        print('Migration starting/resuming from reconciled live balances')
    elif mode == 'remaining':
        print(int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16))
    elif mode == 'verify':
        require(int(call(url, config['tokenStaking'], 'phase()'), 16) == 2, 'Staking is not Wrapped')
        require(int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16) == 0, 'Unconverted DTF remains')
        chunks = [item['migration'] for item in journal['stages'] if 'migration' in item]
        require(chunks, 'No reconciled migration chunks in this run')
        require(sum(chunk['amountIn'] for chunk in chunks) == journal['initialReserve'], 'Converted DTF does not reconcile with initial principal/reward pool; inspect intervening activity')
        print('Verified Wrapped staking and receipt-backed conversion of the full initial DTF reserve')
    else:
        raise ValueError('Unknown fee-accrual check')

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'Fee accrual stopped: {error}', file=sys.stderr)
        sys.exit(1)
