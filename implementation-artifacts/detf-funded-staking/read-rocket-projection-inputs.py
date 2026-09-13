"""Read actual Rocket Pool quote inputs on a pinned Ethereum block; no transactions."""
from pathlib import Path
from datetime import datetime, timezone
import json, os, urllib.request, argparse
from Crypto.Hash import keccak

art = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--block', default='24000000', help='Pinned block number or latest (resolved once before input reads).')
args = parser.parse_args()
block = None
url = 'https://eth-mainnet.g.alchemy.com/v2/' + os.environ['ALCHEMY_KEY']
storage = '0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46'
calls = []

def digest(value):
    return keccak.new(digest_bits=256, data=value.encode()).hexdigest()

def rpc(method, params):
    request = urllib.request.Request(url, data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(), headers={'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            result = json.load(response)
    except Exception as error:
        return {'transport_error_type':type(error).__name__}
    return {'rpc_error_code':result['error'].get('code')} if 'error' in result else result['result']

def call(target, signature, argument=''):
    raw = rpc('eth_call', [{'to':target,'data':'0x'+digest(signature)[:8]+argument}, block])
    words = [int(raw[i:i+64],16) for i in range(2,len(raw),64)] if isinstance(raw,str) and raw.startswith('0x') else []
    calls.append({'target':target,'signature':signature,'argument':argument,'raw':raw,'words':words})
    return words[0] if len(words)==1 else None

def resolve(name):
    value = call(storage,'getAddress(bytes32)',digest('contract.address'+name))
    assert value, 'Registered protocol address unavailable; endpoint omitted.'
    return '0x'+format(value,'040x')

chain = rpc('eth_chainId',[])
assert chain == '0x1', 'Wrong chain or unavailable read-only endpoint.'
block = rpc('eth_blockNumber',[]) if args.block == 'latest' else hex(int(args.block,0))
assert isinstance(block,str) and block.startswith('0x'), 'Pinned block unavailable.'
bindings = {name:resolve(name) for name in ['rocketDepositPool','rocketTokenRETH','rocketDAOProtocolSettingsDeposit','rocketDAOProtocolSettingsNetwork','rocketNetworkBalances','rocketMinipoolQueue']}
for name, signatures in {
    'rocketDepositPool':['version()','getBalance()','getMaximumDepositAmount()','getExcessBalance()'],
    'rocketTokenRETH':['getTotalCollateral()','getEthValue(uint256)','getRethValue(uint256)'],
    'rocketDAOProtocolSettingsDeposit':['getDepositEnabled()','getAssignDepositsEnabled()','getMinimumDeposit()','getDepositFee()','getMaximumDepositPoolSize()'],
    'rocketDAOProtocolSettingsNetwork':['getTargetRethCollateralRate()','getRethDepositDelay()'],
    'rocketNetworkBalances':['getTotalETHBalance()','getTotalRETHSupply()'],
    'rocketMinipoolQueue':['getEffectiveCapacity()']
}.items():
    for signature in signatures:
        call(bindings[name],signature,format(10**18,'064x') if '(uint256)' in signature else '')
balances = {name:rpc('eth_getBalance',[bindings[name],block]) for name in ['rocketTokenRETH']}
out = {'recorded_at_utc':datetime.now(timezone.utc).isoformat(),'block':int(block,16),'chain':chain,'broadcast':False,'bindings':bindings,'native_balances':balances,'calls':calls,'status':'PUBLIC_INPUT_READS_ONLY_NOT_PROJECTION_VALIDATION'}
filename = 'rocket-projection-input-preflight'+('' if int(block,16)==24_000_000 else '-'+str(int(block,16)))+'.json'
(art/filename).write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
