"""Refresh source declarations; compiled and assembled-proxy checks are separate."""
from pathlib import Path
import json,re,hashlib,datetime,subprocess
art=Path(__file__).resolve().parent;root=art.parent.parent
initial=json.loads((art/'source-manifest.json').read_text())
paths={r['path'] for r in initial}
roots=['contracts/vaults/detf/common','contracts/vaults/detf/protocols/dexes/uniswap/v4','contracts/vaults/standard/sy','contracts/fee/collector']
issuers=json.loads((art/'current-se-package-inventory.json').read_text())['rows']
roots+=sorted({str(Path(r['path']).parent) for r in issuers if r['disposition']=='in-scope SE share issuer'})
paths.update(subprocess.check_output(['rg','--files',*roots],cwd=root,text=True).splitlines())
rows=[]
def without_comments(s):
 return re.sub(r'//[^\n]*|/\*[\s\S]*?\*/',lambda m:'\n'*m[0].count('\n'),s)
for path in sorted(paths):
 p=root/path
 if p.suffix!='.sol':continue
 if '/slipstream/' in path:
  rows.append(dict(path=path,scope='D66_DEFERRED_PRESERVE_EXISTING',source_inventory='No unfinished release gate'));continue
 if '/vaults/detf/protocols/dexes/balancer/' in path:
  rows.append(dict(path=path,scope='D60_BALANCER_DETF_EXCLUDED',source_inventory='Compilation maintenance only'));continue
 if not p.exists():
  rows.append(dict(path=path,disposition='REMOVED_SINCE_INITIAL_SOURCE_INVENTORY'));continue
 text=p.read_text();s=without_comments(text);structs=[];fns=[]
 for m in re.finditer(r'\bstruct\s+(\w+)\s*\{([^}]+)\}',s):
  fields=[' '.join(f.split()) for f in m[2].split(';') if f.strip()]
  structs.append(dict(name=m[1],line=s.count('\n',0,m.start())+1,fields=fields))
 for m in re.finditer(r'\bfunction\s+(\w+)\s*\(([^)]*)\)\s*([^;{]*)',s):
  if not re.search(r'\b(public|external)\b',m[3]):continue
  fns.append(dict(name=m[1],parameters=' '.join(m[2].split()),qualifiers=' '.join(m[3].split()),line=s.count('\n',0,m.start())+1))
 rows.append(dict(path=path,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),scope='CURRENT_SOURCE',structs=structs,declared_public_functions=fns))
record=dict(recorded_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),method='Lexical source declarations and hashes, excluding comments. Not inherited ABI resolution or a storage alias/dataflow proof. Actual compiled/assembled proxy checks are separate.',initial_inventory='source-manifest.json is the preserved initial discovery inventory, not the current interface or storage specification.',rows=rows)
(art/'current-source-manifest.json').write_text(json.dumps(record,indent=2)+'\n')
(art/'source-manifest-provenance.json').write_text(json.dumps(dict(initial='source-manifest.json',current='current-source-manifest.json',active_funded_storage='current-funded-storage-readers.json',package_models='current-se-package-inventory.json',owner_approved_removed_surface='approved-close-cleanup-surface.json',note='Initial discovery rows containing retired selectors/fields are historical. Current records and explicit D60/D66 scope govern completion.'),indent=2)+'\n')
print('Current manifest rows:',len(rows))
