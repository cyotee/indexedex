"""Reconcile actual receipt-bound CREATE3 inputs and address calculations offline."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib,json
from Crypto.Hash import keccak
from eth_abi import decode
here=Path(__file__).resolve().parent;root=here.parents[2];runtime=here.parent/'current-robinhood-rehearsal-production-readiness-lifecycle-fixed'
receipts=json.loads((runtime/'receipt-manifest.json').read_text());assert receipts['status']=='PASS_LOCAL_RECEIPTS_AND_STRICT_BLOCK_LIMITS'
core=json.loads((runtime/'deployments/phase02_stage01_create3_factory.json').read_text())['create3Factory'].lower()
verified={r['transaction_hash']:r for r in receipts['transactions']}
def digest(b):return keccak.new(digest_bits=256,data=b).digest()
def raw(v):return bytes.fromhex(v.removeprefix('0x'))
proxy=bytes.fromhex('67363d3d37363d34f03d5260086018f3')
sigs={'deployFacet(bytes,bytes32)': ['bytes','bytes32'],'deployCanonicalFacet(bytes,bytes32)':['bytes','bytes32'],'create3(bytes,bytes32)':['bytes','bytes32'], 'deployPkg(bytes,bytes,bytes32)':['bytes','bytes','bytes32'],'deployPackageWithArgs(bytes,bytes,bytes32)':['bytes','bytes','bytes32'],'create3WithArgs(bytes,bytes,bytes32)':['bytes','bytes','bytes32'],'deployCanonicalPackageWithArgs(bytes,bytes,bytes32,bytes4)':['bytes','bytes','bytes32','bytes4']}
def typ(v):return '('+','.join(typ(c) for c in v['components'])+')'+v['type'][5:] if v['type'].startswith('tuple') else v['type']
def convert(v):
 if isinstance(v,bytes):return '0x'+v.hex()
 if isinstance(v,(list,tuple)):return [convert(x) for x in v]
 return v
rows=[];seen=set()
for file in receipts['broadcast_files']:
 p=root/file['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==file['sha256']
 for tx in json.loads(p.read_text())['transactions']:
  sig=tx.get('function');txid=tx.get('hash','').lower()
  if txid in seen:continue
  seen.add(txid)
  if sig not in sigs:continue
  data=raw(tx['transaction']['input']);assert digest(data).hex()==verified[txid]['calldata_keccak256'][2:]
  assert data[:4]==digest(sig.encode())[:4]
  args=decode(sigs[sig],data[4:]);creation=args[0];constructor=b'' if len(args)==2 else args[1];salt=args[1] if len(args)==2 else args[2]
  intermediate='0x'+digest(b'\xff'+raw(core)+salt+digest(proxy))[-20:].hex()
  predicted='0x'+digest(bytes.fromhex('d694')+raw(intermediate)+b'\x01')[-20:].hex()
  adds=tx['additionalContracts']
  if not adds:
   earlier=next(r for r in rows if r['address']==predicted)
   assert earlier['creation_code_keccak256']=='0x'+digest(creation).hex() and earlier['constructor_args']=='0x'+constructor.hex()
   rows.append(dict(earlier,transaction_hash=txid,entrypoint=sig,broadcast_record=file['path'],reused_existing_deployment=True,original_deployment_transaction=earlier['transaction_hash']))
   continue
  assert any(x['transactionType']=='CREATE2' and x['address'].lower()==intermediate and raw(x['initCode'])==proxy for x in adds)
  target=next(x for x in adds if x['transactionType']=='CREATE' and x['address'].lower()==predicted)
  assert raw(target['initCode'])==creation+constructor
  name=target['contractName'];paths=list((root/'out').glob('*.sol/'+name+'.json'));assert len(paths)==1
  artifact=json.loads(paths[0].read_text());ctor=next((x for x in artifact['abi'] if x['type']=='constructor'),{'inputs':[]})
  embedded = len(artifact['bytecode']['object'].removeprefix('0x')) // 2
  constructor_payload = constructor or creation[embedded:]
  decoded=decode([typ(x) for x in ctor['inputs']],constructor_payload) if constructor_payload else ()
  assert bool(constructor_payload)==bool(ctor['inputs']), (name, 'Constructor payload mismatch')
  rows.append({'contract':name,'address':predicted,'factory':core,'salt':'0x'+salt.hex(),'create2_intermediate':intermediate,'create3_proxy_creation_keccak256':'0x'+digest(proxy).hex(),'creation_code_keccak256':'0x'+digest(creation).hex(),'constructor_args':'0x'+constructor.hex(),'constructor_args_keccak256':'0x'+digest(constructor).hex(),'constructor_abi':ctor,'constructor_payload':'0x'+constructor_payload.hex(),'constructor_embedded_in_creation_input':bool(constructor_payload) and not bool(constructor),'decoded_constructor_args':convert(decoded),'transaction_hash':txid,'entrypoint':sig,'broadcast_record':file['path'],'artifact':str(paths[0].relative_to(root)),'artifact_sha256':hashlib.sha256(paths[0].read_bytes()).hexdigest(),'prediction_and_input_match':True})
assert len(rows)==135
record={'status':'PASS_ALL_135_CREATE3_DEPLOYMENT_INPUTS','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'provenance':receipts['provenance'],'method':'Decode persisted calldata verified against actual local receipts; independently derive CREATE2 trampoline and CREATE nonce-one target; match recorded full creation+constructor inputs. Runtime/source and linked library checks are separate.','rows':rows,'row_count':len(rows),'core_create2_prediction':'current-robinhood-rehearsal-production-readiness-lifecycle-fixed/architecture-run.json','hook_instance_flags_and_nonce':'Runtime hook factory/package flags are in corrected-local-core-and-packages.json; per-instance nonce mining is exercised by all binding lifecycle tests, and public instance activation remains separate.'}
out=here/'create3-deployment-inputs.json';assert not out.exists();out.write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
