"""Typecheck prepared fixtures in memory; never write canonical source or out/."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, subprocess, time

art = Path(__file__).resolve().parent
root = art.parent.parent
record = json.loads((art/'stata-hermetic-followups-prepared.json').read_text())
assert record['status'] == 'PREPARED_NOT_APPLIED'
sources = {}
for row in record['changes']:
    assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest() == row['before_sha256']
    text = (root/row['draft']).read_text()
    assert hashlib.sha256(text.encode()).hexdigest() == row['after_sha256']
    sources[row['path']] = {'content':text}
base = 'test/foundry/spec/protocol/lending/aave/v3.6/'
tests = [base+'AaveV3StataStandardExchange_Real.t.sol',
    base+'adversarial/Adversarial_AaveV3StataSE_SecurePull.t.sol']
for decimals in (6,9):
    tests += [base+f'decimals/AaveV3StataStandardExchange_Real_U{decimals}.t.sol',
        base+f'decimals/Adversarial_AaveV3StataSE_SecurePull_U{decimals}.t.sol']
for path in tests:
    sources.setdefault(path,{'content':(root/path).read_text()})
settings = json.loads((art/'script-base-main-compiler-input.json').read_text())['settings']
assert not settings.get('viaIR',False)
settings['outputSelection'] = {path:{'*':['abi']} for path in tests}
input_path = art/'stata-hermetic-draft-typecheck-input.json'
output_path = art/'stata-hermetic-draft-typecheck-output.json'
input_path.write_text(json.dumps({'language':'Solidity','sources':sources,'settings':settings}))
started = time.monotonic()
with input_path.open() as source, output_path.open('w') as output:
    result = subprocess.run([str(Path.home()/'.svm/0.8.35/solc-0.8.35'),'--standard-json',
        '--base-path','.','--allow-paths','.'],cwd=root,stdin=source,stdout=output,stderr=subprocess.PIPE,text=True)
compiled = json.loads(output_path.read_text())
errors = [row['formattedMessage'] for row in compiled.get('errors',[]) if row['severity']=='error']
suites = {name:len([entry for entry in data['abi'] if entry.get('type')=='function' and entry.get('name','').startswith('test')])
    for path, contracts in compiled.get('contracts',{}).items() for name,data in contracts.items()}
check = {'recorded_at_utc':datetime.now(timezone.utc).isoformat(),
    'status':'DRAFT_TYPECHECK_ONLY_NOT_RUNTIME_VALIDATION',
    'seconds':round(time.monotonic()-started,3),'exit_code':result.returncode,
    'errors':errors,'concrete_suites':suites,'compiled_methods':sum(suites.values()),
    'compiler_input_sha256':hashlib.sha256(input_path.read_bytes()).hexdigest(),
    'source_freeze_preserved':all(hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256'] for row in record['changes']),
    'validation_passed':not errors and result.returncode==0 and len(suites)==6}
(art/'stata-hermetic-draft-typecheck.json').write_text(json.dumps(check,indent=2)+'\n')
print(json.dumps(check,indent=2),flush=True)
raise SystemExit(0 if check['validation_passed'] else 1)
