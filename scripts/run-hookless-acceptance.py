#!/usr/bin/env python3
"""Run the unchanged artifact/test workflow independently of a tool wait lifetime."""

import datetime
import argparse
import fcntl
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parent.parent
TEMP = Path("/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode")
H = "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless"
TESTS = "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless"


def worker(directory, test_root):
    directory = Path(directory)
    with (TEMP / "hookless-acceptance.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Diagnostics can enqueue their own compiler processes. Never compete
        # with those writers, and never terminate them to begin acceptance.
        while subprocess.run(["pgrep", "-f", r"^forge build|^forge test|/solc-0.8.35 |forge-artifacts.py (test|build)"],
                             stdout=subprocess.DEVNULL, check=False).returncode == 0:
            time.sleep(15)
        started = time.monotonic()
        sources = [str(path.relative_to(ROOT)) for path in sorted((ROOT / H).glob("*.sol"))]
        commands = [
            [sys.executable, "scripts/forge-artifacts.py", "test", *sources, "--test-root", test_root, "--", "-vv"],
            [sys.executable, "scripts/check-hookless-artifacts.py"],
        ]
        results = []
        for command in commands:
            print("COMMAND " + json.dumps(command), flush=True)
            result = subprocess.run(command, cwd=ROOT, check=False)
            results.append({"command": command, "returncode": result.returncode})
            if result.returncode:
                break
        summary = {
            "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "elapsed_seconds": time.monotonic() - started,
            "results": results,
            "success": len(results) == len(commands) and all(row["returncode"] == 0 for row in results),
        }
        (directory / "result.json").write_text(json.dumps(summary, indent=2) + "\n")
        print("RESULT " + json.dumps(summary), flush=True)
        return 0 if summary["success"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test-root", default=TESTS)
    parser.add_argument("--worker")
    args = parser.parse_args()
    if args.worker:
        return worker(args.worker, args.test_root)
    active = subprocess.run(["pgrep", "-f", r"run-hookless-acceptance.py --worker"],
                            capture_output=True, text=True, check=False)
    if active.returncode == 0:
        raise SystemExit("Existing compiler/acceptance worker active; wait for its real exit: " + active.stdout.strip())
    directory = Path(tempfile.mkdtemp(prefix="hookless-acceptance-", dir=TEMP))
    with (directory / "output.log").open("w") as output:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--worker", str(directory), "--test-root", args.test_root],
                                   cwd=ROOT, stdin=subprocess.DEVNULL, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
    print(json.dumps({"pid": process.pid, "directory": str(directory), "result": str(directory / "result.json")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
