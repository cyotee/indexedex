#!/usr/bin/env python3
"""Serialized, detached H/P acceptance with durable exit codes and no consumer roots."""
import argparse
import datetime
import fcntl
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
TEMP = Path("/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode")
SOURCES = "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread"
TESTS = "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread"


def worker(directory, campaign, rate_baselines):
    with (TEMP / "hookless-acceptance.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        while subprocess.run(["pgrep", "-f", r"^forge build|^forge test|/solc-0.8.35 |forge-artifacts.py (test|build)"],
                             stdout=subprocess.DEVNULL, check=False).returncode == 0:
            time.sleep(15)
        sources = [str(path.relative_to(ROOT)) for family in ("hookless", "ponsFamilyV2Hook")
                   for path in sorted((ROOT / SOURCES / family).glob("*.sol"))]
        args = ["-vv", "--no-cache"]
        if campaign:
            args += ["--match-test", "testFuzz_crossModeStatefulCampaign", "--fuzz-runs", "128"]
        roots = ["--test-root", TESTS]
        if rate_baselines:
            sources.append("contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol")
            for path in (
                "test/foundry/spec/protocols/staking/token/FeeAccrualCustodyScript.t.sol",
                "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol",
                "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_RateProvider_U6.t.sol",
                "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_RateProvider_U9.t.sol",
                "test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol",
            ):
                roots += ["--test-root", path]
        commands = [[sys.executable, "scripts/forge-artifacts.py", "test", *sources, *roots, "--", *args],
                    [sys.executable, "scripts/check-hookless-artifacts.py"],
                    [sys.executable, "scripts/check-pons-fullspread-artifacts.py"]]
        start = time.monotonic()
        results = []
        for command in commands:
            print("COMMAND " + json.dumps(command), flush=True)
            code = subprocess.run(command, cwd=ROOT, check=False).returncode
            results.append({"command": command, "returncode": code})
            if code:
                break
        result = {"finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  "elapsed_seconds": time.monotonic() - start, "campaign": campaign, "rate_baselines": rate_baselines,
                  "results": results, "success": len(results) == 3 and all(row["returncode"] == 0 for row in results)}
        (Path(directory) / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print("RESULT " + json.dumps(result), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", action="store_true")
    parser.add_argument("--rate-baselines", action="store_true")
    parser.add_argument("--worker")
    args = parser.parse_args()
    if args.worker:
        worker(args.worker, args.campaign, args.rate_baselines)
        return
    directory = Path(tempfile.mkdtemp(prefix="fullspread-family-", dir=TEMP))
    command = [sys.executable, str(Path(__file__).resolve()), "--worker", str(directory)]
    if args.campaign:
        command.append("--campaign")
    if args.rate_baselines:
        command.append("--rate-baselines")
    with (directory / "output.log").open("w") as output:
        process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
    print(json.dumps({"pid": process.pid, "directory": str(directory)}, indent=2))


if __name__ == "__main__":
    main()
