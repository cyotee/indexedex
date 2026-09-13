"""Verify persisted local receipts against the live strict fork and retain calldata provenance."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import urllib.request
from Crypto.Hash import keccak

here = Path(__file__).resolve().parent
root = here.parents[2]
runtime = here.parent / 'current-robinhood-rehearsal-production-readiness-lifecycle-fixed'
architecture = json.loads((runtime / 'architecture-run.json').read_text())
assert architecture['status'] == 'PASS_REQUIRES_RECEIPT_AND_CODE_RECONCILIATION'
output = runtime / 'receipt-manifest.json'
assert not output.exists(), 'Preserve the prior receipt reconciliation.'
rpc_url = 'http://127.0.0.1:18665'

def rpc(method, params):
    assert method in ('eth_chainId', 'eth_getTransactionReceipt', 'eth_getTransactionByHash', 'eth_getCode', 'eth_getBlockByNumber')
    req = urllib.request.Request(rpc_url, data=json.dumps(
        {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode(),
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as response:
        result = json.load(response)
    assert 'error' not in result, 'Local RPC failure: ' + method
    return result['result']

def number(value):
    return int(value, 16) if isinstance(value, str) and value.startswith('0x') else int(value)

assert number(rpc('eth_chainId', [])) == 4663
catalog = json.loads((here / 'maintained-release-catalog.json').read_text())
required_stages = [stage for stage in catalog['stages']
                   if stage['local_rehearsal_action'] == 'FRESH_CORRECTED_DEPLOYMENT']
assert len(required_stages) == 19, 'Retain every onchain architecture catalog stage.'
stage_evidence = []
for stage in required_stages:
    path = runtime / 'broadcast' / Path(stage['script']).name / '4663/run-latest.json'
    assert path.is_file(), 'Missing architecture stage receipt file: ' + stage['script']
    saved = json.loads(path.read_text())
    assert saved.get('transactions') and saved.get('receipts'), 'No deployment receipts for ' + stage['script']
    stage_evidence.append({'phase': stage['phase'], 'stage': stage['stage'],
                           'broadcast_record': str(path.relative_to(root)),
                           'receipt_count': len(saved['receipts'])})
records = []
seen = set()
files = []
blocks = {}
for path in sorted((runtime / 'broadcast').rglob('run-latest.json')):
    if '/dry-run/' in str(path):
        continue
    data = json.loads(path.read_text())
    files.append({'path': str(path.relative_to(root)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    transactions = {t['hash'].lower(): t for t in data.get('transactions', []) if t.get('hash')}
    for saved in data.get('receipts', []):
        tx_hash = saved['transactionHash'].lower()
        if tx_hash in seen:
            continue
        seen.add(tx_hash)
        live = rpc('eth_getTransactionReceipt', [tx_hash])
        transaction = rpc('eth_getTransactionByHash', [tx_hash])
        assert live is not None and transaction is not None, 'Persisted transaction missing on local node.'
        assert number(live['status']) == number(saved['status']) == 1, 'Failed deployment receipt.'
        assert live['blockHash'] == saved['blockHash'], 'Receipt belongs to another fork state.'
        block_number = number(live['blockNumber'])
        assert block_number > 56118361, 'Only locally mined release transactions belong in this manifest.'
        if block_number not in blocks:
            block = rpc('eth_getBlockByNumber', [live['blockNumber'], False])
            assert number(block['gasLimit']) == 32000000
            blocks[block_number] = {'hash': block['hash'], 'gas_limit': number(block['gasLimit']), 'gas_used': number(block['gasUsed'])}
        assert number(live['gasUsed']) <= number(transaction['gas']) <= 32000000
        calldata = bytes.fromhex(transaction['input'].removeprefix('0x'))
        entry = transactions.get(tx_hash, {})
        records.append({
            'transaction_hash': tx_hash, 'block_number': block_number, 'block_hash': live['blockHash'],
            'sender': transaction['from'], 'to': transaction['to'], 'nonce': number(transaction['nonce']),
            'value': number(transaction['value']), 'gas_limit': number(transaction['gas']),
            'gas_used': number(live['gasUsed']), 'effective_gas_price': number(live['effectiveGasPrice']),
            'status': 1, 'contract_address': live['contractAddress'],
            'calldata_keccak256': '0x' + keccak.new(digest_bits=256, data=calldata).hexdigest(),
            'broadcast_record': str(path.relative_to(root)),
            'recorded_contract': entry.get('contractName'), 'recorded_function': entry.get('function'),
            'recorded_arguments': entry.get('arguments'),
            'additional_deployments': entry.get('additionalContracts', []),
        })
assert files and records, 'No local broadcast evidence found.'
report = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'status': 'PASS_LOCAL_RECEIPTS_AND_STRICT_BLOCK_LIMITS',
    'provenance': architecture['provenance'], 'rpc': rpc_url, 'public_broadcast': False,
    'transactions': records, 'broadcast_files': files, 'blocks': blocks,
    'required_catalog_stages': stage_evidence, 'all_19_catalog_stages_have_receipts': True,
    'transaction_count': len(records), 'total_gas_used': sum(r['gas_used'] for r in records),
    'max_transaction_gas_limit': max(r['gas_limit'] for r in records),
    'max_transaction_gas_used': max(r['gas_used'] for r in records),
    'actual_local_fee_wei': sum(r['gas_used'] * r['effective_gas_price'] for r in records),
    'limitations': 'These are actual isolated-fork legacy-fee costs, not a public funding quote. Full creation inputs are retained in the hashed broadcast files. Package/runtime/immutable/selector verification is recorded separately.',
}
output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({key: report[key] for key in ('status', 'transaction_count', 'total_gas_used', 'max_transaction_gas_limit', 'max_transaction_gas_used')}))
