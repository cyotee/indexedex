"""Record every current funded storage member and direct-source access anchors."""
from pathlib import Path
import re,json,hashlib,datetime
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking'
paths=[*sorted((r/'contracts/vaults/detf/common').rglob('*Repo.sol')),r/'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol']
paths=[p for p in paths if p.name!='DETFNFTVaultRepo.sol']
all_sources={p:p.read_text() for p in (r/'contracts').rglob('*.sol') if '/test/' not in str(p) and not p.name.startswith('TestBase')}
rows=[]
for p in paths:
 source=p.read_text();direct={q:s for q,s in all_sources.items() if q==p or str(p.relative_to(r)) in s}
 for struct in re.finditer(r'\bstruct\s+(\w+)\s*\{([^}]*)\}',source,re.S):
  if struct[1] not in ('Storage','Table'):continue
  members=[]
  for declaration in re.sub(r'//[^\n]*','',struct[2]).split(';'):
   declaration=' '.join(declaration.split())
   if not declaration:continue
   name=re.search(r'(\w+)\s*$',declaration)[1];anchors=[]
   for q,s in direct.items():
    function=''
    for line_no,line in enumerate(s.splitlines(),1):
     f=re.search(r'\bfunction\s+(\w+)\s*\(',line)
     if f:function=f[1]
     if not re.search(r'\.\s*'+re.escape(name)+r'\b',line):continue
     expression=re.sub(r'//.*','',line).strip()
     if not expression:continue
     writing=bool(re.search(r'\.\s*'+re.escape(name)+r'(?:\[[^\]]*\])?\s*(?:[+\-*/]?=(?!=)|\+\+|--)|delete\s+\S*\.'+re.escape(name)+r'\b',expression))
     anchors.append({'path':str(q.relative_to(r)),'line':line_no,'function':function,'access':'assignment/write' if writing else 'read or mutating accessor; inspect source','source':expression})
   members.append({'member':name,'declaration':declaration,'disposition':'RETAINED_ACTIVE_FUNDED_STORAGE','direct_source_references':anchors})
  rows.append({'repo':str(p.relative_to(r)),'sha256':hashlib.sha256(source.encode()).hexdigest(),'struct':struct[1],'members':members})
record={'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'Current core field inventory after owner-approved mature-close cleanup; runtime validation and final acceptance reconciliation remain pending.','method':'Every field in the four active funded Repo Storage structs and unified V4 Storage/Table. References are lexical direct-import production-source anchors, not a compiler alias/dataflow proof; accessor calls can write storage. The obsolete 17-member DETFNFTVaultRepo and its unused implementation/lifecycle cluster were removed after a repo-wide dependency audit; legacy interfaces required by excluded families remain. See obsolete-common-ledger-cleanup-applied.json. Prior removed/replaced claim fields are mapped in claim-storage-disposition.json.','rows':rows}
(a/'current-funded-storage-readers.json').write_text(json.dumps(record,indent=2)+'\n')
for row in rows:
 print(row['repo'].rsplit('/',1)[-1],row['struct'],len(row['members']),'fields',sum(not x['direct_source_references'] for x in row['members']),'without direct anchors')
