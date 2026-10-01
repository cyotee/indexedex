from pathlib import Path
import shlex,subprocess,json,datetime,sys
root=Path('/tmp/apex-review-accounting-red-run'); ev=root/'hook-red-evidence'
line=next(x for x in (ev/'hook-accounting-red.log').read_text().splitlines() if x.startswith('forge test '))
cmd=shlex.split(line)
(ev/'retry-command.txt').write_text('cd '+shlex.quote(str(root))+'\n'+shlex.join(cmd)+'\n')
meta={'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':cmd,'reason':'Prior artifact and test compiles succeeded. Retry exact test command outside sandbox after macOS reqwest NULL-object panic.'}
with (ev/'hook-accounting-red-unsandboxed.log').open('w') as out:
 p=subprocess.run(cmd,cwd=root,stdout=out,stderr=subprocess.STDOUT)
meta['exitCode']=p.returncode;meta['finishedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
(ev/'retry-run.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps({'exitCode':p.returncode,'log':str(ev/'hook-accounting-red-unsandboxed.log')}));sys.exit(p.returncode)
