#!/usr/bin/env python3
"""Normalized portfolio P&L for Mode A (internal review).

Absolute USDC marks are huge (full matrix book). This chart answers:

  “Per dollar of starting book, what happened?”

  total / price / fee as fraction of portfolio0 (and fee also in absolute USDC
  on a secondary panel so small maker income remains readable).
"""

from __future__ import annotations

import argparse
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

from common import demand_title, load_meta, load_series, market_bought_asset, parse_int, w18


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("run_dir", type=Path)
    p.add_argument("--out", type=Path, default=None)
    args = p.parse_args()

    rows = load_series(args.run_dir / "series.jsonl")
    if not rows:
        raise SystemExit("empty series")
    if "totalPnlUsdc" not in rows[0]:
        raise SystemExit("missing P&L fields; re-run forge script")

    meta = load_meta(args.run_dir)
    market_bought = market_bought_asset(meta, rows)
    main_t, sub_t = demand_title(market_bought)

    p0 = parse_int(rows[0]["portfolio0Usdc"])
    if p0 <= 0:
        raise SystemExit("zero portfolio0")

    steps = [r["step"] for r in rows]
    price_frac = [parse_int(r["pricePnlUsdc"]) / p0 for r in rows]
    fee_frac = [parse_int(r["feePnlUsdc"]) / p0 for r in rows]
    total_frac = [parse_int(r["totalPnlUsdc"]) / p0 for r in rows]
    fee_usdc = [w18(r["feePnlUsdc"]) for r in rows]
    exit_frac = [parse_int(r["portfolioExitUsdc"]) / p0 for r in rows]

    fig, axes = plt.subplots(
        3,
        1,
        figsize=(12.5, 9.5),
        sharex=True,
        gridspec_kw={"height_ratios": [2.0, 1.15, 1.25]},
    )

    ax = axes[0]
    ax.axhline(0.0, color="gray", linestyle="--", lw=1, alpha=0.7)
    ax.plot(
        steps,
        price_frac,
        color="#1f77b4",
        lw=2.2,
        label="Asset-value P&L / start (t0 claim @ live prices)",
    )
    ax.plot(steps, total_frac, color="#111111", lw=2.4, label="Total P&L / start (full exit − start)")
    ax.set_ylabel("Fraction of start book")
    ax.set_title(
        f"Normalized P&L — {main_t}\n"
        f"{sub_t}  ·  all series ÷ portfolio0 (removes absolute scale)",
        fontsize=11,
        pad=12,
    )
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.annotate(
        f"end total {total_frac[-1]:+.4%}",
        xy=(steps[-1], total_frac[-1]),
        xytext=(-110, 12),
        textcoords="offset points",
        fontsize=9,
    )

    axf = axes[1]
    axf.axhline(0.0, color="gray", linestyle="--", lw=1, alpha=0.7)
    axf.plot(steps, fee_usdc, color="#2ca02c", lw=2.4, label="Maker fees + claim qty change (USDC units)")
    axf.set_ylabel("Fee P&L (USDC)")
    axf.legend(loc="best", fontsize=9)
    axf.grid(True, alpha=0.3)
    axf.annotate(
        f"end {fee_usdc[-1]:+.4f} USDC\n({fee_frac[-1]:+.6%} of book)",
        xy=(steps[-1], fee_usdc[-1]),
        xytext=(-140, 8),
        textcoords="offset points",
        fontsize=9,
        color="#2ca02c",
    )

    ax2 = axes[2]
    ax2.axhline(1.0, color="gray", linestyle="--", lw=1, label="Start = 1.0")
    ax2.plot(steps, exit_frac, color="#9467bd", lw=2.0, label="Full-exit value / start")
    ax2.set_xlabel("Trade step")
    ax2.set_ylabel("Book / start")
    ax2.legend(loc="best", fontsize=9)
    ax2.grid(True, alpha=0.3)

    fig.text(
        0.5,
        0.01,
        "Price panel is β to WETH/USDC under one-way flow. Fee panel is the strategy income signal "
        "(small vs directional mark). Use both when explaining SE vault economics.",
        ha="center",
        va="bottom",
        fontsize=9,
        color="0.35",
    )
    fig.tight_layout(rect=(0, 0.04, 1, 1))

    out = args.out or (args.run_dir / "pnl_normalized.png")
    fig.savefig(out, dpi=160, bbox_inches="tight")
    print(f"wrote {out}")
    print(f"  market_bought={market_bought}")
    print(f"  end total/start: {total_frac[-1]:+.6%}")
    print(f"  end price/start: {price_frac[-1]:+.6%}")
    print(f"  end fee USDC:    {fee_usdc[-1]:+.6f}  ({fee_frac[-1]:+.8%} of book)")
    print(f"  end book/start:  {exit_frac[-1]:.6f}")


if __name__ == "__main__":
    main()
