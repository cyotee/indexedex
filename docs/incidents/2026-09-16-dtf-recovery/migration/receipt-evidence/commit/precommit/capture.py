#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import stat
import subprocess
import sys

WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence"
COMMON = "/Users/cyotee/Projects/indexedex/.git"
OWN_INDEX = "worktrees/dtf-migration-phase-28-receipt-evidence/index"
OUT = "/tmp/phase28-receipt-evidence-precommit"
PARENT = "789fced820ed494d9651c598fb8f75c646d727a7"
BRANCH = "work/dtf-migration-phase-28-receipt-evidence"
PHASE09 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas"
HELD09 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas"
COMMIT_DIR = os.path.join(
    WT,
    "docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/commit",
)
EVIDENCE = os.path.join(
    WT, "docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence"
)
SOURCE_JSON = (
    "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/"
    "phase28-receipt-evidence-commit-source.json"
)
REPORT = os.path.join(EVIDENCE, "verification/report.md")
ACCEPTED_REPORT = "77bb12de3b210f0091d4f7409fdb52eff81b1fec5d8cc11dce0db38897bfa5aa"

GIT_ENV = os.environ.copy()
GIT_ENV.update(
    {
        "GIT_MASTER": "1",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_PAGER": "cat",
        "PAGER": "cat",
    }
)

CONTENT_KEYS = ("path", "kind", "gitMode", "perm", "st_mode", "size", "sha256", "target")
PERM_KEYS = ("path", "kind", "perm", "st_mode", "size", "sha256", "target")
DIR_KEYS = (
    "path",
    "kind",
    "perm",
    "st_mode",
    "size",
    "nlink",
    "childCount",
    "childrenSha256",
    "sha256",
    "target",
)


def dumps(row: dict, keys: tuple[str, ...]) -> str:
    ordered = {key: row[key] for key in keys}
    return json.dumps(ordered, ensure_ascii=False, separators=(",", ":"))


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def perm_text(mode: int) -> str:
    return oct(mode & 0o777)


def git_mode(mode: int) -> str:
    if stat.S_ISLNK(mode):
        return "120000"
    if stat.S_ISREG(mode):
        return "100755" if mode & 0o111 else "100644"
    return "000000"


def kind_of(mode: int) -> str:
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISDIR(mode):
        return "dir"
    if stat.S_ISREG(mode):
        return "file"
    return "other"


def refuse(path: str) -> None:
    real = os.path.realpath(path)
    for banned in (PHASE09, "/Users/cyotee/Projects/indexedex/lib/crane", "/Users/cyotee/Projects/indexedex/node_modules"):
        if real == banned or real.startswith(banned + os.sep):
            raise SystemExit(f"CAPTURE_BLOCKED refused path {path}")


def git(*args: str) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", "--no-pager", *args],
        cwd=WT,
        env=GIT_ENV,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def write_jsonl(name: str, rows: list[dict], keys: tuple[str, ...]) -> dict:
    rows = sorted(rows, key=lambda row: row["path"].encode())
    payload = "".join(dumps(row, keys) + "\n" for row in rows).encode()
    path = os.path.join(OUT, name)
    with open(path, "wb") as handle:
        handle.write(payload)
    return {"file": name, "rows": len(rows), "bytes": len(payload), "sha256": sha_bytes(payload)}


