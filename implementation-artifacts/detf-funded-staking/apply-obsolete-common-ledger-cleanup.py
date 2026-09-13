"""Apply the already owner-approved cleanup after completed gold validation."""
from pathlib import Path
from datetime import datetime,timezone
import json,hashlib,shutil
from build_provenance import capture
art=Path(__file__).resolve().parent;root=art.parent.parent
prepared_path=art/'obsolete-common-ledger-cleanup-prepared.json';p=json.loads(prepared_path.read_text())
assert p['status']=='PREPARED_NOT_APPLIED'
run=json.loads((art/'hermetic-remediation-v4-gold-first-runtime.json').read_text())
assert run.get('finished_at_utc') and run['status']!='RUNNING'
diag=json.loads((art/'obsolete-common-ledger-draft-typecheck.json').read_text());assert diag['validation_passed']
for row in p['changes']:
 assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256'],row['path']
 assert hashlib.sha256((root/row['draft']).read_bytes()).hexdigest()==row['after_sha256'],row['path']
before=capture(root);archive=art/'before-obsolete-common-ledger-cleanup';archive.mkdir(exist_ok=False)
for row in p['changes']:
 target=archive/row['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/row['path'],target)
for name in ('obsolete-common-ledger-cleanup-prepared.json','current-implementation-queue.json','current-funded-storage-readers.json','retired-test-anchor-consolidation.json','current-test-consolidation.json'):
 shutil.copy2(art/name,archive/name)
for row in p['changes']:
 target=root/row['path']
 if row['action']=='delete':target.unlink()
 else:target.write_bytes((root/row['draft']).read_bytes())
after=capture(root)
for row in p['changes']:
 assert not (root/row['path']).exists() if row['action']=='delete' else hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['after_sha256']
p.update(status='APPLIED_RUNTIME_VALIDATION_PENDING',applied_at_utc=datetime.now(timezone.utc).isoformat(),application_record='obsolete-common-ledger-cleanup-applied.json');prepared_path.write_text(json.dumps(p,indent=2)+'\n')
record={'status':'APPLIED_RUNTIME_VALIDATION_PENDING','approval':p['approval'],'before_provenance':before,'after_provenance':after,'before_archive':str(archive.relative_to(root)),'changes':p['changes'],'removed_storage_members':p['removed_storage_members'],'validation_before_application':'obsolete-common-ledger-draft-typecheck.json','scope':p['scope']}
(art/'obsolete-common-ledger-cleanup-applied.json').write_text(json.dumps(record,indent=2)+'\n')
for name in ('obsolete-common-ledger-test-consolidation.json',):
 path=art/name;x=json.loads(path.read_text());x.update(status='APPLIED_RUNTIME_VALIDATION_PENDING',application_record='obsolete-common-ledger-cleanup-applied.json');path.write_text(json.dumps(x,indent=2)+'\n')
qpath=art/'current-implementation-queue.json';q=json.loads(qpath.read_text());q.update(active_forge_session=None,active_validation_parent_pid=None,solidity_frozen_until_session_exits=False,current_source_and_config_sha256=after['source_and_config_sha256'],in_validation=[]);q['authorized_dead_storage_followup'].update(status=p['status'],application_record=p['application_record']);qpath.write_text(json.dumps(q,indent=2)+'\n')
print(json.dumps({'status':record['status'],'files':len(p['changes']),'removed_fields':len(p['removed_storage_members']),'current_source':after['source_and_config_sha256']}))
