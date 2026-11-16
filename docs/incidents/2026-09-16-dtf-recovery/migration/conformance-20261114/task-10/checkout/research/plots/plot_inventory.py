#!/usr/bin/env python3
"""Plot full-exit token claim (inventory) over Mode A steps.

Shows classic LP inventory shift without USD P&L noise:

  exitClaimWeth / exitClaimWeth_0
  exitClaimUsdc / exitClaimUsdc_0
  optional: claim value split in USDC terms (stacked composition)

This is the “why the book moves” chart under one-way demand.
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
    for key in ("exitClaimWeth", "exitClaimUsdc", "uniSpot_USDCperWETH"):
        if key not in rows[0]:
            raise SystemExit(f"missing {key}; re-run forge script")

    meta = load_meta(args.run_dir)
    market_bought = market_bought_asset(meta, rows)
    main_t, sub_t = demand_title(market_bought)

    steps = [r["step"] for r in rows]
    w0 = parse_int(rows[0]["exitClaimWeth"])
    u0 = parse_int(rows[0]["exitClaimUsdc"])
    if w0 <= 0 or u0 <= 0:
        raise SystemExit("zero t0 claim")

    w_idx = [parse_int(r["exitClaimWeth"]) / w0 for r in rows]
    u_idx = [parse_int(r["exitClaimUsdc"]) / u0 for r in rows]

    # USDC mark of each leg (absolute 18-dec token units → float)
    w_usdc = [
        w18(r["exitClaimWeth"]) * w18(r["uniSpot_USDCperWETH"]) for r in rows
    ]
    u_usdc = [w18(r["exitClaimUsdc"]) for r in rows]
    total_usdc = [w_usdc[i] + u_usdc[i] for i in range(len(rows))]
    w_share = [w_usdc[i] / total_usdc[i] if total_usdc[i] else 0.0 for i in range(len(rows))]

    fig, axes = plt.subplots(
        2,
        1,
        figsize=(12.5, 8.2),
        sharex=True,
        gridspec_kw={"height_ratios": [1.4, 1.0]},
    )

    ax = axes[0]
    ax.axhline(1.0, color="gray", linestyle="--", lw=1, alpha=0.65)
    ax.plot(steps, w_idx, color="#1f77b4", lw=2.4, label="WETH claim index (full exit)")
    ax.plot(steps, u_idx, color="#2ca02c", lw=2.4, label="USDC claim index (full exit)")
    ax.set_ylabel("Token claim / t0 claim")
    ax.set_title(
        f"Inventory (full-exit claim) — {main_t}\n"
        f"{sub_t}  ·  classic CPMM inventory tilt under one-way flow",
        fontsize=11,
        pad=12,
    )
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.annotate(
        f"WETH {w_idx[-1]:.6f}",
        xy=(steps[-1], w_idx[-1]),
        xytext=(-90, 10),
        textcoords="offset points",
        fontsize=9,
        color="#1f77b4",
    )
    ax.annotate(
        f"USDC {u_idx[-1]:.6f}",
        xy=(steps[-1], u_idx[-1]),
        xytext=(-90, -14),
        textcoords="offset points",
        fontsize=9,
        color="#2ca02c",
    )

    ax2 = axes[1]
    ax2.fill_between(steps, 0, w_share, color="#1f77b4", alpha=0.45, label="WETH leg (USDC mark share)")
    ax2.fill_between(steps, w_share, 1.0, color="#2ca02c", alpha=0.45, label="USDC leg (USDC mark share)")
    ax2.set_ylim(0, 1)
    ax2.set_xlabel("Trade step (market demand against our liquidity)")
    ax2.set_ylabel("Portfolio mix\n(USDC-mark share)")
    ax2.legend(loc="best", fontsize=9)
    ax2.grid(True, alpha=0.3)
    ax2.annotate(
        f"end WETH share {w_share[-1]:.2%}",
        xy=(steps[-1], w_share[-1]),
        xytext=(-120, 0),
        textcoords="offset points",
        fontsize=9,
        color="#1f77b4",
        va="center",
    )

    # Full-exit claim includes large Balancer *pair* legs, not only Uni LP inside the SE vault.
    # Token-qty indices can look flat while rates and USDC marks move — see rates.png / pnl_*.png.
    if market_bought == "WETH":
        expect = (
            "Uni LP inside SE tilts (less WETH / more USDC after selling WETH), but full-exit token "
            "indices are often ~flat because Balancer pair legs dominate qty. Read rates + P&L for economics."
        )
    elif market_bought == "USDC":
        expect = (
            "Uni LP inside SE tilts (more WETH / less USDC after selling USDC), but full-exit token "
            "indices are often ~flat because Balancer pair legs dominate qty. Read rates + P&L for economics."
        )
    else:
        expect = "Full-exit claim = Balancer pairs + SE→LP→tokens. Rates move more than raw token indices."

    fig.text(0.5, 0.01, expect, ha="center", va="bottom", fontsize=8.5, color="0.35")
    fig.tight_layout(rect=(0, 0.04, 1, 1))

    out = args.out or (args.run_dir / "inventory.png")
    fig.savefig(out, dpi=160, bbox_inches="tight")
    print(f"wrote {out}")
    print(f"  market_bought={market_bought}")
    print(f"  WETH claim index end={w_idx[-1]:.8f}")
    print(f"  USDC claim index end={u_idx[-1]:.8f}")
    print(f"  WETH USDC-mark share: {w_share[0]:.4%} → {w_share[-1]:.4%}")


if __name__ == "__main__":
    main()
