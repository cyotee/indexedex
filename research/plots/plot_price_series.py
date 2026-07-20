#!/usr/bin/env python3
"""Plot research Mode A price series — raw bar-ratio indices (default).

Five markets (notation labels only):

  (USDC/WETH)                 Uniswap V2 spot index
  (USDC/WETH(USDC/WETH))      pair USDC, vault rated WETH
  (USDC/USDC(USDC/WETH))      pair USDC, vault rated USDC
  (WETH/WETH(USDC/WETH))      pair WETH, vault rated WETH
  (WETH/USDC(USDC/WETH))      pair WETH, vault rated USDC

Balancer index = mid_t/mid_0 with mid = pair / liveShares (bar supply ratio).
With frozen Balancer inventory: mid_t/mid_0 = rate_0/rate_t for that rate target.

Default: **raw** indices — Uni USDC/WETH falls when market buys USDC; WETH-rated
pools move with Uni; USDC-rated move opposite. No display invert.
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
import numpy as np


LABEL_UNIV2 = "(USDC/WETH)"
LABEL_USDC_VAULT_WETH = "(USDC/WETH(USDC/WETH))"
LABEL_USDC_VAULT_USDC = "(USDC/USDC(USDC/WETH))"
LABEL_WETH_VAULT_WETH = "(WETH/WETH(USDC/WETH))"
LABEL_WETH_VAULT_USDC = "(WETH/USDC(USDC/WETH))"

WETH_RATED = {LABEL_USDC_VAULT_WETH, LABEL_WETH_VAULT_WETH}
USDC_RATED = {LABEL_USDC_VAULT_USDC, LABEL_WETH_VAULT_USDC}


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
    meta_path = run_dir / "meta.json"
    if not meta_path.exists():
        return {}
    return json.loads(meta_path.read_text())


def w(x: str | int) -> float:
    return int(x) / 1e18


def mid_index_series(rows: list[dict], mid_key: str) -> list[float]:
    if mid_key not in rows[0]:
        raise SystemExit(f"missing {mid_key}; re-run forge script to regenerate series")
    m0 = w(rows[0][mid_key])
    if m0 <= 0:
        raise SystemExit(f"zero mid0 for {mid_key}")
    return [w(r[mid_key]) / m0 for r in rows]


def uni_index_series(rows: list[dict]) -> list[float]:
    if "uniSpot_USDCperWETH" not in rows[0]:
        raise SystemExit("missing uniSpot_USDCperWETH")
    s0 = w(rows[0]["uniSpot_USDCperWETH"])
    return [w(r["uniSpot_USDCperWETH"]) / s0 for r in rows]


def pick_five_pools(rows: list[dict]) -> list[tuple[str, list[float]]]:
    return [
        (LABEL_UNIV2, uni_index_series(rows)),
        (LABEL_USDC_VAULT_WETH, mid_index_series(rows, "rateWeth_pairUsdc_cross_midRaw")),
        (LABEL_USDC_VAULT_USDC, mid_index_series(rows, "rateUsdc_pairUsdc_same_midRaw")),
        (LABEL_WETH_VAULT_WETH, mid_index_series(rows, "rateWeth_pairWeth_same_midRaw")),
        (LABEL_WETH_VAULT_USDC, mid_index_series(rows, "rateUsdc_pairWeth_cross_midRaw")),
    ]


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


def place_end_labels(
    ax: plt.Axes,
    ends: list[tuple[float, float, str, object]],
    x_max: float,
) -> None:
    if not ends:
        return

    ends_sorted = sorted(ends, key=lambda t: t[1])
    n = len(ends_sorted)

    y_data_min = min(e[1] for e in ends_sorted)
    y_data_max = max(e[1] for e in ends_sorted)
    y_lo, y_hi = ax.get_ylim()
    data_span = max(y_data_max - y_data_min, abs(y_hi - y_lo) * 0.02, 1e-15)

    pad = data_span * 0.15
    y_lo2 = min(y_lo, y_data_min - pad)
    y_hi2 = max(y_hi, y_data_max + pad)

    label_slot = data_span * 0.28
    needed = max(n * label_slot, data_span * 1.35)
    mid = 0.5 * (y_data_min + y_data_max)
    y_lo2 = min(y_lo2, mid - needed / 2)
    y_hi2 = max(y_hi2, mid + needed / 2)
    ax.set_ylim(y_lo2, y_hi2)

    margin = (y_hi2 - y_lo2) * 0.07
    if n == 1:
        label_ys = [0.5 * (y_lo2 + y_hi2)]
    else:
        label_ys = list(np.linspace(y_lo2 + margin, y_hi2 - margin, n))

    x0, _ = ax.get_xlim()
    width = max(x_max - x0, 1.0)
    ax.set_xlim(x0, x_max + width * 0.85)
    x_text = x_max + width * 0.05

    for (x_end, y_end, label, color), y_lab in zip(ends_sorted, label_ys):
        ax.annotate(
            label,
            xy=(x_end, y_end),
            xytext=(x_text, y_lab),
            textcoords="data",
            fontsize=9,
            color=color,
            va="center",
            ha="left",
            arrowprops=dict(arrowstyle="-", color=color, lw=0.9, shrinkA=0, shrinkB=3),
            bbox=dict(boxstyle="round,pad=0.35", fc="white", ec=color, alpha=0.94, lw=0.8),
            zorder=5,
        )


def title_for_run(market_bought: str, uni_end: float) -> tuple[str, str]:
    bought = market_bought or "?"
    uni_dir = "up" if uni_end >= 1.0 else "down"
    main = f"Price indices — Mode A: market buys {bought} from our Uni liquidity"
    if bought == "USDC":
        sub = (
            f"Raw bar ratios (no invert). Uni USDC/WETH goes {uni_dir} "
            f"(WETH cheaper)  ·  WETH-rated mids with Uni  ·  USDC-rated opposite"
        )
    elif bought == "WETH":
        sub = (
            f"Raw bar ratios (no invert). Uni USDC/WETH goes {uni_dir} "
            f"(WETH dearer)  ·  WETH-rated mids with Uni  ·  USDC-rated opposite"
        )
    else:
        sub = "Raw mid_t/mid_0  ·  mid = pair / liveShares"
    return main, sub


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("run_dir", type=Path)
    p.add_argument("--out", type=Path, default=None)
    p.add_argument(
        "--invert",
        action="store_true",
        help="Legacy pitch invert (1/index). Default is raw bar-ratio direction.",
    )
    args = p.parse_args()

    rows = load_series(args.run_dir / "series.jsonl")
    if not rows:
        raise SystemExit("empty series")
    meta = load_meta(args.run_dir)
    steps = [r["step"] for r in rows]
    paths = pick_five_pools(rows)
    market_bought = market_bought_asset(meta, rows)

    if args.invert:
        flipped = []
        for lab, ys in paths:
            flipped.append((lab, [1.0 / y if y > 0 else float("nan") for y in ys]))
        paths = flipped

    color_for = {
        LABEL_UNIV2: "#111111",
        LABEL_USDC_VAULT_WETH: "#1f77b4",
        LABEL_WETH_VAULT_WETH: "#17becf",
        LABEL_USDC_VAULT_USDC: "#d62728",
        LABEL_WETH_VAULT_USDC: "#ff7f0e",
    }
    styles = {
        LABEL_UNIV2: "-",
        LABEL_USDC_VAULT_WETH: "-",
        LABEL_WETH_VAULT_WETH: "--",
        LABEL_USDC_VAULT_USDC: "-",
        LABEL_WETH_VAULT_USDC: "--",
    }

    fig, ax = plt.subplots(figsize=(14.0, 7.2))
    ends: list[tuple[float, float, str, object]] = []

    for label, ys in paths:
        color = color_for.get(label, "#333333")
        (line,) = ax.plot(
            steps,
            ys,
            color=color,
            linewidth=2.4 if label == LABEL_UNIV2 else 2.0,
            linestyle=styles.get(label, "-"),
            solid_capstyle="round",
            zorder=3 if label == LABEL_UNIV2 else 2,
        )
        ends.append((float(steps[-1]), float(ys[-1]), label, line.get_color()))

    uni_end = next(ys[-1] for lab, ys in paths if lab == LABEL_UNIV2)

    ax.axhline(1.0, color="gray", linestyle="--", linewidth=1, alpha=0.65, zorder=0)
    ax.set_xlabel("Trade step")
    ax.set_ylabel("Relative bar-ratio index (start = 1.0)\nmid = pair / liveShares")

    main_title, sub_title = title_for_run(market_bought, uni_end)
    if args.invert:
        sub_title = "DISPLAY INVERTED (1/index) — not raw market direction"
    ax.set_title(f"{main_title}\n{sub_title}", fontsize=12, pad=14)

    ax.grid(True, alpha=0.3)
    place_end_labels(ax, ends, x_max=float(steps[-1]))

    fig.text(
        0.5,
        0.01,
        "Black = Uni USDC/WETH  ·  Blue/cyan = vault rated WETH (moves with Uni)  ·  "
        "Red/orange = vault rated USDC (moves opposite Uni)  ·  Same rating ⇒ same path",
        ha="center",
        va="bottom",
        fontsize=9,
        color="0.35",
    )

    fig.tight_layout(rect=(0, 0.04, 1, 1))
    out = args.out or (args.run_dir / "price_index.png")
    fig.savefig(out, dpi=160, bbox_inches="tight")
    print(f"wrote {out}")
    print(f"market_bought={market_bought}  invert={args.invert}  uni_end={uni_end:.6f}")
    for label, ys in paths:
        family = (
            "uni"
            if label == LABEL_UNIV2
            else "WETH-rated"
            if label in WETH_RATED
            else "USDC-rated"
        )
        print(f"  [{family:10s}] {label}  end={ys[-1]:.10f}")


if __name__ == "__main__":
    main()
