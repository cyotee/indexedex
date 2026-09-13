"""Build the normal complete roots after the two-field maintained launch fix."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, os, subprocess, sys, time
here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture, hermetic_environment
record_path, log_path = here / 'pr08-script-build.json', here / 'pr08-script-build.log'
assert not record_path.exists() and not log_path.exists()
provenance = capture(root)
record = {'status':'RUNNING', 'provenance':provenance, 'command':['forge','build'], 'started_at_utc':datetime.now(timezone.utc).isoformat(), 'scope':'Normal complete production/test/script roots and warm default out/cache, no filters, no viaIR or coverage changes.'}
record_path.write_text(json.dumps(record,indent=2)+'\n')
env, cleared = hermetic_environment(root)
for key in ('FOUNDRY_CACHE_PATH','FOUNDRY_OUT'): env.pop(key,None)
record['cleared_rpc_environment_variable_names'] = cleared
start=time.monotonic()
with os.fdopen(os.open(log_path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'w') as log:
 result=subprocess.run(record['command'],cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
current=capture(root)
keys=('source_and_config_sha256','crane_head','crane_tracked_contract_and_config_diff_sha256','crane_source_and_config_sha256','forge_version')
record.update(exit_code=result.returncode,seconds=round(time.monotonic()-start,3),finished_at_utc=datetime.now(timezone.utc).isoformat(),sources_unchanged=all(current[k]==provenance[k] for k in keys),log_sha256=hashlib.sha256(log_path.read_bytes()).hexdigest())
record['status']='PASS_COMPLETE_NORMAL_BUILD' if result.returncode==0 and record['sources_unchanged'] else 'FAILED_REQUIRES_REVIEW'
record_path.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:record[k] for k in ('status','exit_code','seconds','sources_unchanged')}),flush=True)
raise SystemExit(0 if record['status']=='PASS_COMPLETE_NORMAL_BUILD' else 1)
