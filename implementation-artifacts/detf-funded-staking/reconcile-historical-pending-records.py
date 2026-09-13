"""Retire preparation records only when their corresponding application is recorded."""
from pathlib import Path
import json,datetime,hashlib
p=Path(__file__).resolve().parent;r=p.parent.parent;rows=[]
for f in sorted(p.glob('pending-*.json')):
 d=json.loads(f.read_text());twin=p/f.name.removeprefix('pending-')
 row={'preparation':f.name,'status':d.get('status')}
 if twin.exists():
  applied=json.loads(twin.read_text());status=applied.get('status','')
  if 'applied' in status.lower():
   d.setdefault('historical_preparation_status',d.get('status'))
   d['status']='HISTORICAL_PREPARATION_SUPERSEDED_BY_RECORDED_APPLICATION'
   d['application_record']=twin.name
   d['current_status_source']='current-implementation-queue.json and acceptance-progress.json; later edits and validation can supersede the original application hashes.'
   d['pending_owner_approval']=False
   f.write_text(json.dumps(d,indent=2)+'\n')
   row.update(status=d['status'],application=twin.name,application_status=status)
 rows.append(row)
report={'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'policy':'Preserve preparation payloads/hashes as historical evidence. A matching applied record resolves preparation status, not final acceptance; no application or validation result is inferred solely from a filename. Current engineering work and explicit approval are authoritative in the queue/approval/acceptance records.','rows':rows}
(p/'historical-pending-record-reconciliation.json').write_text(json.dumps(report,indent=2)+'\n')
for row in rows:
 if 'application' not in row:print(row)
print(sum('application' in row for row in rows),'historical preparation records linked to recorded applications')
