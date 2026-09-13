"""Typecheck checked artifact drafts; never write canonical Solidity or Forge state."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, time

art=Path(__file__).resolve().parent
root=art.parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--label', required=True)
parser.add_argument('--prepared', action='append', required=True)
parser.add_argument('--test', action='append', default=[])
parser.add_argument('--codegen', action='store_true', help='Also generate bytecode under the unchanged repository compiler settings.')
args=parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+',args.label)
kind='codegen' if args.codegen else 'typecheck'
record_path=art/(args.label+'-draft-'+kind+'.json')
assert not record_path.exists(), 'Preserve diagnostic history; use a new label.'
sources={}; changes=[]
for name in args.prepared:
    record=json.loads((art/name).read_text())
    assert record['status']=='PREPARED_NOT_APPLIED'
    for row in record['changes']:
        assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256']
        text=(root/row['draft']).read_text()
        assert hashlib.sha256(text.encode()).hexdigest()==row['after_sha256']
        assert row['path'] not in sources, 'Overlapping draft must be reconciled explicitly.'
        sources[row['path']]={'content':text};changes.append(row)
tests={row['path'] for row in changes if row['path'].endswith('.t.sol')} | set(args.test)
for path in tests: sources.setdefault(path,{'content':(root/path).read_text()})
settings=json.loads((art/'script-base-main-compiler-input.json').read_text())['settings']
assert not settings.get('viaIR',False)
outputs=['abi','evm.deployedBytecode.object'] if args.codegen else ['abi']
settings['outputSelection']={path:{'*':outputs} for path in tests}
input_path=art/(args.label+'-draft-'+kind+'-input.json')
output_path=art/(args.label+'-draft-'+kind+'-output.json')
input_path.write_text(json.dumps({'language':'Solidity','sources':sources,'settings':settings}))
started=time.monotonic()
with input_path.open() as source,output_path.open('w') as output:
    result=subprocess.run([str(Path.home()/'.svm/0.8.35/solc-0.8.35'),'--standard-json','--base-path','.','--allow-paths','.'],
        cwd=root,stdin=source,stdout=output,stderr=subprocess.PIPE,text=True)
compiled=json.loads(output_path.read_text())
errors=[row['formattedMessage'] for row in compiled.get('errors',[]) if row['severity']=='error']
suites={name:sum(entry.get('type')=='function' and entry.get('name','').startswith('test') for entry in data['abi'])
    for contracts in compiled.get('contracts',{}).values() for name,data in contracts.items()}
record={'status':'DRAFT_'+kind.upper()+'_ONLY_NOT_RUNTIME_VALIDATION','seconds':round(time.monotonic()-started,3),
    'prepared_records':args.prepared,'exit_code':result.returncode,'errors':errors,
    'concrete_suites':suites,'compiled_methods':sum(suites.values()),
    'compiler_input_sha256':hashlib.sha256(input_path.read_bytes()).hexdigest(),
    'validation_passed':not errors and result.returncode==0 and bool(suites),
    'canonical_sources_unchanged':all(hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256'] for row in changes)}
if args.codegen:
    record['test_container_runtime_bytes']={name:len(data.get('evm',{}).get('deployedBytecode',{}).get('object',''))//2
        for contracts in compiled.get('contracts',{}).values() for name,data in contracts.items()}
    record['validation_passed']=record['validation_passed'] and all(
        record['test_container_runtime_bytes'][name]>0 for name,methods in suites.items() if methods)
record_path.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2),flush=True)
raise SystemExit(0 if record['validation_passed'] else 1)