def inventory(abs_root: str, rel_root: str) -> tuple[list[dict], list[dict], list[dict]]:
    refuse(abs_root)
    content: list[dict] = []
    perms: list[dict] = []
    dirs: list[dict] = []
    seen = 0

    def rel_path(abs_path: str) -> str:
        if abs_path == abs_root:
            return rel_root
        suffix = os.path.relpath(abs_path, abs_root)
        return rel_root if suffix == "." else f"{rel_root}/{suffix}"

    def add_non_dir(abs_path: str, st: os.stat_result) -> None:
        kind = kind_of(st.st_mode)
        target = os.readlink(abs_path) if kind == "symlink" else None
        if kind == "symlink":
            digest = sha_bytes(target.encode()) if target is not None else None
        elif kind == "file":
            digest = sha_file(abs_path)
        else:
            digest = None
        row = {
            "path": rel_path(abs_path).replace(os.sep, "/"),
            "kind": kind,
            "gitMode": git_mode(st.st_mode),
            "perm": perm_text(st.st_mode),
            "st_mode": st.st_mode,
            "size": st.st_size,
            "sha256": digest,
            "target": target,
        }
        content.append({key: row[key] for key in CONTENT_KEYS})
        perms.append({key: row[key] for key in PERM_KEYS})

    def add_dir(abs_path: str) -> None:
        refuse(abs_path)
        st = os.lstat(abs_path)
        try:
            names = sorted(os.listdir(abs_path), key=lambda item: item.encode())
        except OSError as exc:
            raise SystemExit(f"CAPTURE_BLOCKED listdir {abs_path}: {exc}") from exc
        child_payload = "".join(name + "\n" for name in names).encode()
        rel = rel_path(abs_path).replace(os.sep, "/")
        dirs.append(
            {
                "path": rel,
                "kind": "dir",
                "perm": perm_text(st.st_mode),
                "st_mode": st.st_mode,
                "size": st.st_size,
                "nlink": st.st_nlink,
                "childCount": len(names),
                "childrenSha256": sha_bytes(child_payload),
                "sha256": None,
                "target": None,
            }
        )
        perms.append(
            {
                "path": rel,
                "kind": "dir",
                "perm": perm_text(st.st_mode),
                "st_mode": st.st_mode,
                "size": st.st_size,
                "sha256": None,
                "target": None,
            }
        )
        for name in names:
            child = os.path.join(abs_path, name)
            try:
                child_st = os.lstat(child)
            except OSError as exc:
                raise SystemExit(f"CAPTURE_BLOCKED lstat {child}: {exc}") from exc
            if stat.S_ISLNK(child_st.st_mode) or not stat.S_ISDIR(child_st.st_mode):
                add_non_dir(child, child_st)
            else:
                add_dir(child)
            nonlocal_seen[0] += 1
            if nonlocal_seen[0] % 2000 == 0:
                print(f"WALK {rel_root} entries {nonlocal_seen[0]}", flush=True)

    nonlocal_seen = [0]
    if not os.path.isdir(abs_root) or os.path.islink(abs_root):
        raise SystemExit(f"CAPTURE_BLOCKED walk root is not an ordinary directory: {abs_root}")
    add_dir(abs_root)
    return content, perms, dirs


def file_record(path: str) -> dict:
    st = os.lstat(path)
    kind = kind_of(st.st_mode)
    target = os.readlink(path) if kind == "symlink" else None
    digest = sha_bytes(target.encode()) if target is not None else sha_file(path) if kind == "file" else None
    return {
        "path": path,
        "kind": kind,
        "gitMode": git_mode(st.st_mode),
        "perm": perm_text(st.st_mode),
        "st_mode": st.st_mode,
        "size": st.st_size,
        "sha256": digest,
        "target": target,
        "inode": st.st_ino,
    }


