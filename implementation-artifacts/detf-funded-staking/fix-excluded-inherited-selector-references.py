"""D60 compilation maintenance: name the interface that declares a selector.

Solidity permits inherited methods on contract values, but not on the derived
interface type for .selector / abi.encodeCall. Keep historical calls and checks.
"""
from pathlib import Path
import re,json,datetime,shutil
root=Path(__file__).resolve().parents[2]
art=Path(__file__).resolve().parent
for suffix in ('json','log'):
 shutil.copy2(art/('implementation-full-build.'+suffix),art/('full-build-inherited-selector-failure.'+suffix))
changes=[]
for path in (root/'test/foundry/spec/vaults/detf/protocols/dexes/balancer').rglob('*.sol'):
 source=path.read_text(); original=source
 for match in list(re.finditer(r'import\s*\{\s*(ILegacy\w+)\s+as\s+(\w+)\s*\}\s*from\s*[\"\']([^\"\']+)[\"\'];',source)):
  legacy,alias,location=match.groups(); base=(root/location).read_text()
  inheritance=re.search(r'interface\s+'+legacy+r'\s+is\s+(\w+)\s*\{',base)
  if not inheritance: continue
  parent=inheritance[1]
  imported=re.search(r'import\s*\{\s*'+parent+r'\s*\}\s*from\s*[\"\']([^\"\']+)[\"\'];',base)
  if not imported: continue
  parent_path=imported[1]
  if parent_path.startswith('.'): parent_path=str(((root/location).parent/parent_path).resolve().relative_to(root))
  parent_src=(root/parent_path).read_text()
  declaration=re.search(r'interface\s+'+parent+r'\b[^\{]*\{',parent_src)
  if not declaration: continue
  start=declaration.end(); depth=1;end=start
  while depth:
   if parent_src[end]=='{':depth+=1
   elif parent_src[end]=='}':depth-=1
   end+=1
  functions=set(re.findall(r'function\s+(\w+)\s*\(',parent_src[start:end-1]))
  methods=sorted(f for f in functions if re.search(r'\b'+alias+r'\.'+f+r'\b',source))
  if not methods:continue
  label=parent+'SelectorSource'
  for method in methods:source=re.sub(r'\b'+alias+r'\.'+method+r'\b',label+'.'+method,source)
  source=source.replace(match[0],match[0]+'\nimport {'+parent+' as '+label+'} from "'+parent_path+'";')
  changes.append({'source':str(path.relative_to(root)),'parent':parent_path,'methods':methods})
 if source!=original:path.write_text(source)
report={'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'APPLIED_AWAITING_FULL_BUILD','scope':'D60 compilation-only selector qualification; no function, argument, expectation or deployed surface changed','changes':changes}
(art/'excluded-inherited-selector-compatibility.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
