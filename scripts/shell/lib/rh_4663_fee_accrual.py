#!/usr/bin/env python3
"""Identity and receipt checks for the local and explicitly selected public runners."""
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

PACKAGE_MANIFESTS = {
    'uniswapV4Se': ('phase05_stage03_uniswap_v4_standard_exchange_pkg.json', 'uniV4SePkg'),
    'rebasingAwareErc4626': ('phase06_stage10_rebasing_aware_erc4626_pkg.json', 'rebasingAwareErc4626Pkg'),
    'rateProvider': ('phase05_stage01_se_rate_provider_pkg.json', 'rateProviderPkg'),
    'weightedHook': ('phase06_stage04_weighted_buffer_hook_pkg.json', 'weightedHookPkg'),
    'detf': ('phase06_stage07_uniswap_v4_detf_pkg.json', 'uniV4DetfPkg'),
}

def resolve_package_config(config, manifests):
    result = {**config, 'packages': {}}
    for key, (filename, field) in PACKAGE_MANIFESTS.items():
        manifest = manifests[filename]
        require(manifest['chainId'] == 4663, f'Wrong package manifest chain: {filename}')
        address = manifest[field]
        require_sender(address, address)  # Reject empty/zero/malformed package addresses.
        result['packages'][key] = address
    require_complete(result)
    return result

def require(condition, message):
    if not condition:
        raise ValueError(message)

class MissingStageError(ValueError):
    """Distinguish a new stage from a recorded stage whose receipts are invalid."""

def local_url(value):
    u = urllib.parse.urlsplit(value)
    require(u.scheme in ('http', 'https') and u.hostname in ('127.0.0.1', 'localhost', '::1')
            and u.port is not None and not u.username and not u.password,
            'Fee accrual requires an explicit loopback Anvil RPC')
    return value

def public_url(value):
    u = urllib.parse.urlsplit(value)
    require(u.scheme == 'https' and u.hostname and not u.username and not u.password,
            'Public fee accrual requires an HTTPS RPC without embedded credentials')
    return value

def require_sender(sender, expected):
    require(isinstance(sender, str) and len(sender) == 42 and sender.startswith('0x')
            and all(c in '0123456789abcdefABCDEF' for c in sender[2:])
            and int(sender[2:], 16) != 0, 'Set a valid DEPLOYER_ADDRESS')
    require(sender.lower() == expected.lower(), 'DEPLOYER_ADDRESS must match the configured staking owner')

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        raise ValueError('Deployment RPC redirects are forbidden')


def rpc(url, method, params=None):
    request = urllib.request.Request(url, json.dumps({
        'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params or []
    }).encode(), {'Content-Type': 'application/json', 'User-Agent': 'IndexedEx-deployment/1.0'})
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

def validate_script_transition(previous, current, transition):
    require({k: v for k, v in previous.items() if k != 'scriptSourceSha256'} ==
            {k: v for k, v in current.items() if k != 'scriptSourceSha256'},
            'Only the reviewed script update may change; network/config/core must match')
    require(previous['scriptSourceSha256'] == transition['from'] and
            current['scriptSourceSha256'] == transition['to'], 'Unreviewed script update')

def refresh_pre_migration_snapshot(journal, phase, remaining, principal):
    if any('migration' in item for item in journal['stages']):
        return
    require(phase == 0, 'Cannot adopt an unjournaled migration')
    previous = {key: journal[key] for key in ('initialReserve', 'initialPrincipal')}
    if previous != {'initialReserve': remaining, 'initialPrincipal': principal}:
        journal.setdefault('preMigrationSnapshots', []).append(previous)
    journal.update(initialReserve=remaining, initialPrincipal=principal, migrationStarted=True)

