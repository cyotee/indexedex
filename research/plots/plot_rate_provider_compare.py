#!/usr/bin/env python3
"""Side-by-side R+ (rates on) vs R− (rates off) comparison plots."""

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


def residual_series(rows: list[dict]) -> tuple[list[float], list[float]]:
    """Return (mid*rate residual, rate dual-numeraire residual) as absolute (not ppm)."""
    mid_track = []
    rate_id = []
    for r in rows:
        mid_i = w18(r["rateWeth_pairUsdc_cross_index"])
        rw_i = w18(r["rateWethIndex"])
        mid_track.append(mid_i * rw_i - 1.0)
        prod = si(r["rateWeth"]) * si(r["uniSpot_USDCperWETH"]) / 1e18
        rate_id.append(prod / si(r["rateUsdc"]) - 1.0)
    return mid_track, rate_id


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("rates_on_dir", type=Path)
    p.add_argument("rates_off_dir", type=Path)
    p.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Default: research/out/uniswapV2Se/rateProviderCompare/compare/<pair>/",
    )
    args = p.parse_args()

    on = load_series(args.rates_on_dir / "series.jsonl")
    off = load_series(args.rates_off_dir / "series.jsonl")
    if not on or not off:
        raise SystemExit("empty series")
    meta_on = load_meta(args.rates_on_dir)
    meta_off = load_meta(args.rates_off_dir)

    demand = meta_on.get("marketBoughtAsset") or "?"
    mode = meta_on.get("mode") or "?"
    pair_name = f"{mode}_{demand}"

    out_dir = args.out_dir or Path(
        "research/out/uniswapV2Se/rateProviderCompare/compare"
    ) / pair_name.replace(" ", "_")
    out_dir.mkdir(parents=True, exist_ok=True)

    steps_on = [r["step"] for r in on]
    steps_off = [r["step"] for r in off]
    uni_on = [w18(r["uniPriceIndex"]) for r in on]
    uni_off = [w18(r["uniPriceIndex"]) for r in off]
    mid_on = [w18(r["rateWeth_pairUsdc_cross_index"]) for r in on]
    mid_off = [w18(r["rateWeth_pairUsdc_cross_index"]) for r in off]

    mid_t_on, _ = residual_series(on)
    mid_t_off, _ = residual_series(off)

    p0_on = si(on[0]["portfolio0Usdc"])
    p0_off = si(off[0]["portfolio0Usdc"])
    total_on = [si(r["totalPnlUsdc"]) / p0_on for r in on]
    total_off = [si(r["totalPnlUsdc"]) / p0_off for r in off]
    fee_on = [si(r["feePnlUsdc"]) / 1e18 for r in on]
    fee_off = [si(r["feePnlUsdc"]) / 1e18 for r in off]

    has_probe = "maxBuyProbe" in on[0] and "maxBuyProbe" in off[0]
    if has_probe:
        buy_on = [si(r.get("maxBuyProbe") or 0) for r in on]
        buy_off = [si(r.get("maxBuyProbe") or 0) for r in off]
        fills_on = [si(r.get("arbFills") or 0) for r in on]
        fills_off = [si(r.get("arbFills") or 0) for r in off]
    else:
        buy_on = buy_off = fills_on = fills_off = None

    # --- fairness_compare ---
    fig, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    ax = axes[0]
    ax.plot(steps_on, uni_on, "k-", lw=2, label="R+ Uni index")
    ax.plot(steps_off, uni_off, "k--", lw=1.5, alpha=0.7, label="R− Uni index")
    ax.plot(steps_on, mid_on, "b-", lw=2, label="R+ midW index")
    ax.plot(steps_off, mid_off, "b--", lw=1.5, alpha=0.7, label="R− midW index")
    ax.axhline(1.0, color="gray", ls=":", alpha=0.5)
    ax.set_ylabel("Index (start=1)")
    ax.set_title(f"R+ vs R− indices — market buys {demand} ({mode})")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    ax = axes[1]
    ax.axhline(0.0, color="gray", ls="--")
    ax.plot(steps_on, [x * 1e6 for x in mid_t_on], "g-", lw=2, label="R+ mid×rate residual (×1e6)")
    ax.plot(steps_off, [x * 1e6 for x in mid_t_off], "r-", lw=2, label="R− mid×rate residual (×1e6)")
    ax.set_xlabel("Step")
    ax.set_ylabel("Residual ×1e6")
    ax.set_title("Fairness: R+ mid tracks 1/rate (~0); R− does not use live rate on pool")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(out_dir / "fairness_compare.png", dpi=160, bbox_inches="tight")
    print("wrote", out_dir / "fairness_compare.png")

    # --- pnl_compare ---
    fig, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    ax = axes[0]
    ax.axhline(0.0, color="gray", ls="--")
    ax.plot(steps_on, [x * 100 for x in total_on], "g-", lw=2, label="R+ total P&L / start %")
    ax.plot(steps_off, [x * 100 for x in total_off], "r-", lw=2, label="R− total P&L / start %")
    ax.set_ylabel("% of start book")
    ax.set_title(f"LP book total P&L — market buys {demand}")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    ax = axes[1]
    ax.axhline(0.0, color="gray", ls="--")
    ax.plot(steps_on, fee_on, "g-", lw=2, label="R+ fee P&L (USDC)")
    ax.plot(steps_off, fee_off, "r-", lw=2, label="R− fee P&L (USDC)")
    ax.set_xlabel("Step")
    ax.set_ylabel("Fee P&L (USDC)")
    ax.set_title("LP fee P&L (maker fees + claim drift)")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(out_dir / "pnl_compare.png", dpi=160, bbox_inches="tight")
    print("wrote", out_dir / "pnl_compare.png")

    # --- probes_compare ---
    fig, ax = plt.subplots(figsize=(12, 5))
    ax.axhline(0.0, color="gray", ls="--")
    if has_probe:
        ax.plot(steps_on, buy_on, "g-", lw=2.2, label="R+ maxBuyProbe (wei)")
        ax.plot(steps_off, buy_off, "r-", lw=2.2, label="R− maxBuyProbe (wei)")
        ax.plot(steps_on, fills_on, "g--", lw=1.2, alpha=0.7, label="R+ fills")
        ax.plot(steps_off, fills_off, "r--", lw=1.2, alpha=0.7, label="R− fills")
        ax.set_title(
            f"Arb probes — market buys {demand}\n"
            f"R+ maxBuy={max(buy_on)} fills={sum(fills_on)} · "
            f"R− maxBuy={max(buy_off)} fills={sum(fills_off)}"
        )
    else:
        ax.text(0.5, 0.5, "No probe fields (Mode A run)", ha="center", transform=ax.transAxes)
        ax.set_title("Arb probes (N/A for Mode A-only)")
    ax.set_xlabel("Step")
    ax.set_ylabel("Probe wei / fills")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(out_dir / "probes_compare.png", dpi=160, bbox_inches="tight")
    print("wrote", out_dir / "probes_compare.png")

    summary = {
        "demand": demand,
        "mode": mode,
        "rates_on": str(args.rates_on_dir),
        "rates_off": str(args.rates_off_dir),
        "uni_end_on": uni_on[-1],
        "uni_end_off": uni_off[-1],
        "midW_end_on": mid_on[-1],
        "midW_end_off": mid_off[-1],
        "mid_rate_residual_end_on": mid_t_on[-1],
        "mid_rate_residual_end_off": mid_t_off[-1],
        "total_pnl_frac_end_on": total_on[-1],
        "total_pnl_frac_end_off": total_off[-1],
        "fee_usdc_end_on": fee_on[-1],
        "fee_usdc_end_off": fee_off[-1],
        "maxBuyProbe_on": max(buy_on) if has_probe else None,
        "maxBuyProbe_off": max(buy_off) if has_probe else None,
        "fills_sum_on": sum(fills_on) if has_probe else None,
        "fills_sum_off": sum(fills_off) if has_probe else None,
        "meta_on": meta_on,
        "meta_off": meta_off,
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("wrote", out_dir / "summary.json")


if __name__ == "__main__":
    main()
