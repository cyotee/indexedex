#!/usr/bin/env python3
"""Side-by-side R+ vs R− DualLiquidity research plots (residual + P&L)."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

os.environ.setdefault("MPLBACKEND", "Agg")
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from common import load_meta, load_series, parse_int, w18


def si(x) -> int:
    return parse_int(x)


def residual_vals(rows: list[dict]) -> list[float]:
    out = []
    for r in rows:
        # residualA is signed int string in 1e18 fixed point (midIndex*rateIndex/1e18 - 1e18)
        v = si(r.get("residualA") or 0)
        out.append(v / 1e18)
    return out


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("rates_on_dir", type=Path)
    p.add_argument("rates_off_dir", type=Path)
    p.add_argument("--out-dir", type=Path, default=None)
    args = p.parse_args()

    on = load_series(args.rates_on_dir / "series.jsonl")
    off = load_series(args.rates_off_dir / "series.jsonl")
    if not on or not off:
        raise SystemExit("empty series")
    meta_on = load_meta(args.rates_on_dir)
    mode = meta_on.get("mode") or "unknown"

    out_dir = args.out_dir or Path(
        "research/out/dualLiquidityLinkedCrossVersion/compare"
    ) / str(mode).replace(" ", "_")
    out_dir.mkdir(parents=True, exist_ok=True)

    steps_on = [r["step"] for r in on]
    steps_off = [r["step"] for r in off]
    res_on = residual_vals(on)
    res_off = residual_vals(off)

    p0_on = max(si(on[0].get("portfolio0Bpt") or 1), 1)
    p0_off = max(si(off[0].get("portfolio0Bpt") or 1), 1)
    pnl_on = [si(r.get("totalPnlBpt") or 0) / p0_on for r in on]
    pnl_off = [si(r.get("totalPnlBpt") or 0) / p0_off for r in off]

    fig, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    ax = axes[0]
    ax.axhline(0.0, color="gray", ls="--")
    ax.plot(steps_on, res_on, "g-", lw=2, label="R+ residualA")
    ax.plot(steps_off, res_off, "r-", lw=2, label="R− residualA")
    ax.set_ylabel("residualA (fraction)")
    ax.set_title(f"DualLiquidity residualA — {mode}")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    ax = axes[1]
    ax.axhline(0.0, color="gray", ls="--")
    ax.plot(steps_on, [x * 100 for x in pnl_on], "g-", lw=2, label="R+ totalPnlBpt / start %")
    ax.plot(steps_off, [x * 100 for x in pnl_off], "r-", lw=2, label="R− totalPnlBpt / start %")
    ax.set_xlabel("Step")
    ax.set_ylabel("% of start BPT book")
    ax.set_title("Share book P&L (BPT full-exit mark)")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(out_dir / "fairness_pnl_compare.png", dpi=160, bbox_inches="tight")
    print("wrote", out_dir / "fairness_pnl_compare.png")

    # Mode B preview gap if present
    if any(si(r.get("previewOut") or 0) for r in on + off):
        fig, ax = plt.subplots(figsize=(12, 4))
        gap_on = [
            (si(r.get("execOut") or 0) - si(r.get("previewOut") or 0)) for r in on
        ]
        gap_off = [
            (si(r.get("execOut") or 0) - si(r.get("previewOut") or 0)) for r in off
        ]
        ax.plot(steps_on, gap_on, "g-", lw=2, label="R+ exec-preview")
        ax.plot(steps_off, gap_off, "r-", lw=2, label="R− exec-preview")
        ax.axhline(0.0, color="gray", ls="--")
        ax.set_title("Mode B preview gap (wei)")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)
        fig.tight_layout()
        fig.savefig(out_dir / "preview_gap.png", dpi=160, bbox_inches="tight")
        print("wrote", out_dir / "preview_gap.png")

    summary = {
        "mode": mode,
        "rates_on": str(args.rates_on_dir),
        "rates_off": str(args.rates_off_dir),
        "residualA_end_on": res_on[-1],
        "residualA_end_off": res_off[-1],
        "residualA_max_abs_on": max(abs(x) for x in res_on),
        "residualA_max_abs_off": max(abs(x) for x in res_off),
        "pnl_frac_end_on": pnl_on[-1],
        "pnl_frac_end_off": pnl_off[-1],
        "meta_on": meta_on,
        "meta_off": load_meta(args.rates_off_dir),
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("wrote", out_dir / "summary.json")


if __name__ == "__main__":
    main()
