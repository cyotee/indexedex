from pathlib import Path
import json,re,hashlib
root=Path('/tmp/apex-review-accounting-red-run'); ev=root/'hook-red-evidence'
log=(ev/'hook-accounting-red-unsandboxed.log').read_text()
rows=[];suite=None;in_failure_summary=False
for line in log.splitlines():
 if line.startswith('Failing tests:'):in_failure_summary=True
 if in_failure_summary:continue
 m=re.match(r'Ran \d+ tests? for (\S+):(\S+)',line)
 if m:suite={'file':m[1],'contract':m[2]}
 m=re.match(r'\[(PASS|FAIL)(?:: (.*))?\] (test_APEX008_\w+)\(\)',line)
 if m:rows.append({**(suite or {}),'status':m[1],'reason':m[2],'test':m[3]})
summary={'evidenceType':'RECONSTRUCTED_PRE_REVIEW_RED','tests':rows,'passed':sum(r['status']=='PASS' for r in rows),'failed':sum(r['status']=='FAIL' for r in rows),'compilerFinished': (ev/'hook-accounting-red.log').read_text().count('Solc 0.8.35 finished') == 2,'logSha256':hashlib.sha256((ev/'hook-accounting-red-unsandboxed.log').read_bytes()).hexdigest()}
summary['run']=json.loads((ev/'retry-run.json').read_text())
summary['buildAndInitialRun']=json.loads((ev/'run.json').read_text())
arts=[]
for p in ['out/UniswapV4StandardExchangeOrbitalBufferHookSeFacet.sol/UniswapV4StandardExchangeOrbitalBufferHookSeFacet.json','out/UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet.sol/UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet.json','out/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.json']:
 f=root/p;arts.append({'file':p,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'inode':f.stat().st_ino})
summary['rebuiltArtifacts']=arts
(ev/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
