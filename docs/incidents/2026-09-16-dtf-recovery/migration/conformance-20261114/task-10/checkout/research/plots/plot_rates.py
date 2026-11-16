#!/usr/bin/env python3
"""Plot SE vault rate-provider indices vs Uni spot (Mode A teaching chart).

Shows the foundation story without Balancer noise:

  Uni USDC/WETH index
  rate(WETH) index  — SE share valued as WETH claim
  rate(USDC) index  — SE share valued as USDC claim

With frozen Balancer inventory, Balancer mids follow rate_0/rate_t for that
rate target — so understanding rates is understanding the SE vault layer.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# Headless / non-interactive (research scripts must not block on a GUI backend).
os.environ.setdefault("MPLBACKEND", "Agg")

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from common import demand_title, load_meta, load_series, market_bought_asset, w18


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("run_dir", type=Path)
    p.add_argument("--out", type=Path, default=None)
    args = p.parse_args()

    rows = load_series(args.run_dir / "series.jsonl")
    if not rows:
        raise SystemExit("empty series")
    for key in ("uniPriceIndex", "rateWethIndex", "rateUsdcIndex"):
        if key not in rows[0]:
            raise SystemExit(f"missing {key}; re-run forge script")

    meta = load_meta(args.run_dir)
    market_bought = market_bought_asset(meta, rows)
    main_t, sub_t = demand_title(market_bought)

    steps = [r["step"] for r in rows]
    uni = [w18(r["uniPriceIndex"]) for r in rows]
    rw = [w18(r["rateWethIndex"]) for r in rows]
    ru = [w18(r["rateUsdcIndex"]) for r in rows]

    fig, ax = plt.subplots(figsize=(12.5, 6.8))
    ax.axhline(1.0, color="gray", linestyle="--", lw=1, alpha=0.65)
    ax.plot(steps, uni, color="#111111", lw=2.6, label="Uni (USDC/WETH) index")
    ax.plot(steps, rw, color="#1f77b4", lw=2.2, label="SE rate(WETH) index")
    ax.plot(steps, ru, color="#d62728", lw=2.2, label="SE rate(USDC) index")

    ax.set_xlabel("Trade step")
    ax.set_ylabel("Relative index (start = 1.0)")
    ax.set_title(
        f"SE vault rate providers — {main_t}\n"
        f"{sub_t}  ·  rates re-mark vault shares when Uni inventory tilts",
        fontsize=11,
        pad=12,
    )
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.3)

    # End annotations
    for ys, color, lab in (
        (uni, "#111111", f"Uni {uni[-1]:.6f}"),
        (rw, "#1f77b4", f"rateW {rw[-1]:.6f}"),
        (ru, "#d62728", f"rateU {ru[-1]:.6f}"),
    ):
        ax.annotate(
            lab,
            xy=(steps[-1], ys[-1]),
            xytext=(8, 0),
            textcoords="offset points",
            fontsize=8,
            color=color,
            va="center",
        )

    fig.text(
        0.5,
        0.01,
        "Foundation layer: Balancer mids with frozen inventory track 1/rate for that pool’s rate target. "
        "WETH-rated ≈ moves with Uni; USDC-rated ≈ opposite (see price_index.png).",
        ha="center",
        va="bottom",
        fontsize=9,
        color="0.35",
    )
    fig.tight_layout(rect=(0, 0.04, 1, 1))

    out = args.out or (args.run_dir / "rates.png")
    fig.savefig(out, dpi=160, bbox_inches="tight")
    print(f"wrote {out}")
    print(f"  market_bought={market_bought}")
    print(f"  uni_end={uni[-1]:.8f}  rateWeth_end={rw[-1]:.8f}  rateUsdc_end={ru[-1]:.8f}")
    # Product: rateWeth * (USDC/WETH) should track rateUsdc directionally
    product = [rw[i] * uni[i] for i in range(len(rows))]
    print(f"  rateWeth*uni_end={product[-1]:.8f}  (compare rateUsdc_end; identity is approximate with fees)")


if __name__ == "__main__":
    main()