def identity(url, config, raw, public=False):
    require(config.get('version') == 1 and config.get('chainId') == 4663, 'Wrong config version/chain')
    require(int(rpc(url, 'eth_chainId'), 16) == 4663, 'Wrong RPC chain')
    if public:
        metadata = {'instanceId': 'public-4663'}
    else:
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
                source_root / 'scripts/foundry/anvil_robinhood_main/deploy_all.sh',
                source_root / 'scripts/shell/robinhood_main.sh']
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
    public = sys.argv[1:2] == ['--public']
    if public:
        del sys.argv[1]
    mode = sys.argv[1]
    url = (public_url if public else local_url)(os.environ['RPC_URL'])
    raw = Path(os.environ['FEE_ACCRUAL_CONFIG']).read_bytes()
    config = json.loads(raw)
    if public:
        require_sender(os.environ.get('DEPLOYER_ADDRESS'), config['stakingOwner'])
    if mode == 'ready':
        require_complete(config)
        for key, address in config['packages'].items():
            require(rpc(url, 'eth_getCode', [address, 'latest']) != '0x', f'Deploy prerequisite package through its existing stage: {key}')
    output = Path(os.environ['OUT_DIR_OVERRIDE']).resolve()
    if not public:
        require('.scratch' in output.parts, 'Fee accrual outputs must be isolated under .scratch')
    output.mkdir(parents=True, exist_ok=True)
    journal_path = output / 'fee-accrual-journal.json'
    current = identity(url, config, raw, public=public)
    if journal_path.exists():
        journal = json.loads(journal_path.read_text())
        if mode == 'reconcile-scripts':
            if journal['identity'] == current:
                print('Journal already uses the current scripts')
                return
            transition = json.loads(Path(__file__).with_name('rh_4663_fee_accrual_script_update.json').read_text())
            validate_script_transition(journal['identity'], current, transition)
            for entry in journal['stages']:
                for saved in entry['receipts']:
                    receipt = rpc(url, 'eth_getTransactionReceipt', [saved['transactionHash']])
                    require(receipt and int(receipt['status'], 16) == 1 and
                            receipt['blockHash'] == saved['blockHash'] and
                            receipt['blockNumber'] == saved['blockNumber'], 'Saved receipt mismatch')
                    block = rpc(url, 'eth_getBlockByNumber', [receipt['blockNumber'], False])
                    require(block['hash'] == receipt['blockHash'], 'Saved receipt is not canonical')
            backup = output / f'fee-accrual-journal.before-{transition["from"]}.json'
            require(not backup.exists(), 'Script-update backup already exists; inspect before continuing')
            write_json(backup, journal)
            journal.setdefault('scriptUpdates', []).append(transition)
            journal['identity'] = current
            write_json(journal_path, journal)
            print('Verified existing receipts and recorded reviewed script update; original journal backed up')
            return
        require(journal['identity'] == current, 'Network/config/scripts/core changed; reconcile before continuing')
    else:
        require(mode != 'reconcile-scripts', 'No existing journal to reconcile')
        journal = {'identity': current, 'stages': [], 'initialReserve': int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16),
                   'initialPrincipal': int(call(url, config['tokenStaking'], 'totalSupply()'), 16)}
    if mode in ('preflight', 'ready'):
        write_json(journal_path, journal)
        print('Verified network identity, existing core, owners and fee collector')
    elif mode == 'launch-config':
        # Package pins are resolved from confirmed receipts after their deployment.
        require_complete({**config, 'packages': {}})
        for expected in (config['managerOwner'], config['bootstrap']['actor']):
            require_sender(os.environ.get('DEPLOYER_ADDRESS'), expected)
        print('Verified launch decisions and DEPLOYER_ADDRESS for every signer role')
    elif mode == 'pin-packages':
        needed = {'05-01', '05-03', '06-01', '06-02', '06-04', '06-07', '06-10'}
        require(needed <= {item['stage'] for item in journal['stages']}, 'Missing confirmed package stages')
        for item in journal['stages']:
            for saved in item['receipts']:
                receipt = rpc(url, 'eth_getTransactionReceipt', [saved['transactionHash']])
                require(receipt and int(receipt['status'], 16) == 1 and receipt['blockHash'] == saved['blockHash'],
                        'Package receipt no longer matches')
                block = rpc(url, 'eth_getBlockByNumber', [receipt['blockNumber'], False])
                require(block['hash'] == receipt['blockHash'], 'Package receipt is not canonical')
        manifests = {filename: json.loads((output / filename).read_text())
                     for filename, _ in PACKAGE_MANIFESTS.values()}
        resolved = resolve_package_config(config, manifests)
        for address in resolved['packages'].values():
            require(rpc(url, 'eth_getCode', [address, 'latest']) != '0x', 'Resolved package has no code')
        destination = output / 'fee-accrual-config.resolved.json'
        if destination.exists():
            require(json.loads(destination.read_text()) == resolved, 'Resolved config changed; reconcile before continuing')
        else:
            write_json(destination, resolved)
        print(f'Confirmed package addresses exported to {destination}')
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
            chunks = quote.get('chunks', [quote])
            prior_migrations = [item for item in journal['stages'] if 'migration' in item]
            # Before cutover, ordinary deposits/withdrawals can change the reserve.
            # Establish the actual baseline from the first confirmed migration,
            # whose event must exactly match its fresh simulated reserve delta.
            previous_remaining = prior_migrations[-1]['reserveRemaining'] if prior_migrations else quote_uint(chunks[0]['beforeRemaining'])
            record['migration'] = verify_migration_events(events, chunks, target,
                                                         previous_remaining, record['reserveRemaining'])
            principal = int(call(url, config['tokenStaking'], 'totalSupply()'), 16)
            if not prior_migrations:
                require(principal == quote_uint(chunks[0]['principalBefore']), 'Principal changed since first migration quote')
                journal.setdefault('preMigrationSnapshots', []).append({key: journal[key] for key in ('initialReserve', 'initialPrincipal')})
                journal.update(initialReserve=previous_remaining, initialPrincipal=principal)
            require(principal == journal['initialPrincipal'], 'Principal weights changed during migration')
        journal['stages'].append(record)
        write_json(journal_path, journal)
        print(f'Confirmed {len(confirmed)} transaction receipts for {stage}')
    elif mode == 'stage-complete':
        records = [item for item in journal['stages'] if item['stage'] == sys.argv[2]]
        if not records:
            raise MissingStageError('Stage has no confirmed journal entry')
        for entry in records:
            for saved in entry['receipts']:
                receipt = rpc(url, 'eth_getTransactionReceipt', [saved['transactionHash']])
                require(receipt and int(receipt['status'], 16) == 1 and receipt['blockHash'] == saved['blockHash'], 'Stage receipt no longer matches')
        print('Confirmed prior stage receipts')
    elif mode == 'begin-migration':
        remaining = int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16)
        principal = int(call(url, config['tokenStaking'], 'totalSupply()'), 16)
        refresh_pre_migration_snapshot(journal, int(call(url, config['tokenStaking'], 'phase()'), 16), remaining, principal)
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
    except MissingStageError as error:
        print(f'Fee accrual stopped: {error}', file=sys.stderr)
        sys.exit(3)
    except Exception as error:
        print(f'Fee accrual stopped: {error}', file=sys.stderr)
        sys.exit(1)
