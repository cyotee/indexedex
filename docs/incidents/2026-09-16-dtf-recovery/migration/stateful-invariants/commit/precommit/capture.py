#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import json
import os
import stat
import subprocess
from pathlib import Path

WT = Path("/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants")
GIT_COMMON = Path("/Users/cyotee/Projects/indexedex/.git")
OUT = Path("/tmp/phase24-precommit")
EVIDENCE = WT / "docs/incidents/2026-09-16-dtf-recovery/migration/stateful-invariants"
COMMIT_DIR = EVIDENCE / "commit"
OWN_GITDIR = GIT_COMMON / "worktrees/dtf-migration-phase-24-stateful-invariants"
EXPECTED_INDEX = "0aac78e6504612422343709283b720e3628f7e43a04df63575f91130d58000b0"
EXPECTED_HEAD = "55eb467bf493d97b2f10565b49be43816ab9dbabf035325d891b0b22a0dd23fe"
EXPECTED_REF = "1fc8fc83c08ffea454b82ae5312aa8a5ba769c5cd6ee1ab2520b9f3d423526fc"
PARENT = "15fd629375edeb361f6a39262795bdc66723ca3a"
HELD09_MARKERS = ("phase-09-deployment-gas", "held09", "held-09")

ENV = os.environ.copy()
ENV["GIT_MASTER"] = "1"
ENV["GIT_OPTIONAL_LOCKS"] = "0"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_mode(st: os.stat_result) -> str:
    if stat.S_ISLNK(st.st_mode):
        return "120000"
    if stat.S_ISREG(st.st_mode):
        return "100755" if (st.st_mode & 0o111) else "100644"
    return "000000"


def perm_oct(st: os.stat_result) -> str:
    return oct(st.st_mode & 0o777)


def kind_of(st: os.stat_result) -> str:
    if stat.S_ISDIR(st.st_mode):
        return "dir"
    if stat.S_ISLNK(st.st_mode):
        return "symlink"
    if stat.S_ISREG(st.st_mode):
        return "file"
    return "other"


def rel_posix(path: Path) -> str:
    return path.relative_to(WT).as_posix()


def dumps(obj: dict) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n"


def write_jsonl(name: str, rows: list[dict]) -> dict:
    raw = "".join(dumps(row) for row in rows).encode("utf-8")
    path = OUT / name
    path.write_bytes(raw)
    return {
        "file": name,
        "entries": len(rows),
        "bytes": len(raw),
        "sha256": sha256_bytes(raw),
    }


def forbidden(path: str) -> bool:
    return any(marker in path for marker in HELD09_MARKERS)


def allowed_git_meta(path: str) -> bool:
    return "/.git/" in path and (
        path.endswith("/index") or path.endswith("/HEAD") or "/refs/" in path or path.endswith("/packed-refs")
    )


def file_record(path: Path, *, absolute: bool = False) -> dict:
    text = str(path)
    if forbidden(text) and not allowed_git_meta(text):
        raise SystemExit(f"refusing held09 path: {text}")
    st = path.lstat()
    kind = kind_of(st)
    target = None
    digest = None
    if kind == "symlink":
        target = os.readlink(path)
        digest = sha256_bytes(target.encode("utf-8"))
    elif kind == "file":
        digest = sha256_file(path)
    record = {
        "path": text if absolute else rel_posix(path),
        "kind": kind,
        "mode": git_mode(st),
        "perm": perm_oct(st),
        "size": st.st_size,
        "sha256": digest,
        "st_mode": st.st_mode,
        "target": target,
    }
    return record


