"""Refresh only the existing V2 package ABI export from a current compiled artifact."""
from pathlib import Path
import json,re,hashlib,datetime
art=Path(__file__).resolve().parent;root=art.parent.parent
artifact=root/'out/UniswapV2StandardExchangeDFPkg.sol/UniswapV2StandardExchangeDFPkg.json'
compiled=json.loads(artifact.read_text());abi=compiled['abi']
ctor=next(x for x in abi if x['type']=='constructor')
fields=ctor['inputs'][0]['components']
assert any(x['name']=='uniswapV2StandardExchangeQueryFacet' for x in fields), 'Compile current V2 package first'
path=root/'frontend/apps/dtf/app/generated.js';s=path.read_text()
pattern=r'(exports\.uniswapV2StandardExchangeDfPkgAbi\s*=\s*)\[[\s\S]*?\n\];'
m=re.search(pattern,s);assert m,'Missing existing V2 package ABI export'
replacement=m[1]+json.dumps(abi,indent=4)+';'
t=s[:m.start()]+replacement+s[m.end():]
path.write_text(t)
record=dict(recorded_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_artifact=str(artifact.relative_to(root)),artifact_sha256=hashlib.sha256(artifact.read_bytes()).hexdigest(),target=str(path.relative_to(root)),before_sha256=hashlib.sha256(s.encode()).hexdigest(),after_sha256=hashlib.sha256(t.encode()).hexdigest(),scope='Existing V2 package ABI export only; deployment addresses and unrelated generated exports retained.',pkg_init_fields=[x['name'] for x in fields])
(art/'current-v2-package-abi-sync.json').write_text(json.dumps(record,indent=2)+'\n');print(record['target'],len(abi),'ABI entries')