def main() -> int:
    if os.path.exists(OUT):
        raise SystemExit(f"CAPTURE_BLOCKED output already exists: {OUT}")
    if os.path.exists(COMMIT_DIR):
        raise SystemExit(f"CAPTURE_BLOCKED commit directory already exists: {COMMIT_DIR}")
    os.makedirs(OUT)
    blockers: list[str] = []

    head = git("rev-parse", "HEAD")
    branch = git("branch", "--show-current")
    parents = git("rev-list", "--parents", "-n", "1", "HEAD")
    status = git("status", "--porcelain=v1", "--ignore-submodules=all")
    diff_stat = git("diff", "--stat", "--ignore-submodules=all")
    diff_patch = git(
        "diff",
        "--ignore-submodules=all",
        "--",
        "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md",
        "scripts/recovery/dtf-migration/cli.ts",
    )
    cached = git("diff", "--cached", "--stat", "--ignore-submodules=all")
    show_ref = git("show-ref")
    upstream = git("rev-parse", "--abbrev-ref", "@{upstream}")
    autocrlf = git("config", "--get", "core.autocrlf")
    hooks = git("config", "--get", "core.hooksPath")
    whitespace = git("diff", "--ignore-submodules=all", "--check")
    whitespace_head = git("diff", "--ignore-submodules=all", "--check", "HEAD")

    head_text = head.stdout.decode().strip()
    branch_text = branch.stdout.decode().strip()
    if head.returncode != 0 or head_text != PARENT:
        blockers.append(f"HEAD {head_text!r} exit {head.returncode}")
    if branch.returncode != 0 or branch_text != BRANCH:
        blockers.append(f"branch {branch_text!r}")
    if cached.stdout.strip() or cached.returncode != 0:
        blockers.append("staged diff is not empty before staging")

    expected = {
        " M docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md",
        " M scripts/recovery/dtf-migration/cli.ts",
        "?? docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/",
        "?? scripts/recovery/dtf-migration/receipt-association.ts",
        "?? scripts/recovery/dtf-migration/receipt-evidence.ts",
        "?? scripts/recovery/dtf-migration/receipt-input.ts",
        "?? scripts/recovery/dtf-migration/receipt-reconciliation.test.ts",
        "?? scripts/recovery/dtf-migration/receipt-reconciliation.ts",
        "?? scripts/recovery/dtf-migration/receipt-rpc.ts",
        "?? scripts/recovery/dtf-migration/receipt.fixture.ts",
        "?? scripts/recovery/dtf-migration/receipt.test.ts",
    }
    actual_status = {line for line in status.stdout.decode().splitlines() if line}
    if actual_status != expected:
        blockers.append(
            "status set differs: extra="
            + ",".join(sorted(actual_status - expected))
            + " missing="
            + ",".join(sorted(expected - actual_status))
        )

    source = json.load(open(SOURCE_JSON))
    if source.get("parent") != PARENT:
        blockers.append("commit source parent differs")
    accepted = source["paths"]
    if len(accepted) != 10:
        blockers.append(f"accepted path count {len(accepted)}")
    bindings = []
    for row in accepted:
        path = os.path.join(WT, row["path"])
        current = file_record(path)
        current["acceptedBytes"] = row["bytes"]
        current["acceptedSha256"] = row["sha256"]
        current["match"] = current["size"] == row["bytes"] and current["sha256"] == row["sha256"]
        if not current["match"]:
            blockers.append(f"accepted identity mismatch {row['path']}")
        bindings.append(current)
    check_attr = git("check-attr", "-a", "--", *[row["path"] for row in accepted])

    producer = json.load(open(os.path.join(EVIDENCE, "implementation/source-manifest.json")))
    operator = producer["operator"]
    if len(operator) != 70:
        blockers.append(f"operator identity count {len(operator)}")
    frozen = []
    for row in operator:
        path = os.path.join(WT, row["path"])
        current = file_record(path)
        current["testedBytes"] = row["bytes"]
        current["testedSha256"] = row["sha256"]
        current["match"] = current["size"] == row["bytes"] and current["sha256"] == row["sha256"]
        current["committed"] = any(item["path"] == row["path"] for item in accepted)
        if not current["match"]:
            blockers.append(f"frozen identity mismatch {row['path']}")
        frozen.append(
            {
                "path": row["path"],
                "bytes": current["size"],
                "sha256": current["sha256"],
                "perm": current["perm"],
                "st_mode": current["st_mode"],
                "gitMode": current["gitMode"],
                "match": current["match"],
                "committed": current["committed"],
            }
        )

    report_bytes = open(REPORT, "rb").read()
    report_sha = sha_bytes(report_bytes)
    if report_sha != ACCEPTED_REPORT or len(report_bytes) != 20647:
        blockers.append(f"verifier report {report_sha} {len(report_bytes)}")

    def seal_members(lane: str, members: list[tuple[str, int, str]]) -> list[dict]:
        rows = []
        for rel, size, digest in members:
            path = os.path.join(EVIDENCE, lane, rel)
            data = open(path, "rb").read()
            actual = sha_bytes(data)
            match = len(data) == size and actual == digest
            if not match:
                blockers.append(f"seal member mismatch {lane}/{rel}")
            rows.append({"path": f"{lane}/{rel}", "bytes": len(data), "sha256": actual, "match": match})
        return rows

    seals = seal_members(
        "verification",
        [
            ("manifest.json", 123457, "1964b2db2377db6fb17727a2998f8bfd41d823a082f2c2522d6018bbca512baf"),
            ("report.md", 20647, ACCEPTED_REPORT),
            ("cleanup.json", 1747, "1119ed962389cd66b99c87334058b34a703a0bb4b71cb56e563d9fa8395075ed"),
            ("final-state.json", 112437, "fec22fc537ed14f482634a0ce1322a18f732012f4e06639268fd0f6916919f1d"),
            ("intake.json", 517207, "004b9267feeb782e2b06efa097688713945805067c238bb8270620f4234b0514"),
            ("preservation.json", 304653, "f77773784206655734471c55289ec18b3d0b31beee0767eb169ec4074a399496"),
            ("actual/archive.json", 3848804, "e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b"),
            ("actual/http-manifest.json", 154633, "6feab989ce86fe70e1b70ad37acb42a775131c5e46a848b575689436f88d0731"),
            ("independent-proof.json", 7808127, "18e9c490df316d958a9d0b8f841ba0c8de103693b6ea66143e22627ea67bbb0a"),
        ],
    ) + seal_members(
        "implementation",
        [
            ("manifest.json", 123425, "0b5f1a0714354e66e4b0e773c11c2930ff8e440ef3dc77e1207633f782070e7f"),
            ("report.md", 17946, "931b2130f345835240f67fd438e4864e05fb71cc856f9c16db6a678f3ffab815"),
            ("source-manifest.json", 16341, "2c91a827e237db5c664c053730d40763fff8228de5b121b7df87ed8509c59861"),
            ("cleanup.json", 1870, "de24379a0393ff688b5548ad440924641b55ade2ca2b30c2c4633f2478a922d2"),
            ("actual/archive.json", 3848804, "e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b"),
            ("actual/http-manifest.json", 154633, "6feab989ce86fe70e1b70ad37acb42a775131c5e46a848b575689436f88d0731"),
            ("independent-proof.json", 143499, "c1fd3a0195f4fcd6781245e1c9b78721efe953519657b1a9f8f7f8cc10ca024f"),
            ("reference-review.json", 225230, "b82a2a0d5cd44addfc14baee05d19d5dd4386841d4e41d6b6117c07bcf2fce51"),
        ],
    )

    authorities = []
    for row in producer["authorities"]:
        current = file_record(row["path"])
        current["testedBytes"] = row["bytes"]
        current["testedSha256"] = row["sha256"]
        current["match"] = current["size"] == row["bytes"] and current["sha256"] == row["sha256"]
        if not current["match"]:
            blockers.append(f"authority mismatch {row['path']}")
        authorities.append(current)

    print("WALK evidence/out/cache/input", flush=True)
    walks = {
        "docs-incidents": (
            os.path.join(WT, "docs/incidents"),
            "docs/incidents",
        ),
        "out": (os.path.join(WT, "out"), "out"),
        "cache_forge": (os.path.join(WT, "cache_forge"), "cache_forge"),
        "recovered-input": (
            "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery",
            "phase27-frozen-input-recovery",
        ),
        "original-incident": (
            "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery",
            "2026-09-16-dtf-recovery",
        ),
    }
    summaries = []
    for name, (abs_root, rel_root) in walks.items():
        print(f"START {name}", flush=True)
        content, perms, directories = inventory(abs_root, rel_root)
        summaries.append({"name": name, "content": write_jsonl(f"{name}.jsonl", content, CONTENT_KEYS)})
        summaries.append({"name": name, "perms": write_jsonl(f"{name}-perms.jsonl", perms, PERM_KEYS)})
        summaries.append({"name": name, "dirs": write_jsonl(f"{name}-dirs.jsonl", directories, DIR_KEYS)})
        print(f"DONE {name} content {len(content)} perms {len(perms)} dirs {len(directories)}", flush=True)

    indexes = []
    index_paths = []
    main_index = os.path.join(COMMON, "index")
    if os.path.isfile(main_index):
        index_paths.append(main_index)
    worktrees = os.path.join(COMMON, "worktrees")
    for name in sorted(os.listdir(worktrees), key=lambda item: item.encode()):
        candidate = os.path.join(worktrees, name, "index")
        if os.path.isfile(candidate):
            index_paths.append(candidate)
    for path in index_paths:
        rel = os.path.relpath(path, COMMON).replace(os.sep, "/")
        if rel.startswith("../") or os.path.realpath(path).startswith(PHASE09 + os.sep):
            blockers.append(f"index path escaped {path}")
            continue
        st = os.lstat(path)
        indexes.append(
            {
                "path": rel,
                "foreign": rel != OWN_INDEX,
                "bytes": st.st_size,
                "sha256": sha_file(path),
                "perm": perm_text(st.st_mode),
                "st_mode": st.st_mode,
            }
        )

    refs = []
    ref_files = []
    for base, prefix in ((os.path.join(COMMON, "refs"), "refs"),):
        for root, dirnames, filenames in os.walk(base, followlinks=False):
            dirnames[:] = [item for item in dirnames if item != "logs"]
            for filename in filenames:
                ref_files.append(os.path.join(root, filename))
    for extra in (os.path.join(COMMON, "HEAD"), os.path.join(COMMON, "packed-refs")):
        if os.path.isfile(extra):
            ref_files.append(extra)
    for name in sorted(os.listdir(worktrees), key=lambda item: item.encode()):
        head_path = os.path.join(worktrees, name, "HEAD")
        if os.path.isfile(head_path) and not os.path.islink(head_path):
            ref_files.append(head_path)
    for path in ref_files:
        rel = os.path.relpath(path, COMMON).replace(os.sep, "/")
        st = os.lstat(path)
        data = open(path, "rb").read()
        text = data.decode() if len(data) <= 200 else None
        refs.append(
            {
                "path": rel,
                "bytes": len(data),
                "sha256": sha_bytes(data),
                "perm": perm_text(st.st_mode),
                "st_mode": st.st_mode,
                "text": text,
            }
        )
    refs.sort(key=lambda row: row["path"].encode())
    ref_payload = "".join(
        json.dumps(
            {key: row[key] for key in ("path", "bytes", "sha256", "perm", "st_mode", "text")},
            ensure_ascii=False,
            separators=(",", ":"),
        )
        + "\n"
        for row in refs
    ).encode()
    with open(os.path.join(OUT, "refs.jsonl"), "wb") as handle:
        handle.write(ref_payload)

    host = {
        "libCrane": file_record(os.path.join(WT, "lib/crane")),
        "nodeModules": file_record(os.path.join(WT, "node_modules")),
        "gitlink": git("ls-files", "-s", "--", "lib/crane").stdout.decode(),
        "targetsOpened": False,
    }
    if host["libCrane"]["kind"] != "symlink" or host["nodeModules"]["kind"] != "symlink":
        blockers.append("host dependency is not a symlink")

    with open(os.path.join(OUT, "show-ref.txt"), "wb") as handle:
        handle.write(show_ref.stdout)
    for name, proc in (
        ("status-before.txt", status),
        ("diff-stat.txt", diff_stat),
        ("tracked-diff.txt", diff_patch),
        ("staged-before.txt", cached),
        ("whitespace-before.txt", whitespace),
        ("whitespace-head-before.txt", whitespace_head),
        ("check-attr.txt", check_attr),
    ):
        with open(os.path.join(OUT, name), "wb") as handle:
            handle.write(proc.stdout)
            if proc.stderr:
                handle.write(b"\nSTDERR\n")
                handle.write(proc.stderr)

    summary = {
        "head": head_text,
        "branch": branch_text,
        "parents": parents.stdout.decode().strip(),
        "upstreamExit": upstream.returncode,
        "upstreamStderr": upstream.stderr.decode().strip(),
        "autocrlfExit": autocrlf.returncode,
        "hooksPath": hooks.stdout.decode().strip(),
        "hooksPathExistsInWorktree": os.path.isdir(os.path.join(WT, ".husky/_")),
        "commitDirExisted": False,
        "cacheExists": os.path.exists(os.path.join(WT, "cache")),
        "foundryCache": "cache_forge",
        "stagedEmpty": cached.stdout == b"" and cached.returncode == 0,
        "whitespaceExit": whitespace.returncode,
        "whitespaceBytes": len(whitespace.stdout),
        "statusMatch": actual_status == expected,
        "acceptedMatches": sum(1 for row in bindings if row["match"]),
        "frozenMatches": sum(1 for row in frozen if row["match"]),
        "frozenCount": len(frozen),
        "authorityMatches": sum(1 for row in authorities if row["match"]),
        "sealMatches": sum(1 for row in seals if row["match"]),
        "indexCount": len(indexes),
        "foreignIndexCount": sum(1 for row in indexes if row["foreign"]),
        "refCount": len(refs),
        "showRefBytes": len(show_ref.stdout),
        "showRefSha256": sha_bytes(show_ref.stdout),
        "walks": summaries,
        "blockers": blockers,
        "phase09WorktreeOpened": False,
        "held09WorktreeOpened": False,
        "symlinkTargetsOpened": False,
    }
    for name, value in (
        ("indexes.json", indexes),
        ("host-deps.json", host),
        ("authorities.json", authorities),
        ("source-bindings.json", bindings),
        ("frozen-source-modes.json", frozen),
        ("seal-check.json", seals),
        ("summary.json", summary),
        ("cache-absent.json", {"cache": False, "cache_forge": True, "reason": "worktree cache/ does not exist; Foundry cache_path is cache_forge"}),
        ("roots.json", {name: {"absolute": abs_root, "relRoot": rel_root} for name, (abs_root, rel_root) in walks.items()}),
    ):
        with open(os.path.join(OUT, name), "w") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
    recipe = """Precommit inventory recipe v1
Captured before staging or committing the phase28 finite receipt-evidence source delivery.
The walks completed before any file existed under migration/receipt-evidence/commit/.
Inventory files were written only under /tmp/phase28-receipt-evidence-precommit during the walk.
They are excluded evidence and are not members of the preservation set.
No build, deletion, chmod, cache write, artifact restoration, relocation, test, collector, oracle, or runtime rerun is part of this recipe.
Every Git invocation uses GIT_MASTER=1 and --no-pager. GIT_PAGER=cat and PAGER=cat are set.
Read-only Git invocations also set GIT_OPTIONAL_LOCKS=0 so they do not refresh the index.
Status and diff use --ignore-submodules=all.
Index identity is the SHA-256 of the raw index file bytes. It is not git ls-files output and not a decoded string.
No path under /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas was opened. Any phase09 foreign index was hashed only at .git/worktrees/dtf-migration-phase-09-deployment-gas/index.
No held09 worktree path was opened. Symlink targets were not opened.

Content inventory
Files: docs-incidents.jsonl, out.jsonl, cache_forge.jsonl, recovered-input.jsonl, original-incident.jsonl.
Walk: lstat, followlinks false. Symlinked directories are recorded and not descended. Ordinary directories are not content entries.
Fields, fixed key order: path, kind, gitMode, perm, st_mode, size, sha256, target.
path: worktree trees are POSIX paths relative to the worktree. Recovered-input paths are relative to phase27-frozen-input-recovery's parent name, rooted at phase27-frozen-input-recovery. Original-incident paths are relative to /Users/cyotee/Projects/indexedex/docs/incidents. Sorted by UTF-8 byte order.
kind: file, symlink, or other.
gitMode: 100644 regular non-executable, 100755 regular executable, 120000 symlink, 000000 other. This collapses exact regular-file modes and is not the permission proof.
perm: oct(st_mode & 0o777), written as 0o644 style text.
st_mode: full lstat mode integer.
size: lstat st_size.
sha256: SHA-256 of file bytes for regular files; SHA-256 of the symlink target string encoded UTF-8 for symlinks; null otherwise. Symlink targets are not opened.
target: symlink target string, else null.
Serialization: UTF-8 JSON Lines, separators (',', ':'), one record per line, each line ending in \\n, no extra trailing blank line.
Aggregate SHA-256 is SHA-256 of those exact JSONL bytes and is not a substitute for the rows.

Permission inventory
Files: docs-incidents-perms.jsonl, out-perms.jsonl, cache_forge-perms.jsonl, recovered-input-perms.jsonl, original-incident-perms.jsonl.
Same roots. Ordinary directories are included, including the walk root. Directory paths have no trailing slash.
Fields, fixed key order: path, kind, perm, st_mode, size, sha256, target.
Directory sha256 is null. File and symlink sha256 use the same rules as the content inventory.

Directory bookkeeping
Files: docs-incidents-dirs.jsonl, out-dirs.jsonl, cache_forge-dirs.jsonl, recovered-input-dirs.jsonl, original-incident-dirs.jsonl.
Fields, fixed key order: path, kind, perm, st_mode, size, nlink, childCount, childrenSha256, sha256, target.
childrenSha256 is SHA-256 of the directory's child names sorted by UTF-8, each followed by \\n. It is not a content hash. Directory sha256 is null.
nlink is st_nlink. childCount is len(os.listdir). size is st_size.

Other baselines
indexes.json: raw SHA-256, size, mode, and permission of .git/index and every .git/worktrees/*/index. foreign is true except worktrees/dtf-migration-phase-28-receipt-evidence/index.
refs.jsonl: raw bytes, length, mode, permission, and text when the file is at most 200 bytes, for every file under .git/refs, plus .git/HEAD, .git/packed-refs when present, and every worktree HEAD under .git/worktrees. Reflogs are not in this set.
show-ref.txt: exact UTF-8 bytes of GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git --no-pager show-ref, captured before staging.
host-deps.json: lib/crane and node_modules symlinks only. Targets were not opened. lib/crane gitlink is git ls-files -s output.
authorities.json: ten named regular authority files from the producer source manifest.
cache-absent.json: worktree cache/ does not exist. Foundry cache_path is cache_forge. Absence is recorded; no cache tree was invented.
source-bindings.json: filesystem modes of the ten accepted paths. Tested source manifests omit modes; gitMode is the filesystem executable-bit collapse, not historical tested mode evidence.
frozen-source-modes.json: filesystem modes of all 70 tested operator/runbook identities.
seal-check.json: seal member hashes recomputed before staging.
capture.py: the read-only script that produced the inventories. It writes only under /tmp/phase28-receipt-evidence-precommit.
"""
    with open(os.path.join(OUT, "recipe.txt"), "w") as handle:
        handle.write(recipe)
    with open(os.path.join(OUT, "capture.py"), "w") as handle:
        handle.write(open(__file__).read())
    print(json.dumps(summary), flush=True)
    if blockers:
        print("CAPTURE_BLOCKED", flush=True)
        return 2
    print("CAPTURE_COMPLETE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
