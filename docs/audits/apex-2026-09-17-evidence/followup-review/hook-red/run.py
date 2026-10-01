from pathlib import Path
import subprocess,sys,shlex,json,datetime
root=Path('/tmp/apex-review-accounting-red-run'); ev=root/'hook-red-evidence'
cmd=['python3','scripts/forge-artifacts.py','test']+(ev/'source-paths.txt').read_text().splitlines()
for test in (ev/'test-paths.txt').read_text().splitlines():cmd+=['--test-root',test]
cmd+=['--','--match-test','test_APEX008_(bufferedPretransfer|ratedRawLeg|identityLeg)','-vv']
(ev/'command.txt').write_text('cd '+shlex.quote(str(root))+'\n'+shlex.join(cmd)+'\n')
meta={'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':cmd}
with (ev/'hook-accounting-red.log').open('w') as out:
 p=subprocess.run(cmd,cwd=root,stdout=out,stderr=subprocess.STDOUT)
meta['exitCode']=p.returncode;meta['finishedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
(ev/'run.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps(meta));sys.exit(p.returncode)
