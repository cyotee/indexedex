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
    quoted_remaining = quote_uint(quotes[0]['beforeRemaining'])
    for event, raw_quote in zip(events, quotes):
        quote = {key: quote_uint(raw_quote[key]) for key in
                 ('amountIn', 'minClaimOut', 'beforeRemaining', 'afterRemaining')}
        require(event['topics'][1][-40:].lower() == target[2:].lower(), 'Migration event targets another DETF')
        data = bytes.fromhex(event['data'][2:])
        require(len(data) == 160, 'Unexpected migration event ABI')
        amount, detf_out, claim_out, shares_out, after = [int.from_bytes(data[i:i+32], 'big') for i in range(0, 160, 32)]
        require(amount == quote['amountIn'] and amount > 0, 'Migration input differs from simulation')
        require(detf_out > 0 and claim_out >= quote['minClaimOut'] > 0 and shares_out > 0, 'Migration output below limits')
        require(quote['beforeRemaining'] == quoted_remaining and
                quote['afterRemaining'] == quoted_remaining - amount,
                'Migration quote reserve delta mismatch')
        require(after == remaining - amount,
                'Migration reserve delta mismatch')
        quoted_remaining = quote['afterRemaining']
        remaining = after
        for key, value in zip(('amountIn', 'detfOut', 'claimOut', 'sharesOut'), (amount, detf_out, claim_out, shares_out)):
            totals[key] += value
    require(remaining == live_remaining, 'Migration final reserve differs from live balance')
    return totals


def verify_cutover_timestamp(timestamp, period_finish, last_update, earlier_events):
    # _beginMigration writes both timestamps exactly once, on the first migration.
    # A previous migration in the same block would have the same timestamp, so
    # explicitly reject earlier migration events in that block as well.
    require(timestamp == period_finish == last_update and not earlier_events,
            'Cannot adopt an unjournaled earlier migration')


def confirmed_cutover_reserve(url, staking, first_receipt, first_event, topic):
    block = rpc(url, 'eth_getBlockByNumber', [first_receipt['blockNumber'], False])
    require(block['hash'] == first_receipt['blockHash'], 'Cutover block is not canonical')
    index = int(first_receipt['transactionIndex'], 16)
    require(block['transactions'][index].lower() == first_receipt['transactionHash'].lower(),
            'Cutover transaction order mismatch')
    earlier_events = []
    for tx_hash in block['transactions'][:index]:
        receipt = rpc(url, 'eth_getTransactionReceipt', [tx_hash])
        require(receipt and receipt['blockHash'] == block['hash'], 'Missing cutover predecessor receipt')
        earlier_events.extend(log for log in receipt['logs'] if
                              log['address'].lower() == staking.lower() and log['topics'] and
                              log['topics'][0] == topic)
    verify_cutover_timestamp(int(block['timestamp'], 16),
                             int(call(url, staking, 'periodFinish()'), 16),
                             int(call(url, staking, 'lastUpdateTime()'), 16), earlier_events)
    data = bytes.fromhex(first_event['data'][2:])
    require(len(data) == 160, 'Unexpected migration event ABI')
    return int.from_bytes(data[:32], 'big') + int.from_bytes(data[-32:], 'big')


def recovery_needed(transactions, journal):
    require(transactions and all(tx.get('hash') for tx in transactions),
            'Incomplete broadcast record; reconcile partial submission separately')
    hashes = [tx['hash'].lower() for tx in transactions]
    require(len(set(hashes)) == len(hashes), 'Duplicate broadcast transaction')
    recorded = {r['transactionHash'].lower() for item in journal['stages'] for r in item['receipts']}
    seen = [tx_hash in recorded for tx_hash in hashes]
    require(not any(seen) or all(seen), 'Partially journaled batch; inspect before continuing')
    return not all(seen)


def verify_reverted_batch(transactions, receipt, live_tx, mined_nonce, pending_nonce):
    require(transactions and transactions[0].get('hash') and
            not any(tx.get('hash') for tx in transactions[1:]),
            'Failed-batch recovery requires only the first transaction to have been submitted')
    first = transactions[0]
    require(receipt and int(receipt['status'], 16) == 0 and not receipt.get('logs'),
            'Expected a confirmed reverted transaction')
    require(live_tx and receipt['transactionHash'].lower() == first['hash'].lower() == live_tx['hash'].lower(),
            'Failed transaction hash mismatch')
    expected = first['transaction']
    for field in ('from', 'to', 'input', 'nonce'):
        require(str(expected.get(field, '')).lower() == str(live_tx.get(field, '')).lower(),
                f'Failed broadcast {field} mismatch')
    nonce = int(live_tx['nonce'], 16)
    require(mined_nonce == pending_nonce == nonce + 1,
            'Later or pending sender transactions require separate reconciliation')
    for offset, tx in enumerate(transactions):
        require(int(tx['transaction']['nonce'], 16) == nonce + offset,
                'Failed batch nonce sequence mismatch')


