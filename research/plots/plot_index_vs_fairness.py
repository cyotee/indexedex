#!/usr/bin/env python3
"""Visual proof: chart slopes can diverge without creating redeem arb.

Three panels (same Mode A / Mode C series.jsonl):

  1) Relative indices — Uni USDC/WETH vs Balancer mids (different slopes; what you saw)
  2) True consistency residuals near 0 — rate dual-numeraire + mid tracks 1/rate
  3) Mistaken “chart gap” vs real arb probe (0 when Mode C fields present)

Teaching point: Uni_index − mid_index is NOT (redeem value − buy cost).
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


def si(x) -> int:
    return parse_int(x)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("run_dir", type=Path)
    p.add_argument("--out", type=Path, default=None)
    args = p.parse_args()

    rows = load_series(args.run_dir / "series.jsonl")
    if not rows:
        raise SystemExit("empty series")
    need = [
        "uniPriceIndex",
        "rateWeth",
        "rateUsdc",
        "rateWethIndex",
        "rateUsdcIndex",
        "uniSpot_USDCperWETH",
        "rateWeth_pairUsdc_cross_index",
        "rateUsdc_pairUsdc_same_index",
    ]
    for k in need:
        if k not in rows[0]:
            raise SystemExit(f"missing {k}")

    meta = load_meta(args.run_dir)
    bought = market_bought_asset(meta, rows)
    main_t, sub_t = demand_title(bought)

    steps = [r["step"] for r in rows]
    uni = [w18(r["uniPriceIndex"]) for r in rows]
    mid_w = [w18(r["rateWeth_pairUsdc_cross_index"]) for r in rows]
    mid_u = [w18(r["rateUsdc_pairUsdc_same_index"]) for r in rows]
    rw_idx = [w18(r["rateWethIndex"]) for r in rows]
    ru_idx = [w18(r["rateUsdcIndex"]) for r in rows]

    # Dual-numeraire identity: rateWeth * uniSpot / 1e18 ≈ rateUsdc
    # residual = product / rateUsdc - 1  (should be ~0)
    rate_id = []
    for r in rows:
        prod = si(r["rateWeth"]) * si(r["uniSpot_USDCperWETH"]) / 1e18
        rate_id.append(prod / si(r["rateUsdc"]) - 1.0)

    # Mid tracks inverse rate: mid_index * rateWeth_index ≈ 1
    mid_tracks = [mid_w[i] * rw_idx[i] - 1.0 for i in range(len(rows))]
    # USDC-rated mid tracks inverse rateUsdc
    mid_u_tracks = [mid_u[i] * ru_idx[i] - 1.0 for i in range(len(rows))]

    # Mistaken signal people read off the chart (not arb)
    chart_gap = [uni[i] / mid_w[i] - 1.0 for i in range(len(rows))]

    # Real Mode C probe if present (fraction of 1e18 wei for scale-free display: just raw 0)
    has_probe = "maxBuyProbe" in rows[0]
    if has_probe:
        buy_p = [si(r.get("maxBuyProbe") or 0) for r in rows]
        sell_p = [si(r.get("maxSellProbe") or 0) for r in rows]
    else:
        buy_p = sell_p = None

    fig, axes = plt.subplots(
        3,
        1,
        figsize=(12.5, 11.0),
        sharex=True,
        gridspec_kw={"height_ratios": [1.35, 1.15, 1.25]},
    )

    # --- Panel 1: different slopes (user's observation) ---
    ax = axes[0]
    ax.axhline(1.0, color="gray", ls="--", lw=1, alpha=0.65)
    ax.plot(steps, uni, color="#111111", lw=2.4, label="Uni USDC/WETH index")
    ax.plot(
        steps,
        mid_w,
        color="#1f77b4",
        lw=2.1,
        label="Balancer mid index (pair USDC, vault rated WETH)",
    )
    ax.plot(
        steps,
        mid_u,
        color="#d62728",
        lw=2.1,
        label="Balancer mid index (pair USDC, vault rated USDC)",
    )
    ax.set_ylabel("Relative index\n(start = 1.0)")
    ax.set_title(
        f"1) Chart slopes differ — that is expected\n{main_t}  ·  {sub_t}",
        fontsize=11,
        pad=10,
    )
    ax.legend(loc="best", fontsize=8)
    ax.grid(True, alpha=0.3)
    ax.annotate(
        f"Uni {uni[-1]:.4f}\nmidW {mid_w[-1]:.4f}\nmidU {mid_u[-1]:.4f}",
        xy=(steps[-1], uni[-1]),
        xytext=(-110, -30),
        textcoords="offset points",
        fontsize=8,
        bbox=dict(boxstyle="round", fc="white", alpha=0.9),
    )

    # --- Panel 2: true consistency residuals ---
    ax = axes[1]
    ax.axhline(0.0, color="gray", ls="--", lw=1, alpha=0.7)
    ax.plot(
        steps,
        [x * 1e6 for x in rate_id],
        color="#2ca02c",
        lw=2.2,
        label="rateWeth×uni/rateUsdc − 1  (×1e6)",
    )
    ax.plot(
        steps,
        [x * 1e6 for x in mid_tracks],
        color="#1f77b4",
        lw=2.0,
        label="midW_index×rateW_index − 1  (×1e6)",
    )
    ax.plot(
        steps,
        [x * 1e6 for x in mid_u_tracks],
        color="#d62728",
        lw=2.0,
        ls="--",
        label="midU_index×rateU_index − 1  (×1e6)",
    )
    ax.set_ylabel("Residual (ppm-scale)\n×1e6 vs 0")
    ax.set_title(
        "2) True consistency stays flat near zero (same run)\n"
        "Share has one claim: dual rates match Uni · Balancer mid tracks 1/rate",
        fontsize=11,
        pad=10,
    )
    ax.legend(loc="best", fontsize=8)
    ax.grid(True, alpha=0.3)
    # y limits tight around 0 but visible
    flat = rate_id + mid_tracks + mid_u_tracks
    m = max(1e-9, max(abs(x) for x in flat))
    ax.set_ylim(-m * 1e6 * 3, m * 1e6 * 3)

    # --- Panel 3: mistaken chart gap vs real arb probe ---
    ax = axes[2]
    ax.axhline(0.0, color="gray", ls="--", lw=1, alpha=0.7)
    ax.plot(
        steps,
        [x * 100 for x in chart_gap],
        color="#ff7f0e",
        lw=2.3,
        label="Mistaken signal: (Uni_index/midW_index − 1) × 100%  [NOT arb]",
    )
    if buy_p is not None:
        # probes are absolute wei; show as 0 line annotation if all zero
        ax.plot(
            steps,
            buy_p,
            color="#2ca02c",
            lw=2.4,
            label="Mode C maxBuyProbe (wei of profit token)",
        )
        ax.plot(
            steps,
            sell_p,
            color="#9467bd",
            lw=1.8,
            ls="--",
            label="Mode C maxSellProbe (wei)",
        )
        ax.set_ylabel("Mistaken % gap\n+ probe wei")
        if max(buy_p) == 0 and max(sell_p) == 0:
            ax.annotate(
                "Real arb probes = 0 every step\n(no buy-share→redeem profit)",
                xy=(steps[len(steps) // 2], 0),
                xytext=(0, 25),
                textcoords="offset points",
                ha="center",
                fontsize=9,
                color="#2ca02c",
                bbox=dict(boxstyle="round", fc="#e8f5e9", ec="#2ca02c"),
            )
    else:
        ax.set_ylabel("Mistaken gap (%)")
        ax.annotate(
            "Mode A run: no arb probes in series.\n"
            "Compare Mode C twin — probes stay 0 while chart gap moves.",
            xy=(steps[-1], chart_gap[-1] * 100),
            xytext=(-200, 20),
            textcoords="offset points",
            fontsize=8,
            bbox=dict(boxstyle="round", fc="white", alpha=0.92),
        )
    ax.set_xlabel("Trade step")
    ax.set_title(
        "3) Large-looking chart gap ≠ redeem arb\n"
        "Orange = index ratio people misread as free money · Green/purple = measured probe profit",
        fontsize=11,
        pad=10,
    )
    ax.legend(loc="best", fontsize=8)
    ax.grid(True, alpha=0.3)

    fig.text(
        0.5,
        0.01,
        "Arb needs (redeem value − buy cost) in one token > fees. "
        "Panel 1 compares different meters (WETH spot vs share mid). "
        "Panel 2 shows the system stays internally fair. Panel 3: chart gap can move while probes stay 0.",
        ha="center",
        va="bottom",
        fontsize=8.5,
        color="0.35",
    )
    fig.tight_layout(rect=(0, 0.04, 1, 1))

    out = args.out or (args.run_dir / "index_vs_fairness.png")
    fig.savefig(out, dpi=160, bbox_inches="tight")
    print(f"wrote {out}")
    print(f"  market_bought={bought}")
    print(f"  uni_end={uni[-1]:.6f}  midW_end={mid_w[-1]:.6f}  midU_end={mid_u[-1]:.6f}")
    print(f"  chart_gap_end%={(chart_gap[-1] * 100):.4f}")
    print(f"  rate_identity_end_ppm={rate_id[-1] * 1e6:.4f}")
    print(f"  midW*rateW_end_ppm={mid_tracks[-1] * 1e6:.4f}")
    if buy_p is not None:
        print(f"  max maxBuyProbe={max(buy_p)}  max maxSellProbe={max(sell_p)}")


if __name__ == "__main__":
    main()