def walk(root: Path):
    files = []
    perms = []
    root_st = root.lstat()
    perms.append({
        "path": rel_posix(root),
        "kind": "dir",
        "perm": perm_oct(root_st),
        "size": root_st.st_size,
        "sha256": None,
    })
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        current = Path(dirpath)
        dirnames.sort()
        filenames.sort()
        for name in dirnames:
            child = current / name
            st = child.lstat()
            if stat.S_ISLNK(st.st_mode):
                target = os.readlink(child)
                files.append({
                    "path": rel_posix(child),
                    "kind": "symlink",
                    "mode": git_mode(st),
                    "size": st.st_size,
                    "sha256": sha256_bytes(target.encode("utf-8")),
                    "target": target,
                })
                perms.append({
                    "path": rel_posix(child),
                    "kind": "symlink",
                    "perm": perm_oct(st),
                    "size": st.st_size,
                    "sha256": sha256_bytes(target.encode("utf-8")),
                })
                continue
            if stat.S_ISDIR(st.st_mode):
                perms.append({
                    "path": rel_posix(child),
                    "kind": "dir",
                    "perm": perm_oct(st),
                    "size": st.st_size,
                    "sha256": None,
                })
        for name in filenames:
            child = current / name
            st = child.lstat()
            kind = kind_of(st)
            target = None
            digest = None
            if kind == "symlink":
                target = os.readlink(child)
                digest = sha256_bytes(target.encode("utf-8"))
            elif kind == "file":
                digest = sha256_file(child)
            files.append({
                "path": rel_posix(child),
                "kind": kind if kind != "dir" else "other",
                "mode": git_mode(st),
                "size": st.st_size,
                "sha256": digest,
                "target": target,
            })
            perms.append({
                "path": rel_posix(child),
                "kind": kind,
                "perm": perm_oct(st),
                "size": st.st_size,
                "sha256": digest,
            })
        if len(files) and len(files) % 1000 == 0:
            print(f"WALK {root.name} files={len(files)}", flush=True)
    files.sort(key=lambda row: row["path"])
    perms.sort(key=lambda row: row["path"])
    return files, perms


def git_bytes(args: list[str]) -> bytes:
    proc = subprocess.run(
        ["git", "-C", str(WT), *args],
        check=False,
        capture_output=True,
        env=ENV,
    )
    if proc.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} exit {proc.returncode}: {proc.stderr.decode('utf-8', 'replace')}")
    return proc.stdout


