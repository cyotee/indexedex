"""Move only the refactor delta, preserving independent changes in the main checkout."""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

source = Path('/private/tmp/indexedex-detf-funded-staking-impl')
destination = Path(__file__).resolve().parents[3]
records = Path(__file__).resolve().parent
base = 'e08b415733e729471779dcb8102529631330ea16'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=source)

def data(path):
    if path.is_symlink():
        return ('symlink', os.readlink(path).encode())
    if path.is_file():
        return ('file', path.read_bytes())
    if not path.exists():
        return None
    raise RuntimeError('Unexpected directory at file path: '+str(path))

def digest(value):
    return None if value is None else hashlib.sha256(value[0].encode()+b'\0'+value[1]).hexdigest()

tree = {}
for row in git('ls-tree', '-rz', base).split(b'\0'):
    if not row:
        continue
    meta, name = row.split(b'\t',1)
    mode, kind, oid = meta.split()
    tree[name.decode()] = (mode, kind, oid)

paths = set(git('diff', base, '--name-only', '-z', '--no-renames', '--ignore-submodules=all').decode().split('\0'))
paths.update(git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0'))
paths.discard('')
paths = sorted(name for name in paths if name != 'lib/crane' and not name.startswith('lib/crane/'))

rows = []
payloads = {}
for name in paths:
    if name in tree and tree[name][1] == b'commit':
        continue
    old = None
    if name in tree:
        mode, kind, oid = tree[name]
        old = ('symlink' if mode == b'120000' else 'file', git('cat-file','blob',oid.decode()))
    ours = data(source/name)
    theirs = data(destination/name)
    if ours == old:
        continue
    if ours == theirs:
        action = 'already matches'
    elif theirs == old:
        action = 'delete' if ours is None else 'copy'
    else:
        action = 'reconcile'
    rows.append({'path':name, 'action':action, 'base_sha256':digest(old),
                 'refactor_sha256':digest(ours), 'main_before_sha256':digest(theirs)})
    payloads[name] = (old, ours, theirs)

report = {'recorded_at_utc':datetime.now(timezone.utc).isoformat(), 'source':str(source),
          'destination':str(destination), 'refactor_base_commit':base,
          'counts':dict(Counter(row['action'] for row in rows)), 'rows':rows}
(records/'inventory.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report['counts'],indent=2),flush=True)
conflicts = [row['path'] for row in rows if row['action']=='reconcile']
if conflicts:
    print('Paths requiring three-way reconciliation:', json.dumps(conflicts,indent=2),flush=True)
if '--apply-clean' not in sys.argv:
    raise SystemExit(0)

backup = records/'main-before-transfer.tar.gz'
if backup.exists() and '--resume' not in sys.argv:
    raise RuntimeError('Backup already exists; inspect the recorded transfer instead of overwriting it.')
if not backup.exists():
    with tarfile.open(backup,'w:gz',dereference=False) as archive:
        for row in rows:
            p = destination/row['path']
            if p.exists() or p.is_symlink():
                archive.add(p,arcname=row['path'],recursive=False)

protected = []
for row in rows:
    name = row['path']; old, ours, theirs = payloads[name]
    target = destination/name
    if row['action']=='reconcile':
        staging = records/'reconcile'/name
        staging.parent.mkdir(parents=True,exist_ok=True)
        for label, value in [('base',old),('refactor',ours),('main',theirs)]:
            if value:
                Path(str(staging)+'.'+label).write_bytes(value[1])
        continue
    if row['action']=='already matches':
        continue
    if name.startswith(('.agents/', '.codex/')):
        protected.append(name)
        row['deferred']='Filesystem sandbox protects this directory; copy separately with escalation.'
        continue
    assert data(target)==theirs, 'Main checkout changed after analysis: '+name
    # Refuse writes through an external parent-directory symlink.
    assert target.parent.resolve().is_relative_to(destination), str(target)
    if row['action']=='delete':
        target.unlink()
    else:
        target.parent.mkdir(parents=True,exist_ok=True)
        if target.is_symlink():
            target.unlink()
        if ours[0]=='symlink':
            if target.exists():
                target.unlink()
            target.symlink_to(ours[1].decode())
        else:
            shutil.copy2(source/name,target)
    assert data(target)==ours,name
    row['applied']=True
    row['main_after_sha256']=digest(data(target))

report['status']='clean changes applied; reconcile listed overlaps' if conflicts else 'all refactor changes applied'
if protected:
    report['status']='all unprotected refactor changes applied; protected documentation remains'
    report['protected_paths']=protected
(records/'applied.json').write_text(json.dumps(report,indent=2)+'\n')
print(report['status'],flush=True)
