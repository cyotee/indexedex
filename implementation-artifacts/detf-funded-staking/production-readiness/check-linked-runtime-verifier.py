import ast, hashlib, json, re, tempfile
from pathlib import Path
from Crypto.Hash import keccak
from datetime import datetime, timezone
checker=Path('implementation-artifacts/detf-funded-staking/production-readiness/inspect-rehearsal-core.py')
module=ast.parse(checker.read_text())
functions=ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name in ('compare','code_hash')],type_ignores=[])
checks=[]
with tempfile.TemporaryDirectory(prefix='release-runtime-check-') as tmp:
 root=Path(tmp); (root/'out').mkdir(); (root/'contracts').mkdir()
 a='0x'+'11'*20; lib='0x'+'22'*20
 def h(b): return '0x'+keccak.new(digest_bits=256,data=b).hexdigest()
 source=root/'contracts/Math.sol'; source.write_text('library Math {}')
 template='73'+'00'*20+'301400'; code=bytes.fromhex('73'+'22'*20+'301400')
 def artifact(name,text,refs={},sources={},target=None):
  d={'deployedBytecode':{'object':'0x'+text,'linkReferences':refs},'metadata':{'sources':sources,'settings':{'compilationTarget':target or {}}}}
  p=root/'out'/(name+'.sol'); p.mkdir(exist_ok=True); (p/(name+'.json')).write_text(json.dumps(d))
 artifact('Math',template,sources={'contracts/Math.sol':{'keccak256':h(source.read_bytes())}},target={'contracts/Math.sol':'Math'})
 refs={'contracts/Math.sol':{'Math':[{'start':1,'length':20},{'start':22,'length':20}]}}
 artifact('Facet','73'+'_'*40+'73'+'_'*40+'00',refs)
 codes={a:bytes.fromhex('73'+'22'*20+'73'+'22'*20+'00'),lib:code}
 env=dict(root=root,json=json,hashlib=hashlib,re=re,keccak=keccak,block='latest',rpc=lambda method,params:'0x'+codes[params[0]].hex())
 exec(compile(functions,str(checker),'exec'),env)
 compare=env['compare']
 def check(name,fn):
  assert fn(),name;checks.append({'name':name,'passed':True})
 check('recursively verifies linked bytecode and exact library self address',lambda:compare(a,'Facet')['status']=='MATCH')
 codes[lib]=code[:-1]+b'\x01'
 check('rejects changed linked library executable',lambda:compare(a,'Facet')['status']=='LINKED_LIBRARY_MISMATCH')
 codes[lib]=code
 source.write_text('library Math { /* changed */ }')
 check('rejects stale linked library source',lambda:compare(a,'Facet')['status']=='LINKED_LIBRARY_MISMATCH')
 source.write_text('library Math {}')
 def rejected(fn):
  try: fn()
  except AssertionError:return True
  return False
 codes[lib]=b'\x73'+bytes.fromhex('33'*20)+code[21:]
 check('rejects wrong library self guard address',lambda:rejected(lambda:compare(a,'Facet')))
 codes[lib]=code
 codes[a]=bytes.fromhex('73'+'22'*20+'73'+'33'*20+'00')
 check('rejects inconsistent repeated links',lambda:rejected(lambda:compare(a,'Facet')))
 codes[a]=bytes.fromhex('73'+'00'*20+'73'+'00'*20+'00')
 check('rejects zero linked library',lambda:rejected(lambda:compare(a,'Facet')))
 codes[a]=bytes.fromhex('73'+'22'*20+'73'+'22'*20+'00')
 artifact('Facet','73'+'_'*40+'73'+'_'*40+'00',{})
 check('rejects undeclared linker placeholders',lambda:compare(a,'Facet')['status']=='LINKED_LIBRARY_COMPARISON_REQUIRED')
 codes[a]=b'\x00'
 check('rejects runtime length mismatch before substitutions',lambda:compare(a,'Facet')['status']=='CODE_LENGTH_MISMATCH')
record={'status':'PASS_EIGHT_RUNTIME_VERIFIER_CHECKS','checked_at_utc':datetime.now(timezone.utc).isoformat(),'checker_sha256':hashlib.sha256(checker.read_bytes()).hexdigest(),'checks':checks,'scope':'Verifier regressions; additional to production tests, not counted as Solidity test cases.'}
p=checker.parent/'linked-runtime-verifier-checks.json';assert not p.exists();p.write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
