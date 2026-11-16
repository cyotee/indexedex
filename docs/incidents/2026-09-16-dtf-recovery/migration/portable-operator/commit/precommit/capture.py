#!/usr/bin/env python3
"""Read-only phase26 precommit inventory. Writes only under /tmp/phase26-portable-operator-precommit."""
import hashlib, json, os, stat, subprocess, sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator"
COMMON = "/Users/cyotee/Projects/indexedex/.git"
OWN = "dtf-migration-phase-26-portable-operator"
HELD = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas"
OUT = Path("/tmp/phase26-portable-operator-precommit")
COMMIT = Path(WT) / "docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator/commit"
SRC_JSON = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase26-portable-operator-commit-source.json"
PARENT = "137fa0c8749165087c7d1d0156788f58a1dbf1b8"

env = os.environ.copy()
env.update({"GIT_MASTER": "1", "GIT_OPTIONAL_LOCKS": "0", "GIT_PAGER": "cat", "PAGER": "cat"})

def guard(path: str) -> None:
    if path == HELD or path.startswith(HELD + "/"):
        raise SystemExit("refusing to open held09 worktree path: " + path)

def git(*args):
    return subprocess.run(["git", "--no-pager", *args], cwd=WT, env=env, capture_output=True)

def perm_of(mode: int) -> str:
    return "0o" + format(mode & 0o777, "o")

def git_mode(mode: int) -> str:
    if stat.S_ISLNK(mode):
        return "120000"
    if stat.S_ISREG(mode):
        return "100755" if (mode & 0o111) else "100644"
    return "000000"

def kind_of(mode: int) -> str:
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISDIR(mode):
        return "dir"
    if stat.S_ISREG(mode):
        return "file"
    return "other"

def sha_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()

def hash_file(path: str) -> str:
    guard(path)
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def blob_id(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()

def dumps(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))

def cmp_path(row):
    return row["path"].encode("utf-8")

CONTENT_KEYS = ["path", "kind", "gitMode", "perm", "st_mode", "size", "sha256", "target"]
PERM_KEYS = ["path", "kind", "perm", "st_mode", "size", "sha256", "target"]
DIR_KEYS = ["path", "kind", "perm", "st_mode", "size", "nlink", "childCount", "childrenSha256"]

def to_jsonl(rows, keys) -> str:
    ordered = sorted(rows, key=cmp_path)
    if not ordered:
        return ""
    return "".join(dumps({k: row[k] for k in keys}) + "\n" for row in ordered)

def walk(abs_root: str, rel_root: str):
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
            "path": rel,
            "kind": kind,
            "gitMode": git_mode(mode),
            "perm": perm_of(mode),
            "st_mode": mode,
            "size": st.st_size,
            "sha256": None,
            "target": None,
            "nlink": st.st_nlink,
            "childCount": None,
            "childrenSha256": None,
            "_abs": abs_path,
        }
        if kind == "symlink":
            target = os.readlink(abs_path)
            row["target"] = target
            row["sha256"] = sha_bytes(target.encode("utf-8"))
            rows.append(row)
            continue
        if kind == "dir":
            names = []
            with os.scandir(abs_path) as it:
                for entry in it:
                    names.append(entry.name)
            names.sort(key=lambda name: name.encode("utf-8"))
            payload = "".join(name + "\n" for name in names).encode("utf-8")
            row["childCount"] = len(names)
            row["childrenSha256"] = sha_bytes(payload)
            rows.append(row)
            for name in reversed(names):
                child_rel = name if rel == "" else rel + "/" + name
                stack.append((os.path.join(abs_path, name), child_rel))
            continue
        rows.append(row)
    return rows

def fill_hashes(rows):
    files = [row for row in rows if row["kind"] == "file"]
    print(f"hashing {len(files)} files", flush=True)
    if not files:
        return
    paths = [row["_abs"] for row in files]
    done = 0
    with ProcessPoolExecutor(max_workers=12) as pool:
        for path, digest in pool.map(hash_file, paths, chunksize=16):
            done += 1
            if done % 2000 == 0:
                print(f"hashed {done}/{len(files)}", flush=True)
    by_abs = {}
    # pool.map preserves order
    # recompute mapping from the returned pairs
    # The loop above discarded path association if hash_file returns only digest.
    raise SystemExit("internal: hash mapping rewritten below")