def submitted_prefix(transactions):
    """A slow broadcast may contain a mined prefix and an unsubmitted suffix."""
    count = 0
    for tx in transactions:
        if not tx.get('hash'):
            break
        count += 1
    require(count > 0 and not any(tx.get('hash') for tx in transactions[count:]),
            'Missing or noncontiguous submitted migration transactions')
    require(len({tx['hash'].lower() for tx in transactions[:count]}) == count,
            'Duplicate submitted migration transaction')
    return count

def verify_successful_prefix(transactions, count, receipt, live_tx, mined_nonce, pending_nonce):
    """Prove the saved tail has not consumed or reserved a sender nonce."""
    require(0 < count < len(transactions) and submitted_prefix(transactions) == count,
            'Expected a successful submitted prefix and an unsent suffix')
    last = transactions[count - 1]
    require(receipt and int(receipt['status'], 16) == 1,
            'Expected a confirmed successful prefix')
    require(live_tx and receipt['transactionHash'].lower() == last['hash'].lower() == live_tx['hash'].lower(),
            'Successful prefix transaction hash mismatch')
    for field in ('from', 'to', 'input', 'nonce'):
        require(str(last['transaction'].get(field, '')).lower() == str(live_tx.get(field, '')).lower(),
                f'Successful prefix {field} mismatch')
    next_nonce = int(live_tx['nonce'], 16) + 1
    require(mined_nonce == pending_nonce == next_nonce,
            'Later or pending sender transactions require separate reconciliation')
    first_nonce = next_nonce - count
    for offset, tx in enumerate(transactions):
        require(int(tx['transaction']['nonce'], 16) == first_nonce + offset,
                'Interrupted batch nonce sequence mismatch')
        require(tx['transaction']['from'].lower() == live_tx['from'].lower() and
                tx['transaction']['to'].lower() == live_tx['to'].lower(),
                'Interrupted batch sender or target mismatch')


