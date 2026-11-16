#!/usr/bin/env python3
"""Append reconstruction fields (git commit, forge version, timestamp) to meta.json."""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def _run(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def stamp(run_dir: Path, script: str = "") -> None:
    meta_path = run_dir / "meta.json"
    if not meta_path.exists():
        raise SystemExit(f"missing {meta_path}")
    meta = json.loads(meta_path.read_text())
    meta["gitCommit"] = _run(["git", "rev-parse", "HEAD"])
    meta["gitCommitShort"] = _run(["git", "rev-parse", "--short", "HEAD"])
    meta["forgeVersion"] = _run(["forge", "--version"]).split("\n")[0] if _run(["forge", "--version"]) else ""
    meta["stampedAtUtc"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if script:
        meta["script"] = script
    meta_path.write_text(json.dumps(meta, indent=2) + "\n")
    print(f"stamped {meta_path} commit={meta.get('gitCommitShort')} script={meta.get('script', '')}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("run_dir", type=Path)
    p.add_argument("--script", default="")
    args = p.parse_args()
    stamp(args.run_dir, args.script)


if __name__ == "__main__":
    main()
