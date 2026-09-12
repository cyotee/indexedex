"""Run the complete current default hermetic suite after a matching full build."""
from pathlib import Path
import json,subprocess,time
from build_provenance import capture, hermetic_environment
artifacts=Path(__file__).resolve().parent
checkout=artifacts.parent.parent
build=json.loads((artifacts/'implementation-full-build.json').read_text())
assert build['exit_code']==0, 'A successful full default build must precede this run.'
provenance=capture(checkout)
fingerprints = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
                'crane_source_and_config_sha256', 'forge_version')
for key in fingerprints:
 assert provenance[key] == build['provenance'][key], 'Build mismatch: ' + key
deferral_path=artifacts/'hermetic-pre-provider-deferral.json'
if deferral_path.exists():
 deferral=json.loads(deferral_path.read_text())
 if deferral.get('active') and deferral.get('source_and_config_sha256')==provenance['source_and_config_sha256']:
  deferral.update(status='DEFERRED_NOT_EXECUTED',executed_cases=0,validation_passed=False)
  deferral_path.write_text(json.dumps(deferral,indent=2)+'\n')
  print('Full hermetic run deferred until the prepared provider source fixes are applied. No tests executed or acceptance awarded.',flush=True)
  raise SystemExit(75)
environment,empty_rpc_keys=hermetic_environment(checkout)
command=['forge','test','--offline']
record={'command':command,'provenance':provenance,'scope':'Complete current default hermetic test suite; no test/family/path filters. The five baseline misplaced network sources now live in the fork tree under the recorded unchanged-source move/deduplication.','prior_full_build':'implementation-full-build.json','explicitly_empty_rpc_environment_keys':sorted(empty_rpc_keys)}
start=time.monotonic()
with (artifacts/'implementation-hermetic-test.log').open('w') as output:
 process=subprocess.Popen(command,cwd=checkout,env=environment,stdout=output,stderr=subprocess.STDOUT)
 record['pid']=process.pid;(artifacts/'implementation-hermetic-start.json').write_text(json.dumps(record,indent=2)+'\n')
 code=process.wait()
executed_cases=0
with (artifacts/'implementation-hermetic-test.log').open() as log:
 for line in log:
  if line.startswith('Failing tests:'):break
  executed_cases += line.startswith(('[PASS]', '[FAIL'))
record.update(exit_code=code,seconds=round(time.monotonic()-start,3),executed_cases=executed_cases,validation_passed=code==0 and executed_cases>0)
(artifacts/'implementation-hermetic-test.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'exit_code':code,'seconds':record['seconds']}),flush=True)
with (artifacts/'implementation-hermetic-test.log').open() as log:
 for line in log:
  if line.startswith('Ran ') and 'test suites in' in line:print(line.strip(),flush=True)
if code==0 and executed_cases==0:
 print('No executed test cases; refusing an empty validation result.',flush=True)
 code=1
raise SystemExit(code)
