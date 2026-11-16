#!/usr/bin/env python3
"""Plot portfolio P&L from research Mode A series.jsonl.

LP / market-demand framing (not "we sell X"):

  modeA_trade_usdc  → market buys WETH from our Uni liquidity
  modeA_trade_weth  → market buys USDC from our Uni liquidity

Full-exit valuation in USDC:
  totalPnl   = exitValue - portfolio0
  pricePnl   = hold(claim0 at live prices) - portfolio0   # asset revaluation
  feePnl     = exitValue - hold(claim0)                   # maker fees + claim qty drift

Fee and price use separate panels so fee (~USDC) is not crushed by price (~1e9).
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

os.environ.setdefault("MPLBACKEND", "Agg")

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def load_series(path: Path) -> list[dict]:
    rows = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def load_meta(run_dir: Path) -> dict:
    p = run_dir / "meta.json"
    return json.loads(p.read_text()) if p.exists() else {}


def parse_int(s: str) -> int:
    s = str(s)
    if s.startswith("-"):
        return -int(s[1:])
    return int(s)


def market_bought_asset(meta: dict, rows: list[dict]) -> str:
    bought = meta.get("marketBoughtAsset") or meta.get("demandAsset")
    if bought in ("WETH", "USDC"):
        return bought
    traded = meta.get("tradedAsset", "")
    if traded == "WETH":
        return "USDC"
    if traded == "USDC":
        return "WETH"
    if "tradedIsWeth" in rows[0]:
        return "USDC" if rows[0]["tradedIsWeth"] else "WETH"
    return "?"


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("run_dir", type=Path)
    p.add_argument("--out", type=Path, default=None)
    args = p.parse_args()

    rows = load_series(args.run_dir / "series.jsonl")
    if not rows:
        raise SystemExit("empty series")
    if "totalPnlUsdc" not in rows[0]:
        raise SystemExit(
            "series.jsonl missing P&L fields; re-run forge script with updated fixture"
        )

    meta = load_meta(args.run_dir)
    market_bought = market_bought_asset(meta, rows)
    steps = [r["step"] for r in rows]
    price = [parse_int(r["pricePnlUsdc"]) / 1e18 for r in rows]
    fee = [parse_int(r["feePnlUsdc"]) / 1e18 for r in rows]
    total = [parse_int(r["totalPnlUsdc"]) / 1e18 for r in rows]
    exit_v = [parse_int(r["portfolioExitUsdc"]) / 1e18 for r in rows]
    p0 = parse_int(rows[0]["portfolio0Usdc"]) / 1e18

    if market_bought == "WETH":
        main_title = "Portfolio P&L — Mode A: market buys WETH from our Uni liquidity"
        sub_title = (
            "Full exit marked in USDC. WETH demand lifts USDC/WETH → "
            "asset-value P&L rises; green = maker fees."
        )
    elif market_bought == "USDC":
        main_title = "Portfolio P&L — Mode A: market buys USDC from our Uni liquidity"
        sub_title = (
            "Full exit marked in USDC. USDC demand lowers USDC/WETH → "
            "WETH inventory marks down in USDC; green = maker fees (still positive)."
        )
    else:
        main_title = "Portfolio P&L — Mode A"
        sub_title = "Full exit to USDC (Balancer → vault → Uni LP → tokens)"

    fig, axes = plt.subplots(
        3,
        1,
        figsize=(12, 9.5),
        sharex=True,
        gridspec_kw={"height_ratios": [2.0, 1.2, 1.4]},
    )

    # --- Panel 1: price + total (same order of magnitude) ---
    ax = axes[0]
    ax.axhline(0.0, color="gray", linestyle="--", lw=1, alpha=0.7)
    ax.plot(
        steps,
        price,
        label="Asset value P&L (t0 claim @ live USDC marks)",
        color="#1f77b4",
        lw=2.2,
    )
    ax.plot(steps, total, label="Total P&L (full exit − start)", color="#111111", lw=2.4)
    ax.set_ylabel("P&L (USDC)")
    ax.set_title(f"{main_title}\n{sub_title}", fontsize=11, pad=12)
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.3)

    # --- Panel 2: maker fees alone (readable scale) ---
    axf = axes[1]
    axf.axhline(0.0, color="gray", linestyle="--", lw=1, alpha=0.7)
    axf.plot(steps, fee, label="Maker fees + LP claim qty change", color="#2ca02c", lw=2.4)
    axf.set_ylabel("Fee P&L (USDC)")
    axf.legend(loc="best", fontsize=9)
    axf.grid(True, alpha=0.3)
    axf.annotate(
        f"end {fee[-1]:+.4f} USDC",
        xy=(steps[-1], fee[-1]),
        xytext=(-80, 12),
        textcoords="offset points",
        fontsize=9,
        color="#2ca02c",
        arrowprops=dict(arrowstyle="->", color="#2ca02c", lw=0.9),
    )

    # --- Panel 3: portfolio value ---
    ax2 = axes[2]
    ax2.plot(steps, exit_v, color="#9467bd", lw=2.0, label="Full-exit portfolio value")
    ax2.axhline(p0, color="gray", linestyle="--", lw=1, label=f"Start ({p0:,.0f} USDC)")
    ax2.set_xlabel("Trade step (market demand against our liquidity)")
    ax2.set_ylabel("Portfolio (USDC)")
    ax2.legend(loc="best", fontsize=9)
    ax2.grid(True, alpha=0.3)

    fig.tight_layout()
    out = args.out or (args.run_dir / "pnl.png")
    fig.savefig(out, dpi=160, bbox_inches="tight")
    print(f"wrote {out}")
    print(f"  run: market buys {market_bought}")
    print(f"  start portfolio USDC: {p0:,.6f}")
    print(f"  end exit USDC:        {exit_v[-1]:,.6f}")
    print(f"  end price P&L:        {price[-1]:,.6f}")
    print(f"  end fee P&L:          {fee[-1]:,.6f}")
    print(f"  end total P&L:        {total[-1]:,.6f}")


if __name__ == "__main__":
    main()
