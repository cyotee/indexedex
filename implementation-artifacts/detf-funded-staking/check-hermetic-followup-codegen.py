"""Catch code-generation failures in two actual suites without changing Forge state."""
from pathlib import Path
import hashlib,json,subprocess,time

art=Path(__file__).resolve().parent
root=art.parent.parent
changes=[]
sources={}
for name in ('stata-hermetic-followups-prepared.json','production-se-fixture-followups-prepared.json'):
    record=json.loads((art/name).read_text())
    assert record['status']=='PREPARED_NOT_APPLIED'
    for row in record['changes']:
        assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256']
        text=(root/row['draft']).read_text()
        assert hashlib.sha256(text.encode()).hexdigest()==row['after_sha256']
        sources[row['path']]={'content':text};changes.append(row)
tests={
    'test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_Real.t.sol':'AaveV3StataStandardExchange_RealTest',
    'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ4Se_ProductLaw.t.sol':'UniswapV4Detf_Cp_Univ4Se_ProductLaw'}
for path in tests:sources.setdefault(path,{'content':(root/path).read_text()})
settings=json.loads((art/'script-base-main-compiler-input.json').read_text())['settings']
assert not settings.get('viaIR',False) and settings['optimizer']['enabled'] and settings['optimizer']['runs']==1
settings['outputSelection']={path:{name:['abi','evm.deployedBytecode.object']} for path,name in tests.items()}
input_path=art/'hermetic-followup-codegen-input.json'
output_path=art/'hermetic-followup-codegen-output.json'
input_path.write_text(json.dumps({'language':'Solidity','sources':sources,'settings':settings}))
started=time.monotonic()
with input_path.open() as source,output_path.open('w') as output:
    result=subprocess.run([str(Path.home()/'.svm/0.8.35/solc-0.8.35'),'--standard-json','--base-path','.','--allow-paths','.'],
        cwd=root,stdin=source,stdout=output,stderr=subprocess.PIPE,text=True)
compiled=json.loads(output_path.read_text())
errors=[row['formattedMessage'] for row in compiled.get('errors',[]) if row['severity']=='error']
suites={name:{'methods':sum(entry.get('type')=='function' and entry.get('name','').startswith('test') for entry in data['abi']),
    'test_container_runtime_bytes':len(data.get('evm',{}).get('deployedBytecode',{}).get('object',''))//2}
    for contracts in compiled.get('contracts',{}).values() for name,data in contracts.items()}
record={'status':'DRAFT_CODEGEN_ONLY_NOT_RUNTIME_VALIDATION','seconds':round(time.monotonic()-started,3),
    'exit_code':result.returncode,'errors':errors,'concrete_suites':suites,
    'compiler_input_sha256':hashlib.sha256(input_path.read_bytes()).hexdigest(),
    'validation_passed':not errors and result.returncode==0 and len(suites)==len(tests) and all(row['test_container_runtime_bytes']>0 for row in suites.values()),
    'canonical_sources_unchanged':all(hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256'] for row in changes)}
(art/'hermetic-followup-codegen.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2),flush=True)
raise SystemExit(0 if record['validation_passed'] else 1)
