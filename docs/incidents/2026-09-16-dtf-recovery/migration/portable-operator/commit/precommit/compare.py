#!/usr/bin/env python3
import hashlib, json, os, stat
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator"
COMMON = "/Users/cyotee/Projects/indexedex/.git"
OUT = Path("/tmp/phase26-portable-operator-precommit")
PARENT = "137fa0c8749165087c7d1d0156788f58a1dbf1b8"
HEAD = Path("/tmp/phase26-commit-hash.txt").read_text().strip()
HELD = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas"

def guard(path):
    if path == HELD or path.startswith(HELD + "/"):
        raise SystemExit("refusing held09 " + path)

def perm_of(mode):
    return "0o" + format(mode & 0o777, "o")

def git_mode(mode):
    if stat.S_ISLNK(mode):
        return "120000"
    if stat.S_ISREG(mode):
        return "100755" if (mode & 0o111) else "100644"
    return "000000"

def kind_of(mode):
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISDIR(mode):
        return "dir"
    if stat.S_ISREG(mode):
        return "file"
    return "other"

def hash_file(path):
    guard(path)
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def walk(abs_root, rel_root):
    guard(abs_root)
    rows = []
    stack = [(abs_root, rel_root)]
    while stack:
        abs_path, rel = stack.pop()
        guard(abs_path)
        st = os.lstat(abs_path)
        mode = st.st_mode
        kind = kind_of(mode)
        row = {
            "path": rel, "kind": kind, "gitMode": git_mode(mode), "perm": perm_of(mode),
            "st_mode": mode, "size": st.st_size, "sha256": None, "target": None,
            "nlink": st.st_nlink, "childCount": None, "childrenSha256": None, "_abs": abs_path,
        }
        if kind == "symlink":
            target = os.readlink(abs_path)
            row["target"] = target
            row["sha256"] = hashlib.sha256(target.encode()).hexdigest()
            rows.append(row)
            continue
        if kind == "dir":
            names = sorted(os.listdir(abs_path), key=lambda name: name.encode())
            payload = "".join(name + "\n" for name in names).encode()
            row["childCount"] = len(names)
            row["childrenSha256"] = hashlib.sha256(payload).hexdigest()
            rows.append(row)
            for name in reversed(names):
                child_rel = name if rel == "" else rel + "/" + name
                stack.append((os.path.join(abs_path, name), child_rel))
            continue
        rows.append(row)
    return rows

def load_jsonl(name):
    text = (OUT / name).read_text()
    return [json.loads(line) for line in text.splitlines()] if text else []

def differ(before, after, keys):
    return [key for key in keys if before.get(key) != after.get(key)]