def recover_reverted_batch(url, config, journal, transactions, receipt, output):
    tx_hash = transactions[0]['hash']
    attempts = journal.get('failedMigrationAttempts', [])
    if any(item['transactionHash'].lower() == tx_hash.lower() for item in attempts):
        print('Reverted migration attempt already reconciled; next run will quote fresh transactions')
        return
    live_tx = rpc(url, 'eth_getTransactionByHash', [tx_hash])
    sender = config['stakingOwner']
    verify_reverted_batch(transactions, receipt, live_tx,
                          int(rpc(url, 'eth_getTransactionCount', [sender, 'latest']), 16),
                          int(rpc(url, 'eth_getTransactionCount', [sender, 'pending']), 16))
    require(live_tx['from'].lower() == sender.lower() and
            live_tx['to'].lower() == config['tokenStaking'].lower() and
            live_tx['input'][:10].lower() == subprocess.check_output(
                ['cast', 'sig', 'migrateToClaimVault(uint256,uint256,uint256)'], text=True).strip(),
            'Failed transaction is not the configured staking migration')
    block = rpc(url, 'eth_getBlockByNumber', [receipt['blockNumber'], False])
    require(block['hash'] == receipt['blockHash'], 'Failed receipt is not canonical')
    prior = [item for item in journal['stages'] if 'migration' in item]
    require(prior and int(call(url, config['tokenStaking'], 'phase()'), 16) == 1,
            'Failed-batch recovery requires an existing reconciled migration')
    remaining = int(call(url, config['tokenStaking'], 'reserveRemaining()'), 16)
    require(remaining == prior[-1]['reserveRemaining'], 'Staking reserve changed after the failed batch')
    require(int(call(url, config['tokenStaking'], 'totalSupply()'), 16) == journal['initialPrincipal'],
            'Principal weights changed after the failed batch')
    # Preserve the failed calldata/quotes before Forge replaces run-latest.json.
    quote = json.loads((output / 'phase08_stage07_staking_principal_migration.json').read_text())
    record = {'transactionHash': tx_hash, 'blockHash': receipt['blockHash'],
              'blockNumber': receipt['blockNumber'], 'status': 0, 'reserveRemaining': remaining,
              'transactions': transactions, 'quote': quote}
    journal.setdefault('failedMigrationAttempts', []).append(record)
    write_json(output / 'fee-accrual-journal.json', journal)
    print('Confirmed reverted migration: no reserve debit; unsent transactions discarded on fresh execution')


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
    elif mode in ('receipts', 'recover-migration'):
        if mode == 'recover-migration':
            stage = '08-07'
            path = output / 'broadcast/Phase_08_Stage_07_StakingPrincipalMigration.s.sol/4663/run-latest.json'
            if not path.exists():
                print('No migration broadcast to recover')
                return
        else:
            stage, path = sys.argv[2:4]
        broadcast = json.loads(Path(path).read_text())
        transactions = broadcast.get('transactions', [])
        require(transactions, 'No broadcast transactions; cannot certify a money/deployment stage')
        reverted = None
        interrupted = None
        if mode == 'recover-migration':
            count = submitted_prefix(transactions)
            last_receipt = rpc(url, 'eth_getTransactionReceipt', [transactions[count - 1]['hash']])
            require(last_receipt, 'Submitted migration transaction is still pending')
            if int(last_receipt['status'], 16) == 0:
                reverted = (transactions[count - 1:], last_receipt)
                failed_tx = rpc(url, 'eth_getTransactionByHash', [transactions[count - 1]['hash']])
                sender = config['stakingOwner']
                verify_reverted_batch(reverted[0], last_receipt, failed_tx,
                    int(rpc(url, 'eth_getTransactionCount', [sender, 'latest']), 16),
                    int(rpc(url, 'eth_getTransactionCount', [sender, 'pending']), 16))
                transactions = transactions[:count - 1]
            else:
                if count < len(transactions):
                    require(not broadcast.get('pending'), 'Broadcast records pending transactions; wait for confirmation')
                    live_tx = rpc(url, 'eth_getTransactionByHash', [transactions[count - 1]['hash']])
                    sender = config['stakingOwner']
                    require(live_tx and live_tx['from'].lower() == sender.lower() and
                            live_tx['to'].lower() == config['tokenStaking'].lower(),
                            'Successful prefix is not from the configured staking owner to staking')
                    verify_successful_prefix(transactions, count, last_receipt, live_tx,
                        int(rpc(url, 'eth_getTransactionCount', [sender, 'latest']), 16),
                        int(rpc(url, 'eth_getTransactionCount', [sender, 'pending']), 16))
                    interrupted = transactions
                    transactions = transactions[:count]
            if not transactions:
                recover_reverted_batch(url, config, journal, *reverted, output)
                return
        if mode == 'recover-migration' and not recovery_needed(transactions, journal):
            if reverted:
                recover_reverted_batch(url, config, journal, *reverted, output)
                return
            print('Migration broadcast already reconciled')
            return
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
            for field in ('from', 'to', 'input', 'nonce'):
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
            if reverted or interrupted:
                # Only the successful prefix debited reserves. Retain the full
                # original quote with the terminal failure record for diagnosis.
                chunks = chunks[:len(transactions)]
            if interrupted:
                # Archive the original prepared tail before the next Forge run
                # overwrites run-latest.json. Only confirmed events count below.
                record['interruptedBroadcast'] = {'transactions': interrupted, 'quote': quote,
                                                   'confirmedCount': len(transactions)}
            prior_migrations = [item for item in journal['stages'] if 'migration' in item]
            require(len(events) == len(live_receipts) == len(chunks), 'Expected one migration per transaction')
            # Staking remains open between simulation and the first mined call.
            # Prove this is the actual cutover, then use its receipt-backed reserve.
            # Quotes still constrain each input/output, but cannot freeze deposits.
            previous_remaining = (prior_migrations[-1]['reserveRemaining'] if prior_migrations else
                                  confirmed_cutover_reserve(url, config['tokenStaking'], live_receipts[0], events[0], topic))
            if prior_migrations:
                require(quote_uint(chunks[0]['beforeRemaining']) == previous_remaining,
                        'Migration quote starts from an unrecorded reserve')
            record['migration'] = verify_migration_events(events, chunks, target,
                                                         previous_remaining, record['reserveRemaining'])
            record['quotes'] = chunks
            principal = int(call(url, config['tokenStaking'], 'totalSupply()'), 16)
            if not prior_migrations:
                # The first migration freezes principal; use that frozen supply,
                # not the provisional simulation supply while users could exit.
                journal.setdefault('preMigrationSnapshots', []).append({key: journal[key] for key in ('initialReserve', 'initialPrincipal')})
                journal.update(initialReserve=previous_remaining, initialPrincipal=principal)
            require(principal == journal['initialPrincipal'], 'Principal weights changed during migration')
        journal['stages'].append(record)
        write_json(journal_path, journal)
        print(f'Confirmed {len(confirmed)} transaction receipts for {stage}')
        if interrupted:
            print('Recovered successful migration prefix; unsent tail will be freshly quoted from live balances')
        if reverted:
            recover_reverted_batch(url, config, journal, *reverted, output)
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
