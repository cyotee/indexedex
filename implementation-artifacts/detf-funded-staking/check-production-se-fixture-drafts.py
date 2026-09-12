"""Typecheck existing provider integrations with unapplied fixture changes."""
from pathlib import Path
import hashlib,json,subprocess,time

art=Path(__file__).resolve().parent
root=art.parent.parent
prepared=json.loads((art/'production-se-fixture-followups-prepared.json').read_text())
sources={}
for row in prepared['changes']:
    assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256']
    text=(root/row['draft']).read_text()
    assert hashlib.sha256(text.encode()).hexdigest()==row['after_sha256']
    sources[row['path']]={'content':text}
base='test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/'
tests=[base+'UniswapV4Detf_Cp_Univ3Se_ProductLaw.t.sol',
    base+'UniswapV4Detf_Cp_Univ4Se_ProductLaw.t.sol',base+'UniswapV4Detf_Cp_PonsV1Se_ProductLaw.t.sol',
    base+'UniswapV4Detf_Quad_PonsMix_ProductLaw.t.sol',base+'UniswapV4Detf_Weighted_MorphoMix_ProductLaw.t.sol',
    base+'UniswapV4Detf_Orbital_Univ4Se_ProductLaw.t.sol',
    base+'decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R6.t.sol',
    base+'decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P9_R6.t.sol',
    base+'decimals/UniswapV4Detf_Cp_PonsV1Se_ProductLaw_P18_R6.t.sol',
    base+'decimals/UniswapV4Detf_Quad_MorphoMix_ProductLaw_B_P9_R6.t.sol']
for path in tests:sources[path]={'content':(root/path).read_text()}
settings=json.loads((art/'script-base-main-compiler-input.json').read_text())['settings']
assert not settings.get('viaIR',False)
settings['outputSelection']={path:{'*':['abi']} for path in tests}
input_path=art/'production-se-fixture-draft-typecheck-input.json'
output_path=art/'production-se-fixture-draft-typecheck-output.json'
input_path.write_text(json.dumps({'language':'Solidity','sources':sources,'settings':settings}))
started=time.monotonic()
with input_path.open() as source,output_path.open('w') as output:
    result=subprocess.run([str(Path.home()/'.svm/0.8.35/solc-0.8.35'),'--standard-json','--base-path','.','--allow-paths','.'],
        cwd=root,stdin=source,stdout=output,stderr=subprocess.PIPE,text=True)
compiled=json.loads(output_path.read_text())
errors=[row['formattedMessage'] for row in compiled.get('errors',[]) if row['severity']=='error']
suites={name:sum(entry.get('type')=='function' and entry.get('name','').startswith('test') for entry in data['abi'])
    for contracts in compiled.get('contracts',{}).values() for name,data in contracts.items()}
record={'status':'DRAFT_TYPECHECK_ONLY_NOT_RUNTIME_VALIDATION','seconds':round(time.monotonic()-started,3),
    'exit_code':result.returncode,'errors':errors,'concrete_suites':suites,'compiled_methods':sum(suites.values()),
    'compiler_input_sha256':hashlib.sha256(input_path.read_bytes()).hexdigest(),
    'validation_passed':not errors and result.returncode==0 and len(suites)==len(tests),
    'canonical_sources_unchanged':all(hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256'] for row in prepared['changes'])}
(art/'production-se-fixture-draft-typecheck.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2),flush=True)
raise SystemExit(0 if record['validation_passed'] else 1)