def main():
    print("rewalking", flush=True)
    walked = {}
    for rel, key in [("docs/incidents", "docs-incidents"), ("out", "out"), ("cache_forge", "cache_forge")]:
        rows = walk(os.path.join(WT, rel), rel)
        print(f"walked {key} {len(rows)}", flush=True)
        walked[key] = rows
    files = [row for rows in walked.values() for row in rows if row["kind"] == "file"]
    print(f"rehashing {len(files)}", flush=True)
    paths = [row["_abs"] for row in files]
    digests = []
    done = 0
    with ProcessPoolExecutor(max_workers=12) as pool:
        for digest in pool.map(hash_file, paths, chunksize=32):
            digests.append(digest)
            done += 1
            if done % 4000 == 0:
                print(f"rehashed {done}/{len(paths)}", flush=True)
    for row, digest in zip(files, digests):
        row["sha256"] = digest
    print("rehash complete", flush=True)

    report = {"head": HEAD, "parent": PARENT, "content": {}, "directories": {}, "additive": {}}
    mode_collapsed_would_hide = []
    for key in ["docs-incidents", "out", "cache_forge"]:
        cur_by = {row["path"]: row for row in walked[key]}
        content_before = load_jsonl(f"{key}.jsonl")
        dir_before = load_jsonl(f"{key}-dirs.jsonl")
        perm_before = load_jsonl(f"{key}-perms.jsonl")
        content_bad, missing = [], []
        for row in content_before:
            now = cur_by.get(row["path"])
            if now is None:
                missing.append(row["path"])
                continue
            bad = differ(row, now, ["kind", "gitMode", "perm", "st_mode", "size", "sha256", "target"])
            if bad:
                content_bad.append({"path": row["path"], "fields": bad, "before": {k: row[k] for k in bad}, "after": {k: now[k] for k in bad}})
            elif row["gitMode"] == now["gitMode"] and (row["perm"] != now["perm"] or row["st_mode"] != now["st_mode"]):
                mode_collapsed_would_hide.append(row["path"])
        dir_bad, dir_missing = [], []
        for row in dir_before:
            now = cur_by.get(row["path"])
            if now is None:
                dir_missing.append(row["path"])
                continue
            bad = differ(row, now, ["kind", "perm", "st_mode", "size", "nlink", "childCount", "childrenSha256"])
            if bad:
                dir_bad.append({"path": row["path"], "fields": bad, "before": {k: row.get(k) for k in bad}, "after": {k: now.get(k) for k in bad}})
        before_paths = {row["path"] for row in perm_before}
        additive = sorted(path for path in cur_by if path not in before_paths)
        report["content"][key] = {"rows": len(content_before), "missing": len(missing), "changed": len(content_bad), "samples": content_bad[:8]}
        report["directories"][key] = {"rows": len(dir_before), "missing": len(dir_missing), "changed": len(dir_bad), "samples": dir_bad[:8]}
        report["additive"][key] = {"count": len(additive), "samples": additive[:30]}
        print(key, "content_missing", len(missing), "content_changed", len(content_bad), "dir_missing", len(dir_missing), "dir_changed", len(dir_bad), "additive", len(additive), flush=True)

    old_indexes = json.loads((OUT / "indexes.json").read_text())
    foreign_changed = []
    own = None
    for before in old_indexes:
        guard(before["path"])
        st = os.lstat(before["path"])
        raw = open(before["path"], "rb").read()
        after = {"perm": perm_of(st.st_mode), "st_mode": st.st_mode, "size": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        same = all(before[k] == after[k] for k in after)
        if before["foreign"] and not same:
            foreign_changed.append({"path": before["path"], "before": before["sha256"], "after": after["sha256"], "beforeMode": before["st_mode"], "afterMode": after["st_mode"]})
        if before["own"]:
            own = {"before": {k: before[k] for k in ["path", "perm", "st_mode", "size", "sha256"]}, "after": after, "unchanged": same}
    report["indexes"] = {"total": len(old_indexes), "foreignCount": sum(1 for r in old_indexes if r["foreign"]), "foreignChanged": foreign_changed, "own": own}

    old_refs = load_jsonl("refs.jsonl")
    ref_changed, ref_missing = [], []
    for row in old_refs:
        if not os.path.lexists(row["path"]):
            ref_missing.append(row["path"])
            continue
        guard(row["path"])
        st = os.lstat(row["path"])
        if stat.S_ISLNK(st.st_mode):
            target = os.readlink(row["path"])
            digest = hashlib.sha256(target.encode()).hexdigest()
            size = st.st_size
            kind = "symlink"
        else:
            raw = open(row["path"], "rb").read()
            target = None
            digest = hashlib.sha256(raw).hexdigest()
            size = len(raw)
            kind = "file"
        if digest != row["sha256"] or size != row["size"] or st.st_mode != row["st_mode"] or perm_of(st.st_mode) != row["perm"] or kind != row["kind"] or target != row["target"]:
            ref_changed.append({"path": row["path"], "beforeSha256": row["sha256"], "afterSha256": digest, "beforeSize": row["size"], "afterSize": size, "beforeMode": row["st_mode"], "afterMode": st.st_mode, "perm": perm_of(st.st_mode)})
    report["refs"] = {"rows": len(old_refs), "missing": ref_missing, "changed": ref_changed}

    import subprocess
    env = os.environ.copy()
    env.update({"GIT_MASTER": "1", "GIT_OPTIONAL_LOCKS": "0", "GIT_PAGER": "cat", "PAGER": "cat"})
    show = subprocess.run(["git", "--no-pager", "show-ref"], cwd=WT, env=env, capture_output=True)
    old_show = (OUT / "show-ref.txt").read_bytes()
    old_lines = set(old_show.decode().splitlines())
    new_lines = set(show.stdout.decode().splitlines())
    report["showRef"] = {
        "beforeBytes": len(old_show), "beforeSha256": hashlib.sha256(old_show).hexdigest(),
        "afterBytes": len(show.stdout), "afterSha256": hashlib.sha256(show.stdout).hexdigest(),
        "linesBefore": old_show.count(b"\n"),
        "removed": sorted(old_lines - new_lines), "added": sorted(new_lines - old_lines),
    }
    host_before = json.loads((OUT / "host-deps.json").read_text())
    host_bad = []
    for row in host_before:
        abs_path = os.path.join(WT, row["path"])
        guard(abs_path)
        st = os.lstat(abs_path)
        target = os.readlink(abs_path)
        after = {
            "path": row["path"], "kind": "symlink", "perm": perm_of(st.st_mode), "st_mode": st.st_mode,
            "size": st.st_size, "ino": st.st_ino, "target": target,
            "sha256": hashlib.sha256(target.encode()).hexdigest(), "openedTarget": False,
        }
        if after != row:
            host_bad.append({"path": row["path"], "before": row, "after": after})
    crane = subprocess.run(["git", "--no-pager", "ls-files", "-s", "--", "lib/crane"], cwd=WT, env=env, capture_output=True)
    report["hostDeps"] = {"unchanged": not host_bad, "changed": host_bad}
    report["craneGitlink"] = crane.stdout.decode().strip()
    report["modeCollapsedWouldHide"] = mode_collapsed_would_hide
    report["held09WorktreeOpened"] = False
    report["commitDirExistedDuringCompare"] = (Path(WT) / "docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator/commit").exists()
    Path("/tmp/phase26-postcommit-compare.json").write_text(json.dumps(report, indent=2) + "\n")
    print("COMPARE_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
