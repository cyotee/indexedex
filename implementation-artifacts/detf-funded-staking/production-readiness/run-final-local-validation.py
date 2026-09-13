"""Continue the authorized local checks after explicit runtime reconciliation."""
from datetime import datetime, timezone
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, time
here=Path(__file__).resolve().parent
art=here.parent
root=art.parent.parent
sys.path.insert(0,str(art))
from build_provenance import capture, readiness_provenance_matches
parser=argparse.ArgumentParser();parser.add_argument('--resume-after-harness-import',action='store_true');parser.add_argument('--label');args=parser.parse_args()
if args.label:
 assert all(c.isalnum() or c=='-' for c in args.label) and args.label, 'Use a fresh simple evidence label.'
keys=('source_and_config_sha256','crane_head','crane_tracked_contract_and_config_diff_sha256','crane_source_and_config_sha256','forge_version')
provenance=capture(root)
core=json.loads((here/'corrected-local-core-and-packages.json').read_text())
assert core['current_release_checks_passed'] and readiness_provenance_matches(root,provenance,core['provenance'])
suffix='-'+args.label if args.label else ('-resume' if args.resume_after_harness_import else '')
record_path=here/('final-local-validation'+suffix+'.json')
assert not record_path.exists(), 'Preserve earlier validation evidence.'
record={'status':'RUNNING','provenance':provenance,'started_at_utc':datetime.now(timezone.utc).isoformat(),'steps':[],
 'predecessor':'production-readiness/post-build-release-core-final-resume5/run.json',
 'predecessor_stop_resolution':'Runtime checker now recursively validates deployed linked libraries and recognizes exact source-declared ERC721 replacement cuts. Both failed inspection records are preserved. Current read-only core inspection passed.',
 'runtime_inspection':'production-readiness/corrected-local-core-and-packages.json',
 'public_broadcast':False,'fund_migration':False}
def save():record_path.write_text(json.dumps(record,indent=2)+'\n')
save()
for name,script,args in [('local-receipts','record-local-release-receipts.py',[]),('local-lifecycle','run-local-release-rehearsal.py',['lifecycle']),('local-funding-quote','run-local-funding-quote.py',[])]:
 if suffix and name=='local-receipts':
  prior=json.loads((here/'final-local-validation.json').read_text());step=prior['steps'][0]
  assert step['name']==name and step['exit_code']==0 and not step['changed_fingerprints']
  assert readiness_provenance_matches(root,provenance,prior['provenance'])
  assert hashlib.sha256((root/step['log']).read_bytes()).hexdigest()==step['log_sha256']
  record['reused_receipt_check']=step;record['harness_import_reuse']='production-readiness/rehearsal-import-evidence-reuse.json';save();continue
 command=['python3',str(here/script),*args];log=here/('final-'+name+suffix+'.log');assert not log.exists()
 record['active_step']=name;save();print('Starting '+name,flush=True);started=time.monotonic()
 with log.open('x') as stream:r=subprocess.run(command,cwd=root,stdout=stream,stderr=subprocess.STDOUT)
 current=capture(root);changed=[k for k in keys if current[k]!=provenance[k]]
 record['steps'].append({'name':name,'command':command,'exit_code':r.returncode,'seconds':round(time.monotonic()-started,3),'changed_fingerprints':changed,'log':str(log.relative_to(root)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()});save();print(record['steps'][-1],flush=True)
 if r.returncode or changed:
  record.update(status='STOPPED_REQUIRES_REVIEW',finished_at_utc=datetime.now(timezone.utc).isoformat());save();raise SystemExit(1)
record.pop('active_step');record.update(status='PASS_ALL_LOCAL_RELEASE_CHECKS',finished_at_utc=datetime.now(timezone.utc).isoformat());save();print(record['status'],flush=True)
