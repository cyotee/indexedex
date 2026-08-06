#!/usr/bin/env python3
"""Plot Uni V4 hook research series: reserves + mid index.

Usage:
  python research/plots/plot_uniswap_v4_hook_mids.py research/out/uniswapV4/hooks/orbital/H1_demand_01
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


def load_series(run_dir: Path) -> list[dict]:
    path = run_dir / "series.jsonl"
    rows = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    run_dir = Path(sys.argv[1])
    rows = load_series(run_dir)
    if not rows:
        print(f"no rows in {run_dir}/series.jsonl")
        return 1

    steps = [r.get("step", i) for i, r in enumerate(rows)]
    mid = [r.get("midIndex01") for r in rows]
    r0 = [r.get("r0") for r in rows]
    r1 = [r.get("r1") for r in rows]
    r2 = [r.get("r2") for r in rows]
    radius = [r.get("radius") for r in rows]

    fig, axes = plt.subplots(3, 1, figsize=(10, 9), sharex=True)

    if any(v is not None for v in mid):
        axes[0].plot(steps, [v / 1e18 if v else None for v in mid], color="black", label="midIndex01")
        axes[0].axhline(1.0, color="gray", ls="--", lw=0.8)
        axes[0].set_ylabel("mid index")
        axes[0].legend(loc="best")
        axes[0].set_title(f"{run_dir.name}: mid index (r1/r0 vs t0)")

    if any(v is not None for v in r0):
        axes[1].plot(steps, r0, label="r0")
        axes[1].plot(steps, r1, label="r1")
        if any(v is not None for v in r2):
            axes[1].plot(steps, r2, label="r2")
        axes[1].set_ylabel("reserves (wei)")
        axes[1].legend(loc="best")
        axes[1].set_title("Reserves")

    if any(v is not None for v in radius):
        axes[2].plot(steps, radius, color="purple", label="radius")
        axes[2].set_ylabel("radius")
        axes[2].legend(loc="best")
        axes[2].set_title("Sphere radius")

    axes[-1].set_xlabel("step")
    fig.tight_layout()
    out = run_dir / "mids_reserves.png"
    fig.savefig(out, dpi=140)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