def main():
    if COMMIT.exists():
        raise SystemExit("commit/ already exists; capture must precede it")
    OUT.mkdir(parents=True, exist_ok=False)
    head = git("rev-parse", "HEAD")
    if head.returncode != 0 or head.stdout.decode().strip() != PARENT:
        raise SystemExit("HEAD is not the required parent: " + head.stdout.decode() + head.stderr.decode())
    branch = git("branch", "--show-current").stdout.decode().strip()
    if branch != "work/dtf-migration-phase-26-portable-operator":
        raise SystemExit("unexpected branch " + branch)

    accepted = json.loads(Path(SRC_JSON).read_text())
    identity = []
    for row in accepted["paths"]:
        path = Path(WT) / row["path"]
        guard(str(path))
        st = path.lstat()
        raw = path.read_bytes()
        digest = sha_bytes(raw)
        perm = st.st_mode & 0o777
        if digest != row["sha256"] or len(raw) != row["bytes"] or perm != row["permissionMode"] or not stat.S_ISREG(st.st_mode):
            raise SystemExit("source binding mismatch " + row["path"])
        in_head = git("cat-file", "-e", f"HEAD:{row['path']}").returncode == 0
        identity.append({
            "path": row["path"],
            "status": "modified" if in_head else "added",
            "bytes": len(raw),
            "acceptedSha256": row["sha256"],
            "currentSha256": digest,
            "permissionMode": perm,
            "perm": perm_of(st.st_mode),
            "st_mode": st.st_mode,
            "gitMode": git_mode(st.st_mode),
            "blob": blob_id(raw),
            "crlf": b"\r\n" in raw,
        })
    print("source identity bound", len(identity), flush=True)

    roots = [
        ("docs/incidents", "docs-incidents"),
        ("out", "out"),
        ("cache_forge", "cache_forge"),
    ]
    walked = {}
    for rel, key in roots:
        abs_root = os.path.join(WT, rel)
        guard(abs_root)
        st = os.lstat(abs_root)
        print(f"root {rel} mode={oct(st.st_mode)} kind={kind_of(st.st_mode)}", flush=True)
        if not stat.S_ISDIR(st.st_mode) or stat.S_ISLNK(st.st_mode):
            raise SystemExit(f"{rel} is not an ordinary directory")
        print(f"walking {rel}", flush=True)
        rows = walk(abs_root, rel)
        print(f"walked {rel} entries={len(rows)}", flush=True)
        walked[key] = rows

    all_files = [row for rows in walked.values() for row in rows if row["kind"] == "file"]
    print(f"hashing {len(all_files)} files", flush=True)
    paths = [row["_abs"] for row in all_files]
    digests = []
    done = 0
    with ProcessPoolExecutor(max_workers=12) as pool:
        for digest in pool.map(hash_file, paths, chunksize=32):
            digests.append(digest)
            done += 1
            if done % 2000 == 0:
                print(f"hashed {done}/{len(paths)}", flush=True)
    if len(digests) != len(all_files):
        raise SystemExit("hash count mismatch")
    for row, digest in zip(all_files, digests):
        row["sha256"] = digest
    print("hashing complete", flush=True)

    def emit(key, prefix):
        rows = walked[key]
        content = [row for row in rows if row["kind"] != "dir"]
        dirs = [row for row in rows if row["kind"] == "dir"]
        files = {
            f"{key}.jsonl": to_jsonl(content, CONTENT_KEYS),
            f"{key}-perms.jsonl": to_jsonl(rows, PERM_KEYS),
            f"{key}-dirs.jsonl": to_jsonl(dirs, DIR_KEYS),
        }
        return files, {
            "content": len(content),
            "permission": len(rows),
            "directories": len(dirs),
            "files": sum(1 for row in rows if row["kind"] == "file"),
            "symlinks": sum(1 for row in rows if row["kind"] == "symlink"),
            "other": sum(1 for row in rows if row["kind"] == "other"),
        }

    written = {}
    totals = {}
    mode_hist = {}
    for key, prefix in [("docs-incidents", "docs/incidents"), ("out", "out"), ("cache_forge", "cache_forge")]:
        files, counts = emit(key, prefix)
        totals[key] = counts
        for name, text in files.items():
            raw = text.encode("utf-8")
            (OUT / name).write_bytes(raw)
            written[name] = {"bytes": len(raw), "sha256": sha_bytes(raw), "lines": text.count("\n")}
        for row in walked[key]:
            sig = (row["kind"], row["gitMode"], row["perm"], row["st_mode"])
            mode_hist[str(sig)] = mode_hist.get(str(sig), 0) + 1

    # indexes
    index_paths = [os.path.join(COMMON, "index")]
    wt_root = os.path.join(COMMON, "worktrees")
    for name in sorted(os.listdir(wt_root), key=lambda n: n.encode()):
        idx = os.path.join(wt_root, name, "index")
        if os.path.exists(idx):
            index_paths.append(idx)
    indexes = []
    for path in index_paths:
        guard(path)
        st = os.lstat(path)
        if not stat.S_ISREG(st.st_mode) or stat.S_ISLNK(st.st_mode):
            raise SystemExit("index is not a regular file: " + path)
        raw = open(path, "rb").read()
        own = f"/worktrees/{OWN}/" in path
        indexes.append({
            "path": path,
            "foreign": not own,
            "own": own,
            "perm": perm_of(st.st_mode),
            "st_mode": st.st_mode,
            "size": len(raw),
            "sha256": sha_bytes(raw),
        })
    indexes.sort(key=lambda row: row["path"].encode())
    if sum(1 for row in indexes if row["own"]) != 1:
        raise SystemExit("expected exactly one own index")
    index_text = json.dumps(indexes, indent=2) + "\n"
    (OUT / "indexes.json").write_text(index_text)
    written["indexes.json"] = {"bytes": len(index_text.encode()), "sha256": sha_bytes(index_text.encode()), "count": len(indexes), "foreignCount": sum(1 for row in indexes if row["foreign"])}

    # refs: files under .git/refs, .git/HEAD, packed-refs, worktree HEADs. No reflogs.
    ref_rows = []
    def add_ref(path):
        guard(path)
        st = os.lstat(path)
        kind = kind_of(st.st_mode)
        row = {
            "path": path,
            "kind": kind,
            "perm": perm_of(st.st_mode),
            "st_mode": st.st_mode,
            "size": st.st_size,
            "sha256": None,
            "target": None,
        }
        if kind == "symlink":
            target = os.readlink(path)
            row["target"] = target
            row["sha256"] = sha_bytes(target.encode("utf-8"))
            row["size"] = st.st_size
        elif kind == "file":
            raw = open(path, "rb").read()
            row["size"] = len(raw)
            row["sha256"] = sha_bytes(raw)
        else:
            raise SystemExit("unexpected ref kind " + path)
        ref_rows.append(row)
    def walk_refs(abs_path):
        guard(abs_path)
        st = os.lstat(abs_path)
        if stat.S_ISLNK(st.st_mode):
            add_ref(abs_path)
            return
        if stat.S_ISDIR(st.st_mode):
            for name in sorted(os.listdir(abs_path), key=lambda n: n.encode()):
                walk_refs(os.path.join(abs_path, name))
            return
        if stat.S_ISREG(st.st_mode):
            add_ref(abs_path)
    walk_refs(os.path.join(COMMON, "refs"))
    add_ref(os.path.join(COMMON, "HEAD"))
    packed = os.path.join(COMMON, "packed-refs")
    if os.path.exists(packed):
        add_ref(packed)
    for name in sorted(os.listdir(wt_root), key=lambda n: n.encode()):
        head = os.path.join(wt_root, name, "HEAD")
        if os.path.exists(head):
            add_ref(head)
    ref_text = to_jsonl(ref_rows, ["path", "kind", "perm", "st_mode", "size", "sha256", "target"])
    (OUT / "refs.jsonl").write_bytes(ref_text.encode())
    written["refs.jsonl"] = {"bytes": len(ref_text.encode()), "sha256": sha_bytes(ref_text.encode()), "lines": ref_text.count("\n")}

    show = git("show-ref")
    if show.returncode != 0:
        raise SystemExit("show-ref failed " + show.stderr.decode())
    (OUT / "show-ref.txt").write_bytes(show.stdout)
    written["show-ref.txt"] = {"bytes": len(show.stdout), "sha256": sha_bytes(show.stdout), "lines": show.stdout.count(b"\n")}

    status = git("status", "--ignore-submodules=all", "--porcelain=v1")
    if status.returncode != 0:
        raise SystemExit(status.stderr.decode())
    (OUT / "status-before.txt").write_bytes(status.stdout)
    diff = git("diff", "--ignore-submodules=all")
    (OUT / "tracked-diff.txt").write_bytes(diff.stdout)
    written["tracked-diff.txt"] = {"bytes": len(diff.stdout), "sha256": sha_bytes(diff.stdout)}
    check = git("diff", "--ignore-submodules=all", "--check")
    (OUT / "whitespace-before.txt").write_bytes(f"exit {check.returncode}\n".encode() + check.stdout + check.stderr)

    # host dependencies: root and lib symlinks only. Do not open targets.
    host = []
    for rel_dir in [".", "lib"]:
        abs_dir = WT if rel_dir == "." else os.path.join(WT, rel_dir)
        guard(abs_dir)
        if not os.path.isdir(abs_dir) or os.path.islink(abs_dir):
            if rel_dir == "lib" and os.path.islink(abs_dir):
                st = os.lstat(abs_dir)
                target = os.readlink(abs_dir)
                host.append({
                    "path": "lib", "kind": "symlink", "perm": perm_of(st.st_mode), "st_mode": st.st_mode,
                    "size": st.st_size, "ino": st.st_ino, "target": target,
                    "sha256": sha_bytes(target.encode()), "openedTarget": False,
                })
            continue
        for name in sorted(os.listdir(abs_dir), key=lambda n: n.encode()):
            abs_path = os.path.join(abs_dir, name)
            if not os.path.islink(abs_path):
                continue
            guard(abs_path)
            st = os.lstat(abs_path)
            target = os.readlink(abs_path)
            rel = name if rel_dir == "." else rel_dir + "/" + name
            host.append({
                "path": rel, "kind": "symlink", "perm": perm_of(st.st_mode), "st_mode": st.st_mode,
                "size": st.st_size, "ino": st.st_ino, "target": target,
                "sha256": sha_bytes(target.encode()), "openedTarget": False,
            })
    host_text = json.dumps(host, indent=2) + "\n"
    (OUT / "host-deps.json").write_text(host_text)
    crane = git("ls-files", "-s", "lib/crane")
    ignore = git("check-ignore", "-v", "node_modules")
    attrs = git("check-attr", "filter", "--", *[row["path"] for row in identity])
    (OUT / "git-bindings.txt").write_bytes(crane.stdout + b"\n" + ignore.stdout + ignore.stderr + b"\n" + attrs.stdout)

    lsof = subprocess.run(["lsof", "-nP", "-iTCP:18575", "-sTCP:LISTEN"], capture_output=True)
    (OUT / "processes.txt").write_bytes(f"exit {lsof.returncode}\n".encode() + lsof.stdout + lsof.stderr)
    checkpoint = Path(WT) / ".omo-runtime/dtf-migration-portable/checkpoints"
    (OUT / "source-identity-before.json").write_text(json.dumps({
        "parent": PARENT,
        "branch": branch,
        "permissionModeMeaning": "decimal st_mode & 0o777; 420 is 0o644, not full lstat mode 33188",
        "paths": identity,
        "checkpointExists": checkpoint.exists(),
        "listenerExit": lsof.returncode,
    }, indent=2) + "\n")

    if COMMIT.exists():
        raise SystemExit("commit/ appeared during capture")
    summary = {
        "schema": "phase26-portable-operator-precommit-summary-v1",
        "parent": PARENT,
        "branch": branch,
        "held09WorktreeOpened": False,
        "commitDirExisted": False,
        "totals": totals,
        "modeDistinctions": mode_hist,
        "indexes": written["indexes.json"],
        "files": written,
        "selfDigest": "This summary does not claim its own raw SHA-256.",
    }
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("CAPTURE_COMPLETE", flush=True)
    print(json.dumps({"totals": totals, "indexes": written["indexes.json"], "refs": written["refs.jsonl"], "showRef": written["show-ref.txt"]}, indent=2), flush=True)

if __name__ == "__main__":
    main()