def main() -> None:
    if COMMIT_DIR.exists():
        raise SystemExit("commit directory already exists; refusing to capture after it")
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.iterdir():
        if old.is_file():
            old.unlink()

    index_before = file_record(OWN_GITDIR / "index", absolute=True)
    head_before = file_record(OWN_GITDIR / "HEAD", absolute=True)
    ref_before = file_record(
        GIT_COMMON / "refs/heads/work/dtf-migration-phase-24-stateful-invariants",
        absolute=True,
    )
    if index_before["sha256"] != EXPECTED_INDEX or index_before["size"] != 2073604:
        raise SystemExit(f"own index already diverges: {index_before}")
    if head_before["sha256"] != EXPECTED_HEAD:
        raise SystemExit(f"own HEAD already diverges: {head_before}")
    if ref_before["sha256"] != EXPECTED_REF:
        raise SystemExit(f"own ref already diverges: {ref_before}")

    summaries = []
    docs_files, docs_perms = walk(WT / "docs/incidents")
    summaries.append(write_jsonl("docs-incidents.jsonl", docs_files))
    summaries.append(write_jsonl("docs-incidents-perms.jsonl", docs_perms))
    print(f"DOCS files={len(docs_files)} perms={len(docs_perms)}", flush=True)

    out_files, _out_perms = walk(WT / "out")
    summaries.append(write_jsonl("out.jsonl", out_files))
    print(f"OUT files={len(out_files)}", flush=True)

    cache_files, _cache_perms = walk(WT / "cache_forge")
    summaries.append(write_jsonl("cache_forge.jsonl", cache_files))
    print(f"CACHE files={len(cache_files)}", flush=True)

    preservation = json.loads((EVIDENCE / "verification-r2/preservation-final.json").read_text())
    rows = []
    mismatches = []
    for check in preservation["checks"]:
        path = Path(check["path"])
        if forbidden(str(path)) and not allowed_git_meta(str(path)):
            mismatches.append({"path": str(path), "reason": "held09-blocked"})
            continue
        st = path.lstat()
        digest = sha256_file(path) if stat.S_ISREG(st.st_mode) else None
        row = {
            "path": str(path),
            "kind": kind_of(st),
            "mode": git_mode(st),
            "perm": perm_oct(st),
            "size": st.st_size,
            "sha256": digest,
            "st_mode": st.st_mode,
            "sealedSha256": check["sha256"],
            "sealedBytes": check["bytes"],
            "sealedMode": check["mode"],
            "sha256Matches": digest == check["sha256"],
            "bytesMatch": st.st_size == check["bytes"],
            "modeMatches": st.st_mode == check["mode"],
        }
        rows.append(row)
        if not (row["sha256Matches"] and row["bytesMatch"] and row["modeMatches"]):
            mismatches.append({"path": row["path"], "size": row["size"], "sha256": row["sha256"], "st_mode": row["st_mode"]})
    summaries.append(write_jsonl("preservation-rows.jsonl", rows))
    print(f"PRESERVATION rows={len(rows)} mismatches={len(mismatches)}", flush=True)

    indexes = []
    index_paths = [GIT_COMMON / "index"]
    worktrees = GIT_COMMON / "worktrees"
    if worktrees.is_dir():
        for child in sorted(worktrees.iterdir(), key=lambda p: p.name):
            index = child / "index"
            if index.is_file():
                index_paths.append(index)
    for index in index_paths:
        st = index.lstat()
        head = index.parent / "HEAD"
        head_text = head.read_text() if head.is_file() else None
        indexes.append({
            "path": str(index),
            "worktreeGitdir": index.parent.name if index.parent != GIT_COMMON else "main",
            "foreign": index != (OWN_GITDIR / "index"),
            "bytes": st.st_size,
            "mode": git_mode(st),
            "perm": perm_oct(st),
            "st_mode": st.st_mode,
            "sha256": sha256_file(index),
            "headFile": head.read_text() if head.is_file() else None,
        })
    foreign = [row for row in indexes if row["foreign"]]
    own = [row for row in indexes if not row["foreign"]]
    (OUT / "indexes.json").write_text(json.dumps({
        "count": len(indexes),
        "foreignCount": len(foreign),
        "ownCount": len(own),
        "encoding": "SHA-256 of raw index file bytes. Not git ls-files and not a decoded string.",
        "indexes": indexes,
    }, indent=2) + "\n")
    print(f"INDEXES total={len(indexes)} foreign={len(foreign)}", flush=True)

    refs = []
    refs_root = GIT_COMMON / "refs"
    for dirpath, dirnames, filenames in os.walk(refs_root, followlinks=False):
        dirnames.sort()
        filenames.sort()
        for name in filenames:
            child = Path(dirpath) / name
            st = child.lstat()
            if not stat.S_ISREG(st.st_mode):
                continue
            refs.append({
                "path": str(child),
                "kind": "file",
                "mode": git_mode(st),
                "perm": perm_oct(st),
                "size": st.st_size,
                "sha256": sha256_file(child),
                "st_mode": st.st_mode,
            })
    packed = GIT_COMMON / "packed-refs"
    if packed.is_file():
        st = packed.lstat()
        refs.append({
            "path": str(packed),
            "kind": "file",
            "mode": git_mode(st),
            "perm": perm_oct(st),
            "size": st.st_size,
            "sha256": sha256_file(packed),
            "st_mode": st.st_mode,
        })
    refs.sort(key=lambda row: row["path"])
    summaries.append(write_jsonl("refs.jsonl", refs))

    show_ref = git_bytes(["show-ref"])
    (OUT / "show-ref.txt").write_bytes(show_ref)
    print(f"REFS loose={len(refs)} show-ref-bytes={len(show_ref)}", flush=True)

    links = []
    for name in ("lib/crane", "node_modules"):
        path = WT / name
        st = path.lstat()
        target = os.readlink(path)
        links.append({
            "path": str(path),
            "target": target,
            "perm": perm_oct(st),
            "st_mode": st.st_mode,
            "size": st.st_size,
            "ino": st.st_ino,
            "sha256": sha256_bytes(target.encode("utf-8")),
        })

    membership = {}
    seal_specs = [
        ("implementation", EVIDENCE / "implementation", 22, "97d7df1bb3b21d7c17f272e48c73fe0e44e5a4377d7ce9318aa125e0a450c303"),
        ("verification", EVIDENCE / "verification", 13, "c70690725cbacb032bc90251fe0389b0343bda6d7fc4607d64656048d00ee982"),
        ("implementation-r2", EVIDENCE / "implementation-r2", 72, "4a03fe2325aed85208ce9ec418d194e1cd44fa220fb63180176cdcb5466a86e1"),
        ("verification-r2", EVIDENCE / "verification-r2", 17, "c830c13d4585bcf99e838fb04da35f4d208b5f7638ebf7e1b42b77e778eebad7"),
    ]
    membership_bad = []
    for label, directory, expected_count, seal_sha in seal_specs:
        actual = sorted(p.name for p in directory.iterdir() if p.is_file())
        seal = json.loads((directory / "seal.json").read_text())
        sealed_names = sorted(item["path"] for item in seal["files"])
        extra = sorted(set(actual) - set(sealed_names) - {"seal.json"})
        missing = sorted(set(sealed_names) - set(actual))
        file_bad = []
        for item in seal["files"]:
            path = directory / item["path"]
            st = path.lstat()
            digest = sha256_file(path)
            if digest != item["sha256"] or st.st_size != item["bytes"] or st.st_mode != item["mode"]:
                file_bad.append(item["path"])
        seal_st = (directory / "seal.json").lstat()
        seal_digest = sha256_file(directory / "seal.json")
        ok = (
            len(actual) == expected_count
            and not extra
            and not missing
            and not file_bad
            and seal_digest == seal_sha
            and seal_st.st_mode == 33188
        )
        membership[label] = {
            "files": len(actual),
            "expectedFiles": expected_count,
            "sealedMembers": len(sealed_names),
            "extra": extra,
            "missing": missing,
            "contentMismatches": file_bad,
            "sealSha256": seal_digest,
            "sealBytes": seal_st.st_size,
            "sealMode": seal_st.st_mode,
            "ok": ok,
        }
        if not ok:
            membership_bad.append(label)
        print(f"MEMBERSHIP {label} ok={ok} files={len(actual)}", flush=True)

    def verify_carrier(prefix: str, expected: int) -> dict:
        count = 0
        bad = []
        carriers = sorted(p.name for p in (EVIDENCE / "implementation-r2").iterdir() if p.name.startswith(prefix))
        for name in carriers:
            data = json.loads((EVIDENCE / "implementation-r2" / name).read_text())
            for item in data["files"]:
                raw = base64.b64decode(item["base64"])
                count += 1
                if hashlib.sha256(raw).hexdigest() != item["sha256"] or len(raw) != item["bytes"]:
                    bad.append({"carrier": name, "path": item["path"]})
        return {"carriers": carriers, "entries": count, "expected": expected, "bad": bad, "ok": count == expected and not bad}

    original_carrier = verify_carrier("original-artifacts-", 179)
    candidate_carrier = verify_carrier("candidate-artifacts-", 189)
    print(
        f"CARRIERS original={original_carrier['entries']} candidate={candidate_carrier['entries']} "
        f"bad={len(original_carrier['bad']) + len(candidate_carrier['bad'])}",
        flush=True,
    )

    changed_expected = {
        "out/MigrationNativeHandler.sol/MigrationNativeHandler.json",
        "out/MigrationNativeLedger.sol/MigrationNativeLedger.json",
        "out/TestBase_UniswapV4DetfMigrationSnapshot.sol/IMigrationPairPreview.json",
        "out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json",
        "out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotMathExposure.json",
        "out/TestBase_UniswapV4DetfMigrationSnapshot.sol/TestBase_UniswapV4DetfMigrationSnapshot.json",
    }
    current_diffs = []
    candidate_entries = 0
    for name in candidate_carrier["carriers"]:
        data = json.loads((EVIDENCE / "implementation-r2" / name).read_text())
        for item in data["files"]:
            candidate_entries += 1
            current = Path(item["path"])
            if not current.is_file():
                current_diffs.append({"path": item["path"], "reason": "missing-current"})
                continue
            st = current.lstat()
            digest = sha256_file(current)
            if digest != item["sha256"] or st.st_size != item["bytes"] or st.st_mode != item["mode"]:
                current_diffs.append({
                    "path": str(current.relative_to(WT)),
                    "currentSha256": digest,
                    "carrierSha256": item["sha256"],
                    "currentBytes": st.st_size,
                    "carrierBytes": item["bytes"],
                    "currentMode": st.st_mode,
                    "carrierMode": item["mode"],
                })
    diff_paths = {row["path"] for row in current_diffs}
    artifact_split = {
        "candidateEntries": candidate_entries,
        "currentDifferences": len(current_diffs),
        "differencePaths": sorted(diff_paths),
        "matchesExpectedSix": diff_paths == changed_expected,
        "equalToCarrier": candidate_entries - len(current_diffs),
    }
    print(f"ARTIFACT_SPLIT diffs={len(current_diffs)} expectedMatch={artifact_split['matchesExpectedSix']}", flush=True)

    changed_bytes = EVIDENCE / "verification-r2/changed-artifact-bytes.json"
    changed_record = file_record(changed_bytes, absolute=True)

    index_after = file_record(OWN_GITDIR / "index", absolute=True)
    if index_after["sha256"] != EXPECTED_INDEX:
        raise SystemExit("own index changed during read-only capture")

    port = subprocess.run(["lsof", "-nP", "-iTCP:18574", "-sTCP:LISTEN"], capture_output=True, text=True)
    procs = subprocess.run(["ps", "-ax", "-o", "pid=,command="], capture_output=True, text=True)
    interesting = []
    for line in procs.stdout.splitlines():
        low = line.lower()
        if any(token in low for token in ("forge", "anvil", "solar")) and "phase24-capture" not in low:
            interesting.append(line.strip())
    (OUT / "processes.txt").write_text(
        f"lsof-18574-exit={port.returncode}\n{port.stdout}{port.stderr}\n---\n" + "\n".join(interesting) + "\n"
    )

    summary = {
        "commitDirExisted": False,
        "indexUnchanged": True,
        "ownIndex": index_before,
        "ownHead": head_before,
        "ownRef": ref_before,
        "inventories": summaries,
        "preservationRows": len(rows),
        "preservationMismatches": mismatches,
        "indexes": {"count": len(indexes), "foreignCount": len(foreign), "ownCount": len(own)},
        "refs": len(refs),
        "showRefBytes": len(show_ref),
        "showRefSha256": sha256_bytes(show_ref),
        "links": links,
        "membership": membership,
        "membershipBad": membership_bad,
        "originalCarrier": {k: original_carrier[k] for k in ("entries", "expected", "ok", "carriers")},
        "candidateCarrier": {k: candidate_carrier[k] for k in ("entries", "expected", "ok", "carriers")},
        "carrierBad": len(original_carrier["bad"]) + len(candidate_carrier["bad"]),
        "artifactSplit": artifact_split,
        "changedArtifactCarrier": changed_record,
        "port18574Exit": port.returncode,
        "interestingProcesses": interesting,
        "docsFiles": len(docs_files),
        "docsPerms": len(docs_perms),
        "outFiles": len(out_files),
        "cacheFiles": len(cache_files),
    }
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    blockers = []
    if mismatches:
        blockers.append("preservation-row-mismatch")
    if membership_bad:
        blockers.append("membership")
    if not original_carrier["ok"] or not candidate_carrier["ok"]:
        blockers.append("carrier-lossless")
    if not artifact_split["matchesExpectedSix"]:
        blockers.append("artifact-split")
    if blockers:
        print("PHASE24_CAPTURE_FAIL " + ",".join(blockers), flush=True)
        raise SystemExit(2)
    print("PHASE24_CAPTURE_DONE", flush=True)


if __name__ == "__main__":
    main()
