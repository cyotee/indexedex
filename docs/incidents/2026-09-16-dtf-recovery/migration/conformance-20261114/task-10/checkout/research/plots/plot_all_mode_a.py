#!/usr/bin/env python3
"""Run the full Mode A internal plot pack on a research run directory."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

PLOTS = [
    "plot_price_series.py",
    "plot_rates.py",
    "plot_inventory.py",
    "plot_pnl.py",
    "plot_pnl_normalized.py",
    "plot_index_vs_fairness.py",  # Uni vs mid slopes vs true fairness / arb probes
]


def main() -> None:
    p = argparse.ArgumentParser(description="Plot full Mode A pack for one run dir")
    p.add_argument("run_dir", type=Path, nargs="+")
    args = p.parse_args()

    here = Path(__file__).resolve().parent
    failed = 0
    for run_dir in args.run_dir:
        run_dir = run_dir.resolve()
        print(f"\n=== {run_dir} ===")
        if not (run_dir / "series.jsonl").exists():
            print(f"  SKIP: no series.jsonl", file=sys.stderr)
            failed += 1
            continue
        for script in PLOTS:
            cmd = [sys.executable, str(here / script), str(run_dir)]
            print(f"  $ {' '.join(cmd)}")
            r = subprocess.run(cmd, cwd=str(here))
            if r.returncode != 0:
                failed += 1
                print(f"  FAIL {script} exit={r.returncode}", file=sys.stderr)

    if failed:
        raise SystemExit(failed)
    print("\nall Mode A plots ok")


if __name__ == "__main__":
    main()
